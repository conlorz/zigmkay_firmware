const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const protocol = zigmkay.telemetry;
const helpers = @import("test_processing_helpers.zig");

const Capture = struct {
    signals: [6]protocol.Signal = undefined,
    count: usize = 0,
    fn write(context: *anyopaque, signal: protocol.Signal) void {
        const self: *Capture = @ptrCast(@alignCast(context));
        self.signals[self.count] = signal;
        self.count += 1;
    }
};

test "reserved custom controls preserve press release and independent typing" {
    const ids = [_]u8{ core.CUSTOM_ID_COMPANION_TOGGLE, core.CUSTOM_ID_COMPANION_LOG_TOGGLE, core.CUSTOM_ID_COMPANION_SHUTDOWN };
    const kinds = [_]protocol.SignalKind{ .overlay_toggle, .log_toggle, .shutdown };
    const map = comptime [_][4]?core.KeyDef{.{ zigmkay.macros.SIG(ids[0]), zigmkay.macros.SIG(ids[1]), zigmkay.macros.SIG(ids[2]), helpers.TAP(4) }};
    var processor = helpers.init_with_config(.{ .key_count = 4, .layer_count = 1 }, .{ .keymap = &map }){};
    var captured = Capture{};
    processor.actions_queue.companion_signals = .{ .context = &captured, .write = Capture.write };
    const time = core.TimeSinceBoot.from_absolute_us(1000);
    for (ids, 0..) |_, index| {
        try processor.press_key(@intCast(index), time);
        try processor.release_key(@intCast(index), time);
    }
    try processor.press_key(3, time);
    try processor.release_key(3, time);
    try processor.process(time);
    try std.testing.expectEqual(@as(usize, 6), captured.count);
    for (kinds, 0..) |kind, index| {
        try std.testing.expectEqual(protocol.Signal{ .kind = kind, .pressed = true }, captured.signals[index * 2]);
        try std.testing.expectEqual(protocol.Signal{ .kind = kind, .pressed = false }, captured.signals[index * 2 + 1]);
    }
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = 4 }, processor.actions_queue.dequeue().?);
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = 4 }, processor.actions_queue.dequeue().?);
    try std.testing.expect(processor.actions_queue.dequeue() == null);

    // A missing optional sink consumes custom actions without keyboard output.
    processor.actions_queue.companion_signals = null;
    try processor.press_key(0, time);
    try processor.release_key(0, time);
    try processor.press_key(3, time);
    try processor.release_key(3, time);
    try processor.process(time);
    try std.testing.expectEqual(@as(usize, 6), captured.count);
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = 4 }, processor.actions_queue.dequeue().?);
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = 4 }, processor.actions_queue.dequeue().?);
    try std.testing.expect(processor.actions_queue.dequeue() == null);
}
