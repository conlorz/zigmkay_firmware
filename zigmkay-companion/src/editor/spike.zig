//! Bounded native acceptance probe. No transport or device implementation is imported.
const std = @import("std");
const dvui = @import("dvui");
const Backend = @import("sdl-backend");
const sdl = Backend.c;
const Probe = struct {
    mapped: usize = 0,
    reset: usize = 0,
    pub fn raw(self: *Probe, event: sdl.SDL_Event) !bool {
        if (event.type == sdl.SDL_EVENT_WINDOW_FOCUS_LOST) self.reset += 1;
        if (event.type == sdl.SDL_EVENT_KEY_DOWN and event.key.scancode == sdl.SDL_SCANCODE_A) {
            self.mapped += 1;
            return true;
        }
        return false;
    }
};

pub fn run(init: std.process.Init, native_dialog: bool) !void {
    var backend = try Backend.initWindow(.{ .io = init.io, .environ_map = init.environ_map, .size = .{ .w = 900, .h = 600 }, .min_size = .{ .w = 640, .h = 400 }, .title = "Zigmkay editor — offline window probe", .vsync = false, .persist_window_geometry = false });
    defer backend.deinit();
    var open = true;
    var overlay_open = true;
    var window = try dvui.Window.init(@src(), init.gpa, backend.backend(), .{ .open_flag = &open });
    defer window.deinit();
    var telemetry: usize = 0;
    var frames: usize = 0;
    var child_id: u32 = 0;
    var probe = Probe{};
    var close_seen = false;
    var resized = false;
    var dialog_done = !native_dialog;
    var dialog_ticks: usize = 0;
    var close_sent = false;
    const deadline = std.Io.Clock.awake.now(init.io).toMilliseconds() + 60_000;
    while (open and (frames < 60 or !dialog_done or !close_seen)) : (frames += 1) {
        if (std.Io.Clock.awake.now(init.io).toMilliseconds() > deadline) return error.NativeDialogCheckTimedOut;
        try window.begin(window.beginWait(false));
        try @import("events.zig").pump(&backend, &window, &probe);
        telemetry += 1;
        dvui.label(@src(), "Offline native spike · fake telemetry {d}", .{telemetry}, .{});
        if (frames == 3 and !native_dialog) dvui.dialog(@src(), .{}, .{ .modal = false, .title = "File workflow probe", .message = "Telemetry continues while a dialog is displayed." });
        if (native_dialog and frames == 10) try @import("dialog.zig").start(backend.window);
        if (@import("dialog.zig").active()) dialog_ticks += 1;
        if (@import("dialog.zig").poll()) |result| {
            _ = try result;
            dialog_done = true;
        }
        if (frames == 20) resized = window.data().rect.w >= 1000 and window.data().rect.h >= 690;
        if (overlay_open) {
            const child = dvui.osWindow(@src(), .{ .title = "Separate overlay probe", .size = .{ .w = 400, .h = 200 } }, .{ .open_flag = &overlay_open });
            defer child.deinit();
            switch (child.inner) {
                .os => |os| child_id = sdl.SDL_GetWindowID(os.backend.window),
                else => return error.NativeChildWindowUnavailable,
            }
            dvui.label(@src(), "Overlay remains separate from editor", .{}, .{});
            dvui.label(@src(), "Fake telemetry: {d}", .{telemetry}, .{});
        } else close_seen = true;
        _ = try window.end(.{});
        if (frames == 10) {
            var key: sdl.SDL_Event = .{ .key = .{ .type = sdl.SDL_EVENT_KEY_DOWN, .windowID = sdl.SDL_GetWindowID(backend.window), .scancode = sdl.SDL_SCANCODE_A, .key = sdl.SDLK_A, .down = true } };
            if (!sdl.SDL_PushEvent(&key)) return error.EventRejected;
        }
        if (frames == 25) {
            var focus: sdl.SDL_Event = .{ .window = .{ .type = sdl.SDL_EVENT_WINDOW_FOCUS_LOST, .windowID = sdl.SDL_GetWindowID(backend.window) } };
            if (!sdl.SDL_PushEvent(&focus)) return error.EventRejected;
        }
        if (frames == 15 and !sdl.SDL_SetWindowSize(backend.window, 1024, 700)) return error.NativeResizeFailed;
        if (frames >= 35 and dialog_done and !close_sent) {
            var close: sdl.SDL_Event = .{ .window = .{ .type = sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED, .windowID = child_id } };
            if (!sdl.SDL_PushEvent(&close)) return error.EventRejected;
            close_sent = true;
        }
        _ = try backend.waitEventTimeout(16_000);
    }
    if (telemetry < 60 or probe.mapped == 0 or probe.reset == 0 or !close_seen or !open or !resized or (native_dialog and dialog_ticks == 0)) return error.NativeSpikeFailed;
    std.log.info("07B native spike: {d} telemetry ticks; mapped={d}; focus resets={d}; resize passed; child close preserved editor; renderer scale={d}; native dialog ticks={d}", .{ telemetry, probe.mapped, probe.reset, window.natural_scale, dialog_ticks });
}
