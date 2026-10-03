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

export fn validate_geometry(keys: [*]const model.physical_layout.Key, len: usize, key_count: u8, layer_count: u8) bool {
    if (key_count > 127 or layer_count > 15) return false;
    model.physical_layout.validateKeys(keys[0..len], .{
        .key_count = @intCast(key_count),
        .layer_count = @intCast(layer_count),
    }) catch return false;
    return true;
}
