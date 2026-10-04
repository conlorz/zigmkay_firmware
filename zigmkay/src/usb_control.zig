//! Vendor Output SetReport shim for the pinned MicroZig controller.
//! Generic USB/controller parameters keep the same boundary fake-testable.
const protocol = @import("device-protocol");
const transport = @import("telemetry_transport.zig");
const ep0 = @import("usb_ep0.zig");

pub const Setup = ep0.Setup;
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
    /// Disable/reset noncontrol endpoints before (re)initializing drivers.
    configure: ?*const fn (u16) void = null,
    request: ?*const fn (Setup) ep0.Reply = null,
    output: ?*const fn ([]const u8) bool = null,
    status_complete: ?*const fn () void = null,
    reset: ?*const fn () void = null,
    interrupt_output: ?*const fn (u8, []const u8) u16 = null,
    ready: ?*const fn () bool = null,
};

pub fn Controller(comptime usb: type, comptime Base: type) type {
    return struct {
        base: *Base,
        telemetry: ?*transport.Transport = null,
        gate: Gate = .{},
        control_owned: bool = false,
        status_out_pending: bool = false,
        configuration_reply: [1]u8 = .{0},
        configuration_descriptor: ?[]const u8 = null,
        hid_descriptors: []const [9]u8 = &.{},
        hooks: Hooks,
        transfer: ep0.Transfer = .{},
        const Self = @This();

        pub fn on_setup_req(self: *Self, device: *usb.DeviceInterface, packet: *const usb.types.SetupPacket) void {
            self.control_owned = false;
            self.status_out_pending = false;
            self.gate.pending = false;
            // Every SETUP cancels the previous transfer, including unfinished
            // descriptor data and its status packet. The pinned controller does
            // not reset these buffers or discard its pending descriptor slice.
            self.hooks.prepare();
            if (self.hooks.ready) |ready| {
                if (!ready()) {
                    self.transfer.reset();
                    return;
                }
            }
            self.base.tx_slice = null;
            if (comptime @hasField(Base, "new_address")) self.base.new_address = 0;
            const request_type: u8 = @bitCast(packet.request_type);
            if (self.hooks.request) |request| {
                const setup = Setup{ .request_type = request_type, .request = packet.request, .value = packet.value.into(), .index = packet.index.into(), .length = packet.length.into() };
                self.transfer.setup(device, setup, request(setup), self.hooks.reject);
                return;
            }
            if (request_type == 0x00 and packet.request == 9 and self.hooks.configure != null) {
                if (packet.value.into() > 1 or packet.index.into() != 0 or packet.length.into() != 0) {
                    self.hooks.reject();
                    return;
                }
                self.hooks.configure.?(packet.value.into());
                if (self.telemetry) |t| t.disconnect();
                device.ep_ack(.ep0);
                return;
            }
            if (packet.request == 6) {
                const value = packet.value.into();
                const response: ?[]const u8 = if (request_type == 0x80 and value == 0x0200)
                    self.configuration_descriptor
                else if (request_type == 0x81 and value == 0x2100 and packet.index.into() < self.hid_descriptors.len)
                    &self.hid_descriptors[packet.index.into()]
                else
                    null;
                if (response) |bytes| {
                    const limited = bytes[0..@min(bytes.len, packet.length.into())];
                    const sent = device.ep_writev(.ep0, &.{limited});
                    self.base.tx_slice = limited[sent..];
                    self.status_out_pending = limited.len != 0;
                    return;
                }
            }
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
            if (comptime ep.num == .ep0) {
                if (self.hooks.request != null) {
                    if (comptime ep.dir == .In) {
                        if (self.transfer.inComplete(device)) {
                            if (self.hooks.status_complete) |complete| complete();
                        }
                    } else self.transfer.outComplete(device, self.hooks.output.?, self.hooks.reject);
                    return;
                }
            }
            if (comptime ep.num == .ep0 and ep.dir == .In) {
                if (self.control_owned) return;
            }
            if (comptime ep.dir == .Out) {
                if (self.hooks.interrupt_output) |receive| {
                    if (comptime ep.num != .ep0) {
                        var bytes: [64]u8 = undefined;
                        const len = device.ep_readv(ep.num, &.{&bytes});
                        const next = receive(@intFromEnum(ep.num), bytes[0..len]);
                        if (next != 0) device.ep_listen(ep.num, @intCast(next));
                        return;
                    }
                }
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
            self.transfer.reset();
            if (self.telemetry) |t| t.disconnect();
            if (self.hooks.reset) |reset| reset() else if (self.hooks.configure) |configure| configure(0);
            self.base.on_bus_reset(device);
        }
    };
}
