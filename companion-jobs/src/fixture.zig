const std = @import("std");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (std.mem.eql(u8, args[1], "hang")) {
        try std.Io.sleep(init.io, .fromSeconds(10), .awake);
        return;
    }
    if (std.mem.eql(u8, args[1], "crash")) std.process.exit(7);
    if (std.mem.eql(u8, args[1], "flood")) {
        const block: [4096]u8 = @splat('x');
        for (0..300) |_| try std.Io.File.stdout().writeStreamingAll(init.io, &block);
        return;
    }
    try std.Io.File.stdout().writeStreamingAll(init.io, args[1]);
}
