const std = @import("std");
const builtin = @import("builtin");
const uf2 = @import("uf2.zig");
const volume = @import("volume.zig");
const transfer = @import("transfer.zig");
const discovery_ms = 30_000;
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.awake.now(io).toMilliseconds());
}

fn validLabel(label: []const u8) bool {
    if (label.len == 0 or std.mem.eql(u8, label, ".") or std.mem.eql(u8, label, "..")) return false;
    for (label) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' and c != ' ') return false;
    return true;
}
fn mountedPath(gpa: std.mem.Allocator, os: std.Target.Os.Tag, user: ?[]const u8, label: []const u8) ![]u8 {
    if (!validLabel(label)) return error.InvalidVolumeLabel;
    return switch (os) {
        .macos => std.fs.path.join(gpa, &.{ "/Volumes", label }),
        .linux => std.fs.path.join(gpa, &.{ "/run/media", user orelse return error.MissingUser, label }),
        else => error.AbsoluteMountPathRequired,
    };
}
fn waitForDrive(io: std.Io, path: []const u8, deadline: u64) !void {
    while (now(io) < deadline) {
        var dir = std.Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                try std.Io.sleep(io, .fromMilliseconds(200), .awake);
                continue;
            },
            else => return err,
        };
        dir.close(io);
        return;
    }
    return error.DiscoveryTimeout;
}
fn waitForWindowsLabel(gpa: std.mem.Allocator, io: std.Io, label: []const u8, deadline: u64) ![]u8 {
    if (!validLabel(label)) return error.InvalidVolumeLabel;
    const win = struct {
        extern "kernel32" fn GetLogicalDrives() callconv(.winapi) u32;
        extern "kernel32" fn GetVolumeInformationW([*:0]const u16, [*]u16, u32, ?*u32, ?*u32, ?*u32, ?[*]u16, u32) callconv(.winapi) i32;
    };
    while (now(io) < deadline) {
        const drives = win.GetLogicalDrives();
        var selected: ?u8 = null;
        for (0..26) |index| {
            if (drives & (@as(u32, 1) << @intCast(index)) == 0) continue;
            const letter: u8 = 'A' + @as(u8, @intCast(index));
            const root = [_:0]u16{ letter, ':', '\\' };
            var name: [261]u16 = undefined;
            if (win.GetVolumeInformationW(&root, &name, name.len, null, null, null, null, 0) == 0) continue;
            const length = std.mem.indexOfScalar(u16, &name, 0) orelse continue;
            if (length != label.len) continue;
            var matches = true;
            for (label, 0..) |c, i| if (name[i] != c) {
                matches = false;
                break;
            };
            if (matches) {
                if (selected != null) return error.AmbiguousVolumes;
                selected = letter;
            }
        }
        if (selected) |letter| return gpa.dupe(u8, &.{ letter, ':', '\\' });
        try std.Io.sleep(io, .fromMilliseconds(200), .awake);
    }
    return error.DiscoveryTimeout;
}
fn writeFirmware(io: std.Io, contents: []const u8, destination_dir: std.Io.Dir, destination: []const u8) !void {
    // A UF2 volume is a device protocol, not ordinary file storage. Write the
    // final name directly and synchronize it before reporting completion.
    const Native = struct {
        io: std.Io,
        dir: std.Io.Dir,
        name: []const u8,
        output: ?std.Io.File = null,
        pub fn now(self: *@This()) u64 {
            return @intCast(std.Io.Clock.awake.now(self.io).toMilliseconds());
        }
        pub fn open(self: *@This()) !void {
            self.output = try self.dir.createFile(self.io, self.name, .{});
            std.log.info("Destination opened; writing firmware bytes", .{});
        }
        pub fn close(self: *@This()) void {
            self.output.?.close(self.io);
        }
        pub fn checkCancellation(self: *@This()) !void {
            try self.io.checkCancel();
        }
        pub fn write(self: *@This(), bytes: []const u8, offset: usize) !void {
            try self.output.?.writePositionalAll(self.io, bytes, offset);
        }
        pub fn sync(self: *@This()) !void {
            std.log.info("Write complete; synchronizing destination", .{});
            try self.output.?.sync(self.io);
        }
    };
    var backend = Native{ .io = io, .dir = destination_dir, .name = destination };
    var stage: transfer.Stage = .opening;
    transfer.run(Native, &backend, contents, &stage) catch |err| {
        std.log.err("Transfer failed at {s}: {s}; completion is not confirmed", .{ @tagName(stage), @errorName(err) });
        return err;
    };
}
fn writeIdentifiedVolume(io: std.Io, contents: []const u8, dir: std.Io.Dir) !void {
    try volume.validate(io, dir);
    try writeFirmware(io, contents, dir, "firmware.uf2");
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--help")) {
        std.debug.print("Usage: zig_flash <firmware.uf2> [mount or label] [--verify-lk7 <companion binary> | --expected-sha256 <hex>]\nDefault label: RPI-RP2; discovery: 30s.\n", .{});
        return;
    }
    // No implicit input: running the binary without arguments cannot start waiting for hardware.
    if (args.len < 2 or args.len > 5) return error.Usage;
    const verifier: ?[]const u8 = if (args.len == 5 and std.mem.eql(u8, args[3], "--verify-lk7")) args[4] else null;
    const expected_hash: ?[]const u8 = if (args.len == 5 and std.mem.eql(u8, args[3], "--expected-sha256")) args[4] else null;
    if (args.len > 3 and verifier == null and expected_hash == null) return error.Usage;
    if (verifier) |executable| {
        const file = try std.Io.Dir.cwd().openFile(init.io, executable, .{});
        file.close(init.io);
    }
    const source = args[1];
    const contents = try std.Io.Dir.cwd().readFileAlloc(init.io, source, gpa, .limited(32 * 1024 * 1024));
    uf2.validate(gpa, contents) catch |err| {
        std.log.err("Invalid RP2040 UF2: {t}; no device file opened", .{err});
        return err;
    };
    const hash = std.crypto.hash.sha2.Sha256.hash;
    var digest: [32]u8 = undefined;
    hash(contents, &digest, .{});
    if (expected_hash) |expected| try verifyExpectedHash(digest, expected);
    std.log.info("Validated RP2040 artifact: {s}, {d} bytes, sha256={x}", .{ source, contents.len, digest });
    const mount = if (args.len >= 3) args[2] else "RPI-RP2";
    const deadline = now(init.io) +| discovery_ms;
    var path = if (std.fs.path.isAbsolute(mount)) try gpa.dupe(u8, mount) else if (builtin.os.tag == .windows) try waitForWindowsLabel(gpa, init.io, mount, deadline) else try mountedPath(gpa, builtin.os.tag, init.environ_map.get("USER"), mount);
    std.log.info("Discovering intended BOOTSEL volume {s}; deadline {d} ms", .{ mount, discovery_ms });
    if (!std.fs.path.isAbsolute(mount) and builtin.os.tag != .windows) {
        const root = std.fs.path.dirname(path).?;
        while (now(init.io) < deadline) {
            if (try volume.discover(gpa, init.io, root, mount)) |selected| {
                path = selected;
                break;
            }
            try std.Io.sleep(init.io, .fromMilliseconds(200), .awake);
        }
    }
    std.log.info("Waiting for volume at {s}", .{path});
    try waitForDrive(init.io, path, deadline);
    var destination_dir = try std.Io.Dir.cwd().openDir(init.io, path, .{});
    defer destination_dir.close(init.io);
    try volume.validate(init.io, destination_dir);
    std.log.info("Identified RP2040 BOOTSEL volume at {s}; opening firmware.uf2", .{path});
    std.log.warn("Filesystem open/write/sync can block in the kernel. Deadline checks cannot interrupt that call; use Ctrl-C once, then physical BOOTSEL reconnect if it remains stuck. Never start a second writer.", .{});
    // Keep the exact validated input even if another build replaces the source
    // while this command waits for BOOTSEL.
    try writeIdentifiedVolume(init.io, contents, destination_dir);
    std.log.info("Transfer completed and synchronized at {s}; restart is not yet verified", .{path});
    if (verifier) |executable| {
        var child = try std.process.spawn(init.io, .{ .argv = &.{ executable, "--verify-running" } });
        const result = try child.wait(init.io);
        switch (result) {
            .exited => |code| if (code != 0) return error.RunningVerificationFailed,
            else => return error.RunningVerificationFailed,
        }
        std.log.info("Running LK7 identity and coherent snapshot verified; no binary readback was performed", .{});
    }
}

