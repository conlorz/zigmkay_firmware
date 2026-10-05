//! Explicit asynchronous firmware workflow; construction/export/build never touches a device.
const std = @import("std");
const p = @import("keymap-project");
const jobs = @import("companion-jobs");
const backend = jobs.firmware;
const toolchain = @import("editor-toolchain");
pub const State = enum { idle, building, built, stale, failed, cancelled, transferring, transferred, awaiting_reconnect, verified, reconnect_timeout };
pub fn recoveryTarget(override: []const u8) ![]const u8 {
    if (override.len == 0) return "RPI-RP2";
    if (!std.fs.path.isAbsolute(override) or std.mem.indexOfScalar(u8, override, 0) != null) return error.AbsoluteRecoveryVolumeRequired;
    return override;
}
pub fn flasherExecutable(gpa: std.mem.Allocator) ![]u8 {
    return std.fs.path.resolve(gpa, &.{ toolchain.build_root, toolchain.flash_exe });
}
pub const Controller = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    state: State = .idle,
    snapshot_id: [32]u8 = @splat(0),
    inputs: ?backend.Inputs = null,
    git_revision: ?[]const u8 = null,
    job: ?*jobs.Job = null,
    manifest: ?backend.Manifest = null,
    frozen: ?p.snapshot.Loaded = null,
    expected: ?@import("device-protocol").Identity = null,
    reconnect_deadline: u64 = 0,
    artifact_path: ?[]const u8 = null,
    rollback_path: ?[]const u8 = null,
    diagnostic: std.ArrayList(u8) = .empty,
    transferred: bool = false,
    running_verified: bool = false,
    typing_verified: bool = false,
    pub fn init(gpa: std.mem.Allocator, io: std.Io, root: []const u8) !Controller {
        const owned_root = try gpa.dupe(u8, root);
        errdefer gpa.free(owned_root);
        var self = Controller{ .gpa = gpa, .io = io, .root = owned_root };
        // This is the exact user-accepted G04 artifact, never a latest-file guess.
        const rollback = try std.fs.path.join(gpa, &.{ root, ".zig-cache/manual-session/recovery-11/lk7-accepted-c402a550.uf2" });
        defer gpa.free(rollback);
        if (std.Io.Dir.cwd().readFileAlloc(io, rollback, gpa, .limited(16 * 1024 * 1024))) |bytes| {
            defer gpa.free(bytes);
            const hex = std.fmt.bytesToHex(backend.digest(bytes), .lower);
            if (std.mem.eql(u8, &hex, "c402a55066505d338162e120eac4f038a621d0cee925ca0618f17efe48492263")) self.rollback_path = try gpa.dupe(u8, rollback);
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
        return self;
    }
    pub fn deinit(self: *Controller) void {
        self.stopJob();
        self.clearArtifact();
        if (self.frozen) |*frozen| frozen.deinit();
        if (self.rollback_path) |path| self.gpa.free(path);
        self.gpa.free(self.root);
        if (self.git_revision) |revision| self.gpa.free(revision);
        self.diagnostic.deinit(self.gpa);
    }
    fn stopJob(self: *Controller) void {
        if (self.job) |job| {
            job.deinit();
            self.gpa.destroy(job);
            self.job = null;
        }
    }
    fn clearArtifact(self: *Controller) void {
        if (self.manifest) |*manifest| manifest.deinit();
        self.manifest = null;
        if (self.artifact_path) |path| self.gpa.free(path);
        self.artifact_path = null;
        self.transferred = false;
        self.running_verified = false;
        self.typing_verified = false;
    }
    pub fn cancel(self: *Controller) void {
        // UI offers cancellation only before transfer, which cannot be rolled back.
        if (self.state != .building) return;
        self.stopJob();
        self.clearArtifact();
        self.state = .cancelled;
    }
    pub fn invalidateExternalSources(self: *Controller) void {
        if (self.state != .built and self.state != .building) return;
        self.stopJob();
        self.clearArtifact();
        self.state = .stale;
    }
    fn fail(self: *Controller, err: anyerror) void {
        self.stopJob();
        self.clearArtifact();
        self.state = .failed;
        self.diagnostic.appendSlice(self.gpa, @errorName(err)) catch {};
    }
    fn compilerDigest(self: *Controller) ![32]u8 {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(self.io, toolchain.zig_exe, self.gpa, .limited(256 * 1024 * 1024));
        defer self.gpa.free(bytes);
        return backend.digest(bytes);
    }
    fn currentInputs(self: *Controller, current: [32]u8) !backend.Inputs {
        var inputs = self.inputs orelse return error.NoBuildInputs;
        inputs.project_digest = current;
        inputs.build_inputs_digest = try @import("build_inputs.zig").digest(self.gpa, self.io, self.root);
        inputs.compiler_digest = try self.compilerDigest();
        return inputs;
    }
    pub fn build(self: *Controller, snapshot: p.snapshot.Snapshot) !void {
        if (self.state == .transferring) return error.TransferInProgress;
        self.stopJob();
        self.clearArtifact();
        self.state = .failed;
        self.diagnostic.clearRetainingCapacity();
        errdefer |err| self.fail(err);
        self.snapshot_id = try p.snapshot.projectDigest(self.gpa, snapshot, p.profiles.board);
        var compiler_version = try jobs.run(self.gpa, self.io, .{ .argv = &.{ toolchain.zig_exe, "version" }, .cwd = self.root, .snapshot_id = self.snapshot_id, .timeout_ms = 2000 });
        defer compiler_version.deinit(self.gpa);
        if (!compiler_version.successful() or !std.mem.eql(u8, std.mem.trim(u8, compiler_version.process.stdout, "\r\n"), "0.16.0")) return error.UnsupportedCompilerVersion;
        const identity = try p.snapshot.identity(self.gpa, snapshot, p.profiles.board);
        if (self.frozen) |*frozen| frozen.deinit();
        self.frozen = null;
        self.frozen = try p.snapshot.clone(self.gpa, snapshot);
        self.expected = identity;
        self.reconnect_deadline = 0;
        var source_hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (snapshot.document.callbacks) |callback| source_hash.update(&p.snapshot.bundleDigest(callback));
        self.inputs = .{ .project_digest = self.snapshot_id, .source_digest = source_hash.finalResult(), .build_inputs_digest = try @import("build_inputs.zig").digest(self.gpa, self.io, self.root), .compiler_digest = try self.compilerDigest(), .profile_id = identity.profile_id, .identity_digest = identity.digest };
        if (self.git_revision) |revision| self.gpa.free(revision);
        self.git_revision = null;
        if (jobs.run(self.gpa, self.io, .{ .argv = &.{ "git", "rev-parse", "HEAD" }, .cwd = self.root, .snapshot_id = self.snapshot_id, .timeout_ms = 2000 })) |value| {
            var result = value;
            defer result.deinit(self.gpa);
            if (result.successful()) self.git_revision = try self.gpa.dupe(u8, std.mem.trim(u8, result.process.stdout, "\r\n"));
        } else |_| {}
        self.inputs.?.git_revision = self.git_revision;
        const hex = std.fmt.bytesToHex(backend.key(self.inputs.?), .lower);
        const directory = try std.fs.path.join(self.gpa, &.{ self.root, ".zig-cache", "editor-firmware", &hex });
        defer self.gpa.free(directory);
        const exported = try std.fs.path.join(self.gpa, &.{ directory, "profile" });
        defer self.gpa.free(exported);
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, exported, .{});
        defer dir.close(self.io);
        const export_manifest = try p.exporter.write(self.gpa, self.io, dir, snapshot, p.profiles.board);
        defer std.zon.parse.free(self.gpa, export_manifest);
        const prefix = try std.fs.path.join(self.gpa, &.{ directory, "install" });
        defer self.gpa.free(prefix);
        var command = try backend.Command.init(self.gpa, self.inputs.?, toolchain.zig_exe, self.root, exported, prefix);
        defer command.deinit();
        self.artifact_path = try self.gpa.dupe(u8, command.uf2_path);
        const job = try self.gpa.create(jobs.Job);
        errdefer self.gpa.destroy(job);
        job.* = try jobs.Job.init(self.gpa, self.io, .{ .argv = command.argv, .cwd = command.cwd, .snapshot_id = self.snapshot_id, .timeout_ms = 120_000 });
        errdefer job.deinit();
        try job.start();
        self.job = job;
        self.state = .building;
    }
    fn persist(self: *Controller) !void {
        const manifest = self.manifest.?;
        var writer: std.Io.Writer.Allocating = .init(self.gpa);
        defer writer.deinit();
        try std.zon.stringify.serializeMaxDepth(.{ .version = manifest.version, .inputs = manifest.inputs, .build_key = manifest.build_key, .uf2_path = manifest.uf2_path, .uf2_size = manifest.uf2_size, .uf2_hash = manifest.uf2_hash }, .{}, &writer.writer, 16);
        const path = try std.fmt.allocPrint(self.gpa, "{s}.manifest.zon", .{manifest.uf2_path});
        defer self.gpa.free(path);
        var file = try std.Io.Dir.cwd().createFileAtomic(self.io, path, .{ .replace = true });
        defer file.deinit(self.io);
        try file.file.writeStreamingAll(self.io, writer.written());
        try file.file.sync(self.io);
        try file.replace(self.io);
    }
    pub fn poll(self: *Controller, current: [32]u8) void {
        if (!self.transferred and !std.mem.eql(u8, &self.snapshot_id, &current) and self.state != .idle and self.state != .failed and self.state != .cancelled) {
            // Let an explicitly authorized transfer finish; record it as stale afterwards.
            if (self.state != .transferring) {
                self.stopJob();
                self.clearArtifact();
                self.state = .stale;
                return;
            }
        }
        if (self.job) |job| if (job.poll()) |status| {
            self.job = null;
            defer {
                job.deinit();
                self.gpa.destroy(job);
            }
            if (status) |value| {
                var result = value;
                defer result.deinit(self.gpa);
                self.diagnostic.clearRetainingCapacity();
                self.diagnostic.appendSlice(self.gpa, result.process.stdout) catch {};
                self.diagnostic.appendSlice(self.gpa, result.process.stderr) catch {};
                if (!result.successful()) {
                    self.fail(error.ProcessFailed);
                    return;
                }
                if (self.state == .transferring) {
                    self.transferred = true;
                    self.state = if (result.fresh(current)) .transferred else .stale;
                    return;
                }
                self.finishBuild(current) catch |err| {
                    self.fail(err);
                    return;
                };
                self.state = .built;
            } else |err| self.fail(err);
        };
    }
    fn finishBuild(self: *Controller, current: [32]u8) !void {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(self.io, self.artifact_path.?, self.gpa, .limited(16 * 1024 * 1024));
        defer self.gpa.free(bytes);
        self.manifest = try backend.Manifest.complete(self.gpa, .succeeded, backend.key(self.inputs.?), self.inputs.?, try self.currentInputs(current), self.artifact_path.?, bytes);
        try self.persist();
    }
    pub fn flash(self: *Controller, current: [32]u8, volume: []const u8, confirmed: bool) !void {
        if (!confirmed) return error.FlashConfirmationRequired;
        if (self.state != .built or self.manifest == null) return error.NoCurrentArtifact;
        const target = try recoveryTarget(volume);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(self.io, self.artifact_path.?, self.gpa, .limited(16 * 1024 * 1024));
        defer self.gpa.free(bytes);
        self.manifest.?.verify(self.gpa, try self.currentInputs(current), bytes) catch |err| {
            self.clearArtifact();
            self.state = .stale;
            return err;
        };
        // Existing flasher validates UF2, mount metadata and compatible RP2040 family.
        const job = try self.gpa.create(jobs.Job);
        errdefer self.gpa.destroy(job);
        const expected_hash = std.fmt.bytesToHex(self.manifest.?.uf2_hash, .lower);
        const executable = try flasherExecutable(self.gpa);
        defer self.gpa.free(executable);
        job.* = try jobs.Job.init(self.gpa, self.io, .{ .argv = &.{ executable, self.artifact_path.?, target, "--expected-sha256", &expected_hash }, .cwd = self.root, .snapshot_id = self.snapshot_id, .timeout_ms = 60_000 });
        errdefer job.deinit();
        try job.start();
        self.job = job;
        self.state = .transferring;
    }
    pub fn verifyRunning(self: *Controller, identity: @import("device-protocol").Identity) !void {
        if (!self.transferred or self.manifest == null) return error.NoTransferredArtifact;
        const inputs = self.manifest.?.inputs;
        if (!std.mem.eql(u8, &inputs.profile_id, &identity.profile_id) or !std.mem.eql(u8, &inputs.identity_digest, &identity.digest) or !std.mem.eql(u8, &identity.board_id, &p.profiles.board.id)) return error.RunningIdentityMismatch;
        self.running_verified = true;
        self.state = .verified;
    }
    pub fn acceptTyping(self: *Controller) !void {
        if (!self.running_verified) return error.RunningIdentityNotVerified;
        const path = try self.gpa.dupe(u8, self.artifact_path.?);
        if (self.rollback_path) |old| self.gpa.free(old);
        self.rollback_path = path;
        self.typing_verified = true;
    }
    pub fn expectedIdentity(self: *const Controller) ?@import("device-protocol").Identity {
        return if (self.transferred) self.expected else null;
    }
    pub fn observeRunning(self: *Controller, identity: ?@import("device-protocol").Identity, coherent: bool, now: u64) void {
        if (!self.transferred or self.running_verified) return;
        if (self.reconnect_deadline == 0) {
            self.reconnect_deadline = now +| 10_000;
            self.state = .awaiting_reconnect;
        }
        if (coherent) if (identity) |running| {
            self.verifyRunning(running) catch |err| {
                self.diagnostic.clearRetainingCapacity();
                self.diagnostic.appendSlice(self.gpa, @errorName(err)) catch {};
            };
        };
        if (!self.running_verified and now >= self.reconnect_deadline) self.state = .reconnect_timeout;
    }
};

