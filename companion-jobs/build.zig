const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("companion-jobs", .{ .root_source_file = b.path("src/root.zig") });
    const helper = b.addExecutable(.{ .name = "job-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("src/fixture.zig"), .target = b.graph.host }) });
    const tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("src/test_process.zig"), .target = b.graph.host, .imports = &.{.{ .name = "companion-jobs", .module = module }} }) });
    const options = b.addOptions();
    options.addOptionPath("helper_path", helper.getEmittedBin());
    tests.root_module.addOptions("options", options);
    const run = b.addRunArtifact(tests);
    const step = b.step("test", "Test bounded process jobs cancellation timeout crash and stale results offline");
    step.dependOn(&run.step);
    b.default_step = step;
}
