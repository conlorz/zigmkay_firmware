//! Typed controls preserve simultaneous optional fields. Merely opening a form
//! cannot simplify an existing action; only explicit mode/field edits change it.
const std = @import("std");
const dvui = @import("dvui");
const p = @import("keymap-project");
const types = @import("layout-model");
const labels = @import("labels.zig");
pub const Draft = struct {
    mode: usize = 0,
    tap: p.Tap = .{},
    hold: p.Hold = .{},
    term: u16 = 180,
    retro: bool = false,
    initial: u16 = 300,
    repeat: u16 = 50,
    pub fn from(value: ?p.Action) Draft {
        const a = value orelse return .{};
        return switch (a) {
            .none => .{ .mode = 1 },
            .tap_only => |t| .{ .mode = 2, .tap = t },
            .hold_only => |h| .{ .mode = 3, .hold = h },
            .tap_hold => |th| .{ .mode = 4, .tap = th.tap, .hold = th.hold, .term = th.tapping_term.ms, .retro = th.retro_tapping },
            .tap_with_autofire => |af| .{ .mode = 5, .tap = af.tap, .initial = af.initial_delay.ms, .repeat = af.repeat_interval.ms },
        };
    }
    pub fn action(self: Draft) ?p.Action {
        return switch (self.mode) {
            0 => null,
            1 => .none,
            2 => .{ .tap_only = self.tap },
            3 => .{ .hold_only = self.hold },
            4 => .{ .tap_hold = .{ .tap = self.tap, .hold = self.hold, .tapping_term = .{ .ms = self.term }, .retro_tapping = self.retro } },
            5 => .{ .tap_with_autofire = .{ .tap = self.tap, .initial_delay = .{ .ms = self.initial }, .repeat_interval = .{ .ms = self.repeat } } },
            else => unreachable,
        };
    }
    pub fn homeRowMod(self: *Draft, bits: u8) void {
        self.mode = 4;
        self.hold.hold_modifiers = @bitCast(bits);
    }
};
fn number(comptime T: type, value: *T, title: []const u8) void {
    const row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .id_extra = std.hash.Wyhash.hash(0, title) });
    defer row.deinit();
    dvui.labelNoFmt(@src(), title, .{}, .{ .min_size_content = .{ .w = 200 } });
    _ = dvui.textEntryNumber(@src(), T, .{ .value = value }, .{ .min_size_content = .{ .w = 110, .h = 26 }, .padding = .all(6) });
}
fn modifiers(mods: *types.Modifiers, title: []const u8) void {
    const box = dvui.box(@src(), .{}, .{ .id_extra = std.hash.Wyhash.hash(0, title), .expand = .horizontal });
    defer box.deinit();
    dvui.labelNoFmt(@src(), title, .{}, .{});
    inline for (0..2) |side| {
        const row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = side });
        defer row.deinit();
        inline for (.{ "left_ctrl", "left_shift", "left_alt", "left_gui", "right_ctrl", "right_shift", "right_alt", "right_gui" }, 0..) |field, i| {
            if (i / 4 == side) {
                var checked = @field(mods, field);
                if (dvui.checkbox(@src(), &checked, switch (i) {
                    0 => "L Control",
                    1 => "L Shift",
                    2 => "L Option",
                    3 => "L Command",
                    4 => "R Control",
                    5 => "R Shift",
                    6 => "R Option",
                    7 => "R Command",
                    else => unreachable,
                }, .{ .id_extra = i })) @field(mods, field) = checked;
            }
        }
    }
}
pub fn hold(value: *p.Hold, doc: p.Document, title: []const u8) void {
    const box = dvui.box(@src(), .{}, .{ .id_extra = std.hash.Wyhash.hash(0, title), .expand = .horizontal });
    defer box.deinit();
    dvui.labelNoFmt(@src(), title, .{}, .{});
    modifiers(&value.hold_modifiers, "Hold modifiers (left/right)");
    var selected: usize = 0;
    var names: [16][]const u8 = undefined;
    names[0] = "No layer";
    for (doc.layers, 0..) |layer, i| {
        names[i + 1] = layer.name;
        if (value.layer_id == layer.id) selected = i + 1;
    }
    if (dvui.dropdown(@src(), names[0 .. doc.layers.len + 1], .{ .choice = &selected }, .{}, .{ .expand = .horizontal })) value.layer_id = if (selected == 0) null else doc.layers[selected - 1].id;
    var has_custom = value.custom != null;
    if (dvui.checkbox(@src(), &has_custom, "Custom hold callback", .{})) value.custom = if (has_custom) 1 else null;
    if (value.custom) |*id| number(u8, id, "Hold callback ID");
}
pub fn tap(value: *p.Tap, doc: p.Document) void {
    dvui.label(@src(), "Tap fields may coexist; uncheck a field only to remove it.", .{}, .{});
    var has_key = value.key_press != null;
    if (dvui.checkbox(@src(), &has_key, "Key / modifier chord", .{})) value.key_press = if (has_key) .{ .tap_keycode = 4 } else null;
    if (value.key_press) |*key| {
        var name_buffers: [256][64]u8 = undefined;
        var names: [256][]const u8 = undefined;
        for (&names, 0..) |*name, code| name.* = labels.usage(@intCast(code), &name_buffers[code]);
        var choice: usize = key.tap_keycode;
        if (dvui.dropdown(@src(), &names, .{ .choice = &choice }, .{}, .{ .expand = .horizontal })) key.tap_keycode = @intCast(choice);
        number(u8, &key.tap_keycode, "HID usage (252 = recovery)");
        modifiers(&key.tap_modifiers, "Tap modifiers (left/right)");
        _ = dvui.checkbox(@src(), &key.dead, "Dead-key chord", .{});
    }
    var has_one_shot = value.one_shot != null;
    if (dvui.checkbox(@src(), &has_one_shot, "One-shot hold", .{})) value.one_shot = if (has_one_shot) .{} else null;
    if (value.one_shot) |*one| hold(one, doc, "One-shot fields");
    var has_custom = value.custom != null;
    if (dvui.checkbox(@src(), &has_custom, "Custom tap callback / reserved signal", .{})) value.custom = if (has_custom) 1 else null;
    if (value.custom) |*id| {
        var selected: usize = switch (id.*) {
            253 => 1,
            254 => 2,
            255 => 3,
            else => 0,
        };
        if (dvui.dropdown(@src(), &.{ "Custom callback", "Toggle companion logging", "Quit companion", "Show / hide companion" }, .{ .choice = &selected }, .{}, .{ .expand = .horizontal })) id.* = switch (selected) {
            1 => 253,
            2 => 254,
            3 => 255,
            else => 1,
        };
        if (selected == 0) number(u8, id, "Tap callback ID");
    }
    var has_media = value.media_key != null;
    if (dvui.checkbox(@src(), &has_media, "Consumer / media key", .{})) value.media_key = if (has_media) .VolumeUp else null;
    if (value.media_key) |*media| _ = dvui.dropdownEnum(@src(), types.MediaCode, .{ .choice = media }, .{}, .{ .expand = .horizontal });
    var has_mouse = value.mouse_action != null;
    if (dvui.checkbox(@src(), &has_mouse, "Mouse action", .{})) value.mouse_action = if (has_mouse) .WheelDown else null;
    if (value.mouse_action) |*mouse| _ = dvui.dropdownEnum(@src(), types.MouseAction, .{ .choice = mouse }, .{}, .{ .expand = .horizontal });
}
pub fn draw(draft: *Draft, doc: p.Document) void {
    if (draft.tap.key_press != null and (draft.mode == 2 or draft.mode == 4)) {
        var choice: usize = 0;
        if (dvui.dropdown(@src(), &.{ "Set home row mod…", "Hold left Control", "Hold left Shift", "Hold left Alt / Option", "Hold left GUI / Command", "Hold right Control", "Hold right Shift", "Hold right Alt / Option", "Hold right GUI / Command" }, .{ .choice = &choice }, .{}, .{ .expand = .horizontal })) {
            if (choice > 0) draft.homeRowMod(@as(u8, 1) << @intCast(choice - 1));
        }
        if (draft.mode == 4) {
            dvui.label(@src(), "Home row mod: keep the tap key, choose hold modifiers below.", .{}, .{});
        }
    }
    _ = dvui.dropdown(@src(), &.{ "Transparent / inherited", "Explicit no action", "Tap only", "Hold only", "Tap / hold", "Tap with autofire" }, .{ .choice = &draft.mode }, .{}, .{ .expand = .horizontal });
    if (draft.mode == 2 or draft.mode == 4 or draft.mode == 5) tap(&draft.tap, doc);
    if (draft.mode == 3 or draft.mode == 4) hold(&draft.hold, doc, "Hold fields");
    if (draft.mode == 4) {
        number(u16, &draft.term, "Tapping term (ms)");
        _ = dvui.checkbox(@src(), &draft.retro, "Retro tapping", .{});
    }
    if (draft.mode == 5) {
        number(u16, &draft.initial, "Initial delay (ms)");
        number(u16, &draft.repeat, "Repeat interval (ms)");
    }
}
test "form representation preserves every simultaneous tap and hold field" {
    const action = p.Action{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 8, .dead = true, .tap_modifiers = .{ .right_gui = true } }, .custom = 1, .one_shot = .{ .layer_id = 3 }, .media_key = .VolumeUp, .mouse_action = .WheelDown }, .hold = .{ .layer_id = 2, .custom = 2, .hold_modifiers = .{ .left_ctrl = true } }, .tapping_term = .{ .ms = 231 }, .retro_tapping = true } };
    try std.testing.expectEqualDeep(@as(?p.Action, action), Draft.from(action).action());
}
test "home row mod shortcut preserves tap chord and timing" {
    var draft = Draft{ .mode = 2, .tap = .{ .key_press = .{ .tap_keycode = 4, .tap_modifiers = .{ .right_alt = true } } }, .term = 231, .retro = true };
    const original = draft.tap;
    draft.homeRowMod(2);
    const action = draft.action().?.tap_hold;
    try std.testing.expectEqualDeep(original, action.tap);
    try std.testing.expect(action.hold.hold_modifiers.left_shift);
    try std.testing.expectEqual(@as(u16, 231), action.tapping_term.ms);
    try std.testing.expect(action.retro_tapping);
}
