const std = @import("std");

pub fn build(b: *std.Build) void {
    const module = b.addModule("layout-model", .{ .root_source_file = b.path("src/root.zig") });
    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.graph.host,
    }) });
    b.step("test", "Test portable keyboard types").dependOn(&b.addRunArtifact(tests).step);
    const check = b.step("check-portable", "Compile model for native and freestanding Wasm");
    for ([_]std.Build.ResolvedTarget{ b.graph.host, b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }) }) |target| {
        const object = b.addObject(.{
            .name = "layout-model-check",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/portable_check.zig"),
                .target = target,
                .imports = &.{.{ .name = "layout-model", .module = module }},
            }),
        });
        check.dependOn(&object.step);
    }
}
