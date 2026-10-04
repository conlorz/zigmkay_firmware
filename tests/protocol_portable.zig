const protocol = @import("device-protocol");
const companion = @import("companion-model");

export fn receive_report(bytes: [*]const u8, len: usize) bool {
    var state = companion.State.init(.{ .key_count = 34, .layer_count = 4 }) catch return false;
    state.receive(bytes[0..len]) catch return false;
    _ = protocol.encode(.{ .sequence = 0, .event = .{ .layers = .{ .active_layers = state.active_layers, .highest_layer = state.highest_layer, .modifiers = state.modifiers } } }, state.dimensions) catch return false;
    return true;
}

export fn decode_session_packet(bytes: [*]const u8, len: usize) bool {
    const dimensions = (companion.State.init(.{ .key_count = 34, .layer_count = 4 }) catch return false).dimensions;
    const packet = protocol.decodePacket(bytes[0..len], dimensions, .device_to_host) catch return false;
    _ = protocol.encodePacket(packet, dimensions, .device_to_host) catch return false;
    return true;
}

export fn canonical_identity_byte(index: u8) u8 {
    if (index >= 16) return 0;
    const identity = protocol.computeIdentity(.{
        .board_id = .{ 'l', 'k', '7', 0, 0, 0, 0, 0 },
        .profile_id = .{ 't', 'e', 's', 't', 0, 0, 0, 0 },
        .dimensions = .{ .key_count = 1, .layer_count = 1 },
        .keys = &.{null},
        .sides = &.{.X},
        .combos = &.{},
        .encoders = &.{},
        .callbacks = &.{},
    }) catch return 0;
    return identity.digest[index];
}
