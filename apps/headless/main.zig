const std = @import("std");
const protocol = @import("device-protocol");
const companion = @import("companion-model");
const lk7 = @import("lk7-keymap");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) {
        std.debug.print("Usage: zigmkay-companion-headless-lk7 <reports.bin>\n", .{});
        std.process.exit(1);
    }
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(64 * 1024 * 1024)) catch |err| {
        std.debug.print("Cannot read replay file '{s}': {s}\n", .{ args[1], @errorName(err) });
        std.process.exit(1);
    };
    defer init.gpa.free(bytes);
    if (bytes.len % protocol.report_size != 0) {
        std.debug.print("Truncated replay: {d} bytes; reports must have complete {d}-byte boundaries\n", .{ bytes.len, protocol.report_size });
        std.process.exit(1);
    }
    var state = try companion.State.init(lk7.dimensions);
    var offset: usize = 0;
    while (offset < bytes.len) : (offset += protocol.report_size) {
        state.receive(bytes[offset..][0..protocol.report_size]) catch |err| {
            std.debug.print("Replay report {d} at byte {d}: {s}\n", .{ offset / protocol.report_size, offset, @errorName(err) });
            std.process.exit(1);
        };
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    const writer = &stdout.interface;
    try writer.print("board=lk7\nkeys={d}\nlayers={d}\nreports={d}\npressed=[", .{ lk7.dimensions.key_count, lk7.dimensions.layer_count, bytes.len / protocol.report_size });
    var comma = false;
    for (state.pressed, 0..) |pressed, index| if (pressed) {
        if (comma) try writer.writeAll(",");
        try writer.print("{d}", .{index});
        comma = true;
    };
    try writer.print("]\nactive_layers={d}\nhighest_layer={d}\nmodifiers=0x{x:0>2}\nlast_sequence=", .{ state.active_layers, state.highest_layer, state.modifiers.toByte() });
    if (state.last_sequence) |sequence| try writer.print("{d}", .{sequence}) else try writer.writeAll("none");
    try writer.print("\nneeds_resync={s}\n", .{if (state.needs_resync) "true" else "false"});
    try writer.flush();
}
