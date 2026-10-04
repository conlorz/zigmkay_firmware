const std = @import("std");
pub fn build(b: *std.Build) void {
    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "layout-model", .module = b.dependency("layout_model", .{}).module("layout-model") },
        .{ .name = "device-protocol", .module = b.dependency("device_protocol", .{}).module("device-protocol") },
    };
    _ = b.addModule("keymap-project", .{ .root_source_file = b.path("src/root.zig"), .imports = imports });
    const tests = b.step("test", "Test project data without compiling or executing callbacks");
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.graph.host,
        .imports = imports,
    }) })).step);
    b.default_step = tests;
}
