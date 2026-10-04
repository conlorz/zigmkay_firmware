const dvui = @import("dvui");
const Backend = @import("sdl-backend");
const sdl = Backend.c;
/// Route app-owned raw events, preserving child-window delivery. The hook can
/// consume mapped scancodes and observes focus loss (DVUI does not expose it).
pub fn pump(backend: *Backend, window: *dvui.Window, context: anytype) !void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        if (try context.raw(event)) continue;
        const id = switch (event.type) {
            sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_KEY_UP => event.key.windowID,
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => event.button.windowID,
            sdl.SDL_EVENT_MOUSE_MOTION => event.motion.windowID,
            sdl.SDL_EVENT_MOUSE_WHEEL => event.wheel.windowID,
            sdl.SDL_EVENT_TEXT_INPUT => event.text.windowID,
            else => if (event.type >= sdl.SDL_EVENT_WINDOW_FIRST and event.type <= sdl.SDL_EVENT_WINDOW_LAST) event.window.windowID else 0,
        };
        _ = try dispatch(backend, window, event, id);
    }
}
fn dispatch(backend: *Backend, window: *dvui.Window, event: sdl.SDL_Event, id: u32) !bool {
    if (id == 0 or sdl.SDL_GetWindowID(backend.window) == id) {
        _ = try backend.addEvent(window, event);
        return true;
    }
    var iterator = window.child_os_wins.iterator();
    while (iterator.next_peek()) |child| if (try dispatch(child.value.backend, child.value.dvui_win, event, id)) return true;
    return false;
}
