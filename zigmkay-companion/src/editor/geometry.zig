const std = @import("std");
pub const Rect = struct { x: f32, y: f32, w: f32, h: f32 };
pub const Panel = enum { toolbar, sidebar, physical, inspector, os, testing, callbacks };
pub const reference = [7]Rect{
    .{ .x = 0, .y = 0, .w = 1536, .h = 67 },
    .{ .x = 15, .y = 77, .w = 247, .h = 932 },
    .{ .x = 273, .y = 77, .w = 869, .h = 445 },
    .{ .x = 1153, .y = 77, .w = 368, .h = 445 },
    .{ .x = 273, .y = 533, .w = 1248, .h = 380 },
    .{ .x = 273, .y = 923, .w = 785, .h = 87 },
    .{ .x = 1068, .y = 923, .w = 453, .h = 87 },
};
pub const minimum = Rect{ .x = 0, .y = 0, .w = 1280, .h = 900 };
/// Smaller windows scroll a full legible reference canvas; fonts/hit targets do
/// not scale down. Larger windows gain breathing room around the same canvas.
pub fn panel(which: Panel) Rect {
    return reference[@intFromEnum(which)];
}
test "reference panels match visual specification and remain disjoint" {
    for (reference[1..], 1..) |a, i| {
        try std.testing.expect(a.x >= 15 and a.y >= 77 and a.x + a.w <= 1521 and a.y + a.h <= 1010);
        for (reference[i + 1 ..]) |b| try std.testing.expect(a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y);
    }
}
