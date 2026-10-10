const std = @import("std");
const testing = std.testing;
const dvui = @import("dvui");
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");
const icons = @import("icons");
const project = @import("keymap-project");
const editor_labels = @import("../editor/labels.zig");

const log = std.log.scoped(.companion);

const core = keymap.core;
const Modifiers = core.Modifiers;

/// Cached key content for UI rendering.
///
/// This struct holds all the visual information needed to display a key:
/// - label: UTF-8 text label (e.g., "A", "DEL", "Esc")
/// - icon: SVG icon bytes for keys with icons
/// - icon_name: Name identifier for the icon
/// - hold_layer: Layer index for layer-hold keys
/// - hold_mods: Modifier state for modifier-hold keys
/// - hid_code: HID keycode from firmware
///
/// Labels are allocated from a LabelCache arena and remain valid
/// for the lifetime of the cache.
pub const CachedKeyContent = struct {
    /// Host-aware action caption shared with Editor. `label` remains native
    /// translated output for practice matching, independently of this caption.
    caption: ?[]const u8 = null,
    label: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    icon_name: []const u8 = "",
    hold_layer: ?core.LayerIndex = null,
    hold_mods: ?core.Modifiers = null,
    hid_code: ?u8 = null,
    dead: bool = false,
    shortcut: bool = false,

    pub fn withIcon(self: CachedKeyContent, icon: []const u8, name: []const u8) CachedKeyContent {
        var c = self;
        c.icon = icon;
        c.icon_name = name;
        return c;
    }

    pub fn withLabel(self: CachedKeyContent, label: []const u8) CachedKeyContent {
        var c = self;
        c.label = label;
        return c;
    }
};

/// Pre-computed label lookup cache for all key states.
///
/// LabelCache stores the rendered content for every possible key+layer+modifier
/// combination in a flat array for O(1) lookup during UI rendering.
///
/// # Indexing
/// Entry index = (layer * key_count + key_index) * 256 + mods_byte
/// - layer: 0 to layer_count-1
/// - key_index: 0 to key_count-1
/// - mods_byte: 0 to 255 (8-bit modifier mask from Modifiers.toByte())
///
/// # Memory Management
/// The cache owns an arena allocator that stores all duplicated label strings.
/// Call `deinit()` to properly clean up when the cache is no longer needed.
pub const LabelCache = struct {
    entries: []CachedKeyContent,
    arena: std.heap.ArenaAllocator,
    layer_count: usize,
    key_count: usize,

    pub fn init(allocator: std.mem.Allocator, layer_count: usize, key_count: usize) !LabelCache {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const entries = try arena.allocator().alloc(CachedKeyContent, layer_count * key_count * 256);
        for (entries) |*entry| {
            entry.* = .{};
        }
        return LabelCache{
            .entries = entries,
            .arena = arena,
            .layer_count = layer_count,
            .key_count = key_count,
        };
    }

    pub fn lookup(self: *const LabelCache, layer: usize, key_index: usize, mods: Modifiers) *const CachedKeyContent {
        const idx = (layer * self.key_count + key_index) * 256 + @as(usize, mods.toByte());
        return &self.entries[idx];
    }
    /// Resolve transparent keys against the layers actually enabled by the
    /// processor, rather than treating every lower numbered layer as active.
    pub fn lookupActive(self: *const LabelCache, layer: usize, key_index: usize, mods: Modifiers, active: u16) *const CachedKeyContent {
        var selected = @min(layer, self.layer_count - 1);
        while (true) {
            const entry = self.lookup(selected, key_index, mods);
            const inherited = if (entry.label) |label| std.mem.eql(u8, label, "---") else false;
            if (selected == 0 or (active & (@as(u16, 1) << @intCast(selected)) != 0 and !inherited)) return entry;
            selected -= 1;
        }
    }

    pub fn deinit(self: *LabelCache) void {
        self.arena.deinit();
    }
};

