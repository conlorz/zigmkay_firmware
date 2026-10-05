const std = @import("std");
pub fn build(b: *std.Build) void {
    const source_files = b.addModule("source-files", .{ .root_source_file = b.path("src/source_files.zig") });
    const module = b.addModule("companion-jobs", .{ .root_source_file = b.path("src/root.zig") });
    module.addImport("source-files", source_files);
    module.addImport("firmware-uf2", b.dependency("zig_flash", .{}).module("uf2"));
    const helper = b.addExecutable(.{ .name = "job-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("src/fixture.zig"), .target = b.graph.host }) });
    const tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("src/test_process.zig"), .target = b.graph.host, .imports = &.{.{ .name = "companion-jobs", .module = module }} }) });
    const options = b.addOptions();
    options.addOptionPath("helper_path", helper.getEmittedBin());
    tests.root_module.addOptions("options", options);
    const run = b.addRunArtifact(tests);
    const step = b.step("test", "Test bounded process jobs cancellation timeout crash and stale results offline");
    const traversal_tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("src/source_files.zig"), .target = b.graph.host }) });
    step.dependOn(&b.addRunArtifact(traversal_tests).step);
    step.dependOn(&run.step);
    const firmware_tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("src/firmware.zig"), .target = b.graph.host, .imports = &.{.{ .name = "firmware-uf2", .module = b.dependency("zig_flash", .{}).module("uf2") }} }) });
    step.dependOn(&b.addRunArtifact(firmware_tests).step);
    b.default_step = step;
}
