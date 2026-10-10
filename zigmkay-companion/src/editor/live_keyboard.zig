//! Presentation boundary for a verified running keyboard. OS text/scancodes
//! cannot identify physical keys or reproduce firmware layer decisions.
const std = @import("std");
const cache = @import("../components/cache.zig");
const companion = @import("companion-model");
const Modifiers = @import("layout-model").Modifiers;

pub const Frame = struct {
    labels: ?*const cache.LabelCache = null,
    profile: [8]u8 = @splat(0),
    stale: bool = true,
    layer: usize = 0,
    active: u16 = 1,
    modifiers: Modifiers = .{},
    pressed: [128]bool = @splat(false),

    /// The caller supplies labels only after matching the complete firmware
    /// identity. Missing telemetry and dimension mismatch never show a draft.
    pub fn select(labels: ?*const cache.LabelCache, state: ?companion.State, profile: [8]u8, stale: bool) Frame {
        var frame = Frame{ .profile = profile };
        const verified = labels orelse return frame;
        const current = state orelse return frame;
        if (verified.key_count != current.dimensions.key_count or verified.layer_count != current.dimensions.layer_count) return frame;
        frame.labels = verified;
        frame.stale = stale or current.needs_resync;
        // Stale snapshots retain profile captions but must not suggest a key
        // is still held or a momentary layer is still active after disconnect.
        if (!frame.stale) {
            frame.layer = current.highest_layer;
            frame.active = current.active_layers;
            frame.modifiers = current.modifiers;
            frame.pressed = current.pressed;
        }
        return frame;
    }

    pub fn content(self: *const Frame, key_index: usize) ?*const cache.CachedKeyContent {
        const labels = self.labels orelse return null;
        if (key_index >= labels.key_count) return null;
        return labels.lookupActive(self.layer, key_index, self.modifiers, self.active);
    }
};

test "unverified or mismatched keyboard has no fabricated layout" {
    var labels = try cache.LabelCache.init(std.testing.allocator, 4, 34);
    defer labels.deinit();
    const state = try companion.State.init(.{ .key_count = 34, .layer_count = 4 });
    try std.testing.expect(Frame.select(null, state, "eurmac\x00\x00".*, false).labels == null);
    try std.testing.expect(Frame.select(&labels, null, "eurmac\x00\x00".*, false).labels == null);
    const wrong = try companion.State.init(.{ .key_count = 34, .layer_count = 3 });
    try std.testing.expect(Frame.select(&labels, wrong, "eurmac\x00\x00".*, false).labels == null);
}

const zigmkay = @import("zigmkay");
const protocol = @import("device-protocol");
const core = zigmkay.core;
const project = @import("keymap-project");
const dimensions = @import("layout-model").KeymapDimensions{ .key_count = 34, .layer_count = 4 };
const physical_map: [4][34]?core.KeyDef = blk: {
    var map: [4][34]?core.KeyDef = @splat(@splat(null));
    map[0][19] = .{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 42 } }, .hold = .{ .hold_layer = 3 }, .tapping_term = .{ .ms = 180 } } };
    map[0][30] = .{ .hold_only = .{ .hold_layer = 1 } };
    map[0][31] = .{ .hold_only = .{ .hold_layer = 2 } };
    map[0][10] = .{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } };
    map[1][10] = .{ .tap_only = .{ .key_press = .{ .tap_keycode = 5 } } };
    map[3][10] = .{ .tap_only = .{ .key_press = .{ .tap_keycode = 7 } } };
    break :blk map;
};
const sides: [34]core.Side = blk: {
    var result: [34]core.Side = @splat(.X);
    result[19] = .R;
    break :blk result;
};
const Processor = zigmkay.processing.CreateProcessorType(&dimensions, &physical_map, &sides, &.{}, &.{}, &.{});

/// Encode actual processor observer events and decode them through the same
/// portable telemetry reducer used by the live session before presentation.
const Trace = struct {
    state: companion.State,
    failed: bool = false,
    fn receive(context: *anyopaque, message: protocol.Message) bool {
        const self: *Trace = @ptrCast(@alignCast(context));
        const bytes = protocol.encode(message, dimensions) catch {
            self.failed = true;
            return false;
        };
        self.state.receive(&bytes) catch {
            self.failed = true;
            return false;
        };
        return true;
    }
};

