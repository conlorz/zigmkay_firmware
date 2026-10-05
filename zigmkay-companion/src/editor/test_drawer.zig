const std = @import("std");
const dvui = @import("dvui");
const ui = @import("ui.zig");
pub fn draw(self: anytype, t: ui.Theme) !void {
    const window = ui.drawer(@src(), t, .{ .x = 320, .y = 590, .w = 900, .h = 310 }, false);
    defer window.deinit();
    const area = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer area.deinit();
    dvui.label(@src(), "Test: {s} · preparation {d} ms", .{ @tagName(self.testing.state), @divTrunc(self.testing.elapsed_ns, 1_000_000) }, .{});
    dvui.label(@src(), "Mapped QWERTY scancodes target LK7 positions; focus loss stops and resets.", .{}, .{});
    if (self.text.native_session) |*session| dvui.label(@src(), "Actual source: {s} · EurKEY selected: {}", .{ session.source.id(), session.eurkey() }, .{});
    if (self.testing.last) |output| {
        dvui.label(@src(), "Sequence {d} · layers {x} · highest {d} · modifiers {x} · commands {d} · events {d} · signals {d}", .{ output.sequence, output.active_layers, output.highest_layer, output.modifiers, output.commands.len, output.events.len, output.signals.len }, .{});
        for (output.commands) |command| dvui.label(@src(), "Command: {any}", .{command}, .{});
        for (output.events) |event| dvui.label(@src(), "Event: {any}", .{event}, .{});
        for (output.signals) |signal| dvui.label(@src(), "Signal: {any}", .{signal}, .{});
    }
    if (self.testing.state == .running) {
        if (dvui.button(@src(), "Selected key down", .{}, .{})) try self.testing.input(.{ .key_down = @intCast(self.model.primary) }, self.testTime());
        if (dvui.button(@src(), "Selected key up", .{}, .{})) try self.testing.input(.{ .key_up = @intCast(self.model.primary) }, self.testTime());
    }
    dvui.labelNoFmt(@src(), self.testing.diagnostic.items, .{}, .{});
    if (dvui.button(@src(), "Close details", .{}, .{})) self.test_details = false;
}
