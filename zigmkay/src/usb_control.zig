//! Vendor Output SetReport shim for the pinned MicroZig controller.
//! Generic USB/controller parameters keep the same boundary fake-testable.
const protocol = @import("device-protocol");
const transport = @import("telemetry_transport.zig");

pub const Setup = struct { request_type: u8, request: u8, value: u16, index: u16, length: u16 };
pub const Decision = enum { delegate, receive, reject };
pub const Gate = struct {
    pending: bool = false,
    pub fn setup(self: *Gate, packet: Setup, vendor_interface: u8) Decision {
        self.pending = false;
        // Other collections retain the upstream controller's behavior.
        if (packet.index & 0xff != vendor_interface or packet.request != 9) return .delegate;
        if (packet.request_type != 0x21 or packet.index != vendor_interface or packet.value != 0x0200 or packet.length != protocol.report_size) return .reject;
        self.pending = true;
        return .receive;
    }
    pub fn data(self: *Gate, bytes: []const u8) bool {
        const pending = self.pending;
        self.pending = false;
        return pending and bytes.len == protocol.report_size;
    }
};

pub const Hooks = struct {
    /// Abort old EP0 buffers, clear stall, reset OUT PID before a new DATA1.
    prepare: *const fn () void,
    reject: *const fn () void,
};

pub fn Controller(comptime usb: type, comptime Base: type) type {
    return struct {
        base: *Base,
        telemetry: ?*transport.Transport = null,
        gate: Gate = .{},
        control_owned: bool = false,
        status_out_pending: bool = false,
        configuration_reply: [1]u8 = .{0},
        hooks: Hooks,
        const Self = @This();

        pub fn on_setup_req(self: *Self, device: *usb.DeviceInterface, packet: *const usb.types.SetupPacket) void {
            self.control_owned = false;
            self.status_out_pending = false;
            self.gate.pending = false;
            // Every SETUP cancels the previous transfer, including unfinished
            // descriptor data and its status packet. The pinned controller does
            // not reset these buffers or discard its pending descriptor slice.
            self.hooks.prepare();
            self.base.tx_slice = null;
            // The pinned controller enumerates GetConfiguration but does not
            // implement it. Hosts may query the active configuration before or
            // after selecting one; leaving it unanswered times out EP0.
            if (@as(u8, @bitCast(packet.request_type)) == 0x80 and packet.request == 8 and
                packet.value.into() == 0 and packet.index.into() == 0 and packet.length.into() == 1)
            {
                self.configuration_reply[0] = @intCast(self.base.cfg_num);
                _ = device.ep_writev(.ep0, &.{&self.configuration_reply});
                self.status_out_pending = true;
                return;
            }
            if (self.telemetry != null) {
                if (self.base.drivers()) |drivers| {
                    const decision = self.gate.setup(.{
                        .request_type = @bitCast(packet.request_type),
                        .request = packet.request,
                        .value = packet.value.into(),
                        .index = packet.index.into(),
                        .length = packet.length.into(),
                    }, drivers.rawhid.descriptor.interface.interface_number);
                    switch (decision) {
                        .receive => {
                            self.control_owned = true;
                            device.ep_listen(.ep0, protocol.report_size);
                            return;
                        },
                        .reject => {
                            self.control_owned = true;
                            self.hooks.reject();
                            return;
                        },
                        .delegate => {},
                    }
                }
            }
            self.base.on_setup_req(device, packet);
            self.status_out_pending = (@as(u8, @bitCast(packet.request_type)) & 0x80 != 0) and packet.length.into() != 0;
            // A standard deconfiguration is a session boundary as well as bus
            // reset. Physical state survives, but old reports must not resume.
            if (self.telemetry) |t| {
                if (self.base.drivers() == null) t.disconnect();
            }
        }

        pub fn on_buffer(self: *Self, device: *usb.DeviceInterface, comptime ep: usb.types.Endpoint) void {
            if (comptime ep.num == .ep0 and ep.dir == .In) {
                if (self.control_owned) return;
            }
            if (comptime ep.dir == .Out) {
                if (self.telemetry) |t| {
                    if (comptime ep.num == .ep0) {
                        if (self.gate.pending) {
                            // EP0 hardware packets are at most 64 bytes; using the
                            // full scratch capacity exposes overlength as well as short data.
                            var bytes: [64]u8 = @splat(0);
                            const len = device.ep_readv(.ep0, &.{&bytes});
                            if (self.gate.data(bytes[0..len])) {
                                t.receive(bytes[0..len]);
                                device.ep_ack(.ep0);
                            } else self.hooks.reject();
                            return;
                        }
                    } else if (self.base.drivers()) |drivers| {
                        if (ep.num == drivers.rawhid.descriptor.ep_out.endpoint.num) {
                            var bytes: [64]u8 = @splat(0);
                            const len = device.ep_readv(ep.num, &.{&bytes});
                            t.receive(bytes[0..len]);
                            device.ep_listen(ep.num, protocol.report_size);
                            return;
                        }
                    }
                }
            }
            self.base.on_buffer(device, ep);
            if (comptime ep.num == .ep0 and ep.dir == .In) {
                // MicroZig advances tx_slice here but leaves the ensuing OUT
                // status stage unarmed. Wait until the final data packet has
                // completed, including for descriptors spanning several packets.
                if (self.status_out_pending and self.base.tx_slice == null) {
                    self.status_out_pending = false;
                    device.ep_listen(.ep0, 0);
                }
            }
        }

        pub fn on_bus_reset(self: *Self, device: *usb.DeviceInterface) void {
            self.gate.pending = false;
            self.control_owned = false;
            self.status_out_pending = false;
            if (self.telemetry) |t| t.disconnect();
            self.base.on_bus_reset(device);
        }
    };
}
