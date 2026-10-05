const std = @import("std");

fn readCount(text: ?[]const u8) !u16 {
    const value = text orelse return error.MissingCount;
    return std.fmt.parseInt(u16, value, 10);
}

fn defaultCount(text: ?[]const u8) u16 {
    return readCount(text) catch 1;
}

test "optional input and errors" {
    try std.testing.expectEqual(@as(u16, 12), try readCount("12"));
    try std.testing.expectError(error.MissingCount, readCount(null));
    try std.testing.expectEqual(@as(u16, 1), defaultCount(null));
    try std.testing.expectEqual(@as(u16, 1), defaultCount("bad"));
}
