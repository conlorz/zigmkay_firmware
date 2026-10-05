const std = @import("std");

fn twice(value: i32) i32 {
    return value * 2;
}

fn distance(a: i32, b: i32) u32 {
    return @intCast(@abs(a - b));
}

test "small functions" {
    try std.testing.expectEqual(@as(i32, 14), twice(7));
    try std.testing.expectEqual(@as(i32, -6), twice(-3));
    try std.testing.expectEqual(@as(u32, 9), distance(2, 11));
    try std.testing.expectEqual(@as(u32, 0), distance(4, 4));
}
