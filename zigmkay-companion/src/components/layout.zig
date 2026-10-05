//! Shared physical identities and geometry; processing sides do not place keys.
const std = @import("std");
const dvui = @import("dvui");
const model = @import("layout-model");
const physical = @import("lk7-physical");
const cache = @import("cache.zig");
const key = @import("key.zig");
pub const Placement = struct { id: u16, key_index: u8, rect: dvui.Rect, rotation: f32 };
pub const Fit = struct {
    scale: f32,
    offset_x: f32,
    offset_y: f32,
    pub fn place(self: Fit, item: model.physical_layout.Key) Placement {
        return .{ .id = item.id, .key_index = item.key_index, .rotation = item.rotation * std.math.pi / 180, .rect = .{
            .x = self.offset_x + item.x * self.scale,
            .y = self.offset_y + item.y * self.scale,
            .w = item.width * self.scale,
            .h = item.height * self.scale,
        } };
    }
};
/// Geometry rotation is degrees around the key center. Include rotated corners
/// in fitted bounds, preserving non-square keys and arbitrary stable IDs.
pub fn fit(items: []const model.physical_layout.Key, bounds: dvui.Rect) Fit {
    var min_x: f32 = std.math.inf(f32);
    var min_y = min_x;
    var max_x: f32 = -min_x;
    var max_y = max_x;
    for (items) |item| {
        const angle = item.rotation * std.math.pi / 180;
        const half_w = (@abs(@cos(angle)) * item.width + @abs(@sin(angle)) * item.height) / 2;
        const half_h = (@abs(@sin(angle)) * item.width + @abs(@cos(angle)) * item.height) / 2;
        const cx = item.x + item.width / 2;
        const cy = item.y + item.height / 2;
        min_x = @min(min_x, cx - half_w);
        max_x = @max(max_x, cx + half_w);
        min_y = @min(min_y, cy - half_h);
        max_y = @max(max_y, cy + half_h);
    }
    if (items.len == 0) return .{ .scale = 0, .offset_x = bounds.x, .offset_y = bounds.y };
    const scale = @max(0, @min(bounds.w / (max_x - min_x), bounds.h / (max_y - min_y)));
    return .{ .scale = scale, .offset_x = bounds.x + (bounds.w - (max_x - min_x) * scale) / 2 - min_x * scale, .offset_y = bounds.y + (bounds.h - (max_y - min_y) * scale) / 2 - min_y * scale };
}
pub fn draw(label_cache: *const cache.LabelCache, layer: usize, pressed: *const [128]bool, mods: model.Modifiers, stale: bool, bounds: dvui.Rect) !void {
    return drawGuided(label_cache, layer, pressed, mods, stale, bounds, null, null);
}
pub fn drawGuided(label_cache: *const cache.LabelCache, layer: usize, pressed: *const [128]bool, mods: model.Modifiers, stale: bool, bounds: dvui.Rect, targets: ?*const [128]bool, active_layers: ?u16) !void {
    return drawPractice(label_cache, layer, pressed, mods, stale, bounds, targets, null, layer, active_layers);
}
pub fn drawPractice(label_cache: *const cache.LabelCache, layer: usize, pressed: *const [128]bool, mods: model.Modifiers, stale: bool, bounds: dvui.Rect, targets: ?*const [128]bool, holds: ?*const [128]bool, hold_source_layer: usize, active_layers: ?u16) !void {
    const fitted = fit(&physical.keys, bounds);
    if (fitted.scale <= 0) return;
    for (physical.keys) |item| {
        const placed = fitted.place(item);
        var rect = placed.rect;
        const padding = @min(3, fitted.scale * 0.06);
        rect.x += padding;
        rect.y += padding;
        rect.w -= padding * 2;
        rect.h -= padding * 2;
        const entry = if (active_layers) |active| label_cache.lookupActive(layer, placed.key_index, mods, active) else label_cache.lookup(layer, placed.key_index, mods);
        const hold = if (holds) |hints| hints[placed.key_index] else false;
        const content = if (hold) label_cache.lookup(hold_source_layer, placed.key_index, .{}).* else entry.*;
        try key.drawPracticeKey(layer, placed.id, rect, placed.rotation, fitted.scale / 45, content, !stale and pressed[placed.key_index], if (targets) |hints| hints[placed.key_index] else false, hold);
    }
}
test "shared physical identity thumbs and resized fitted bounds" {
    try model.physical_layout.validateKeys(&physical.keys, .{ .key_count = 34, .layer_count = 2 });
    for ([_]dvui.Rect{ .{ .x = 10, .y = 80, .w = 700, .h = 240 }, .{ .x = 0, .y = 0, .w = 340, .h = 160 } }) |bounds| {
        const fitted = fit(&physical.keys, bounds);
        for (physical.keys) |item| {
            const placed = fitted.place(item);
            try std.testing.expectEqual(item.id, placed.id);
            try std.testing.expectEqual(item.key_index, placed.key_index);
            try std.testing.expect(placed.rect.x >= bounds.x - 0.001 and placed.rect.y >= bounds.y - 0.001);
            try std.testing.expect(placed.rect.x + placed.rect.w <= bounds.x + bounds.w + 0.001);
            try std.testing.expect(placed.rect.y + placed.rect.h <= bounds.y + bounds.h + 0.001);
        }
    }
    try std.testing.expectEqual(model.physical_layout.Group.thumb, physical.keys[30].group);
    try std.testing.expectEqual(@as(u16, 0x280), physical.keys[32].id);
}
test "rotation and non-square geometry contribute to fitted bounds" {
    const item = model.physical_layout.Key{ .id = 123, .key_index = 0, .x = 0, .y = 0, .width = 2, .height = 1, .rotation = 90, .hand = .neutral };
    const fitted = fit(&.{item}, .{ .w = 100, .h = 100 });
    try std.testing.expectApproxEqAbs(@as(f32, 50), fitted.scale, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), fitted.place(item).rotation, 0.001);
}
