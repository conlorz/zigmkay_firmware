const std = @import("std");
const zigmkay = @import("zigmkay");
const lk7 = @import("lk7-keymap");
const protocol = @import("device-protocol");
const companion = @import("companion-model");
const adapter = @import("live-adapter");
const core = zigmkay.core;
const Firmware = zigmkay.telemetry_transport.Transport;
const Processor = zigmkay.processing.CreateProcessorType(&lk7.dimensions, &lk7.keymap, &lk7.sides, &lk7.combos, &lk7.custom_functions, &.{});
const identity = lk7.identity(protocol);

// A complete offline link: actual processor -> firmware queue -> native report
// framing -> companion adapter/session -> host requests -> firmware controller.
const Link = struct {
    firmware: *Firmware,
    present: bool = true,
    ready: bool = true,
    report: ?protocol.Report = null,
    clock: u64 = 0,
    pub fn discover(self: *Link, _: ?[]const u8) !adapter.Discovery {
        return if (self.present) .selected else .no_device;
    }
    fn accepted(context: *anyopaque, report: *const protocol.Report) bool {
        const self: *Link = @ptrCast(@alignCast(context));
        if (!self.ready or self.report != null) return false;
        self.report = report.*;
        return true;
    }
    pub fn read(self: *Link, bytes: *[33]u8) !usize {
        if (!self.present) return error.Disconnected;
        self.firmware.boundary();
        self.firmware.pump(.{ .context = self, .send = accepted });
        const report = self.report orelse return 0;
        @memcpy(bytes[0..32], &report);
        self.report = null;
        return 32;
    }
    pub fn write(self: *Link, bytes: []const u8) !void {
        if (!self.present) return error.Disconnected;
        if (bytes.len != 33 or bytes[0] != 0) return error.InvalidWrite;
        self.firmware.receive(bytes[1..]);
        self.firmware.boundary();
    }
    pub fn close(self: *Link) void {
        self.report = null;
        self.firmware.disconnect();
    }
    pub fn now(self: *Link) u64 {
        return self.clock;
    }
};

fn input(processor: *Processor, queue: *core.MatrixStateChangeQueue, pressed: bool, at_us: u64) !void {
    try queue.enqueue(.{ .pressed = pressed, .key_index = 3, .time = core.TimeSinceBoot.from_absolute_us(at_us) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(at_us));
}

test "LK7 processor firmware and overlay synchronize recover overload and reconnect together" {
    var firmware = Firmware.init(identity);
    var inputs = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var processor = Processor{ .input_matrix_changes = &inputs, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    processor.observer.sink = firmware.sink();
    try input(&processor, &inputs, true, 0);
    var driver = try adapter.Driver(Link).init(.{ .firmware = &firmware }, identity, 0, null);
    driver.poll(0);
    try std.testing.expectEqual(companion.Phase.live, driver.session.phase);
    try std.testing.expect(driver.session.state.pressed[3]);
    driver.transport.ready = false;
    try input(&processor, &inputs, false, 1_000);
    driver.poll(1);
    try std.testing.expect(driver.session.state.pressed[3]);
    for (0..32) |index| try input(&processor, &inputs, index % 2 == 0, (index + 2) * 1_000);
    try input(&processor, &inputs, true, 35_000);
    try std.testing.expect(firmware.recovery != null);
    driver.transport.ready = true;
    driver.poll(40);
    try std.testing.expectEqual(companion.Phase.live, driver.session.phase);
    try std.testing.expect(!driver.session.stale and driver.session.state.pressed[3]);
    try std.testing.expect(!driver.session.state.pressed[0]);
    const old_token = driver.session.token;
    driver.transport.present = false;
    driver.poll(50);
    try std.testing.expect(driver.session.stale and !driver.connected);
    try input(&processor, &inputs, false, 60_000);
    driver.transport.present = true;
    driver.poll(1_050);
    try std.testing.expectEqual(companion.Phase.live, driver.session.phase);
    try std.testing.expect(!driver.session.stale and !driver.session.state.pressed[3]);
    try std.testing.expect(driver.session.token != old_token);
    for (driver.session.state.pressed) |pressed| try std.testing.expect(!pressed);
}
