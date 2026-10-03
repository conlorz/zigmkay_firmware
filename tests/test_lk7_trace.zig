const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const lk7 = @import("lk7-keymap");
const protocol = @import("device-protocol");
const companion = @import("companion-model");
const Processor = zigmkay.processing.CreateProcessorType(&lk7.dimensions, &lk7.keymap, &lk7.sides, &lk7.combos, &lk7.custom_functions, &.{});

const Capture = struct {
    reports: [16]protocol.Report = undefined,
    count: usize = 0,
    full: bool = false,
    failure: ?anyerror = null,
    state: companion.State = companion.State.init(lk7.dimensions) catch unreachable,

    fn write(context: *anyopaque, message: protocol.Message) bool {
        const self: *Capture = @ptrCast(@alignCast(context));
        if (self.full or self.count == self.reports.len) return false;
        const report = protocol.encode(message, lk7.dimensions) catch |err| {
            self.failure = err;
            return false;
        };
        self.state.receive(&report) catch |err| {
            self.failure = err;
            return false;
        };
        self.reports[self.count] = report;
        self.count += 1;
        return true;
    }
};

const Mode = enum { capture, disabled, full };
const Result = struct { output: [6]core.OutputCommand, capture: Capture, drops: u32 };

fn event(input: *core.MatrixStateChangeQueue, processor: *Processor, pressed: bool, index: core.KeyIndex, at_us: u64) !void {
    try input.enqueue(.{ .pressed = pressed, .key_index = index, .time = core.TimeSinceBoot.from_absolute_us(at_us) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(at_us));
}

fn trace(mode: Mode) !Result {
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var capture = Capture{ .full = mode == .full };
    var processor = Processor{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    if (mode != .disabled) processor.observer.sink = .{ .context = &capture, .write = Capture.write };
    try event(&input, &processor, true, 0, 0);
    if (mode == .capture) try std.testing.expect(capture.state.pressed[0]);
    // The base-layer Q participates in combos; allow the real decision timeout.
    try processor.Process(core.TimeSinceBoot.from_absolute_us(41_000));
    try event(&input, &processor, false, 0, 50_000);
    if (mode == .capture) try std.testing.expect(!capture.state.pressed[0]);
    try event(&input, &processor, true, 30, 100_000);
    if (mode == .capture) {
        try std.testing.expect(capture.state.pressed[30]);
        try std.testing.expectEqual(@as(core.LayerIndex, 0), capture.state.highest_layer);
    }
    // The real custom callback selects the arrows layer after the 150 ms hold.
    try processor.Process(core.TimeSinceBoot.from_absolute_us(251_000));
    if (mode == .capture) {
        try std.testing.expectEqual(@as(core.LayerIndex, 1), capture.state.highest_layer);
        try std.testing.expectEqual(@as(u16, 3), capture.state.active_layers);
        try std.testing.expectEqual(@as(usize, 4), capture.count);
    }
    try processor.Process(core.TimeSinceBoot.from_absolute_us(252_000));
    if (mode == .capture) try std.testing.expectEqual(@as(usize, 4), capture.count);
    try event(&input, &processor, true, 0, 300_000);
    if (mode == .capture) try std.testing.expect(capture.state.pressed[0]);
    try event(&input, &processor, false, 0, 310_000);
    if (mode == .capture) try std.testing.expect(!capture.state.pressed[0]);
    try event(&input, &processor, false, 30, 350_000);
    try processor.Process(core.TimeSinceBoot.from_absolute_us(351_000));
    if (capture.failure) |err| return err;
    if (mode == .capture) {
        for (capture.state.pressed) |pressed| try std.testing.expect(!pressed);
        try std.testing.expectEqual(@as(u16, 1), capture.state.active_layers);
        try std.testing.expectEqual(@as(core.LayerIndex, 0), capture.state.highest_layer);
        try std.testing.expectEqual(@as(u8, 0), capture.state.modifiers.toByte());
        try std.testing.expect(!capture.state.needs_resync);
    }
    try std.testing.expectEqual(@as(usize, 6), output.Count());
    var commands: [6]core.OutputCommand = undefined;
    for (&commands) |*command| command.* = output.dequeue().?;
    return .{ .output = commands, .capture = capture, .drops = processor.observer.dropped_events };
}

test "real LK7 press release and custom layer trace reaches exact bytes and companion state" {
    // Complete every trace before the next: LK7's custom callback still has global hold state.
    const captured = try trace(.capture);
    const disabled = try trace(.disabled);
    const full = try trace(.full);
    const expected = [_]core.OutputCommand{
        .{ .KeyCodePress = 0x14 },
        .{ .KeyCodeRelease = 0x14 },
        .{ .ModifiersChanged = .{ .left_shift = true } },
        .{ .KeyCodePress = 0x1E },
        .{ .KeyCodeRelease = 0x1E },
        .{ .ModifiersChanged = .{} },
    };
    try std.testing.expectEqualDeep(expected, captured.output);
    try std.testing.expectEqualDeep(expected, disabled.output);
    try std.testing.expectEqualDeep(expected, full.output);
    const fixture = @embedFile("fixtures/lk7_trace.bin");
    try std.testing.expectEqual(fixture.len / protocol.report_size, captured.capture.count);
    for (captured.capture.reports[0..captured.capture.count], 0..) |report, i| {
        try std.testing.expectEqualSlices(u8, fixture[i * protocol.report_size ..][0..protocol.report_size], &report);
    }
    try std.testing.expectEqual(@as(u32, 0), captured.drops);
    try std.testing.expectEqual(@as(u32, 8), full.drops);
}
