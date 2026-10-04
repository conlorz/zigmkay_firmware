const std = @import("std");
const zigmkay = @import("zigmkay");
const protocol = @import("device-protocol");
const lk7 = @import("lk7-keymap");
const core = zigmkay.core;
const transport = zigmkay.telemetry_transport;
const identity = blk: {
    @setEvalBranchQuota(100_000);
    break :blk lk7.identity(protocol);
};
const Fake = struct {
    ready: bool = true,
    reports: [64]protocol.Report = undefined,
    count: usize = 0,
    attempts: usize = 0,
    fn send(context: *anyopaque, bytes: *const protocol.Report) bool {
        const self: *Fake = @ptrCast(@alignCast(context));
        self.attempts += 1;
        if (!self.ready) return false;
        self.reports[self.count] = bytes.*;
        self.count += 1;
        return true;
    }
    fn endpoint(self: *Fake) transport.Endpoint {
        return .{ .context = self, .send = send };
    }
    fn packet(self: *Fake, index: usize) !protocol.Packet {
        return protocol.decodePacket(&self.reports[index], identity.dimensions, .device_to_host);
    }
};
fn control(t: *transport.Transport, packet: protocol.Packet) !void {
    const bytes = try protocol.encodePacket(packet, identity.dimensions, .host_to_device);
    t.receive(&bytes);
    t.boundary();
}
fn hello(t: *transport.Transport, fake: *Fake) !void {
    try control(t, .{ .session = 0, .nonce = 42, .request = 1, .payload = .hello });
    for (0..3) |_| t.pump(fake.endpoint());
}
fn synchronize(t: *transport.Transport, fake: *Fake) !void {
    try hello(t, fake);
    try control(t, .{ .session = 42, .request = 2, .payload = .snapshot_request });
    for (0..2) |_| t.pump(fake.endpoint());
}
fn key(t: *transport.Transport, pressed: bool, index: core.KeyIndex) void {
    const sink = t.sink();
    _ = sink.write(sink.context, .{ .sequence = 0, .event = .{ .key = .{ .pressed = pressed, .key_index = index, .layer = 0, .modifiers = .{} } } });
}

test "not ready preserves exact report bytes and acceptance removes only one" {
    var t = transport.Transport.init(identity);
    var fake = Fake{ .ready = false };
    try control(&t, .{ .session = 0, .nonce = 42, .request = 1, .payload = .hello });
    const first = t.controls[0];
    for (0..100) |_| t.pump(fake.endpoint());
    try std.testing.expectEqual(@as(usize, 3), t.control_count);
    try std.testing.expectEqual(@as(usize, 100), fake.attempts);
    fake.ready = true;
    t.pump(fake.endpoint());
    try std.testing.expectEqualSlices(u8, &first, &fake.reports[0]);
    try std.testing.expectEqual(@as(usize, 2), t.control_count);
}

test "physical state survives no session and disconnect and snapshot cuts before deltas" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    key(&t, true, 2);
    try hello(&t, &fake);
    try control(&t, .{ .session = 42, .request = 2, .payload = .snapshot_request });
    key(&t, false, 2);
    for (0..3) |_| t.pump(fake.endpoint());
    const first = try fake.packet(3);
    const second = try fake.packet(4);
    try std.testing.expectEqual(@as(u8, 4), first.payload.snapshot.bytes[0]);
    try std.testing.expectEqual(first.sequence, second.sequence);
    const delta = try fake.packet(5);
    try std.testing.expectEqual(first.sequence, delta.sequence);
    try std.testing.expect(!delta.payload.key.pressed);
    key(&t, true, 3);
    t.disconnect();
    try std.testing.expectEqual(@as(u8, 8), t.state.pressed[0]);
    const before = fake.count;
    t.pump(fake.endpoint());
    try std.testing.expectEqual(before, fake.count);
}