fn scanCodeFromInt(code: u8) !zkeymap.ScanCode {
    return std.enums.fromInt(zkeymap.ScanCode, code) orelse error.InvalidScanCode;
}

/// Computes the visual content for a key based on its definition and modifier state.
///
/// This function handles:
/// - Special keys (media keys, mouse actions, custom commands)
/// - Layer-hold and modifier-hold indicators
/// - Scancode-based icon mapping (backspace, enter, arrows, etc.)
/// - Layout-dependent text via zkeymap.keyToText()
///
/// The caller provides a `label_buf` buffer that computeKeyContent may use
/// for temporary string formatting. The returned CachedKeyContent.label
/// may point into this buffer or to arena-allocated memory.
pub fn textKey(key: core.KeyCodeFire, physical_mods: Modifiers) zkeymap.KeyCodeFire {
    const mods = key.tap_modifiers.add(physical_mods);
    return .{ .tap_keycode = key.tap_keycode, .tap_modifiers = mods, .dead = key.dead };
}

pub fn computeKeyContent(km: anytype, maybe_def: ?core.KeyDef, physical_mods: Modifiers, label_buf: *[64]u8) CachedKeyContent {
    const def = maybe_def orelse return .{ .label = "---" };
    var maybe_key_code_fire: ?core.KeyCodeFire = null;
    var content = CachedKeyContent{};

    switch (def) {
        .tap_only => |t| {
            if (t.custom == keymap.COM_TOG) return content.withIcon(icons.tvg.lucide.@"circuit-board", "companion");
            if (t.custom == keymap.COM_OFF) return content.withIcon(icons.tvg.lucide.power, "shutdown");
            if (t.media_key) |media| {
                switch (media) {
                    .VolumeUp => return content.withIcon(icons.tvg.lucide.@"volume-2", "vol_up"),
                    .VolumeDown => return content.withIcon(icons.tvg.lucide.@"volume-1", "vol_down"),
                    .VolumeMute => return content.withIcon(icons.tvg.lucide.@"volume-x", "mute"),
                    .NextTrack => return content.withIcon(icons.tvg.lucide.@"skip-forward", "next"),
                    .PreviousTrack => return content.withIcon(icons.tvg.lucide.@"skip-back", "prev"),
                }
            }
            if (t.mouse_action) |mouse| {
                switch (mouse) {
                    .LeftButton => return content.withIcon(icons.tvg.lucide.mouse, "m_left"),
                    .RightButton => return content.withIcon(icons.tvg.lucide.mouse, "m_right"),
                    .MiddleButton => return content.withIcon(icons.tvg.lucide.mouse, "m_mid"),
                    .WheelUp => return content.withIcon(icons.tvg.lucide.@"chevron-up", "w_up"),
                    .WheelDown => return content.withIcon(icons.tvg.lucide.@"chevron-down", "w_down"),
                    .WheelLeft => return content.withIcon(icons.tvg.lucide.@"chevron-left", "w_left"),
                    .WheelRight => return content.withIcon(icons.tvg.lucide.@"chevron-right", "w_right"),
                    else => content.label = "MS",
                }
            }
            if (t.key_press) |kp| {
                maybe_key_code_fire = kp;
            }
        },
        .tap_hold => |th| {
            if (th.tap.custom == keymap.COM_TOG) {
                content = content.withIcon(icons.tvg.lucide.@"circuit-board", "companion");
            } else if (th.tap.custom == keymap.COM_OFF) {
                content = content.withIcon(icons.tvg.lucide.power, "shutdown");
            } else if (th.tap.key_press) |kp| {
                maybe_key_code_fire = kp;
            }
            content.hold_layer = th.hold.hold_layer;
            content.hold_mods = if (th.hold.hold_modifiers.has_any()) th.hold.hold_modifiers else null;
        },
        .tap_with_autofire => |af| if (af.tap.key_press) |kp| {
            maybe_key_code_fire = kp;
        },
        .hold_only => |h| {
            content.hold_layer = h.hold_layer;
            content.hold_mods = if (h.hold_modifiers.has_any()) h.hold_modifiers else null;
            // Holds change processor state without producing text. Their visual
            // symbols belong to caption, never to the translated output label.
        },
        else => {},
    }
    const key_code_fire = maybe_key_code_fire orelse return content;

    content.hid_code = key_code_fire.tap_keycode;
    content.dead = key_code_fire.dead;
    const tap_mods = key_code_fire.tap_modifiers;
    content.shortcut = tap_mods.left_ctrl or tap_mods.right_ctrl or tap_mods.left_gui or tap_mods.right_gui;

    const scancode = scanCodeFromInt(key_code_fire.tap_keycode) catch {
        content.label = "???";
        return content;
    };

    switch (scancode) {
        .KC_BACKSPACE => return content.withIcon(icons.tvg.lucide.delete, "backspace"),
        .KC_ENTER => return content.withIcon(icons.tvg.lucide.@"corner-down-left", "enter"),
        .KC_LEFT => return content.withIcon(icons.tvg.lucide.@"arrow-left", "left"),
        .KC_RIGHT => return content.withIcon(icons.tvg.lucide.@"arrow-right", "right"),
        .KC_UP => return content.withIcon(icons.tvg.lucide.@"arrow-up", "up"),
        .KC_DOWN => return content.withIcon(icons.tvg.lucide.@"arrow-down", "down"),
        .KC_TAB => return content.withIcon(icons.tvg.lucide.@"arrow-right-left", "tab"),
        .KC_SPACE => return content.withIcon(icons.tvg.lucide.space, "space").withLabel(" "),
        .KC_PAGE_DOWN => return content.withIcon(icons.tvg.lucide.@"arrow-down-to-line", "page_down"),
        .KC_PAGE_UP => return content.withIcon(icons.tvg.lucide.@"arrow-up-to-line", "page_up"),
        .KC_HOME => return content.withIcon(icons.tvg.lucide.@"arrow-left-to-line", "home"),
        .KC_END => return content.withIcon(icons.tvg.lucide.@"arrow-right-to-line", "end"),
        else => {},
    }

    const result = km.keyToText(textKey(key_code_fire, physical_mods));

    if (result.isLabel()) {
        const lbl = result.getLabel();
        if (lbl.len > 0 and lbl.len < 64) {
            @memcpy(label_buf[0..lbl.len], lbl);
            label_buf[lbl.len] = 0;
            content.label = label_buf[0..lbl.len];
        }
        return content;
    } else if (result.len > 0) {
        const slice = result.slice();
        if (slice.len == 1 and slice[0] < 32) {
            // Ignore unprintable control characters
        } else {
            if (slice.len < 64) {
                @memcpy(label_buf[0..slice.len], slice);
                label_buf[slice.len] = 0;
                content.label = label_buf[0..slice.len];
            }
            return content;
        }
    }

    if (content.label == null and content.icon == null) {
        content.label = switch (def) {
            .none => "",
            else => "?",
        };
    }

    return content;
}

