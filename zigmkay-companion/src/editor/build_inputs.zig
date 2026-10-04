//! Fingerprint first-party compiler inputs and immutable dependency manifests.
const std = @import("std");
pub fn digest(gpa: std.mem.Allocator, io: std.Io, root: []const u8) ![32]u8 {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var files: std.ArrayList([]const u8) = .empty;
    for ([_][]const u8{ "apps/keymap-test", "zigmkay", "layout-model", "zkeycodes", "device-protocol", "keymap-project", "companion-jobs" }) |package| {
        const path = try std.fs.path.join(a, &.{ root, package });
        var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
        defer dir.close(io);
        var walker = try dir.walk(a);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind == .directory and (std.mem.startsWith(u8, entry.basename, ".") or std.mem.eql(u8, entry.basename, "zig-pkg") or std.mem.eql(u8, entry.basename, "zig-out"))) {
                walker.leave(io);
                continue;
            }
            if (entry.kind == .file and (std.mem.endsWith(u8, entry.basename, ".zig") or std.mem.endsWith(u8, entry.basename, ".zon"))) try files.append(a, try std.fs.path.join(a, &.{ package, entry.path }));
            if (files.items.len > 2048) return error.BuildInputLimit;
        }
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn less(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.order(u8, lhs, rhs) == .lt;
        }
    }.less);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var total: usize = 0;
    for (files.items) |file| {
        const path = try std.fs.path.join(a, &.{ root, file });
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(1024 * 1024));
        total += bytes.len;
        if (total > 16 * 1024 * 1024) return error.BuildInputLimit;
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, file.len, .little);
        hash.update(&length);
        hash.update(file);
        std.mem.writeInt(u64, &length, bytes.len, .little);
        hash.update(&length);
        hash.update(bytes);
    }
    return hash.finalResult();
}