test "overflow bypasses full delta queue and snapshot recovery uses current physical state" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    for (0..1000) |i| key(&t, i % 2 == 0, 1);
    try std.testing.expectEqual(@as(u16, 1000), t.next_sequence);
    try std.testing.expectEqual(@as(usize, 0), t.delta_count);
    t.pump(fake.endpoint());
    try std.testing.expectEqual(protocol.RecoveryReason.overflow, (try fake.packet(5)).payload.recovery);
    try control(&t, .{ .session = 42, .request = 3, .payload = .snapshot_request });
    for (0..2) |_| t.pump(fake.endpoint());
    try std.testing.expectEqual(@as(u16, 1000), (try fake.packet(6)).sequence);
    try std.testing.expectEqual(@as(u8, 0), (try fake.packet(6)).payload.snapshot.bytes[0]);
    key(&t, true, 0);
    t.pump(fake.endpoint());
    try std.testing.expectEqual(@as(u16, 1000), (try fake.packet(8)).sequence);
}

test "overflow invalidates partially delivered snapshot and recovery is retryable" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try hello(&t, &fake);
    try control(&t, .{ .session = 42, .request = 2, .payload = .snapshot_request });
    t.pump(fake.endpoint());
    for (0..transport.delta_capacity + 1) |_| key(&t, true, 0);
    try std.testing.expectEqual(@as(usize, 0), t.control_count);
    fake.ready = false;
    t.pump(fake.endpoint());
    try std.testing.expectEqual(protocol.RecoveryReason.snapshot_invalidated, t.recovery.?);
    fake.ready = true;
    t.pump(fake.endpoint());
    try std.testing.expectEqual(protocol.RecoveryReason.snapshot_invalidated, (try fake.packet(4)).payload.recovery);
}

test "malformed wrong direction wrong session and control floods stay bounded" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    t.receive(&.{ 0xA7, 2 });
    const wrong = try protocol.encodePacket(.{ .session = 42, .payload = .{ .key = .{ .pressed = true, .key_index = 0, .layer = 0, .modifiers = .{} } } }, identity.dimensions, .device_to_host);
    t.receive(&wrong);
    try hello(&t, &fake);
    try control(&t, .{ .session = 7, .request = 2, .payload = .snapshot_request });
    try std.testing.expectEqual(@as(u32, 3), t.rejected_controls);
    const request = try protocol.encodePacket(.{ .session = 42, .request = 2, .payload = .snapshot_request }, identity.dimensions, .host_to_device);
    for (0..10000) |_| t.receive(&request);
    try std.testing.expect(t.pending != null);
    t.boundary();
    try std.testing.expectEqual(@as(usize, 2), t.control_count);
    try std.testing.expectEqual(@as(usize, 0), t.delta_count);
}

const Processor = zigmkay.processing.CreateProcessorType(&lk7.dimensions, &lk7.keymap, &lk7.sides, &lk7.combos, &lk7.custom_functions, &.{});
const Mode = enum { disabled, enabled, saturated, disconnected };
fn typing(mode: Mode) ![6]core.OutputCommand {
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    if (mode == .saturated) for (0..transport.delta_capacity + 1) |_| key(&t, true, 2);
    if (mode == .disconnected) t.disconnect();
    var processor = Processor{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    if (mode != .disabled) processor.observer.sink = t.sink();
    const events = [_]struct { pressed: bool, index: core.KeyIndex, time: u64 }{
        .{ .pressed = true, .index = 0, .time = 0 },
        .{ .pressed = false, .index = 0, .time = 50_000 },
        .{ .pressed = true, .index = 30, .time = 100_000 },
        .{ .pressed = true, .index = 0, .time = 300_000 },
        .{ .pressed = false, .index = 0, .time = 310_000 },
        .{ .pressed = false, .index = 30, .time = 350_000 },
    };
    for (events, 0..) |event, i| {
        try input.enqueue(.{ .pressed = event.pressed, .key_index = event.index, .time = core.TimeSinceBoot.from_absolute_us(event.time) });
        try processor.Process(core.TimeSinceBoot.from_absolute_us(event.time));
        if (i == 0) try processor.Process(core.TimeSinceBoot.from_absolute_us(41_000));
        if (i == 2) {
            try processor.Process(core.TimeSinceBoot.from_absolute_us(251_000));
            try processor.Process(core.TimeSinceBoot.from_absolute_us(252_000));
        }
    }
    try std.testing.expectEqual(@as(usize, 6), output.Count());
    var commands: [6]core.OutputCommand = undefined;
    for (&commands) |*command| command.* = output.dequeue().?;
    for (processor.observer.state.pressed) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    return commands;
}

test "real LK7 typing commands match enabled saturated and disconnected telemetry" {
    const baseline = try typing(.disabled);
    inline for (.{ Mode.enabled, Mode.saturated, Mode.disconnected }) |mode| {
        const actual = try typing(mode);
        for (baseline, actual) |expected, command| try std.testing.expectEqual(expected, command);
    }
}

test "replacement Hello clears old traffic and sequence wraps including signals" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    t.next_sequence = 65535;
    t.signal(.{ .kind = .overlay_toggle, .pressed = true });
    key(&t, true, 1);
    for (0..2) |_| t.pump(fake.endpoint());
    try std.testing.expectEqual(@as(u16, 65535), (try fake.packet(5)).sequence);
    try std.testing.expectEqual(@as(u16, 0), (try fake.packet(6)).sequence);
    key(&t, true, 0);
    try control(&t, .{ .session = 0, .nonce = 99, .request = 7, .payload = .hello });
    try std.testing.expectEqual(@as(usize, 0), t.delta_count);
    t.pump(fake.endpoint());
    try std.testing.expectEqual(@as(u32, 99), (try fake.packet(7)).session);
    try std.testing.expectEqual(@as(u16, 0), t.next_sequence);
    try std.testing.expectEqual(@as(u8, 3), t.state.pressed[0]);
}

