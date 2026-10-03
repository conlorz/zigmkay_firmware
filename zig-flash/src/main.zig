const std = @import("std");
const builtin = @import("builtin");

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
pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--help")) {
        std.debug.print("Usage: zig_flash <firmware.uf2> [absolute mount path or volume label]\nDefault label: RPI-RP2. Windows requires an absolute mount path.\n", .{});
        return;
    }
    // No implicit input: running the binary without arguments cannot start waiting for hardware.
    if (args.len < 2 or args.len > 3) return error.Usage;
    const source = args[1];
    try std.Io.Dir.cwd().access(init.io, source, .{});
    const mount = if (args.len == 3) args[2] else "RPI-RP2";
    const path = if (std.fs.path.isAbsolute(mount)) mount else try mountedPath(gpa, builtin.os.tag, init.environ_map.get("USER"), mount);
    std.log.info("Waiting for volume at {s}", .{path});
    try waitForDrive(init.io, path);
    try std.Io.sleep(init.io, .fromMilliseconds(500), .awake);
    const destination = try std.fs.path.join(gpa, &.{ path, "firmware.uf2" });
    try std.Io.Dir.cwd().copyFile(source, std.Io.Dir.cwd(), destination, init.io, .{});
    std.log.info("Firmware copied to {s}", .{destination});
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
