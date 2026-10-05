const std = @import("std");
const source_files = @import("source-files");
const File = struct { path: []const u8, hash: [32]u8 };
fn less(_: void, a: File, b: File) bool {
    return std.mem.order(u8, a.path, b.path) == .lt;
}
fn excluded(path: []const u8, name: []const u8, _: std.Io.File.Kind) bool {
    for ([_][]const u8{ ".git", ".zig-cache", "zig-out", "zig-pkg" }) |cache| if (std.mem.eql(u8, name, cache)) return true;
    return std.mem.eql(u8, path, "docs/evidence") or std.mem.eql(u8, path, ".slim/deepwork");
}
pub fn snapshot(gpa: std.mem.Allocator, io: std.Io, root: std.Io.Dir) ![32]u8 {
    var files: std.ArrayList(File) = .empty;
    defer {
        for (files.items) |f| gpa.free(f.path);
        files.deinit(gpa);
    }
    const entries = try source_files.collect(gpa, io, root, .{ .excluded = excluded });
    defer source_files.free(gpa, entries);
    for (entries) |entry| {
        var hash: [32]u8 = undefined;
        if (entry.kind == .sym_link) {
            var buffer: [4096]u8 = undefined;
            const len = try root.readLink(io, entry.path, &buffer);
            var h = std.crypto.hash.sha2.Sha256.init(.{});
            h.update("symlink:");
            h.update(buffer[0..len]);
            h.final(&hash);
        } else {
            const bytes = try root.readFileAlloc(io, entry.path, gpa, .unlimited);
            defer gpa.free(bytes);
            std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
        }
        try files.append(gpa, .{ .path = try gpa.dupe(u8, entry.path), .hash = hash });
    }
    std.mem.sort(File, files.items, {}, less);
    var total = std.crypto.hash.sha2.Sha256.init(.{});
    for (files.items) |f| {
        total.update(f.path);
        total.update(&.{0});
        total.update(&f.hash);
    }
    return total.finalResult();
}
pub fn verifyVersion(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, std.mem.trim(u8, expected, " \r\n"), std.mem.trim(u8, actual, " \r\n"))) return error.CompilerVersionMismatch;
}
test "inventory detects ignored additions deletions and edits while excluding explicit outputs" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = ".gitignore", .data = "ignored.zig\n" });
    const before = try snapshot(gpa, io, tmp.dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "ignored.zig", .data = "new" });
    try std.testing.expect(!std.mem.eql(u8, &before, &(try snapshot(gpa, io, tmp.dir))));
    try tmp.dir.deleteFile(io, "ignored.zig");
    try std.testing.expectEqual(before, try snapshot(gpa, io, tmp.dir));
    for ([_][]const u8{ ".zig-cache", "zig-out", "zig-pkg", "docs/evidence" }) |name| {
        try tmp.dir.createDirPath(io, name);
        const path = try std.fs.path.join(gpa, &.{ name, "output" });
        defer gpa.free(path);
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "cached" });
    }
    try std.testing.expectEqual(before, try snapshot(gpa, io, tmp.dir));
    try tmp.dir.writeFile(io, .{ .sub_path = ".gitignore", .data = "changed" });
    try std.testing.expect(!std.mem.eql(u8, &before, &(try snapshot(gpa, io, tmp.dir))));
}
test "compiler pin rejects the old compiler" {
    try verifyVersion("0.16.0\n", "0.16.0\n");
    try std.testing.expectError(error.CompilerVersionMismatch, verifyVersion("0.16.0", "0.15.2"));
}
