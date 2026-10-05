const std = @import("std");

pub fn fixture(b: *std.Build, project: *std.Build.Module, name: []const u8, mode: ?[]const u8) std.Build.LazyPath {
    const generator = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
        .root_source_file = b.path("fixture.zig"),
        .target = b.graph.host,
        .imports = &.{.{ .name = "keymap-project", .module = project }},
    }) });
    const run = b.addRunArtifact(generator);
    const source = run.addOutputFileArg("keymap.zig");
    if (mode) |arg| run.addArg(arg);
    return source;
}

pub fn runner(b: *std.Build, name: []const u8, firmware: *std.Build.Module, profile: *std.Build.Module, protocol: *std.Build.Module, snapshot_id: [32]u8) *std.Build.Step.Compile {
    const options = b.addOptions();
    options.addOption([32]u8, "snapshot_id", snapshot_id);
    const module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .imports = &.{
            .{ .name = "zigmkay", .module = firmware },
            .{ .name = "selected-profile", .module = profile },
            .{ .name = "runner-protocol", .module = protocol },
        },
    });
    module.addOptions("snapshot-options", options);
    return b.addExecutable(.{ .name = name, .root_module = module });
}
