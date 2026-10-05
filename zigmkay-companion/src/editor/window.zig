const Backend = @import("sdl-backend");
const sdl = Backend.c;
/// Low-density native renderer for acceptance, using the pinned backend's
/// existing-window API. Production windows use its normal high-density path.
pub fn init(options: Backend.InitOptions, low_density: bool) !Backend {
    if (!low_density) return Backend.initWindow(options);
    try Backend.initSDL();
    errdefer sdl.SDL_Quit();
    const window = sdl.SDL_CreateWindow(options.title, @intFromFloat(options.size.w), @intFromFloat(options.size.h), sdl.SDL_WINDOW_HIDDEN | sdl.SDL_WINDOW_RESIZABLE) orelse return error.WindowCreationFailed;
    errdefer sdl.SDL_DestroyWindow(window);
    if (!sdl.SDL_SetWindowMinimumSize(window, @intFromFloat(options.min_size.?.w), @intFromFloat(options.min_size.?.h))) return error.WindowConfigurationFailed;
    const renderer = sdl.SDL_CreateRenderer(window, null) orelse return error.RendererCreationFailed;
    errdefer sdl.SDL_DestroyRenderer(renderer);
    const blend = sdl.SDL_ComposeCustomBlendMode(sdl.SDL_BLENDFACTOR_ONE, sdl.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA, sdl.SDL_BLENDOPERATION_ADD, sdl.SDL_BLENDFACTOR_ONE, sdl.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA, sdl.SDL_BLENDOPERATION_ADD);
    if (!sdl.SDL_SetRenderDrawBlendMode(renderer, blend)) return error.RendererConfigurationFailed;
    var backend = Backend.init(options.io, window, renderer);
    backend.init_opts_save = options;
    backend.we_own_window = true;
    backend.clear_window_on_begin = true;
    backend.ak_should_initialized = false;
    return backend;
}
