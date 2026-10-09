const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");
const sdl = SDLBackend.c;
const keymap = @import("keymap");
const protocol = @import("device-protocol");
const companion = @import("companion-model");
const adapter = @import("live_adapter.zig");
const capture = @import("session_capture.zig");
const input = @import("input_source.zig");
const cache = @import("components/cache.zig");
const keys = @import("components/key.zig");
const layout = @import("components/layout.zig");
const LogComponent = @import("components/log.zig").LogComponent;
const desktop = @import("desktop.zig");

const DesktopEvents = struct {
    life: *desktop.Lifecycle,
    companion_id: u32,
    editor: ?*@import("editor/main.zig").Editor,
    pub fn raw(self: DesktopEvents, event: sdl.SDL_Event) !bool {
        if (self.life.resident) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                self.life.action(.quit);
                return true;
            }
            if (event.type == sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID == self.companion_id) {
                self.life.companion_visible = false;
                return true;
            }
        }
        if (self.editor) |editor| return editor.raw(event);
        return false;
    }
};

pub const Native = struct {
    device: ?*sdl.SDL_hid_device = null,
    io: std.Io,
    paths: [8][512:0]u8 = undefined,
    path_lengths: [8]usize = @splat(0),
    path_count: usize = 0,
    discovery_logged: bool = false,
    pub fn now(self: *Native) u64 {
        return @intCast(std.Io.Clock.awake.now(self.io).toMilliseconds());
    }
    pub fn discover(self: *Native, requested: ?[]const u8) !adapter.Discovery {
        const devices = sdl.SDL_hid_enumerate(0xFAFA, 0x00F0);
        defer sdl.SDL_hid_free_enumeration(devices);
        self.path_count = 0;
        var count: usize = 0;
        var selected: ?[*:0]const u8 = null;
        var device = devices;
        while (device != null) : (device = device.*.next) {
            if (!self.discovery_logged) std.log.info("HID candidate: page={x}, usage={x}, path={s}", .{ device.*.usage_page, device.*.usage, if (device.*.path) |p| std.mem.span(p) else "(none)" });
            if (device.*.usage_page != 0xFF31 or device.*.usage != 0x0074 or device.*.path == null) continue;
            count += 1;
            const path = std.mem.span(device.*.path);
            if (self.path_count < self.paths.len and path.len < self.paths[0].len) {
                @memcpy(self.paths[self.path_count][0..path.len], path);
                self.paths[self.path_count][path.len] = 0;
                self.path_lengths[self.path_count] = path.len;
                self.path_count += 1;
            }
            if (requested) |wanted| {
                if (std.mem.eql(u8, wanted, path)) selected = device.*.path;
            } else selected = device.*.path;
        }
        if (!self.discovery_logged) std.log.info("Vendor HID discovery found {d} matching collections", .{count});
        self.discovery_logged = true;
        if (requested != null and selected == null) return .path_not_found;
        if (requested == null and count > 1) return .multiple_devices;
        if (selected) |path| {
            _ = sdl.SDL_ClearError();
            self.device = sdl.SDL_hid_open_path(path) orelse {
                const detail = std.mem.span(sdl.SDL_GetError());
                std.log.err("Cannot open vendor HID collection {s}: {s}", .{ std.mem.span(path), if (detail.len == 0) "SDL provided no native error detail" else detail });
                return error.HidOpenFailed;
            };
            std.log.info("Opened vendor HID collection {s}", .{std.mem.span(path)});
            return .selected;
        }
        return .no_device;
    }
    pub fn read(self: *Native, bytes: *[33]u8) !usize {
        const count = sdl.SDL_hid_read_timeout(self.device.?, bytes, bytes.len, 0);
        if (count < 0) return error.HidReadFailed;
        return @intCast(count);
    }
    pub fn write(self: *Native, bytes: []const u8) !void {
        const count = sdl.SDL_hid_write(self.device.?, bytes.ptr, bytes.len);
        if (count != bytes.len) return error.HidWriteFailed;
    }
    pub fn close(self: *Native) void {
        if (self.device) |device| _ = sdl.SDL_hid_close(device);
        self.device = null;
    }
};
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
    if (args.len > 1 and std.mem.eql(u8, args[1], "--native-text-check")) {
        var session = input.Session.init();
        defer session.deinit();
        std.log.info("Native source={s}; layout={s}; EurKEY={}", .{ session.source.id(), session.source.layoutId(), session.eurkey() });
        var output: [128]u8 = undefined;
        for ([_]u8{ 4, 8, 22, 52 }) |code| {
            session.reset();
            const translated = try session.translate(.{ .tap_keycode = code, .tap_modifiers = .{ .left_alt = true } }, &output);
            std.log.info("Option + HID {d}: {s}; dead-state={d}", .{ code, translated, session.dead_state });
            if (session.dead_state != 0) {
                const composed = try session.translate(.{ .tap_keycode = 8 }, &output);
                std.log.info("Then E: {s}", .{composed});
            }
        }
        session.reset();
        _ = try session.translate(.{ .tap_keycode = 52, .tap_modifiers = .{ .left_alt = true } }, &output);
        try std.testing.expectEqualStrings("´q", try session.translate(.{ .tap_keycode = 20 }, &output));
        _ = try session.translate(.{ .tap_keycode = 52, .tap_modifiers = .{ .left_alt = true } }, &output);
        session.reset();
        try std.testing.expectEqualStrings("e", try session.translate(.{ .tap_keycode = 8 }, &output));
        std.log.info("Native EurKEY composition, multi-scalar fallback and reset passed", .{});
        return;
    }
    if (args.len > 1 and std.mem.eql(u8, args[1], "--editor-spike")) return @import("editor/spike.zig").run(init, args.len > 2 and std.mem.eql(u8, args[2], "--native-dialog"));
    const editor_start = args.len > 1 and std.mem.eql(u8, args[1], "--editor");
    // Preserve the finite acceptance runner and its full command-line contract.
    if (editor_start) for (args[2..]) |arg| {
        if (!std.mem.eql(u8, arg, "--light") and !std.mem.eql(u8, arg, "--practice") and !std.mem.eql(u8, arg, "--live")) return @import("editor/main.zig").run(init, args);
    };
    var editor_light = false;
    var editor_practice = false;
    var smoke = false;
    var tray_check = false;
    var editor_smoke = false;
    var live = false;
    var verify_running = false;
    var replay: ?[]const u8 = null;
    var timed_replay: ?[]const u8 = null;
    var path: ?[]const u8 = null;
    var capture_path: ?[]const u8 = null;
    var capture_ms: u64 = 30_000;
    var opacity: f32 = 0.94;
    var top = true;
    var focusable = true;
    var borderless = false;
    var click_through = false;
    var position: ?struct { x: c_int, y: c_int } = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (editor_start) {
            if (std.mem.eql(u8, arg, "--light")) editor_light = true;
            if (std.mem.eql(u8, arg, "--practice")) editor_practice = true;
            if (std.mem.eql(u8, arg, "--live")) live = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--tray-check")) {
            tray_check = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--editor-overlay-smoke")) {
            smoke = true;
            editor_smoke = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--verify-running")) {
            verify_running = true;
            live = true;
        } else if (std.mem.eql(u8, arg, "--smoke")) smoke = true else if (std.mem.eql(u8, arg, "--live")) live = true else if (std.mem.eql(u8, arg, "--no-top")) top = false else if (std.mem.eql(u8, arg, "--unfocusable")) focusable = false else if (std.mem.eql(u8, arg, "--borderless")) borderless = true else if (std.mem.eql(u8, arg, "--click-through")) click_through = true else if (std.mem.eql(u8, arg, "--position") and i + 2 < args.len) {
            position = .{ .x = try std.fmt.parseInt(c_int, args[i + 1], 10), .y = try std.fmt.parseInt(c_int, args[i + 2], 10) };
            i += 2;
        } else if (i + 1 < args.len and (std.mem.eql(u8, arg, "--replay") or std.mem.eql(u8, arg, "--session-replay") or std.mem.eql(u8, arg, "--device-path") or std.mem.eql(u8, arg, "--capture") or std.mem.eql(u8, arg, "--capture-ms") or std.mem.eql(u8, arg, "--opacity"))) {
            i += 1;
            if (std.mem.eql(u8, arg, "--replay")) replay = args[i] else if (std.mem.eql(u8, arg, "--session-replay")) timed_replay = args[i] else if (std.mem.eql(u8, arg, "--device-path")) path = args[i] else if (std.mem.eql(u8, arg, "--capture")) capture_path = args[i] else if (std.mem.eql(u8, arg, "--capture-ms")) capture_ms = try std.fmt.parseInt(u64, args[i], 10) else opacity = try std.fmt.parseFloat(f32, args[i]);
        } else return error.Usage;
    }
    if (live and (smoke or replay != null or timed_replay != null) or (replay != null and timed_replay != null) or (!live and (path != null or capture_path != null))) return error.IncompatibleModes;
    if (tray_check and (live or smoke or replay != null or timed_replay != null or capture_path != null)) return error.IncompatibleModes;
    if (!std.math.isFinite(opacity) or opacity < 0.1 or opacity > 1 or capture_ms == 0 or capture_ms > 300_000) return error.InvalidConfiguration;
    // SDL 3.4 defaults to game-controller collections and filters our vendor page.
    // Selection below still opens only the exact FAFA/00F0/FF31/0074 collection.
    if (live and !sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
    if (verify_running) {
        if (capture_path != null) return error.IncompatibleModes;
        var verification_seed: u32 = undefined;
        try init.io.randomSecure(std.mem.asBytes(&verification_seed));
        var verifier = try adapter.Driver(Native).init(.{ .io = init.io }, keymap.identity, verification_seed, path);
        defer verifier.disconnect(verifier.transport.now());
        const deadline = verifier.transport.now() +| 10_000;
        while (verifier.transport.now() < deadline) {
            verifier.poll(verifier.transport.now());
            if (verifier.status == .multiple_devices) return error.AmbiguousRunningDevices;
            if (verifier.session.phase == .incompatible) return error.RunningIdentityMismatch;
            if (verifier.session.phase == .live and !verifier.session.stale) {
                std.log.info("Verified running board/profile/layout identity and coherent snapshot: lk7/danish digest={x}", .{keymap.identity.digest});
                return;
            }
            try std.Io.sleep(init.io, .fromMilliseconds(10), .awake);
        }
        std.log.err("Running verification timed out: connection={s}, phase={s}, transport={s}", .{ @tagName(verifier.status), @tagName(verifier.session.phase), if (verifier.transport_error) |err| @errorName(err) else "none" });
        return error.RunningVerificationTimeout;
    }
    var state = try companion.State.init(.{ .key_count = keymap.key_count, .layer_count = keymap.keymap.len });
    var replay_stale = false;
    var log = LogComponent{};
    if (replay) |file| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, file, init.arena.allocator(), .limited(64 * 1024 * 1024));
        if (bytes.len % protocol.report_size != 0) return error.IncompleteReport;
        var offset: usize = 0;
        while (offset < bytes.len) : (offset += protocol.report_size) try receive(&state, &log, init.io, bytes[offset..][0..protocol.report_size]);
    }
    if (timed_replay) |file| {
        // Allow an EOF probe at the exact recorder capacity; replay enforces
        // the logical size limit before accepting any records.
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, file, init.arena.allocator(), .limited(capture.max_bytes + 1));
        const session = try capture.replay(bytes, keymap.identity);
        state = session.state;
        replay_stale = session.stale;
    }
    var backend = try SDLBackend.initWindow(.{ .io = init.io, .environ_map = init.environ_map, .size = .{ .w = 760, .h = 370 }, .min_size = .{ .w = 340, .h = 220 }, .title = "Zigmkay LK7 Overlay", .vsync = true, .persist_window_geometry = false });
    defer backend.deinit();
    var window_warning = click_through;
    if (!sdl.SDL_SetWindowAlwaysOnTop(backend.window, top)) window_warning = true;
    if (!sdl.SDL_SetWindowOpacity(backend.window, opacity)) window_warning = true;
    if (!sdl.SDL_SetWindowFocusable(backend.window, focusable)) window_warning = true;
    if (!sdl.SDL_SetWindowBordered(backend.window, !borderless)) window_warning = true;
    if (position) |pos| if (!sdl.SDL_SetWindowPosition(backend.window, pos.x, pos.y)) {
        window_warning = true;
    };
    var open = true;
    var win = try dvui.Window.init(@src(), init.gpa, backend.backend(), .{ .theme = dvui.Theme.builtin.adwaita_dark, .open_flag = &open });
    defer win.deinit();
    var source = input.Source.init();
    defer source.deinit();
    var labels = try cache.buildLabelCache(init.gpa, &source);
    defer labels.deinit();
    var transferred_profile: ?@import("keymap-project").snapshot.Loaded = null;
    defer if (transferred_profile) |*profile| profile.deinit();
    var seed: u32 = 0;
    if (live) try init.io.randomSecure(std.mem.asBytes(&seed));
    var driver = try adapter.Driver(Native).init(.{ .io = init.io }, keymap.identity, seed, path);
    var monitoring = live;
    defer driver.transport.close();
    var recording: ?capture.Recorder = if (capture_path != null) try capture.Recorder.init(init.gpa) else null;
    defer if (recording) |*recorder| recorder.deinit(init.gpa);
    const start = driver.transport.now();
    const capture_end = start +| capture_ms;
    if (recording) |*recorder| driver.recording = recorder;
    var capture_saved = false;
    var capture_error: ?anyerror = null;
    var refresh_at: u64 = 0;
    var interrupted = false;
    var frames: usize = 0;
    var show_log = false;
    var visible = true;
    var tray = desktop.NativeTray.init(.{ .allocator = init.gpa }, !smoke and capture_path == null);
    defer tray.deinit();
    var life = desktop.Lifecycle{ .resident = tray.installed, .companion_visible = !editor_start, .editor_visible = editor_start or editor_smoke };
    tray.update(.{ .companion_visible = life.companion_visible });
    if (tray_check and !tray.installed) return error.TrayCheckRequiresNativeTray;
    life.resident = tray.installed;
    if (!life.companion_visible) _ = sdl.SDL_HideWindow(backend.window);
    var editor_open = editor_smoke or editor_start;
    var editor: ?@import("editor/main.zig").Editor = if (editor_open) try @import("editor/main.zig").Editor.init(init, editor_smoke) else null;
    defer if (editor) |*draft| draft.deinit();
    if (editor) |*draft| {
        draft.light = editor_light;
        if (editor_start and live) draft.live_requested = true;
        if (editor_practice) {
            draft.main_view = .try_it_out;
            draft.try_mode = .typing_test;
        }
    }
    var quit_pending = false;
    var check = @import("tray_check.zig").Check{};
    while (life.keepRunning()) {
        try win.begin(win.beginWait(interrupted));
        if (frames == 0) try @import("editor/fonts.zig").install(init.gpa, init.io);
        if (editor) |*draft| draft.tray_managed = life.resident;
        try @import("editor/events.zig").pump(&backend, &win, DesktopEvents{ .life = &life, .companion_id = sdl.SDL_GetWindowID(backend.window), .editor = if (editor) |*draft| draft else null });
        if (tray.poll()) |action| {
            life.action(action);
            if (action == .open_editor and editor != null) {
                _ = sdl.SDL_ShowWindow(editor.?.backend_window.?);
                _ = sdl.SDL_RaiseWindow(editor.?.backend_window.?);
            }
        }
        if (life.quit_requested) {
            life.cancelQuit();
            if (editor) |*draft| {
                life.editor_visible = true;
                if (draft.backend_window) |native_window| {
                    _ = sdl.SDL_ShowWindow(native_window);
                    _ = sdl.SDL_RaiseWindow(native_window);
                }
                try draft.requestQuit();
                quit_pending = draft.should_close or draft.pending != null or draft.close_requested;
            } else life.finishQuit();
        }
        if (life.editor_visible and editor == null) editor = try @import("editor/main.zig").Editor.init(init, tray_check);
        editor_open = if (life.resident) editor != null else life.editor_visible;
        const now = driver.transport.now();
        if (editor) |*draft| if (draft.live_requested and !draft.fixture) {
            draft.live_requested = false;
            if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
            // Freeze the selected layout before connecting, then require its
            // complete device identity before publishing any key positions.
            const profile = try @import("keymap-project").snapshot.clone(init.gpa, draft.model.current.snapshot);
            errdefer {
                var owned = profile;
                owned.deinit();
            }
            const expected = try @import("keymap-project").snapshot.identity(init.gpa, profile.snapshot, @import("keymap-project").profiles.board);
            var replacement = try cache.buildProjectCache(init.gpa, &source, profile.snapshot.document);
            errdefer replacement.deinit();
            try init.io.randomSecure(std.mem.asBytes(&seed));
            const new_driver = try adapter.Driver(Native).init(.{ .io = init.io }, expected, seed, path);
            driver.disconnect(now);
            if (transferred_profile) |*old| old.deinit();
            transferred_profile = profile;
            labels.deinit();
            labels = replacement;
            driver = new_driver;
            monitoring = true;
        };
        // Preserve the editor's existing post-transfer identity verification.
        // Only an explicitly completed flash enables this path in offline mode.
        if (!monitoring) if (editor) |*draft| {
            if (!draft.fixture and draft.firmware.expectedIdentity() != null) {
                if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
                try init.io.randomSecure(std.mem.asBytes(&seed));
                driver = try adapter.Driver(Native).init(.{ .io = init.io }, draft.firmware.expectedIdentity().?, seed, path);
                monitoring = true;
            }
        };
        if (recording) |*recorder| {
            if (now >= capture_end or recorder.full) driver.recording = null;
        }
        if (now >= refresh_at) {
            refresh_at = now +| 500;
            if (source.refresh()) {
                var replacement = if (transferred_profile) |profile| try cache.buildProjectCache(init.gpa, &source, profile.snapshot.document) else try cache.buildLabelCache(init.gpa, &source);
                labels.deinit();
                labels = replacement;
                replacement = undefined;
            }
        }
        if (monitoring and !(if (editor) |*draft| draft.bootloaderBusy() else false)) {
            driver.poll(now);
            state = driver.session.state;
            for (driver.key_events[0..driver.key_event_count]) |event| log.record(event, @intCast(now));
            for (driver.signals[0..driver.signal_count]) |signal| switch (signal) {
                .log_toggle => show_log = !show_log,
                .overlay_toggle => visible = !visible,
                .shutdown => life.action(.quit),
            };
        }
        if (recording) |*recorder| {
            if (!capture_saved and (now >= capture_end or recorder.full or !open)) {
                driver.recording = null;
                std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = capture_path.?, .data = recorder.encoded() }) catch |err| {
                    capture_error = err;
                };
                capture_saved = true;
            }
        }
        const stale = if (monitoring) driver.session.stale else replay_stale;
        const phase_label = if (driver.session.phase == .synchronizing and !stale) "live" else @tagName(driver.session.phase);
        dvui.label(@src(), "LK7 / {s} · layer {d} · mods {X:0>2} · {s}{s}", .{ std.mem.sliceTo(if (monitoring) &driver.session.expected.profile_id else &keymap.identity.profile_id, 0), state.highest_layer, state.modifiers.toByte(), if (monitoring) phase_label else "offline", if (stale) " / STALE" else "" }, .{});
        dvui.label(@src(), "Input source: {s} / layout: {s}", .{ source.id(), source.layoutId() }, .{});
        if (monitoring and driver.status != .connected) {
            dvui.label(@src(), "Connection: {s}; select --device-path for multiple devices", .{@tagName(driver.status)}, .{});
            for (0..driver.transport.path_count) |n| dvui.label(@src(), "{s}", .{driver.transport.paths[n][0..driver.transport.path_lengths[n]]}, .{ .id_extra = n });
        }
        if (monitoring and driver.session.phase == .incompatible) dvui.label(@src(), "Device board/profile/version differs. Build matching firmware; reconnect to retry.", .{}, .{});
        if (monitoring) {
            if (driver.session.last_error) |err| dvui.label(@src(), "Last protocol diagnostic: {s}", .{@errorName(err)}, .{});
            if (driver.transport_error) |err| dvui.label(@src(), "Transport: {s}; retrying once per second", .{@errorName(err)}, .{});
        }
        if (window_warning) dvui.label(@src(), "Window fallback: click-through unavailable; requested flags need macOS verification.", .{}, .{});
        if (recording != null) dvui.label(@src(), "Capture: {s}", .{if (capture_saved) "stopped" else "recording (bounded test session)"}, .{});
        if (capture_error) |err| dvui.label(@src(), "Capture save failed: {s}", .{@errorName(err)}, .{});
        _ = dvui.checkbox(@src(), &show_log, "Event log", .{});
        if (monitoring and dvui.button(@src(), "Reconnect", .{}, .{})) driver.disconnect(now);
        {
            const controls = dvui.box(@src(), .{ .dir = .horizontal }, .{});
            defer controls.deinit();
            if (dvui.button(@src(), "Close", .{}, .{})) open = false;
            if (!open and editor_open) _ = sdl.SDL_HideWindow(backend.window);
            if (dvui.button(@src(), "Open editor", .{}, .{})) {
                if (editor == null) editor = try @import("editor/main.zig").Editor.init(init, tray_check);
                editor_open = true;
                life.editor_visible = true;
            }
        }
        const bounds = win.data().rect;
        const extra_rows: usize = (if (monitoring and driver.status != .connected) @as(usize, 1) + driver.transport.path_count else 0) + @intFromBool(monitoring and driver.session.phase == .incompatible) + @intFromBool(monitoring and driver.session.last_error != null) + @intFromBool(monitoring and driver.transport_error != null) + @intFromBool(window_warning) + @intFromBool(recording != null) + @intFromBool(capture_error != null);
        const header_height: f32 = 140 + @as(f32, @floatFromInt(extra_rows)) * 24;
        if (visible and (!monitoring or (driver.session.phase != .incompatible and driver.session.phase != .negotiating))) try layout.draw(&labels, state.highest_layer, &state.pressed, state.modifiers, stale, .{ .x = 8, .y = header_height, .w = @max(0, bounds.w - 16), .h = @max(0, bounds.h - header_height - 8) });
        if (show_log) try log.draw(&labels, bounds.w / 2, 140, 0.8);
        if (editor_open) {
            const editor_geometry = @import("editor/geometry.zig");
            const child = dvui.osWindow(@src(), .{ .title = "Zigmkay — LK7 Keymap Editor", .size = .{ .w = editor_geometry.initial.w, .h = editor_geometry.initial.h }, .min_size = .{ .w = editor_geometry.minimum.w, .h = editor_geometry.minimum.h } }, .{ .open_flag = &editor_open, .theme = if (editor.?.light) dvui.Theme.builtin.adwaita_light else dvui.Theme.builtin.adwaita_dark });
            defer child.deinit();
            switch (child.inner) {
                .os => |os| {
                    editor.?.backend_window = os.backend.window;
                    editor.?.window_id = sdl.SDL_GetWindowID(os.backend.window);
                    if (sdl.SDL_GetWindowOpacity(os.backend.window) != 1 or sdl.SDL_GetWindowFlags(os.backend.window) & sdl.SDL_WINDOW_ALWAYS_ON_TOP != 0) return error.EditorWindowFlagsInherited;
                },
                else => return error.NativeEditorWindowUnavailable,
            }
            if (monitoring) {
                if (editor.?.firmware.expectedIdentity()) |expected| {
                    if (!std.meta.eql(expected, driver.session.expected)) {
                        const profile = try @import("keymap-project").snapshot.clone(init.gpa, editor.?.firmware.frozen.?.snapshot);
                        errdefer {
                            var owned = profile;
                            owned.deinit();
                        }
                        const replacement = try cache.buildProjectCache(init.gpa, &source, profile.snapshot.document);
                        if (transferred_profile) |*old| old.deinit();
                        transferred_profile = profile;
                        labels.deinit();
                        labels = replacement;
                        driver.disconnect(now);
                        driver.session = try @import("companion-model").Session.init(expected);
                        driver.retry_at = now;
                    }
                    editor.?.firmware.observeRunning(if (driver.session.phase == .live and !driver.session.stale) driver.session.expected else null, driver.session.phase == .live and !driver.session.stale, now);
                }
                editor.?.connection_text = if (driver.session.phase == .incompatible) "Device identity differs" else if (driver.status != .connected) "No device · draft only" else if (driver.session.phase != .live or driver.session.stale) "Device · verifying" else blk: {
                    const draft_identity = try @import("keymap-project").snapshot.identity(init.gpa, editor.?.model.current.snapshot, @import("keymap-project").profiles.board);
                    break :blk if (std.meta.eql(draft_identity, driver.session.expected)) "Live · draft matches" else "Live · draft differs";
                };
            }
            const practice_live = monitoring and driver.session.phase == .live;
            editor.?.practice_live_labels = if (practice_live) &labels else null;
            editor.?.practice_live_state = if (practice_live) state else null;
            editor.?.practice_live_profile = driver.session.expected.profile_id;
            editor.?.practice_live_stale = !monitoring or stale or driver.session.phase != .live;
            if (tray_check) try check.beforeEditorDraw(frames);
            editor.?.draw() catch |err| editor.?.report(err);
            if (editor.?.bootloader_requested) {
                if (monitoring) driver.disconnect(now);
            }
            editor.?.pollBootloader(path);
            if (editor.?.hide_requested) {
                life.editor_visible = false;
                editor.?.hide_requested = false;
            }
            if (quit_pending) {
                if (editor.?.should_close) life.finishQuit() else if (editor.?.pending == null and !editor.?.close_requested) quit_pending = false;
            } else if (editor.?.should_close) {
                editor.?.pauseHidden();
                life.editor_visible = false;
                if (life.resident) editor.?.should_close = false else editor_open = false;
            }
            if (life.resident and !life.editor_visible) _ = sdl.SDL_HideWindow(editor.?.backend_window.?);
            if (life.editor_visible and sdl.SDL_GetWindowFlags(editor.?.backend_window.?) & sdl.SDL_WINDOW_HIDDEN != 0) {
                _ = sdl.SDL_ShowWindow(editor.?.backend_window.?);
                _ = sdl.SDL_RaiseWindow(editor.?.backend_window.?);
            }
        }
        const end_micros = try win.end(.{});
        if (!open) {
            life.companion_visible = false;
            if (life.resident) open = true;
        }
        if (!editor_open) life.editor_visible = false;
        if (life.companion_visible) {
            if (sdl.SDL_GetWindowFlags(backend.window) & sdl.SDL_WINDOW_HIDDEN != 0) {
                _ = sdl.SDL_ShowWindow(backend.window);
                _ = sdl.SDL_RaiseWindow(backend.window);
            }
        } else _ = sdl.SDL_HideWindow(backend.window);
        tray.update(.{ .live_mode = monitoring, .companion_visible = life.companion_visible, .status = if (!monitoring) .offline else if (driver.session.phase == .incompatible) .incompatible else if (driver.status == .searching) .connecting else if (driver.status != .connected) .disconnected else if (driver.session.stale) .stale else if (driver.session.phase == .live) .live else .connecting });
        if (life.resident and !tray.installed) {
            life.resident = false;
            life.companion_visible = true;
            _ = sdl.SDL_ShowWindow(backend.window);
            if (editor) |*draft| {
                life.editor_visible = true;
                editor_open = true;
                if (draft.backend_window) |native_window| _ = sdl.SDL_ShowWindow(native_window);
            }
        }
        if (!editor_open and editor != null) {
            editor.?.deinit();
            editor = null;
        }
        if (tray_check) try check.afterFrame(frames, &life, &tray, &backend, if (editor) |*draft| draft else null);
        frames += 1;
        if (smoke and frames == 3) break;
        interrupted = try backend.waitEventTimeout(if (smoke or (monitoring and (life.companion_visible or life.editor_visible))) 16_000 else if (!life.companion_visible and !life.editor_visible) 100_000 else @min(100_000, win.waitTime(end_micros)));
    }
    if (recording) |*recorder| if (!capture_saved) {
        driver.recording = null;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = capture_path.?, .data = recorder.encoded() });
    };
}
test {
    _ = @import("editor/model.zig");
    _ = @import("editor/main.zig");
    _ = @import("editor/testing.zig");
    std.mem.doNotOptimizeAway(&main);
    _ = adapter;
    _ = capture;
    _ = input;
    _ = layout;
    _ = keys;
    _ = cache;
}

