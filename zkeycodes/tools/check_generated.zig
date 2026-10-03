const std = @import("std");
const log = if (@import("builtin").is_test) struct {
    fn err(comptime _: []const u8, _: anytype) void {}
} else std.log;

fn check(gpa: std.mem.Allocator, io: std.Io, directory: []const u8, pairs: []const []const u8) !void {
    if (pairs.len % 2 != 0) return error.ExpectedNamePathPairs;
    var dir = try std.Io.Dir.cwd().openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        var found = false;
        var i: usize = 0;
        while (i < pairs.len) : (i += 2) if (std.mem.eql(u8, entry.name, pairs[i])) {
            found = true;
            break;
        };
        if (!found) {
            log.err("extra generated file: {s}", .{entry.name});
            return error.ExtraGeneratedFile;
        }
    }
    var i: usize = 0;
    while (i < pairs.len) : (i += 2) {
        const actual = dir.readFileAlloc(io, pairs[i], gpa, .limited(16 * 1024 * 1024)) catch {
            log.err("missing generated file: {s}", .{pairs[i]});
            return error.MissingGeneratedFile;
        };
        defer gpa.free(actual);
        const expected = try std.Io.Dir.cwd().readFileAlloc(io, pairs[i + 1], gpa, .limited(16 * 1024 * 1024));
        defer gpa.free(expected);
        if (!std.mem.eql(u8, actual, expected)) {
            log.err("stale generated file: {s}; run zig build convert-all explicitly", .{pairs[i]});
            return error.StaleGeneratedFile;
        }
    }
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) return error.Usage;
    try check(init.arena.allocator(), init.io, args[1], args[2..]);
}
test "generated checks include export index and preserve sources on failure" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(root);
    try tmp.dir.createDir(std.testing.io, "committed", .default_dir);
    const dir = try std.fs.path.join(std.testing.allocator, &.{ root, "committed" });
    defer std.testing.allocator.free(dir);
    const cache = try std.fs.path.join(std.testing.allocator, &.{ root, "cache" });
    defer std.testing.allocator.free(cache);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "cache", .data = "expected" });
    // Diagnostics are expected in this test; avoid treating them as test failures.
    try std.testing.expectError(error.MissingGeneratedFile, check(std.testing.allocator, std.testing.io, dir, &.{ "all.zig", cache }));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "committed/all.zig", .data = "expected" });
    try check(std.testing.allocator, std.testing.io, dir, &.{ "all.zig", cache });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "committed/all.zig", .data = "stale" });
    try std.testing.expectError(error.StaleGeneratedFile, check(std.testing.allocator, std.testing.io, dir, &.{ "all.zig", cache }));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "committed/extra.zig", .data = "extra" });
    try std.testing.expectError(error.ExtraGeneratedFile, check(std.testing.allocator, std.testing.io, dir, &.{ "all.zig", cache }));
}
