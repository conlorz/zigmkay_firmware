//! Explicit native draft testing. Preparation uses argv, immutable exports and
//! bounded jobs. Input runs in a serialized worker so hung callbacks cannot stall UI.
const std = @import("std");
const p = @import("keymap-project");
const jobs = @import("companion-jobs");
const wire = @import("runner-protocol");

fn inspectorTrace(controller: *Controller, id: [32]u8, command: wire.Command, time: u64, expected: []const @import("zigmkay").core.OutputCommand) !void {
    const sequence = controller.sequence + 1;
    try controller.input(command, time);
    const deadline = std.Io.Clock.awake.now(controller.io).toMilliseconds() + 10_000;
    while (true) {
        controller.poll(id);
        if (controller.state != .running) return error.InspectorRunnerStopped;
        if (controller.last) |output| if (output.sequence == sequence) {
            try std.testing.expectEqualDeep(expected, output.commands);
            return;
        };
        if (std.Io.Clock.awake.now(controller.io).toMilliseconds() > deadline) return error.InspectorTraceTimeout;
        try std.Io.sleep(controller.io, .fromMilliseconds(1), .awake);
    }
}

test "inspector clearing and inheritance produce real processor traces" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const root = try std.Io.Dir.cwd().realPathFileAlloc(io, "..", gpa);
    defer gpa.free(root);
    const editing = @import("session.zig");
    for (0..4) |case| {
        var model = try @import("model.zig").Model.init(gpa, .eurkey);
        defer model.deinit();
        // An explicit held layer makes fallback independent of the built-in profile.
        model.select(31, false);
        try model.apply(.{ .hold_only = .{ .layer_id = model.document().layers[1].id } });
        model.select(10, false);
        try model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } });
        model.layer = 1;
        try model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 5 } }, .hold = .{ .hold_modifiers = .{ .left_gui = true } }, .tapping_term = .{ .ms = 180 } } });
        var session = try editing.Session.init(&model);
        session.mutate(switch (case) {
            0 => .unassign,
            1 => .inherit,
            2 => .clear_hold,
            else => .clear_tap,
        });
        try std.testing.expect(try session.apply(&model));
        const id = try model.id();
        var controller = try Controller.init(gpa, io, root);
        defer controller.deinit();
        try controller.prepare(model.current.snapshot);
        const deadline = std.Io.Clock.awake.now(io).toMilliseconds() + 60_000;
        while (controller.state == .preparing) {
            controller.poll(id);
            if (std.Io.Clock.awake.now(io).toMilliseconds() > deadline) return error.InspectorPreparationTimeout;
            try std.Io.sleep(io, .fromMilliseconds(5), .awake);
        }
        try std.testing.expectEqual(State.prepared, controller.state);
        try controller.start();
        try inspectorTrace(&controller, id, .{ .key_down = 31 }, 1000, &.{});
        const down: []const @import("zigmkay").core.OutputCommand = switch (case) {
            0 => &.{},
            1 => &.{.{ .KeyCodePress = 4 }},
            2 => &.{.{ .KeyCodePress = 5 }},
            else => &.{.{ .ModifiersChanged = .{ .left_gui = true } }},
        };
        const up: []const @import("zigmkay").core.OutputCommand = switch (case) {
            0 => &.{},
            1 => &.{.{ .KeyCodeRelease = 4 }},
            2 => &.{.{ .KeyCodeRelease = 5 }},
            else => &.{.{ .ModifiersChanged = .{} }},
        };
        try inspectorTrace(&controller, id, .{ .key_down = 10 }, 2000, down);
        try inspectorTrace(&controller, id, .{ .key_up = 10 }, 3000, up);
        try inspectorTrace(&controller, id, .{ .key_up = 31 }, 4000, &.{});
    }
}
pub const State = enum { idle, preparing, prepared, running, stale, failed };
pub const Controller = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    state: State = .idle,
    snapshot_id: [32]u8 = @splat(0),
    job: ?*jobs.Job = null,
    session: *jobs.Session,
    executable: ?[]const u8 = null,
    sequence: u64 = 0,
    time_us: u64 = 0,
    pressed: [34]bool = @splat(false),
    queue: std.ArrayList(wire.Input) = .empty,
    request: ?std.Io.Future(anyerror![]u8) = null,
    request_done: std.atomic.Value(bool) = .init(false),
    request_frame: ?[]u8 = null,
    expected_reply: u64 = 0,
    diagnostic: std.ArrayList(u8) = .empty,
    last: ?wire.Output = null,
    elapsed_ns: i96 = 0,
    build_inputs: [32]u8 = @splat(0),
    pub fn init(gpa: std.mem.Allocator, io: std.Io, root: []const u8) !Controller {
        const session = try gpa.create(jobs.Session);
        session.* = .{};
        errdefer gpa.destroy(session);
        return .{ .gpa = gpa, .io = io, .root = try gpa.dupe(u8, root), .session = session };
    }
    pub fn deinit(self: *Controller) void {
        self.stop();
        self.gpa.destroy(self.session);
        self.gpa.free(self.root);
        if (self.executable) |path| self.gpa.free(path);
        self.queue.deinit(self.gpa);
        self.diagnostic.deinit(self.gpa);
        if (self.last) |output| std.zon.parse.free(self.gpa, output);
    }
    pub fn stop(self: *Controller) void {
        if (self.job) |job| {
            job.deinit();
            self.gpa.destroy(job);
            self.job = null;
        }
        if (self.request) |*future| {
            if (future.cancel(self.io)) |bytes| self.gpa.free(bytes) else |_| {}
            self.request = null;
        }
        if (self.request_frame) |frame| self.gpa.free(frame);
        self.request_frame = null;
        self.session.stop(self.io);
        self.pressed = @splat(false);
        self.queue.clearRetainingCapacity();
        if (self.state == .running) self.state = .prepared else if (self.state == .preparing) self.state = .idle;
    }
    pub fn invalidate(self: *Controller, current: [32]u8) void {
        if (self.state == .idle or self.state == .failed or std.mem.eql(u8, &current, &self.snapshot_id)) return;
        self.stop();
        self.state = .stale;
    }
    fn fail(self: *Controller, err: anyerror) void {
        self.stop();
        self.state = .failed;
        self.diagnostic.clearRetainingCapacity();
        self.diagnostic.appendSlice(self.gpa, @errorName(err)) catch {};
    }
    pub fn prepare(self: *Controller, snapshot: p.snapshot.Snapshot) !void {
        self.stop();
        self.snapshot_id = try p.snapshot.projectDigest(self.gpa, snapshot, p.profiles.board);
        self.build_inputs = try @import("build_inputs.zig").digest(self.gpa, self.io, self.root);
        const artifact = jobs.artifactKey(.{ .snapshot_id = self.snapshot_id, .build_inputs_digest = self.build_inputs, .zig_version = @import("builtin").zig_version_string, .target = @tagName(@import("builtin").cpu.arch) ++ "-" ++ @tagName(@import("builtin").os.tag), .optimize = "Debug" });
        const digest = std.fmt.bytesToHex(artifact, .lower);
        const directory = try std.fs.path.join(self.gpa, &.{ self.root, ".zig-cache", "editor-tests", &digest });
        defer self.gpa.free(directory);
        const exported = try std.fs.path.join(self.gpa, &.{ directory, "profile" });
        defer self.gpa.free(exported);
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, exported, .{});
        defer dir.close(self.io);
        const manifest = try p.exporter.write(self.gpa, self.io, dir, snapshot, p.profiles.board);
        defer std.zon.parse.free(self.gpa, manifest);
        const prefix = try std.fs.path.join(self.gpa, &.{ directory, "native" });
        defer self.gpa.free(prefix);
        if (self.executable) |path| self.gpa.free(path);
        self.executable = try std.fs.path.join(self.gpa, &.{ prefix, "bin", "keymap-test" });
        const profile_arg = try std.fmt.allocPrint(self.gpa, "-Dprofile={s}", .{exported});
        defer self.gpa.free(profile_arg);
        const cwd = try std.fs.path.join(self.gpa, &.{ self.root, "apps", "keymap-test" });
        defer self.gpa.free(cwd);
        // The caller launches the app through mise; child inherits pinned Zig PATH.
        const job = try self.gpa.create(jobs.Job);
        errdefer self.gpa.destroy(job);
        job.* = try jobs.Job.init(self.gpa, self.io, .{ .argv = &.{ @import("editor-toolchain").zig_exe, "build", "-j4", profile_arg, "-p", prefix }, .cwd = cwd, .snapshot_id = self.snapshot_id, .timeout_ms = 60_000 });
        errdefer job.deinit();
        try job.start();
        self.job = job;
        self.state = .preparing;
    }
    fn exchange(self: *Controller) anyerror![]u8 {
        defer self.request_done.store(true, .release);
        return self.session.request(self.gpa, self.io, self.request_frame, 2000);
    }
    fn beginRequest(self: *Controller, message: ?wire.Input) !void {
        if (self.request != null) return error.RequestBusy;
        self.expected_reply = if (message) |value| value.sequence else 0;
        if (message) |value| {
            var writer: std.Io.Writer.Allocating = .init(self.gpa);
            defer writer.deinit();
            try std.zon.stringify.serializeMaxDepth(value, .{ .whitespace = false }, &writer.writer, 16);
            self.request_frame = try writer.toOwnedSlice();
        }
        self.request_done.store(false, .release);
        self.request = try std.Io.concurrent(self.io, exchange, .{self});
    }
    pub fn start(self: *Controller) !void {
        if (self.state != .prepared) return error.TestNotPrepared;
        const current_inputs = try @import("build_inputs.zig").digest(self.gpa, self.io, self.root);
        if (!std.mem.eql(u8, &current_inputs, &self.build_inputs)) {
            self.state = .stale;
            return error.BuildInputsChanged;
        }
        try self.session.start(self.io, &.{self.executable.?});
        if (self.last) |output| std.zon.parse.free(self.gpa, output);
        self.last = null;
        self.sequence = 0;
        self.time_us = 0;
        self.state = .running;
        try self.beginRequest(null);
    }
    pub fn input(self: *Controller, command: wire.Command, time_us: u64) !void {
        if (self.state != .running) return error.TestNotRunning;
        if (self.queue.items.len >= 128) return error.InputQueueFull;
        if (time_us < self.time_us) return error.BackwardsTime;
        switch (command) {
            .key_down => |index| {
                if (index >= 34 or self.pressed[index]) return error.InvalidKeyDown;
                self.pressed[index] = true;
            },
            .key_up => |index| {
                if (index >= 34 or !self.pressed[index]) return error.InvalidKeyUp;
                self.pressed[index] = false;
            },
            else => {},
        }
        self.sequence += 1;
        self.time_us = time_us;
        try self.queue.append(self.gpa, .{ .sequence = self.sequence, .time_us = time_us, .command = command });
    }
    /// Called on UI thread. Every response must retain frozen project identity.
    pub fn poll(self: *Controller, current: [32]u8) void {
        self.invalidate(current);
        if (self.job) |job| if (job.poll()) |status| {
            self.job = null;
            defer {
                job.deinit();
                self.gpa.destroy(job);
            }
            if (status) |result_value| {
                var result = result_value;
                defer result.deinit(self.gpa);
                self.elapsed_ns = result.elapsed_ns;
                self.diagnostic.clearRetainingCapacity();
                self.diagnostic.appendSlice(self.gpa, result.process.stderr) catch {};
                self.state = if (!result.fresh(current)) .stale else if (result.successful()) .prepared else .failed;
            } else |err| self.fail(err);
        };
        if (self.request != null and self.request_done.load(.acquire)) {
            const status = self.request.?.await(self.io);
            self.request = null;
            if (self.request_frame) |frame| self.gpa.free(frame);
            self.request_frame = null;
            if (status) |bytes| {
                defer self.gpa.free(bytes);
                const terminated = self.gpa.dupeZ(u8, bytes) catch |err| {
                    self.fail(err);
                    return;
                };
                defer self.gpa.free(terminated);
                var diagnostics: std.zon.parse.Diagnostics = .{};
                defer diagnostics.deinit(self.gpa);
                const output = std.zon.parse.fromSliceAlloc(wire.Output, self.gpa, terminated, &diagnostics, .{}) catch |err| {
                    self.fail(err);
                    return;
                };
                if (output.version != wire.version or output.sequence != self.expected_reply or !std.mem.eql(u8, &output.snapshot_id, &self.snapshot_id) or output.state == .failed or output.state == .restart_required) {
                    std.zon.parse.free(self.gpa, output);
                    self.fail(error.InvalidRunnerResponse);
                    return;
                }
                if (self.last) |old| std.zon.parse.free(self.gpa, old);
                self.last = output;
            } else |err| {
                self.fail(err);
                return;
            }
        }
        if (self.state == .running and self.request == null and self.queue.items.len > 0) {
            const next = self.queue.orderedRemove(0);
            self.beginRequest(next) catch |err| self.fail(err);
        }
    }
};

