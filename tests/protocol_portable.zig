const protocol = @import("device-protocol");
const companion = @import("companion-model");

export fn receive_report(bytes: [*]const u8, len: usize) bool {
    var state = companion.State.init(.{ .key_count = 34, .layer_count = 4 }) catch return false;
    state.receive(bytes[0..len]) catch return false;
    _ = protocol.encode(.{ .sequence = 0, .event = .{ .layers = .{ .active_layers = state.active_layers, .highest_layer = state.highest_layer, .modifiers = state.modifiers } } }, state.dimensions) catch return false;
    return true;
}
