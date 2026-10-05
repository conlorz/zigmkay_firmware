const core = @import("layout-model");
fn withModifiers(fire: core.KeyCodeFire, modifiers: core.Modifiers) core.KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    copy.tap_modifiers = copy.tap_modifiers.add(modifiers);
    return copy;
}
pub fn L_CTL(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .left_ctrl = true });
}
pub fn R_CTL(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .right_ctrl = true });
}
pub fn L_SFT(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .left_shift = true });
}
pub fn R_SFT(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .right_shift = true });
}
pub fn L_GUI(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .left_gui = true });
}
pub fn R_GUI(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .right_gui = true });
}
pub fn L_ALT(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .left_alt = true });
}
pub fn R_ALT(fire: core.KeyCodeFire) core.KeyCodeFire {
    return withModifiers(fire, .{ .right_alt = true });
}
/// Sets the dead key flag on a core.KeyCodeFire. Dead keys send the keycode followed by a
/// spacebar press to cancel the dead key combination.
pub fn DEAD(fire: core.KeyCodeFire) core.KeyCodeFire {
    var copy = fire;
    copy.dead = true;
    return copy;
}

pub const LabelEntry = struct {
    value: core.KeyCodeFire,
    label: []const u8,
    short_label: []const u8,
};

/// Looks up `keycode` in `table` by matching both `tap_keycode` and `tap_modifiers`.
/// This distinguishes e.g. `S(KC_1)` ("EXLM") from plain `KC_1` ("1").
pub fn getLabel(table: []const LabelEntry, keycode: core.KeyCodeFire, shortest: bool) ?[]const u8 {
    const key_mods: u8 = keycode.tap_modifiers.toByte();
    for (table) |entry| {
        const entry_mods: u8 = entry.value.tap_modifiers.toByte();
        if (entry.value.tap_keycode == keycode.tap_keycode and entry_mods == key_mods) {
            return if (shortest) entry.short_label else entry.label;
        }
    }
    return null;
}
