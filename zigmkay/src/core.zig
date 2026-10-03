const model = @import("layout-model");
const generic_queue = @import("generic_queue.zig");
const std = @import("std");
const string_printing = @import("string_printing.zig");

pub const special_keycode_BOOT = model.special_keycode_BOOT;
pub const special_keycode_PRINT_STATS = model.special_keycode_PRINT_STATS;
pub const special_keycode_COMPANION = model.special_keycode_COMPANION;
pub const special_keycode_SHUTDOWN_COMPANION = model.special_keycode_SHUTDOWN_COMPANION;
pub const CUSTOM_ID_COMPANION_LOG_TOGGLE = model.CUSTOM_ID_COMPANION_LOG_TOGGLE;
pub const CUSTOM_ID_COMPANION_SHUTDOWN = model.CUSTOM_ID_COMPANION_SHUTDOWN;
pub const CUSTOM_ID_COMPANION_TOGGLE = model.CUSTOM_ID_COMPANION_TOGGLE;
pub const KC_BOOT = model.KC_BOOT;
pub const KC_PRINT_STATS = model.KC_PRINT_STATS;
pub const KC_COMPANION = model.KC_COMPANION;
pub const KC_SHUTDOWN_COMPANION = model.KC_SHUTDOWN_COMPANION;
pub const Modifiers = model.Modifiers;
pub const KeymapDimensions = model.KeymapDimensions;
pub const MouseAction = model.MouseAction;
pub const TapDef = model.TapDef;
pub const MediaCode = model.MediaCode;
pub const HoldDef = model.HoldDef;
pub const TapHoldDef = model.TapHoldDef;
pub const KeyDef = model.KeyDef;
pub const Side = model.Side;
pub const Combo2Def = model.Combo2Def;
pub const AutoFireDef = model.AutoFireDef;
pub const TimeSpan = model.TimeSpan;
pub const KeyIndex = model.KeyIndex;
pub const LayerIndex = model.LayerIndex;

const queue_capacities = 250;

// Matrix events: switch press/release,
pub const UartMessage = packed struct {
    pressed: bool,
    key_index: u7,
    pub fn toByte(self: UartMessage) u8 {
        return @bitCast(self);
    }
    pub fn fromByte(byte_val: u8) UartMessage {
        return @bitCast(byte_val);
    }
};

pub const LogMessage = extern struct {
    pressed: bool,
    key_index: u8,
    layer: u8,
    modifiers: Modifiers,
    pub fn toBytes(self: LogMessage) [4]u8 {
        return @bitCast(self);
    }
    pub fn fromBytes(bytes: [4]u8) LogMessage {
        return @bitCast(bytes);
    }
};
pub const MatrixStateChange = struct { pressed: bool, key_index: KeyIndex, time: TimeSinceBoot };
pub const MatrixStateChangeQueue = generic_queue.GenericQueue(MatrixStateChange, queue_capacities);
pub const EncoderEventQueue = generic_queue.GenericQueue(EncoderEvent, queue_capacities);

pub const EncoderAction = model.EncoderAction;
pub const EncoderEvent = struct {
    encoder_action_index: u8,
};
pub const KeyCodeFire = model.KeyCodeFire;

// Media Key Codes (Consumer Page)
pub const MEDIA_VOLUME_UP = model.MEDIA_VOLUME_UP;
pub const MEDIA_VOLUME_DOWN = model.MEDIA_VOLUME_DOWN;
pub const MEDIA_MUTE = model.MEDIA_MUTE;
pub const MEDIA_PLAY_PAUSE = model.MEDIA_PLAY_PAUSE;
pub const MEDIA_NEXT_TRACK = model.MEDIA_NEXT_TRACK;
pub const MEDIA_PREV_TRACK = model.MEDIA_PREV_TRACK;