/// Builds a complete label cache for all keys, layers, and modifier combinations.
///
/// This function pre-computes the visual content for every possible key state
/// and stores it in a flat array for O(1) runtime lookup. The cache includes:
/// - All layers in the keymap
/// - All keys per layer
/// - All 256 possible modifier byte values
///
/// # Arguments
/// - `allocator`: Memory allocator for the cache and string storage
/// - `km`: Initialized KeyMap for layout-dependent text rendering
///
/// # Returns
/// A fully populated LabelCache. Call `deinit()` when done.
///
/// # Memory Usage
/// Approximately: layer_count * key_count * 256 * sizeof(CachedKeyContent) bytes
/// plus arena allocations for label strings.
pub fn buildLabelCache(allocator: std.mem.Allocator, km: anytype) !LabelCache {
    const layer_count = keymap.keymap.len;
    const key_count = keymap.key_count;
    var cache = try LabelCache.init(allocator, layer_count, key_count);
    errdefer cache.deinit();
    var layers: [keymap.keymap.len]project.Layer = undefined;
    for (&layers, 0..) |*layer, i| layer.* = .{ .id = @intCast(i + 1), .name = "", .actions = &.{} };
    const document: project.Document = .{ .schema_version = 1, .board_id = @splat(0), .profile_id = @splat(0), .physical_layout = "", .name = "", .key_ids = &.{}, .layers = &layers };

    for (0..layer_count) |layer| {
        for (0..key_count) |key_idx| {
            const def = keymap.keymap[layer][key_idx];
            const action = if (def) |value| try project.adapter.liftAction(&layers, value) else null;
            var caption_buffer: [256]u8 = undefined;
            for (0..256) |mods_byte| {
                const mods_u8 = @as(u8, @intCast(mods_byte));
                const mods: Modifiers = @bitCast(mods_u8);
                const idx = (layer * key_count + key_idx) * 256 + mods_byte;
                var label_buf: [64]u8 = undefined;
                @memset(&label_buf, 0);
                var entry = computeKeyContent(km, def, mods, &label_buf);
                entry.caption = try cache.arena.allocator().dupe(u8, editor_labels.keycapWithLayout(km, action, document, @bitCast(mods_u8), &caption_buffer));
                if (entry.label) |label| {
                    entry.label = try cache.arena.allocator().dupe(u8, label);
                }
                cache.entries[idx] = entry;
            }
        }
    }

    return cache;
}

