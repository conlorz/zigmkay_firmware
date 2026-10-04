//! App-owned visual states and semantic event scenario, independent of HID.
const std = @import("std");
const dvui = @import("dvui");
const geometry = @import("geometry.zig");
pub const State = @import("states.zig").State;
pub fn setup(editor: anytype, state: State) !void {
    editor.testing.snapshot_id = try editor.model.id();
    switch (state) {
        .normal => {},
        .no_device => editor.connection_text = "Offline · No device",
        .multiselect => editor.model.select(11, true),
        .layer_add_rename => {
            try editor.model.addLayer(false);
            try editor.model.rename("New navigation");
            editor.syncRename();
        },
        .deletion_constraint => editor.model.deleteLayer(1) catch |err| editor.report(err),
        .combo => editor.combo_open = true,
        .advanced => editor.openAction(),
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
        .test_stale => editor.testing.state = .stale,
        .test_failed => {
            editor.testing.state = .failed;
            try editor.testing.diagnostic.appendSlice(editor.gpa, "Fixture compiler diagnostic: callback ABI mismatch");
            editor.test_details = true;
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
