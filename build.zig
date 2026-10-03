const std = @import("std");

pub fn build(b: *std.Build) void {
    const firmware = b.dependency("zigmkay", .{});
    const test_step = b.step("test", "Run portable and firmware core tests");
    test_step.dependOn(&firmware.builder.top_level_steps.get("test").?.step);
    const model = b.dependency("layout_model", .{});
    const types_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/test_shared_types.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware.module("zigmkay") },
            .{ .name = "layout-model", .module = model.module("layout-model") },
            .{ .name = "zkeycodes", .module = b.dependency("zkeycodes", .{}).module("zkeycodes") },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(types_test).step);
    test_step.dependOn(&model.builder.top_level_steps.get("test").?.step);
    test_step.dependOn(&model.builder.top_level_steps.get("check-portable").?.step);
}