fn physicalInput(processor: *Processor, inputs: *core.MatrixStateChangeQueue, index: @import("layout-model").KeyIndex, down: bool, time: u64) !void {
    try inputs.enqueue(.{ .key_index = index, .pressed = down, .time = core.TimeSinceBoot.from_absolute_us(time) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(time));
}

const Source = struct {
    pub fn keyToText(_: *Source, input: @import("zkeymap").KeyCodeFire) @import("zkeymap").TextResult {
        if (!@import("zkeymap").isLayoutDependent(input.tap_keycode)) {
            var result: @import("zkeymap").TextResult = .{};
            result.data[0..2].* = @bitCast(@as(u16, input.tap_keycode));
            return result;
        }
        return .{ .data = .{ @as(u8, 'a') + input.tap_keycode - 4, 0, 0, 0 }, .len = 1 };
    }
};

/// Native acceptance drives an actual processor independently of ordinary OS
/// text events. It verifies the same presentation source as drawFreeCompanion.
pub const NativeDriver = struct {
    pub const capture_frame = 25;
    trace: Trace = .{ .state = .{ .dimensions = dimensions } },
    inputs: core.MatrixStateChangeQueue = core.MatrixStateChangeQueue.Create(),
    encoders: core.EncoderEventQueue = core.EncoderEventQueue.Create(),
    output: core.OutputCommandQueue = core.OutputCommandQueue.Create(),
    processor: ?Processor = null,
    sequence: u64 = 0,
    initialized: bool = false,
    stale: bool = false,

    pub fn setup(editor: anytype) !void {
        var loaded = try project.profiles.create(editor.gpa, .eurmac);
        defer loaded.deinit();
        var actions: [4][34]?project.Action = undefined;
        var layers: [4]project.Layer = undefined;
        for (&layers, 0..) |*layer, index| layer.* = .{ .id = @intCast(index + 1), .name = if (index == 3) "Orange" else "Navigation", .actions = &actions[index] };
        for (physical_map, &actions) |map, *target| for (map, target) |action, *value| {
            value.* = if (action) |def| try project.adapter.liftAction(&layers, def) else null;
        };
        var snapshot = loaded.snapshot;
        snapshot.document.name = "Physical keyboard integration trace";
        snapshot.document.layers = &layers;
        snapshot.document.combos = &.{};
        try editor.model.commit(snapshot);
        editor.main_view = .try_it_out;
        editor.try_mode = .free_typing;
        editor.practice_show_keyboard = true;
        editor.free_text.clear();
    }

    pub fn beforeDraw(self: *NativeDriver, editor: anytype, window: *@import("dvui").Window, frame: usize) !void {
        if (!self.initialized) {
            self.initialized = true;
            self.sequence = editor.testing.sequence;
            self.processor = .{ .input_matrix_changes = &self.inputs, .encoder_event_changes = &self.encoders, .output_usb_commands = &self.output };
            self.processor.?.observer.sink = .{ .context = &self.trace, .write = Trace.receive };
        }
        if (frame == 2) {
            const tag = @import("dvui").tagGet("free.input") orelse return error.LiveInputFieldMissing;
            window.focusWidget(tag.id, null, null);
            editor.free_focus = true;
        }
        switch (frame) {
            3 => try self.hostText(editor, window, "a"),
            4 => try self.hostText(editor, window, "é"),
            5 => try self.hostText(editor, window, "λ"),
            6 => try physicalInput(&self.processor.?, &self.inputs, 30, true, 0),
            8 => try physicalInput(&self.processor.?, &self.inputs, 30, false, 50_000),
            9 => try physicalInput(&self.processor.?, &self.inputs, 19, true, 100_000),
            10 => {
                try physicalInput(&self.processor.?, &self.inputs, 19, false, 150_000);
                try std.testing.expectEqualDeep(core.OutputCommand{ .KeyCodePress = 42 }, self.output.dequeue().?);
                try std.testing.expectEqualDeep(core.OutputCommand{ .KeyCodeRelease = 42 }, self.output.dequeue().?);
                var event = std.mem.zeroes(@import("sdl-backend").c.SDL_Event);
                event.type = @import("sdl-backend").c.SDL_EVENT_KEY_DOWN;
                event.key.windowID = editor.window_id;
                event.key.scancode = @import("sdl-backend").c.SDL_SCANCODE_BACKSPACE;
                if (try editor.raw(event)) return error.LiveBackspaceIntercepted;
                _ = try window.addEventKey(.{ .code = .backspace, .action = .down, .mod = .none });
            },
            12 => try physicalInput(&self.processor.?, &self.inputs, 19, true, 1_000_000),
            13 => try self.processor.?.Process(core.TimeSinceBoot.from_absolute_us(1_179_000)),
            14 => try self.processor.?.Process(core.TimeSinceBoot.from_absolute_us(1_180_001)),
            16 => try physicalInput(&self.processor.?, &self.inputs, 19, false, 1_200_000),
            18 => try physicalInput(&self.processor.?, &self.inputs, 30, true, 1_300_000),
            19 => self.stale = true,
            20 => try self.hostText(editor, window, "Ω"),
            22 => try physicalInput(&self.processor.?, &self.inputs, 30, false, 1_350_000),
            23 => self.stale = false,
            else => {},
        }
        editor.practice_live_labels = try editor.practiceLabels();
        editor.practice_live_state = self.trace.state;
        editor.practice_live_profile = editor.model.document().profile_id;
        editor.practice_live_stale = self.stale;
    }

    fn hostText(_: *NativeDriver, editor: anytype, window: *@import("dvui").Window, text: [:0]const u8) !void {
        var event = std.mem.zeroes(@import("sdl-backend").c.SDL_Event);
        event.type = @import("sdl-backend").c.SDL_EVENT_TEXT_INPUT;
        event.text.windowID = editor.window_id;
        event.text.text = @constCast(text.ptr);
        if (try editor.raw(event)) return error.LiveTextIntercepted;
        _ = try window.addEventText(.{ .text = text });
    }

    pub fn afterDraw(self: *NativeDriver, editor: anytype, frame_number: usize) !void {
        const testing = std.testing;
        const presented = Frame.select(editor.practice_live_labels, editor.practice_live_state, editor.practice_live_profile, editor.practice_live_stale);
        if (presented.labels == null or !std.mem.eql(u8, &presented.profile, &editor.model.document().profile_id)) return error.LiveCompanionLostVerifiedLayout;
        const source_tag = @import("dvui").tagGet("free.keyboard.source") orelse return error.LiveCompanionSourceMissing;
        const keyboard = @import("dvui").tagGet("free.keyboard") orelse return error.LiveCompanionMissing;
        if (!source_tag.visible or !keyboard.visible or @import("dvui").tagGet("free.keyboard.unavailable") != null) return error.LiveCompanionNotRendered;
        const expected_text: []const u8 = if (frame_number >= 20) "aéΩ" else if (frame_number >= 10) "aé" else if (frame_number >= 5) "aéλ" else if (frame_number >= 4) "aé" else if (frame_number >= 3) "a" else "";
        try testing.expectEqualStrings(expected_text, editor.free_text.value());
        const expected_layer: usize = if ((frame_number >= 6 and frame_number < 8) or frame_number == 18) 1 else if (frame_number >= 14 and frame_number < 16) 3 else 0;
        try testing.expectEqual(expected_layer, presented.layer);
        try testing.expectEqual(frame_number >= 19 and frame_number < 23, presented.stale);
        try testing.expectEqual((frame_number >= 6 and frame_number < 8) or frame_number == 18, presented.pressed[30]);
        try testing.expectEqual((frame_number == 9) or (frame_number >= 12 and frame_number < 16), presented.pressed[19]);
        for (31..34) |index| try testing.expect(!presented.pressed[index]);
        var buffer: [256]u8 = undefined;
        const document = editor.model.document();
        var fixture: @import("practice_layout.zig").Fixture = .{};
        const caption = if (editor.source) |*source| @import("labels.zig").keycapWithLayout(source, document.layers[0].actions[19], document, @bitCast(presented.modifiers.toByte()), &buffer) else @import("labels.zig").keycapWithLayout(&fixture, document.layers[0].actions[19], document, @bitCast(presented.modifiers.toByte()), &buffer);
        try testing.expectEqualStrings(caption, presented.content(19).?.caption.?);
        const action_layer: usize = if (expected_layer == 3) 3 else if (expected_layer == 1) 1 else 0;
        const layer_caption = if (editor.source) |*source| @import("labels.zig").keycapWithLayout(source, document.layers[action_layer].actions[10], document, @bitCast(presented.modifiers.toByte()), &buffer) else @import("labels.zig").keycapWithLayout(&fixture, document.layers[action_layer].actions[10], document, @bitCast(presented.modifiers.toByte()), &buffer);
        try testing.expectEqualStrings(layer_caption, presented.content(10).?.caption.?);
        if (self.trace.failed or editor.testing.sequence != self.sequence or editor.testing.job != null) return error.LiveNativeInputEnteredRunner;
        if (self.output.dequeue() != null) return error.LiveHoldProducedUnexpectedText;
        if (frame_number == capture_frame) std.log.info("Native live keyboard integration passed: physical thumb without OS output, Unicode single Backspace, pinky hold Orange timing, actual captions, stale state and native text independence", .{});
    }
};

test "real processor physical thumb and pinky telemetry drive live companion captions and layers" {
    const testing = std.testing;
    var actions: [4][34]?project.Action = undefined;
    var layers: [4]project.Layer = undefined;
    for (&layers, 0..) |*layer, index| layer.* = .{ .id = @intCast(index + 1), .name = if (index == 3) "Orange" else "Navigation", .actions = &actions[index] };
    for (physical_map, &actions) |map, *target| for (map, target) |action, *value| {
        value.* = if (action) |def| try project.adapter.liftAction(&layers, def) else null;
    };
    const document: project.Document = .{ .schema_version = 1, .board_id = "lk7\x00\x00\x00\x00\x00".*, .profile_id = "trace\x00\x00\x00".*, .name = "Actual physical trace", .physical_layout = "lk7_schematic_v1", .key_ids = &project.profiles.key_ids, .layers = &layers };
    var source: Source = .{};
    var labels = try cache.buildProjectCache(testing.allocator, &source, document);
    defer labels.deinit();
    var trace = Trace{ .state = try companion.State.init(dimensions) };
    var inputs = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var processor = Processor{ .input_matrix_changes = &inputs, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    processor.observer.sink = .{ .context = &trace, .write = Trace.receive };
    var frame = Frame.select(&labels, trace.state, document.profile_id, false);
    var buffer: [256]u8 = undefined;
    try testing.expectEqualStrings(@import("labels.zig").keycap(actions[0][19], document, &buffer), frame.content(19).?.caption.?);

    // A quick actual pinky tap emits Backspace, without moving to a thumb.
    try physicalInput(&processor, &inputs, 19, true, 0);
    frame = Frame.select(&labels, trace.state, document.profile_id, false);
    try testing.expect(frame.pressed[19]);
    for (30..34) |thumb| try testing.expect(!frame.pressed[thumb]);
    try testing.expectEqual(@as(usize, 0), frame.layer);
    try physicalInput(&processor, &inputs, 19, false, 50_000);
    try testing.expectEqualDeep(core.OutputCommand{ .KeyCodePress = 42 }, output.dequeue().?);
    try testing.expectEqualDeep(core.OutputCommand{ .KeyCodeRelease = 42 }, output.dequeue().?);
    try testing.expect(output.dequeue() == null);

    // Holding exactly that same physical key follows firmware's tapping term.
    try physicalInput(&processor, &inputs, 19, true, 100_000);
    try processor.Process(core.TimeSinceBoot.from_absolute_us(279_000));
    try testing.expectEqual(@as(usize, 0), Frame.select(&labels, trace.state, document.profile_id, false).layer);
    try processor.Process(core.TimeSinceBoot.from_absolute_us(280_001));
    frame = Frame.select(&labels, trace.state, document.profile_id, false);
    try testing.expectEqual(@as(usize, 3), frame.layer);
    try testing.expectEqual(@as(u16, 0b1001), frame.active);
    try testing.expect(frame.pressed[19]);
    try testing.expectEqualStrings("d", frame.content(10).?.label.?);
    try testing.expectEqualStrings(@import("labels.zig").keycap(actions[0][19], document, &buffer), frame.content(19).?.caption.?);
    try physicalInput(&processor, &inputs, 19, false, 300_000);
    try testing.expect(output.dequeue() == null);

    // A layer-only left thumb has no OS keycode, but remains visible immediately.
    try physicalInput(&processor, &inputs, 30, true, 400_000);
    frame = Frame.select(&labels, trace.state, document.profile_id, false);
    try testing.expect(frame.pressed[30]);
    try testing.expectEqual(@as(usize, 1), frame.layer);
    try testing.expectEqualStrings("b", frame.content(10).?.label.?);
    try physicalInput(&processor, &inputs, 30, false, 450_000);
    try physicalInput(&processor, &inputs, 31, true, 500_000);
    frame = Frame.select(&labels, trace.state, document.profile_id, false);
    try testing.expectEqual(@as(u16, 0b0101), frame.active);
    // Disabled Navigation must not supply B through transparent layer 2.
    try testing.expectEqualStrings("a", frame.content(10).?.label.?);
    const stale = Frame.select(&labels, trace.state, document.profile_id, true);
    try testing.expectEqual(@as(usize, 0), stale.layer);
    for (stale.pressed) |down| try testing.expect(!down);
    try physicalInput(&processor, &inputs, 31, false, 550_000);
    frame = Frame.select(&labels, trace.state, document.profile_id, false);
    try testing.expectEqual(@as(usize, 0), frame.layer);
    for (frame.pressed) |down| try testing.expect(!down);
    try testing.expect(!trace.failed);
}
