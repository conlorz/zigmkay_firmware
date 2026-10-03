const std = @import("std");
const model = @import("layout-model");
const core = @import("zigmkay").core;
const codes = @import("zkeycodes");

test "firmware and keycode helpers share portable action types" {
    try std.testing.expect(core.KeyDef == model.KeyDef);
    try std.testing.expect(core.KeyCodeFire == model.KeyCodeFire);
    const key: model.KeyCodeFire = codes.layouts.danish.Q;
    const label_entry = codes.core.LabelEntry{ .value = key, .label = "Q", .short_label = "Q" };
    try std.testing.expectEqual(key, label_entry.value);
    try std.testing.expectEqual(@as(u8, 0x04), codes.core.L_ALT(key).tap_modifiers.toByte());
}
