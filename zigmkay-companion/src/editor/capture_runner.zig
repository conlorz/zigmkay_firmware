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
            if (std.mem.eql(u8, field.name, "normal")) try argv.appendSlice(a, &.{ "--compare-reference", if (light) "docs/plans/mockups/editor-02-light-layer-sidebar.png" else "docs/plans/mockups/editor-04-dark-layer-sidebar.png" });
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
    std.log.info("64 captures, panel geometry, Retina/non-Retina readback and semantic interactions passed", .{});
}
