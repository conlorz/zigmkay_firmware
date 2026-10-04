const std = @import("std");
const inventory = @import("source_inventory.zig");
pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len != 5 and args.len != 6) return error.Usage;
    const zig = args[1];
    const root_path = args[2];
    const scratch = args[4];
    var root = try std.Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true });
    defer root.close(io);
    const expected = try root.readFileAlloc(io, ".zigversion", gpa, .limited(256));
    const version = try std.process.run(gpa, io, .{ .argv = &.{ zig, "version" } });
    inventory.verifyVersion(expected, version.stdout) catch |err| {
        std.debug.print("Expected Zig {s}, got {s}\n", .{ std.mem.trim(u8, expected, "\r\n"), std.mem.trim(u8, version.stdout, "\r\n") });
        return err;
    };
    const full = args.len == 6 and std.mem.eql(u8, args[5], "--full");
    try std.Io.Dir.cwd().createDirPath(io, scratch);
    defer std.Io.Dir.cwd().deleteTree(io, scratch) catch {};
    const before = try inventory.snapshot(gpa, io, root);
    const marker = try std.fs.path.join(gpa, &.{ scratch, "hardware-tool-executed" });
    for ([_][]const u8{ "zig_flash", "zig-flash", "picotool", "diskutil", "mount", "flash" }) |name| {
        const path = try std.fs.path.join(gpa, &.{ scratch, name });
        try std.Io.Dir.cwd().copyFile(args[3], std.Io.Dir.cwd(), path, io, .{});
    }
    try init.environ_map.put("ZIGMKAY_SENTINEL", marker);
    try init.environ_map.put("PATH", try std.fmt.allocPrint(gpa, "{s}{c}{s}", .{ scratch, std.fs.path.delimiter, init.environ_map.get("PATH") orelse "" }));
    try runTasks(init, root_path, if (full) &.{"//:_validate-full"} else &.{ "//:test", "//:check-generated" });
    if (full) {
        try run(init, zig, try std.fs.path.join(gpa, &.{ root_path, "keyboards" }), &.{ "firmware", "-Dkeyboard=lk7" });
        try run(init, zig, try std.fs.path.join(gpa, &.{ root_path, "apps/headless" }), &.{ "-p", "../../zig-out", "-Dtarget=thumb-freestanding-eabi" });
        const entries = @import("board-catalog");
        inline for (entries) |entry| {
            const path = try std.fmt.allocPrint(gpa, "zig-out/firmware/{s}/zigmkay.uf2", .{entry.name});
            try root.access(io, path, .{});
        }
        const root_uf2 = try root.readFileAlloc(io, "zig-out/firmware/lk7/zigmkay.uf2", gpa, .limited(1024 * 1024));
        const leaf_uf2 = try root.readFileAlloc(io, "keyboards/zig-out/firmware/lk7/zigmkay.uf2", gpa, .limited(1024 * 1024));
        if (!std.mem.eql(u8, root_uf2, leaf_uf2)) return error.FirmwareParityMismatch;
        const replay = try std.process.run(gpa, io, .{ .argv = &.{ try std.fs.path.join(gpa, &.{ root_path, "zig-out/bin/zigmkay-companion-headless-lk7" }), try std.fs.path.join(gpa, &.{ root_path, "tests/fixtures/lk7_trace.bin" }) }, .environ_map = init.environ_map });
        if (!success(replay.term) or std.mem.indexOf(u8, replay.stdout, "reports=8\npressed=[]\nactive_layers=1") == null) return error.InstalledReplayFailed;
        std.debug.print("All 10 board artifacts exist; mise/standalone LK7 UF2 bytes match\n", .{});
    }
    try std.testing.expectError(error.FileNotFound, std.Io.Dir.cwd().access(io, marker, .{}));
    if (!std.mem.eql(u8, &before, &(try inventory.snapshot(gpa, io, root)))) return error.SourceChangedByChecks;
    std.debug.print("Source contents and inventory unchanged; no hardware tool executed\n", .{});
}
fn runTasks(init: std.process.Init, cwd: []const u8, tasks: []const []const u8) !void {
    const argv = try std.mem.concat(init.arena.allocator(), []const u8, &.{ &.{ "mise", "run", "--jobs", "2" }, tasks });
    const result = try std.process.run(init.arena.allocator(), init.io, .{ .argv = argv, .cwd = .{ .path = cwd }, .environ_map = init.environ_map, .stdout_limit = .limited(16 * 1024 * 1024), .stderr_limit = .limited(16 * 1024 * 1024) });
    if (!success(result.term)) {
        std.debug.print("{s}{s}", .{ result.stdout, result.stderr });
        return error.CheckFailed;
    }
    std.debug.print("Mise aggregate tasks passed: {s}\n", .{try std.mem.join(init.arena.allocator(), " ", tasks)});
}
fn success(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}
fn run(init: std.process.Init, zig: []const u8, cwd: []const u8, flags: []const []const u8) !void {
    const argv = try std.mem.concat(init.arena.allocator(), []const u8, &.{ &.{ zig, "build", "-j4", "--summary", "failures" }, flags });
    std.debug.print("Checking {s}: {s}\n", .{ cwd, try std.mem.join(init.arena.allocator(), " ", flags) });
    const result = try std.process.run(init.arena.allocator(), init.io, .{ .argv = argv, .cwd = .{ .path = cwd }, .environ_map = init.environ_map, .stdout_limit = .limited(16 * 1024 * 1024), .stderr_limit = .limited(16 * 1024 * 1024) });
    if (!success(result.term)) {
        std.debug.print("{s}{s}", .{ result.stdout, result.stderr });
        return error.CheckFailed;
    }
}