fn verifyExpectedHash(actual: [32]u8, expected: []const u8) !void {
    if (expected.len != 64) return error.InvalidExpectedHash;
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, expected) catch return error.InvalidExpectedHash;
    if (!std.mem.eql(u8, &actual, &bytes)) return error.ArtifactChanged;
}

test "manifest hash guards the exact transfer bytes before discovery" {
    const digest: [32]u8 = @splat(0xa7);
    const expected = std.fmt.bytesToHex(digest, .lower);
    try verifyExpectedHash(digest, &expected);
    try std.testing.expectError(error.ArtifactChanged, verifyExpectedHash(@splat(0), &expected));
    try std.testing.expectError(error.InvalidExpectedHash, verifyExpectedHash(digest, "not a hash"));
}
test "direct firmware write replaces longer files and preserves all chunks" {
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const bytes: [9217]u8 = @splat(0xa7);
    try temp.dir.writeFile(io, .{ .sub_path = "firmware.uf2", .data = &(@as([10000]u8, @splat(0))) });
    try writeFirmware(io, &bytes, temp.dir, "firmware.uf2");
    const actual = try temp.dir.readFileAlloc(io, "firmware.uf2", std.testing.allocator, .limited(10000));
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, &bytes, actual);
}
test "volume labels cannot escape mount roots" {
    for ([_][]const u8{ "", ".", "..", "../RPI-RP2", "x/y", "x\\y", "a'b" }) |label| try std.testing.expectError(error.InvalidVolumeLabel, mountedPath(std.testing.allocator, .macos, null, label));
    const mac = try mountedPath(std.testing.allocator, .macos, null, "RPI-RP2");
    defer std.testing.allocator.free(mac);
    try std.testing.expectEqualStrings("/Volumes/RPI-RP2", mac);
    const linux = try mountedPath(std.testing.allocator, .linux, "alice", "RPI-RP2");
    defer std.testing.allocator.free(linux);
    try std.testing.expectEqualStrings("/run/media/alice/RPI-RP2", linux);
    try std.testing.expectError(error.MissingUser, mountedPath(std.testing.allocator, .linux, null, "RPI-RP2"));
    try std.testing.expectError(error.AbsoluteMountPathRequired, mountedPath(std.testing.allocator, .windows, null, "RPI-RP2"));
}

