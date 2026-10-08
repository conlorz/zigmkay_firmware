//! Host keyboard substitutes for physical LK7 positions during draft preview.
const std = @import("std");
const project = @import("keymap-project");
const KeyIndex = @import("layout-model").KeyIndex;

const fingers = [_]u8{ 20, 26, 8, 21, 23, 28, 24, 12, 18, 19, 4, 22, 7, 9, 10, 11, 13, 14, 15, 51, 29, 27, 6, 25, 5, 17, 16, 54, 55, 56 };
const thumb_fallback = [_]u8{ 44, 40, 42, 43 };

fn tapUsage(action: ?project.Action) ?u8 {
    const value = action orelse return null;
    const tap = switch (value) {
        .tap_only => |t| t,
        .tap_hold => |t| t.tap,
        .tap_with_autofire => |t| t.tap,
        else => return null,
    };
    const key = tap.key_press orelse return null;
    return if (key.tap_modifiers.has_any()) null else key.tap_keycode;
}

/// Fingers use QWERTY positions rather than the draft's output letters. Thumb
/// substitutes follow their base-layer taps (including transparent upper layers)
/// so Enter/Tab/Backspace cannot trigger a different thumb's hold action. Reserve
/// explicit taps first, then give duplicate or non-key taps unused substitutes.
pub fn mapping(document: project.Document) [34]u8 {
    var result: [34]u8 = @splat(0);
    @memcpy(result[0..30], &fingers);
    var used: [256]bool = @splat(false);
    for (fingers) |code| used[code] = true;
    for (30..34) |index| {
        const code = tapUsage(document.layers[0].actions[index]) orelse continue;
        // Only host keys reserved for thumb simulation can replace a thumb.
        if (std.mem.indexOfScalar(u8, &thumb_fallback, code) == null or used[code]) continue;
        result[index] = code;
        used[code] = true;
    }
    for (30..34) |index| {
        if (result[index] != 0) continue;
        for (thumb_fallback) |code| {
            if (used[code]) continue;
            result[index] = code;
            used[code] = true;
            break;
        }
    }
    return result;
}

pub fn keyIndex(document: project.Document, scancode: u32) ?KeyIndex {
    const mapped = mapping(document);
    for (mapped, 0..) |code, index| if (code == scancode) return @intCast(index);
    return null;
}

test "Mac thumb substitutes follow the same actions as Editor keycaps" {
    var loaded = try project.profiles.create(std.testing.allocator, .eurmac);
    defer loaded.deinit();
    const document = loaded.snapshot.document;
    try std.testing.expectEqual(@as(?KeyIndex, 30), keyIndex(document, 44));
    try std.testing.expectEqual(@as(?KeyIndex, 31), keyIndex(document, 43));
    try std.testing.expectEqual(@as(?KeyIndex, 32), keyIndex(document, 40));
    try std.testing.expectEqual(@as(?KeyIndex, 33), keyIndex(document, 42));
    try std.testing.expectEqual(@as(?KeyIndex, null), keyIndex(document, 82));
    // Every position remains independently releasable, even with duplicate taps.
    for ([_]project.profiles.Profile{ .qwerty, .eurkey, .danish, .eurmac }) |profile| {
        var candidate = try project.profiles.create(std.testing.allocator, profile);
        defer candidate.deinit();
        const mapped = mapping(candidate.snapshot.document);
        for (mapped, 0..) |code, index| {
            try std.testing.expect(code != 0);
            try std.testing.expect(std.mem.indexOfScalar(u8, mapped[0..index], code) == null);
            try std.testing.expectEqual(@as(?KeyIndex, @intCast(index)), keyIndex(candidate.snapshot.document, code));
        }
    }
}
