const std = @import("std");
pub fn publish(b: *std.Build, root: std.Build.LazyPath, model: *std.Build.Module, protocol: *std.Build.Module) *std.Build.Module {
    return b.addModule("companion-model", .{
        .root_source_file = root.path(b, "src/root.zig"),
        .imports = &.{
            .{ .name = "layout-model", .module = model },
            .{ .name = "device-protocol", .module = protocol },
        },
    });
}
pub fn build(b: *std.Build) void {
    const module = publish(b, b.path("."), b.dependency("layout_model", .{}).module("layout-model"), b.dependency("device_protocol", .{}).module("device-protocol"));
    const tests = b.step("test", "Run portable companion unit tests");
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "layout-model", .module = module.import_table.get("layout-model").? },
            .{ .name = "device-protocol", .module = module.import_table.get("device-protocol").? },
        },
    }) })).step);
    b.default_step = tests;
}
