const std = @import("std");
pub fn build(b: *std.Build) void {
    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "layout-model", .module = b.dependency("layout_model", .{}).module("layout-model") },
        .{ .name = "device-protocol", .module = b.dependency("device_protocol", .{}).module("device-protocol") },
    };
    const project = b.addModule("keymap-project", .{ .root_source_file = b.path("src/root.zig"), .imports = imports });
    const tests = b.step("test", "Test project data and a generated processor fixture offline");
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.graph.host,
        .imports = imports,
    }) })).step);
    b.default_step = tests;
    const generator = b.addExecutable(.{ .name = "export-compile-fixture", .root_module = b.createModule(.{
        .root_source_file = b.path("src/export_fixture.zig"),
        .target = b.graph.host,
        .imports = &.{.{ .name = "keymap-project", .module = project }},
    }) });
    const generated = b.addRunArtifact(generator).addOutputFileArg("keymap.zig");
    const firmware = b.dependency("zigmkay", .{}).module("zigmkay");
    const profile = b.createModule(.{ .root_source_file = generated, .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/export_compile_test.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "generated-profile", .module = profile },
            .{ .name = "zigmkay", .module = firmware },
            .{ .name = "device-protocol", .module = imports[1].module },
        },
    }) })).step);
}
