const std = @import("std");

pub fn publish(b: *std.Build, source: std.Build.LazyPath, keymap: *std.Build.Module, protocol: *std.Build.Module, companion: *std.Build.Module) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "zigmkay-companion-headless-lk7",
        .root_module = b.createModule(.{
            .root_source_file = source,
            .target = b.graph.host,
            .imports = &.{
                .{ .name = "lk7-keymap", .module = keymap },
                .{ .name = "device-protocol", .module = protocol },
                .{ .name = "companion-model", .module = companion },
            },
        }),
    });
}

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    const keymap = b.createModule(.{
        .root_source_file = b.path("../../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig"),
        .imports = &.{
            .{ .name = "zigmkay", .module = b.dependency("zigmkay", .{}).module("zigmkay") },
            .{ .name = "zkeycodes", .module = b.dependency("zkeycodes", .{}).module("zkeycodes") },
        },
    });
    const exe = publish(b, b.path("main.zig"), keymap, b.dependency("device_protocol", .{}).module("device-protocol"), b.dependency("companion_model", .{}).module("companion-model"));
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    run.setCwd(b.path("../.."));
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Replay reports offline, paths relative to monorepo root").dependOn(&run.step);
}
