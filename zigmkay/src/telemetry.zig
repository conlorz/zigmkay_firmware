//! Optional observation only: no USB scheduling or shared keyboard output queue.
const protocol = @import("device-protocol");
pub const Message = protocol.Message;
pub const Event = protocol.Event;
pub const Sink = struct {
    context: *anyopaque,
    /// Must be nonblocking; false indicates a dropped event.
    write: *const fn (*anyopaque, Message) bool,
};

pub const Observer = struct {
    sink: ?Sink = null,
    next_sequence: u16 = 0,
    dropped_events: u32 = 0,

    pub fn emit(self: *Observer, event: Event) void {
        const sink = self.sink orelse return;
        const message = Message{ .sequence = self.next_sequence, .event = event };
        self.next_sequence +%= 1;
        if (!sink.write(sink.context, message)) self.dropped_events +%= 1;
    }
};
