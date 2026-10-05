const std = @import("std");
const dvui = @import("dvui");
const Backend = @import("sdl-backend");
const sdl = Backend.c;
const p = @import("keymap-project");
const Model = @import("model.zig").Model;
const geometry = @import("geometry.zig");
const labels = @import("labels.zig");
const physical = @import("lk7-physical");
const input = @import("../input_source.zig");
const palette = @import("../components/key.zig").layer_colors;
const forms = @import("forms.zig");
const Testing = @import("testing.zig").Controller;
const Firmware = @import("firmware.zig").Controller;
const Text = @import("text.zig").Text;
const dialog = @import("dialog.zig");
const jobs = @import("companion-jobs");
const scenario = @import("scenario.zig");
const fonts = @import("fonts.zig");

const ui = @import("ui.zig");
pub const Theme = ui.Theme;
const options = ui.options;
const color = ui.color;
const rect = ui.rect;
const label = ui.label;
const button = ui.button;
const panel = ui.panel;

pub const Editor = struct {
    model: Model,
    io: std.Io,
    gpa: std.mem.Allocator,
    light: bool = false,
    content_scale: f32 = 1,
    fixture: bool = false,
    connection_text: []const u8 = "Offline · No device",
    source: ?input.Source = null,
    shift: bool = false,
    option: bool = false,
    extend: bool = false,
    canvas_focus: bool = true,
    fonts_loaded: bool = false,
    advanced: bool = false,
    action_draft: forms.Draft = .{},
    testing: Testing,
    firmware: Firmware,
    firmware_open: bool = false,
    bootloader_requested: bool = false,
    bootloader_available: bool = false,
    bootloader_status: []const u8 = "Physical recovery: hold positions 0 + 4 to enter BOOTSEL.",
    recovery_volume: [1024]u8 = @splat(0),
    recovery_manual: bool = false,
    flash_confirmed: bool = false,
    text: Text,
    test_start: i64 = 0,
    last_text_sequence: ?u64 = null,
    test_details: bool = false,
    window_id: u32 = 0,
    view: usize = 0,
    combo_open: bool = false,
    combo_index: ?usize = null,
    combo_keys: [2]usize = .{ 0, 4 },
    combo_layer: usize = 0,
    combo_timeout: u16 = 40,
    combo_draft: forms.Draft = .{ .mode = 2, .tap = .{ .key_press = .{ .tap_keycode = 4 } } },
    rename_buffer: [129]u8 = @splat(0),
    search: [128]u8 = @splat(0),
    picker_open: bool = false,
    profile_choice: usize = 2,
    diagnostic: [512]u8 = @splat(0),
    project_path: [1024]u8 = @splat(0),
    export_path: [1024]u8 = @splat(0),
    exported_id: ?[32]u8 = null,
    paths_open: bool = false,
    callback_open: bool = false,
    callback_root: [1024]u8 = @splat(0),
    callback_entry: [241]u8 = @splat(0),
    callback_id: u8 = 1,
    callback_ids: [256]u8 = .{'1'} ++ @as([255]u8, @splat(0)),
    callback_state: enum { none, snapshot, changed, missing, failed } = .none,
    callback_index: usize = 0,
    dialog_target: enum { project, exported, callback } = .project,
    backend_window: ?*sdl.SDL_Window = null,
    external_job: ?*jobs.Job = null,
    close_requested: bool = false,
    should_close: bool = false,
    recovery_id: [32]u8 = @splat(0),
    recovery_at: i64 = 0,
    overlay_open: bool = false,
    pub fn init(process: std.process.Init, fixture: bool) !Editor {
        const root = try std.Io.Dir.cwd().realPathFileAlloc(process.io, ".", process.gpa);
        defer process.gpa.free(root);
        var self = Editor{ .model = try Model.init(process.gpa, .eurkey), .io = process.io, .gpa = process.gpa, .fixture = fixture, .testing = try Testing.init(process.gpa, process.io, root), .firmware = try Firmware.init(process.gpa, process.io, root), .text = Text.init(fixture) };
        if (!fixture) self.source = input.Source.init();
        if (fixture) {
            try @import("fixture.zig").setup(&self.model);
            self.connection_text = "Fixture · profile match";
            self.option = true;
            try self.text.insert("Hello, Grüß dich!");
        }
        self.syncRename();
        return self;
    }
    pub fn deinit(self: *Editor) void {
        if (self.external_job) |job| {
            job.deinit();
            self.gpa.destroy(job);
        }
        self.testing.deinit();
        self.firmware.deinit();
        self.text.deinit();
        self.model.deinit();
        if (self.source) |*source| source.deinit();
    }
    pub fn syncRename(self: *Editor) void {
        self.rename_buffer = @splat(0);
        const name = self.model.document().layers[self.model.layer].name;
        @memcpy(self.rename_buffer[0..name.len], name);
    }
    pub fn report(self: *Editor, err: anyerror) void {
        self.diagnostic = @splat(0);
        _ = std.fmt.bufPrint(&self.diagnostic, "{s}", .{@errorName(err)}) catch {};
    }
    pub fn raw(self: *Editor, event: sdl.SDL_Event) !bool {
        if ((event.type == sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID == self.window_id) or event.type == sdl.SDL_EVENT_QUIT) {
            if (self.firmware.state == .transferring) {
                self.report(error.TransferInProgress);
                return true;
            }
            if (dialog.active()) {
                self.report(error.CloseNativeDialogFirst);
                return true;
            }
            if (self.model.dirty()) {
                self.close_requested = true;
                return true;
            }
        }
        if (event.type == sdl.SDL_EVENT_WINDOW_FOCUS_LOST and event.window.windowID == self.window_id) {
            self.testing.stop();
            self.text.reset();
        }
        if (event.type == sdl.SDL_EVENT_KEY_DOWN or event.type == sdl.SDL_EVENT_KEY_UP) self.extend = event.key.mod & sdl.SDL_KMOD_SHIFT != 0;
        if (self.testing.state == .running) {
            if (event.type == sdl.SDL_EVENT_TEXT_INPUT and event.text.windowID == self.window_id) return true;
            if ((event.type == sdl.SDL_EVENT_KEY_DOWN or event.type == sdl.SDL_EVENT_KEY_UP) and event.key.windowID == self.window_id) {
                const mapped = [_]u8{ 20, 26, 8, 21, 23, 28, 24, 12, 18, 19, 4, 22, 7, 9, 10, 11, 13, 14, 15, 51, 29, 27, 6, 25, 5, 17, 16, 54, 55, 56, 44, 40, 42, 43 };
                for (mapped, 0..) |scancode, index| if (event.key.scancode == scancode) {
                    if (!event.key.repeat) self.testing.input(if (event.type == sdl.SDL_EVENT_KEY_DOWN) .{ .key_down = @intCast(index) } else .{ .key_up = @intCast(index) }, self.testTime()) catch |err| self.report(err);
                    return true;
                };
            }
        } else if (self.canvas_focus and event.type == sdl.SDL_EVENT_KEY_DOWN and event.key.windowID == self.window_id and !event.key.repeat and !self.paths_open and !self.advanced and !self.picker_open and !self.combo_open and !self.callback_open) {
            if (event.key.scancode == sdl.SDL_SCANCODE_LEFT or event.key.scancode == sdl.SDL_SCANCODE_RIGHT) {
                self.model.select((self.model.primary + (if (event.key.scancode == sdl.SDL_SCANCODE_RIGHT) @as(usize, 1) else 33)) % 34, self.extend);
                return true;
            }
            if (event.key.mod & (sdl.SDL_KMOD_GUI | sdl.SDL_KMOD_CTRL) != 0) switch (event.key.scancode) {
                sdl.SDL_SCANCODE_Z => {
                    if (self.extend) try self.model.redo() else try self.model.undo();
                    return true;
                },
                sdl.SDL_SCANCODE_C => {
                    self.model.copy();
                    return true;
                },
                sdl.SDL_SCANCODE_V => {
                    try self.model.paste();
                    return true;
                },
                else => {},
            };
        }
        return false;
    }
    pub fn testTime(self: *Editor) u64 {
        return @max(self.testing.time_us, @as(u64, @intCast(@max(0, std.Io.Clock.awake.now(self.io).toMicroseconds() - self.test_start))));
    }
    pub fn openAction(self: *Editor) void {
        self.action_draft = forms.Draft.from(self.model.action());
        self.advanced = true;
    }
    pub fn draw(self: *Editor) !void {
        if (!self.fonts_loaded) {
            try fonts.install(self.gpa, self.io);
            self.fonts_loaded = true;
        }
        self.canvas_focus = dvui.focusedWidgetId() == null;
        if (dialog.poll()) |result| {
            if (result) |path| {
                if (path[0] != 0) switch (self.dialog_target) {
                    .project => self.project_path = path,
                    .exported => self.export_path = path,
                    .callback => self.callback_root = path,
                };
            } else |err| self.report(err);
        }
        if (self.external_job) |job| if (job.poll()) |result| {
            self.external_job = null;
            defer {
                job.deinit();
                self.gpa.destroy(job);
            }
            if (result) |value| {
                var owned = value;
                defer owned.deinit(self.gpa);
                if (!owned.successful()) self.report(error.ExternalEditorFailed);
            } else |err| self.report(err);
        };
        const now: i64 = @intCast(std.Io.Clock.awake.now(self.io).toMilliseconds());
        if (!self.fixture and self.model.dirty() and now >= self.recovery_at) {
            self.recovery_at = now + 1000;
            const current_id = try self.model.id();
            if (!std.mem.eql(u8, &current_id, &self.recovery_id)) {
                self.recover() catch |err| self.report(err);
                self.recovery_id = current_id;
            }
        }
        self.testing.poll(try self.model.id());
        self.firmware.poll(try self.model.id());
        if (self.callback_state == .changed or self.callback_state == .missing) self.firmware.invalidateExternalSources();
        if (self.text.refresh()) {
            self.testing.stop();
            self.text.reset();
        }
        if (self.testing.last) |output| if (self.last_text_sequence != output.sequence) {
            self.last_text_sequence = output.sequence;
            self.text.output(output.commands) catch |err| self.report(err);
        };
        if (self.testing.state == .running and self.testing.queue.items.len < 32) {
            var held = false;
            for (self.testing.pressed) |pressed| held = held or pressed;
            if (held) self.testing.input(.advance, self.testTime()) catch |err| self.report(err);
        }
        const t = Theme.get(self.light);
        const current_window = dvui.currentWindow();
        const available = current_window.backend.windowSize();
        const system_scale = current_window.backend.contentScale();
        self.content_scale = geometry.fitScale(available.w / system_scale, available.h / system_scale);
        current_window.snap_to_pixels = self.content_scale == 1;
        // Window zoom also covers floating dialogs, menus and input transforms.
        // DVUI applies it at the next frame boundary after a native resize.
        if (current_window.content_scale != self.content_scale) {
            current_window.content_scale = self.content_scale;
            dvui.refresh(null, @src(), null);
        }
        const canvas = dvui.box(@src(), .{}, .{ .min_size_content = .{ .w = 1536, .h = 1024 }, .padding = .{}, .margin = .{}, .background = true, .color_fill = .{ .color = t.bg } });
        defer canvas.deinit();
        try self.toolbar(t);
        try self.sidebar(t);
        try self.keyboard(t);
        try self.inspector(t);
        self.host(t);
        try self.bottom(t);
        if (self.paths_open) try self.paths(t);
        if (self.advanced) try self.actionForm(t);
        if (self.test_details) try self.testDrawer(t);
        if (self.firmware_open) try self.firmwareDrawer(t);
        if (self.callback_open) try self.callbackDrawer(t);
        if (self.combo_open) try self.comboDrawer(t);
        if (self.picker_open) try self.picker(t);
        if (self.close_requested) {
            const window = dvui.floatingWindow(@src(), .{ .modal = true }, .{ .rect = .{ .x = 480, .y = 340, .w = 540, .h = 230 }, .padding = .all(20) });
            defer window.deinit();
            dvui.label(@src(), "Unsaved draft · Save before closing?", .{}, .{});
            if (dvui.button(@src(), "Save and close", .{}, .{})) {
                self.save() catch |err| self.report(err);
                if (!self.model.dirty()) self.should_close = true;
            }
            if (dvui.button(@src(), "Close (recoverable draft retained)", .{}, .{})) {
                try self.recover();
                self.should_close = true;
            }
            if (dvui.button(@src(), "Keep editing", .{}, .{})) self.close_requested = false;
        }
        if (self.overlay_open) {
            const child = dvui.osWindow(@src(), .{ .title = "Zigmkay LK7 Overlay — offline", .size = .{ .w = 760, .h = 370 }, .min_size = .{ .w = 340, .h = 220 } }, .{ .open_flag = &self.overlay_open });
            defer child.deinit();
            dvui.label(@src(), "LK7 / offline · no verified device profile", .{}, .{});
            _ = @import("../components/layout.zig");
            dvui.label(@src(), "The live overlay is available separately through --live.", .{}, .{});
        }
    }
    fn toolbar(self: *Editor, t: Theme) !void {
        const box = panel(t, .toolbar);
        defer box.deinit();
        label(t, "Zigmkay", .{ .x = 20, .y = 21, .w = 140, .h = 30 }, 23);
        label(t, "Keyboard", .{ .x = 140, .y = 7, .w = 85, .h = 18 }, 11);
        var board_choice: usize = 0;
        _ = dvui.dropdown(@src(), &.{"LK7"}, .{ .choice = &board_choice }, .{}, options(t, .{ .x = 140, .y = 25, .w = 80, .h = 30 }, 13));
        label(t, self.connection_text, .{ .x = 230, .y = 25, .w = 165, .h = 25 }, 12);
        if (dvui.dropdown(@src(), &p.profiles.names, .{ .choice = &self.profile_choice }, .{}, options(t, .{ .x = 405, .y = 16, .w = 270, .h = 36 }, 14))) {
            var loaded = try p.profiles.create(self.gpa, @enumFromInt(self.profile_choice));
            defer loaded.deinit();
            try self.model.commit(loaded.snapshot);
            self.model.layer = 0;
            self.syncRename();
        }
        if (self.model.dirty()) label(t, "Unsaved", .{ .x = 686, .y = 27, .w = 85, .h = 23 }, 12);
        if (button(t, "Open / Export", "file.paths", .{ .x = 775, .y = 16, .w = 130, .h = 36 })) self.paths_open = true;
        if (button(t, "Undo", "edit.undo", .{ .x = 920, .y = 16, .w = 68, .h = 36 })) {
            try self.model.undo();
            self.syncRename();
        }
        if (button(t, "Redo", "edit.redo", .{ .x = 996, .y = 16, .w = 68, .h = 36 })) {
            try self.model.redo();
            self.syncRename();
        }
        if (button(t, "Save", "file.save", .{ .x = 1078, .y = 16, .w = 76, .h = 36 })) self.save() catch |err| self.report(err);
        if (button(t, "Build", "firmware.build", .{ .x = 1166, .y = 16, .w = 110, .h = 36 })) {
            self.firmware_open = true;
            self.flash_confirmed = false;
            if (!self.fixture) self.firmware.build(self.model.current.snapshot) catch |err| self.report(err);
        }
        if (button(t, "Flash", "firmware.inspect", .{ .x = 1288, .y = 16, .w = 110, .h = 36 })) self.firmware_open = true;
        if (button(t, if (self.light) "Dark" else "Light", "theme.toggle", .{ .x = 1410, .y = 16, .w = 100, .h = 36 })) self.light = !self.light;
    }
    fn sidebar(self: *Editor, t: Theme) !void {
        const box = panel(t, .sidebar);
        defer box.deinit();
        label(t, "Layers", .{ .x = 16, .y = 18, .w = 160, .h = 25 }, 19);
        if (button(t, "+", "layer.add", .{ .x = 196, .y = 13, .w = 36, .h = 33 })) {
            try self.model.addLayer(false);
            self.syncRename();
        }
        {
            const area = dvui.scrollArea(@src(), .{}, .{ .rect = .{ .x = 11, .y = 52, .w = 225, .h = 725 }, .padding = .{}, .margin = .{}, .background = false });
            defer area.deinit();
            const list = dvui.box(@src(), .{}, .{ .min_size_content = .{ .w = 224, .h = @as(f32, @floatFromInt(self.model.document().layers.len)) * 67 }, .padding = .{}, .background = false });
            defer list.deinit();
            for (self.model.document().layers, 0..) |layer, i| {
                const y = @as(f32, @floatFromInt(i)) * 67;
                const c = palette[i % palette.len];
                var opts = options(t, .{ .x = 0, .y = y, .w = 224, .h = 59 }, 15);
                opts.id_extra = i;
                opts.tag = try std.fmt.allocPrint(dvui.currentWindow().arena(), "layer.select.{d}", .{i});
                opts.background = true;
                opts.color_fill = .{ .color = if (self.model.layer == i) c else .{ .r = @intCast((@as(u16, t.panel.r) * 4 + c.r) / 5), .g = @intCast((@as(u16, t.panel.g) * 4 + c.g) / 5), .b = @intCast((@as(u16, t.panel.b) * 4 + c.b) / 5), .a = 255 } };
                opts.color_text = .{ .color = if (self.model.layer == i) color(0x10151C) else t.text };
                opts.border = .all(if (self.model.layer == i) 2 else 0);
                {
                    var background = opts;
                    background.id_extra = 1000 + i;
                    background.tag = null;
                    const card = dvui.box(@src(), .{}, background);
                    card.deinit();
                }
                opts.background = false;
                opts.border = .{};
                opts.rect.?.w = 168;
                if (dvui.button(@src(), "", .{}, opts)) {
                    self.model.layer = i;
                    self.syncRename();
                }
                var badge = options(t, .{ .x = 0, .y = y, .w = 48, .h = 59 }, 24);
                badge.color_fill = .{ .color = c };
                badge.color_text = .{ .color = color(0x10151C) };
                badge.background = true;
                badge.id_extra = i;
                dvui.label(@src(), "{d}", .{i}, badge);
                label(if (self.model.layer == i) Theme{ .bg = t.bg, .panel = t.panel, .control = t.control, .border = t.border, .text = color(0x10151C), .muted = t.muted } else t, layer.name, .{ .x = 59, .y = y + 20, .w = 115, .h = 24 }, 14);
                const dup = try std.fmt.allocPrint(dvui.currentWindow().arena(), "layer.duplicate.{d}", .{i});
                if (button(t, "+", dup, .{ .x = 170, .y = y + 14, .w = 25, .h = 30 })) {
                    self.model.layer = i;
                    self.model.addLayer(true) catch |err| self.report(err);
                    self.syncRename();
                }
                const del = try std.fmt.allocPrint(dvui.currentWindow().arena(), "layer.delete.{d}", .{i});
                if (button(t, "×", del, .{ .x = 197, .y = y + 14, .w = 25, .h = 30 })) {
                    self.model.deleteLayer(i) catch |err| self.report(err);
                    self.syncRename();
                }
            }
        }
        label(t, "Selected layer name", .{ .x = 16, .y = 804, .w = 220, .h = 23 }, 13);
        const rename = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.rename_buffer } }, options(t, .{ .x = 16, .y = 832, .w = 215, .h = 34 }, 13));
        const enter = rename.enter_pressed;
        rename.deinit();
        if (enter or button(t, "Rename", "layer.rename", .{ .x = 16, .y = 876, .w = 90, .h = 33 })) self.model.rename(std.mem.sliceTo(&self.rename_buffer, 0)) catch |err| self.report(err);
    }
    fn keyboard(self: *Editor, t: Theme) !void {
        const box = panel(t, .physical);
        defer box.deinit();
        label(t, "LK7 keymap", .{ .x = 20, .y = 20, .w = 180, .h = 25 }, 19);
        {
            var badge = options(t, .{ .x = 195, .y = 18, .w = 31, .h = 28 }, 16);
            badge.padding = .{};
            badge.background = true;
            badge.color_fill = .{ .color = palette[self.model.layer % palette.len] };
            badge.color_text = .{ .color = color(0x10151C) };
            dvui.labelNoFmt(@src(), try std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}", .{self.model.layer}), .{ .align_x = 0.5, .align_y = 0.5 }, badge);
        }
        label(t, self.model.document().layers[self.model.layer].name, .{ .x = 242, .y = 23, .w = 250, .h = 25 }, 16);
        if (dvui.dropdown(@src(), &.{ "Keys", "Combos", "Encoders" }, .{ .choice = &self.view }, .{}, options(t, .{ .x = 692, .y = 15, .w = 150, .h = 36 }, 13))) {
            if (self.view == 1) self.combo_open = true;
            if (self.view == 2) self.report(error.LK7HasNoEncoderActions);
        }
        label(t, "LEFT · 17 keys", .{ .x = 157, .y = 72, .w = 220, .h = 24 }, 13);
        label(t, "RIGHT · 17 keys", .{ .x = 562, .y = 72, .w = 220, .h = 24 }, 13);
        for (physical.keys) |key| {
            const x = 18 + key.x * 70;
            const y = 112 + key.y * 70;
            const tag = try std.fmt.allocPrint(dvui.currentWindow().arena(), "key.select.{d}", .{key.key_index});
            var opts = options(t, .{ .x = x, .y = y, .w = 65, .h = 65 }, 20);
            opts.id_extra = key.key_index;
            var data: dvui.WidgetData = undefined;
            opts.data_out = &data;
            opts.tag = tag;
            opts.background = true;
            opts.border = .all(if (self.model.selected[key.key_index]) 2 else 1);
            if (self.model.selected[key.key_index]) {
                opts.color_border = .{ .color = color(0x3296FF) };
                opts.color_fill = .{ .color = if (self.light) color(0xE2F0FF) else color(0x233B55) };
            }
            var buffer: [256]u8 = undefined;
            const direct = self.model.document().layers[self.model.layer].actions[key.key_index];
            var resolved = direct;
            if (resolved == null) {
                var layer_index = self.model.layer;
                while (layer_index > 0 and resolved == null) {
                    layer_index -= 1;
                    resolved = self.model.document().layers[layer_index].actions[key.key_index];
                }
            }
            const caption = labels.keycap(resolved, self.model.document(), &buffer);
            opts.padding = .all(2);
            opts.font = fonts.font(caption, if (std.mem.indexOfScalar(u8, caption, '\n') != null) 9 else if (caption.len > 9) 9 else if (caption.len >= 4) 13 else 20);
            if (dvui.button(@src(), caption, .{}, opts)) {
                self.model.select(key.key_index, self.extend);
                if (self.testing.state == .running) {
                    const time = self.testTime();
                    self.testing.input(.{ .key_down = key.key_index }, time) catch |err| self.report(err);
                    self.testing.input(.{ .key_up = key.key_index }, time + 1000) catch |err| self.report(err);
                }
            }
            if (dvui.focusedWidgetId() == data.id) self.canvas_focus = true;
            if (direct == null) label(t, "inherited", .{ .x = x + 7, .y = y + 56, .w = 55, .h = 8 }, 6);
        }
    }
    fn inspector(self: *Editor, t: Theme) !void {
        const box = panel(t, .inspector);
        defer box.deinit();
        label(t, "Key inspector", .{ .x = 18, .y = 20, .w = 185, .h = 25 }, 19);
        if (button(t, "Copy", "edit.copy", .{ .x = 218, .y = 15, .w = 60, .h = 34 })) self.model.copy();
        if (button(t, "Paste", "edit.paste", .{ .x = 285, .y = 15, .w = 65, .h = 34 })) try self.model.paste();
        var buffer: [64]u8 = undefined;
        _ = button(t, labels.action(self.model.action(), &buffer), "inspector.preview", .{ .x = 20, .y = 75, .w = 74, .h = 74 });
        label(t, "Physical key", .{ .x = 113, .y = 81, .w = 215, .h = 23 }, 14);
        label(t, p.profiles.key_ids[self.model.primary], .{ .x = 113, .y = 112, .w = 210, .h = 23 }, 13);
        const selected_key = physical.keys[self.model.primary];
        label(t, try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s} · {s} · index {d}/34", .{ @tagName(selected_key.hand), @tagName(selected_key.group), self.model.primary + 1 }), .{ .x = 113, .y = 138, .w = 225, .h = 22 }, 11);
        label(t, "Tap", .{ .x = 20, .y = 177, .w = 90, .h = 25 }, 15);
        if (button(t, labels.action(self.model.action(), &buffer), "inspector.tap", .{ .x = 114, .y = 168, .w = 230, .h = 39 })) self.openAction();
        label(t, "Hold", .{ .x = 20, .y = 229, .w = 90, .h = 25 }, 15);
        const draft = forms.Draft.from(self.model.action());
        const hold_caption = if (draft.mode == 3 or draft.mode == 4) labels.hold(draft.hold, self.model.document(), &buffer) else "No hold";
        if (button(t, hold_caption, "inspector.hold", .{ .x = 114, .y = 220, .w = 230, .h = 39 })) self.openAction();
        label(t, "Tapping term", .{ .x = 20, .y = 281, .w = 115, .h = 25 }, 12);
        var timing: u16 = if (self.model.action()) |a| switch (a) {
            .tap_hold => |th| th.tapping_term.ms,
            else => 180,
        } else 180;
        if (dvui.textEntryNumber(@src(), u16, .{ .value = &timing }, options(t, .{ .x = 150, .y = 272, .w = 143, .h = 38 }, 14)).changed) if (self.model.action()) |a| switch (a) {
            .tap_hold => |th| {
                var changed = th;
                changed.tapping_term.ms = timing;
                self.model.apply(.{ .tap_hold = changed }) catch |err| self.report(err);
            },
            else => {},
        };
        label(t, "ms", .{ .x = 308, .y = 281, .w = 35, .h = 25 }, 14);
        label(t, "Find an action", .{ .x = 20, .y = 339, .w = 310, .h = 25 }, 14);
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.search }, .placeholder = "Search keys, layers, media…" }, options(t, .{ .x = 20, .y = 371, .w = 325, .h = 38 }, 13));
        if (entry.text_changed and self.search[0] != 0) self.picker_open = true;
        entry.deinit();
    }
    fn host(self: *Editor, t: Theme) void {
        const box = panel(t, .os);
        defer box.deinit();
        label(t, "OS keyboard", .{ .x = 20, .y = 18, .w = 205, .h = 25 }, 19);
        label(t, if (self.source) |*source| source.id() else "EurKEY fixture · ANSI", .{ .x = 225, .y = 23, .w = 570, .h = 25 }, 13);
        label(t, "Show characters with modifiers", .{ .x = 811, .y = 23, .w = 265, .h = 25 }, 12);
        var shift_theme = t;
        var option_theme = t;
        if (self.shift) {
            shift_theme.control = color(0x126AFF);
            shift_theme.text = color(0xFFFFFF);
        }
        if (self.option) {
            option_theme.control = color(0x126AFF);
            option_theme.text = color(0xFFFFFF);
        }
        if (button(shift_theme, "Shift", "os.shift", .{ .x = 1081, .y = 15, .w = 70, .h = 33 })) self.shift = !self.shift;
        if (button(option_theme, "Option", "os.option", .{ .x = 1158, .y = 15, .w = 73, .h = 33 })) self.option = !self.option;
        for (labels.rows, 0..) |row, ri| {
            var x: f32 = 22;
            for (row, 0..) |key, ki| {
                var buffer: [64]u8 = undefined;
                var modified_buffer: [64]u8 = undefined;
                var caption = if (key.name.len != 0) key.name else labels.usage(key.code, &buffer);
                var modified: []const u8 = if (key.name.len == 0 and self.option) @import("fixture.zig").optionLabel(key.code, self.shift) else if (key.name.len == 0 and self.shift) @import("fixture.zig").shiftLabel(key.code) else "";
                if (self.source) |*source| if (key.name.len == 0 and key.code >= 4 and key.code <= 56) {
                    const result = source.keyToText(.{ .tap_keycode = key.code });
                    if (result.len > 0) {
                        @memcpy(buffer[0..result.len], result.data[0..result.len]);
                        caption = buffer[0..result.len];
                    }
                    modified = "";
                    if (self.shift or self.option) {
                        const preview = source.keyToText(.{ .tap_keycode = key.code, .tap_modifiers = .{ .left_shift = self.shift, .left_alt = self.option } });
                        if (preview.len > 0) {
                            @memcpy(modified_buffer[0..preview.len], preview.data[0..preview.len]);
                            modified = modified_buffer[0..preview.len];
                        }
                    }
                };
                var opts = options(t, .{ .x = x, .y = 58 + @as(f32, @floatFromInt(ri)) * 51, .w = 76 * key.units - 5, .h = 47 }, if (caption.len > 3) 13 else 18);
                opts.font = fonts.font(caption, if (caption.len > 3) 13 else 18);
                opts.id_extra = ri * 100 + ki;
                opts.background = true;
                opts.gravity_x = 0.5;
                opts.gravity_y = 0.5;
                opts.border = .all(1);
                dvui.labelNoFmt(@src(), caption, .{ .align_x = 0.5, .align_y = if (modified.len == 0) 0.5 else 0.8 }, opts);
                if (modified.len != 0 and !std.mem.eql(u8, modified, caption)) {
                    var secondary = options(t, .{ .x = x + 2, .y = opts.rect.?.y + 2, .w = opts.rect.?.w - 4, .h = 17 }, 11);
                    secondary.font = fonts.font(modified, 12);
                    secondary.id_extra = ri * 100 + ki;
                    secondary.padding = .{};
                    secondary.color_text = .{ .color = color(if (self.light) 0x126ACC else 0x65B1FF) };
                    dvui.labelNoFmt(@src(), modified, .{ .align_x = 0.5, .align_y = 0.5 }, secondary);
                }
                x += 76 * key.units;
            }
        }
    }
    fn bottom(self: *Editor, t: Theme) !void {
        {
            const box = panel(t, .testing);
            defer box.deinit();
            label(t, try std.fmt.allocPrint(dvui.currentWindow().arena(), "Try your draft · {s}", .{@tagName(self.testing.state)}), .{ .x = 18, .y = 12, .w = 360, .h = 24 }, 16);
            var text_options = options(t, .{ .x = 18, .y = 39, .w = 493, .h = 36 }, 17);
            text_options.background = true;
            text_options.border = .all(1);
            dvui.labelNoFmt(@src(), if (self.text.len == 0) "Prepare an immutable draft to test offline" else self.text.value(), .{}, text_options);
            if (button(t, "Details", "test.details", .{ .x = 521, .y = 27, .w = 90, .h = 39 })) self.test_details = !self.test_details;
            if (button(t, switch (self.testing.state) {
                .idle, .stale, .failed => "Prepare Test",
                .preparing => "Cancel",
                .prepared => "Start Test",
                .running => "Stop Test",
            }, "test.prepare", .{ .x = 621, .y = 27, .w = 145, .h = 39 })) {
                switch (self.testing.state) {
                    .idle, .stale, .failed => self.testing.prepare(self.model.current.snapshot) catch |err| self.report(err),
                    .prepared => {
                        if (self.text.native_session) |*session| if (!session.eurkey()) {
                            self.report(error.SelectEurKeyInputSource);
                            return;
                        };
                        self.test_start = @intCast(std.Io.Clock.awake.now(self.io).toMicroseconds());
                        self.last_text_sequence = null;
                        self.text.reset();
                        self.testing.start() catch |err| self.report(err);
                    },
                    .running, .preparing => {
                        self.testing.stop();
                        self.text.reset();
                    },
                }
            }
        }
        {
            const box = panel(t, .callbacks);
            defer box.deinit();
            label(t, "Callbacks", .{ .x = 18, .y = 12, .w = 200, .h = 24 }, 16);
            if (button(t, if (self.model.document().callbacks.len > 0) self.model.document().callbacks[0].binding else "Attach source…", "callback.attach", .{ .x = 124, .y = 10, .w = 169, .h = 30 })) self.callback_open = true;
            label(t, if (self.model.document().callbacks.len == 0) "No attached source · external Zig files" else switch (self.callback_state) {
                .changed => "External source changed · refresh explicitly",
                .missing => "External source missing · snapshot preserved",
                .failed => "Callback diagnostic · open Manage",
                else => "Source snapshot preserved · external Zig",
            }, .{ .x = 18, .y = 49, .w = 390, .h = 24 }, 12);
            if (button(t, "Open externally", "callback.external", .{ .x = 301, .y = 9, .w = 132, .h = 31 })) {
                if (self.model.document().callbacks.len == 0) self.callback_open = true else self.openCallback(0) catch |err| self.report(err);
            }
        }
        if (self.diagnostic[0] != 0) label(t, std.mem.sliceTo(&self.diagnostic, 0), .{ .x = 294, .y = 490, .w = 815, .h = 25 }, 12);
    }
    pub fn openCallback(self: *Editor, index: usize) !void {
        const callback = self.model.document().callbacks[index];
        if (callback.kind != .attached) return error.RegisteredSourceReadOnly;
        if (self.project_path[0] == 0) return error.SaveProjectDirectoryFirst;
        if (self.external_job != null) return error.ExternalEditorBusy;
        var dir = try std.Io.Dir.cwd().openDir(self.io, std.mem.sliceTo(&self.project_path, 0), .{});
        defer dir.close(self.io);
        try p.sources.checkout(self.gpa, self.io, dir, self.model.current.snapshot, index);
        const relative = try std.fmt.allocPrint(self.gpa, "callbacks/{d}/{s}", .{ index, callback.binding });
        defer self.gpa.free(relative);
        const path = try dir.realPathFileAlloc(self.io, relative, self.gpa);
        defer self.gpa.free(path);
        const job = try self.gpa.create(jobs.Job);
        errdefer self.gpa.destroy(job);
        job.* = try jobs.Job.init(self.gpa, self.io, .{ .argv = &.{ "/usr/bin/open", "-t", path }, .cwd = self.testing.root, .snapshot_id = try self.model.id(), .timeout_ms = 5000 });
        errdefer job.deinit();
        try job.start();
        self.external_job = job;
    }
    fn paths(self: *Editor, t: Theme) !void {
        const window = dvui.floatingWindow(@src(), .{ .modal = true }, .{ .rect = .{ .x = 400, .y = 120, .w = 740, .h = 720 }, .padding = .all(20), .background = true, .color_fill = .{ .color = t.panel } });
        defer window.deinit();
        const area = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer area.deinit();
        dvui.label(@src(), "Project directory (atomic project.zon + immutable sources)", .{}, .{});
        {
            const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.project_path } }, .{ .expand = .horizontal });
            entry.deinit();
        }
        if (dvui.button(@src(), "Choose project folder…", .{}, .{})) {
            self.dialog_target = .project;
            dialog.start(self.backend_window.?) catch |err| self.report(err);
        }
        if (dvui.button(@src(), "Open", .{}, .{})) {
            var dir = try std.Io.Dir.cwd().openDir(self.io, std.mem.sliceTo(&self.project_path, 0), .{});
            defer dir.close(self.io);
            self.model.open(self.io, dir) catch |err| self.report(err);
            self.syncRename();
        }
        if (dvui.button(@src(), "Save", .{}, .{})) self.save() catch |err| self.report(err);
        dvui.label(@src(), "Owned export directory (existing differing files are refused)", .{}, .{});
        {
            const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.export_path } }, .{ .expand = .horizontal });
            entry.deinit();
        }
        if (dvui.button(@src(), "Choose export folder…", .{}, .{})) {
            self.dialog_target = .exported;
            dialog.start(self.backend_window.?) catch |err| self.report(err);
        }
        if (dvui.button(@src(), "Export Zig", .{}, .{})) {
            if (self.export_path[0] == 0) {
                self.report(error.ChooseExportDirectoryFirst);
                return;
            }
            var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, std.mem.sliceTo(&self.export_path, 0), .{});
            defer dir.close(self.io);
            const manifest = p.exporter.write(self.gpa, self.io, dir, self.model.current.snapshot, p.profiles.board) catch |err| {
                self.report(err);
                return;
            };
            std.zon.parse.free(self.gpa, manifest);
            self.exported_id = manifest.snapshot_id;
        }
        const current_id = try self.model.id();
        dvui.label(@src(), "Draft snapshot: {s}", .{std.fmt.bytesToHex(current_id, .lower)}, .{});
        if (self.exported_id) |id| dvui.label(@src(), "Export {s}: {s} · running firmware remains unverified", .{ if (std.mem.eql(u8, &id, &current_id)) "matches draft" else "is stale", std.fmt.bytesToHex(id, .lower) }, .{});
        const advisory = try p.assessment.assess(self.model.document());
        dvui.label(@src(), "Declarative recovery action reachable: {} · callbacks require review: {}", .{ advisory.recovery_found, advisory.callbacks_require_review }, .{});
        for (self.model.document().layers, 0..) |layer, index| if (!advisory.reachable[index]) dvui.label(@src(), "Layer {s}: no declarative path from Base", .{layer.name}, .{ .id_extra = index });
        if (dvui.button(@src(), "Separate overlay", .{}, .{})) self.overlay_open = true;
        if (dvui.button(@src(), "Restore recovery draft", .{}, .{})) {
            const path = try std.fs.path.join(self.gpa, &.{ self.testing.root, ".zig-cache", "editor-recovery" });
            defer self.gpa.free(path);
            var dir = std.Io.Dir.cwd().openDir(self.io, path, .{}) catch |err| {
                self.report(err);
                return;
            };
            defer dir.close(self.io);
            var loaded = p.snapshot.load(self.gpa, self.io, dir, p.profiles.board) catch |err| {
                self.report(err);
                return;
            };
            defer loaded.deinit();
            try self.model.commit(loaded.snapshot);
            self.syncRename();
        }
        if (dvui.button(@src(), "Close", .{}, .{})) self.paths_open = false;
    }
    fn save(self: *Editor) !void {
        if (self.project_path[0] == 0) {
            self.paths_open = true;
            return;
        }
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, std.mem.sliceTo(&self.project_path, 0), .{});
        defer dir.close(self.io);
        try self.model.save(self.io, dir);
    }
    fn recover(self: *Editor) !void {
        const path = try std.fs.path.join(self.gpa, &.{ self.testing.root, ".zig-cache", "editor-recovery" });
        defer self.gpa.free(path);
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, path, .{});
        defer dir.close(self.io);
        try p.snapshot.save(self.gpa, self.io, dir, self.model.current.snapshot, p.profiles.board);
    }
    fn callbackDrawer(self: *Editor, t: Theme) !void {
        try @import("callback_drawer.zig").draw(self, t);
    }
    fn comboDrawer(self: *Editor, t: Theme) !void {
        try @import("combo_drawer.zig").draw(self, t);
    }
    fn picker(self: *Editor, t: Theme) !void {
        const window = dvui.floatingWindow(@src(), .{ .modal = true }, .{ .rect = .{ .x = 1000, .y = 230, .w = 490, .h = 650 }, .padding = .all(18), .background = true, .color_fill = .{ .color = t.panel } });
        defer window.deinit();
        dvui.label(@src(), "Search actions · key choice preserves existing hold fields", .{}, .{});
        {
            const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.search } }, .{ .expand = .horizontal });
            entry.deinit();
        }
        const query = std.mem.sliceTo(&self.search, 0);
        {
            const area = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
            defer area.deinit();
            for (0..256) |index| {
                var buffer: [64]u8 = undefined;
                const caption = labels.usage(@intCast(index), &buffer);
                if (query.len > 0 and std.ascii.indexOfIgnoreCase(caption, query) == null) continue;
                if (dvui.button(@src(), caption, .{}, .{ .id_extra = index, .expand = .horizontal })) {
                    var draft = forms.Draft.from(self.model.action());
                    if (draft.mode == 0 or draft.mode == 1 or draft.mode == 3) draft.mode = if (draft.mode == 3) 4 else 2;
                    const mods = if (draft.tap.key_press) |key| key.tap_modifiers else @import("layout-model").Modifiers{};
                    draft.tap.key_press = .{ .tap_keycode = @intCast(index), .tap_modifiers = mods };
                    self.model.apply(draft.action()) catch |err| self.report(err);
                    self.picker_open = false;
                }
            }
            inline for (@typeInfo(@import("layout-model").MediaCode).@"enum".fields, 0..) |field, i| {
                if (query.len == 0 or std.ascii.indexOfIgnoreCase(field.name, query) != null) if (dvui.button(@src(), field.name, .{}, .{ .id_extra = 256 + i, .expand = .horizontal })) {
                    try self.model.apply(.{ .tap_only = .{ .media_key = @enumFromInt(field.value) } });
                    self.picker_open = false;
                };
            }
            for (253..256) |id| {
                var signal_buffer: [64]u8 = undefined;
                const caption = labels.signal(@intCast(id), &signal_buffer);
                if (query.len == 0 or std.ascii.indexOfIgnoreCase(caption, query) != null) if (dvui.button(@src(), caption, .{}, .{ .id_extra = 768 + id, .expand = .horizontal })) {
                    try self.model.apply(.{ .tap_only = .{ .custom = @intCast(id) } });
                    self.picker_open = false;
                };
            }
            for (self.model.document().layers, 0..) |layer, i| {
                const caption = try std.fmt.allocPrint(dvui.currentWindow().arena(), "Hold layer: {s}", .{layer.name});
                if (query.len == 0 or std.ascii.indexOfIgnoreCase(caption, query) != null) if (dvui.button(@src(), caption, .{}, .{ .id_extra = 512 + i, .expand = .horizontal })) {
                    try self.model.apply(.{ .hold_only = .{ .layer_id = layer.id } });
                    self.picker_open = false;
                };
            }
        }
        if (dvui.button(@src(), "Advanced fields…", .{}, .{})) {
            self.picker_open = false;
            self.openAction();
        }
        if (dvui.button(@src(), "Cancel search", .{}, .{})) self.picker_open = false;
    }
    fn actionForm(self: *Editor, t: Theme) !void {
        const window = dvui.floatingWindow(@src(), .{ .modal = true }, .{ .rect = .{ .x = 690, .y = 90, .w = 700, .h = 810 }, .padding = .all(18), .background = true, .color_fill = .{ .color = t.panel } });
        defer window.deinit();
        dvui.label(@src(), "Advanced action · selected positions · one undo operation", .{}, .{});
        {
            const area = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
            defer area.deinit();
            forms.draw(&self.action_draft, self.model.document());
        }
        if (dvui.button(@src(), "Apply to selection", .{}, .{ .tag = "advanced.apply" })) {
            self.model.apply(self.action_draft.action()) catch |err| {
                self.report(err);
                return;
            };
            self.advanced = false;
        }
        if (dvui.button(@src(), "Cancel", .{}, .{})) self.advanced = false;
    }
    fn firmwareDrawer(self: *Editor, t: Theme) !void {
        try @import("firmware_drawer.zig").draw(self, t);
    }
    fn testDrawer(self: *Editor, t: Theme) !void {
        try @import("test_drawer.zig").draw(self, t);
    }
};