/// Display exactly the frozen profile used for the explicit firmware transfer.
pub fn buildProjectCache(allocator: std.mem.Allocator, km: anytype, document: @import("keymap-project").Document) !LabelCache {
    var result = try LabelCache.init(allocator, document.layers.len, document.layers[0].actions.len);
    errdefer result.deinit();
    for (document.layers, 0..) |layer, layer_index| {
        for (layer.actions, 0..) |action, key_index| {
            const def = if (action) |value| try project.lowerAction(document, value) else null;
            var caption_buffer: [256]u8 = undefined;
            for (0..256) |mods| {
                var buffer: [64]u8 = @splat(0);
                var entry = computeKeyContent(km, def, @bitCast(@as(u8, @intCast(mods))), &buffer);
                entry.caption = try result.arena.allocator().dupe(u8, editor_labels.keycapWithLayout(km, action, document, @bitCast(@as(u8, @intCast(mods))), &caption_buffer));
                if (entry.label) |text| entry.label = try result.arena.allocator().dupe(u8, text);
                result.entries[(layer_index * result.key_count + key_index) * 256 + mods] = entry;
            }
        }
    }
    return result;
}

test "computeKeyContent: KC_A returns lowercase a label" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("a", label);
    }
}

test "computeKeyContent: KC_A with shift returns uppercase A label" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{ .left_shift = true }, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("A", label);
    }
}

test "computeKeyContent: KC_DELETE returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_DELETE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("DEL", label);
    }
}

test "computeKeyContent: KC_PRINT_SCREEN returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_PRINT_SCREEN),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("PSCR", label);
    }
}

test "computeKeyContent: KC_ESCAPE returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_ESCAPE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("ESC", label);
    }
}

test "computeKeyContent: KC_SPACE returns space character" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_SPACE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings(" ", label);
    }
}

test "LabelCache: buildLabelCache creates entries for all layers and keys" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    var cache = try buildLabelCache(testing.allocator, &km);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, keymap.keymap.len), cache.layer_count);
    try testing.expectEqual(@as(usize, keymap.key_count), cache.key_count);

    const total_entries = cache.layer_count * cache.key_count * 256;
    try testing.expectEqual(@as(usize, total_entries), cache.entries.len);
}

test "LabelCache: lookup returns valid pointer for KC_A" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    var cache = try buildLabelCache(testing.allocator, &km);
    defer cache.deinit();

    const content = cache.lookup(0, 0, .{});

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expect(label.len > 0);
    }
}

