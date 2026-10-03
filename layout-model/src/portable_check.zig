const model = @import("layout-model");

export fn action_tag(action: *const model.KeyDef) u8 {
    return switch (action.*) {
        .none => 0,
        .tap_only => 1,
        .hold_only => 2,
        .tap_hold => 3,
        .tap_with_autofire => 4,
    };
}

export fn modifier_mask(modifiers: u8) u8 {
    return model.Modifiers.fromByte(modifiers).toByte();
}
