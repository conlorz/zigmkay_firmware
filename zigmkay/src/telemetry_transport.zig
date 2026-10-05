//! Fixed-storage v2 transport. All calls are bounded and never affect typing.
const protocol = @import("device-protocol");
const telemetry = @import("telemetry.zig");

pub const delta_capacity = 16;
pub const Endpoint = struct {
    context: *anyopaque,
    /// Must copy/own the bytes before returning true; false preserves the head.
    send: *const fn (*anyopaque, *const protocol.Report) bool,
};

test "bootloader requires explicit session control and bounded acknowledged drain" {
    const std = @import("std");
    const identity = protocol.Identity{ .board_id = "lk7\x00\x00\x00\x00\x00".*, .profile_id = "default\x00".*, .digest = @splat(0), .dimensions = .{ .key_count = 1, .layer_count = 1 } };
    const Fake = struct {
        ready: bool = false,
        response: ?protocol.Report = null,
        fn send(context: *anyopaque, report: *const protocol.Report) bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (!self.ready) return false;
            self.response = report.*;
            return true;
        }
    };
    var t = Transport.init(identity);
    var fake = Fake{};
    const endpoint = Endpoint{ .context = &fake, .send = Fake.send };
    try std.testing.expect(!t.takeBootloader(0));
    t.session = 42;
    const stale = try protocol.encodePacket(.{ .session = 41, .request = 1, .payload = .enter_bootloader }, identity.dimensions, .host_to_device);
    t.receive(&stale);
    t.boundary();
    try std.testing.expect(t.bootloader_request == null);
    var malformed = stale;
    malformed[31] = 1;
    t.receive(&malformed);
    try std.testing.expectEqual(@as(u32, 2), t.rejected_controls);
    const request = try protocol.encodePacket(.{ .session = 42, .request = 2, .payload = .enter_bootloader }, identity.dimensions, .host_to_device);
    t.receive(&request);
    try std.testing.expect(t.bootloader_request == null);
    t.boundary();
    try std.testing.expect(!t.takeBootloader(1));
    t.pump(endpoint);
    try std.testing.expect(!t.takeBootloader(100_001));
    try std.testing.expect(t.bootloader_request == null);
    t.receive(&request);
    t.boundary();
    fake.ready = true;
    t.pump(endpoint);
    const duplicate = try protocol.decodePacket(&fake.response.?, identity.dimensions, .device_to_host);
    try std.testing.expectEqual(protocol.BootloaderResult.duplicate, duplicate.payload.bootloader_result);
    const next = try protocol.encodePacket(.{ .session = 42, .request = 3, .payload = .enter_bootloader }, identity.dimensions, .host_to_device);
    t.receive(&next);
    t.boundary();
    try std.testing.expect(!t.takeBootloader(200_000));
    t.pump(endpoint);
    const accepted = try protocol.decodePacket(&fake.response.?, identity.dimensions, .device_to_host);
    try std.testing.expectEqual(@as(u16, 3), accepted.request);
    try std.testing.expectEqual(protocol.BootloaderResult.accepted, accepted.payload.bootloader_result);
    try std.testing.expect(!t.takeBootloader(219_999));
    try std.testing.expect(t.takeBootloader(220_000));
    try std.testing.expect(!t.takeBootloader(240_000));
}