fn captureControls(recorder: *capture.Recorder, actions: companion.Actions, now: u64) !void {
    for (actions.slice()) |action| if (action == .send) {
        const bytes = adapter.nativeWrite(try protocol.encodePacket(action.send, keymap.identity.dimensions, .host_to_device));
        recorder.add(.send, now, &bytes);
    };
}
test "timed LK7 GUI fixture remains hardware free and retains held key" {
    var recorder = try capture.Recorder.init(std.testing.allocator);
    defer recorder.deinit(std.testing.allocator);
    var session = try companion.Session.init(keymap.identity);
    recorder.nonce(.connect, 0, 123);
    try captureControls(&recorder, try session.connect(0, 123), 0);
    for (try protocol.identityPackets(keymap.identity, 123, session.request)) |packet| {
        const bytes = try protocol.encodePacket(packet, keymap.identity.dimensions, .device_to_host);
        recorder.add(.receive, 1, &bytes);
        try captureControls(&recorder, session.receive(&bytes, 1), 1);
    }
    var snapshot = protocol.Snapshot{ .pressed = @splat(0), .active_layers = 1, .highest_layer = 0, .modifiers = .{} };
    snapshot.pressed[0] = 1;
    for (try protocol.snapshotPackets(snapshot, keymap.identity.dimensions, 123, session.request, 0)) |packet| {
        const bytes = try protocol.encodePacket(packet, keymap.identity.dimensions, .device_to_host);
        recorder.add(.receive, 2, &bytes);
        try captureControls(&recorder, session.receive(&bytes, 2), 2);
    }
    const result = try capture.replay(recorder.encoded(), keymap.identity);
    try std.testing.expect(result.phase == .live and !result.stale and result.state.pressed[0]);
    try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = ".zig-cache/lk7-overlay-timed-fixture.bin", .data = recorder.encoded() });
}