test "disabled observer tracks combo components disabled inputs and stable layers" {
    const dimensions = core.KeymapDimensions{ .key_count = 3, .layer_count = 2 };
    const keymap = [_][3]?core.KeyDef{
        .{ .none, .none, .none },
        .{ null, null, null },
    };
    const sides = [_]core.Side{ .L, .L, .L };
    const combos = [_]core.Combo2Def{.{ .key_indexes = .{ 0, 1 }, .timeout = .{ .ms = 40 }, .layer = 0, .key_def = .none }};
    const P = zigmkay.processing.CreateProcessorType(&dimensions, &keymap, &sides, &combos, &.{}, &.{});
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var processor = P{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    try input.enqueue(.{ .pressed = true, .key_index = 0, .time = core.TimeSinceBoot.from_absolute_us(0) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(0));
    try processor.Process(core.TimeSinceBoot.from_absolute_us(1000));
    try std.testing.expectEqual(@as(u8, 1), processor.observer.state.pressed[0]);
    for (1..3) |i| try input.enqueue(.{ .pressed = true, .key_index = @intCast(i), .time = core.TimeSinceBoot.from_absolute_us(2000) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(2000));
    try std.testing.expectEqual(@as(u8, 7), processor.observer.state.pressed[0]);
    processor.layers_activations.activate(1);
    try output.set_mods(.{ .left_ctrl = true });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(3000));
    try std.testing.expectEqual(@as(u16, 3), processor.observer.state.active_layers);
    try std.testing.expectEqual(@as(u8, 1), processor.observer.state.modifiers.toByte());
    try std.testing.expectEqual(@as(core.LayerIndex, 1), processor.observer.state.highest_layer);
}

const FakeUsb = struct {
    const Num = enum(u4) { ep0, ep1, ep2, ep3, ep4 };
    const Dir = enum { In, Out };
    pub const types = struct {
        pub const Endpoint = struct { num: Num, dir: Dir };
        const Word = struct {
            value: u16,
            pub fn into(self: @This()) u16 {
                return self.value;
            }
        };
        pub const SetupPacket = struct {
            request_type: packed struct(u8) { raw: u8 },
            request: u8,
            value: Word,
            index: Word,
            length: Word,
        };
    };
    pub const DeviceInterface = struct {
        incoming: [64]u8 = @splat(0),
        incoming_len: usize = 0,
        listens: usize = 0,
        acks: usize = 0,
        reads: usize = 0,
        last_listen_length: usize = 0,
        written: [64]u8 = @splat(0),
        written_length: usize = 0,
        pub fn ep_writev(self: *@This(), _: Num, data: []const []const u8) usize {
            self.written_length = @min(self.written.len, data[0].len);
            @memcpy(self.written[0..self.written_length], data[0][0..self.written_length]);
            return self.written_length;
        }
        pub fn ep_listen(self: *@This(), _: Num, length: usize) void {
            self.listens += 1;
            self.last_listen_length = length;
        }
        pub fn ep_ack(self: *@This(), _: Num) void {
            self.acks += 1;
        }
        pub fn ep_readv(self: *@This(), _: Num, destinations: []const []u8) usize {
            self.reads += 1;
            @memcpy(destinations[0][0..self.incoming_len], self.incoming[0..self.incoming_len]);
            return self.incoming_len;
        }
    };
};
const FakeBase = struct {
    const Descriptor = struct {
        interface: struct { interface_number: u8 = 3 } = .{},
        ep_out: struct { endpoint: FakeUsb.types.Endpoint = .{ .num = .ep4, .dir = .Out } } = .{},
    };
    const desc = Descriptor{};
    const Drivers = struct { rawhid: struct { descriptor: *const Descriptor = &desc } = .{} };
    driver_data: Drivers = .{},
    configured: bool = true,
    tx_slice: ?[]const u8 = null,
    cfg_num: u16 = 0,
    setup_count: usize = 0,
    buffers: usize = 0,
    resets: usize = 0,
    pub fn drivers(self: *@This()) ?*Drivers {
        return if (self.configured) &self.driver_data else null;
    }
    pub fn on_setup_req(self: *@This(), _: *FakeUsb.DeviceInterface, _: *const FakeUsb.types.SetupPacket) void {
        self.setup_count += 1;
    }
    pub fn on_buffer(self: *@This(), _: *FakeUsb.DeviceInterface, comptime _: FakeUsb.types.Endpoint) void {
        self.buffers += 1;
    }
    pub fn on_bus_reset(self: *@This(), _: *FakeUsb.DeviceInterface) void {
        self.resets += 1;
    }
};
const HookCapture = struct {
    var prepares: usize = 0;
    var rejects: usize = 0;
    fn prepare() void {
        prepares += 1;
    }
    fn reject() void {
        rejects += 1;
    }
};
fn setupPacket(raw: u8, value: u16, index: u16, length: u16) FakeUsb.types.SetupPacket {
    return .{ .request_type = .{ .raw = raw }, .request = 9, .value = .{ .value = value }, .index = .{ .value = index }, .length = .{ .value = length } };
}

test "SetReport wrapper validates setup data length cancellation and keeps other collections" {
    HookCapture.prepares = 0;
    HookCapture.rejects = 0;
    var t = transport.Transport.init(identity);
    var base = FakeBase{};
    var device = FakeUsb.DeviceInterface{};
    var controller = zigmkay.usb_control.Controller(FakeUsb, FakeBase){ .base = &base, .telemetry = &t, .hooks = .{ .prepare = HookCapture.prepare, .reject = HookCapture.reject } };
    const good = setupPacket(0x21, 0x0200, 3, 32);
    const hello_bytes = try protocol.encodePacket(.{ .session = 0, .nonce = 42, .request = 1, .payload = .hello }, identity.dimensions, .host_to_device);
    @memcpy(device.incoming[0..32], &hello_bytes);
    device.incoming_len = 32;
    controller.on_setup_req(&device, &good);
    try std.testing.expectEqual(@as(usize, 0), device.acks);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .Out });
    try std.testing.expect(t.pending != null);
    try std.testing.expectEqual(@as(usize, 1), device.acks);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 0), base.buffers);
    t.boundary();
    try std.testing.expectEqual(@as(u32, 42), t.session);
    const invalid = [_]FakeUsb.types.SetupPacket{
        setupPacket(0xA1, 0x0200, 3, 32),
        setupPacket(0x21, 0x0201, 3, 32),
        setupPacket(0x21, 0x0300, 3, 32),
        setupPacket(0x21, 0x0200, 0x103, 32),
        setupPacket(0x21, 0x0200, 3, 31),
        setupPacket(0x21, 0x0200, 3, 33),
    };
    for (invalid) |packet| {
        controller.on_setup_req(&device, &packet);
        try std.testing.expect(!controller.gate.pending);
    }
    try std.testing.expectEqual(@as(usize, invalid.len), HookCapture.rejects);
    const other = setupPacket(0x21, 0x0200, 0, 1);
    controller.on_setup_req(&device, &good);
    controller.on_setup_req(&device, &other);
    try std.testing.expect(!controller.gate.pending);
    try std.testing.expectEqual(@as(usize, 1), base.setup_count);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .Out });
    try std.testing.expectEqual(@as(usize, 1), base.buffers);
    for ([_]usize{ 0, 12, 31, 33, 64 }) |length| {
        controller.on_setup_req(&device, &good);
        device.incoming_len = length;
        controller.on_buffer(&device, .{ .num = .ep0, .dir = .Out });
        try std.testing.expect(t.pending == null);
    }
    try std.testing.expectEqual(@as(usize, invalid.len + 5), HookCapture.rejects);
    controller.on_buffer(&device, .{ .num = .ep1, .dir = .Out });
    controller.on_buffer(&device, .{ .num = .ep2, .dir = .In });
    controller.on_buffer(&device, .{ .num = .ep3, .dir = .In });
    try std.testing.expectEqual(@as(usize, 4), base.buffers);
    controller.on_bus_reset(&device);
    try std.testing.expectEqual(@as(u32, 0), t.session);
    try std.testing.expectEqual(@as(usize, 1), base.resets);
    t.session = 42;
    key(&t, true, 0);
    base.configured = false;
    controller.on_setup_req(&device, &other);
    try std.testing.expectEqual(@as(u32, 0), t.session);
    try std.testing.expectEqual(@as(u8, 1), t.state.pressed[0]);
}

