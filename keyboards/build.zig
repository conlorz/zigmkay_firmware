const std = @import("std");
pub const api = @import("build_api.zig");

pub fn build(b: *std.Build) void {
    const selected = b.option([]const u8, "keyboard", "Select a firmware board explicitly");
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Firmware optimization (default ReleaseSafe)") orelse .ReleaseSafe;
    _ = b.standardTargetOptions(.{});
    const core = b.dependency("zigmkay", .{});
    api.commands(b, b.path("."), b.dependency("microzig", .{}), .{
        .processor_root = core.path("."),
        .model = b.dependency("layout_model", .{}).module("layout-model"),
        .protocol = b.dependency("device_protocol", .{}).module("device-protocol"),
        .keycodes = b.dependency("zkeycodes", .{}).module("zkeycodes"),
    }, selected, optimize);
    // Standalone firmware retains explicit selection, without defaulting to a board.
    b.default_step = &b.top_level_steps.get("list-keyboards").?.step;
}
