const model = @import("layout-model");
const protocol = @import("device-protocol");

pub const State = struct {
    dimensions: model.KeymapDimensions,
    pressed: [128]bool = @splat(false),
    active_layers: u16 = 1,
    highest_layer: model.LayerIndex = 0,
    modifiers: model.Modifiers = .{},
    last_sequence: ?u16 = null,
    needs_resync: bool = false,

    pub fn init(dimensions: model.KeymapDimensions) protocol.ProtocolError!State {
        try protocol.validate(.{ .sequence = 0, .event = .{ .layers = .{ .active_layers = 1, .highest_layer = 0, .modifiers = .{} } } }, dimensions);
        return .{ .dimensions = dimensions };
    }

    pub fn apply(self: *State, message: protocol.Message) !void {
        try protocol.validate(message, self.dimensions);
        if (self.needs_resync) return error.ResyncRequired;
        if (self.last_sequence) |last| {
            if (message.sequence != last +% 1) {
                self.needs_resync = true;
                return error.SequenceDiscontinuity;
            }
        }
        switch (message.event) {
            .key => |key| {
                self.pressed[key.key_index] = key.pressed;
                self.modifiers = key.modifiers;
            },
            .layers => |layers| {
                self.active_layers = layers.active_layers;
                self.highest_layer = layers.highest_layer;
                self.modifiers = layers.modifiers;
            },
        }
        self.last_sequence = message.sequence;
    }

    pub fn receive(self: *State, bytes: []const u8) !void {
        try self.apply(try protocol.decode(bytes, self.dimensions));
    }
};
