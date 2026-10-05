const std = @import("std");
const selector = @import("keymap_project").selector;
const helpers = @import("build_helpers.zig");
pub fn build(b: *std.Build) void {
    const firmware = b.dependency("zigmkay", .{}).module("zigmkay");
    const model = b.dependency("layout_model", .{}).module("layout-model");
    const keycodes = b.dependency("zkeycodes", .{}).module("zkeycodes");
    const project = b.dependency("keymap_project", .{});
    const runner_protocol = b.addModule("runner-protocol", .{ .root_source_file = b.path("protocol.zig"), .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    var profile: *std.Build.Module = undefined;
    var snapshot_id: [32]u8 = @splat(0);
    if (b.option([]const u8, "profile", "Absolute verified export directory")) |path| {
        const selected = selector.load(b, path, firmware, keycodes, model) catch |err| @panic(b.fmt("Cannot select profile: {s}", .{@errorName(err)}));
        profile = selected.module;
        snapshot_id = selected.snapshot_id;
    } else {
        const generated = helpers.fixture(b, project.module("keymap-project"), "runner-fixture", null);
        profile = b.createModule(.{ .root_source_file = generated, .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    }
    const exe = helpers.runner(b, "keymap-test", firmware, profile, runner_protocol, snapshot_id);
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Explicitly run the offline processor draft runner").dependOn(&run.step);
    const tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("test_runner.zig"), .target = b.graph.host, .imports = &.{ .{ .name = "runner-protocol", .module = runner_protocol }, .{ .name = "zigmkay", .module = firmware }, .{ .name = "companion-jobs", .module = b.dependency("companion_jobs", .{}).module("companion-jobs") } } }) });
    const acceptance_source = helpers.fixture(b, project.module("keymap-project"), "action-fixture", "all-actions");
    const handler = b.createModule(.{ .root_source_file = b.path("callback_fixture.zig"), .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    const acceptance_profile = b.createModule(.{ .root_source_file = acceptance_source, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "callback_0", .module = handler } } });
    const acceptance_exe = helpers.runner(b, "action-test-runner", firmware, acceptance_profile, runner_protocol, @splat(0));
    const registered_source = helpers.fixture(b, project.module("keymap-project"), "registered-fixture", "danish");
    const registered_handler = project.module("default-profile");
    const registered_profile = b.createModule(.{ .root_source_file = registered_source, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "callback_0", .module = registered_handler } } });
    const registered_exe = helpers.runner(b, "registered-test-runner", firmware, registered_profile, runner_protocol, @splat(0));
    const test_options = b.addOptions();
    test_options.addOptionPath("runner_path", exe.getEmittedBin());
    test_options.addOptionPath("action_runner_path", acceptance_exe.getEmittedBin());
    test_options.addOptionPath("registered_runner_path", registered_exe.getEmittedBin());
    tests.root_module.addOptions("options", test_options);
    b.step("test", "Test the generated native draft runner without device APIs").dependOn(&b.addRunArtifact(tests).step);
}
