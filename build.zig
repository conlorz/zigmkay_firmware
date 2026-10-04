const std = @import("std");

// Mise schedules package commands. This graph owns cross-package tests only.
pub fn build(b: *std.Build) void {
    const model = b.dependency("layout_model", .{}).module("layout-model");
    const protocol = b.dependency("device_protocol", .{}).module("device-protocol");
    const companion = b.dependency("companion_model", .{}).module("companion-model");
    const firmware = b.dependency("zigmkay", .{}).module("zigmkay");
    const keycodes_dep = b.dependency("zkeycodes", .{});
    const keycodes = keycodes_dep.module("zkeycodes");
    const keymap = b.createModule(.{
        .root_source_file = b.path("keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig"),
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware },
            .{ .name = "zkeycodes", .module = keycodes },
        },
    });
    const physical = b.createModule(.{
        .root_source_file = b.path("keyboards/my_keyboards/rollercole/lk7_physical_layout.zig"),
        .imports = &.{.{ .name = "layout-model", .module = model }},
    });
    const adapter = b.createModule(.{
        .root_source_file = b.path("zigmkay-companion/src/live_adapter.zig"),
        .imports = &.{
            .{ .name = "device-protocol", .module = protocol },
            .{ .name = "companion-model", .module = companion },
        },
    });
    const tests = b.step("test", "Run integration tests (mise test runs all packages)");
    b.default_step = tests;
    for ([_][]const u8{
        "tests/test_device_protocol.zig",     "tests/test_protocol_session.zig",
        "tests/test_lk7_layout.zig",          "tests/test_lk7_gaming_layer.zig",
        "tests/test_lk7_trace.zig",           "tests/test_observer_inputs.zig",
        "tests/test_telemetry_transport.zig", "tests/test_live_integration.zig",
        "tests/test_shared_types.zig",
    }) |source| {
        const module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = b.graph.host,
            .imports = &.{
                .{ .name = "layout-model", .module = model },
                .{ .name = "device-protocol", .module = protocol },
                .{ .name = "companion-model", .module = companion },
                .{ .name = "zigmkay", .module = firmware },
                .{ .name = "zkeycodes", .module = keycodes },
                .{ .name = "lk7-keymap", .module = keymap },
                .{ .name = "lk7-physical", .module = physical },
                .{ .name = "live-adapter", .module = adapter },
            },
        });
        tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    }
    const portable = b.addObject(.{ .name = "protocol-check", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/protocol_portable.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .imports = &.{
            .{ .name = "device-protocol", .module = protocol },
            .{ .name = "companion-model", .module = companion },
        },
    }) });
    tests.dependOn(&portable.step);
    const headless = @import("apps/headless/build.zig").publish(b, b.path("apps/headless/main.zig"), keymap, protocol, companion);
    const checker_module = b.createModule(.{ .root_source_file = b.path("tools/check_local.zig"), .target = b.graph.host });
    checker_module.addAnonymousImport("board-catalog", .{ .root_source_file = b.path("keyboards/boards.zon") });
    const checker = b.addExecutable(.{ .name = "check-local", .root_module = checker_module });
    const sentinel = b.addExecutable(.{ .name = "offline-sentinel", .root_module = b.createModule(.{ .root_source_file = b.path("tools/sentinel.zig"), .target = b.graph.host }) });
    const process_checks = b.addExecutable(.{ .name = "process-checks", .root_module = b.createModule(.{
        .root_source_file = b.path("tools/process_checks.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "device-protocol", .module = protocol },
            .{ .name = "lk7-keymap", .module = keymap },
        },
    }) });
    process_checks.root_module.addAnonymousImport("board-catalog", .{ .root_source_file = b.path("keyboards/boards.zon") });
    const checks = b.addRunArtifact(process_checks);
    // These inspect mise configuration and CLI discovery outside Zig's file DAG.
    checks.has_side_effects = true;
    checks.addArtifactArg(headless);
    checks.addFileArg(b.path("tests/fixtures/lk7_trace.bin"));
    checks.addArtifactArg(keycodes_dep.artifact("zkeycodes"));
    checks.addArg(b.graph.zig_exe);
    checks.addDirectoryArg(b.path("."));
    checks.addArtifactArg(checker);
    checks.addArtifactArg(sentinel);
    _ = checks.addOutputDirectoryArg("scratch");
    tests.dependOn(&checks.step);
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/source_inventory.zig"),
        .target = b.graph.host,
    }) })).step);
    for ([_][]const u8{ "check", "check-full" }) |name| {
        const run = b.addRunArtifact(checker);
        run.has_side_effects = true;
        run.addArg(b.graph.zig_exe);
        run.addDirectoryArg(b.path("."));
        run.addArtifactArg(sentinel);
        _ = run.addOutputDirectoryArg("scratch");
        if (std.mem.eql(u8, name, "check-full")) run.addArg("--full");
        b.step(name, "Guard mise aggregate checks against source mutation and hardware").dependOn(&run.step);
    }
}
