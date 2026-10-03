pub const special_keycode_BOOT: u8 = 0xFC; // Special keycode that signals puts the keyboard into bootloader mode.
pub const special_keycode_PRINT_STATS: u8 = 0xFD; // Special keycode that prints stats into any text editor.
pub const special_keycode_COMPANION: u8 = 0xFE; // Special keycode that signals the companion app to toggle the overlay.
pub const special_keycode_SHUTDOWN_COMPANION: u8 = 0xFF; // Special keycode that signals the companion app to shut down entirely.

/// Reserved TapDef.custom ID for SIG(): toggles companion app log visibility.
/// Mirrors the special_keycode_* naming convention. Do not use in user keymaps.
pub const CUSTOM_ID_COMPANION_LOG_TOGGLE: u8 = 0xFD;
/// Reserved TapDef.custom ID for SIG(): sends a companion app shutdown command.
/// Mirrors the special_keycode_* naming convention. Do not use in user keymaps.
pub const CUSTOM_ID_COMPANION_SHUTDOWN: u8 = 0xFE;
/// Reserved TapDef.custom ID for SIG(): signals the companion overlay to toggle
/// (press=1 on key enter, release=0 on key exit). Mirrors the special_keycode_*
/// naming convention. Do not use in user keymaps.
///
/// User-defined custom IDs may use any value from 1 to 252 (0x01..0xFC).
/// Values 0xFD, 0xFE, and 0xFF are reserved by zigmkay for built-in companion
/// signals and must not be used for keymap-specific logic.
pub const CUSTOM_ID_COMPANION_TOGGLE: u8 = 0xFF;
pub const KC_BOOT = KeyCodeFire{ .tap_keycode = special_keycode_BOOT };
pub const KC_PRINT_STATS = KeyCodeFire{ .tap_keycode = special_keycode_PRINT_STATS };
pub const KC_COMPANION = KeyCodeFire{ .tap_keycode = special_keycode_COMPANION };
pub const KC_SHUTDOWN_COMPANION = KeyCodeFire{ .tap_keycode = special_keycode_SHUTDOWN_COMPANION };

pub const Modifiers = packed struct {
    left_ctrl: bool = false,
    left_shift: bool = false,
    left_alt: bool = false,
    left_gui: bool = false,
    right_ctrl: bool = false,
    right_shift: bool = false,
    right_alt: bool = false,
    right_gui: bool = false,
    pub fn has_any(self: *const Modifiers) bool {
        return self.left_gui or self.left_alt or self.left_shift or self.left_ctrl or self.right_gui or self.right_alt or self.right_shift or self.right_ctrl;
    }

    pub fn add(self: *const Modifiers, other: Modifiers) Modifiers {
        const self_bytes = self.toByte();
        const other_bytes = other.toByte();
        return Modifiers.fromByte(self_bytes | other_bytes);
    }

    pub fn remove(self: *const Modifiers, other: Modifiers) Modifiers {
        const self_bytes = self.toByte();
        const other_bytes = other.toByte();
        return Modifiers.fromByte(self_bytes & ~other_bytes);
    }
    pub fn toByte(self: Modifiers) u8 {
        return @bitCast(self);
    }
    pub fn fromByte(byte_val: u8) Modifiers {
        return @bitCast(byte_val);
    }
};

pub const KeymapDimensions = struct {
    key_count: KeyIndex,
    layer_count: LayerIndex,
};

/// Defines an action representing mouse movement, wheel scrolling, or a mouse button click.
pub const MouseAction = enum(u8) {
    LeftButton,
    RightButton,
    MiddleButton,
    Button4,
    Button5,
    WheelUp,
    WheelDown,
    WheelLeft,
    WheelRight,
};
pub const TapDef = struct {
    key_press: ?KeyCodeFire = null,
    one_shot: ?HoldDef = null,
    custom: ?u8 = null,
    media_key: ?MediaCode = null, // Optional media keycode for consumer control (e.g., volume, play/pause).
    mouse_action: ?MouseAction = null, // Optional mouse action to be executed on tap.
};

// this list comes from here: https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
pub const MediaCode = enum(u16) {
    NextTrack = 0x00b5,
    PreviousTrack = 0x00b6,
    VolumeMute = 0x00e8,
    VolumeUp = 0x00e9,
    VolumeDown = 0x00ea,
};

pub const HoldDef = struct {
    hold_modifiers: Modifiers = .{},
    hold_layer: ?LayerIndex = null,
    custom: ?u8 = null,
};

pub const TapHoldDef = struct {
    tap: TapDef,
    hold: HoldDef,
    tapping_term: TimeSpan,
    retro_tapping: bool = false,
};

pub const KeyDef = union(enum) {
    none,
    tap_only: TapDef,
    hold_only: HoldDef,
    tap_hold: TapHoldDef,
    tap_with_autofire: AutoFireDef,
};

/// Processing side used by permissive-hold rules; X has no left/right affinity.
pub const Side = enum { L, R, X };
pub const Combo2Def = struct {
    key_indexes: [2]KeyIndex,
    timeout: TimeSpan,
    layer: LayerIndex,
    key_def: KeyDef,
};

pub const AutoFireDef = struct {
    tap: TapDef,
    initial_delay: TimeSpan,
    repeat_interval: TimeSpan,
};

pub const TimeSpan = struct {
    ms: u16 = 0,
};
pub const KeyIndex = u7;
pub const LayerIndex = u4;

pub const EncoderAction = struct {
    tap: TapDef,
};
pub const KeyCodeFire = struct {
    tap_keycode: u8 = 0,
    tap_modifiers: Modifiers = .{},
    dead: bool = false,
};
pub const MEDIA_VOLUME_UP: u16 = 0xE9;
pub const MEDIA_VOLUME_DOWN: u16 = 0xEA;
pub const MEDIA_MUTE: u16 = 0xE2;
pub const MEDIA_PLAY_PAUSE: u16 = 0xCD;
pub const MEDIA_NEXT_TRACK: u16 = 0xB5;
pub const MEDIA_PREV_TRACK: u16 = 0xB6;
