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
const inspector_ui = @import("inspector.zig");
const Session = @import("session.zig").Session;

const ui = @import("ui.zig");
pub const Theme = ui.Theme;
const options = ui.options;
const color = ui.color;
const rect = ui.rect;
const label = ui.label;
const button = ui.button;
const panel = ui.panel;

pub const Editor = struct {
    pub const Intent = union(enum) {
        select: struct { index: usize, extend: bool },
        layer: usize,
        profile: usize,
        duplicate: usize,
        delete: usize,
        add_layer,
        rename,
        undo,
        redo,
        copy,
        paste,
        save,
        build,
        flash,
        main_view: @import("try_state.zig").MainView,
        combo,
        callback,
        paths,
        close,
        chord: struct { value: @import("assignment.zig").Chord, held: bool, target: ?usize },
    };
    edit_session: ?Session = null,
    inspector_state: inspector_ui.State = .{},
    inspector_error: [256]u8 = @splat(0),
    pending: ?Intent = null,
    model: Model,
    io: std.Io,
    gpa: std.mem.Allocator,
    light: bool = false,
    content_scale: f32 = 1,
    canvas_width: f32 = 1536,
    canvas_height: f32 = 1076,
    fixture: bool = false,
    connection_text: []const u8 = "Offline · No device",
    source: ?input.Source = null,
    shift: bool = false,
    option: bool = false,
    drag_chord: ?@import("assignment.zig").Chord = null,
    extend: bool = false,
    canvas_focus: bool = true,
    fonts_loaded: bool = false,
    testing: Testing,
    firmware: Firmware,
    auto_build: @import("auto_build.zig").Scheduler = .{},
    pending_flash: @import("pending_flash.zig").Gate = .{},
    bootloader_requested: bool = false,
    try_hid_bootloader: bool = true,
    bootloader: ?@import("../live_adapter.zig").BootloaderAttempt(@import("../main.zig").Native) = null,
    bootloader_status: []const u8 = "",
    text: Text,
    free_text: Text,
    main_view: @import("try_state.zig").MainView = .editor,
    try_mode: @import("try_state.zig").Mode = .free_typing,
    free_focus: bool = false,
    window_focused: bool = true,
    free_failed: bool = false,
    free_pending: bool = false,
    free_input_after: u64 = 0,
    free_focus_requested: bool = true,
    free_snapshot: ?[32]u8 = null,
    preview: @import("try_state.zig").State = .{},
    preview_ticket: ?@import("try_state.zig").Ticket = null,
    preview_notice: []const u8 = "",
    practice: @import("practice.zig").Session = .{},
    practice_active: bool = false,
    practice_mode: usize = 0,
    practice_level: usize = 1,
    practice_source: usize = 0,
    practice_seed: u64 = 1,
    practice_snapshot: [32]u8 = @splat(0),
    practice_drawn_len: usize = 0,
    practice_show_keyboard: bool = true,
    practice_scroll_position: f32 = 0,
    practice_scroll_at: ?u64 = null,
    practice_labels: ?@import("../components/cache.zig").LabelCache = null,
    practice_labels_id: [32]u8 = @splat(0),
    practice_live_labels: ?*const @import("../components/cache.zig").LabelCache = null,
    practice_live_state: ?@import("companion-model").State = null,
    practice_live_stale: bool = true,
    practice_live_profile: [8]u8 = @splat(0),
    live_requested: bool = false,
    practice_best: [2][3][2]f64 = @splat(@splat(@splat(0))),
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
    profile_choice: usize = 2,
    profile_projects: @import("profile_projects.zig").Registry = .{},
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
    tray_managed: bool = false,
    hide_requested: bool = false,
    recovery_id: [32]u8 = @splat(0),
    recovery_at: i64 = 0,
    overlay_open: bool = false,
    pub fn init(process: std.process.Init, fixture: bool) !Editor {
        const root = try std.Io.Dir.cwd().realPathFileAlloc(process.io, ".", process.gpa);
        defer process.gpa.free(root);
        var self = Editor{ .model = try Model.init(process.gpa, .eurkey), .io = process.io, .gpa = process.gpa, .fixture = fixture, .testing = try Testing.init(process.gpa, process.io, root), .firmware = try Firmware.init(process.gpa, process.io, root), .text = Text.init(fixture), .free_text = .{} };
        if (!fixture) self.source = input.Source.init();
        if (fixture) {
            try @import("fixture.zig").setup(&self.model);
            self.connection_text = "Fixture · profile match";
            self.option = true;
            try self.text.insert("Hello, Grüß dich!");
        } else {
            self.restoreStartupProject() catch |err| self.report(err);
        }
        self.syncRename();
        self.auto_build.manual(try self.model.id());
        return self;
    }
    fn rememberProject(self: *Editor) !void {
        if (self.fixture) return;
        const path = try std.Io.Dir.cwd().realPathFileAlloc(self.io, std.mem.sliceTo(&self.project_path, 0), self.gpa);
        defer self.gpa.free(path);
        const directory = try std.fs.path.join(self.gpa, &.{ self.testing.root, "projects" });
        defer self.gpa.free(directory);
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, directory, .{});
        defer dir.close(self.io);
        try @import("startup_project.zig").save(self.gpa, self.io, dir, path);
        try self.profile_projects.set(self.profile_choice, path);
        try self.profile_projects.save(self.gpa, self.io, dir);
        self.project_path = @splat(0);
        @memcpy(self.project_path[0..path.len], path);
    }
    fn openProject(self: *Editor, path: []const u8) !void {
        if (path.len >= self.project_path.len) return error.InvalidStartupProject;
        var dir = try std.Io.Dir.cwd().openDir(self.io, path, .{});
        defer dir.close(self.io);
        try self.model.open(self.io, dir);
        self.clearFreeProject();
        // path can borrow the input buffer; retain bytes before clearing it.
        var buffer: [1024]u8 = @splat(0);
        @memcpy(buffer[0..path.len], path);
        self.project_path = buffer;
        self.model.layer = 0;
        for ([_][8]u8{ "danish\x00\x00".*, "qwerty\x00\x00".*, "eurkey\x00\x00".*, "eurmac\x00\x00".* }, 0..) |id, index| {
            if (std.mem.eql(u8, &id, &self.model.document().profile_id)) self.profile_choice = index;
        }
        self.syncRename();
        try self.rememberProject();
    }
    fn restoreStartupProject(self: *Editor) !void {
        const directory = try std.fs.path.join(self.gpa, &.{ self.testing.root, "projects" });
        defer self.gpa.free(directory);
        var dir = std.Io.Dir.cwd().openDir(self.io, directory, .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer dir.close(self.io);
        self.profile_projects = try @import("profile_projects.zig").Registry.load(self.gpa, self.io, dir);
        if (try @import("startup_project.zig").load(self.gpa, self.io, dir)) |path| {
            defer self.gpa.free(path);
            try self.openProject(path);
        } else {
            const starter = try std.fs.path.join(self.gpa, &.{ directory, "eurmac" });
            defer self.gpa.free(starter);
            self.openProject(starter) catch |err| switch (err) {
                error.FileNotFound => return,
                else => return err,
            };
        }
    }
    fn selectProfile(self: *Editor, index: usize) !void {
        const profile: p.profiles.Profile = @enumFromInt(index);
        if (self.fixture) {
            var loaded = try p.profiles.create(self.gpa, profile);
            defer loaded.deinit();
            try self.model.commit(loaded.snapshot);
            self.profile_choice = index;
        } else {
            const associated = self.profile_projects.path(index);
            const directory = if (associated.len != 0) try self.gpa.dupe(u8, associated) else try std.fs.path.join(self.gpa, &.{ self.testing.root, "projects", @tagName(profile) });
            defer self.gpa.free(directory);
            try @import("profile_projects.zig").open(&self.model, self.io, directory, profile);
            self.profile_choice = index;
            self.project_path = @splat(0);
            if (directory.len >= self.project_path.len) return error.InvalidProjectPath;
            @memcpy(self.project_path[0..directory.len], directory);
            try self.rememberProject();
        }
        self.clearFreeProject();
        self.model.layer = 0;
        self.syncRename();
    }
    fn clearFreeProject(self: *Editor) void {
        self.testing.stop();
        self.free_text.clear();
        self.free_snapshot = null;
        self.free_failed = false;
        self.free_pending = false;
        self.preview.invalidate();
        self.preview_notice = "Project changed · free text cleared for the new snapshot.";
    }
    pub fn deinit(self: *Editor) void {
        if (self.bootloader) |*attempt| attempt.driver.transport.close();
        if (self.external_job) |job| {
            job.deinit();
            self.gpa.destroy(job);
        }
        self.testing.deinit();
        self.firmware.deinit();
        self.text.deinit();
        self.free_text.deinit();
        if (self.practice_labels) |*labels_cache| labels_cache.deinit();
        self.model.deinit();
        if (self.source) |*source| source.deinit();
    }
    pub fn bootloaderBusy(self: *const Editor) bool {
        return self.bootloader_requested or if (self.bootloader) |*attempt| attempt.active() else false;
    }
    fn requestFlash(self: *Editor) !void {
        if (self.fixture) return;
        if (self.firmware.state == .transferring or self.firmware.state == .transferred or self.firmware.state == .awaiting_reconnect or self.bootloaderBusy()) return error.TransferInProgress;
        if (self.callback_state == .changed or self.callback_state == .missing or self.callback_state == .failed) return error.RefreshCallbackSourcesFirst;
        const current = try self.model.id();
        self.firmware.poll(current);
        if (self.firmware.state != .built and self.firmware.state != .building) {
            try self.firmware.build(self.model.current.snapshot);
            self.auto_build.manual(current);
        }
        self.pending_flash.request(current, self.try_hid_bootloader);
        self.auto_build.manual(current);
        try self.finishPendingFlash(current);
    }
    fn finishPendingFlash(self: *Editor, current: [32]u8) !void {
        if (!self.pending_flash.take(current, self.firmware.state == .built, self.firmware.state == .failed or self.firmware.state == .cancelled or self.callback_state == .changed or self.callback_state == .missing or self.callback_state == .failed)) return;
        self.firmware.flash(current, "", true) catch |err| {
            if (err == error.StaleBuild or err == error.ArtifactChanged or err == error.FileNotFound or err == error.NoCurrentArtifact) {
                try self.firmware.build(self.model.current.snapshot);
                self.auto_build.manual(current);
                self.pending_flash.request(current, self.pending_flash.hid);
                return;
            }
            return err;
        };
        if (self.bootloader) |*old| old.driver.transport.close();
        self.bootloader = null;
        self.diagnostic = @splat(0);
        self.bootloader_requested = self.pending_flash.hid;
        self.bootloader_status = if (self.pending_flash.hid) "Checking HID bootloader support…" else "Enter BOOTSEL manually to continue flashing.";
    }
    /// Called by both editor hosts only after an explicit successful Flash click.
    pub fn pollBootloader(self: *Editor, path: ?[]const u8) void {
        if (self.fixture) return;
        if (self.bootloader_requested) {
            self.bootloader_requested = false;
            if (self.bootloader) |*old| old.driver.transport.close();
            self.bootloader = null;
            self.bootloader_status = "HID unavailable · enter BOOTSEL manually to continue flashing.";
            if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return;
            var seed: u32 = undefined;
            self.io.randomSecure(std.mem.asBytes(&seed)) catch return;
            self.bootloader = @import("../live_adapter.zig").BootloaderAttempt(@import("../main.zig").Native).init(.{ .io = self.io }, self.firmware.expected orelse return, seed, path) catch return;
            const attempt = &self.bootloader.?;
            attempt.start(attempt.driver.transport.now());
        }
        if (self.bootloader) |*attempt| {
            attempt.poll(attempt.driver.transport.now());
            self.bootloader_status = attempt.message();
        }
    }
    pub fn syncRename(self: *Editor) void {
        self.rename_buffer = @splat(0);
        const name = self.model.document().layers[self.model.layer].name;
        @memcpy(self.rename_buffer[0..name.len], name);
    }
    pub fn report(self: *Editor, err: anyerror) void {
        self.diagnostic = @splat(0);
        if (err == error.DropModifierKeyOnHold) {
            _ = std.fmt.bufPrint(&self.diagnostic, "Drop a Control, Shift, Option or Command key onto Hold.", .{}) catch {};
            return;
        }
        _ = std.fmt.bufPrint(&self.diagnostic, "{s}", .{@errorName(err)}) catch {};
    }
    pub fn pauseHidden(self: *Editor) void {
        self.pausePractice();
        self.testing.stop();
        self.free_focus = false;
        self.free_pending = false;
        self.preview.release();
        self.text.reset();
        self.free_text.reset();
    }
    pub fn requestQuit(self: *Editor) !void {
        // Close confirmation lives in the editor inspector, including when
        // Quit was requested from a hidden Try it out window.
        self.main_view = .editor;
        const managed = self.tray_managed;
        self.tray_managed = false;
        defer self.tray_managed = managed;
        var event: sdl.SDL_Event = std.mem.zeroes(sdl.SDL_Event);
        event.type = sdl.SDL_EVENT_QUIT;
        if (!try self.raw(event)) self.should_close = true;
    }
    pub fn raw(self: *Editor, event: sdl.SDL_Event) !bool {
        if (self.tray_managed and event.type == sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID == self.window_id) {
            self.pauseHidden();
            self.hide_requested = true;
            return true;
        }
        const input_window: ?u32 = switch (event.type) {
            sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_KEY_UP => event.key.windowID,
            sdl.SDL_EVENT_TEXT_INPUT => event.text.windowID,
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => event.button.windowID,
            else => null,
        };
        if (input_window) |id| if (id != self.window_id) return false;
        if ((event.type == sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID == self.window_id) or event.type == sdl.SDL_EVENT_QUIT) {
            self.pausePractice();
            self.testing.stop();
            self.free_focus = false;
            self.free_pending = false;
            self.preview.release();
            self.free_text.reset();
            if (self.firmware.state == .transferring) {
                self.report(error.TransferInProgress);
                return true;
            }
            if (dialog.active()) {
                self.report(error.CloseNativeDialogFirst);
                return true;
            }
            if (self.edit_session) |session| if (session.dirty()) {
                self.pending = .close;
                return true;
            };
            if (self.model.dirty()) {
                self.close_requested = true;
                return true;
            }
        }
        if (event.type == sdl.SDL_EVENT_WINDOW_FOCUS_LOST and event.window.windowID == self.window_id) {
            self.window_focused = false;
            self.free_focus = false;
            self.free_pending = false;
            self.preview.release();
            self.pausePractice();
            self.testing.stop();
            self.text.reset();
            self.free_text.reset();
        }
        if (event.type == sdl.SDL_EVENT_WINDOW_FOCUS_GAINED and event.window.windowID == self.window_id) self.window_focused = true;
        if (event.type == sdl.SDL_EVENT_KEY_DOWN or event.type == sdl.SDL_EVENT_KEY_UP) self.extend = event.key.mod & sdl.SDL_KMOD_SHIFT != 0;
        if (self.main_view == .try_it_out and self.try_mode == .typing_test and event.type == sdl.SDL_EVENT_KEY_DOWN and event.key.windowID == self.window_id and event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
            self.pausePractice();
            self.free_focus = false;
            self.free_pending = false;
            self.testing.stop();
            return true;
        }
        if (!self.paths_open and !self.combo_open and !self.callback_open and self.main_view == .editor and event.type == sdl.SDL_EVENT_KEY_DOWN and event.key.windowID == self.window_id and event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
            dvui.focusWidget(null, null, null);
            return true;
        }
        const owns_runner = self.main_view == .try_it_out and self.try_mode == .typing_test and self.window_focused and self.practice_active and self.practice.source == .draft and (self.practice.state == .running or self.practice.state == .ready);
        if (owns_runner and self.testing.state == .running) {
            if (event.type == sdl.SDL_EVENT_TEXT_INPUT and event.text.windowID == self.window_id) return true;
            if ((event.type == sdl.SDL_EVENT_KEY_DOWN or event.type == sdl.SDL_EVENT_KEY_UP) and event.key.windowID == self.window_id) {
                if (@import("host_input.zig").keyIndex(self.model.document(), @intCast(event.key.scancode))) |index| {
                    if (!event.key.repeat) self.testing.input(if (event.type == sdl.SDL_EVENT_KEY_DOWN) .{ .key_down = index } else .{ .key_up = index }, self.testTime()) catch |err| self.report(err);
                    return true;
                }
            }
        } else if (self.main_view == .editor and self.canvas_focus and event.type == sdl.SDL_EVENT_KEY_DOWN and event.key.windowID == self.window_id and !event.key.repeat and !self.paths_open and !self.combo_open and !self.callback_open) {
            if (event.key.scancode == sdl.SDL_SCANCODE_LEFT or event.key.scancode == sdl.SDL_SCANCODE_RIGHT) {
                try self.request(.{ .select = .{ .index = (self.model.primary + (if (event.key.scancode == sdl.SDL_SCANCODE_RIGHT) @as(usize, 1) else 33)) % 34, .extend = self.extend } });
                return true;
            }
            if (event.key.mod & (sdl.SDL_KMOD_GUI | sdl.SDL_KMOD_CTRL) != 0) switch (event.key.scancode) {
                sdl.SDL_SCANCODE_Z => {
                    try self.request(if (self.extend) .redo else .undo);
                    return true;
                },
                sdl.SDL_SCANCODE_C => {
                    try self.request(.copy);
                    return true;
                },
                sdl.SDL_SCANCODE_V => {
                    try self.request(.paste);
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
    pub fn practiceTime(self: *Editor) u64 {
        return @intCast(@max(0, std.Io.Clock.awake.now(self.io).toMicroseconds()));
    }
    pub fn practiceLabels(self: *Editor) !*const @import("../components/cache.zig").LabelCache {
        const id = try self.model.id();
        const source_changed = if (self.source) |*source| source.refresh() else false;
        if (self.practice_labels == null or source_changed or !std.mem.eql(u8, &id, &self.practice_labels_id)) {
            const cache = @import("../components/cache.zig");
            var fixture_source: @import("practice_layout.zig").Fixture = .{};
            const replacement = if (self.source) |*source| try cache.buildProjectCache(self.gpa, source, self.model.document()) else try cache.buildProjectCache(self.gpa, &fixture_source, self.model.document());
            if (self.practice_labels) |*old| old.deinit();
            self.practice_labels = replacement;
            self.practice_labels_id = id;
        }
        return &self.practice_labels.?;
    }
    pub fn pausePractice(self: *Editor) void {
        if (!self.practice_active) return;
        self.practice.pause(self.practiceTime());
        if (self.practice.source == .draft) self.testing.stop();
        self.text.reset();
    }
    pub fn startPractice(self: *Editor, fresh: bool) !void {
        self.diagnostic = @splat(0);
        self.testing.stop();
        if (fresh) {
            var buffer: [8192]u8 = undefined;
            const practice_module = @import("practice.zig");
            const reference = if (self.practice_mode == 0) try practice_module.english(&buffer, self.practice_seed, ([_]usize{ 2, 5, 10 })[self.practice_level]) else practice_module.lessons[self.practice_level];
            try self.practice.load(reference, if (self.practice_source == 0) .os else .draft);
        } else self.practice.restart();
        self.practice_active = true;
        self.practice_drawn_len = 0;
        self.practice_scroll_at = null;
        self.practice_snapshot = try self.model.id();
        self.text.reset();
        self.last_text_sequence = null;
        if (self.practice.source == .draft) {
            if (self.testing.state != .prepared) {
                try self.testing.prepare(self.model.current.snapshot);
                self.practice.pause(self.practiceTime());
            } else {
                self.test_start = @intCast(std.Io.Clock.awake.now(self.io).toMicroseconds());
                try self.testing.start();
            }
        }
    }
    pub fn openAction(self: *Editor) void {
        self.ensureSession() catch |err| self.report(err);
        self.inspector_state.advanced = true;
    }
    pub fn ensureSession(self: *Editor) !void {
        if (self.edit_session) |*session| {
            if (!try session.stale(&self.model) and session.layer_index == self.model.layer and session.primary == self.model.primary and std.meta.eql(session.selected, self.model.selected)) return;
            if (session.dirty()) self.reportInspector(error.StaleInspectorSession);
        }
        self.edit_session = try Session.init(&self.model);
    }
    pub fn reportInspector(self: *Editor, err: anyerror) void {
        self.inspector_error = @splat(0);
        const name = @errorName(err);
        @memcpy(self.inspector_error[0..@min(name.len, self.inspector_error.len - 1)], name[0..@min(name.len, self.inspector_error.len - 1)]);
    }
    pub fn applySession(self: *Editor) !bool {
        const changed = try self.edit_session.?.apply(&self.model);
        self.edit_session = try Session.init(&self.model);
        self.inspector_error = @splat(0);
        self.inspector_state.conversion = false;
        return changed;
    }
    pub fn cancelSession(self: *Editor) !void {
        self.edit_session = try Session.init(&self.model);
        self.inspector_error = @splat(0);
        self.inspector_state.conversion = false;
    }
    pub fn request(self: *Editor, intent: Intent) !void {
        if (self.edit_session) |session| if (session.dirty()) {
            self.pending = intent;
            return;
        };
        try self.perform(intent);
    }
    pub fn resolvePending(self: *Editor, apply: bool) !void {
        if (apply) {
            _ = self.applySession() catch |err| {
                self.reportInspector(err);
                return;
            };
        } else try self.cancelSession();
        const intent = self.pending orelse return;
        self.pending = null;
        try self.perform(intent);
    }
    pub fn finishClose(self: *Editor, save_first: bool) !void {
        if (save_first) {
            try self.save();
            if (self.model.dirty()) return;
        } else try self.recover();
        self.should_close = true;
    }
    fn perform(self: *Editor, intent: Intent) !void {
        switch (intent) {
            .select => |value| self.model.select(value.index, value.extend),
            .layer => |index| self.model.layer = index,
            .profile => |index| try self.selectProfile(index),
            .duplicate => |index| {
                self.model.layer = index;
                try self.model.addLayer(true);
            },
            .delete => |index| try self.model.deleteLayer(index),
            .add_layer => try self.model.addLayer(false),
            .rename => try self.model.rename(std.mem.sliceTo(&self.rename_buffer, 0)),
            .undo => try self.model.undo(),
            .redo => try self.model.redo(),
            .copy => self.model.copy(),
            .paste => try self.model.paste(),
            .save => try self.save(),
            .paths => self.paths_open = true,
            .combo => self.combo_open = true,
            .callback => self.callback_open = true,
            .main_view => |selected| {
                self.pausePractice();
                self.testing.stop();
                self.text.reset();
                self.free_text.reset();
                self.free_pending = false;
                _ = self.preview.navigate(selected, false);
                self.main_view = selected;
                self.free_focus = selected == .try_it_out and self.try_mode == .free_typing;
                self.free_focus_requested = self.free_focus;
                dvui.focusWidget(null, null, null);
            },
            .flash => try self.requestFlash(),
            .build => if (!self.fixture) {
                try self.firmware.build(self.model.current.snapshot);
                self.auto_build.manual(try self.model.id());
            },
            .chord => |value| try self.model.assignChord(value.value, value.held, value.target),
            .close => if (self.model.dirty()) {
                self.close_requested = true;
            } else {
                self.should_close = true;
            },
        }
        self.edit_session = try Session.init(&self.model);
        self.syncRename();
    }
    pub fn draw(self: *Editor) !void {
        if (self.source) |*source| if (source.refresh()) {
            if (self.practice_labels) |*old| old.deinit();
            self.practice_labels = null;
        };
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
        const current_id = try self.model.id();
        if (self.free_snapshot) |previous| if (!std.mem.eql(u8, &previous, &current_id)) {
            self.testing.stop();
            self.free_failed = false;
            self.free_pending = false;
            self.preview.invalidate();
            self.preview_notice = "Draft changed · native typing continues.";
        };
        self.free_snapshot = current_id;
        self.testing.poll(current_id);
        self.firmware.poll(current_id);
        if (self.callback_state == .changed or self.callback_state == .missing) self.firmware.invalidateExternalSources();
        if (!self.fixture) self.finishPendingFlash(current_id) catch |err| self.report(err);
        if (!self.fixture) {
            self.auto_build.observe(current_id, @intCast(now));
            const blocked = switch (self.firmware.state) {
                .transferring, .transferred, .awaiting_reconnect, .building => true,
                else => self.bootloaderBusy() or self.callback_state == .changed or self.callback_state == .missing or self.callback_state == .failed,
            };
            if (self.auto_build.take(@intCast(now), blocked)) self.firmware.build(self.model.current.snapshot) catch |err| self.report(err);
        }
        if (self.text.refresh()) {
            self.pausePractice();
            self.testing.stop();
            self.text.reset();
            self.free_failed = false;
            self.free_pending = false;
            self.preview.invalidate();
            self.preview_notice = "Input source changed · typing test reset.";
        }
        if (self.testing.last) |output| if (self.last_text_sequence != output.sequence) {
            self.last_text_sequence = output.sequence;
            if (self.main_view == .try_it_out and self.try_mode == .typing_test and self.practice_active and self.practice.source == .draft and (self.practice.state == .ready or self.practice.state == .running)) {
                self.text.practiceOutput(output.commands, &self.practice, self.practiceTime()) catch |err| self.report(err);
            }
        };
        if (self.practice_active and self.practice.source == .draft and (self.testing.state == .stale or self.testing.state == .failed)) self.pausePractice();
        if (self.practice_active and self.practice.state == .complete) {
            const best = &self.practice_best[self.practice_mode][self.practice_level][self.practice_source];
            if (self.practice.scored) best.* = @max(best.*, self.practice.wpm(self.practiceTime()));
            if (self.practice.source == .draft) self.testing.stop();
        }
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
        self.canvas_width = available.w / system_scale / self.content_scale;
        self.canvas_height = available.h / system_scale / self.content_scale;
        current_window.snap_to_pixels = self.content_scale == 1;
        // Window zoom also covers floating dialogs, menus and input transforms.
        // DVUI applies it at the next frame boundary after a native resize.
        if (current_window.content_scale != self.content_scale) {
            current_window.content_scale = self.content_scale;
            dvui.refresh(null, @src(), null);
        }
        const canvas = dvui.box(@src(), .{}, .{ .min_size_content = .{ .w = self.canvas_width, .h = self.canvas_height }, .padding = .{}, .margin = .{}, .background = true, .color_fill = .{ .color = t.bg } });
        defer canvas.deinit();
        if (self.main_view == .try_it_out) {
            if (self.try_mode == .typing_test) {
                try @import("practice_drawer.zig").consumeInput(self, canvas.data(), self.practiceTime());
            }
        }
        try self.navigation(t);
        if (self.main_view == .editor) {
            const editor_content = dvui.box(@src(), .{}, .{ .rect = .{ .x = 0, .y = 52, .w = 1536, .h = 1024 }, .padding = .{} });
            defer editor_content.deinit();
            try self.toolbar(t);
            try self.sidebar(t);
            try self.keyboard(t);
            try self.inspector(t);
            self.host(t);
            try self.bottom(t);
        } else try self.tryItOut(t);
        if (self.paths_open) try self.paths(t);
        if (self.callback_open) try self.callbackDrawer(t);
        if (self.combo_open) try self.comboDrawer(t);
        if (self.overlay_open) {
            const child = dvui.osWindow(@src(), .{ .title = "Zigmkay LK7 Overlay — offline", .size = .{ .w = 760, .h = 370 }, .min_size = .{ .w = 340, .h = 220 } }, .{ .open_flag = &self.overlay_open });
            defer child.deinit();
            dvui.label(@src(), "LK7 / offline · no verified device profile", .{}, .{});
            _ = @import("../components/layout.zig");
            dvui.label(@src(), "The live overlay is available separately through --live.", .{}, .{});
        }
    }
    fn navigation(self: *Editor, t: Theme) !void {
        const bar = dvui.box(@src(), .{}, .{ .rect = .{ .x = 0, .y = 0, .w = self.canvas_width, .h = 52 }, .padding = .{}, .background = true, .color_fill = .{ .color = t.panel } });
        defer bar.deinit();
        if (ui.buttonEnabled(t, "Editor", "nav.editor", .{ .x = 18, .y = 7, .w = 125, .h = 38 }, self.main_view != .editor)) try self.request(.{ .main_view = .editor });
        if (ui.buttonEnabled(t, "Try it out", "nav.try", .{ .x = 153, .y = 7, .w = 145, .h = 38 }, self.main_view != .try_it_out)) try self.request(.{ .main_view = .try_it_out });
        const underline = dvui.box(@src(), .{}, .{ .rect = .{ .x = if (self.main_view == .editor) 18 else 153, .y = 47, .w = if (self.main_view == .editor) 125 else 145, .h = 3 }, .background = true, .color_fill = .{ .color = color(0x287AF2) } });
        underline.deinit();
    }
    pub fn chooseTryMode(self: *Editor, mode: @import("try_state.zig").Mode) void {
        if (mode == self.try_mode) return;
        self.pausePractice();
        self.testing.stop();
        self.text.reset();
        self.free_text.reset();
        self.free_pending = false;
        self.preview.chooseMode(mode);
        self.try_mode = mode;
        self.free_focus = mode == .free_typing;
        self.free_focus_requested = self.free_focus;
        dvui.focusWidget(null, null, null);
    }
    pub fn resetFree(self: *Editor) void {
        self.testing.stop();
        self.free_text.clear();
        self.last_text_sequence = null;
        self.free_pending = false;
        self.preview.release();
        self.free_focus = true;
        self.free_focus_requested = true;
        dvui.focusWidget(null, null, null);
    }
    fn tryItOut(self: *Editor, t: Theme) !void {
        const bounds: dvui.Rect = .{ .x = 15, .y = 64, .w = self.canvas_width - 30, .h = self.canvas_height - 79 };
        const content = dvui.box(@src(), .{}, .{ .rect = bounds, .padding = .all(18), .background = true, .color_fill = .{ .color = t.panel }, .corners = .all(12), .tag = "try.content" });
        defer content.deinit();
        const width = bounds.w - 36;
        label(t, self.model.document().name, .{ .x = 0, .y = 0, .w = width - 430, .h = 36 }, 25);
        if (button(t, "Free typing", "try.free", .{ .x = width - 330, .y = 0, .w = 150, .h = 38 })) self.chooseTryMode(.free_typing);
        if (button(t, "Typing Test", "try.test", .{ .x = width - 170, .y = 0, .w = 170, .h = 38 })) self.chooseTryMode(.typing_test);
        label(t, if (self.try_mode == .free_typing) "Normal keyboard input · companion follows verified device telemetry" else "Typing Test", .{ .x = 0, .y = 43, .w = width, .h = 24 }, 16);
        const details_height: f32 = if (self.test_details) 215 else 0;
        const work_height = bounds.h - 36 - 125 - details_height;
        if (self.try_mode == .typing_test) {
            try @import("practice_drawer.zig").draw(self, t, .{ .x = 0, .y = 80, .w = width, .h = work_height });
        } else {
            // Device firmware has already processed taps, holds and the layout.
            // Feed committed OS text directly into the ordinary DVUI widget.
            if (self.free_text.len < self.free_text.bytes.len) self.free_text.bytes[self.free_text.len] = 0;
            const field = dvui.widgetAlloc(dvui.TextEntryWidget);
            field.init(@src(), .{ .text = .{ .buffer = &self.free_text.bytes }, .placeholder = "Type here using your keyboard…" }, .{ .rect = .{ .x = 0, .y = 90, .w = width, .h = 90 }, .padding = .all(12), .font = fonts.font(self.free_text.value(), 30), .background = true, .color_fill = .{ .color = t.control }, .border = .all(1), .color_border = .{ .color = t.border }, .corners = .all(8), .tag = "free.input" });
            {
                defer field.deinit();
                if (self.free_focus_requested) {
                    dvui.focusWidget(field.data().id, null, null);
                    self.free_focus_requested = false;
                }
                field.processEvents();
                field.draw();
                self.free_text.len = field.textGet().len;
                self.free_text.cursor = field.textLayout.selection.cursor;
                self.free_focus = dvui.focusedWidgetId() == field.data().id;
            }
            if (button(t, "Reset text", "free.reset", .{ .x = 0, .y = 192, .w = 140, .h = 40 })) self.resetFree();
            if (button(t, "Connect companion", "free.connect", .{ .x = 155, .y = 192, .w = 225, .h = 40 })) self.live_requested = true;
            _ = dvui.checkbox(@src(), &self.practice_show_keyboard, "Show companion", options(t, .{ .x = width - 220, .y = 192, .w = 220, .h = 40 }, 16));
            label(t, self.preview_notice, .{ .x = 0, .y = 242, .w = width, .h = 28 }, 16);
            if (self.practice_show_keyboard) try @import("practice_drawer.zig").drawFreeCompanion(self, t, .{ .x = 0, .y = 285, .w = width, .h = work_height - 205 });
        }
        if (button(t, if (self.test_details) "Hide diagnostics" else "Diagnostics", "try.details", .{ .x = 0, .y = bounds.h - 36 - 38 - details_height, .w = 185, .h = 34 })) self.test_details = !self.test_details;
        if (self.test_details) try @import("test_drawer.zig").draw(self, t, .{ .x = 0, .y = bounds.h - 36 - details_height, .w = width, .h = details_height });
    }
    fn toolbar(self: *Editor, t: Theme) !void {
        const box = panel(t, .toolbar);
        defer box.deinit();
        label(t, "Zigmkay", .{ .x = 20, .y = 21, .w = 140, .h = 30 }, 23);
        label(t, "Keyboard", .{ .x = 140, .y = 7, .w = 85, .h = 18 }, 11);
        var board_choice: usize = 0;
        _ = dvui.dropdown(@src(), &.{"LK7"}, .{ .choice = &board_choice }, .{}, options(t, .{ .x = 140, .y = 25, .w = 80, .h = 30 }, 13));
        label(t, self.connection_text, .{ .x = 230, .y = 25, .w = 165, .h = 25 }, 12);
        var profile_names = p.profiles.names;
        profile_names[self.profile_choice] = self.model.document().name;
        var selected_profile = self.profile_choice;
        if (dvui.dropdown(@src(), &profile_names, .{ .choice = &selected_profile }, .{}, options(t, .{ .x = 405, .y = 16, .w = 270, .h = 36 }, 14))) {
            self.request(.{ .profile = selected_profile }) catch |err| self.report(err);
        }
        if (self.model.dirty()) label(t, "Unsaved", .{ .x = 686, .y = 27, .w = 85, .h = 23 }, 12);
        if (button(t, "Open / Export", "file.paths", .{ .x = 775, .y = 16, .w = 130, .h = 36 })) try self.request(.paths);
        if (button(t, "Undo", "edit.undo", .{ .x = 920, .y = 16, .w = 68, .h = 36 })) {
            try self.request(.undo);
        }
        if (button(t, "Redo", "edit.redo", .{ .x = 996, .y = 16, .w = 68, .h = 36 })) {
            try self.request(.redo);
        }
        if (button(t, "Save", "file.save", .{ .x = 1078, .y = 16, .w = 76, .h = 36 })) self.request(.save) catch |err| self.report(err);
        if (button(t, "Build", "firmware.build", .{ .x = 1166, .y = 16, .w = 110, .h = 36 })) {
            self.request(.build) catch |err| self.report(err);
        }
        if (button(t, "Flash", "firmware.inspect", .{ .x = 1288, .y = 16, .w = 110, .h = 36 })) {
            self.request(.flash) catch |err| self.report(err);
        }
        const firmware_status: []const u8 = switch (self.firmware.state) {
            .idle => "",
            .building => if (self.pending_flash.id != null) "Building · Flash queued…" else "Building…",
            .built => "Ready to flash",
            .transferring => "Flashing…",
            .transferred, .awaiting_reconnect => "Flashed · reconnecting…",
            .verified => "Flashed · connected",
            .stale => "Build again",
            .failed => "Firmware failed",
            .cancelled => "Build cancelled",
            .reconnect_timeout => "Flashed · reconnect keyboard",
        };
        if (firmware_status.len != 0) label(t, firmware_status, .{ .x = 1166, .y = 52, .w = 230, .h = 14 }, 10);
        _ = dvui.checkbox(@src(), &self.try_hid_bootloader, "Enter bootloader via HID", options(t, .{ .x = 927, .y = 49, .w = 230, .h = 18 }, 10).override(.{ .tag = "firmware.bootloader.toggle", .padding = .{} }));
        if (button(t, if (self.light) "Dark" else "Light", "theme.toggle", .{ .x = 1410, .y = 16, .w = 100, .h = 36 })) self.light = !self.light;
    }
    fn sidebar(self: *Editor, t: Theme) !void {
        const box = panel(t, .sidebar);
        defer box.deinit();
        label(t, "Layers", .{ .x = 16, .y = 18, .w = 160, .h = 25 }, 19);
        if (button(t, "+", "layer.add", .{ .x = 196, .y = 13, .w = 36, .h = 33 })) {
            try self.request(.add_layer);
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
                    try self.request(.{ .layer = i });
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
                    self.request(.{ .duplicate = i }) catch |err| self.report(err);
                }
                const del = try std.fmt.allocPrint(dvui.currentWindow().arena(), "layer.delete.{d}", .{i});
                if (button(t, "×", del, .{ .x = 197, .y = y + 14, .w = 25, .h = 30 })) {
                    self.request(.{ .delete = i }) catch |err| self.report(err);
                }
            }
        }
        label(t, "Selected layer name", .{ .x = 16, .y = 804, .w = 220, .h = 23 }, 13);
        const rename = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.rename_buffer } }, options(t, .{ .x = 16, .y = 832, .w = 215, .h = 34 }, 13));
        const enter = rename.enter_pressed;
        rename.deinit();
        if (enter or button(t, "Rename", "layer.rename", .{ .x = 16, .y = 876, .w = 90, .h = 33 })) self.request(.rename) catch |err| self.report(err);
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
        if (dvui.dropdown(@src(), &.{ "Keys", "Combos", "Encoders" }, .{ .choice = &self.view }, .{}, options(t, .{ .x = 626, .y = 15, .w = 150, .h = 36 }, 13))) {
            if (self.view == 1) try self.request(.combo);
            if (self.view == 2) self.report(error.LK7HasNoEncoderActions);
        }
        label(t, "LEFT · 17 keys", .{ .x = 140, .y = 72, .w = 180, .h = 24 }, 13);
        label(t, "RIGHT · 17 keys", .{ .x = 512, .y = 72, .w = 180, .h = 24 }, 13);
        for (physical.keys) |key| {
            const x = 18 + key.x * 63;
            const y = 108 + key.y * 63;
            const tag = try std.fmt.allocPrint(dvui.currentWindow().arena(), "key.select.{d}", .{key.key_index});
            var opts = options(t, .{ .x = x, .y = y, .w = 59, .h = 59 }, 20);
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
            const caption_length = std.unicode.utf8CountCodepoints(caption) catch caption.len;
            opts.font = fonts.font(caption, if (std.mem.indexOfScalar(u8, caption, '\n') != null) 13 else if (caption_length > 9) 9 else if (caption_length >= 4) 13 else 20);
            if (dvui.button(@src(), caption, .{}, opts)) {
                try self.request(.{ .select = .{ .index = key.key_index, .extend = self.extend } });
                if (self.testing.state == .running) {
                    const time = self.testTime();
                    self.testing.input(.{ .key_down = key.key_index }, time) catch |err| self.report(err);
                    self.testing.input(.{ .key_up = key.key_index }, time + 1000) catch |err| self.report(err);
                }
            }
            if (dvui.focusedWidgetId() == data.id) self.canvas_focus = true;
            self.chordDrop(&data, false, key.key_index);
            if (direct == null) label(t, "inherited", .{ .x = x + 7, .y = y + 50, .w = 48, .h = 8 }, 6);
        }
    }
    fn inspector(self: *Editor, t: Theme) !void {
        try inspector_ui.draw(self, t);
    }
    fn host(self: *Editor, t: Theme) void {
        const box = panel(t, .os);
        defer box.deinit();
        label(t, "OS keyboard", .{ .x = 20, .y = 18, .w = 205, .h = 25 }, 19);
        label(t, if (self.source) |*source| source.id() else "EurKEY fixture · ANSI", .{ .x = 225, .y = 23, .w = 320, .h = 25 }, 12);
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
        if (button(shift_theme, "Shift", "os.shift", .{ .x = 622, .y = 15, .w = 70, .h = 33 })) self.shift = !self.shift;
        if (button(option_theme, "Option", "os.option", .{ .x = 699, .y = 15, .w = 73, .h = 33 })) self.option = !self.option;
        for (labels.rows, 0..) |row, ri| {
            var x: f32 = 14;
            for (row, 0..) |key, ki| {
                var buffer: [64]u8 = undefined;
                var modified_buffer: [64]u8 = undefined;
                var caption = labels.keycapUsage(labels.running_host, key.code, &buffer);
                if (self.source == null and key.code >= 4 and key.code <= 29 and !self.shift) {
                    buffer[0] = 'a' + key.code - 4;
                    caption = buffer[0..1];
                }
                var modified: []const u8 = if (key.name.len == 0 and self.option) @import("fixture.zig").optionLabel(key.code, self.shift) else if (key.name.len == 0 and self.shift) @import("fixture.zig").shiftLabel(key.code) else "";
                if (self.source) |*source| if (key.name.len == 0 and key.code >= 4 and key.code <= 56 and (key.code < 40 or key.code > 44)) {
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
                var opts = options(t, .{ .x = x, .y = 58 + @as(f32, @floatFromInt(ri)) * 38, .w = 47.5 * key.units - 3, .h = 35 }, if (caption.len > 3) 11 else 18);
                opts.padding = .all(2);
                opts.font = fonts.font(caption, if (caption.len > 3) 11 else 18);
                opts.id_extra = ri * 100 + ki;
                opts.background = true;
                opts.gravity_x = 0.5;
                opts.gravity_y = 0.5;
                opts.border = .all(1);
                if (modified.len != 0) caption = modified;
                opts.font = fonts.font(caption, if (caption.len > 3) 11 else 18);
                opts.tag = std.fmt.allocPrint(dvui.currentWindow().arena(), "os.key.{d}", .{key.code}) catch unreachable;
                self.chordSource(key.code, caption, opts);
                x += 47.5 * key.units;
            }
        }
    }
    pub fn chordDrop(self: *Editor, data: *dvui.WidgetData, held: bool, target: ?usize) void {
        const chord = self.drag_chord orelse return;
        if (!dvui.dragName("key_chord")) return;
        for (dvui.events()) |*event| {
            if (!dvui.eventMatch(event, .{ .id = data.id, .r = data.borderRectScale().r, .drag_name = "key_chord" })) continue;
            if (event.evt == .mouse) {
                const mouse = event.evt.mouse;
                if (mouse.action == .position) data.focusBorder();
                if (mouse.action == .release and mouse.button == .left) {
                    event.handle(@src(), data);
                    dvui.dragEnd();
                    self.drag_chord = null;
                    if (target != null) {
                        self.request(.{ .chord = .{ .value = chord, .held = held, .target = target } }) catch |err| self.report(err);
                    } else self.stageChord(chord, held) catch |err| self.reportInspector(err);
                }
            }
        }
    }
    pub fn stageChord(self: *Editor, chord: @import("assignment.zig").Chord, held: bool) !void {
        try self.ensureSession();
        if (held) {
            if (chord.tap_keycode < 224 or chord.tap_keycode > 231) return error.HoldRequiresModifier;
            const bit: u3 = @intCast(chord.tap_keycode - 224);
            self.edit_session.?.toggleModifier(.hold, bit);
        } else self.edit_session.?.mutate(.{ .tap_key = chord });
    }
    fn chordSource(self: *Editor, code: u8, caption: []const u8, opts: dvui.Options) void {
        var key: dvui.ButtonWidget = undefined;
        key.init(@src(), .{}, opts);
        defer key.deinit();
        for (dvui.events()) |*event| {
            if (!key.matchEvent(event) or event.evt != .mouse) continue;
            const mouse = event.evt.mouse;
            if (mouse.action == .press and mouse.button == .left) {
                event.handle(@src(), key.data());
                dvui.captureMouse(key.data(), event.num);
                dvui.focusWidget(key.data().id, null, null);
                self.drag_chord = .{ .tap_keycode = code, .tap_modifiers = .{ .left_shift = self.shift, .left_alt = self.option } };
                dvui.dragPreStart(.left, mouse.p, .{ .name = "key_chord", .cursor = .crosshair });
            } else if (mouse.action == .motion and dvui.captured(key.data().id)) {
                if (dvui.dragging(mouse.p, "key_chord")) |_| {
                    event.handle(@src(), key.data());
                    dvui.captureMouse(null, event.num);
                }
            } else if (mouse.action == .release and mouse.button == .left and dvui.captured(key.data().id)) {
                event.handle(@src(), key.data());
                dvui.captureMouse(null, event.num);
                dvui.dragEnd();
                if (self.drag_chord) |chord| self.request(.{ .chord = .{ .value = chord, .held = false, .target = null } }) catch |err| self.report(err);
                self.drag_chord = null;
            } else if (mouse.action == .position) key.hover = true;
        }
        key.drawBackground();
        dvui.labelNoFmt(@src(), caption, .{ .align_x = 0.5, .align_y = 0.5 }, .{ .expand = .both, .gravity_x = 0.5, .gravity_y = 0.5, .font = opts.font, .color_text = opts.color_text, .padding = .{}, .margin = .{} });
        key.drawFocus();
    }
    fn bottom(self: *Editor, t: Theme) !void {
        {
            const box = panel(t, .callbacks);
            defer box.deinit();
            label(t, "Callbacks", .{ .x = 18, .y = 12, .w = 200, .h = 24 }, 16);
            if (button(t, if (self.model.document().callbacks.len > 0) self.model.document().callbacks[0].binding else "Attach source…", "callback.attach", .{ .x = 154, .y = 10, .w = 249, .h = 30 })) try self.request(.callback);
            label(t, if (self.model.document().callbacks.len == 0) "No attached source · external Zig files" else switch (self.callback_state) {
                .changed => "External source changed · refresh explicitly",
                .missing => "External source missing · snapshot preserved",
                .failed => "Callback diagnostic · open Manage",
                else => "Source snapshot preserved · external Zig",
            }, .{ .x = 18, .y = 49, .w = 750, .h = 24 }, 12);
            if (button(t, "Open externally", "callback.external", .{ .x = 623, .y = 9, .w = 150, .h = 31 })) {
                if (self.model.document().callbacks.len == 0) try self.request(.callback) else self.openCallback(0) catch |err| self.report(err);
            }
        }
        if (self.firmware.state == .failed) {
            const logs = self.firmware.diagnostic.items;
            const start = if (std.mem.indexOf(u8, logs, "error:")) |index| index + 6 else 0;
            const line = logs[start..];
            const end = std.mem.indexOfScalar(u8, line, '\n') orelse line.len;
            label(t, std.mem.trim(u8, line[0..end], " \r"), .{ .x = 294, .y = 490, .w = 815, .h = 25 }, 12);
        } else if (self.diagnostic[0] != 0) label(t, std.mem.sliceTo(&self.diagnostic, 0), .{ .x = 294, .y = 490, .w = 815, .h = 25 }, 12) else if (self.firmware.state == .transferring and self.bootloader_status.len != 0) label(t, self.bootloader_status, .{ .x = 294, .y = 490, .w = 815, .h = 25 }, 12);
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
        const window = ui.editDrawer(@src(), t, 800);
        defer window.deinit();
        {
            const area = dvui.scrollArea(@src(), .{}, .{ .rect = .{ .x = 0, .y = 0, .w = window.data().rect.w - 36, .h = window.data().rect.h - 112 } });
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
                self.openProject(std.mem.sliceTo(&self.project_path, 0)) catch |err| self.report(err);
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
        }
        if (ui.button(t, "Close", "file.close", .{ .x = 0, .y = window.data().rect.h - 86, .w = 100, .h = 40 })) self.paths_open = false;
    }
    fn save(self: *Editor) !void {
        if (self.project_path[0] == 0) {
            if (self.fixture) {
                self.paths_open = true;
                return;
            }
            const directory = try std.fs.path.join(self.gpa, &.{ self.testing.root, "projects", @tagName(@as(p.profiles.Profile, @enumFromInt(self.profile_choice))) });
            defer self.gpa.free(directory);
            if (directory.len >= self.project_path.len) return error.InvalidProjectPath;
            @memcpy(self.project_path[0..directory.len], directory);
        }
        var dir = try std.Io.Dir.cwd().createDirPathOpen(self.io, std.mem.sliceTo(&self.project_path, 0), .{});
        defer dir.close(self.io);
        try self.model.save(self.io, dir);
        try self.rememberProject();
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
};

pub fn run(init: std.process.Init, args: []const []const u8) !void {
    var open_practice = false;
    var requested_live = false;
    var fixture = false;
    var light = false;
    var screenshot: ?[]const u8 = null;
    var reference_path: ?[]const u8 = null;
    var golden_path: ?[]const u8 = null;
    var state: scenario.State = .normal;
    var interactions = false;
    var flash_ui_check = false;
    var density: ?u8 = null;
    var requested_size: ?dvui.Size = null;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--practice")) open_practice = true else if (std.mem.eql(u8, args[i], "--light")) light = true else if (std.mem.eql(u8, args[i], "--fixture")) fixture = true else if (std.mem.eql(u8, args[i], "--screenshot") and i + 1 < args.len) {
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
        } else if (std.mem.eql(u8, args[i], "--live")) {
            requested_live = true;
        } else if (std.mem.eql(u8, args[i], "--flash-ui-check")) {
            flash_ui_check = true;
        } else if (std.mem.eql(u8, args[i], "--interactions")) {
            interactions = true;
            fixture = true;
        } else return error.Usage;
    }
    if (requested_live and fixture) return error.IncompatibleModes;
    if (flash_ui_check and (fixture or screenshot != null or interactions)) return error.IncompatibleModes;
    if (density != null and screenshot == null) return error.DensityRequiresScreenshot;
    if (state != .normal and screenshot == null) return error.ScenarioRequiresScreenshot;
    const window_size = requested_size orelse if (screenshot != null) dvui.Size{ .w = 1536, .h = 1024 } else dvui.Size{ .w = geometry.initial.w, .h = geometry.initial.h };
    var backend = try @import("window.zig").init(.{ .io = init.io, .environ_map = init.environ_map, .size = window_size, .min_size = .{ .w = geometry.minimum.w, .h = geometry.minimum.h }, .title = "Zigmkay — LK7 Keymap Editor", .hidden = screenshot != null, .vsync = true, .persist_window_geometry = false }, density == 1);
    defer backend.deinit();
    if (screenshot == null) {
        try @import("window_placement.zig").place(backend.window, true);
        try @import("window_placement.zig").reveal(backend.window);
    }
    var open = true;
    var window = try dvui.Window.init(@src(), init.gpa, backend.backend(), .{ .theme = if (light) dvui.Theme.builtin.adwaita_light else dvui.Theme.builtin.adwaita_dark, .open_flag = &open });
    defer window.deinit();
    var editor = try Editor.init(init, fixture);
    defer editor.deinit();
    var live_check = @import("flash_ui_check.zig").Check{};
    defer live_check.deinit();
    var reconnect: ?@import("../live_adapter.zig").Driver(@import("../main.zig").Native) = null;
    defer if (reconnect) |*driver| driver.disconnect(driver.transport.now());
    var reconnect_labels: ?@import("../components/cache.zig").LabelCache = null;
    defer if (reconnect_labels) |*native_labels| native_labels.deinit();
    var reconnect_identity: ?@import("device-protocol").Identity = null;
    if (flash_ui_check) {
        editor.model.deinit();
        editor.model = try Model.init(init.gpa, .danish);
        editor.syncRename();
    }
    editor.light = light;
    editor.live_requested = requested_live;
    editor.window_id = sdl.SDL_GetWindowID(backend.window);
    editor.backend_window = backend.window;
    if (open_practice) {
        editor.main_view = .try_it_out;
        editor.try_mode = .typing_test;
    }
    scenario.setup(&editor, state) catch |err| editor.report(err);
    const scenario_history = editor.model.undo_stack.items.len;
    var native_input_check: @import("native_input_check.zig").Driver = .{};
    defer native_input_check.deinit(init.gpa);
    var native_live_check: @import("live_keyboard.zig").NativeDriver = .{};
    if (state == .native_live_input) try @import("live_keyboard.zig").NativeDriver.setup(&editor);
    var frames: usize = 0;
    var interaction_snapshot: [32]u8 = @splat(0);
    var interaction_originals: [2]?p.Action = .{ null, null };
    var interaction_undo_count: usize = 0;
    var practice_clipboard: ?[]u8 = null;
    defer if (practice_clipboard) |bytes| init.gpa.free(bytes);
    while (open) : (frames += 1) {
        try window.begin(window.beginWait(false));
        try @import("events.zig").pump(&backend, &window, &editor);
        if (flash_ui_check) try live_check.beforeDraw(&editor, &window);
        if (state == .free_input) try scenario.freeInteraction(&editor, &window, frames, scenario_history);
        if (state == .native_free_input) try native_input_check.beforeDraw(&editor, &window, &backend, frames);
        if (state == .native_live_input) try native_live_check.beforeDraw(&editor, &window, frames);
        if (state == .practice_guidance) switch (frames) {
            3 => _ = try window.addEventText(.{ .text = "a" }),
            4 => {
                if (@import("practice_view.zig").focus(&editor.practice) != 1 or !editor.practice_show_keyboard) return error.PracticeGuideDidNotFollowInput;
                const keyboard = dvui.tagGet("practice.keyboard") orelse return error.PracticeKeyboardMissing;
                if (!keyboard.visible) return error.PracticeKeyboardClipped;
            },
            5 => try scenario.click(&window, "practice.keyboard.toggle", window.natural_scale, false),
            6 => try scenario.click(&window, "practice.keyboard.toggle", window.natural_scale, true),
            8 => {
                if (editor.practice_show_keyboard or editor.practice.len != 1) return error.PracticeKeyboardToggleFailed;
                _ = try window.addEventKey(.{ .code = .enter, .action = .down, .mod = if (@import("builtin").os.tag == .macos) .lcommand else .lcontrol });
            },
            9 => {
                _ = try window.addEventKey(.{ .code = .space, .action = .down, .mod = .none });
                _ = try window.addEventText(.{ .text = " " });
            },
            11 => {
                if (editor.practice_show_keyboard or editor.practice.len != 2) return error.PracticeSpaceActivatedControl;
            },
            12 => try scenario.click(&window, "practice.keyboard.toggle", window.natural_scale, false),
            13 => try scenario.click(&window, "practice.keyboard.toggle", window.natural_scale, true),
            15 => {
                if (!editor.practice_show_keyboard or @import("practice_view.zig").focus(&editor.practice) != 2) return error.PracticeKeyboardRestoreFailed;
                const keyboard = dvui.tagGet("practice.keyboard") orelse return error.PracticeKeyboardMissing;
                if (!keyboard.visible) return error.PracticeKeyboardClipped;
                std.log.info("Practice companion visibility, next letter and Space input after toggle passed", .{});
            },
            else => {},
        };
        if (state == .practice_live and frames == 3) {
            editor.practice_live_state.?.highest_layer = 1;
            editor.practice_live_state.?.active_layers = 3;
            editor.practice_live_state.?.pressed[10] = false;
            editor.practice_live_state.?.pressed[32] = true;
        }
        if (state == .practice_scroll) switch (frames) {
            3 => _ = try window.addEventText(.{ .text = @import("practice.zig").lessons[1][0..300] }),
            5 => {
                const current = dvui.tagGet("practice.current") orelse return error.PracticeCurrentLineMissing;
                if (!current.visible) return error.PracticeCurrentLineClipped;
            },
            6 => _ = try window.addEventText(.{ .text = @import("practice.zig").lessons[1][300..] }),
            8 => {
                if (editor.practice.state != .complete or editor.practice.len != editor.practice.reference_len) return error.PracticeZigCompletionFailed;
                std.log.info("Practice complete Zig file and current-line scrolling passed", .{});
            },
            else => {},
        };
        if (state == .practice_input) switch (frames) {
            3 => _ = try window.addEventText(.{ .text = "x" }),
            4 => _ = try window.addEventKey(.{ .code = .backspace, .action = .down, .mod = .none }),
            5 => _ = try window.addEventText(.{ .text = "a" }),
            6 => _ = try window.addEventKey(.{ .code = .enter, .action = .down, .mod = .none }),
            7 => _ = try window.addEventKey(.{ .code = .tab, .action = .down, .mod = .none }),
            8 => _ = try window.addEventText(.{ .text = "b" }),
            10 => {
                if (editor.practice.state != .complete or editor.practice.corrected != 1 or editor.practice.attempts != 8) return error.PracticeInputScenarioFailed;
                std.log.info("Practice committed text, correction, Tab/newline and completion passed", .{});
            },
            11 => try scenario.click(&window, "practice.start", window.natural_scale, false),
            12 => try scenario.click(&window, "practice.start", window.natural_scale, true),
            13 => _ = try window.addEventText(.{ .text = "a" }),
            14 => try scenario.click(&window, "practice.pause", window.natural_scale, false),
            15 => try scenario.click(&window, "practice.pause", window.natural_scale, true),
            16 => {
                if (editor.practice.state != .paused or editor.practice.len != 1) return error.PracticePauseScenarioFailed;
                _ = try window.addEventText(.{ .text = "ignored" });
            },
            17 => try scenario.click(&window, "practice.pause", window.natural_scale, false),
            18 => try scenario.click(&window, "practice.pause", window.natural_scale, true),
            19 => _ = try window.addEventKey(.{ .code = .enter, .action = .down, .mod = .none }),
            20 => _ = try window.addEventKey(.{ .code = .tab, .action = .down, .mod = .none }),
            21 => _ = try window.addEventText(.{ .text = "b" }),
            23 => {
                if (editor.practice.state != .complete or editor.practice.attempts != 7 or editor.practice.corrected != 0) return error.PracticeResumeScenarioFailed;
                std.log.info("Practice restart, pause, ignored paused input and resume passed", .{});
            },
            24 => try scenario.click(&window, "practice.start", window.natural_scale, false),
            25 => try scenario.click(&window, "practice.start", window.natural_scale, true),
            26 => {
                var event = std.mem.zeroes(sdl.SDL_Event);
                event.type = sdl.SDL_EVENT_WINDOW_FOCUS_LOST;
                event.window.windowID = editor.window_id;
                _ = try editor.raw(event);
            },
            27 => {
                if (editor.practice.state != .paused or editor.practice.len != 0) return error.PracticeFocusLossScenarioFailed;
                var event = std.mem.zeroes(sdl.SDL_Event);
                event.type = sdl.SDL_EVENT_WINDOW_FOCUS_GAINED;
                event.window.windowID = editor.window_id;
                _ = try editor.raw(event);
                if (editor.practice.state != .paused) return error.FocusRecoveryResumedPractice;
                try scenario.click(&window, "practice.pause", window.natural_scale, false);
            },
            28 => try scenario.click(&window, "practice.pause", window.natural_scale, true),
            29 => {
                practice_clipboard = try init.gpa.dupe(u8, dvui.clipboardText());
                dvui.clipboardTextSet("a\n    b");
                _ = try window.addEventKey(.{ .code = .v, .action = .down, .mod = if (@import("builtin").os.tag == .macos) .lcommand else .lcontrol });
            },
            31 => {
                dvui.clipboardTextSet(practice_clipboard.?);
                if (editor.practice.state != .complete or editor.practice.scored) return error.PracticePasteScenarioFailed;
                std.log.info("Practice focus loss and unscored native paste passed", .{});
            },
            else => {},
        };
        if (state == .advanced and frames == 3) {
            const bounds = geometry.panel(.inspector);
            _ = try window.addEventMouseMotion(.{ .pt = .{ .x = (bounds.x + 250) * window.natural_scale, .y = (bounds.y + 600) * window.natural_scale } });
            _ = try window.addEventMouseWheel(-600, .vertical, .mouse);
        }
        if (state == .key_search) switch (frames) {
            3 => try scenario.click(&window, "inspector.search", window.natural_scale, false),
            4 => try scenario.click(&window, "inspector.search", window.natural_scale, true),
            5 => _ = try window.addEventKey(.{ .code = .a, .action = .down, .mod = if (@import("builtin").os.tag == .macos) .lcommand else .lcontrol }),
            6 => _ = try window.addEventText(.{ .text = "page" }),
            8 => try scenario.click(&window, "inspector.result.0", window.natural_scale, false),
            9 => try scenario.click(&window, "inspector.result.0", window.natural_scale, true),
            else => {},
        };
        if (state == .key_drag) switch (frames) {
            3 => try scenario.click(&window, "os.shift", window.natural_scale, false),
            4 => try scenario.click(&window, "os.shift", window.natural_scale, true),
            5 => try scenario.click(&window, "os.key.4", window.natural_scale, false),
            6 => try scenario.move(&window, "key.select.10"),
            8 => try scenario.click(&window, "key.select.10", window.natural_scale, true),
            11 => try scenario.click(&window, "os.key.5", window.natural_scale, false),
            12 => try scenario.move(&window, "inspector.tap"),
            13 => try scenario.click(&window, "inspector.tap", window.natural_scale, true),
            15 => try scenario.click(&window, "os.key.225", window.natural_scale, false),
            16 => try scenario.move(&window, "inspector.hold"),
            17 => try scenario.click(&window, "inspector.hold", window.natural_scale, true),
            18 => try scenario.click(&window, "advanced.apply", window.natural_scale, false),
            19 => try scenario.click(&window, "advanced.apply", window.natural_scale, true),
            else => {},
        };
        if (interactions) switch (frames) {
            3 => try scenario.click(&window, "key.select.31", window.natural_scale, false),
            4 => try scenario.click(&window, "key.select.31", window.natural_scale, true),
            6 => try scenario.click(&window, "layer.duplicate.1", window.natural_scale, false),
            7 => try scenario.click(&window, "layer.duplicate.1", window.natural_scale, true),
            8 => try scenario.click(&window, "firmware.bootloader.toggle", window.natural_scale, false),
            9 => try scenario.click(&window, "firmware.bootloader.toggle", window.natural_scale, true),
            10 => if (editor.try_hid_bootloader) return error.BootloaderToggleFailed,
            11 => try scenario.click(&window, "edit.undo", window.natural_scale, false),
            12 => try scenario.click(&window, "edit.undo", window.natural_scale, true),
            14 => try scenario.click(&window, "edit.redo", window.natural_scale, false),
            15 => try scenario.click(&window, "edit.redo", window.natural_scale, true),
            16 => try scenario.click(&window, "firmware.bootloader.toggle", window.natural_scale, false),
            17 => try scenario.click(&window, "firmware.bootloader.toggle", window.natural_scale, true),
            18 => try scenario.click(&window, "inspector.tap", window.natural_scale, false),
            19 => try scenario.click(&window, "inspector.tap", window.natural_scale, true),
            20 => editor.edit_session.?.mutate(.{ .replace = .{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } } }),
            22 => try scenario.click(&window, "advanced.apply", window.natural_scale, false),
            23 => try scenario.click(&window, "advanced.apply", window.natural_scale, true),
            27 => {
                try editor.request(.{ .layer = 0 });
                try editor.request(.{ .select = .{ .index = 10, .extend = false } });
                try editor.model.assignChord(.{ .tap_keycode = 227 }, true, 10);
                editor.edit_session = null;
                try editor.request(.{ .select = .{ .index = 11, .extend = true } });
                interaction_snapshot = try editor.model.id();
                interaction_originals = .{ editor.model.document().layers[0].actions[10], editor.model.document().layers[0].actions[11] };
                interaction_undo_count = editor.model.undo_stack.items.len;
            },
            29 => try scenario.click(&window, "inspector.modifier.hold.3", window.natural_scale, false),
            30 => try scenario.click(&window, "inspector.modifier.hold.3", window.natural_scale, true),
            31 => {
                if (!editor.edit_session.?.dirty()) return error.ModifierClickDidNotStageEdit;
                if (!std.mem.eql(u8, &interaction_snapshot, &(try editor.model.id()))) return error.InspectorChangedDocumentBeforeApply;
                const drafts = editor.edit_session.?.drafts;
                if (@import("session.zig").tapPart(drafts[10]).key_press.?.tap_keycode != 4 or @import("session.zig").tapPart(drafts[11]).key_press.?.tap_keycode != 22) return error.BulkInspectorLostTap;
            },
            32 => try scenario.click(&window, "key.select.12", window.natural_scale, false),
            33 => try scenario.click(&window, "key.select.12", window.natural_scale, true),
            34 => if (editor.pending == null or editor.model.primary != 11) {
                std.log.err("Pending selection: primary={d}, pending={any}, dirty={any}, modifiers={any}/{any}", .{ editor.model.primary, editor.pending, editor.edit_session.?.dirty(), @import("session.zig").holdPart(editor.edit_session.?.drafts[10]).hold_modifiers, @import("session.zig").holdPart(editor.edit_session.?.drafts[11]).hold_modifiers });
                return error.PendingSelectionLostDraft;
            },
            35 => try scenario.click(&window, "pending.keep", window.natural_scale, false),
            36 => try scenario.click(&window, "pending.keep", window.natural_scale, true),
            37 => if (editor.pending != null or !editor.edit_session.?.dirty()) return error.PendingKeepLostDraft,
            38 => try scenario.click(&window, "key.select.12", window.natural_scale, false),
            39 => try scenario.click(&window, "key.select.12", window.natural_scale, true),
            40 => try scenario.click(&window, "pending.apply", window.natural_scale, false),
            41 => try scenario.click(&window, "pending.apply", window.natural_scale, true),
            42 => {
                if (editor.model.primary != 12 or editor.model.undo_stack.items.len != interaction_undo_count + 1) return error.PendingApplyNotAtomic;
                const actions = editor.model.document().layers[0].actions;
                if (!@import("session.zig").holdPart(actions[10]).hold_modifiers.left_gui or !@import("session.zig").holdPart(actions[11]).hold_modifiers.left_gui) return error.BulkInspectorModifierFailed;
            },
            43 => try scenario.click(&window, "edit.undo", window.natural_scale, false),
            44 => try scenario.click(&window, "edit.undo", window.natural_scale, true),
            45 => {
                if (!std.meta.eql(interaction_originals[0], editor.model.document().layers[0].actions[10]) or !std.meta.eql(interaction_originals[1], editor.model.document().layers[0].actions[11])) return error.BulkInspectorUndoFailed;
            },
            46 => try scenario.click(&window, "edit.redo", window.natural_scale, false),
            47 => try scenario.click(&window, "edit.redo", window.natural_scale, true),
            48 => try scenario.click(&window, "inspector.remove.tap.key", window.natural_scale, false),
            49 => try scenario.click(&window, "inspector.remove.tap.key", window.natural_scale, true),
            50 => if (!editor.edit_session.?.dirty() or editor.model.action().? == .none) return error.ChipRemovalNotStaged,
            51 => try scenario.click(&window, "advanced.cancel", window.natural_scale, false),
            52 => try scenario.click(&window, "advanced.cancel", window.natural_scale, true),
            53 => if (editor.edit_session.?.dirty()) return error.InspectorCancelFailed,
            56 => {
                editor.edit_session.?.mutate(.{ .mode = .repeat });
                editor.edit_session.?.mutate(.{ .repeat_interval = 0 });
                interaction_snapshot = try editor.model.id();
                interaction_undo_count = editor.model.undo_stack.items.len;
            },
            57 => try scenario.click(&window, "advanced.apply", window.natural_scale, false),
            58 => try scenario.click(&window, "advanced.apply", window.natural_scale, true),
            59 => if (editor.inspector_error[0] == 0 or editor.model.undo_stack.items.len != interaction_undo_count or !std.mem.eql(u8, &interaction_snapshot, &(try editor.model.id()))) return error.InvalidInspectorApplyChangedHistory,
            60 => try scenario.click(&window, "advanced.cancel", window.natural_scale, false),
            61 => try scenario.click(&window, "advanced.cancel", window.natural_scale, true),
            62 => editor.edit_session.?.mutate(.unassign),
            63 => try scenario.click(&window, "key.select.13", window.natural_scale, false),
            64 => try scenario.click(&window, "key.select.13", window.natural_scale, true),
            65 => try scenario.click(&window, "pending.discard", window.natural_scale, false),
            66 => try scenario.click(&window, "pending.discard", window.natural_scale, true),
            67 => {
                if (editor.model.primary != 13 or !std.mem.eql(u8, &interaction_snapshot, &(try editor.model.id()))) return error.PendingDiscardChangedDocument;
                try editor.request(.{ .select = .{ .index = 12, .extend = false } });
                try editor.ensureSession();
                inspector_ui.add(&editor, .{ .media = .VolumeUp });
                inspector_ui.add(&editor, .one_shot);
            },
            69 => try scenario.click(&window, "inspector.remove.tap.media", window.natural_scale, false),
            70 => try scenario.click(&window, "inspector.remove.tap.media", window.natural_scale, true),
            71 => try scenario.click(&window, "inspector.remove.tap.one_shot", window.natural_scale, false),
            72 => try scenario.click(&window, "inspector.remove.tap.one_shot", window.natural_scale, true),
            73 => {
                const tap = @import("session.zig").tapPart(editor.edit_session.?.first());
                if (tap.media_key != null or tap.one_shot != null or tap.key_press == null) return error.InspectorComponentRemovalLostTap;
            },
            74 => try scenario.click(&window, "advanced.cancel", window.natural_scale, false),
            75 => try scenario.click(&window, "advanced.cancel", window.natural_scale, true),
            76 => if (editor.edit_session.?.dirty() or editor.model.undo_stack.items.len != interaction_undo_count) return error.InspectorCancelAddedHistory,
            77 => try scenario.click(&window, "edit.copy", window.natural_scale, false),
            78 => try scenario.click(&window, "edit.copy", window.natural_scale, true),
            79 => try scenario.click(&window, "edit.paste", window.natural_scale, false),
            80 => try scenario.click(&window, "edit.paste", window.natural_scale, true),
            81 => if (!editor.model.clipboard_set or editor.edit_session.?.dirty() or editor.model.undo_stack.items.len != interaction_undo_count) return error.InspectorClipboardChangedHistory,
            else => {},
        };
        editor.draw() catch |err| {
            if (err == error.OutOfMemory) return err;
            editor.report(err);
        };
        if (state == .native_free_input) {
            native_input_check.drawReference(frames);
            try native_input_check.afterDraw(&editor, frames);
        }
        if (state == .native_live_input) try native_live_check.afterDraw(&editor, frames);
        if (flash_ui_check and try live_check.afterDraw(&editor)) {
            _ = try window.end(.{});
            break;
        }
        if (!fixture) {
            if (editor.live_requested) {
                editor.live_requested = false;
                if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
                var profile = try p.snapshot.clone(init.gpa, editor.model.current.snapshot);
                defer profile.deinit();
                const expected = try p.snapshot.identity(init.gpa, profile.snapshot, p.profiles.board);
                var native_labels = try @import("../components/cache.zig").buildProjectCache(init.gpa, &editor.source.?, profile.snapshot.document);
                errdefer native_labels.deinit();
                var seed: u32 = undefined;
                try init.io.randomSecure(std.mem.asBytes(&seed));
                const driver = try @import("../live_adapter.zig").Driver(@import("../main.zig").Native).init(.{ .io = init.io }, expected, seed, null);
                if (reconnect) |*old| old.disconnect(old.transport.now());
                if (reconnect_labels) |*old| old.deinit();
                reconnect = driver;
                reconnect_labels = native_labels;
                reconnect_identity = expected;
            }
            if (editor.bootloader_requested) if (reconnect) |*driver| driver.disconnect(driver.transport.now());
            editor.pollBootloader(null);
            if (!flash_ui_check and !editor.bootloaderBusy()) {
                if (editor.firmware.expectedIdentity() orelse if (reconnect) |driver| driver.session.expected else null) |expected| {
                    if (reconnect == null) {
                        if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
                        var seed: u32 = undefined;
                        try init.io.randomSecure(std.mem.asBytes(&seed));
                        reconnect = try @import("../live_adapter.zig").Driver(@import("../main.zig").Native).init(.{ .io = init.io }, expected, seed, null);
                    }
                    const driver = &reconnect.?;
                    const now = driver.transport.now();
                    if (!std.meta.eql(expected, driver.session.expected)) {
                        driver.disconnect(now);
                        driver.session = try @import("companion-model").Session.init(expected);
                        driver.retry_at = now;
                    }
                    if (reconnect_identity == null or !std.meta.eql(reconnect_identity.?, expected)) {
                        const native_labels = try @import("../components/cache.zig").buildProjectCache(init.gpa, &editor.source.?, editor.firmware.frozen.?.snapshot.document);
                        if (reconnect_labels) |*old| old.deinit();
                        reconnect_labels = native_labels;
                        reconnect_identity = expected;
                    }
                    driver.poll(now);
                    const verified = driver.session.phase == .live;
                    editor.practice_live_labels = if (verified) &reconnect_labels.? else null;
                    editor.practice_live_state = if (verified) driver.session.state else null;
                    editor.practice_live_profile = expected.profile_id;
                    editor.practice_live_stale = !verified or driver.session.stale;
                    const coherent = driver.session.phase == .live and !driver.session.stale;
                    editor.firmware.observeRunning(if (coherent) driver.session.expected else null, coherent, now);
                }
            }
        }
        if (editor.should_close) open = false;
        if (frames == 2 and screenshot != null) {
            if (editor.main_view == .editor) try scenario.verifyPanels(window.natural_scale) else try scenario.verifyTryItOut(editor.try_mode == .typing_test);
        }
        if (frames == 10 and state == .key_search) {
            if (@import("session.zig").tapPart(editor.edit_session.?.first()).key_press.?.tap_keycode != 75) return error.KeySearchSelectionFailed;
            const apply = dvui.tagGet("advanced.apply") orelse return error.MissingApplyButton;
            if (!apply.visible or apply.rect.y + apply.rect.h > window.rect_pixels.h) return error.ClippedApplyButton;
            std.log.info("Key search input passed: typed page, selected Page Up, footer visible", .{});
        }
        if (frames == 20 and state == .key_drag) {
            const changed = editor.model.action().?.tap_hold;
            if (changed.tap.key_press.?.tap_keycode != 5 or changed.tap.key_press.?.tap_modifiers.toByte() != 6 or changed.hold.hold_modifiers.toByte() != 10 or changed.tapping_term.ms != 180) return error.ChordDragFailed;
            try editor.model.undo();
            if (editor.model.action().?.tap_hold.tap.key_press.?.tap_keycode != 4) return error.ChordDragUndoFailed;
            try editor.model.undo();
            if (editor.model.action().?.tap_hold.tap.key_press.?.tap_modifiers.toByte() != 0) return error.ChordDragUndoFailed;
            try editor.model.redo();
            try editor.model.redo();
            std.log.info("Chord drag passed: Shift+Option to split key, Tap and Hold drops, preserved timing, undo/redo", .{});
        }
        if (interactions and frames == 26) {
            if (!editor.try_hid_bootloader or editor.bootloader_requested or editor.bootloader != null) return error.BootloaderToggleFailed;
            if (editor.model.primary != 31 or editor.model.document().layers.len != 7 or editor.model.layer != 5) return error.InteractionScenarioFailed;
            if (editor.model.action().? != .tap_only or editor.model.action().?.tap_only.key_press.?.tap_keycode != 4) return error.FormInteractionFailed;
            std.log.info("Semantic input scenario passed: thumb selection, isolated duplication, undo/redo and advanced form apply", .{});
        }
        if (interactions and frames == 82) {
            std.log.info("Docked inspector semantic scenario passed: mixed bulk modifiers, pending Keep/Apply/Discard, atomic undo/redo, media/one-shot chip removal, invalid Apply and Cancel", .{});
            if (screenshot == null) {
                _ = try window.end(.{});
                break;
            }
        }
        const capture_frame: usize = if (state == .native_free_input) @import("native_input_check.zig").Driver.capture_frame else if (state == .native_live_input) @import("live_keyboard.zig").NativeDriver.capture_frame else if (state == .free_input) 40 else if (state == .practice_guidance) 17 else if (state == .practice_input) 33 else if (state == .practice_scroll) 10 else if (interactions) 84 else if (state == .key_search) 12 else if (state == .key_drag) 22 else 5;
        if (screenshot != null and frames == capture_frame) {
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
    _ = @import("profile_projects.zig");
    _ = geometry;
    _ = @import("model.zig");
    _ = forms;
    _ = @import("text.zig");
    _ = @import("host_input.zig");
    _ = @import("try_state.zig");
    _ = @import("window_placement.zig");
    _ = @import("practice.zig");
    _ = @import("practice_view.zig");
    _ = @import("practice_layout.zig");
}
