const std = @import("std");
const microzig = @import("microzig");
pub const registry = @import("generated/keyboard_registry.zig");
pub const MicroBuild = microzig.MicroBuild(.{ .rp2xxx = true });

pub const Shared = struct {
    profile: ?[]const u8 = null,
    processor_root: std.Build.LazyPath,
    model: *std.Build.Module,
    protocol: *std.Build.Module,
    keycodes: *std.Build.Module,
};
pub const Published = struct { uf2: std.Build.LazyPath, install: *std.Build.Step };

pub fn publish(b: *std.Build, mb: *MicroBuild, root: std.Build.LazyPath, entry: registry.Entry, shared: Shared, optimize: std.builtin.OptimizeMode, destination: []const u8) Published {
    const firmware = mb.add_firmware(.{
        .name = "zigmkay",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico,
        .optimize = optimize,
        .root_source_file = root.path(b, entry.source),
    });
    const processor = @import("zigmkay").processor(b, shared.processor_root, shared.model, shared.protocol);
    if (std.mem.eql(u8, entry.name, "lk7")) {
        const profile = if (shared.profile) |path| blk: {
            const selected = @import("keymap_project").selector.load(b, path, processor, shared.keycodes, shared.model) catch |err| @panic(b.fmt("Invalid LK7 export: {s}", .{@errorName(err)}));
            if (!std.mem.eql(u8, &selected.manifest.board_id, &[_]u8{ 'l', 'k', '7', 0, 0, 0, 0, 0 })) @panic("Export board does not match LK7");
            break :blk selected.module;
        } else b.createModule(.{ .root_source_file = root.path(b, "my_keyboards/rollercole/shared_keymap_3x5_2.zig"), .imports = &.{ .{ .name = "zigmkay", .module = processor }, .{ .name = "zkeycodes", .module = shared.keycodes } } });
        firmware.add_app_import("selected_profile", profile, .{});
    }
    firmware.add_app_import("zigmkay", processor, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", shared.keycodes, .{});
    firmware.add_app_import("layout-model", shared.model, .{});
    firmware.add_app_import("device-protocol", shared.protocol, .{});
    const uf2 = firmware.get_emitted_bin(.{ .uf2 = .{ .family_id = .RP2040 } });
    const install = b.addInstallFileWithDir(uf2, .prefix, destination);
    return .{ .uf2 = uf2, .install = &install.step };
}

pub fn find(name: []const u8) ?registry.Entry {
    for (registry.entries) |entry| if (std.mem.eql(u8, entry.name, name)) return entry;
    return null;
}

pub fn available(b: *std.Build) []const u8 {
    var names: [registry.entries.len][]const u8 = undefined;
    for (registry.entries, 0..) |entry, i| names[i] = entry.name;
    return std.mem.join(b.allocator, ", ", &names) catch @panic("Out of memory");
}

// Selection errors belong only to the requested step, so unrelated commands still work.
pub fn selectionError(b: *std.Build, selection: ?[]const u8) ?[]const u8 {
    const name = selection orelse return b.fmt("Missing -Dkeyboard; available IDs: {s}", .{available(b)});
    if (find(name) == null) return b.fmt("Unknown keyboard '{s}'; available IDs: {s}", .{ name, available(b) });
    return null;
}

pub fn commands(b: *std.Build, root: std.Build.LazyPath, microzig_dep: *std.Build.Dependency, shared: Shared, selected: ?[]const u8, optimize: std.builtin.OptimizeMode) void {
    const usb_module = b.createModule(.{ .root_source_file = microzig_dep.path("core/src/core/usb.zig") });
    const processor_module = @import("zigmkay").processor(b, shared.processor_root, shared.model, shared.protocol);
    const usb_tests = b.createModule(.{
        .root_source_file = root.path(b, "tests/usb_runtime_probe.zig"),
        .target = b.graph.host,
        .imports = &.{ .{ .name = "usb", .module = usb_module }, .{ .name = "zigmkay", .module = processor_module } },
    });
    const usb_check = b.step("usb-test", "Test real pinned USB driver initialization without hardware");
    usb_check.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = usb_tests })).step);
    const target_probe = b.addObject(.{ .name = "usb-runtime-probe", .root_module = b.createModule(.{
        .root_source_file = root.path(b, "tests/usb_runtime_probe.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .thumb, .os_tag = .freestanding, .abi = .eabi, .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus } }),
        .optimize = .ReleaseSmall,
        .imports = &.{ .{ .name = "usb", .module = usb_module }, .{ .name = "zigmkay", .module = processor_module } },
    }) });
    _ = target_probe.getEmittedAsm();
    usb_check.dependOn(&target_probe.step);
    const chosen = b.step("firmware", "Compile and install the explicitly selected board");
    const all = b.step("firmware-all", "Compile and install every catalog entry");
    const list = b.addRunArtifact(b.addExecutable(.{ .name = "list-keyboards", .root_module = b.createModule(.{ .root_source_file = root.path(b, "list.zig"), .target = b.graph.host }) }));
    b.step("list-keyboards", "List sorted IDs and companion support").dependOn(&list.step);
    b.step("ls", "Alias for list-keyboards").dependOn(&list.step);
    if (selectionError(b, selected)) |message| chosen.dependOn(&b.addFail(message).step);
    if (shared.profile != null and selected != null and !std.mem.eql(u8, selected.?, "lk7")) chosen.dependOn(&b.addFail("Editor profile export currently supports LK7 only").step);
    const mb = MicroBuild.init(b, microzig_dep) orelse return;
    for (registry.entries) |entry| {
        const result = publish(b, mb, root, entry, shared, optimize, b.fmt("firmware/{s}/zigmkay.uf2", .{entry.name}));
        all.dependOn(result.install);
        if (selected) |name| if (std.mem.eql(u8, name, entry.name)) {
            chosen.dependOn(result.install);
        };
    }
}
