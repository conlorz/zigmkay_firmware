//! App-owned visual states and semantic event scenario, independent of HID.
const std = @import("std");
const dvui = @import("dvui");
const geometry = @import("geometry.zig");
pub const State = @import("states.zig").State;
pub fn setup(editor: anytype, state: State) !void {
    editor.testing.snapshot_id = try editor.model.id();
    editor.firmware.snapshot_id = try editor.model.id();
    switch (state) {
        .practice_english, .practice_zig, .practice_scroll, .practice_input => {
            editor.practice_open = true;
            editor.practice_mode = if (state == .practice_zig or state == .practice_scroll) 1 else 0;
            try editor.startPractice(true);
            if (state == .practice_input) try editor.practice.load("a\n    b", .os);
        },
        .normal, .key_drag => {},
        .paths => editor.paths_open = true,
        .callback_editor => editor.callback_open = true,
        .no_device => editor.connection_text = "Offline · No device",
        .multiselect => editor.model.select(11, true),
        .layer_add_rename => {
            try editor.model.addLayer(false);
            try editor.model.rename("New navigation");
            editor.syncRename();
        },
        .deletion_constraint => editor.model.deleteLayer(1) catch |err| editor.report(err),
        .combo => editor.combo_open = true,
        .advanced, .key_search => editor.openAction(),
        .dirty => try editor.model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 5 } } }),
        .wrong_identity => {
            editor.connection_text = "Fixture · profile mismatch";
            editor.report(error.DeviceProfileMismatchDraftNotLive);
        },
        .validation => editor.model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 4 } }, .hold = .{ .layer_id = 2 }, .tapping_term = .{ .ms = 0 } } }) catch |err| editor.report(err),
        .callback_missing => editor.callback_state = .missing,
        .callback_changed => editor.callback_state = .changed,
        .test_preparing => editor.testing.state = .preparing,
        .test_running => editor.testing.state = .running,
        .test_output => {
            const wire = @import("runner-protocol");
            const output = wire.Output{
                .sequence = 1,
                .snapshot_id = editor.testing.snapshot_id,
                .state = .processed,
                .commands = &.{ .{ .KeyCodePress = 4 }, .{ .KeyCodeRelease = 4 } },
                .events = &.{ .Tick, .Tick },
                .signals = &.{ .{ .kind = .overlay_toggle, .pressed = true }, .{ .kind = .overlay_toggle, .pressed = false } },
            };
            var writer: std.Io.Writer.Allocating = .init(editor.gpa);
            defer writer.deinit();
            try std.zon.stringify.serializeMaxDepth(output, .{}, &writer.writer, 16);
            const bytes = try editor.gpa.dupeZ(u8, writer.written());
            defer editor.gpa.free(bytes);
            editor.testing.last = try std.zon.parse.fromSliceAlloc(wire.Output, editor.gpa, bytes, null, .{});
            editor.test_details = true;
        },
        .test_stale => editor.testing.state = .stale,
        .test_failed => {
            editor.testing.state = .failed;
            try editor.testing.diagnostic.appendSlice(editor.gpa, "Fixture compiler diagnostic: callback ABI mismatch");
            editor.test_details = true;
        },
        .firmware_building, .firmware_failed, .firmware_stale, .bootloader_fallback, .flash_transferred, .flash_reconnect_timeout => {
            editor.firmware.state = switch (state) {
                .firmware_building => .building,
                .firmware_failed => .failed,
                .firmware_stale => .stale,
                .flash_transferred => .transferred,
                .flash_reconnect_timeout => .reconnect_timeout,
                else => .idle,
            };
            if (state == .firmware_failed) try editor.firmware.diagnostic.appendSlice(editor.gpa, "callback_0.zig:12:9: error: invalid callback argument type");
            editor.firmware.transferred = state == .flash_transferred or state == .flash_reconnect_timeout;
        },
    }
}
pub fn verifyPanels(scale: f32) !void {
    for (geometry.reference, 0..) |expected, i| {
        const actual = dvui.tagGet(@tagName(@as(geometry.Panel, @enumFromInt(i)))) orelse return error.MissingPanelTag;
        if (!actual.visible) return error.ClippedPanel;
        const found = actual.rect;
        const values = [_]f32{ found.x / scale, found.y / scale, found.w / scale, found.h / scale };
        const targets = [_]f32{ expected.x, expected.y, expected.w, expected.h };
        for (values, targets) |value, target| if (@abs(value - target) > 4) return error.PanelGeometryMismatch;
    }
    const selected = dvui.tagGet("key.select.10") orelse return error.MissingKeyTag;
    if (!selected.visible or @abs(selected.rect.w / scale - 65) > 1) return error.KeyGeometryMismatch;
}
/// Dispatches a click through DVUI's actual input path using semantic rectangles.
/// Call before draw on the next frame. Tags and input both use physical pixels.
pub fn click(window: *dvui.Window, tag: []const u8, scale: f32, release: bool) !void {
    _ = scale;
    const target = dvui.tagGet(tag) orelse return error.MissingControlTag;
    if (!target.visible) return error.ControlNotVisible;
    _ = try window.addEventMouseMotion(.{ .pt = .{ .x = target.rect.x + target.rect.w / 2, .y = target.rect.y + target.rect.h / 2 } });
    _ = try window.addEventMouseButton(.left, if (release) .release else .press);
}
pub fn move(window: *dvui.Window, tag: []const u8) !void {
    const target = dvui.tagGet(tag) orelse return error.MissingControlTag;
    if (!target.visible) return error.ControlNotVisible;
    _ = try window.addEventMouseMotion(.{ .pt = .{ .x = target.rect.x + target.rect.w / 2, .y = target.rect.y + target.rect.h / 2 } });
}
