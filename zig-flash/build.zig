const std = @import("std");

pub fn build(b: *std.Build) void {
    // const optimize = b.standardOptimizeOption(.{});

    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "zig_flash",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .imports = &.{},
        }),
    });

    _ = addFlashStep(b, exe, .{});

    // CI: compile for all supported targets
    const ci_step = b.step("ci", "Compile for all supported targets");
    setupCi(b, ci_step);
}

pub const FlashOptions = struct {
    step_name: []const u8 = "flash",
    input_name: []const u8 = "firmware.uf2",
    input_path: []const u8 = "zig-out/firmware",
    mount_point_or_label: ?[]const u8 = null,
};

pub fn addFlashStep(b: *std.Build, exe: *std.Build.Step.Compile, opts: FlashOptions) *std.Build.Step {
    b.installArtifact(exe);

    const run_step = b.step(opts.step_name, "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    const input_path = b.pathJoin(&.{ opts.input_path, opts.input_name });
    run_cmd.addArg(input_path);
    if (opts.mount_point_or_label) |mp|
        run_cmd.addArg(mp);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    return run_step;
}

// Test build on different systems
pub fn setupCi(b: *std.Build, step: *std.Build.Step) void {
    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .aarch64, .os_tag = .windows },
    };

    for (targets) |t| {
        const target = b.resolveTargetQuery(t);

        const exe = b.addExecutable(.{ .name = "zig_flash", .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .imports = &.{},
        }) });

        step.dependOn(&exe.step);
    }
}
