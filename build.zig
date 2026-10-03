const std = @import("std");

pub fn build(b: *std.Build) void {
    const selection = b.option([]const u8, "keyboard", "Select a firmware or companion board explicitly");
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Firmware optimization (default ReleaseSafe)") orelse .ReleaseSafe;
    _ = b.standardTargetOptions(.{});
    const model_dep = b.dependency("layout_model", .{});
    const core_dep = b.dependency("zigmkay", .{});
    const keycodes_dep = b.dependency("zkeycodes", .{});
    const protocol_dep = b.dependency("device_protocol", .{});
    const companion_dep = b.dependency("companion_model", .{});
    const model = @import("layout_model").publish(b, model_dep.path("."));
    const protocol = @import("device_protocol").publish(b, protocol_dep.path("."), model.module);
    const companion = @import("companion_model").publish(b, companion_dep.path("."), model.module, protocol);
    const firmware = @import("zigmkay").publish(b, core_dep.path("."), model.module, protocol);
    const keycodes = @import("zkeycodes").publish(b, keycodes_dep.path("."), model.module, .Debug);
    const test_step = b.step("test", "Run portable and firmware core tests");
    test_step.dependOn(firmware.tests);
    test_step.dependOn(keycodes.tests);
    const check_generated = b.step("check-generated", "Check committed generated sources");
    check_generated.dependOn(keycodes.check);
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
    const keyboards = b.dependency("keyboards", .{});
    @import("keyboards").api.commands(b, keyboards.path("."), b.dependency("microzig", .{}), .{
        .processor_root = core_dep.path("."),
        .model = model.module,
        .protocol = protocol,
        .keycodes = keycodes.module,
    }, selection, optimize);
    const registry_module = b.createModule(.{ .root_source_file = b.path("tools/registry/main.zig"), .target = b.graph.host });
    const registry_exe = b.addExecutable(.{ .name = "keyboard-registry", .root_module = registry_module });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = registry_module })).step);
    const generate_registry = b.addRunArtifact(registry_exe);
    generate_registry.addFileArg(keyboards.path("boards.zon"));
    generate_registry.addDirectoryArg(keyboards.path("."));
    const generated_registry = generate_registry.addOutputFileArg("keyboard_registry.zig");
    const check_registry = b.addRunArtifact(registry_exe);
    check_registry.addFileArg(keyboards.path("boards.zon"));
    check_registry.addDirectoryArg(keyboards.path("."));
    check_registry.addFileArg(generated_registry);
    check_registry.addArg("--compare");
    check_registry.addFileArg(keyboards.path("generated/keyboard_registry.zig"));
    // This step was already created above for keycode checks.
    const generated_checks = b.step("registry-check-generated", "Check registry against catalog");
    generated_checks.dependOn(&check_registry.step);
    check_generated.dependOn(generated_checks);
    const headless = b.addExecutable(.{
        .name = "zigmkay-companion-headless-lk7",
        .root_module = b.createModule(.{
            .root_source_file = b.path("apps/headless/main.zig"),
            .target = b.graph.host,
            .imports = &.{
                .{ .name = "lk7-keymap", .module = keymap },
                .{ .name = "device-protocol", .module = protocol },
                .{ .name = "companion-model", .module = companion },
            },
        }),
    });
    const companion_step = b.step("companion", "Build the selected offline headless companion");
    b.step("companion-headless", "Build the selected offline replay executable").dependOn(companion_step);
    if (@import("keyboards").api.selectionError(b, selection)) |message| {
        companion_step.dependOn(&b.addFail(message).step);
    } else if (!@import("keyboards").api.find(selection.?).?.companion) {
        companion_step.dependOn(&b.addFail(b.fmt("Unsupported companion board '{s}'; supported companion IDs: lk7", .{selection.?})).step);
    } else {
        companion_step.dependOn(&b.addInstallArtifact(headless, .{}).step);
    }
    const process_checks = b.addExecutable(.{ .name = "process-checks", .root_module = b.createModule(.{ .root_source_file = b.path("tools/process_checks.zig"), .target = b.graph.host }) });
    const adapter_checks = b.addRunArtifact(process_checks);
    adapter_checks.addArtifactArg(headless);
    adapter_checks.addFileArg(b.path("tests/fixtures/lk7_trace.bin"));
    adapter_checks.addArtifactArg(keycodes.generator);
    adapter_checks.addArg(b.graph.zig_exe);
    adapter_checks.addDirectoryArg(b.path("."));
    _ = adapter_checks.addOutputDirectoryArg("scratch");
    test_step.dependOn(&adapter_checks.step);
}