pub fn run(init: std.process.Init, args: []const []const u8) !void {
    var fixture = false;
    var light = false;
    var screenshot: ?[]const u8 = null;
    var reference_path: ?[]const u8 = null;
    var golden_path: ?[]const u8 = null;
    var state: scenario.State = .normal;
    var interactions = false;
    var density: ?u8 = null;
    var requested_size: ?dvui.Size = null;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--light")) light = true else if (std.mem.eql(u8, args[i], "--fixture")) fixture = true else if (std.mem.eql(u8, args[i], "--screenshot") and i + 1 < args.len) {
            i += 1;
            screenshot = args[i];
            fixture = true;
        } else if (std.mem.eql(u8, args[i], "--scenario") and i + 1 < args.len) {
            i += 1;
            state = std.meta.stringToEnum(scenario.State, args[i]) orelse return error.InvalidScenario;
        } else if (std.mem.eql(u8, args[i], "--density") and i + 1 < args.len) {
            i += 1;
            density = try std.fmt.parseInt(u8, args[i], 10);
            if (density.? != 1 and density.? != 2) return error.InvalidDensity;
        } else if (std.mem.eql(u8, args[i], "--window-size") and i + 2 < args.len) {
            const width = try std.fmt.parseInt(u16, args[i + 1], 10);
            const height = try std.fmt.parseInt(u16, args[i + 2], 10);
            if (width < 900 or height < 600 or width > 4096 or height > 4096) return error.InvalidWindowSize;
            requested_size = .{ .w = @floatFromInt(width), .h = @floatFromInt(height) };
            i += 2;
        } else if (std.mem.eql(u8, args[i], "--compare-reference") and i + 1 < args.len) {
            i += 1;
            reference_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--compare-golden") and i + 1 < args.len) {
            i += 1;
            golden_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--interactions")) {
            interactions = true;
            fixture = true;
        } else return error.Usage;
    }
    if (density != null and screenshot == null) return error.DensityRequiresScreenshot;
    if (state != .normal and screenshot == null) return error.ScenarioRequiresScreenshot;
    const window_size = requested_size orelse if (screenshot != null) dvui.Size{ .w = 1536, .h = 1024 } else dvui.Size{ .w = geometry.initial.w, .h = geometry.initial.h };
    var backend = try @import("window.zig").init(.{ .io = init.io, .environ_map = init.environ_map, .size = window_size, .min_size = .{ .w = geometry.minimum.w, .h = geometry.minimum.h }, .title = "Zigmkay — LK7 Keymap Editor", .hidden = screenshot != null, .vsync = true, .persist_window_geometry = false }, density == 1);
    defer backend.deinit();
    var open = true;
    var window = try dvui.Window.init(@src(), init.gpa, backend.backend(), .{ .theme = if (light) dvui.Theme.builtin.adwaita_light else dvui.Theme.builtin.adwaita_dark, .open_flag = &open });
    defer window.deinit();
    var editor = try Editor.init(init, fixture);
    defer editor.deinit();
    editor.light = light;
    editor.window_id = sdl.SDL_GetWindowID(backend.window);
    editor.backend_window = backend.window;
    scenario.setup(&editor, state) catch |err| editor.report(err);
    var frames: usize = 0;
    while (open) : (frames += 1) {
        try window.begin(window.beginWait(false));
        try @import("events.zig").pump(&backend, &window, &editor);
        if (interactions) switch (frames) {
            3 => try scenario.click(&window, "key.select.31", window.natural_scale, false),
            4 => try scenario.click(&window, "key.select.31", window.natural_scale, true),
            6 => try scenario.click(&window, "layer.duplicate.1", window.natural_scale, false),
            7 => try scenario.click(&window, "layer.duplicate.1", window.natural_scale, true),
            11 => try scenario.click(&window, "edit.undo", window.natural_scale, false),
            12 => try scenario.click(&window, "edit.undo", window.natural_scale, true),
            14 => try scenario.click(&window, "edit.redo", window.natural_scale, false),
            15 => try scenario.click(&window, "edit.redo", window.natural_scale, true),
            18 => try scenario.click(&window, "inspector.tap", window.natural_scale, false),
            19 => try scenario.click(&window, "inspector.tap", window.natural_scale, true),
            20 => editor.action_draft = forms.Draft.from(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } }),
            22 => try scenario.click(&window, "advanced.apply", window.natural_scale, false),
            23 => try scenario.click(&window, "advanced.apply", window.natural_scale, true),
            else => {},
        };
        if (editor.source) |*source| _ = source.refresh();
        editor.draw() catch |err| {
            if (err == error.OutOfMemory) return err;
            editor.report(err);
        };
        if (editor.should_close) open = false;
        if (frames == 2 and screenshot != null) try scenario.verifyPanels(window.natural_scale);
        if (interactions and frames == 26) {
            if (editor.model.primary != 31 or editor.model.document().layers.len != 7 or editor.model.layer != 5) return error.InteractionScenarioFailed;
            if (editor.advanced or editor.model.action().? != .tap_only or editor.model.action().?.tap_only.key_press.?.tap_keycode != 4) return error.FormInteractionFailed;
            std.log.info("Semantic input scenario passed: thumb selection, isolated duplication, undo/redo and advanced form apply", .{});
            if (screenshot == null) {
                _ = try window.end(.{});
                break;
            }
        }
        if (screenshot != null and frames == (if (interactions) @as(usize, 28) else 5)) {
            if (density) |expected| if (@abs(window.natural_scale / editor.content_scale - @as(f32, @floatFromInt(expected))) > 0.02) return error.NativeDensityMismatch;
            window.endRendering(.{});
            const size = window.rect_pixels;
            const width: usize = @intFromFloat(size.w);
            const height: usize = @intFromFloat(size.h);
            const pixels = try init.gpa.alloc(u8, width * height * 4);
            defer init.gpa.free(pixels);
            try backend.readPixels(size, pixels.ptr);
            // Normalize Retina readback to the reference content pixels.
            const normalized = try init.gpa.alloc(u8, 1536 * 1024 * 4);
            defer init.gpa.free(normalized);
            for (0..1024) |y| for (0..1536) |x| {
                const src = ((y * height / 1024) * width + x * width / 1536) * 4;
                @memcpy(normalized[(y * 1536 + x) * 4 ..][0..4], pixels[src..][0..4]);
            };
            var writer: std.Io.Writer.Allocating = .init(init.gpa);
            defer writer.deinit();
            try writer.ensureTotalCapacity(4096);
            try dvui.PNGEncoder.writeWithResolution(&writer.writer, normalized, 1536, 1024, 0);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = screenshot.?, .data = writer.written() });
            if (reference_path) |reference| try @import("comparison.zig").write(init.gpa, init.io, reference, normalized, screenshot.?, light, window.natural_scale);
            if (golden_path) |path| try @import("comparison.zig").golden(init.gpa, init.io, path, normalized);
            _ = try window.end(.{});
            break;
        }
        const wait = try window.end(.{});
        _ = try backend.waitEventTimeout(@min(16_000, window.waitTime(wait)));
    }
}
test {
    _ = geometry;
    _ = @import("model.zig");
    _ = forms;
    _ = @import("text.zig");
}
