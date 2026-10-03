const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");
const sdl = SDLBackend.c;
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");
const protocol = @import("device-protocol");
const companion = @import("companion-model");
const cache = @import("components/cache.zig");
const keys = @import("components/key.zig");
const layout_component = @import("components/layout.zig");
const LogComponent = @import("components/log.zig").LogComponent;

fn openRawHid() ?*sdl.SDL_hid_device {
    const devices = sdl.SDL_hid_enumerate(0xFAFA, 0x00F0);
    defer sdl.SDL_hid_free_enumeration(devices);
    var device = devices;
    while (device != null) : (device = device.*.next) {
        if (device.*.usage_page == 0xFF31 and device.*.usage == 0x0074) return sdl.SDL_hid_open_path(device.*.path);
    }
    return null;
}
fn receive(state: *companion.State, log: *LogComponent, io: std.Io, bytes: []const u8) !void {
    const message = try protocol.decode(bytes, state.dimensions);
    try state.apply(message);
    switch (message.event) {
        .key => |event| log.record(event, @intCast(std.Io.Clock.awake.now(io).toMilliseconds())),
        .layers => {},
    }
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var smoke = false;
    var live = false;
    var replay: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--smoke")) smoke = true else if (std.mem.eql(u8, args[i], "--live")) live = true else if (std.mem.eql(u8, args[i], "--replay") and i + 1 < args.len) {
            i += 1;
            replay = args[i];
        } else return error.Usage;
    }
    if (live and (smoke or replay != null)) return error.IncompatibleModes;
    var state = try companion.State.init(.{ .key_count = keymap.key_count, .layer_count = keymap.keymap.len });
    var log = LogComponent{};
    if (replay) |path| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024 * 1024));
        if (bytes.len % protocol.report_size != 0) return error.IncompleteReport;
        var offset: usize = 0;
        while (offset < bytes.len) : (offset += protocol.report_size) try receive(&state, &log, init.io, bytes[offset..][0..protocol.report_size]);
    }
    var backend = try SDLBackend.initWindow(.{ .io = init.io, .environ_map = init.environ_map, .size = .{ .w = 1600, .h = 1000 }, .title = "Zigmkay LK7 Companion", .vsync = true });
    defer backend.deinit();
    var open = true;
    var win = try dvui.Window.init(@src(), init.gpa, backend.backend(), .{ .theme = dvui.Theme.builtin.adwaita_dark, .open_flag = &open });
    defer win.deinit();
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);
    var label_cache = try cache.buildLabelCache(init.gpa, &km);
    defer label_cache.deinit();
    // All state changes occur on the UI thread. Default and smoke modes never enumerate HID.
    const device = if (live) openRawHid() orelse return error.KeyboardNotFound else null;
    defer {
        if (device) |dev| _ = sdl.SDL_hid_close(dev);
    }
    const layout = comptime layout_component.generateKeyPositions(keymap.key_count, keymap.sides, .{});
    var interrupted = false;
    var frames: usize = 0;
    var show_log = false;
    while (open) {
        try win.begin(win.beginWait(interrupted));
        try backend.addAllEvents(&win);
        if (device) |dev| {
            var report: protocol.Report = undefined;
            const size = sdl.SDL_hid_read_timeout(dev, &report, report.len, 0);
            if (size < 0) return error.KeyboardDisconnected;
            if (size > 0) try receive(&state, &log, init.io, report[0..@intCast(size)]);
        }
        dvui.label(@src(), "LK7 · layer {d} · {s}", .{ state.highest_layer, if (live) "live" else "offline" }, .{});
        _ = dvui.checkbox(@src(), &show_log, "Show event log", .{});
        const center_x: f32 = 800;
        const center_y: f32 = 500;
        const start_y = center_y - layout.total_height / 2;
        try keys.drawLayerGrid(state.highest_layer, keymap.keymap.len, 80, 2);
        try layout_component.drawKeysAndEncoder(&layout, &label_cache, state.highest_layer, &state.pressed, state.modifiers, null, center_x, center_y, start_y);
        if (show_log) try log.draw(&km, center_x, start_y, 2);
        const end_micros = try win.end(.{});
        frames += 1;
        if (smoke and frames == 3) break;
        interrupted = try backend.waitEventTimeout(if (live or smoke) 16_000 else win.waitTime(end_micros));
    }
}
test {
    _ = layout_component;
    _ = keys;
    _ = cache;
}