// USB output
pub const OutputCommand = union(enum) {
    KeyCodePress: u8,
    KeyCodeRelease: u8,
    ModifiersChanged: Modifiers,
    ActivateBootMode,
    RawHidSignal: struct { signal_id: u8, data: [8]u8, len: u8 },
    ConsumerKeyPressed: MediaCode,
    ConsumerKeyReleased: MediaCode,
    MouseCommandPressed: MouseAction,
    MouseCommandReleased: MouseAction,
};
pub const OutputCommandQueue = struct {
    const QueueType = generic_queue.GenericQueue(OutputCommand, queue_capacities);
    currently_pressed_keycodes: [256]bool = [1]bool{false} ** 256,
    queue: QueueType = QueueType.Create(),
    current_mods: Modifiers = .{}, // holds the latest submitted
    pub fn Create() OutputCommandQueue {
        return OutputCommandQueue{};
    }
    pub fn dequeue(self: *OutputCommandQueue) ?OutputCommand {
        return self.queue.dequeue();
    }
    pub fn Count(self: *OutputCommandQueue) usize {
        return self.queue.Count();
    }
    pub fn has_events(self: *OutputCommandQueue) bool {
        return self.queue.Count() > 0;
    }
    pub fn go_to_boot_mode(self: *OutputCommandQueue) !void {
        try self.queue.enqueue(OutputCommand.ActivateBootMode);
    }

    pub fn tap_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        try press_key(self, tap);
        try release_key(self, tap);
    }
    pub fn press_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        if (self.currently_pressed_keycodes[tap.tap_keycode]) {
            try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });
            self.currently_pressed_keycodes[tap.tap_keycode] = false;
        }

        if (tap.tap_modifiers.has_any()) {
            const temp_mods = self.current_mods.add(tap.tap_modifiers);
            try self.queue.enqueue(.{ .ModifiersChanged = temp_mods });

            try self.queue.enqueue(.{ .KeyCodePress = tap.tap_keycode });
            try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });

            try self.queue.enqueue(.{ .ModifiersChanged = self.current_mods });
        } else {
            self.currently_pressed_keycodes[tap.tap_keycode] = true;
            try self.queue.enqueue(.{ .KeyCodePress = tap.tap_keycode });
        }
    }
    pub fn release_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        if (tap.tap_modifiers.has_any()) {
            return; // if modifiers exist, release has already been fire
        }
        if (self.currently_pressed_keycodes[tap.tap_keycode] == false) {
            return; // release has already been fired per #CASE 1
        }
        try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });
        self.currently_pressed_keycodes[tap.tap_keycode] = false;
    }
    pub fn get_current_modifiers(self: *OutputCommandQueue) Modifiers {
        return self.current_mods;
    }
    pub fn set_mods(self: *OutputCommandQueue, modifiers: Modifiers) !void {
        if (self.current_mods.toByte() != modifiers.toByte()) {}
        self.current_mods = modifiers;
        try self.queue.enqueue(.{ .ModifiersChanged = modifiers });
    }

    pub fn send_raw_hid_signal(self: *OutputCommandQueue, signal_id: u8, data: []const u8) !void {
        var buf: [8]u8 = [_]u8{0} ** 8;
        const len = @min(data.len, 8);
        @memcpy(buf[0..len], data[0..len]);
        try self.queue.enqueue(.{ .RawHidSignal = .{ .signal_id = signal_id, .data = buf, .len = @intCast(len) } });
    }

    pub fn print_string(self: *OutputCommandQueue, string: []u8) !void {
        try string_printing.print_string(string, self);
    }
};
pub const TimeSinceBoot = struct {
    time_since_boot_us: u64,

    pub fn from_absolute_us(time_us: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = time_us };
    }
    pub fn add_us(self: *const TimeSinceBoot, delta_us: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = self.time_since_boot_us + delta_us };
    }
    pub fn add_ms(self: *const TimeSinceBoot, delta_ms: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = self.time_since_boot_us + delta_ms * 1000 };
    }
    pub fn add(self: *const TimeSinceBoot, delta: TimeSpan) TimeSinceBoot {
        return self.add_ms(delta.ms);
    }
    pub fn diff_us(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        if (self.time_since_boot_us < other.time_since_boot_us) {
            return DiffError.CurrentIsEarlierThanInput;
        }
        return self.time_since_boot_us - other.time_since_boot_us;
    }
    pub fn diff_ms(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        return try self.diff_us(other) * 1000;
    }
    pub fn up_til_ms(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        if (self.time_since_boot_us > other.time_since_boot_us) {
            return DiffError.CurrentIsLaterThanInput;
        }
        return (other.time_since_boot_us - self.time_since_boot_us) / 1000;
    }
};

