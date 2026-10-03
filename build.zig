const std = @import("std");

pub fn build(b: *std.Build) void {
    const model_dep = b.dependency("layout_model", .{});
    const core_dep = b.dependency("zigmkay", .{});
    const keycodes_dep = b.dependency("zkeycodes", .{});
    const protocol_dep = b.dependency("device_protocol", .{});
    const companion_dep = b.dependency("companion_model", .{});
    const model = @import("layout_model").publish(b, model_dep.path("."));
    const protocol = @import("device_protocol").publish(b, protocol_dep.path("."), model.module);
    const companion = @import("companion_model").publish(b, companion_dep.path("."), model.module, protocol);
    const firmware = @import("zigmkay").publish(b, core_dep.path("."), model.module, protocol);
    const keycodes = @import("zkeycodes").publish(b, keycodes_dep.path("."), model.module);
    const test_step = b.step("test", "Run portable and firmware core tests");
    test_step.dependOn(firmware.tests);
    test_step.dependOn(keycodes.tests);
    b.step("check-generated", "Check committed generated sources").dependOn(keycodes.check);
    b.default_step = test_step;
    const codec_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/test_device_protocol.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "layout-model", .module = model.module },
            .{ .name = "device-protocol", .module = protocol },
            .{ .name = "companion-model", .module = companion },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(codec_test).step);
    const portable = b.addObject(.{
        .name = "protocol-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/protocol_portable.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .imports = &.{
                .{ .name = "device-protocol", .module = protocol },
                .{ .name = "companion-model", .module = companion },
            },
        }),
    });
    test_step.dependOn(&portable.step);
    const keymap = b.addModule("lk7-keymap", .{
        .root_source_file = b.path("keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig"),
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware.module },
            .{ .name = "zkeycodes", .module = keycodes.module },
        },
    });
    const physical = b.addModule("lk7-physical", .{
        .root_source_file = b.path("keyboards/my_keyboards/rollercole/lk7_physical_layout.zig"),
        .imports = &.{.{ .name = "layout-model", .module = model.module }},
    });
    const layout_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/test_lk7_layout.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "layout-model", .module = model.module },
            .{ .name = "lk7-keymap", .module = keymap },
            .{ .name = "lk7-physical", .module = physical },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(layout_test).step);
    const gaming_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/test_lk7_gaming_layer.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware.module },
            .{ .name = "lk7-keymap", .module = keymap },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(gaming_test).step);

    for ([_][]const u8{ "tests/test_lk7_trace.zig", "tests/test_observer_inputs.zig" }) |source| {
        const trace_test = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = b.graph.host,
            .imports = &.{
                .{ .name = "zigmkay", .module = firmware.module },
                .{ .name = "lk7-keymap", .module = keymap },
                .{ .name = "device-protocol", .module = protocol },
                .{ .name = "companion-model", .module = companion },
            },
        }) });
        test_step.dependOn(&b.addRunArtifact(trace_test).step);
    }
    const types_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/test_shared_types.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware.module },
            .{ .name = "layout-model", .module = model.module },
            .{ .name = "zkeycodes", .module = keycodes.module },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(types_test).step);
    test_step.dependOn(model.tests);
    test_step.dependOn(model.portable);
}
