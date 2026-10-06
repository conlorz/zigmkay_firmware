const std = @import("std");
const builtin = @import("builtin");
const ztray = @import("ztray");

pub const Action = enum(i32) { open_editor = 1, toggle_companion = 2, quit = 3 };
pub const Status = enum { offline, connecting, live, stale, disconnected, incompatible };
pub const MenuState = struct { live_mode: bool = false, status: Status = .offline, companion_visible: bool = true };

/// UI-thread-owned lifecycle. Window visibility never owns document lifetime.
pub const Lifecycle = struct {
    running: bool = true,
    resident: bool = false,
    companion_visible: bool = true,
    editor_visible: bool = false,
    quit_requested: bool = false,

    pub fn action(self: *Lifecycle, value: Action) void {
        switch (value) {
            .open_editor => self.editor_visible = true,
            .toggle_companion => self.companion_visible = !self.companion_visible,
            .quit => self.quit_requested = true,
        }
    }
    pub fn cancelQuit(self: *Lifecycle) void {
        self.quit_requested = false;
    }
    pub fn finishQuit(self: *Lifecycle) void {
        self.running = false;
    }
    pub fn keepRunning(self: Lifecycle) bool {
        return self.running and (self.resident or self.companion_visible or self.editor_visible);
    }
};

pub fn Tray(comptime Backend: type) type {
    return struct {
        const Self = @This();
        backend: Backend,
        installed: bool = false,
        previous: ?MenuState = null,

        pub fn init(backend: Backend, enabled: bool) Self {
            var self = Self{ .backend = backend };
            if (enabled) {
                self.backend.install() catch |err| {
                    if (!builtin.is_test) std.log.warn("Tray unavailable: {s}; closing windows will exit", .{@errorName(err)});
                    return self;
                };
                self.installed = true;
            }
            return self;
        }
        pub fn update(self: *Self, state: MenuState) void {
            if (!self.installed or (self.previous != null and std.meta.eql(self.previous.?, state))) return;
            self.backend.menu(state) catch |err| {
                if (!builtin.is_test) std.log.warn("Tray menu unavailable: {s}; restoring window lifecycle", .{@errorName(err)});
                self.deinit();
                return;
            };
            self.previous = state;
        }
        pub fn poll(self: *Self) ?Action {
            if (!self.installed) return null;
            return self.backend.poll();
        }
        pub fn deinit(self: *Self) void {
            if (self.installed) self.backend.shutdown();
            self.installed = false;
        }
    };
}

pub const Native = struct {
    allocator: std.mem.Allocator,
    pub fn install(self: Native) !void {
        try ztray.installTrayIcon(self.allocator, .{ .tooltip = "Zigmkay is running", .icon_png = &@import("tray_icon.zig").png });
    }
    pub fn menu(self: Native, state: MenuState) !void {
        const items = [_]ztray.Item{
            .{ .action = .{ .title = if (state.live_mode) "Companion: live monitoring" else "Companion: offline", .action_id = 10, .enabled = false } },
            .{ .action = .{ .title = switch (state.status) {
                .offline => "Device: offline",
                .connecting => "Device: connecting",
                .live => "Device: live",
                .stale => "Device: stale",
                .disconnected => "Device: disconnected",
                .incompatible => "Device: incompatible",
            }, .action_id = 11, .enabled = false } },
            .{ .action = .{ .title = "Open Editor", .action_id = @intFromEnum(Action.open_editor) } },
            .{ .action = .{ .title = if (state.companion_visible) "Hide Companion" else "Show Companion", .action_id = @intFromEnum(Action.toggle_companion) } },
            .separator,
            .{ .action = .{ .title = "Quit Zigmkay", .action_id = @intFromEnum(Action.quit) } },
        };
        try ztray.setTrayMenu(self.allocator, .{ .title = "Zigmkay", .items = &items });
    }
    pub fn poll(_: Native) ?Action {
        // SDL_PollEvent already pumps AppKit/Win32 and delivers tray callbacks.
        // A second native pump can block AppKit or consume SDL's Win32 messages.
        if (builtin.os.tag == .linux) ztray.pumpEvents();
        return ztray.pollTrayAction(Action);
    }
    pub fn shutdown(_: Native) void {
        ztray.shutdownTray();
    }
};
pub const NativeTray = Tray(Native);

const Fake = struct {
    counters: *Counters,
    const Counters = struct { installs: usize = 0, menus: usize = 0, shutdowns: usize = 0, fail: bool = false, fail_menu: bool = false, next: ?Action = null };
    fn install(self: Fake) !void {
        self.counters.installs += 1;
        if (self.counters.fail) return error.Unavailable;
    }
    fn menu(self: Fake, _: MenuState) !void {
        self.counters.menus += 1;
        if (self.counters.fail_menu) return error.Unavailable;
    }
    fn poll(self: Fake) ?Action {
        defer self.counters.next = null;
        return self.counters.next;
    }
    fn shutdown(self: Fake) void {
        self.counters.shutdowns += 1;
    }
};

test "resident lifecycle hides both windows, reopens, and cancels quit" {
    var life = Lifecycle{ .resident = true, .editor_visible = true };
    life.companion_visible = false;
    life.editor_visible = false;
    try std.testing.expect(life.keepRunning());
    life.action(.open_editor);
    life.action(.open_editor);
    try std.testing.expect(life.editor_visible);
    life.action(.toggle_companion);
    try std.testing.expect(life.companion_visible);
    life.action(.quit);
    life.cancelQuit();
    try std.testing.expect(life.keepRunning() and !life.quit_requested);
    life.finishQuit();
    try std.testing.expect(!life.keepRunning());
}
test "tray caches status, polls actions, and tears down exactly once" {
    var counters = Fake.Counters{};
    var tray = Tray(Fake).init(.{ .counters = &counters }, true);
    tray.update(.{});
    tray.update(.{});
    for (std.enums.values(Status)) |status| tray.update(.{ .status = status });
    try std.testing.expectEqual(@as(usize, 6), counters.menus);
    counters.next = .open_editor;
    try std.testing.expectEqual(Action.open_editor, tray.poll().?);
    try std.testing.expect(tray.poll() == null);
    tray.deinit();
    tray.deinit();
    try std.testing.expectEqual(@as(usize, 1), counters.shutdowns);
}
test "finite modes and tray failure do not leave invisible resident processes" {
    var counters = Fake.Counters{};
    var tray = Tray(Fake).init(.{ .counters = &counters }, false);
    try std.testing.expectEqual(@as(usize, 0), counters.installs);
    counters.fail = true;
    tray = Tray(Fake).init(.{ .counters = &counters }, true);
    const life = Lifecycle{ .resident = tray.installed, .companion_visible = false };
    try std.testing.expect(!life.keepRunning());
}

test "menu failure removes the tray and disables background persistence" {
    var counters = Fake.Counters{ .fail_menu = true };
    var tray = Tray(Fake).init(.{ .counters = &counters }, true);
    tray.update(.{});
    try std.testing.expect(!tray.installed);
    try std.testing.expectEqual(@as(usize, 1), counters.shutdowns);
    tray.deinit();
    try std.testing.expectEqual(@as(usize, 1), counters.shutdowns);
}