test "interrupt OUT wrapper rejects short reports and accepts exact length without tail reads" {
    var t = transport.Transport.init(identity);
    var base = FakeBase{};
    var device = FakeUsb.DeviceInterface{};
    var controller = zigmkay.usb_control.Controller(FakeUsb, FakeBase){ .base = &base, .telemetry = &t, .hooks = .{ .prepare = HookCapture.prepare, .reject = HookCapture.reject } };
    const bytes = try protocol.encodePacket(.{ .session = 0, .nonce = 12, .request = 1, .payload = .hello }, identity.dimensions, .host_to_device);
    @memcpy(device.incoming[0..32], &bytes);
    for ([_]usize{ 0, 12, 31, 33, 64 }) |len| {
        device.incoming_len = len;
        controller.on_buffer(&device, .{ .num = .ep4, .dir = .Out });
        try std.testing.expect(t.pending == null);
    }
    device.incoming_len = 32;
    controller.on_buffer(&device, .{ .num = .ep4, .dir = .Out });
    try std.testing.expect(t.pending != null);
    try std.testing.expectEqual(@as(usize, 6), device.listens);
    try std.testing.expectEqual(@as(usize, 0), base.buffers);
}

test "descriptor status OUT is armed after the final IN and cancelled by SETUP or reset" {
    var base = FakeBase{ .configured = false };
    var device = FakeUsb.DeviceInterface{};
    var controller = zigmkay.usb_control.Controller(FakeUsb, FakeBase){ .base = &base, .hooks = .{ .prepare = HookCapture.prepare, .reject = HookCapture.reject } };
    var descriptor = setupPacket(0x80, 0x0200, 0, 146);
    descriptor.request = 6;
    base.tx_slice = "old response";
    controller.on_setup_req(&device, &descriptor);
    try std.testing.expect(base.tx_slice == null);
    // The upstream controller keeps a slice until the last data completion.
    base.tx_slice = "remaining descriptor bytes";
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 0), device.listens);
    base.tx_slice = null;
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 1), device.listens);
    try std.testing.expectEqual(@as(usize, 0), device.last_listen_length);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 1), device.listens);

    controller.on_setup_req(&device, &descriptor);
    var configure = setupPacket(0x00, 1, 0, 0);
    controller.on_setup_req(&device, &configure);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 1), device.listens);
    controller.on_setup_req(&device, &descriptor);
    controller.on_bus_reset(&device);
    controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
    try std.testing.expectEqual(@as(usize, 1), device.listens);
}

