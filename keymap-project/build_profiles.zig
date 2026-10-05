//! Default profile publication shared by host builds and MicroZig processors.
const std = @import("std");

pub fn defaultProfile(b: *std.Build, keyboards: std.Build.LazyPath, processor: *std.Build.Module, keycodes: *std.Build.Module) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = keyboards.path(b, "my_keyboards/rollercole/shared_keymap_3x5_2.zig"),
        .imports = &.{
            .{ .name = "zigmkay", .module = processor },
            .{ .name = "zkeycodes", .module = keycodes },
        },
    });
}

pub fn physicalLayout(b: *std.Build, keyboards: std.Build.LazyPath, model: *std.Build.Module) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = keyboards.path(b, "my_keyboards/rollercole/lk7_physical_layout.zig"),
        .imports = &.{.{ .name = "layout-model", .module = model }},
    });
}
