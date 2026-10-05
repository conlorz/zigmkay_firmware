const std = @import("std");
pub const Shared = struct { keymap: *std.Build.Module, core: *std.Build.Module, keycodes: *std.Build.Module, keymap_native: *std.Build.Module, protocol: *std.Build.Module, companion: *std.Build.Module, model: *std.Build.Module, physical: *std.Build.Module };
pub const Published = struct { exe: *std.Build.Step.Compile, tests: *std.Build.Step };
pub fn publish(b: *std.Build, root: std.Build.LazyPath, deps: *std.Build, shared: Shared) Published {
    const display = b.createModule(.{ .root_source_file = root.path(b, "src/lk7_keymap.zig"), .imports = &.{ .{ .name = "firmware_keymap", .module = shared.keymap }, .{ .name = "zigmkay", .module = shared.core }, .{ .name = "device-protocol", .module = shared.protocol } } });
    const dvui = deps.dependency("dvui", .{ .target = b.graph.host, .optimize = .Debug, .backend = .sdl3 });
    const icons = deps.dependency("icons", .{});
    const toolchain = b.addOptions();
    toolchain.addOption([]const u8, "zig_exe", b.graph.zig_exe);
    toolchain.addOption([]const u8, "build_root", b.build_root.path orelse ".");
    toolchain.addOptionPath("flash_exe", deps.dependency("zig_flash", .{}).artifact("zig_flash").getEmittedBin());
    const module = b.createModule(.{ .root_source_file = root.path(b, "src/main.zig"), .target = b.graph.host, .imports = &.{
        .{ .name = "dvui", .module = dvui.module("dvui_sdl3") }, .{ .name = "sdl-backend", .module = dvui.module("sdl3") }, .{ .name = "icons", .module = icons.module("icons") },                                                    .{ .name = "keymap", .module = display },                                                                 .{ .name = "zigmkay", .module = shared.core },                                                           .{ .name = "zkeymap", .module = shared.keymap_native }, .{ .name = "device-protocol", .module = shared.protocol }, .{ .name = "companion-model", .module = shared.companion },
        .{ .name = "layout-model", .module = shared.model },     .{ .name = "lk7-physical", .module = shared.physical },    .{ .name = "keymap-project", .module = deps.dependency("keymap_project", .{}).module("keymap-project") }, .{ .name = "companion-jobs", .module = deps.dependency("companion_jobs", .{}).module("companion-jobs") }, .{ .name = "runner-protocol", .module = deps.dependency("keymap_test", .{}).module("runner-protocol") },
    } });
    const exe = b.addExecutable(.{ .name = "zigmkay_companion", .root_module = module });
    module.addOptions("editor-toolchain", toolchain);
    module.addImport("zkeycodes", shared.keycodes);
    const tests = b.addRunArtifact(b.addTest(.{ .root_module = module }));
    tests.setCwd(root);
    return .{ .exe = exe, .tests = &tests.step };
}
pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});
    const core = b.dependency("zigmkay", .{}).module("zigmkay");
    const keycodes = b.dependency("zkeycodes", .{}).module("zkeycodes");
    const model = b.dependency("layout_model", .{}).module("layout-model");
    const keymap = if (b.option([]const u8, "profile", "Absolute verified LK7 export directory")) |path| blk: {
        const selected = @import("keymap_project").selector.load(b, path, core, keycodes, model) catch |err| @panic(b.fmt("Invalid editor profile: {s}", .{@errorName(err)}));
        if (!std.mem.eql(u8, &selected.manifest.board_id, &[_]u8{ 'l', 'k', '7', 0, 0, 0, 0, 0 })) @panic("Companion profile must be LK7");
        break :blk selected.module;
    } else b.dependency("keymap_project", .{}).module("default-profile");
    const physical = b.dependency("keymap_project", .{}).module("physical-layout");
    const gui = publish(b, b.path("."), b, .{ .keymap = keymap, .core = core, .keycodes = keycodes, .keymap_native = b.dependency("zkeymap", .{}).module("zkeymap"), .protocol = b.dependency("device_protocol", .{}).module("device-protocol"), .companion = b.dependency("companion_model", .{}).module("companion-model"), .model = model, .physical = physical });
    b.installArtifact(gui.exe);
    b.step("test", "Run companion component tests").dependOn(gui.tests);
    const run = b.addRunArtifact(gui.exe);
    run.setCwd(b.path(".."));
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run the offline GUI; --live opts into HID").dependOn(&run.step);
    const capture_tool = b.addExecutable(.{ .name = "editor-capture", .root_module = b.createModule(.{ .root_source_file = b.path("src/editor/capture_runner.zig"), .target = b.graph.host }) });
    capture_tool.root_module.addImport("companion-jobs", b.dependency("companion_jobs", .{}).module("companion-jobs"));
    const captures = b.addRunArtifact(capture_tool);
    captures.addArtifactArg(gui.exe);
    captures.setCwd(b.path(".."));
    b.step("editor-check", "Capture both themes/scales and run semantic scenarios offline").dependOn(&captures.step);
    const golden_check = b.addRunArtifact(capture_tool);
    golden_check.addArtifactArg(gui.exe);
    golden_check.addArg("docs/plans/goldens/07-editor");
    golden_check.setCwd(b.path(".."));
    b.step("editor-golden-check", "Check explicitly approved screenshots without refreshing them").dependOn(&golden_check.step);
}
