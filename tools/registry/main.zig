const std = @import("std");
const Entry = struct { name: []const u8, source: []const u8, split: bool, encoder: bool, companion: bool };

fn validate(entries: []const Entry) !void {
    if (entries.len == 0) return error.EmptyCatalog;
    for (entries, 0..) |entry, i| {
        if (entry.name.len == 0 or !std.ascii.isLower(entry.name[0])) return error.InvalidName;
        for (entry.name) |c| if (!std.ascii.isLower(c) and !std.ascii.isDigit(c) and c != '_') return error.InvalidName;
        for (entries[0..i]) |other| if (std.mem.eql(u8, entry.name, other.name)) return error.DuplicateName;
        if (!std.mem.endsWith(u8, entry.source, ".zig")) return error.InvalidPath;
        for (entry.source) |c| if (!std.ascii.isAlphanumeric(c) and std.mem.indexOfScalar(u8, "/.-_", c) == null) return error.InvalidPath;
        var parts = std.mem.splitScalar(u8, entry.source, '/');
        while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return error.InvalidPath;
    }
}
fn less(_: void, a: Entry, b: Entry) bool {
    return std.mem.order(u8, a.name, b.name) == .lt;
}
fn render(gpa: std.mem.Allocator, entries: []Entry) ![]u8 {
    std.mem.sort(Entry, entries, {}, less);
    var w = std.Io.Writer.Allocating.init(gpa);
    defer w.deinit();
    try w.writer.writeAll("// Generated from boards.zon by tools/registry/main.zig. Do not edit.\npub const Entry = struct {\n    name: []const u8,\n    source: []const u8,\n    split: bool,\n    encoder: bool,\n    companion: bool,\n};\n\npub const entries = [_]Entry{\n");
    for (entries) |e| try w.writer.print("    .{{ .name = \"{s}\", .source = \"{s}\", .split = {}, .encoder = {}, .companion = {} }},\n", .{ e.name, e.source, e.split, e.encoder, e.companion });
    try w.writer.writeAll("};\n");
    return gpa.dupe(u8, w.written());
}
fn compare(gpa: std.mem.Allocator, io: std.Io, path: []const u8, data: []const u8) !void {
    const old = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1024 * 1024)) catch return error.MissingRegistry;
    defer gpa.free(old);
    if (!std.mem.eql(u8, old, data)) return error.StaleRegistry;
}
fn verifySources(gpa: std.mem.Allocator, io: std.Io, root: std.Io.Dir, entries: []const Entry) !void {
    const real_root = try root.realPathFileAlloc(io, ".", gpa);
    defer gpa.free(real_root);
    for (entries) |e| {
        const actual = try root.realPathFileAlloc(io, e.source, gpa);
        defer gpa.free(actual);
        if (!std.mem.startsWith(u8, actual, real_root) or actual.len <= real_root.len or actual[real_root.len] != std.fs.path.sep) return error.SourceEscapesPackage;
        const file = try root.openFile(io, e.source, .{});
        defer file.close(io);
        if ((try file.stat(io)).kind != .file) return error.SourceIsNotFile;
    }
}
pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len != 4 and args.len != 5 and args.len != 6) return error.Usage;
    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], gpa, .limited(1024 * 1024));
    const entries = try std.zon.parse.fromSliceAlloc([]Entry, gpa, try gpa.dupeZ(u8, source), null, .{});
    try validate(entries);
    var root = try std.Io.Dir.cwd().openDir(init.io, args[2], .{});
    defer root.close(init.io);
    try verifySources(gpa, init.io, root, entries);
    const data = try render(gpa, entries);
    if (args.len == 5 and std.mem.eql(u8, args[4], "--check")) return compare(gpa, init.io, args[3], data);
    if (args.len == 6 and std.mem.eql(u8, args[4], "--compare")) {
        const generated = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], gpa, .limited(1024 * 1024));
        return compare(gpa, init.io, args[5], generated);
    }
    if (args.len != 4) return error.Usage;
    if (std.fs.path.dirname(args[3])) |parent| try std.Io.Dir.cwd().createDirPath(init.io, parent);
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, args[3], .{});
    defer atomic.deinit(init.io);
    try atomic.file.writeStreamingAll(init.io, data);
    try atomic.file.sync(init.io);
    try atomic.replace(init.io);
}

