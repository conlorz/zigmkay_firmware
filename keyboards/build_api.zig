const std = @import("std");
const microzig = @import("microzig");
pub const registry = @import("generated/keyboard_registry.zig");
pub const MicroBuild = microzig.MicroBuild(.{ .rp2xxx = true });

pub const Shared = struct {
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
    firmware.add_app_import("zigmkay", processor, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", shared.keycodes, .{});
    firmware.add_app_import("layout-model", shared.model, .{});
    const uf2 = firmware.get_emitted_bin(.{ .uf2 = .{} });
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
    const chosen = b.step("firmware", "Compile and install the explicitly selected board");
    const all = b.step("firmware-all", "Compile and install every catalog entry");
    b.step("flash", "Reserved for later hardware transport").dependOn(&b.addFail("flash is not implemented in phase 2").step);
    const list = b.addSystemCommand(&.{ "python3", "-c" });
    var listing: std.ArrayList(u8) = .empty;
    for (registry.entries) |entry| listing.appendSlice(b.allocator, b.fmt("{s}: companion={s}, split={s}, encoder={s}\n", .{ entry.name, if (entry.companion) "lk7 offline" else "unsupported", if (entry.split) "yes" else "no", if (entry.encoder) "yes" else "no" })) catch @panic("Out of memory");
    // Python receives the data as an argument, never interpolated into code.
    list.addArg("import sys; print(sys.argv[1], end='')");
    list.addArg(listing.items);
    b.step("list-keyboards", "List sorted IDs and companion support").dependOn(&list.step);
    if (selectionError(b, selected)) |message| chosen.dependOn(&b.addFail(message).step);
    const mb = MicroBuild.init(b, microzig_dep) orelse return;
    for (registry.entries) |entry| {
        const result = publish(b, mb, root, entry, shared, optimize, b.fmt("firmware/{s}/zigmkay.uf2", .{entry.name}));
        all.dependOn(result.install);
        if (selected) |name| if (std.mem.eql(u8, name, entry.name)) {
            chosen.dependOn(result.install);
        };
    }
}
