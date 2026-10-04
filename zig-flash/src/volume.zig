const std = @import("std");

pub fn validateInfo(bytes: []const u8) !void {
    var model = false;
    var board = false;
    var lines = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "Model: Raspberry Pi RP2")) model = true;
        if (std.mem.eql(u8, line, "Board-ID: RPI-RP2")) board = true;
    }
    if (!model or !board or !std.mem.startsWith(u8, bytes, "UF2 Bootloader ")) return error.UnexpectedBootloader;
}

pub fn validate(io: std.Io, dir: std.Io.Dir) !void {
    var buffer: [1025]u8 = undefined;
    const bytes = try dir.readFile(io, "INFO_UF2.TXT", &buffer);
    try validateInfo(bytes);
}

// A label can acquire a numeric suffix on macOS when another volume is mounted.
pub fn matchesLabel(name: []const u8, label: []const u8) bool {
    if (std.mem.eql(u8, name, label)) return true;
    if (!std.mem.startsWith(u8, name, label) or name.len <= label.len + 1 or name[label.len] != ' ') return false;
    for (name[label.len + 1 ..]) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

pub fn discover(gpa: std.mem.Allocator, io: std.Io, root: []const u8, label: []const u8) !?[]u8 {
    var dir = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer dir.close(io);
    var iterator = dir.iterate();
    var selected: ?[]u8 = null;
    errdefer if (selected) |path| gpa.free(path);
    while (try iterator.next(io)) |entry| {
        if (!matchesLabel(entry.name, label)) continue;
        if (selected != null) return error.AmbiguousVolumes;
        selected = try std.fs.path.join(gpa, &.{ root, entry.name });
    }
    return selected;
}

test "bootloader identity rejects wrong board and misleading substrings" {
    try validateInfo("UF2 Bootloader v3.0\r\nModel: Raspberry Pi RP2\r\nBoard-ID: RPI-RP2\r\n");
    for ([_][]const u8{
        "UF2 Bootloader v3.0\nModel: Raspberry Pi RP2\nBoard-ID: OTHER\n",
        "UF2 Bootloader v3.0\nModel: Raspberry Pi RP2350\nBoard-ID: RPI-RP2\n",
        "UF2 Bootloader v3.0\nModel: Raspberry Pi RP2 bad\nBoard-ID: RPI-RP2\n",
    }) |info| try std.testing.expectError(error.UnexpectedBootloader, validateInfo(info));
}

test "fixture discovery distinguishes missing unique and ambiguous mounts" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(root);
    try std.testing.expect(try discover(std.testing.allocator, std.testing.io, root, "RPI-RP2") == null);
    try temp.dir.createDir(std.testing.io, "RPI-RP2", .default_dir);
    const selected = (try discover(std.testing.allocator, std.testing.io, root, "RPI-RP2")).?;
    defer std.testing.allocator.free(selected);
    try std.testing.expect(std.mem.endsWith(u8, selected, "RPI-RP2"));
    try temp.dir.createDir(std.testing.io, "RPI-RP2 1", .default_dir);
    try std.testing.expectError(error.AmbiguousVolumes, discover(std.testing.allocator, std.testing.io, root, "RPI-RP2"));
    try std.testing.expect(!matchesLabel("RPI-RP2-other", "RPI-RP2"));
}
