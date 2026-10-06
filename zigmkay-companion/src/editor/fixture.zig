//! Fixed visual fixture. Native captures never compile or execute source bytes.
const std = @import("std");
const p = @import("keymap-project");
pub fn setup(model: anytype) !void {
    model.layer = 1;
    try model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 4 } }, .hold = .{ .hold_modifiers = .{ .left_gui = true } }, .tapping_term = .{ .ms = 180 } } });
    const bytes = "const core = @import(\"zigmkay\").core;\npub const custom_functions = core.CustomFunctions{};\n";
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const metadata = [_]p.Source{.{ .path = "callbacks.zig", .digest = digest }};
    const callbacks = [_]p.Callback{.{ .kind = .attached, .binding = "callbacks.zig", .ids = &.{1}, .sources = &metadata }};
    const sources = [_]p.snapshot.SourceBytes{.{ .callback_index = 0, .path = "callbacks.zig", .bytes = bytes }};
    var snapshot = model.current.snapshot;
    snapshot.document.callbacks = &callbacks;
    snapshot.sources = &sources;
    try model.commit(snapshot);
    model.saved_id = try model.id();
}
/// EurKEY Next 2026.03.22 Option labels keyed by Carbon virtual key. This is a
/// deterministic label fixture, independent of whichever source the OS selects.
pub fn optionLabel(code: u8, shift: bool) []const u8 {
    const vk = @import("zkeymap").hid_to_platform.hidToMacVk(code) orelse return "";
    if (shift) return switch (vk) {
        0 => "Ä",
        1 => "ẞ",
        2 => "Đ",
        3 => "È",
        4 => "Ù",
        5 => "É",
        6 => "À",
        7 => "Á",
        8 => "Ç",
        9 => "Ì",
        11 => "Í",
        12 => "Æ",
        13 => "Å",
        14 => "Ë",
        15 => "Ý",
        16 => "Ÿ",
        17 => "Þ",
        31 => "Ö",
        32 => "Ü",
        34 => "Ï",
        35 => "Œ",
        37 => "Ø",
        38 => "Ú",
        40 => "Ĳ",
        45 => "Ñ",
        46 => "Ω",
        47 => "Ó",
        39 => "¨",
        else => "",
    };
    return switch (vk) {
        0 => "ä",
        1 => "ß",
        2 => "đ",
        3 => "è",
        4 => "ù",
        5 => "é",
        6 => "à",
        7 => "á",
        8 => "ç",
        9 => "ì",
        11 => "í",
        12 => "æ",
        13 => "å",
        14 => "ë",
        15 => "ý",
        16 => "ÿ",
        17 => "þ",
        18 => "¡",
        19 => "ª",
        20 => "º",
        21 => "£",
        22 => "^",
        23 => "€",
        24 => "×",
        25 => "“",
        26 => "˚",
        27 => "✓",
        28 => "„",
        29 => "”",
        30 => "»",
        31 => "ö",
        32 => "ü",
        33 => "«",
        34 => "ï",
        35 => "œ",
        37 => "ø",
        38 => "ú",
        39 => "´",
        40 => "ĳ",
        41 => "°",
        42 => "¬",
        43 => "ò",
        44 => "¿",
        45 => "ñ",
        46 => "Ω",
        47 => "ó",
        49 => "NBSP",
        50 => "`",
        else => "",
    };
}
pub fn shiftLabel(code: u8) []const u8 {
    return switch (code) {
        30 => "!",
        31 => "@",
        32 => "#",
        33 => "$",
        34 => "%",
        35 => "^",
        36 => "&",
        37 => "*",
        38 => "(",
        39 => ")",
        45 => "_",
        46 => "+",
        47 => "{",
        48 => "}",
        49 => "|",
        51 => ":",
        52 => "\"",
        53 => "~",
        54 => "<",
        55 => ">",
        56 => "?",
        else => "",
    };
}
