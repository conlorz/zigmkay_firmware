//! Explicit native capture acceptance task. This is separate from default tests.
const std = @import("std");
const jobs = @import("companion-jobs");
const State = @import("states.zig").State;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2 and args.len != 3) return error.Usage;
    const a = init.arena.allocator();
    const directory = ".zig-cache/editor-acceptance";
    var dir = try std.Io.Dir.cwd().createDirPathOpen(init.io, directory, .{});
    dir.close(init.io);
    for ([_]bool{ false, true }) |light| for ([_]u8{ 1, 2 }) |density| {
        inline for (@typeInfo(State).@"enum".fields) |field| {
            const path = try std.fmt.allocPrint(a, "{s}/{s}-{d}x-{s}.png", .{ directory, if (light) "light" else "dark", density, field.name });
            var argv: std.ArrayList([]const u8) = .empty;
            try argv.appendSlice(a, &.{ args[1], "--editor", "--screenshot", path, "--scenario", field.name, "--density", try std.fmt.allocPrint(a, "{d}", .{density}) });
            if (light) try argv.append(a, "--light");
            if (!light and std.mem.eql(u8, field.name, "normal")) try argv.appendSlice(a, &.{ "--compare-reference", "docs/plans/mockups/key-creation/02-inspector-dark-macos.png" });
            if (args.len == 3 and std.mem.eql(u8, field.name, "normal")) try argv.appendSlice(a, &.{ "--compare-golden", try std.fmt.allocPrint(a, "{s}/{s}-{d}x-normal.png", .{ args[2], if (light) "light" else "dark", density }) });
            var owned = try jobs.run(init.gpa, init.io, .{ .argv = argv.items, .cwd = ".", .snapshot_id = @splat(0), .timeout_ms = 20000 });
            defer owned.deinit(init.gpa);
            const result = owned.process;

            if (result.term != .exited or result.term.exited != 0) {
                std.log.err("Capture failed: {s}\n{s}", .{ path, result.stderr });
                return error.CaptureFailed;
            }
            if (std.mem.indexOf(u8, result.stderr, "error(dvui)") != null or std.mem.indexOf(u8, result.stderr, "duplicate widget") != null) {
                std.log.err("Capture widget diagnostic: {s}\n{s}", .{ path, result.stderr });
                return error.WidgetDiagnostic;
            }
            std.log.info("Captured {s}", .{path});
        }
    };
    var owned = try jobs.run(init.gpa, init.io, .{ .argv = &.{ args[1], "--editor", "--interactions", "--screenshot", ".zig-cache/editor-acceptance/interactions.png" }, .cwd = ".", .snapshot_id = @splat(0), .timeout_ms = 20000 });
    defer owned.deinit(init.gpa);
    const result = owned.process;

    if (result.term != .exited or result.term.exited != 0) {
        std.log.err("Interaction failed: {s}", .{result.stderr});
        return error.InteractionFailed;
    }
    for ([_][]const []const u8{
        &.{ args[1], "--editor", "--window-size", "1152", "768", "--density", "1", "--interactions", "--screenshot", ".zig-cache/editor-acceptance/resizable-1152.png" },
        &.{ args[1], "--editor", "--window-size", "900", "600", "--density", "2", "--scenario", "firmware_failed", "--screenshot", ".zig-cache/editor-acceptance/resizable-minimum.png" },
    }) |argv| {
        var resized = try jobs.run(init.gpa, init.io, .{ .argv = argv, .cwd = ".", .snapshot_id = @splat(0), .timeout_ms = 20000 });
        defer resized.deinit(init.gpa);
        if (!resized.successful() or std.mem.indexOf(u8, resized.process.stderr, "error(dvui)") != null) {
            std.log.err("Resized editor failed: {s}", .{resized.process.stderr});
            return error.ResizeCheckFailed;
        }
    }
    for ([_]bool{ false, true }) |light| for ([_]u8{ 1, 2 }) |density| for ([_][2]u16{ .{ 1152, 768 }, .{ 900, 600 } }) |size| for ([_][]const u8{ "free_typing", "free_long", "practice_english", "practice_zig", "native_free_input", "native_live_input" }) |mode| {
        const path = try std.fmt.allocPrint(a, "{s}/{s}-{d}x-{d}x{d}-{s}.png", .{ directory, if (light) "light" else "dark", density, size[0], size[1], mode });
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(a, &.{ args[1], "--editor", "--window-size", try std.fmt.allocPrint(a, "{d}", .{size[0]}), try std.fmt.allocPrint(a, "{d}", .{size[1]}), "--density", try std.fmt.allocPrint(a, "{d}", .{density}), "--scenario", mode, "--screenshot", path });
        if (light) try argv.append(a, "--light");
        var resized = try jobs.run(init.gpa, init.io, .{ .argv = argv.items, .cwd = ".", .snapshot_id = @splat(0), .timeout_ms = 20000 });
        defer resized.deinit(init.gpa);
        if (!resized.successful() or std.mem.indexOf(u8, resized.process.stderr, "error(dvui)") != null or std.mem.indexOf(u8, resized.process.stderr, "duplicate widget") != null) {
            std.log.err("Resized Try it out failed: {s}\n{s}", .{ path, resized.process.stderr });
            return error.ResizeCheckFailed;
        }
        std.log.info("Captured {s}", .{path});
    };
    std.log.info("{d} captures, panel geometry, Retina/non-Retina readback and semantic interactions passed", .{@typeInfo(State).@"enum".fields.len * 4 + 51});
}
