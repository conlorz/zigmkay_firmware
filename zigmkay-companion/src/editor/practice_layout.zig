const std = @import("std");
const cache = @import("../components/cache.zig");
const Modifiers = @import("layout-model").Modifiers;
pub const Hint = struct { layer: usize, key: usize, mods: Modifiers };
const physical = @import("lk7-physical");
pub const Guidance = struct {
    tap: [128]bool = @splat(false),
    hold: [128]bool = @splat(false),
};
pub fn guidance(labels: *const cache.LabelCache, current_layer: usize, mods: Modifiers, next: ?Hint) Guidance {
    var result: Guidance = .{};
    const needed = next orelse return result;
    result.tap[needed.key] = true;
    if (needed.layer != current_layer) {
        for (0..@min(labels.key_count, 128)) |key| {
            if (labels.lookup(current_layer, key, mods).hold_layer) |layer| {
                if (layer == needed.layer and key != needed.key) {
                    result.hold[key] = true;
                    break;
                }
            }
        }
    }
    // Left/right Shift produce the same character, but the held key should
    // belong to the opposite hand. Prefer finger keys over thumb alternatives.
    var missing = needed.mods.toByte() & ~mods.toByte();
    if (mods.left_shift or mods.right_shift) missing &= ~@as(u8, 0x22);
    for (0..8) |bit| {
        const flag = @as(u8, 1) << @intCast(bit);
        if (missing & flag == 0) continue;
        var best: ?usize = null;
        var best_score: usize = 0;
        for (0..@min(labels.key_count, 128)) |key| {
            if (key == needed.key) continue;
            const entry = labels.lookup(current_layer, key, mods).*;
            const held = if (entry.hold_mods) |held| held.toByte() else if (entry.hid_code) |code| (if (code >= 224 and code <= 231) @as(u8, 1) << @intCast(code - 224) else 0) else 0;
            const accepted = if (flag & 0x22 != 0) @as(u8, 0x22) else flag;
            if (held & accepted == 0) continue;
            var score: usize = 1;
            if (labels.key_count == physical.keys.len) {
                const provider = physical.keys[key];
                const tap = physical.keys[needed.key];
                if (provider.hand != tap.hand and provider.hand != .neutral) score += 4;
                if (provider.group != .thumb) score += 2;
            }
            if (score > best_score) {
                best = key;
                best_score = score;
            }
        }
        if (best) |key| result.hold[key] = true;
    }
    return result;
}
fn matches(entry: cache.CachedKeyContent, cp: u21) bool {
    if (entry.dead or entry.shortcut) return false;
    if (entry.hid_code) |code| {
        if (cp == '\n' and code == 40) return true;
        if (cp == '\t' and code == 43) return true;
        if (cp == ' ' and code == 44) return true;
    }
    const label = entry.label orelse return false;
    var bytes: [4]u8 = undefined;
    const n = std.unicode.utf8Encode(cp, &bytes) catch return false;
    return std.mem.eql(u8, label, bytes[0..n]);
}
/// Find a directly labelled key. Never claim a dead-key sequence or callback
/// produces a character merely because its HID usage looks similar.
pub fn hint(labels: *const cache.LabelCache, current_layer: usize, current_mods: Modifiers, cp: u21) ?Hint {
    return hintActive(labels, current_layer, current_mods, cp, 1 | (@as(u16, 1) << @intCast(current_layer)));
}
pub fn hintActive(labels: *const cache.LabelCache, current_layer: usize, current_mods: Modifiers, cp: u21, active: u16) ?Hint {
    const variants = [_]Modifiers{ current_mods, .{}, .{ .left_shift = true }, .{ .left_alt = true }, .{ .left_shift = true, .left_alt = true } };
    for (0..labels.layer_count) |offset| {
        const layer = (current_layer + offset) % labels.layer_count;
        for (variants) |mods| {
            if (mods.left_ctrl or mods.right_ctrl or mods.left_gui or mods.right_gui) continue;
            for (0..labels.key_count) |key| {
                const mask = if (layer == current_layer) active else 1 | (@as(u16, 1) << @intCast(layer));
                const entry = labels.lookupActive(layer, key, mods, mask).*;
                if (matches(entry, cp)) return .{ .layer = layer, .key = key, .mods = mods };
            }
        }
    }
    return null;
}
pub fn targets(labels: *const cache.LabelCache, displayed_layer: usize, mods: Modifiers, next: ?Hint) [128]bool {
    var result: [128]bool = @splat(false);
    const needed = next orelse return result;
    if (needed.layer == displayed_layer) result[needed.key] = true;
    for (0..@min(labels.key_count, result.len)) |key| {
        const entry = labels.lookupActive(displayed_layer, key, mods, 1 | (@as(u16, 1) << @intCast(displayed_layer))).*;
        if (entry.hold_layer) |held_layer| if (needed.layer != displayed_layer and held_layer == needed.layer) {
            result[key] = true;
        };
        if (entry.hold_mods) |held| if (held.toByte() & needed.mods.toByte() & ~mods.toByte() != 0) {
            result[key] = true;
        };
        if (entry.hid_code) |code| if (code >= 224 and code <= 231 and needed.mods.toByte() & ~mods.toByte() & (@as(u8, 1) << @intCast(code - 224)) != 0) {
            result[key] = true;
        };
    }
    return result;
}
pub const Fixture = struct {
    pub fn keyToText(_: *@This(), input: @import("zkeymap").KeyCodeFire) @import("zkeymap").TextResult {
        var result: @import("zkeymap").TextResult = .{};
        const code = input.tap_keycode;
        if (code >= 4 and code <= 29) {
            result.data[0] = (if (input.tap_modifiers.left_shift or input.tap_modifiers.right_shift) @as(u8, 'A') else 'a') + code - 4;
            result.len = 1;
        } else if (code >= 30 and code <= 39) {
            result.data[0] = (if (input.tap_modifiers.left_shift or input.tap_modifiers.right_shift) "!@#$%^&*()" else "1234567890")[code - 30];
            result.len = 1;
        } else if (code == 44) {
            result.data[0] = ' ';
            result.len = 1;
        } else if (code >= 45 and code <= 56) {
            result.data[0] = (if (input.tap_modifiers.left_shift or input.tap_modifiers.right_shift) "_+{}|~:\"~<>?" else "-=[]\\#;'`,./")[code - 45];
            result.len = 1;
        }
        return result;
    }
};
test "guidance finds shifted keys, other layers, hold access and missing characters" {
    var labels = try cache.LabelCache.init(std.testing.allocator, 2, 3);
    defer labels.deinit();
    labels.entries[(0 * 3 + 0) * 256] = .{ .label = "a", .hid_code = 4 };
    labels.entries[(0 * 3 + 0) * 256 + 2] = .{ .label = "A", .hid_code = 4 };
    labels.entries[(0 * 3 + 1) * 256] = .{ .hold_layer = 1 };
    labels.entries[(1 * 3 + 2) * 256] = .{ .label = "!" };
    const capital = hint(&labels, 0, .{}, 'A').?;
    try std.testing.expect(capital.mods.left_shift);
    const punctuation = hint(&labels, 0, .{}, '!').?;
    try std.testing.expectEqual(@as(usize, 1), punctuation.layer);
    try std.testing.expect(targets(&labels, 0, .{}, punctuation)[1]);
    try std.testing.expect(targets(&labels, 1, .{}, punctuation)[2]);
    try std.testing.expect(hint(&labels, 0, .{}, 'é') == null);
}

