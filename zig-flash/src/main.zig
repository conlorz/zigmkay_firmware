const std = @import("std");
const builtin = @import("builtin");
const uf2 = @import("uf2.zig");

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
fn waitForDrive(io: std.Io, path: []const u8) !void {
    while (true) {
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
}
fn waitForWindowsLabel(gpa: std.mem.Allocator, io: std.Io, label: []const u8) ![]u8 {
    if (!validLabel(label)) return error.InvalidVolumeLabel;
    const win = struct {
        extern "kernel32" fn GetLogicalDrives() callconv(.winapi) u32;
        extern "kernel32" fn GetVolumeInformationW([*:0]const u16, [*]u16, u32, ?*u32, ?*u32, ?*u32, ?[*]u16, u32) callconv(.winapi) i32;
    };
    while (true) {
        const drives = win.GetLogicalDrives();
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
            if (matches) return gpa.dupe(u8, &.{ letter, ':', '\\' });
        }
        try std.Io.sleep(io, .fromMilliseconds(200), .awake);
    }
}
fn writeFirmware(io: std.Io, contents: []const u8, destination_dir: std.Io.Dir, destination: []const u8) !void {
    // A UF2 volume is a device protocol, not ordinary file storage. Write the
    // final name directly and synchronize it before reporting completion.
    const output = try destination_dir.createFile(io, destination, .{});
    defer output.close(io);
    std.log.info("Destination opened; writing firmware bytes", .{});
    var offset: usize = 0;
    while (offset < contents.len) {
        const count = @min(4096, contents.len - offset);
        try output.writePositionalAll(io, contents[offset..][0..count], offset);
        offset += count;
    }
    std.log.info("Write complete; synchronizing destination", .{});
    try output.sync(io);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--help")) {
        std.debug.print("Usage: zig_flash <firmware.uf2> [absolute mount path or volume label]\nDefault label: RPI-RP2.\n", .{});
        return;
    }
    // No implicit input: running the binary without arguments cannot start waiting for hardware.
    if (args.len < 2 or args.len > 3) return error.Usage;
    const source = args[1];
    const contents = try std.Io.Dir.cwd().readFileAlloc(init.io, source, gpa, .limited(32 * 1024 * 1024));
    uf2.validate(gpa, contents) catch |err| {
        std.log.err("Invalid RP2040 UF2: {t}; no device file opened", .{err});
        return err;
    };
    const mount = if (args.len == 3) args[2] else "RPI-RP2";
    const path = if (std.fs.path.isAbsolute(mount)) mount else if (builtin.os.tag == .windows) try waitForWindowsLabel(gpa, init.io, mount) else try mountedPath(gpa, builtin.os.tag, init.environ_map.get("USER"), mount);
    std.log.info("Waiting for volume at {s}", .{path});
    try waitForDrive(init.io, path);
    std.log.info("Volume found; opening firmware.uf2 for writing", .{});
    try std.Io.sleep(init.io, .fromMilliseconds(500), .awake);
    const destination = try std.fs.path.join(gpa, &.{ path, "firmware.uf2" });
    // Keep the exact validated input even if another build replaces the source
    // while this command waits for BOOTSEL.
    try writeFirmware(init.io, contents, std.Io.Dir.cwd(), destination);
    std.log.info("Firmware written and synchronized to {s}", .{destination});
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
