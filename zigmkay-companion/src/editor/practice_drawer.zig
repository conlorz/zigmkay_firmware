const std = @import("std");
const dvui = @import("dvui");
const ui = @import("ui.zig");
const practice = @import("practice.zig");
pub fn draw(self: anytype, t: ui.Theme) !void {
    const window = ui.editDrawer(@src(), t, 1250);
    defer window.deinit();
    const now = self.practiceTime();
    const height = window.data().rect.h;
    const width = window.data().rect.w - 36;
    dvui.label(@src(), "Typing practice · English and complete Zig files", .{}, .{});
    {
        const row = dvui.box(@src(), .{ .dir = .horizontal }, .{});
        defer row.deinit();
        var changed = dvui.dropdown(@src(), &.{ "English", "Zig" }, .{ .choice = &self.practice_mode }, .{}, .{ .min_size_content = .{ .w = 130 } });
        changed = dvui.dropdown(@src(), if (self.practice_mode == 0) &.{ "Short · 2 sentences", "Normal · 5 sentences", "Long · 10 sentences" } else &practice.lesson_names, .{ .choice = &self.practice_level }, .{}, .{ .min_size_content = .{ .w = 250 } }) or changed;
        changed = dvui.dropdown(@src(), &.{ "OS keyboard text", "Unflashed draft layout" }, .{ .choice = &self.practice_source }, .{}, .{ .min_size_content = .{ .w = 230 } }) or changed;
        if (changed) {
            self.pausePractice();
            self.practice_active = false;
        }
    }
    dvui.label(@src(), "{s} · {d:.1} WPM · {d:.1}% accuracy · {d:.1}s · {d} corrections", .{ if (!self.practice_active) "Press Start" else @tagName(self.practice.state), self.practice.wpm(now), self.practice.accuracy(), @as(f64, @floatFromInt(self.practice.duration(now))) / 1_000_000, self.practice.corrected }, .{});
    if (self.practice_active and (self.practice.state == .ready or self.practice.state == .running) and self.practice.source == .os) {
        dvui.wantTextInput(window.data().borderRectScale().r.toNatural());
        for (dvui.events()) |*event| {
            if (event.handled) continue;
            switch (event.evt) {
                .text => |text| {
                    if (text.action == .value and !text.action.value.selected) try self.practice.insert(text.action.value.txt, now, false);
                    event.handle(@src(), window.data());
                },
                .key => |key| {
                    if (key.action == .up) continue;
                    if (key.matchBind("paste")) try self.practice.insert(dvui.clipboardText(), now, true) else switch (key.code) {
                        .backspace => self.practice.backspace(),
                        .tab => try self.practice.insert("    ", now, false),
                        .enter => try self.practice.insert("\n", now, false),
                        .escape => self.pausePractice(),
                        else => {},
                    }
                    event.handle(@src(), window.data());
                },
                else => {},
            }
        }
    }
    {
        const body = dvui.scrollArea(@src(), .{}, .{ .rect = .{ .x = 0, .y = 110, .w = width, .h = height - 290 }, .background = true, .color_fill = .{ .color = t.bg }, .padding = .all(12), .tag = "practice.text" });
        defer body.deinit();
        dvui.label(@src(), "Reference / your text · green matches · red mistakes · | caret", .{}, .{});
        if (self.practice_active) {
            var start: usize = 0;
            var line: usize = 1;
            while (start < self.practice.reference_len) : (line += 1) {
                var end = start;
                while (end < self.practice.reference_len and self.practice.reference[end] != '\n') end += 1;
                const next = @min(end + 1, self.practice.reference_len);
                const row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = line, .expand = .horizontal });
                defer row.deinit();
                dvui.label(@src(), "{d}", .{line}, .{ .tag = if (self.practice.len >= start and self.practice.len <= end) "practice.current" else null, .min_size_content = .{ .w = 35 }, .color_text = .{ .color = if (self.practice.len >= start and self.practice.len <= end) ui.color(0x3988FF) else t.muted } });
                const columns = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer columns.deinit();
                {
                    const text = dvui.textLayout(@src(), .{}, .{ .min_size_content = .{ .w = (width - 100) / 2 }, .font = dvui.Font.theme(.mono) });
                    defer text.deinit();
                    for (start..end) |i| {
                        var bytes: [4]u8 = undefined;
                        const n = try std.unicode.utf8Encode(self.practice.reference[i], &bytes);
                        text.addText(bytes[0..n], .{ .color_text = .{ .color = if (i >= self.practice.len) t.text else if (self.practice.typed[i] == self.practice.reference[i]) ui.color(0x28A065) else ui.color(0xE45353) } });
                    }
                }
                {
                    const text = dvui.textLayout(@src(), .{}, .{ .min_size_content = .{ .w = (width - 100) / 2 }, .font = dvui.Font.theme(.mono) });
                    defer text.deinit();
                    const typed_end = if (next == self.practice.reference_len) self.practice.len else @min(end, self.practice.len);
                    if (self.practice.len >= start) {
                        for (start..@max(start, typed_end)) |i| {
                            var bytes: [4]u8 = undefined;
                            const n = try std.unicode.utf8Encode(self.practice.typed[i], &bytes);
                            text.addText(if (self.practice.typed[i] == '\n') "↵" else bytes[0..n], .{ .color_text = .{ .color = if (i < self.practice.reference_len and self.practice.typed[i] == self.practice.reference[i]) ui.color(0x28A065) else ui.color(0xE45353) } });
                        }
                        if (self.practice.len <= end or next == self.practice.reference_len) text.addText("|", .{ .color_text = .{ .color = ui.color(0x3988FF) } });
                    } else text.addText(" ", .{});
                }
                if (self.practice.len != self.practice_drawn_len and self.practice.len >= start and self.practice.len <= end) dvui.scrollTo(.{ .screen_rect = columns.data().borderRectScale().r });
                start = next;
            }
        } else dvui.label(@src(), "Timing begins on your first character. Backspace corrects; Tab inserts four spaces.", .{}, .{});
    }
    self.practice_drawn_len = self.practice.len;
    const y = height - 160;
    if (ui.button(t, if (self.practice_active) "Restart" else "Start", "practice.start", .{ .x = 0, .y = y, .w = 120, .h = 40 })) try self.startPractice(!self.practice_active);
    if (ui.button(t, "New exercise", "practice.new", .{ .x = 130, .y = y, .w = 150, .h = 40 })) {
        self.practice_seed +%= 1;
        if (self.practice_mode == 1) self.practice_level = (self.practice_level + 1) % 3;
        try self.startPractice(true);
    }
    if (ui.button(t, if (self.practice.state == .paused) "Resume" else "Pause", "practice.pause", .{ .x = 290, .y = y, .w = 120, .h = 40 }) and self.practice_active) {
        if (self.practice.state == .paused) {
            if (self.practice.source == .draft) {
                if (!std.mem.eql(u8, &self.practice_snapshot, &(try self.model.id()))) {
                    self.report(error.DraftChangedRestartPractice);
                    return;
                }
                if (self.testing.state != .prepared) {
                    try self.testing.prepare(self.model.current.snapshot);
                    return;
                }
                self.last_text_sequence = null;
                self.test_start = @intCast(std.Io.Clock.awake.now(self.io).toMicroseconds());
                try self.testing.start();
            }
            self.practice.resumeRun(now);
        } else self.pausePractice();
    }
    if (ui.button(t, "Stop", "practice.stop", .{ .x = 420, .y = y, .w = 100, .h = 40 })) {
        self.pausePractice();
        self.practice_active = false;
    }
    if (ui.button(t, "Close", "practice.close", .{ .x = 530, .y = y, .w = 100, .h = 40 })) {
        self.pausePractice();
        self.practice_open = false;
    }
    const footer = dvui.box(@src(), .{}, .{ .rect = .{ .x = 0, .y = y + 48, .w = width, .h = 100 } });
    defer footer.deinit();
    dvui.label(@src(), "{d}/{d} characters · {d:.1} CPM · session best {d:.1} WPM · {s}", .{ self.practice.matched(), self.practice.reference_len, self.practice.wpm(now) * 5, self.practice_best[self.practice_mode][self.practice_level][self.practice_source], if (self.practice.scored) "scored" else "paste preview · unscored" }, .{});
    if (self.practice.source == .draft and self.practice_active) dvui.label(@src(), "Draft: {s}. After preparation, press Resume. QWERTY keys map to LK7 positions.", .{@tagName(self.testing.state)}, .{});
    var worst: usize = 0;
    for (self.practice.errors[0..self.practice.reference_len], 0..) |count, i| {
        if (count > self.practice.errors[worst]) worst = i;
    }
    if (self.practice.reference_len > 0 and self.practice.errors[worst] > 0) {
        var bytes: [4]u8 = undefined;
        const n = try std.unicode.utf8Encode(self.practice.reference[worst], &bytes);
        dvui.label(@src(), "Troublesome expected character: {s} · {d} mistakes", .{ if (self.practice.reference[worst] == ' ') "space" else if (self.practice.reference[worst] == '\n') "newline" else bytes[0..n], self.practice.errors[worst] }, .{});
    }
    dvui.labelNoFmt(@src(), std.mem.sliceTo(&self.diagnostic, 0), .{}, .{});
}
