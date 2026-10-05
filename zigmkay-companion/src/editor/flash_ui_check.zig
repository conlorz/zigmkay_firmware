//! Explicit hardware acceptance command. Never used by default builds or tests.
const std = @import("std");
const dvui = @import("dvui");
const sdl = @import("sdl-backend").c;
const adapter = @import("../live_adapter.zig");
const Native = @import("../main.zig").Native;
const scenario = @import("scenario.zig");
pub const Check = struct {
    phase: enum { start, build_press, build_release, building, flash_release, transferring, verifying } = .start,
    deadline: i64 = 0,
    warmup: usize = 0,
    driver: ?adapter.Driver(Native) = null,
    pub fn deinit(self: *Check) void {
        if (self.driver) |*driver| driver.disconnect(driver.transport.now());
    }
    pub fn beforeDraw(self: *Check, editor: anytype, window: *dvui.Window) !void {
        switch (self.phase) {
            .start => {
                self.deadline = std.Io.Clock.awake.now(editor.io).toMilliseconds() + 150_000;
                self.warmup += 1;
                if (self.warmup < 8) return;
                self.phase = .build_press;
            },
            .build_press => {
                try scenario.click(window, "firmware.build", 1, false);
                self.phase = .build_release;
            },
            .build_release => {
                try scenario.click(window, "firmware.build", 1, true);
                self.phase = .building;
            },
            .building => if (editor.firmware.state == .built) {
                std.log.info("UI build completed; clicking Flash firmware", .{});
                try scenario.click(window, "firmware.inspect", 1, false);
                self.phase = .flash_release;
            },
            .flash_release => {
                try scenario.click(window, "firmware.inspect", 1, true);
                self.phase = .transferring;
            },
            else => {},
        }
    }
    pub fn afterDraw(self: *Check, editor: anytype) !bool {
        if (editor.diagnostic[0] != 0) {
            std.log.err("UI action error: {s}", .{std.mem.sliceTo(&editor.diagnostic, 0)});
            return error.FlashUiActionFailed;
        }
        if (editor.firmware.state == .failed) {
            std.log.err("UI firmware workflow failed: {s}", .{editor.firmware.diagnostic.items});
            return error.FlashUiCheckFailed;
        }
        if (std.Io.Clock.awake.now(editor.io).toMilliseconds() > self.deadline) return error.FlashUiCheckTimeout;
        if (self.phase == .transferring and editor.firmware.transferred) {
            std.log.info("UI transfer completed: {s}", .{editor.firmware.diagnostic.items});
            if (!sdl.SDL_SetHint(sdl.SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS, "0")) return error.HidEnumerationHintRejected;
            var seed: u32 = undefined;
            try editor.io.randomSecure(std.mem.asBytes(&seed));
            self.driver = try adapter.Driver(Native).init(.{ .io = editor.io }, editor.firmware.expectedIdentity().?, seed, null);
            self.deadline = std.Io.Clock.awake.now(editor.io).toMilliseconds() + 15_000;
            self.phase = .verifying;
        }
        if (self.driver) |*driver| {
            const now = driver.transport.now();
            driver.poll(now);
            if (driver.session.phase == .incompatible) return error.RunningIdentityMismatch;
            const coherent = driver.session.phase == .live and !driver.session.stale;
            editor.firmware.observeRunning(if (coherent) driver.session.expected else null, coherent, now);
            if (editor.firmware.running_verified) {
                std.log.info("UI end-to-end passed: Build click, Flash click, automatic drive discovery, synchronized transfer, reconnect, exact profile identity and coherent snapshot", .{});
                return true;
            }
        }
        return false;
    }
};
