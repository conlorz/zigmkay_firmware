const std = @import("std");
const build_utils = @import("build_utils.zig");

pub const Published = struct { module: *std.Build.Module, tests: *std.Build.Step };

// Firmware calls this separately for each MicroZig configuration; portable imports stay shared.
pub fn processor(b: *std.Build, root: std.Build.LazyPath, model: *std.Build.Module, protocol: *std.Build.Module) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = root.path(b, "src/root.zig"),
        .imports = &.{
            .{ .name = "layout-model", .module = model },
            .{ .name = "device-protocol", .module = protocol },
        },
    });
}

pub fn publish(b: *std.Build, root: std.Build.LazyPath, model: *std.Build.Module, protocol: *std.Build.Module) Published {
    const module = processor(b, root, model, protocol);
    const tests = b.step("core-test", "Run original processor corpus");
    build_utils.add_test_steps(b, root, module, tests, "tests");
    return .{ .module = module, .tests = tests };
}

pub fn build(b: *std.Build) void {
    const published = publish(b, b.path("."), b.dependency("layout_model", .{}).module("layout-model"), b.dependency("device_protocol", .{}).module("device-protocol"));
    b.modules.put(b.allocator, "zigmkay", published.module) catch @panic("Out of memory");
    const tests = b.step("test", "Run core tests");
    tests.dependOn(published.tests);
    b.default_step = tests;
}
