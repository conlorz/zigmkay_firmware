const std = @import("std");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "version")) {
        try std.Io.File.stdout().writeStreamingAll(init.io, "0.15.2\n");
        return;
    }
    const marker = init.environ_map.get("ZIGMKAY_SENTINEL") orelse return error.HardwareToolExecuted;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = marker, .data = args[0] });
    std.process.exit(99);
}
