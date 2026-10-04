const std = @import("std");
pub const selector = @import("src/build_input.zig");
pub fn build(b: *std.Build) void {
    const firmware = b.dependency("zigmkay", .{}).module("zigmkay");
    const model = b.dependency("layout_model", .{}).module("layout-model");
    const original = b.createModule(.{ .root_source_file = b.path("../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig"), .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "zkeycodes", .module = b.dependency("zkeycodes", .{}).module("zkeycodes") } } });
    const physical = b.createModule(.{ .root_source_file = b.path("../keyboards/my_keyboards/rollercole/lk7_physical_layout.zig"), .imports = &.{.{ .name = "layout-model", .module = model }} });
    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "layout-model", .module = model },
        .{ .name = "device-protocol", .module = b.dependency("device_protocol", .{}).module("device-protocol") },
        .{ .name = "rollercole-profile", .module = original },
        .{ .name = "lk7-physical", .module = physical },
    };
    const project = b.addModule("keymap-project", .{ .root_source_file = b.path("src/root.zig"), .imports = imports });
    project.addAnonymousImport("rollercole-source", .{ .root_source_file = b.path("../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig") });
    const cli = b.addExecutable(.{ .name = "keymap-project", .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = b.graph.host, .imports = &.{.{ .name = "keymap-project", .module = project }} }) });
    b.installArtifact(cli);
    const cli_run = b.addRunArtifact(cli);
    cli_run.setCwd(b.path(".."));
    if (b.args) |args| cli_run.addArgs(args);
    b.step("run", "Explicit create validate or owned Zig export").dependOn(&cli_run.step);
    const tests = b.step("test", "Test project data and a generated processor fixture offline");
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.graph.host,
        .imports = imports,
    });
    test_module.addAnonymousImport("rollercole-source", .{ .root_source_file = b.path("../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig") });
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = test_module })).step);
    b.default_step = tests;
    const generator = b.addExecutable(.{ .name = "export-compile-fixture", .root_module = b.createModule(.{
        .root_source_file = b.path("src/export_fixture.zig"),
        .target = b.graph.host,
        .imports = &.{.{ .name = "keymap-project", .module = project }},
    }) });
    const generated = b.addRunArtifact(generator).addOutputFileArg("keymap.zig");
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