test "dead keys and shortcut chords never receive direct character hints" {
    var labels = try cache.LabelCache.init(std.testing.allocator, 1, 2);
    defer labels.deinit();
    labels.entries[0] = .{ .label = "´", .hid_code = 52, .dead = true };
    labels.entries[256] = .{ .label = " ", .hid_code = 44, .shortcut = true };
    try std.testing.expect(hint(&labels, 0, .{}, '´') == null);
    try std.testing.expect(hint(&labels, 0, .{}, ' ') == null);
}

test "modifier-only captions never become literal character hints" {
    const p = @import("keymap-project");
    const actions: []const ?p.Action = &.{
        .{ .hold_only = .{ .hold_modifiers = .{ .left_alt = true } } },
        .{ .hold_only = .{ .hold_modifiers = .{ .left_shift = true } } },
        .{ .hold_only = .{ .hold_modifiers = .{ .left_ctrl = true } } },
        .{ .hold_only = .{ .hold_modifiers = .{ .left_gui = true } } },
    };
    const document: p.Document = .{ .schema_version = 1, .board_id = @splat(0), .profile_id = @splat(0), .physical_layout = "fixture", .name = "Hold fixture", .key_ids = &.{}, .layers = &.{.{ .id = 1, .name = "Base", .actions = actions }} };
    var source: Fixture = .{};
    var labels = try cache.buildProjectCache(std.testing.allocator, &source, document);
    defer labels.deinit();
    for ([_]u21{ '⌥', '⇧', '⌃', '⌘' }, 0..) |symbol, index| {
        try std.testing.expect(labels.lookup(0, index, .{}).caption != null);
        try std.testing.expect(labels.lookup(0, index, .{}).label == null);
        try std.testing.expect(hint(&labels, 0, .{}, symbol) == null);
    }
}

test "practice separates layer holds from taps and prefers opposite hand home row shift" {
    var labels = try cache.LabelCache.init(std.testing.allocator, 4, 34);
    defer labels.deinit();
    labels.entries[13 * 256] = .{ .hold_mods = .{ .left_shift = true } };
    labels.entries[16 * 256] = .{ .hold_mods = .{ .right_shift = true } };
    labels.entries[33 * 256] = .{ .hold_mods = .{ .right_shift = true } };
    labels.entries[31 * 256] = .{ .hold_layer = 3 };
    const capital = guidance(&labels, 0, .{}, .{ .layer = 0, .key = 10, .mods = .{ .left_shift = true } });
    try std.testing.expect(capital.tap[10]);
    try std.testing.expect(capital.hold[16]);
    try std.testing.expect(!capital.hold[13] and !capital.hold[33]);
    const right = guidance(&labels, 0, .{}, .{ .layer = 0, .key = 16, .mods = .{ .left_shift = true } });
    try std.testing.expect(right.hold[13]);
    const symbol = guidance(&labels, 0, .{}, .{ .layer = 3, .key = 24, .mods = .{} });
    try std.testing.expect(symbol.tap[24] and symbol.hold[31]);
    try std.testing.expect(!symbol.tap[31] and !symbol.hold[24]);
    const shifted = guidance(&labels, 0, .{ .right_shift = true }, .{ .layer = 0, .key = 10, .mods = .{ .left_shift = true } });
    try std.testing.expect(!shifted.hold[13] and !shifted.hold[16]);
}
