const std = @import("std");
pub const Published = struct { exe: *std.Build.Step.Compile, tests: *std.Build.Step };
pub fn publish(b: *std.Build, root: std.Build.LazyPath) Published {
    const module = b.createModule(.{ .root_source_file = root.path(b, "src/main.zig"), .target = b.graph.host, .optimize = .ReleaseSafe });
    const exe = b.addExecutable(.{ .name = "zig_flash", .root_module = module });
    const tests = &b.addRunArtifact(b.addTest(.{ .root_module = module })).step;
    return .{ .exe = exe, .tests = tests };
}
pub fn build(b: *std.Build) void {
    const published = publish(b, b.path("."));
    b.installArtifact(published.exe);
    b.step("test", "Run volume path tests without device access").dependOn(published.tests);
    const run = b.addRunArtifact(published.exe);
    if (b.args) |args| run.addArgs(args);
    b.step("flash", "Explicitly run the flasher with input and mount arguments").dependOn(&run.step);
    const ci = b.step("ci", "Compile host tooling for supported operating systems");
    for ([_]std.Target.Query{ .{ .cpu_arch = .aarch64, .os_tag = .macos }, .{ .cpu_arch = .aarch64, .os_tag = .linux }, .{ .cpu_arch = .x86_64, .os_tag = .linux }, .{ .cpu_arch = .x86_64, .os_tag = .windows }, .{ .cpu_arch = .aarch64, .os_tag = .windows } }) |target| {
        const exe = b.addExecutable(.{ .name = "zig_flash", .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = b.resolveTargetQuery(target), .optimize = .ReleaseSafe }) });
        ci.dependOn(&exe.step);
    }
}