const FixtureLabels = struct {
    alternate: bool = false,
    pub fn keyToText(self: *FixtureLabels, input: zkeymap.KeyCodeFire) zkeymap.TextResult {
        if (!zkeymap.isLayoutDependent(input.tap_keycode)) {
            var r = zkeymap.TextResult{};
            r.data[0..2].* = @bitCast(@as(u16, input.tap_keycode));
            return r;
        }
        const mods = input.tap_modifiers;
        if (input.dead) return .{ .data = .{ '^', 0, 0, 0 }, .len = 1 };
        if (mods.left_alt or mods.right_alt) return .{ .data = .{ '@', 0, 0, 0 }, .len = 1 };
        // Command participates in lookup but does not imply a physical press.
        const upper = mods.left_shift or mods.right_shift;
        return .{ .data = .{ if (self.alternate) 'z' else if (upper) 'A' else 'a', 0, 0, 0 }, .len = 1 };
    }
};
test "label fixtures separate fixed Shift Option Command dead keys and source refresh" {
    var fixture = FixtureLabels{};
    var buffer: [64]u8 = undefined;
    const base = core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A) } } };
    try testing.expectEqualStrings("a", computeKeyContent(&fixture, base, .{}, &buffer).label.?);
    try testing.expectEqualStrings("A", computeKeyContent(&fixture, base, .{ .left_shift = true }, &buffer).label.?);
    try testing.expectEqualStrings("@", computeKeyContent(&fixture, base, .{ .left_alt = true }, &buffer).label.?);
    try testing.expectEqualStrings("a", computeKeyContent(&fixture, base, .{ .left_gui = true }, &buffer).label.?);
    const dead = core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A), .dead = true } } };
    try testing.expectEqualStrings("^", computeKeyContent(&fixture, dead, .{}, &buffer).label.?);
    try testing.expectEqualStrings("a", computeKeyContent(&fixture, base, .{}, &buffer).label.?);
    fixture.alternate = true;
    try testing.expectEqualStrings("z", computeKeyContent(&fixture, base, .{}, &buffer).label.?);
    const fixed = core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_F1) } } };
    try testing.expectEqualStrings("F1", computeKeyContent(&fixture, fixed, .{ .left_alt = true, .left_shift = true }, &buffer).label.?);
}

test "fixture label cache rebuild replaces source while keeping physical metadata" {
    var source = FixtureLabels{};
    var first = try buildLabelCache(testing.allocator, &source);
    defer first.deinit();
    source.alternate = true;
    var second = try buildLabelCache(testing.allocator, &source);
    defer second.deinit();
    var changed: usize = 0;
    var captions_changed: usize = 0;
    for (first.entries, second.entries) |a, b| {
        try testing.expectEqual(a.hid_code, b.hid_code);
        try testing.expectEqual(a.hold_layer, b.hold_layer);
        if (a.label != null and b.label != null and !std.mem.eql(u8, a.label.?, b.label.?)) changed += 1;
        if (!std.mem.eql(u8, a.caption.?, b.caption.?)) captions_changed += 1;
    }
    try testing.expect(changed > 0);
    try testing.expect(captions_changed > 0);
}

test "practice labels resolve transparent keys only through enabled layers" {
    var labels = try LabelCache.init(testing.allocator, 3, 1);
    defer labels.deinit();
    labels.entries[0] = .{ .label = "base" };
    labels.entries[256] = .{ .label = "navigation" };
    labels.entries[512] = .{ .label = "---" };
    try testing.expectEqualStrings("base", labels.lookupActive(2, 0, .{}, 0b101).label.?);
    try testing.expectEqualStrings("navigation", labels.lookupActive(2, 0, .{}, 0b111).label.?);
    labels.entries[512] = .{ .label = "" };
    try testing.expectEqualStrings("", labels.lookupActive(2, 0, .{}, 0b111).label.?);
}

