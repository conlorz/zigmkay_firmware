const std = @import("std");

const Scores = struct {
    values: [4]u16,

    fn total(self: Scores) u32 {
        var sum: u32 = 0;
        for (self.values) |value| {
            sum += value;
        }
        return sum;
    }
};

test "sum an array" {
    const scores = Scores{ .values = .{ 3, 5, 8, 13 } };
    try std.testing.expectEqual(@as(u32, 29), scores.total());
}
