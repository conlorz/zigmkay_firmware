const std = @import("std");
const p = @import("root.zig");
const board = p.Board{ .id = .{ 'l', 'k', '7', 0, 0, 0, 0, 0 }, .physical_layout = "fixture", .key_ids = &.{ "left_0", "right_0" }, .sides = &.{ .L, .R } };
const fixture = p.Document{
    .schema_version = 1,
    .board_id = board.id,
    .profile_id = .{ 't', 'e', 's', 't', 0, 0, 0, 0 },
    .physical_layout = "fixture",
    .name = "Test",
    .key_ids = board.key_ids,
    .layers = &.{
        .{ .id = 10, .name = "Base", .actions = &.{ .{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 4, .tap_modifiers = .{ .left_gui = true }, .dead = true }, .one_shot = .{ .layer_id = 20 }, .custom = 253, .media_key = .VolumeUp, .mouse_action = .WheelDown }, .hold = .{ .layer_id = 20, .hold_modifiers = .{ .right_alt = true } }, .tapping_term = .{ .ms = 180 }, .retro_tapping = true } }, null } },
        .{ .id = 20, .name = "Navigation", .actions = &.{ .none, .{ .tap_with_autofire = .{ .tap = .{ .key_press = .{ .tap_keycode = 80 } }, .initial_delay = .{ .ms = 200 }, .repeat_interval = .{ .ms = 50 } } } } },
    },
    .combos = &.{.{ .key_ids = .{ "left_0", "right_0" }, .layer_id = 10, .timeout = .{ .ms = 40 }, .action = .{ .tap_only = .{ .key_press = .{ .tap_keycode = 252 } } } }},
};
test "typed ZON round trip preserves simultaneous tap fields transparency and explicit none" {
    const gpa = std.testing.allocator;
    try p.validate(fixture, board);
    const bytes = try p.serialize(gpa, fixture);
    defer gpa.free(bytes);
    const doc = try p.parse(gpa, bytes, null);
    defer p.deinit(gpa, doc);
    try p.validate(doc, board);
    const second = try p.serialize(gpa, doc);
    defer gpa.free(second);
    try std.testing.expectEqualStrings(bytes, second);
    try std.testing.expect(doc.layers[0].actions[1] == null);
    try std.testing.expect(doc.layers[1].actions[0].? == .none);
    const lowered = try p.lowerAction(doc, doc.layers[0].actions[0].?);
    try std.testing.expectEqual(@as(?u4, 1), lowered.tap_hold.hold.hold_layer);
    try std.testing.expectEqual(@as(?u4, 1), lowered.tap_hold.tap.one_shot.?.hold_layer);
    try std.testing.expectEqual(@as(u8, 8), lowered.tap_hold.tap.key_press.?.tap_modifiers.toByte());
    try std.testing.expect(lowered.tap_hold.tap.key_press.?.dead);
    try std.testing.expect(lowered.tap_hold.retro_tapping);
    try std.testing.expectEqual(@as(?u8, 253), lowered.tap_hold.tap.custom);
    try std.testing.expectEqual(.VolumeUp, lowered.tap_hold.tap.media_key.?);
    try std.testing.expectEqual(.WheelDown, lowered.tap_hold.tap.mouse_action.?);
}
test "parser rejects executable syntax unknown fields and unsupported versions" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.ParseZon, p.parse(gpa, "@import(\"malicious.zig\")", null));
    const bytes = try p.serialize(gpa, fixture);
    defer gpa.free(bytes);
    const invalid = try std.fmt.allocPrint(gpa, ".{{ .unknown = true, {s}", .{bytes[2..]});
    defer gpa.free(invalid);
    try std.testing.expectError(error.ParseZon, p.parse(gpa, invalid, null));
    var future = fixture;
    future.schema_version = 2;
    const future_bytes = try p.serialize(gpa, future);
    defer gpa.free(future_bytes);
    try std.testing.expectError(error.UnsupportedVersion, p.parse(gpa, future_bytes, null));
    const huge = try gpa.alloc(u8, p.Limits.document_bytes + 1);
    defer gpa.free(huge);
    try std.testing.expectError(error.DocumentTooLarge, p.parse(gpa, huge, null));
}
test "validation rejects wrong geometry duplicate layers and reversed duplicate combos" {
    var doc = fixture;
    doc.physical_layout = "wrong";
    try std.testing.expectError(error.InvalidBoard, p.validate(doc, board));
    doc = fixture;
    var layers = fixture.layers[0..2].*;
    layers[1].id = 10;
    doc.layers = &layers;
    try std.testing.expectError(error.DuplicateLayer, p.validate(doc, board));
    doc = fixture;
    var combos = [_]p.Combo{ fixture.combos[0], fixture.combos[0] };
    combos[1].key_ids = .{ "right_0", "left_0" };
    doc.combos = &combos;
    try std.testing.expectError(error.DuplicateCombo, p.validate(doc, board));
}
test "stable layer references and opaque callback index constraints prevent unsafe deletion" {
    try std.testing.expectError(error.LayerReferenced, p.canDeleteLayer(fixture, 20));
    var doc = fixture;
    doc.layers = &.{ fixture.layers[1], .{ .id = 30, .name = "Unused", .actions = &.{ null, null } }, .{ .id = 40, .name = "Last", .actions = &.{ null, null } } };
    try p.canDeleteLayer(doc, 30);
    doc.callbacks = &.{.{ .kind = .attached, .binding = "callback.zig", .ids = &.{1}, .sources = &.{.{ .path = "callback.zig", .digest = @splat(0) }} }};
    try std.testing.expectError(error.CallbackIndexLocked, p.canDeleteLayer(doc, 30));
    try p.canDeleteLayer(doc, 40);
}
test "paths custom IDs and timing fail without discarding action fields" {
    for ([_][]const u8{ "../escape.zig", "/absolute.zig", "a//b.zig", "a/./b.zig", "a\\b.zig", "bad:drive.zig" }) |path| try std.testing.expect(!p.pathValid(path));
    try std.testing.expect(p.pathValid("helpers/util.zig"));
    try std.testing.expectError(error.InvalidCallback, p.lowerTap(fixture, .{ .custom = 1 }));
    try std.testing.expectError(error.InvalidCallback, p.lowerHold(fixture, .{ .custom = 253 }));
    try std.testing.expectError(error.InvalidTiming, p.lowerAction(fixture, .{ .tap_with_autofire = .{ .tap = .{}, .initial_delay = .{}, .repeat_interval = .{} } }));
    try std.testing.expectError(error.InvalidLayer, p.lowerHold(fixture, .{ .layer_id = 999 }));
}