test "firmware startup cancellation and unconfirmed flashing remain hardware free" {
    var controller = try Controller.init(std.testing.allocator, std.testing.io, "/unused repository");
    defer controller.deinit();
    try std.testing.expect(controller.job == null and controller.manifest == null);
    try std.testing.expectError(error.FlashConfirmationRequired, controller.flash(@splat(0), "/Volumes/RPI-RP2", false));
    try std.testing.expectError(error.NoCurrentArtifact, controller.flash(@splat(0), "/Volumes/RPI-RP2", true));
    controller.state = .building;
    controller.cancel();
    try std.testing.expectEqual(State.cancelled, controller.state);
    try std.testing.expect(controller.artifact_path == null and !controller.transferred);
}
test "automatic recovery uses flasher discovery and manual overrides stay literal" {
    try std.testing.expectEqualStrings("RPI-RP2", try recoveryTarget(""));
    try std.testing.expectEqualStrings("/Volumes/RPI-RP2 1", try recoveryTarget("/Volumes/RPI-RP2 1"));
    try std.testing.expectError(error.AbsoluteRecoveryVolumeRequired, recoveryTarget("../other"));
    try std.testing.expectError(error.AbsoluteRecoveryVolumeRequired, recoveryTarget("/Volumes/RPI-RP2\x00other"));
}
test "cached flasher executable is absolute and exists outside build working directory" {
    const executable = try flasherExecutable(std.testing.allocator);
    defer std.testing.allocator.free(executable);
    try std.testing.expect(std.fs.path.isAbsolute(executable));
    const file = try std.Io.Dir.cwd().openFile(std.testing.io, executable, .{});
    file.close(std.testing.io);
}

