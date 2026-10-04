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
        42 => "Delete",
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
        79 => "Right",
        80 => "Left",
        81 => "Down",
        82 => "Up",
        252 => "BOOT",
        253 => "Overlay",
        254 => "Stats",
        255 => "Shutdown",
        else => if (code >= 58 and code <= 69) std.fmt.bufPrint(buffer, "F{d}", .{code - 57}) catch "?" else std.fmt.bufPrint(buffer, "HID {d}", .{code}) catch "?",
    };
}
pub fn tap(value: p.Tap, buffer: []u8) []const u8 {
    if (value.key_press) |key| return usage(key.tap_keycode, buffer);
    if (value.media_key) |media| return @tagName(media);
    if (value.mouse_action) |mouse| return @tagName(mouse);
    if (value.custom) |custom| return std.fmt.bufPrint(buffer, "Custom {d}", .{custom}) catch "?";
    if (value.one_shot) |hold| return if (hold.layer_id) |id| std.fmt.bufPrint(buffer, "One-shot L{d}", .{id}) catch "?" else "One-shot mods";
    return "No tap";
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
pub const rows = [_][]const HostKey{
    &.{ .{ .code = 41 }, .{ .code = 58 }, .{ .code = 59 }, .{ .code = 60 }, .{ .code = 61 }, .{ .code = 62 }, .{ .code = 63 }, .{ .code = 64 }, .{ .code = 65 }, .{ .code = 66 }, .{ .code = 67 }, .{ .code = 68 }, .{ .code = 69 }, .{ .code = 76, .name = "Del" } },
    &.{ .{ .code = 53 }, .{ .code = 30 }, .{ .code = 31 }, .{ .code = 32 }, .{ .code = 33 }, .{ .code = 34 }, .{ .code = 35 }, .{ .code = 36 }, .{ .code = 37 }, .{ .code = 38 }, .{ .code = 39 }, .{ .code = 45 }, .{ .code = 46 }, .{ .code = 42, .units = 2 } },
    &.{ .{ .code = 43, .units = 1.5 }, .{ .code = 20 }, .{ .code = 26 }, .{ .code = 8 }, .{ .code = 21 }, .{ .code = 23 }, .{ .code = 28 }, .{ .code = 24 }, .{ .code = 12 }, .{ .code = 18 }, .{ .code = 19 }, .{ .code = 47 }, .{ .code = 48 }, .{ .code = 49, .units = 1.5 } },
    &.{ .{ .code = 57, .units = 1.75 }, .{ .code = 4 }, .{ .code = 22 }, .{ .code = 7 }, .{ .code = 9 }, .{ .code = 10 }, .{ .code = 11 }, .{ .code = 13 }, .{ .code = 14 }, .{ .code = 15 }, .{ .code = 51 }, .{ .code = 52 }, .{ .code = 40, .units = 2.25 } },
    &.{ .{ .code = 225, .name = "Shift", .units = 2.25 }, .{ .code = 29 }, .{ .code = 27 }, .{ .code = 6 }, .{ .code = 25 }, .{ .code = 5 }, .{ .code = 17 }, .{ .code = 16 }, .{ .code = 54 }, .{ .code = 55 }, .{ .code = 56 }, .{ .code = 229, .name = "Shift", .units = 1.75 }, .{ .code = 82 } },
    &.{ .{ .code = 224, .name = "Control", .units = 1.25 }, .{ .code = 226, .name = "Option", .units = 1.25 }, .{ .code = 227, .name = "Command", .units = 1.5 }, .{ .code = 44, .units = 5.5 }, .{ .code = 231, .name = "Command", .units = 1.5 }, .{ .code = 230, .name = "Option" }, .{ .code = 80 }, .{ .code = 81 }, .{ .code = 79 } },
};
