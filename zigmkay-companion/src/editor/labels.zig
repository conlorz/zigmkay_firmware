const p = @import("keymap-project");
const std = @import("std");
pub fn usage(code: u8, buffer: []u8) []const u8 {
    if (code >= 4 and code <= 29) {
        buffer[0] = 'A' + code - 4;
        return buffer[0..1];
    }
    if (code >= 30 and code <= 38) {
        buffer[0] = '1' + code - 30;
        return buffer[0..1];
    }
    return switch (code) {
        0 => "—",
        39 => "0",
        40 => "Return",
        41 => "Esc",
        42 => "Backspace",
        43 => "Tab",
        44 => "Space",
        45 => "-",
        46 => "=",
        47 => "[",
        48 => "]",
        49 => "\\",
        51 => ";",
        52 => "'",
        53 => "`",
        54 => ",",
        55 => ".",
        56 => "/",
        57 => "Caps",
        70 => "Print Screen",
        71 => "Scroll Lock",
        72 => "Pause",
        73 => "Insert",
        74 => "Home",
        75 => "Page Up",
        76 => "Delete",
        77 => "End",
        78 => "Page Down",
        79 => "Right",
        80 => "Left",
        81 => "Down",
        82 => "Up",
        224 => "L Ctrl",
        225 => "L Shift",
        226 => "L Alt",
        227 => "L GUI",
        228 => "R Ctrl",
        229 => "R Shift",
        230 => "R Alt",
        231 => "R GUI",
        252 => "BOOT",
        253 => "Print statistics",
        254 => "Show / hide companion",
        255 => "Quit companion",
        else => knownUsage(code, buffer),
    };
}
fn knownUsage(code: u8, buffer: []u8) []const u8 {
    inline for (@typeInfo(@import("zkeycodes").layouts.keycodes.kc.basic).@"enum".fields) |field| {
        if (field.value == code) {
            const name = field.name[3..];
            const len = @min(name.len, buffer.len);
            for (name[0..len], 0..) |char, i| buffer[i] = if (char == '_') ' ' else char;
            return buffer[0..len];
        }
    }
    return std.fmt.bufPrint(buffer, "HID {d}", .{code}) catch "?";
}
pub fn tap(value: p.Tap, buffer: []u8) []const u8 {
    if (value.key_press) |key| {
        if (key.tap_modifiers.toByte() == 0) return usage(key.tap_keycode, buffer);
        var key_buffer: [64]u8 = undefined;
        var mod_buffer: [96]u8 = undefined;
        return std.fmt.bufPrint(buffer, "{s}+{s}", .{ modifierNames(key.tap_modifiers.toByte(), &mod_buffer), usage(key.tap_keycode, &key_buffer) }) catch "Chord";
    }
    if (value.media_key) |media| return @tagName(media);
    if (value.mouse_action) |mouse| return @tagName(mouse);
    if (value.custom) |custom| return signal(custom, buffer);
    if (value.one_shot) |one| return if (one.layer_id) |id| std.fmt.bufPrint(buffer, "One-shot L{d}", .{id}) catch "?" else "One-shot mods";
    return "No tap";
}
pub fn signal(id: u8, buffer: []u8) []const u8 {
    return switch (id) {
        253 => "Toggle companion logging",
        254 => "Quit companion",
        255 => "Show / hide companion",
        else => std.fmt.bufPrint(buffer, "Custom {d}", .{id}) catch "Custom",
    };
}
pub fn modifierNames(bits: u8, buffer: []u8) []const u8 {
    var used: usize = 0;
    for ([_][]const u8{ "L Ctrl", "L Shift", "L Alt", "L GUI", "R Ctrl", "R Shift", "R Alt", "R GUI" }, 0..) |name, i| {
        if (bits & (@as(u8, 1) << @intCast(i)) == 0) continue;
        const part = std.fmt.bufPrint(buffer[used..], "{s}{s}", .{ if (used == 0) "" else "+", name }) catch return "Modifiers";
        used += part.len;
    }
    return buffer[0..used];
}
pub fn keycap(value: ?p.Action, doc: p.Document, buffer: []u8) []const u8 {
    const a = value orelse return "Inherited";
    var tap_buffer: [128]u8 = undefined;
    var hold_buffer: [128]u8 = undefined;
    return switch (a) {
        .tap_only => |t| if (t.custom) |id| switch (id) {
            253 => "Companion\nToggle log",
            254 => "Companion\nQuit",
            255 => "Companion\nShow / hide",
            else => tap(t, buffer),
        } else tap(t, buffer),
        .tap_hold => |th| std.fmt.bufPrint(buffer, "{s}\nHold {s}", .{ tap(th.tap, &tap_buffer), hold(th.hold, doc, &hold_buffer) }) catch "Tap / hold",
        .hold_only => |h| std.fmt.bufPrint(buffer, "Hold\n{s}", .{hold(h, doc, &hold_buffer)}) catch "Hold",
        else => action(value, buffer),
    };
}
pub fn hold(value: p.Hold, doc: p.Document, buffer: []u8) []const u8 {
    if (value.layer_id) |id| for (doc.layers) |layer| if (layer.id == id) {
        return std.fmt.bufPrint(buffer, "L{d}\n{s}", .{ id, layer.name }) catch "Layer";
    };
    if (value.custom) |id| return std.fmt.bufPrint(buffer, "Custom hold {d}", .{id}) catch "Custom";
    return switch (value.hold_modifiers.toByte()) {
        0 => "No hold fields",
        else => modifierNames(value.hold_modifiers.toByte(), buffer),
    };
}
pub fn action(value: ?p.Action, buffer: []u8) []const u8 {
    const a = value orelse return "Inherited";
    return switch (a) {
        .none => "None",
        .tap_only => |t| tap(t, buffer),
        .tap_hold => |t| tap(t.tap, buffer),
        .tap_with_autofire => |t| tap(t.tap, buffer),
        .hold_only => |h| if (h.layer_id) |id| std.fmt.bufPrint(buffer, "Layer {d}", .{id}) catch "?" else if (h.custom) |id| std.fmt.bufPrint(buffer, "Custom {d}", .{id}) catch "?" else "Modifiers",
    };
}
pub const HostKey = struct { code: u8, name: []const u8 = "", units: f32 = 1 };
test "all basic keycodes have names and companion namespaces remain distinct" {
    var buffer: [256]u8 = undefined;
    inline for (@typeInfo(@import("zkeycodes").layouts.keycodes.kc.basic).@"enum".fields) |field| {
        try std.testing.expect(!std.mem.startsWith(u8, usage(@intCast(field.value), &buffer), "HID "));
    }
    try std.testing.expectEqualStrings("Home", usage(74, &buffer));
    try std.testing.expectEqualStrings("Backspace", usage(42, &buffer));
    try std.testing.expectEqualStrings("Delete", usage(76, &buffer));
    try std.testing.expectEqualStrings("Print statistics", usage(253, &buffer));
    try std.testing.expectEqualStrings("Toggle companion logging", tap(.{ .custom = 253 }, &buffer));
    try std.testing.expectEqualStrings("Quit companion", tap(.{ .custom = 254 }, &buffer));
    try std.testing.expectEqualStrings("Show / hide companion", tap(.{ .custom = 255 }, &buffer));
    try std.testing.expectEqualStrings("L Shift+1", tap(.{ .key_press = .{ .tap_keycode = 30, .tap_modifiers = .{ .left_shift = true } } }, &buffer));
}
pub const rows = [_][]const HostKey{
    &.{ .{ .code = 41 }, .{ .code = 58 }, .{ .code = 59 }, .{ .code = 60 }, .{ .code = 61 }, .{ .code = 62 }, .{ .code = 63 }, .{ .code = 64 }, .{ .code = 65 }, .{ .code = 66 }, .{ .code = 67 }, .{ .code = 68 }, .{ .code = 69 }, .{ .code = 76, .name = "Del" } },
    &.{ .{ .code = 53 }, .{ .code = 30 }, .{ .code = 31 }, .{ .code = 32 }, .{ .code = 33 }, .{ .code = 34 }, .{ .code = 35 }, .{ .code = 36 }, .{ .code = 37 }, .{ .code = 38 }, .{ .code = 39 }, .{ .code = 45 }, .{ .code = 46 }, .{ .code = 42, .units = 2 } },
    &.{ .{ .code = 43, .units = 1.5 }, .{ .code = 20 }, .{ .code = 26 }, .{ .code = 8 }, .{ .code = 21 }, .{ .code = 23 }, .{ .code = 28 }, .{ .code = 24 }, .{ .code = 12 }, .{ .code = 18 }, .{ .code = 19 }, .{ .code = 47 }, .{ .code = 48 }, .{ .code = 49, .units = 1.5 } },
    &.{ .{ .code = 57, .units = 1.75 }, .{ .code = 4 }, .{ .code = 22 }, .{ .code = 7 }, .{ .code = 9 }, .{ .code = 10 }, .{ .code = 11 }, .{ .code = 13 }, .{ .code = 14 }, .{ .code = 15 }, .{ .code = 51 }, .{ .code = 52 }, .{ .code = 40, .units = 2.25 } },
    &.{ .{ .code = 225, .name = "Shift", .units = 2.25 }, .{ .code = 29 }, .{ .code = 27 }, .{ .code = 6 }, .{ .code = 25 }, .{ .code = 5 }, .{ .code = 17 }, .{ .code = 16 }, .{ .code = 54 }, .{ .code = 55 }, .{ .code = 56 }, .{ .code = 229, .name = "Shift", .units = 1.75 }, .{ .code = 82 } },
    &.{ .{ .code = 224, .name = "Control", .units = 1.25 }, .{ .code = 226, .name = "Option", .units = 1.25 }, .{ .code = 227, .name = "Command", .units = 1.5 }, .{ .code = 44, .units = 5.5 }, .{ .code = 231, .name = "Command", .units = 1.5 }, .{ .code = 230, .name = "Option" }, .{ .code = 80 }, .{ .code = 81 }, .{ .code = 79 } },
};