test "settled layout change builds frozen LK7 UF2 and rejects later edits without flashing" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const root = try std.Io.Dir.cwd().realPathFileAlloc(io, "..", gpa);
    defer gpa.free(root);
    var model = try @import("model.zig").Model.init(gpa, .eurkey);
    defer model.deinit();
    var controller = try Controller.init(gpa, io, root);
    defer controller.deinit();
    var scheduler = @import("auto_build.zig").Scheduler{};
    scheduler.observe(try model.id(), 0);
    try model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 20 } } });
    const current = try model.id();
    scheduler.observe(current, 1);
    try std.testing.expect(!scheduler.take(750, false));
    try std.testing.expect(scheduler.take(751, false));
    try controller.build(model.current.snapshot);
    var flash_gate = @import("pending_flash.zig").Gate{};
    flash_gate.request(current, false);
    try std.testing.expect(!flash_gate.take(current, controller.state == .built, false));
    const deadline = std.Io.Clock.awake.now(io).toMilliseconds() + 120_000;
    while (controller.state == .building) {
        controller.poll(current);
        if (std.Io.Clock.awake.now(io).toMilliseconds() > deadline) return error.FirmwareBuildTestTimeout;
        try std.Io.sleep(io, .fromMilliseconds(5), .awake);
    }
    if (controller.state != .built) std.debug.print("Firmware build diagnostic: {s}\n", .{controller.diagnostic.items});
    try std.testing.expectEqual(State.built, controller.state);
    try std.testing.expect(flash_gate.take(current, controller.state == .built, false));
    try std.testing.expect(!flash_gate.take(current, true, false));
    try std.testing.expect(controller.manifest != null and !controller.transferred);
    try std.testing.expect(controller.expectedIdentity() == null);
    try std.testing.expectError(error.AbsoluteRecoveryVolumeRequired, controller.flash(current, "RPI-RP2", true));
    // Fake transfer completion tests the pure reconnect boundary, without a device.
    controller.transferred = true;
    var wrong = controller.expected.?;
    wrong.digest[0] ^= 1;
    controller.observeRunning(wrong, true, 1);
    try std.testing.expect(!controller.running_verified);
    controller.observeRunning(null, false, 10_001);
    try std.testing.expectEqual(State.reconnect_timeout, controller.state);
    controller.observeRunning(controller.expected.?, true, 10_002);
    try std.testing.expectEqual(State.verified, controller.state);
    try std.testing.expect(controller.rollback_path != null and !controller.typing_verified);
    controller.transferred = false;
    try model.apply(.none);
    controller.poll(try model.id());
    try std.testing.expectEqual(State.stale, controller.state);
    try std.testing.expect(controller.manifest == null and controller.artifact_path == null);
    try std.testing.expectError(error.NoCurrentArtifact, controller.flash(try model.id(), "/unused/fake", true));
}
