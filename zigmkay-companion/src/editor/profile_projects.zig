//! Persistent project directories associated with the profile dropdown.
const std = @import("std");
const p = @import("keymap-project");
const Model = @import("model.zig").Model;
pub const Registry = struct {
    paths: [4][1024]u8 = @splat(@splat(0)),
    pub fn set(self: *Registry, index: usize, directory: []const u8) !void {
        if (index >= self.paths.len or directory.len >= 1024 or !std.fs.path.isAbsolute(directory) or std.mem.indexOfScalar(u8, directory, 0) != null) return error.InvalidProjectPath;
        self.paths[index] = @splat(0);
        @memcpy(self.paths[index][0..directory.len], directory);
    }
    pub fn path(self: *const Registry, index: usize) []const u8 {
        return std.mem.sliceTo(&self.paths[index], 0);
    }
    pub fn load(gpa: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !Registry {
        const bytes = dir.readFileAlloc(io, "profile-projects.zon", gpa, .limited(65536)) catch |err| switch (err) {
            error.FileNotFound => return .{},
            else => return err,
        };
        defer gpa.free(bytes);
        const text = try gpa.dupeZ(u8, bytes);
        defer gpa.free(text);
        const paths = try std.zon.parse.fromSliceAlloc([4][]const u8, gpa, text, null, .{});
        defer std.zon.parse.free(gpa, paths);
        var registry: Registry = .{};
        for (paths, 0..) |value, index| if (value.len != 0) try registry.set(index, value);
        return registry;
    }
    pub fn save(self: *const Registry, gpa: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !void {
        var paths: [4][]const u8 = undefined;
        for (&paths, 0..) |*value, index| value.* = self.path(index);
        var writer: std.Io.Writer.Allocating = .init(gpa);
        defer writer.deinit();
        try std.zon.stringify.serialize(paths, .{}, &writer.writer);
        var file = try dir.createFileAtomic(io, "profile-projects.zon", .{ .replace = true });
        defer file.deinit(io);
        try file.file.writeStreamingAll(io, writer.written());
        try file.file.sync(io);
        try file.replace(io);
    }
};

/// Existing files always win over built-in templates. Materialize a template
/// only when the selected directory has no project yet.
pub fn open(model: *Model, io: std.Io, directory: []const u8, profile: p.profiles.Profile) !void {
    var dir = try std.Io.Dir.cwd().createDirPathOpen(io, directory, .{});
    defer dir.close(io);
    dir.access(io, "project.zon", .{}) catch |err| switch (err) {
        error.FileNotFound => {
            var loaded = try p.profiles.create(model.gpa, profile);
            defer loaded.deinit();
            try p.snapshot.save(model.gpa, io, dir, loaded.snapshot, p.profiles.board);
        },
        else => return err,
    };
    try model.open(io, dir);
}

test "dropdown project saves survive switching profiles and restarting" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realPathFileAlloc(io, ".", gpa);
    defer gpa.free(root);
    const personal = try std.fs.path.join(gpa, &.{ root, "personal" });
    defer gpa.free(personal);
    const other = try std.fs.path.join(gpa, &.{ root, "other" });
    defer gpa.free(other);
    var registry: Registry = .{};
    try registry.set(3, personal);
    try registry.set(1, other);
    try registry.save(gpa, io, temp.dir);
    const restored = try Registry.load(gpa, io, temp.dir);
    var model = try Model.init(gpa, .eurkey);
    defer model.deinit();
    try open(&model, io, restored.path(3), .eurmac);
    try model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 9 } } });
    var dir = try std.Io.Dir.cwd().openDir(io, personal, .{});
    defer dir.close(io);
    try model.save(io, dir);
    const saved = try model.id();
    try open(&model, io, restored.path(1), .qwerty);
    try open(&model, io, restored.path(3), .eurmac);
    try std.testing.expectEqual(saved, try model.id());
    try std.testing.expect(!model.dirty());
    var fresh = try Model.init(gpa, .eurkey);
    defer fresh.deinit();
    try open(&fresh, io, restored.path(3), .eurmac);
    try std.testing.expectEqual(saved, try fresh.id());
}

test "unreadable existing dropdown project is never replaced with a template" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const directory = try temp.dir.realPathFileAlloc(io, ".", gpa);
    defer gpa.free(directory);
    try temp.dir.writeFile(io, .{ .sub_path = "project.zon", .data = "invalid project" });
    var model = try Model.init(gpa, .eurkey);
    defer model.deinit();
    const original = try model.id();
    if (open(&model, io, directory, .eurmac)) |_| {
        return error.ExpectedLoadFailure;
    } else |_| {}
    const bytes = try temp.dir.readFileAlloc(io, "project.zon", gpa, .limited(100));
    defer gpa.free(bytes);
    try std.testing.expectEqualStrings("invalid project", bytes);
    try std.testing.expectEqual(original, try model.id());
}
