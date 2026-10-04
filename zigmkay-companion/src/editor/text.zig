const std = @import("std");
const core = @import("zigmkay").core;
const native = @import("../input_source.zig");
pub const Text = struct {
    bytes: [8192]u8 = @splat(0),
    len: usize = 0,
    cursor: usize = 0,
    mods: core.Modifiers = .{},
    fixture_dead: bool = false,
    native_session: ?native.Session = null,
    logged: usize = 0,
    pub fn init(use_fixture: bool) Text {
        return .{ .native_session = if (use_fixture) null else native.Session.init() };
    }
    pub fn deinit(self: *Text) void {
        if (self.native_session) |*session| session.deinit();
    }
    pub fn reset(self: *Text) void {
        self.mods = .{};
        self.fixture_dead = false;
        if (self.native_session) |*session| session.reset();
    }
    pub fn refresh(self: *Text) bool {
        if (self.native_session) |*session| return session.refresh();
        return false;
    }
    pub fn value(self: *const Text) []const u8 {
        return self.bytes[0..self.len];
    }
    pub fn insert(self: *Text, bytes: []const u8) !void {
        if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUnicode;
        if (bytes.len > self.bytes.len - self.len) return error.TextLimit;
        std.mem.copyBackwards(u8, self.bytes[self.cursor + bytes.len .. self.len + bytes.len], self.bytes[self.cursor..self.len]);
        @memcpy(self.bytes[self.cursor..][0..bytes.len], bytes);
        self.cursor += bytes.len;
        self.len += bytes.len;
    }
    fn previous(self: *const Text) usize {
        if (self.cursor == 0) return 0;
        var index = self.cursor - 1;
        while (index > 0 and self.bytes[index] & 0xC0 == 0x80) index -= 1;
        return index;
    }
    fn next(self: *const Text) usize {
        if (self.cursor == self.len) return self.len;
        return self.cursor + (std.unicode.utf8ByteSequenceLength(self.bytes[self.cursor]) catch 1);
    }
    fn erase(self: *Text, start: usize, end: usize) void {
        std.mem.copyForwards(u8, self.bytes[start .. self.len - (end - start)], self.bytes[end..self.len]);
        self.len -= end - start;
        self.cursor = start;
    }
    /// Deterministic fixture is deliberately small; native acceptance separately
    /// uses actual selected EurKEY. Includes dead composition and multi-scalar output.
    fn fixture(self: *Text, code: u8, buffer: *[128]u8) []const u8 {
        if (self.mods.left_alt and code == 52) {
            self.fixture_dead = true;
            return "";
        }
        if (self.fixture_dead) {
            self.fixture_dead = false;
            return if (code == 8) "é" else "´a";
        }
        if (self.mods.left_alt and code == 22) return "ß";
        if (code >= 4 and code <= 29) {
            buffer[0] = (if (self.mods.left_shift or self.mods.right_shift) @as(u8, 'A') else 'a') + code - 4;
            return buffer[0..1];
        }
        return switch (code) {
            44 => " ",
            54 => ",",
            55 => ".",
            56 => "/",
            else => "",
        };
    }
    pub fn output(self: *Text, commands: []const core.OutputCommand) !void {
        for (commands) |command| switch (command) {
            .ModifiersChanged => |mods| self.mods = mods,
            .KeyCodeRelease => {},
            .KeyCodePress => |code| {
                if (code >= 252) {
                    self.logged += 1;
                    continue;
                }
                if (self.mods.left_ctrl or self.mods.right_ctrl or self.mods.left_gui or self.mods.right_gui) {
                    self.logged += 1;
                    continue;
                }
                switch (code) {
                    40 => try self.insert("\n"),
                    43 => try self.insert("\t"),
                    42 => self.erase(self.previous(), self.cursor),
                    76 => self.erase(self.cursor, self.next()),
                    80 => self.cursor = self.previous(),
                    79 => self.cursor = self.next(),
                    74 => self.cursor = 0,
                    77 => self.cursor = self.len,
                    else => {
                        var buffer: [128]u8 = undefined;
                        const bytes = if (self.native_session) |*session| try session.translate(.{ .tap_keycode = code, .tap_modifiers = self.mods }, &buffer) else self.fixture(code, &buffer);
                        try self.insert(bytes);
                    },
                }
            },
            else => self.logged += 1,
        };
    }
};
test "composition, several scalars, editing and reset have literal text outcomes" {
    var text = Text.init(true);
    defer text.deinit();
    try text.output(&.{ .{ .ModifiersChanged = .{ .left_alt = true } }, .{ .KeyCodePress = 52 }, .{ .ModifiersChanged = .{} }, .{ .KeyCodePress = 8 } });
    try std.testing.expectEqualStrings("é", text.value());
    try text.output(&.{ .{ .ModifiersChanged = .{ .left_alt = true } }, .{ .KeyCodePress = 52 }, .{ .ModifiersChanged = .{} }, .{ .KeyCodePress = 4 } });
    try std.testing.expectEqualStrings("é´a", text.value());
    try text.output(&.{ .{ .KeyCodePress = 42 }, .{ .KeyCodePress = 80 }, .{ .KeyCodePress = 76 } });
    try std.testing.expectEqualStrings("é", text.value());
    try text.output(&.{ .{ .ModifiersChanged = .{ .left_alt = true } }, .{ .KeyCodePress = 52 } });
    text.reset();
    try text.output(&.{.{ .KeyCodePress = 8 }});
    try std.testing.expectEqualStrings("ée", text.value());
    try text.output(&.{ .ActivateBootMode, .{ .ConsumerKeyPressed = .VolumeUp }, .{ .MouseCommandPressed = .WheelDown }, .{ .ModifiersChanged = .{ .left_gui = true } }, .{ .KeyCodePress = 20 } });
    try std.testing.expectEqualStrings("ée", text.value());
    try std.testing.expectEqual(@as(usize, 4), text.logged);
}
