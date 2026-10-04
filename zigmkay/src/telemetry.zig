//! Optional observation only: no USB scheduling or shared keyboard output queue.
const protocol = @import("device-protocol");
pub const Message = protocol.Message;
pub const Event = protocol.Event;
pub const Sink = struct {
    context: *anyopaque,
    /// Must be nonblocking; false indicates a dropped event.
    write: *const fn (*anyopaque, Message) bool,
};
pub const SignalSink = struct {
    context: *anyopaque,
    write: *const fn (*anyopaque, protocol.Signal) void,
};

pub const Observer = struct {
    sink: ?Sink = null,
    next_sequence: u16 = 0,
    dropped_events: u32 = 0,
    state: protocol.Snapshot = .{},

    pub fn emit(self: *Observer, event: Event) void {
        switch (event) {
            .key => |key| {
                const mask = @as(u8, 1) << @as(u3, @intCast(key.key_index % 8));
                if (key.pressed) self.state.pressed[key.key_index / 8] |= mask else self.state.pressed[key.key_index / 8] &= ~mask;
            },
            .layers => |layers| {
                self.state.active_layers = layers.active_layers;
                self.state.highest_layer = layers.highest_layer;
                self.state.modifiers = layers.modifiers;
            },
        }
        const sink = self.sink orelse return;
        const message = Message{ .sequence = self.next_sequence, .event = event };
        self.next_sequence +%= 1;
        if (!sink.write(sink.context, message)) self.dropped_events +%= 1;
    }
};
