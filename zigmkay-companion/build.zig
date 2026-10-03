const std = @import("std");
pub const Shared = struct { keymap: *std.Build.Module, core: *std.Build.Module, keycodes: *std.Build.Module, keymap_native: *std.Build.Module, protocol: *std.Build.Module, companion: *std.Build.Module };
pub const Published = struct { exe: *std.Build.Step.Compile, tests: *std.Build.Step };
pub fn publish(b: *std.Build, root: std.Build.LazyPath, deps: *std.Build, shared: Shared) Published {
    const display = b.createModule(.{ .root_source_file = root.path(b, "src/lk7_keymap.zig"), .imports = &.{ .{ .name = "firmware_keymap", .module = shared.keymap }, .{ .name = "zigmkay", .module = shared.core } } });
    const dvui = deps.dependency("dvui", .{ .target = b.graph.host, .optimize = .Debug, .backend = .sdl3 });
    const icons = deps.dependency("icons", .{});
    const module = b.createModule(.{ .root_source_file = root.path(b, "src/main.zig"), .target = b.graph.host, .imports = &.{
        .{ .name = "dvui", .module = dvui.module("dvui_sdl3") }, .{ .name = "sdl-backend", .module = dvui.module("sdl3") }, .{ .name = "icons", .module = icons.module("icons") }, .{ .name = "keymap", .module = display }, .{ .name = "zigmkay", .module = shared.core }, .{ .name = "zkeymap", .module = shared.keymap_native }, .{ .name = "device-protocol", .module = shared.protocol }, .{ .name = "companion-model", .module = shared.companion },
    } });
    const exe = b.addExecutable(.{ .name = "zigmkay_companion", .root_module = module });
    return .{ .exe = exe, .tests = &b.addRunArtifact(b.addTest(.{ .root_module = module })).step };
}
pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});
    const core = b.dependency("zigmkay", .{}).module("zigmkay");
    const keycodes = b.dependency("zkeycodes", .{}).module("zkeycodes");
    const keymap = b.createModule(.{ .root_source_file = b.path("../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig"), .imports = &.{ .{ .name = "zigmkay", .module = core }, .{ .name = "zkeycodes", .module = keycodes } } });
    const gui = publish(b, b.path("."), b, .{ .keymap = keymap, .core = core, .keycodes = keycodes, .keymap_native = b.dependency("zkeymap", .{}).module("zkeymap"), .protocol = b.dependency("device_protocol", .{}).module("device-protocol"), .companion = b.dependency("companion_model", .{}).module("companion-model") });
    b.installArtifact(gui.exe);
    b.step("test", "Run companion component tests").dependOn(gui.tests);
    const run = b.addRunArtifact(gui.exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run the offline GUI; --live opts into HID").dependOn(&run.step);
}
