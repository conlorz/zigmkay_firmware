const std = @import("std");

pub const Published = struct { module: *std.Build.Module, tests: *std.Build.Step, portable: *std.Build.Step };

pub fn publish(b: *std.Build, root: std.Build.LazyPath) Published {
    const module = b.addModule("layout-model", .{ .root_source_file = root.path(b, "src/root.zig") });
    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = root.path(b, "src/root.zig"),
        .target = b.graph.host,
    }) });
    const test_step = b.step("model-test", "Test portable keyboard types");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const check = b.step("check-portable", "Compile model for native and freestanding Wasm");
    for ([_]std.Build.ResolvedTarget{ b.graph.host, b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }) }) |target| {
        const object = b.addObject(.{
            .name = "layout-model-check",
            .root_module = b.createModule(.{
                .root_source_file = root.path(b, "src/portable_check.zig"),
                .target = target,
                .imports = &.{.{ .name = "layout-model", .module = module }},
            }),
        });
        check.dependOn(&object.step);
    }
    return .{ .module = module, .tests = test_step, .portable = check };
}

pub fn build(b: *std.Build) void {
    const published = publish(b, b.path("."));
    const tests = b.step("test", "Run model checks");
    tests.dependOn(published.tests);
    tests.dependOn(published.portable);
    b.default_step = tests;
}