test "editor preparation, literal runner output, restart, crash, cancellation and stale snapshots" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const root = try std.Io.Dir.cwd().realPathFileAlloc(io, "..", gpa);
    defer gpa.free(root);
    var model = try @import("model.zig").Model.init(gpa, .eurkey);
    defer model.deinit();
    const frozen = try model.id();
    var controller = try Controller.init(gpa, io, root);
    defer controller.deinit();
    try controller.prepare(model.current.snapshot);
    const deadline = std.Io.Clock.awake.now(io).toMilliseconds() + 60_000;
    while (controller.state == .preparing) {
        controller.poll(frozen);
        if (std.Io.Clock.awake.now(io).toMilliseconds() > deadline) return error.PreparationTestTimeout;
        try std.Io.sleep(io, .fromMilliseconds(5), .awake);
    }
    try std.testing.expectEqual(State.prepared, controller.state);
    try controller.start();
    try controller.input(.{ .key_down = 10 }, 1000);
    var pressed = false;
    while (controller.state == .running and !pressed) {
        controller.poll(frozen);
        if (controller.last) |output| if (output.sequence == 1) {
            try std.testing.expectEqualDeep(@as([]const @import("zigmkay").core.OutputCommand, &.{.{ .KeyCodePress = 4 }}), output.commands);
            var practice: @import("practice.zig").Session = .{};
            try practice.load("a", .draft);
            var text = @import("text.zig").Text.init(true);
            defer text.deinit();
            try text.practiceOutput(output.commands, &practice, 1000);
            try std.testing.expectEqual(@import("practice.zig").State.complete, practice.state);
            try std.testing.expectEqual(@as(usize, 1), practice.attempts);
            try std.testing.expectEqual(frozen, try model.id());
            pressed = true;
        };
        if (std.Io.Clock.awake.now(io).toMilliseconds() > deadline) return error.InputTestTimeout;
        try std.Io.sleep(io, .fromMilliseconds(1), .awake);
    }
    try std.testing.expect(pressed);
    controller.stop();
    try std.testing.expectEqual(State.prepared, controller.state);
    try std.testing.expect(!controller.pressed[10]);
    try controller.start();
    try std.testing.expect(controller.last == null);
    // A crashed process must terminate the outstanding read and remain contained.
    controller.session.child.?.kill(io);
    controller.session.child = null;
    while (controller.state == .running) {
        controller.poll(frozen);
        if (std.Io.Clock.awake.now(io).toMilliseconds() > deadline) return error.CrashTestTimeout;
        try std.Io.sleep(io, .fromMilliseconds(1), .awake);
    }
    try std.testing.expectEqual(State.failed, controller.state);
    try controller.prepare(model.current.snapshot);
    controller.stop();
    try std.testing.expectEqual(State.idle, controller.state);
    try controller.prepare(model.current.snapshot);
    try model.apply(.none);
    controller.poll(try model.id());
    try std.testing.expectEqual(State.stale, controller.state);
    try std.testing.expect(controller.job == null and controller.session.child == null);
}