test "catalog validation rejects duplicate names and unsafe paths" {
    var entries = [_]Entry{.{ .name = "lk7", .source = "a.zig", .split = false, .encoder = false, .companion = true }};
    try validate(&entries);
    try std.testing.expectError(error.EmptyCatalog, validate(&.{}));
    try std.testing.expectError(error.DuplicateName, validate(&.{ entries[0], entries[0] }));
    for ([_][]const u8{ "", "UPPER", "a-b", "a\"" }) |name| {
        var bad = entries[0];
        bad.name = name;
        try std.testing.expectError(error.InvalidName, validate(&.{bad}));
    }
    for ([_][]const u8{ "/a.zig", "../a.zig", "./a.zig", "x//a.zig", "x/../a.zig", "a\".zig", "a.txt" }) |path| {
        var bad = entries[0];
        bad.source = path;
        try std.testing.expectError(error.InvalidPath, validate(&.{bad}));
    }
}
test "typed ZON rejects malformed entries and nonboolean metadata" {
    for ([_][:0]const u8{ "null", ".{}", ".{1}", ".{\"x\"}", ".{.{.name=\"x\"}}", ".{.{.name=\"x\",.source=\"a.zig\",.split=1,.encoder=false,.companion=false}}" }) |source| {
        const parsed = std.zon.parse.fromSliceAlloc([]Entry, std.testing.allocator, source, null, .{}) catch |err| {
            try std.testing.expectEqual(error.ParseZon, err);
            continue;
        };
        defer std.zon.parse.free(std.testing.allocator, parsed);
        try std.testing.expectError(error.EmptyCatalog, validate(parsed));
    }
}
test "render is deterministic regardless of catalog order" {
    var entries = [_]Entry{
        .{ .name = "z", .source = "z.zig", .split = false, .encoder = false, .companion = false },
        .{ .name = "a", .source = "a.zig", .split = true, .encoder = true, .companion = true },
    };
    const first = try render(std.testing.allocator, &entries);
    defer std.testing.allocator.free(first);
    std.mem.swap(Entry, &entries[0], &entries[1]);
    const second = try render(std.testing.allocator, &entries);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
}
test "registry checks never create or change committed files" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const path = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(path);
    const file = try std.fs.path.join(std.testing.allocator, &.{ path, "registry.zig" });
    defer std.testing.allocator.free(file);
    try std.testing.expectError(error.MissingRegistry, compare(std.testing.allocator, std.testing.io, file, "new"));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "registry.zig", .data = "old" });
    try std.testing.expectError(error.StaleRegistry, compare(std.testing.allocator, std.testing.io, file, "new"));
    try compare(std.testing.allocator, std.testing.io, file, "old");
    var atomic = try tmp.dir.createFileAtomic(std.testing.io, "registry.zig", .{});
    try atomic.file.writeStreamingAll(std.testing.io, "partial");
    atomic.deinit(std.testing.io);
    try compare(std.testing.allocator, std.testing.io, file, "old");
    var iter = tmp.dir.iterate();
    const entry = (try iter.next(std.testing.io)).?;
    try std.testing.expectEqualStrings("registry.zig", entry.name);
    try std.testing.expectEqual(null, try iter.next(std.testing.io));
}

test "catalog sources must exist and symbolic links stay inside the package" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDir(io, "boards", .default_dir);
    var root = try tmp.dir.openDir(io, "boards", .{});
    defer root.close(io);
    const entry = Entry{ .name = "lk7", .source = "board.zig", .split = false, .encoder = false, .companion = true };
    try std.testing.expectError(error.FileNotFound, verifySources(gpa, io, root, &.{entry}));
    try root.writeFile(io, .{ .sub_path = "actual.zig", .data = "" });
    try root.symLink(io, "actual.zig", "board.zig", .{});
    try verifySources(gpa, io, root, &.{entry});
    try root.deleteFile(io, "board.zig");
    try tmp.dir.writeFile(io, .{ .sub_path = "outside.zig", .data = "" });
    try root.symLink(io, "../outside.zig", "board.zig", .{});
    try std.testing.expectError(error.SourceEscapesPackage, verifySources(gpa, io, root, &.{entry}));
}
