const std = @import("std");

// Independent literals: they precede codec implementation and define the wire.
pub const hello: [32]u8 = .{ 0xA7, 2, 10, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0x44, 0x33, 0x22, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
// Board "lk7", profile "danish", digest bytes 00..0f, dimensions 34/4.
pub const identity_parts: [3][32]u8 = .{
    .{ 0xA7, 2, 11, 18, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 0, 3, 0x44, 0x33, 0x22, 0x11, 'l', 'k', '7', 0, 0, 0, 0, 0, 'd', 'a', 'n', 'i', 0, 0 },
    .{ 0xA7, 2, 11, 18, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 1, 3, 's', 'h', 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 0 },
    .{ 0xA7, 2, 11, 8, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 2, 3, 12, 13, 14, 15, 34, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
};
pub const snapshot_request: [32]u8 = .{ 0xA7, 2, 12, 0, 0x44, 0x33, 0x22, 0x11, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
// Keys 0 and 30 held, arrows active, persistent left control. Next delta=65535.
pub const snapshot_parts: [2][32]u8 = .{
    .{ 0xA7, 2, 13, 12, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 2, 0, 0, 2, 1, 0, 0, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0xA7, 2, 13, 12, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 2, 0, 1, 2, 0, 0, 0, 0, 0, 0, 3, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
};
pub const release: [32]u8 = .{ 0xA7, 2, 14, 4, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
pub const overflow: [32]u8 = .{ 0xA7, 2, 16, 1, 0x44, 0x33, 0x22, 0x11, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

test "v2 independent fixtures define complete report boundaries and zero padding" {
    const reports = .{hello} ++ identity_parts ++ .{snapshot_request} ++ snapshot_parts ++ .{ release, overflow };
    for (reports) |report| {
        try std.testing.expectEqual(@as(u8, 0xA7), report[0]);
        try std.testing.expectEqual(@as(u8, 2), report[1]);
        try std.testing.expect(report[3] <= 20);
        for (report[12 + report[3] ..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    }
}