test "wrong and missing boot identity never create destination; source snapshot survives replacement" {
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const original: [9217]u8 = @splat(0xa7);
    try std.testing.expectError(error.FileNotFound, writeIdentifiedVolume(io, &original, temp.dir));
    try temp.dir.writeFile(io, .{ .sub_path = "INFO_UF2.TXT", .data = "UF2 Bootloader v3.0\nModel: Other\nBoard-ID: RPI-RP2\n" });
    try std.testing.expectError(error.UnexpectedBootloader, writeIdentifiedVolume(io, &original, temp.dir));
    try std.testing.expectError(error.FileNotFound, temp.dir.openFile(io, "firmware.uf2", .{}));
    try temp.dir.writeFile(io, .{ .sub_path = "source.uf2", .data = &original });
    const snapshot = try temp.dir.readFileAlloc(io, "source.uf2", std.testing.allocator, .limited(10000));
    defer std.testing.allocator.free(snapshot);
    try temp.dir.writeFile(io, .{ .sub_path = "source.uf2", .data = "changed during discovery" });
    try temp.dir.writeFile(io, .{ .sub_path = "INFO_UF2.TXT", .data = "UF2 Bootloader v3.0\nModel: Raspberry Pi RP2\nBoard-ID: RPI-RP2\n" });
    try writeIdentifiedVolume(io, snapshot, temp.dir);
    const result = try temp.dir.readFileAlloc(io, "firmware.uf2", std.testing.allocator, .limited(10000));
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, &original, result);
}
