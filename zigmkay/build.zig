const std = @import("std");

pub const microzig = @import("microzig");
const build_utils = @import("build_utils.zig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const zigmkay_mod = b.addModule("zigmkay", .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = "src/root.zig" },
        },
    });
    zigmkay_mod.addImport("layout-model", b.dependency("layout_model", .{}).module("layout-model"));
    zigmkay_mod.addImport("device-protocol", b.dependency("device_protocol", .{}).module("device-protocol"));
    const test_run_step = b.step("test", "Run unit tests");
    build_utils.add_test_steps(b, zigmkay_mod, test_run_step, "tests");
}