test "companion captions share Editor thumb holds and preserve translated output" {
    var source = FixtureLabels{};
    const actions: []const ?project.Action = &.{
        .{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 44 } }, .hold = .{ .custom = 7 }, .tapping_term = .{ .ms = 200 } } },
        .{ .hold_only = .{ .hold_modifiers = .{ .left_alt = true } } },
        .{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } },
        .{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 40 } }, .hold = .{ .layer_id = 1 }, .tapping_term = .{ .ms = 200 } } },
    };
    const document: project.Document = .{ .schema_version = 1, .board_id = @splat(0), .profile_id = @splat(0), .physical_layout = "fixture", .name = "Fixture", .key_ids = &.{}, .layers = &.{.{ .id = 1, .name = "Base", .actions = actions }}, .callbacks = &.{.{ .kind = .registered, .binding = "fixture", .ids = &.{7}, .sources = &.{} }} };
    var cache = try buildProjectCache(testing.allocator, &source, document);
    defer cache.deinit();
    var buffer: [256]u8 = undefined;
    for (actions, 0..) |action, i| {
        try testing.expectEqualStrings(editor_labels.keycap(action, document, &buffer), cache.lookup(0, i, .{}).caption.?);
        try testing.expectEqualStrings(cache.lookup(0, i, .{}).caption.?, cache.lookup(0, i, .{ .left_shift = true }).caption.?);
    }
    try testing.expectEqualStrings("␣\nHold Callback 7", cache.lookup(0, 0, .{}).caption.?);
    try testing.expectEqualStrings("↩\nHold L1", cache.lookup(0, 3, .{}).caption.?);
    try testing.expectEqualStrings(if (editor_labels.runningHost() == .macos) "Hold\n⌥" else "Hold\nAlt", cache.lookup(0, 1, .{}).caption.?);
    try testing.expectEqualStrings("A", cache.lookup(0, 2, .{}).caption.?);
    try testing.expectEqualStrings("a", cache.lookup(0, 2, .{}).label.?);
    try testing.expectEqualStrings("@", cache.lookup(0, 2, .{ .left_alt = true }).label.?);
    try testing.expectEqualStrings("@", cache.lookup(0, 2, .{ .right_alt = true }).caption.?);
    try testing.expectEqualStrings("⌥", editor_labels.keycapModifiers(.macos, 4, &buffer));
}

test "companion cache displays shifted symbols and physical modifiers in every tap variant" {
    var source: @import("../editor/practice_layout.zig").Fixture = .{};
    const tap: project.Tap = .{ .key_press = .{ .tap_keycode = 38, .tap_modifiers = .{ .right_shift = true } } };
    const actions: []const ?project.Action = &.{
        .{ .tap_only = tap },
        .{ .tap_hold = .{ .tap = tap, .hold = .{ .layer_id = 1 }, .tapping_term = .{ .ms = 200 } } },
        .{ .tap_with_autofire = .{ .tap = tap, .initial_delay = .{ .ms = 200 }, .repeat_interval = .{ .ms = 50 } } },
        .{ .tap_only = .{ .key_press = .{ .tap_keycode = 39 } } },
    };
    const document: project.Document = .{ .schema_version = 1, .board_id = @splat(0), .profile_id = @splat(0), .physical_layout = "fixture", .name = "Symbols", .key_ids = &.{}, .layers = &.{.{ .id = 1, .name = "Base", .actions = actions }} };
    var cache = try buildProjectCache(testing.allocator, &source, document);
    defer cache.deinit();
    try testing.expectEqualStrings("(", cache.lookup(0, 0, .{}).caption.?);
    try testing.expectEqualStrings("(\nHold L1", cache.lookup(0, 1, .{}).caption.?);
    try testing.expectEqualStrings("(", cache.lookup(0, 2, .{}).caption.?);
    try testing.expectEqualStrings("0", cache.lookup(0, 3, .{}).caption.?);
    try testing.expectEqualStrings(")", cache.lookup(0, 3, .{ .left_shift = true }).caption.?);
    try testing.expectEqualStrings(")", cache.lookup(0, 3, .{ .right_shift = true }).caption.?);
    try testing.expectEqualStrings("(", cache.lookup(0, 0, .{}).label.?);
}
