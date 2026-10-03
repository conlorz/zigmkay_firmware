const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zkeycodes_dep = b.dependency("zkeycodes", .{});
    const zkeycodes_mod = zkeycodes_dep.module("zkeycodes");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zkeycodes", zkeycodes_mod);
    addPlatformSources(b, lib_mod, target);

    const lib = b.addLibrary(.{
        .name = "zkeymap",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    // Public module for downstream packages
    const public_mod = b.addModule("zkeymap", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    public_mod.addImport("zkeycodes", zkeycodes_mod);
    addPlatformSources(b, public_mod, target);

    // Tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("zkeycodes", zkeycodes_mod);
    addPlatformSources(b, test_mod, target);

    const tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Example from README (runnable + tested)
    const example_exe_mod = b.createModule(.{
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_exe_mod.addImport("zkeymap", lib_mod);

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_module = example_exe_mod,
    });
    b.installArtifact(example_exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(example_exe);
    run_step.dependOn(&run_cmd.step);

    const example_test_mod = b.createModule(.{
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_test_mod.addImport("zkeymap", lib_mod);

    const example_tests = b.addTest(.{
        .name = "example-test",
        .root_module = example_test_mod,
    });
    const run_example_tests = b.addRunArtifact(example_tests);
    test_step.dependOn(&run_example_tests.step);

    // CI: compile for all supported targets
    const ci_step = b.step("ci", "Compile for all supported targets");
    setupCi(b, ci_step);
}

pub fn setupCi(b: *std.Build, step: *std.Build.Step) void {
    const targets: []const std.Target.Query = &.{
        // macOS cross-compilation requires the Apple SDK; build natively instead.
        // .{ .cpu_arch = .aarch64, .os_tag = .macos },
        // .{ .cpu_arch = .x86_64,  .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        // .{ .cpu_arch = .aarch64, .os_tag = .windows },
    };

    for (targets) |t| {
        const target = b.resolveTargetQuery(t);

        const mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = .Debug,
        });
        addPlatformSources(b, mod, target);

        const lib = b.addLibrary(.{
            .name = b.fmt("zkeymap-{s}-{s}", .{
                @tagName(t.cpu_arch.?),
                @tagName(t.os_tag.?),
            }),
            .root_module = mod,
        });

        step.dependOn(&lib.step);
    }
}

fn addPlatformSources(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
) void {
    switch (target.result.os.tag) {
        .macos => {
            mod.addCSourceFile(.{
                .file = b.path("src/platform/macos.c"),
                .flags = &.{"-std=c11"},
            });
            mod.linkFramework("Carbon", .{});
            mod.link_libc = true;
        },
        .windows => {
            // Zig bundles MinGW headers, so windows.c compiles on any host.
            mod.addCSourceFile(.{
                .file = b.path("src/platform/windows.c"),
                .flags = &.{"-std=c11"},
            });
            mod.link_libc = true;
        },
        .linux => {
            // xkbcommon is a system library; its headers are only available on
            // a Linux build host (or with a custom sysroot). When cross-compiling
            // from macOS/Windows, we skip the C glue — the Zig extern declarations
            // in linux.zig still type-check, and the C symbols are resolved by
            // consumers who link against libxkbcommon on their Linux system.
            if (b.graph.host.result.os.tag == .linux) {
                mod.addCSourceFile(.{
                    .file = b.path("src/platform/linux.c"),
                    .flags = &.{"-std=c11"},
                });
                mod.linkSystemLibrary("xkbcommon", .{});
            }
            mod.link_libc = true;
        },
        else => {},
    }
}