test "GetConfiguration returns current configuration and completes its OUT status stage" {
    var base = FakeBase{ .configured = false };
    var device = FakeUsb.DeviceInterface{};
    var controller = zigmkay.usb_control.Controller(FakeUsb, FakeBase){ .base = &base, .hooks = .{ .prepare = HookCapture.prepare, .reject = HookCapture.reject } };
    var query = setupPacket(0x80, 0, 0, 1);
    query.request = 8;
    for ([_]u16{ 0, 1, 0 }) |configuration| {
        base.cfg_num = configuration;
        controller.on_setup_req(&device, &query);
        try std.testing.expectEqual(@as(usize, 1), device.written_length);
        try std.testing.expectEqual(@as(u8, @intCast(configuration)), device.written[0]);
        controller.on_buffer(&device, .{ .num = .ep0, .dir = .In });
        try std.testing.expectEqual(@as(usize, 0), device.last_listen_length);
    }
    try std.testing.expectEqual(@as(usize, 3), device.listens);
    try std.testing.expectEqual(@as(usize, 0), base.setup_count);
    query.length.value = 2;
    controller.on_setup_req(&device, &query);
    try std.testing.expectEqual(@as(usize, 1), base.setup_count);
}

test "configuration and HID descriptor requests use wire bytes with host length limits" {
    var base = FakeBase{ .configured = false };
    var device = FakeUsb.DeviceInterface{};
    const configuration: [146]u8 = @splat(0x55);
    const hid = [_][9]u8{.{ 9, 0x21, 0x11, 1, 0, 1, 0x22, 65, 0 }};
    var controller = zigmkay.usb_control.Controller(FakeUsb, FakeBase){
        .base = &base,
        .configuration_descriptor = &configuration,
        .hid_descriptors = &hid,
        .hooks = .{ .prepare = HookCapture.prepare, .reject = HookCapture.reject },
    };
    var request = setupPacket(0x80, 0x0200, 0, 9);
    request.request = 6;
    controller.on_setup_req(&device, &request);
    try std.testing.expectEqual(@as(usize, 9), device.written_length);
    try std.testing.expectEqual(@as(usize, 0), base.tx_slice.?.len);
    request.length.value = 255;
    controller.on_setup_req(&device, &request);
    try std.testing.expectEqual(@as(usize, 64), device.written_length);
    try std.testing.expectEqual(@as(usize, 82), base.tx_slice.?.len);
    request.request_type.raw = 0x81;
    request.value.value = 0x2100;
    controller.on_setup_req(&device, &request);
    try std.testing.expectEqualSlices(u8, &hid[0], device.written[0..device.written_length]);
    try std.testing.expectEqual(@as(usize, 0), base.setup_count);
    request.index.value = 1;
    controller.on_setup_req(&device, &request);
    try std.testing.expectEqual(@as(usize, 1), base.setup_count);
}

