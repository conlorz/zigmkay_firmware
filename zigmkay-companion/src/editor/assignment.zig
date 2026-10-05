const p = @import("keymap-project");
const types = @import("layout-model");
pub const Chord = types.KeyCodeFire;
pub fn tap(value: ?p.Action, chord: Chord) p.Action {
    var action = value orelse p.Action{ .tap_only = .{} };
    switch (action) {
        .none => action = .{ .tap_only = .{ .key_press = chord } },
        .tap_only => |*t| t.key_press = chord,
        .tap_hold => |*th| th.tap.key_press = chord,
        .tap_with_autofire => |*af| af.tap.key_press = chord,
        .hold_only => |h| action = .{ .tap_hold = .{ .tap = .{ .key_press = chord }, .hold = h, .tapping_term = .{ .ms = 180 } } },
    }
    return action;
}
pub fn hold(value: ?p.Action, chord: Chord) !p.Action {
    if (chord.tap_keycode < 224 or chord.tap_keycode > 231) return error.DropModifierKeyOnHold;
    const bits = chord.tap_modifiers.toByte() | (@as(u8, 1) << @intCast(chord.tap_keycode - 224));
    const mods: types.Modifiers = @bitCast(bits);
    var action = value orelse p.Action{ .hold_only = .{} };
    switch (action) {
        .none => action = .{ .hold_only = .{ .hold_modifiers = mods } },
        .hold_only => |*h| h.hold_modifiers = mods,
        .tap_hold => |*th| th.hold.hold_modifiers = mods,
        .tap_only => |t| action = .{ .tap_hold = .{ .tap = t, .hold = .{ .hold_modifiers = mods }, .tapping_term = .{ .ms = 180 } } },
        .tap_with_autofire => return error.AutofireCannotHaveHold,
    }
    return action;
}
test "chord assignment preserves simultaneous actions and tap hold settings" {
    const std = @import("std");
    const original = p.Action{ .tap_hold = .{ .tap = .{ .custom = 1, .media_key = .VolumeUp }, .hold = .{ .layer_id = 2, .custom = 2 }, .tapping_term = .{ .ms = 231 }, .retro_tapping = true } };
    const chord = Chord{ .tap_keycode = 30, .tap_modifiers = .{ .left_shift = true, .left_alt = true } };
    const changed = tap(original, chord).tap_hold;
    try std.testing.expectEqualDeep(chord, changed.tap.key_press.?);
    try std.testing.expectEqual(original.tap_hold.tap.custom, changed.tap.custom);
    try std.testing.expectEqual(original.tap_hold.tap.media_key, changed.tap.media_key);
    try std.testing.expectEqualDeep(original.tap_hold.hold, changed.hold);
    try std.testing.expectEqual(@as(u16, 231), changed.tapping_term.ms);
    try std.testing.expect(changed.retro_tapping);
    const held = (try hold(original, .{ .tap_keycode = 225 })).tap_hold;
    try std.testing.expectEqualDeep(original.tap_hold.tap, held.tap);
    try std.testing.expectEqual(original.tap_hold.hold.layer_id, held.hold.layer_id);
    try std.testing.expect(held.hold.hold_modifiers.left_shift);
    try std.testing.expectError(error.DropModifierKeyOnHold, hold(original, chord));
}
