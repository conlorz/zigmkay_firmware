const std = @import("std");
const dvui = @import("dvui");
const ui = @import("ui.zig");
pub fn draw(self: anytype, t: ui.Theme) !void {
    const window = ui.drawer(@src(), t, .{ .x = 350, .y = 170, .w = 900, .h = 680 }, true);
    defer window.deinit();
    const area = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer area.deinit();
    dvui.label(@src(), "LK7 firmware · {s}", .{@tagName(self.firmware.state)}, .{});
    dvui.label(@src(), "Build freezes the draft, including callback sources. Transfer requires a current artifact.", .{}, .{});
    if (self.firmware.artifact_path) |path| dvui.label(@src(), "Artifact: {s}", .{path}, .{});
    if (self.firmware.manifest) |manifest| {
        const hash = std.fmt.bytesToHex(manifest.uf2_hash, .lower);
        dvui.label(@src(), "UF2: {d} bytes · SHA-256 {s}", .{ manifest.uf2_size, hash }, .{});
    }
    if (self.firmware.rollback_path) |path| dvui.label(@src(), "Known running rollback artifact: {s}", .{path}, .{});
    if (self.firmware.state == .building and dvui.button(@src(), "Cancel build", .{}, .{ .tag = "firmware.cancel" })) self.firmware.cancel();
    if (dvui.button(@src(), "Build current draft", .{}, .{ .tag = "firmware.prepare" })) {
        self.flash_confirmed = false;
        if (!self.fixture) self.firmware.build(self.model.current.snapshot) catch |err| self.report(err);
    }
    dvui.labelNoFmt(@src(), self.bootloader_status, .{}, .{});
    if (self.bootloader_available and dvui.button(@src(), "Enter bootloader", .{}, .{ .tag = "firmware.bootloader" })) {
        if (!self.fixture) self.bootloader_requested = true;
    }
    dvui.label(@src(), "The RP2040 recovery drive is detected automatically. Flash waits up to 30 seconds for it to mount.", .{}, .{});
    dvui.label(@src(), "If several recovery drives are connected, disconnect the others or use the advanced override.", .{}, .{});
    if (dvui.checkbox(@src(), &self.recovery_manual, "Advanced: choose a recovery drive manually", .{})) self.flash_confirmed = false;
    if (self.recovery_manual) {
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.recovery_volume }, .placeholder = "Absolute recovery drive path" }, .{ .expand = .horizontal, .tag = "firmware.volume" });
        entry.deinit();
    }
    _ = dvui.checkbox(@src(), &self.flash_confirmed, "My LK7 is in recovery mode and ready to flash.", .{});
    if (self.firmware.state == .built and self.flash_confirmed and dvui.button(@src(), "Flash firmware", .{}, .{ .tag = "firmware.transfer" })) {
        const target = if (self.recovery_manual) std.mem.sliceTo(&self.recovery_volume, 0) else "";
        if (!self.fixture) self.firmware.flash(try self.model.id(), target, true) catch |err| self.report(err);
        self.flash_confirmed = false;
    }
    dvui.label(@src(), "Transfer: {} · Running identity verified: {} · Typing accepted: {}", .{ self.firmware.transferred, self.firmware.running_verified, self.firmware.typing_verified }, .{});
    if (self.firmware.transferred and !self.firmware.running_verified) dvui.label(@src(), "Reconnect the live overlay to verify board/profile identity. On timeout or mismatch, use physical recovery and the rollback artifact.", .{}, .{});
    if (self.firmware.running_verified and dvui.button(@src(), "I verified actual typing", .{}, .{ .tag = "firmware.typing" })) self.firmware.acceptTyping() catch |err| self.report(err);
    dvui.label(@src(), "A synchronized UF2 transfer is not transactional; removal or failure can require physical recovery.", .{}, .{});
    dvui.labelNoFmt(@src(), self.firmware.diagnostic.items, .{}, .{});
    dvui.labelNoFmt(@src(), std.mem.sliceTo(&self.diagnostic, 0), .{}, .{});
    if (dvui.button(@src(), "Close firmware workflow", .{}, .{})) self.firmware_open = false;
}