pub const Transport = struct {
    identity: protocol.Identity,
    state: protocol.Snapshot = .{},
    session: u32 = 0,
    next_sequence: u16 = 0,
    deltas: [delta_capacity]protocol.Report = undefined,
    delta_head: usize = 0,
    delta_count: usize = 0,
    controls: [3]protocol.Report = undefined,
    control_head: usize = 0,
    control_count: usize = 0,
    snapshot_pending: bool = false,
    synchronized: bool = false,
    recovery: ?protocol.RecoveryReason = null,
    pending: ?protocol.Packet = null,
    rejected_controls: u32 = 0,
    dropped_events: u32 = 0,
    bootloader_request: ?u16 = null,
    bootloader_started: ?u64 = null,
    bootloader_acknowledged: ?u64 = null,
    last_bootloader_request: u16 = 0,
    clock_us: u64 = 0,

    pub fn init(identity: protocol.Identity) Transport {
        return .{ .identity = identity };
    }

    pub fn sink(self: *Transport) telemetry.Sink {
        return .{ .context = self, .write = write };
    }

    fn write(context: *anyopaque, message: protocol.Message) bool {
        const self: *Transport = @ptrCast(@alignCast(context));
        switch (message.event) {
            .key => |key| {
                const mask = @as(u8, 1) << @as(u3, @intCast(key.key_index % 8));
                if (key.pressed) self.state.pressed[key.key_index / 8] |= mask else self.state.pressed[key.key_index / 8] &= ~mask;
                return self.event(.{ .key = key });
            },
            .layers => |layers| {
                self.state.active_layers = layers.active_layers;
                self.state.highest_layer = layers.highest_layer;
                self.state.modifiers = layers.modifiers;
                return self.event(.{ .layers = layers });
            },
        }
    }

    pub fn signal(self: *Transport, value: protocol.Signal) void {
        _ = self.event(.{ .signal = value });
    }

    pub fn signalSink(self: *Transport) telemetry.SignalSink {
        return .{ .context = self, .write = writeSignal };
    }

    fn writeSignal(context: *anyopaque, value: protocol.Signal) void {
        const self: *Transport = @ptrCast(@alignCast(context));
        self.signal(value);
    }

    fn event(self: *Transport, payload: protocol.Payload) bool {
        if (self.session == 0) return true;
        const sequence = self.next_sequence;
        self.next_sequence +%= 1;
        if (!self.synchronized) return true;
        if (self.delta_count == delta_capacity) {
            self.dropped_events +%= 1;
            self.delta_count = 0;
            self.delta_head = 0;
            self.synchronized = false;
            self.recovery = if (self.snapshot_pending) .snapshot_invalidated else .overflow;
            if (self.snapshot_pending) {
                self.control_count = 0;
                self.control_head = 0;
                self.snapshot_pending = false;
            }
            return false;
        }
        const bytes = protocol.encodePacket(.{ .session = self.session, .sequence = sequence, .payload = payload }, self.identity.dimensions, .device_to_host) catch return false;
        self.deltas[(self.delta_head + self.delta_count) % delta_capacity] = bytes;
        self.delta_count += 1;
        return true;
    }

    /// USB callbacks only validate and replace a one-command mailbox. Hello wins
    /// over snapshots; repeated snapshot floods cannot expand storage or work.
    pub fn receive(self: *Transport, bytes: []const u8) void {
        const packet = protocol.decodePacket(bytes, self.identity.dimensions, .host_to_device) catch {
            self.rejected_controls +%= 1;
            return;
        };
        switch (packet.payload) {
            .hello => self.pending = packet,
            .snapshot_request, .capabilities_request, .enter_bootloader => {
                if (packet.session != self.session or self.session == 0) {
                    self.rejected_controls +%= 1;
                    return;
                }
                if (self.bootloader_request != null or self.pending != null) {
                    self.rejected_controls +%= 1;
                    return;
                }
                self.pending = packet;
            },
            else => self.rejected_controls +%= 1,
        }
    }

    /// Invoke after the processor boundary. Capture precedes all subsequent
    /// deltas, and old deltas are discarded at the coherent snapshot cut.
    pub fn boundary(self: *Transport) void {
        const packet = self.pending orelse return;
        if (packet.payload != .hello and self.control_count != 0) return;
        self.pending = null;
        switch (packet.payload) {
            .hello => {
                self.disconnect();
                self.session = packet.nonce;
                const parts = protocol.identityPackets(self.identity, packet.nonce, packet.request) catch unreachable;
                for (parts, 0..) |part, i| self.controls[i] = protocol.encodePacket(part, self.identity.dimensions, .device_to_host) catch unreachable;
                self.control_count = 3;
            },
            .snapshot_request => {
                self.delta_count = 0;
                self.delta_head = 0;
                self.recovery = null;
                const parts = protocol.snapshotPackets(self.state, self.identity.dimensions, self.session, packet.request, self.next_sequence) catch unreachable;
                for (parts, 0..) |part, i| self.controls[i] = protocol.encodePacket(part, self.identity.dimensions, .device_to_host) catch unreachable;
                self.control_head = 0;
                self.control_count = 2;
                self.snapshot_pending = true;
                self.synchronized = true;
            },
            .capabilities_request => self.reply(packet.request, .{ .capabilities = protocol.capability_bootloader }),
            .enter_bootloader => {
                if (packet.request <= self.last_bootloader_request) {
                    self.reply(packet.request, .{ .bootloader_result = .duplicate });
                    self.rejected_controls +%= 1;
                } else {
                    self.last_bootloader_request = packet.request;
                    self.bootloader_request = packet.request;
                    self.bootloader_started = null;
                    self.bootloader_acknowledged = null;
                    self.reply(packet.request, .{ .bootloader_result = .accepted });
                }
            },
            else => unreachable,
        }
    }

    fn reply(self: *Transport, request: u16, payload: protocol.Payload) void {
        self.controls[0] = protocol.encodePacket(.{ .session = self.session, .request = request, .payload = payload }, self.identity.dimensions, .device_to_host) catch unreachable;
        self.control_head = 0;
        self.control_count = 1;
    }

    /// Main-loop only. Permit USB drain for 20 ms after acceptance; abandon the
    /// operation after 100 ms of backpressure rather than reboot without an ack.
    pub fn takeBootloader(self: *Transport, now_us: u64) bool {
        self.clock_us = now_us;
        if (self.bootloader_request == null) return false;
        if (self.bootloader_started == null) self.bootloader_started = now_us;
        if (self.bootloader_acknowledged) |accepted| {
            if (now_us -| accepted < 20_000) return false;
            self.disconnect();
            return true;
        }
        if (now_us -| self.bootloader_started.? >= 100_000) {
            self.bootloader_request = null;
            self.control_count = 0;
            self.control_head = 0;
        }
        return false;
    }

    /// At most one send attempt per tick. No readiness loops or allocations.
    pub fn pump(self: *Transport, endpoint: Endpoint) void {
        if (self.session == 0) return;
        if (self.control_count != 0) {
            if (!endpoint.send(endpoint.context, &self.controls[self.control_head])) return;
            if (self.bootloader_request != null) self.bootloader_acknowledged = self.clock_us;
            self.control_head += 1;
            self.control_count -= 1;
            if (self.control_count == 0) self.snapshot_pending = false;
        } else if (self.recovery) |reason| {
            const bytes = protocol.encodePacket(.{ .session = self.session, .payload = .{ .recovery = reason } }, self.identity.dimensions, .device_to_host) catch unreachable;
            if (endpoint.send(endpoint.context, &bytes)) self.recovery = null;
        } else if (self.delta_count != 0) {
            if (!endpoint.send(endpoint.context, &self.deltas[self.delta_head])) return;
            self.delta_head = (self.delta_head + 1) % delta_capacity;
            self.delta_count -= 1;
        }
    }

    /// Physical state survives disconnect; queued traffic and tokens do not.
    pub fn disconnect(self: *Transport) void {
        self.session = 0;
        self.next_sequence = 0;
        self.delta_count = 0;
        self.delta_head = 0;
        self.control_count = 0;
        self.control_head = 0;
        self.snapshot_pending = false;
        self.synchronized = false;
        self.recovery = null;
        self.pending = null;
        self.bootloader_request = null;
        self.bootloader_started = null;
        self.bootloader_acknowledged = null;
        self.last_bootloader_request = 0;
    }
};
