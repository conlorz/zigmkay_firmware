const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.graph.host });
    const exe = b.addExecutable(.{ .name = "keyboard-registry", .root_module = module });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Generate or check the registry independently of the firmware graph").dependOn(&run.step);
    b.step("test", "Test registry validation and atomic output").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    const generate = b.addRunArtifact(exe);
    generate.addFileArg(b.path("../../keyboards/boards.zon"));
    generate.addDirectoryArg(b.path("../../keyboards"));
    const generated = generate.addOutputFileArg("keyboard_registry.zig");
    const check = b.addRunArtifact(exe);
    check.addFileArg(b.path("../../keyboards/boards.zon"));
    check.addDirectoryArg(b.path("../../keyboards"));
    check.addFileArg(generated);
    check.addArg("--compare");
    check.addFileArg(b.path("../../keyboards/generated/keyboard_registry.zig"));
    b.step("check-generated", "Check committed registry without mutation").dependOn(&check.step);
    const regenerate = b.addRunArtifact(exe);
    regenerate.addFileArg(b.path("../../keyboards/boards.zon"));
    regenerate.addDirectoryArg(b.path("../../keyboards"));
    regenerate.addArg(b.path("../../keyboards/generated/keyboard_registry.zig").getPath(b));
    b.step("regenerate", "Explicitly update committed registry").dependOn(&regenerate.step);
}
