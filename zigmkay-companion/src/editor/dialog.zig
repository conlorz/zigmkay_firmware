//! SDL's retained asynchronous native folder dialog. Callback storage has process
//! lifetime, so late cancellation cannot write into a destroyed editor instance.
const std = @import("std");
const sdl = @import("sdl-backend").c;
var busy = std.atomic.Value(bool).init(false);
var done = std.atomic.Value(bool).init(false);
var result: [1024]u8 = @splat(0);
var failed = false;
fn selected(_: ?*anyopaque, paths: [*c]const [*c]const u8, _: c_int) callconv(.c) void {
    result = @splat(0);
    failed = paths == null;
    if (paths != null and paths[0] != null) {
        const path = std.mem.span(@as([*:0]const u8, @ptrCast(paths[0])));
        if (path.len >= result.len) failed = true else @memcpy(result[0..path.len], path);
    }
    done.store(true, .release);
}
pub fn start(window: *sdl.SDL_Window) !void {
    if (busy.swap(true, .acq_rel)) return error.DialogAlreadyOpen;
    done.store(false, .release);
    sdl.SDL_ShowOpenFolderDialog(selected, null, window, null, false);
}
pub fn poll() ?anyerror![1024]u8 {
    if (!busy.load(.acquire) or !done.load(.acquire)) return null;
    busy.store(false, .release);
    return if (failed) error.NativeDialogFailed else result;
}
pub fn active() bool {
    return busy.load(.acquire);
}
