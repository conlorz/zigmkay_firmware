//! Bounded breadcrumbs readable as a USB string without a configured HID.
pub const Event = enum(u8) { setup = 1, decode, open_out, driver, open_in, configured, status, stall, reset, abort_timeout };
pub const Recorder = struct {
    const count = 8;
    events: [count][5]u8 = @splat(@splat(0)),
    next: usize = 0,
    used: usize = 0,
    last_setup: [8]u8 = @splat(0),
    descriptor: [2 + 2 * (8 + 16 + count * 10)]u8 = @splat(0),

    pub fn setup(self: *@This(), packet: @import("usb_ep0.zig").Setup) void {
        self.last_setup = .{ packet.request_type, packet.request, @truncate(packet.value), @truncate(packet.value >> 8), @truncate(packet.index), @truncate(packet.index >> 8), @truncate(packet.length), @truncate(packet.length >> 8) };
        self.record(.setup, packet.request_type, packet.request, packet.value);
    }

    pub fn record(self: *@This(), event: Event, a: u8, b: u8, value: u16) void {
        self.events[self.next] = .{ @intFromEnum(event), a, b, @truncate(value), @truncate(value >> 8) };
        self.next = (self.next + 1) % count;
        self.used = @min(count, self.used + 1);
    }

    pub fn string(self: *@This()) []const u8 {
        const prefix = "USBREC1:";
        const length = 2 + 2 * (prefix.len + 16 + self.used * 10);
        self.descriptor[0] = @intCast(length);
        self.descriptor[1] = 3;
        var offset: usize = 2;
        for (prefix) |c| {
            self.descriptor[offset] = c;
            self.descriptor[offset + 1] = 0;
            offset += 2;
        }
        for (self.last_setup) |byte| self.hex(byte, &offset);
        for (0..self.used) |i| {
            const event = self.events[(self.next + count - self.used + i) % count];
            for (event) |byte| self.hex(byte, &offset);
        }
        return self.descriptor[0..length];
    }

    fn hex(self: *@This(), byte: u8, offset: *usize) void {
        for ([_]u8{ byte >> 4, byte & 15 }) |nibble| {
            self.descriptor[offset.*] = "0123456789ABCDEF"[nibble];
            self.descriptor[offset.* + 1] = 0;
            offset.* += 2;
        }
    }
};
