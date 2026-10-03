const std = @import("std");
pub const Published = struct { module: *std.Build.Module, tests: *std.Build.Step };
pub fn publish(b: *std.Build, root: std.Build.LazyPath, keycodes: *std.Build.Module, target: std.Build.ResolvedTarget) Published {
    const module = b.addModule("zkeymap", .{ .root_source_file = root.path(b, "src/root.zig"), .target = target, .imports = &.{.{ .name = "zkeycodes", .module = keycodes }} });
    addPlatformSources(b, root, module, target);
    const tests = b.step("zkeymap-test", "Run native keyboard label and mapping tests");
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    return .{ .module = module, .tests = tests };
}
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});
    const published = publish(b, b.path("."), b.dependency("zkeycodes", .{}).module("zkeycodes"), target);
    b.installArtifact(b.addLibrary(.{ .name = "zkeymap", .root_module = published.module }));
    const tests = b.step("test", "Run key mapping tests");
    tests.dependOn(published.tests);
    b.default_step = tests;
    const example = b.addExecutable(.{ .name = "keymap-example", .root_module = b.createModule(.{ .root_source_file = b.path("example/main.zig"), .target = target, .imports = &.{.{ .name = "zkeymap", .module = published.module }} }) });
    b.step("example", "Compile the native layout example").dependOn(&b.addInstallArtifact(example, .{}).step);
}
fn addPlatformSources(b: *std.Build, root: std.Build.LazyPath, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    switch (target.result.os.tag) {
        .macos => {
            module.addCSourceFile(.{ .file = root.path(b, "src/platform/macos.c"), .flags = &.{"-std=c11"} });
            module.linkFramework("Carbon", .{});
            module.link_libc = true;
        },
        .windows => {
            module.addCSourceFile(.{ .file = root.path(b, "src/platform/windows.c"), .flags = &.{"-std=c11"} });
            module.link_libc = true;
        },
        .linux => {
            if (b.graph.host.result.os.tag == .linux) {
                module.addCSourceFile(.{ .file = root.path(b, "src/platform/linux.c"), .flags = &.{"-std=c11"} });
                module.linkSystemLibrary("xkbcommon", .{});
            }
            module.link_libc = true;
        },
        else => {},
    }
}