pub const DiffError = error{ CurrentIsEarlierThanInput, CurrentIsLaterThanInput };

pub const LayerActivations = struct {
    layers: [32]bool = [_]bool{false} ** 32,
    top_most_active_layer: LayerIndex = 0,
    const Self = @This();
    pub fn activate(self: *Self, layer_index: LayerIndex) void {
        if (layer_index == 0)
            return;
        self.layers[layer_index] = true;
        if (layer_index > self.top_most_active_layer) {
            self.top_most_active_layer = layer_index;
        }
    }

    pub fn deactivate(self: *Self, layer_index: LayerIndex) void {
        if (layer_index == 0)
            return;
        self.layers[layer_index] = false;
        if (layer_index == self.top_most_active_layer) {
            // now find the next top most active layer
            var counter = self.top_most_active_layer - 1;
            while (self.layers[counter] == false and counter > 0) {
                counter -= 1;
            }
            if (self.top_most_active_layer != counter) {
                self.top_most_active_layer = counter;
            }
        }
    }

    pub fn set_layer_state(self: *Self, layer_index: LayerIndex, state: bool) void {
        switch (state) {
            true => activate(self, layer_index),
            false => deactivate(self, layer_index),
        }
    }

    pub fn is_layer_active(self: *const Self, layer_index: LayerIndex) bool {
        if (layer_index == 0)
            return true;
        return self.layers[layer_index];
    }
    pub fn get_top_most_active_layer(self: *const Self) LayerIndex {
        return self.top_most_active_layer;
    }
};

/// Plugin interface for injecting keymap-specific logic into the processing pipeline.
///
/// zigmkay handles a set of built-in behaviors automatically without requiring a
/// custom handler (see processing.zig for the full list). Only define `on_event`
/// when your keymap needs logic that goes beyond the built-ins — for example,
/// activating a custom layer, chaining multiple keys, or reacting to hold events
/// in a keyboard-specific way.
///
/// A keymap with no custom logic can simply use the zero value:
///   `pub const custom_functions = core.CustomFunctions{};`
pub const CustomFunctions = struct {
    /// Optional callback invoked by the processor on every firmware event.
    /// Receives the event, a pointer to the current layer state, and the output
    /// command queue so that custom actions can enqueue USB output.
    /// Set to null (the default) when no custom logic is needed.
    on_event: ?*const fn (event: ProcessorEvent, layers: *LayerActivations, output_queue: *OutputCommandQueue) void = null,
};
pub const ProcessorEvent = union(enum) {
    Tick,
    OnMatrixChanged: struct { event: MatrixStateChange, layer: LayerIndex, modifiers: Modifiers },
    OnTapEnterBefore: struct { tap: TapDef },
    OnTapEnterAfter: struct { tap: TapDef },
    OnTapExitBefore: struct { tap: TapDef },
    OnTapExitAfter: struct { tap: TapDef },
    OnHoldEnterBefore: struct { hold: HoldDef },
    OnHoldEnterAfter: struct { hold: HoldDef },
    OnHoldExitBefore: struct { hold: HoldDef },
    OnHoldExitAfter: struct { hold: HoldDef },
};
