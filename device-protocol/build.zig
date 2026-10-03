const std = @import("std");
pub fn build(b: *std.Build) void {
    _ = b.addModule("device-protocol", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "layout-model", .module = b.dependency("layout_model", .{}).module("layout-model") },
        },
    });
}