test "reserved custom signals bypass full keyboard queue and preserve sequenced release" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    var output = core.OutputCommandQueue.Create();
    output.companion_signals = t.signalSink();
    while (true) output.queue.enqueue(.{ .KeyCodePress = 4 }) catch break;
    const before = output.Count();
    try output.send_raw_hid_signal(core.CUSTOM_ID_COMPANION_TOGGLE, &.{1});
    try std.testing.expect(output.send_companion_custom(core.CUSTOM_ID_COMPANION_TOGGLE, false));
    try std.testing.expectEqual(before, output.Count());
    for (0..2) |_| t.pump(fake.endpoint());
    const press = try fake.packet(5);
    const release = try fake.packet(6);
    try std.testing.expect(press.payload.signal.pressed);
    try std.testing.expect(!release.payload.signal.pressed);
    try std.testing.expectEqual(press.sequence +% 1, release.sequence);
}

test "fixed transport storage stays below one KiB" {
    try std.testing.expect(@sizeOf(transport.Transport) <= 1024);
}

test "reserved tap and hold custom actions send sequenced press and release" {
    const dimensions = core.KeymapDimensions{ .key_count = 2, .layer_count = 1 };
    const keymap = [_][2]?core.KeyDef{.{
        .{ .tap_only = .{ .custom = core.CUSTOM_ID_COMPANION_TOGGLE } },
        .{ .hold_only = .{ .custom = core.CUSTOM_ID_COMPANION_LOG_TOGGLE } },
    }};
    const sides = [_]core.Side{ .L, .R };
    const P = zigmkay.processing.CreateProcessorType(&dimensions, &keymap, &sides, &.{}, &.{}, &.{});
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    output.companion_signals = t.signalSink();
    var processor = P{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    for (0..4) |i| {
        const at = core.TimeSinceBoot.from_absolute_us(i * 1000);
        try input.enqueue(.{ .pressed = i % 2 == 0, .key_index = @intCast(i / 2), .time = at });
        try processor.Process(at);
        t.pump(fake.endpoint());
        const packet = try fake.packet(5 + i);
        try std.testing.expectEqual(@as(u16, @intCast(i)), packet.sequence);
        try std.testing.expectEqual(i % 2 == 0, packet.payload.signal.pressed);
    }
    try std.testing.expectEqual(@as(usize, 0), output.Count());
}

test "combined reserved custom and keyboard action emits only after successful retry" {
    const dimensions = core.KeymapDimensions{ .key_count = 2, .layer_count = 1 };
    const keymap = [_][2]?core.KeyDef{.{
        .{ .tap_only = .{ .custom = core.CUSTOM_ID_COMPANION_TOGGLE, .key_press = .{ .tap_keycode = 4 } } },
        .{ .hold_only = .{ .custom = core.CUSTOM_ID_COMPANION_LOG_TOGGLE, .hold_modifiers = .{ .left_ctrl = true } } },
    }};
    const sides = [_]core.Side{ .L, .R };
    const P = zigmkay.processing.CreateProcessorType(&dimensions, &keymap, &sides, &.{}, &.{}, &.{});
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    output.companion_signals = t.signalSink();
    var processor = P{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    for (0..2) |i| {
        while (true) output.queue.enqueue(.{ .KeyCodePress = 5 }) catch break;
        const at = core.TimeSinceBoot.from_absolute_us(i * 1000);
        try input.enqueue(.{ .pressed = true, .key_index = @intCast(i), .time = at });
        try std.testing.expectError(error.CapacityExceeded, processor.Process(at));
        try std.testing.expectEqual(@as(usize, 0), t.delta_count);
        while (output.dequeue() != null) {}
        try processor.Process(at);
        t.pump(fake.endpoint());
        const packet = try fake.packet(5 + i);
        try std.testing.expect(packet.payload.signal.pressed);
        try std.testing.expectEqual(@as(u16, @intCast(i)), packet.sequence);
        try processor.Process(at);
        try std.testing.expectEqual(@as(usize, 0), t.delta_count);
    }
}

test "direct companion special key taps bypass full keyboard queue using v2 intents" {
    var t = transport.Transport.init(identity);
    var fake = Fake{};
    try synchronize(&t, &fake);
    var output = core.OutputCommandQueue.Create();
    output.companion_signals = t.signalSink();
    while (true) output.queue.enqueue(.{ .KeyCodePress = 4 }) catch break;
    const before = output.Count();
    try output.tap_key(core.KC_COMPANION);
    try output.tap_key(core.KC_SHUTDOWN_COMPANION);
    try std.testing.expectEqual(before, output.Count());
    for (0..4) |_| t.pump(fake.endpoint());
    try std.testing.expectEqual(protocol.SignalKind.overlay_toggle, (try fake.packet(5)).payload.signal.kind);
    try std.testing.expect(!(try fake.packet(6)).payload.signal.pressed);
    try std.testing.expectEqual(protocol.SignalKind.shutdown, (try fake.packet(7)).payload.signal.kind);
    try std.testing.expect(!(try fake.packet(8)).payload.signal.pressed);
}
