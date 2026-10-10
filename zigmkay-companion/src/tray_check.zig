//! Explicit, finite, offline native tray acceptance. Uses an inert editor and
//! real AppKit action callbacks; never opens HID or personal project files.
const std = @import("std");
const builtin = @import("builtin");
const desktop = @import("desktop.zig");
const Backend = @import("sdl-backend");
const sdl = Backend.c;
const dvui = @import("dvui");
const Editor = @import("editor/main.zig").Editor;
const scenario = @import("editor/scenario.zig");

extern "c" fn objc_getClass([*:0]const u8) ?*anyopaque;
extern "c" fn sel_registerName([*:0]const u8) *anyopaque;
extern "c" fn objc_msgSend() void;
fn object(receiver: *anyopaque, selector: [*:0]const u8) *anyopaque {
    const send: *const fn (*anyopaque, *anyopaque) callconv(.c) *anyopaque = @ptrCast(&objc_msgSend);
    return send(receiver, sel_registerName(selector));
}
fn nativeAction(action: desktop.Action) !void {
    if (builtin.os.tag != .macos) return error.TrayCheckRequiresMacOS;
    const target_class = objc_getClass("ZTrayTrayMenuTarget") orelse return error.NativeTrayTargetMissing;
    const item_class = objc_getClass("NSMenuItem") orelse return error.NativeMenuItemMissing;
    const target = object(target_class, "new");
    defer _ = object(target, "release");
    const item = object(item_class, "new");
    defer _ = object(item, "release");
    const set_tag: *const fn (*anyopaque, *anyopaque, isize) callconv(.c) void = @ptrCast(&objc_msgSend);
    set_tag(item, sel_registerName("setTag:"), @intFromEnum(action));
    const send: *const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.c) void = @ptrCast(&objc_msgSend);
    send(target, sel_registerName("performZTrayTrayAction:"), item);
}
fn closeWindow(window: *sdl.SDL_Window) !void {
    var event: sdl.SDL_Event = std.mem.zeroes(sdl.SDL_Event);
    event.type = sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
    event.window.windowID = sdl.SDL_GetWindowID(window);
    if (!sdl.SDL_PushEvent(&event)) return error.CannotPushCloseEvent;
}
fn expect(condition: bool) !void {
    if (!condition) return error.NativeTrayLifecycleCheckFailed;
}
fn windowFitsDisplay(window: *sdl.SDL_Window) !void {
    var usable: sdl.SDL_Rect = undefined;
    try expect(sdl.SDL_GetDisplayUsableBounds(sdl.SDL_GetDisplayForWindow(window), &usable));
    var client: sdl.SDL_Rect = undefined;
    try expect(sdl.SDL_GetWindowPosition(window, &client.x, &client.y));
    try expect(sdl.SDL_GetWindowSize(window, &client.w, &client.h));
    var borders: @import("editor/window_placement.zig").Borders = .{};
    _ = sdl.SDL_GetWindowBordersSize(window, &borders.top, &borders.left, &borders.bottom, &borders.right);
    try expect(client.x - borders.left >= usable.x and client.y - borders.top >= usable.y);
    try expect(client.x + client.w + borders.right <= usable.x + usable.w and client.y + client.h + borders.bottom <= usable.y + usable.h);
}
pub const Check = struct {
    window_id: u32 = 0,
    snapshot: [32]u8 = @splat(0),
    history: usize = 0,
    selected: usize = 0,
    pub fn beforeEditorDraw(_: *Check, frame: usize) !void {
        if (frame == 14 or frame == 15) {
            const window = dvui.currentWindow();
            try scenario.click(window, "close.keep", window.natural_scale, frame == 15);
        }
    }
    pub fn afterFrame(self: *Check, frame: usize, life: *desktop.Lifecycle, tray: *desktop.NativeTray, backend: *Backend, editor: ?*Editor) !void {
        switch (frame) {
            1 => try nativeAction(.open_editor),
            3 => {
                self.window_id = editor.?.window_id;
                try windowFitsDisplay(editor.?.backend_window.?);
                try nativeAction(.open_editor);
            },
            5 => {
                try expect(editor.?.window_id == self.window_id);
                try expect(sdl.SDL_GetKeyboardFocus() == editor.?.backend_window.?);
                var usable: sdl.SDL_Rect = undefined;
                try expect(sdl.SDL_GetDisplayUsableBounds(sdl.SDL_GetDisplayForWindow(editor.?.backend_window.?), &usable));
                try expect(sdl.SDL_SetWindowPosition(editor.?.backend_window.?, usable.x + usable.w + 500, usable.y + usable.h + 500));
                try editor.?.model.assignChord(.{ .tap_keycode = 5 }, false, 0);
                self.snapshot = try editor.?.model.id();
                self.history = editor.?.model.undo_stack.items.len;
                try closeWindow(editor.?.backend_window.?);
                try closeWindow(backend.window);
            },
            6 => try editor.?.free_text.insert("Retained text"),
            7 => {
                try expect(!life.editor_visible and !life.companion_visible and life.keepRunning());
                try expect(sdl.SDL_GetWindowFlags(editor.?.backend_window.?) & sdl.SDL_WINDOW_HIDDEN != 0);
                try nativeAction(.open_editor);
            },
            9 => {
                try expect(life.editor_visible and editor.?.window_id == self.window_id);
                try windowFitsDisplay(editor.?.backend_window.?);
                try expect(sdl.SDL_GetKeyboardFocus() == editor.?.backend_window.?);
                try expect(std.mem.eql(u8, &self.snapshot, &try editor.?.model.id()));
                try expect(self.history == editor.?.model.undo_stack.items.len);
                try expect(std.mem.eql(u8, editor.?.free_text.value(), "Retained text"));
                try nativeAction(.toggle_companion);
            },
            10 => {
                self.selected = editor.?.model.primary;
                editor.?.canvas_focus = true;
                var event: sdl.SDL_Event = std.mem.zeroes(sdl.SDL_Event);
                event.type = sdl.SDL_EVENT_KEY_DOWN;
                event.key.windowID = self.window_id;
                event.key.scancode = sdl.SDL_SCANCODE_RIGHT;
                if (!sdl.SDL_PushEvent(&event)) return error.CannotPushKeyEvent;
            },
            11 => {
                try expect(life.companion_visible and sdl.SDL_GetWindowFlags(backend.window) & sdl.SDL_WINDOW_HIDDEN == 0);
                try expect(editor.?.model.primary == (self.selected + 1) % 34);
                try nativeAction(.quit);
            },
            13 => try expect(editor.?.close_requested and life.keepRunning()),
            17 => {
                try expect(!editor.?.close_requested and life.keepRunning());
                editor.?.firmware.state = .transferring;
                try nativeAction(.quit);
            },
            19 => {
                try expect(life.keepRunning() and !editor.?.should_close);
                try expect(std.mem.eql(u8, std.mem.sliceTo(&editor.?.diagnostic, 0), "TransferInProgress"));
                editor.?.firmware.state = .idle;
                editor.?.model.saved_id = try editor.?.model.id();
                try nativeAction(.quit);
            },
            20 => {
                try expect(!life.running);
                tray.deinit();
                try expect(!tray.installed);
                std.log.info("Native tray callbacks, hide/reopen, retained draft/history, canceled quit, transfer guard and shutdown passed", .{});
            },
            else => {},
        }
    }
};
