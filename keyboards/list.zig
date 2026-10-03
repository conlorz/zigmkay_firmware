const std = @import("std");
const registry = @import("generated/keyboard_registry.zig");
pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(init.io, &buffer);
    for (registry.entries) |entry| try out.interface.print("{s}: companion={s}, split={s}, encoder={s}\n", .{ entry.name, if (entry.companion) "lk7 offline" else "unsupported", if (entry.split) "yes" else "no", if (entry.encoder) "yes" else "no" });
    try out.interface.flush();
}
