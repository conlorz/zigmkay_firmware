const std = @import("std");
const selector = @import("keymap_project").selector;
pub fn build(b: *std.Build) void {
    const firmware = b.dependency("zigmkay", .{}).module("zigmkay");
    const model = b.dependency("layout_model", .{}).module("layout-model");
    const keycodes = b.dependency("zkeycodes", .{}).module("zkeycodes");
    const runner_protocol = b.addModule("runner-protocol", .{ .root_source_file = b.path("protocol.zig"), .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    var profile: *std.Build.Module = undefined;
    var snapshot_id: [32]u8 = @splat(0);
    if (b.option([]const u8, "profile", "Absolute verified export directory")) |path| {
        const selected = selector.load(b, path, firmware, keycodes, model) catch |err| @panic(b.fmt("Cannot select profile: {s}", .{@errorName(err)}));
        profile = selected.module;
        snapshot_id = selected.snapshot_id;
    } else {
        const generator = b.addExecutable(.{ .name = "runner-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("fixture.zig"), .target = b.graph.host, .imports = &.{.{ .name = "keymap-project", .module = b.dependency("keymap_project", .{}).module("keymap-project") }} }) });
        const generated = b.addRunArtifact(generator).addOutputFileArg("keymap.zig");
        profile = b.createModule(.{ .root_source_file = generated, .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    }
    const options = b.addOptions();
    options.addOption([32]u8, "snapshot_id", snapshot_id);
    const module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.graph.host, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "selected-profile", .module = profile }, .{ .name = "runner-protocol", .module = runner_protocol } } });
    module.addOptions("snapshot-options", options);
    const exe = b.addExecutable(.{ .name = "keymap-test", .root_module = module });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Explicitly run the offline processor draft runner").dependOn(&run.step);
    const tests = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("test_runner.zig"), .target = b.graph.host, .imports = &.{ .{ .name = "runner-protocol", .module = runner_protocol }, .{ .name = "zigmkay", .module = firmware }, .{ .name = "companion-jobs", .module = b.dependency("companion_jobs", .{}).module("companion-jobs") } } }) });
    const acceptance_generator = b.addExecutable(.{ .name = "action-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("fixture.zig"), .target = b.graph.host, .imports = &.{.{ .name = "keymap-project", .module = b.dependency("keymap_project", .{}).module("keymap-project") }} }) });
    const acceptance_run = b.addRunArtifact(acceptance_generator);
    const acceptance_source = acceptance_run.addOutputFileArg("actions.zig");
    acceptance_run.addArg("all-actions");
    const handler = b.createModule(.{ .root_source_file = b.path("callback_fixture.zig"), .imports = &.{.{ .name = "zigmkay", .module = firmware }} });
    const acceptance_profile = b.createModule(.{ .root_source_file = acceptance_source, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "callback_0", .module = handler } } });
    const acceptance_module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.graph.host, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "selected-profile", .module = acceptance_profile }, .{ .name = "runner-protocol", .module = runner_protocol } } });
    const acceptance_options = b.addOptions();
    acceptance_options.addOption([32]u8, "snapshot_id", @splat(0));
    acceptance_module.addOptions("snapshot-options", acceptance_options);
    const acceptance_exe = b.addExecutable(.{ .name = "action-test-runner", .root_module = acceptance_module });
    const registered_generator = b.addExecutable(.{ .name = "registered-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("fixture.zig"), .target = b.graph.host, .imports = &.{.{ .name = "keymap-project", .module = b.dependency("keymap_project", .{}).module("keymap-project") }} }) });
    const registered_run = b.addRunArtifact(registered_generator);
    const registered_source = registered_run.addOutputFileArg("danish.zig");
    registered_run.addArg("danish");
    const registered_handler = b.dependency("keymap_project", .{}).module("keymap-project").import_table.get("rollercole-profile").?;
    const registered_profile = b.createModule(.{ .root_source_file = registered_source, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "callback_0", .module = registered_handler } } });
    const registered_module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.graph.host, .imports = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "selected-profile", .module = registered_profile }, .{ .name = "runner-protocol", .module = runner_protocol } } });
    registered_module.addOptions("snapshot-options", acceptance_options);
    const registered_exe = b.addExecutable(.{ .name = "registered-test-runner", .root_module = registered_module });
    const test_options = b.addOptions();
    test_options.addOptionPath("runner_path", exe.getEmittedBin());
    test_options.addOptionPath("action_runner_path", acceptance_exe.getEmittedBin());
    test_options.addOptionPath("registered_runner_path", registered_exe.getEmittedBin());
    tests.root_module.addOptions("options", test_options);
    b.step("test", "Test the generated native draft runner without device APIs").dependOn(&b.addRunArtifact(tests).step);
}
