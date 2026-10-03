const std = @import("std");
const model = @import("layout-model");

pub const report_size = 32;
pub const Report = [report_size]u8;
pub const KeyEvent = struct { pressed: bool, key_index: model.KeyIndex, layer: model.LayerIndex, modifiers: model.Modifiers };
pub const LayerState = struct { active_layers: u16, highest_layer: model.LayerIndex, modifiers: model.Modifiers };
pub const Event = union(enum) { key: KeyEvent, layers: LayerState };
pub const Message = struct { sequence: u16, event: Event };
pub const ProtocolError = error{ InvalidDimensions, InvalidLength, InvalidMagic, UnsupportedVersion, UnsupportedKind, InvalidPayloadLength, InvalidReserved, InvalidPadding, InvalidBoolean, InvalidKeyIndex, InvalidLayer, InvalidLayerMask };

pub fn validate(message: Message, dimensions: model.KeymapDimensions) ProtocolError!void {
    if (dimensions.key_count == 0 or dimensions.layer_count == 0) return error.InvalidDimensions;
    switch (message.event) {
        .key => |key| {
            if (key.key_index >= dimensions.key_count) return error.InvalidKeyIndex;
            if (key.layer >= dimensions.layer_count) return error.InvalidLayer;
        },
        .layers => |layers| {
            if (layers.highest_layer >= dimensions.layer_count) return error.InvalidLayer;
            const allowed = (@as(u16, 1) << dimensions.layer_count) - 1;
            if (layers.active_layers & ~allowed != 0 or layers.active_layers & 1 == 0) return error.InvalidLayerMask;
            const highest: model.LayerIndex = @intCast(15 - @clz(layers.active_layers));
            if (highest != layers.highest_layer) return error.InvalidLayerMask;
        },
    }
}

pub fn encode(message: Message, dimensions: model.KeymapDimensions) ProtocolError!Report {
    try validate(message, dimensions);
    var report: Report = @splat(0);
    report[0] = 0xA7;
    report[1] = 1;
    report[3] = 4;
    std.mem.writeInt(u16, report[4..6], message.sequence, .little);
    switch (message.event) {
        .key => |key| {
            report[2] = 3;
            report[8] = @intFromBool(key.pressed);
            report[9] = key.key_index;
            report[10] = key.layer;
            report[11] = key.modifiers.toByte();
        },
        .layers => |layers| {
            report[2] = 1;
            std.mem.writeInt(u16, report[8..10], layers.active_layers, .little);
            report[10] = layers.highest_layer;
            report[11] = layers.modifiers.toByte();
        },
    }
    return report;
}

pub fn decode(bytes: []const u8, dimensions: model.KeymapDimensions) ProtocolError!Message {
    if (bytes.len != report_size) return error.InvalidLength;
    if (bytes[0] != 0xA7) return error.InvalidMagic;
    if (bytes[1] != 1) return error.UnsupportedVersion;
    if (bytes[2] != 1 and bytes[2] != 3) return error.UnsupportedKind;
    if (bytes[3] != 4) return error.InvalidPayloadLength;
    if (bytes[6] != 0 or bytes[7] != 0) return error.InvalidReserved;
    for (bytes[12..]) |byte| if (byte != 0) return error.InvalidPadding;
    if (bytes[10] >= dimensions.layer_count or bytes[10] > 15) return error.InvalidLayer;
    const event: Event = if (bytes[2] == 3) blk: {
        if (bytes[8] > 1) return error.InvalidBoolean;
        if (bytes[9] >= dimensions.key_count or bytes[9] > 127) return error.InvalidKeyIndex;
        break :blk .{ .key = .{ .pressed = bytes[8] == 1, .key_index = @intCast(bytes[9]), .layer = @intCast(bytes[10]), .modifiers = model.Modifiers.fromByte(bytes[11]) } };
    } else .{ .layers = .{ .active_layers = std.mem.readInt(u16, bytes[8..10], .little), .highest_layer = @intCast(bytes[10]), .modifiers = model.Modifiers.fromByte(bytes[11]) } };
    const message = Message{ .sequence = std.mem.readInt(u16, bytes[4..6], .little), .event = event };
    try validate(message, dimensions);
    return message;
}
