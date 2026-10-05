const std = @import("std");
const dvui = @import("dvui");
const ui = @import("ui.zig");
const practice = @import("practice.zig");
const view = @import("practice_view.zig");
const guide = @import("practice_layout.zig");
const geometry = @import("../components/layout.zig");
const Modifiers = @import("layout-model").Modifiers;
fn input(self: anytype, data: *dvui.WidgetData, now: u64) !void {
    if (!self.practice_active or (self.practice.state != .ready and self.practice.state != .running) or self.practice.source != .os) return;
    dvui.wantTextInput(data.borderRectScale().r.toNatural());
    for (dvui.events()) |*event| {
        if (event.handled) continue;
        switch (event.evt) {
            .text => |text| {
                if (text.action == .value and !text.action.value.selected) try self.practice.insert(text.action.value.txt, now, false);
                event.handle(@src(), data);
            },
            .key => |key| {
                if (key.action == .up) continue;
                if (key.matchBind("paste")) try self.practice.insert(dvui.clipboardText(), now, true) else if (!key.mod.control() and !key.mod.command()) switch (key.code) {
                    .backspace => self.practice.backspace(),
                    .tab => try self.practice.insert("    ", now, false),
                    .enter => try self.practice.insert("\n", now, false),
                    .escape => self.pausePractice(),
                    else => {},
                };
                event.handle(@src(), data);
            },
            else => {},
        }
    }
}

fn caption(text: []const u8, bounds: dvui.Rect, size: f32, color: dvui.Color, tag: ?[]const u8) void {
    dvui.labelNoFmt(@src(), text, .{ .align_x = 0.5, .align_y = 0.5 }, .{ .rect = bounds, .font = dvui.Font.theme(.body).withSize(size), .color_text = .{ .color = color }, .padding = .{}, .tag = tag, .id_extra = std.hash.Wyhash.hash(0, std.mem.asBytes(&bounds)) });
}
fn letter(s: *const practice.Session, index: usize, focus: usize, bounds: dvui.Rect, size: f32, t: ui.Theme, hero: bool) void {
    const current = index == focus and s.state != .complete;
    const wrong = index < s.len and s.typed[index] != s.reference[index];
    const text_color = if (current) dvui.Color.white else if (wrong) ui.color(0xE85A68) else if (index < s.len) ui.color(if (t.bg.r > 100) 0x2C876E else 0x69BFA3) else if (hero) t.text else t.muted;
    var bytes: [4]u8 = undefined;
    const text = view.glyph(s.reference[index], current or hero, &bytes);
    dvui.labelNoFmt(@src(), text, .{ .align_x = 0.5, .align_y = 0.5 }, .{
        .rect = bounds,
        .font = dvui.Font.theme(.mono).withSize(size),
        .padding = .{},
        .margin = .{},
        .id_extra = index,
        .color_text = .{ .color = text_color },
        .background = current,
        .color_fill = .{ .color = if (wrong) ui.color(0xCF4055) else ui.color(0x287AF2) },
        .corners = .all(6),
        .tag = if (current and !hero) "practice.current" else null,
    });
}
fn focusWord(self: anytype, t: ui.Theme, bounds: dvui.Rect, focus: usize) void {
    const panel = dvui.box(@src(), .{}, .{ .rect = bounds, .background = true, .color_fill = .{ .color = t.control }, .corners = .all(14), .padding = .{}, .tag = "practice.word" });
    defer panel.deinit();
    const s = &self.practice;
    if (!self.practice_active) {
        caption("Learn your layout, one word at a time", .{ .x = 0, .y = 16, .w = bounds.w, .h = bounds.h - 32 }, @min(34, bounds.h * 0.4), t.text, null);
        return;
    }
    if (s.state == .complete) {
        caption("Exercise complete", .{ .x = 0, .y = 8, .w = bounds.w, .h = bounds.h - 36 }, @min(44, bounds.h * 0.5), ui.color(0x36A77C), null);
        var worst: usize = 0;
        for (s.errors[0..s.reference_len], 0..) |count, i| if (count > s.errors[worst]) {
            worst = i;
        };
        var bytes: [4]u8 = undefined;
        const result = if (s.reference_len > 0 and s.errors[worst] > 0) std.fmt.allocPrint(dvui.currentWindow().arena(), "Most troublesome: «{s}» · {d} mistakes · try again or start a new exercise", .{ view.glyph(s.reference[worst], true, &bytes), s.errors[worst] }) catch "Start again or try a new exercise" else "Start again or try a new exercise";
        caption(result, .{ .x = 0, .y = bounds.h - 34, .w = bounds.w, .h = 28 }, 16, t.muted, null);
        return;
    }
    const range = view.word(s.reference[0..s.reference_len], focus);
    const count = range.end - range.start;
    if (count == 0) return;
    const size = @min(@min(@as(f32, 52), bounds.h * 0.5), (bounds.w - 60) / (@as(f32, @floatFromInt(count)) * 0.65));
    const cell = dvui.Font.theme(.mono).withSize(size).textSize("M").w + 4;
    const x = (bounds.w - cell * @as(f32, @floatFromInt(count))) / 2;
    const glyph_height = @min(bounds.h - 43, size * 1.4);
    for (range.start..range.end) |i| letter(s, i, focus, .{ .x = x + @as(f32, @floatFromInt(i - range.start)) * cell, .y = (bounds.h - 43 - glyph_height) / 2 + 4, .w = cell, .h = glyph_height }, size, t, true);
    const wrong = focus < s.len;
    const name = switch (s.reference[focus]) {
        ' ' => "Space",
        '\n' => "Enter",
        '\t' => "Tab",
        else => "Next highlighted letter",
    };
    var wrong_bytes: [4]u8 = undefined;
    const hint = if (wrong) std.fmt.allocPrint(dvui.currentWindow().arena(), "Typed «{s}» · Backspace {d} character{s} to correct", .{ view.glyph(s.typed[focus], true, &wrong_bytes), s.len - focus, if (s.len - focus == 1) "" else "s" }) catch "Correct the red letter" else if (s.state == .paused) "Paused · press Resume to continue" else name;
    caption(hint, .{ .x = 0, .y = bounds.h - 36, .w = bounds.w, .h = 30 }, @min(17, bounds.h * 0.18), if (wrong) ui.color(0xE85A68) else t.muted, "practice.next");
}
fn context(self: anytype, t: ui.Theme, bounds: dvui.Rect, focus: usize, now: u64) void {
    const panel = dvui.box(@src(), .{}, .{ .rect = bounds, .background = true, .color_fill = .{ .color = t.bg }, .corners = .all(12), .padding = .{}, .tag = "practice.text" });
    defer panel.deinit();
    if (!self.practice_active) {
        caption("Type the highlighted character. Your keyboard guide stays below.", .{ .x = 0, .y = 0, .w = bounds.w, .h = bounds.h }, 22, t.muted, null);
        return;
    }
    const font_size = @min(@as(f32, 30), @max(@as(f32, 22), bounds.h / 5));
    const cell = dvui.Font.theme(.mono).withSize(font_size).textSize("M").w + 2;
    const columns: usize = @intFromFloat(@max(1, @floor((bounds.w - 80) / cell)));
    var storage: [8192]view.Range = undefined;
    const ranges = view.lines(self.practice.reference[0..self.practice.reference_len], columns, &storage);
    const active_line = view.currentLine(ranges, focus);
    const target: f32 = @floatFromInt(active_line);
    const previous = self.practice_scroll_at;
    const elapsed: f32 = if (previous) |at| @as(f32, @floatFromInt(@min(now -| at, 100_000))) / 1_000_000 else 1;
    self.practice_scroll_at = now;
    if (self.fixture or previous == null or @abs(target - self.practice_scroll_position) > 3) self.practice_scroll_position = target else self.practice_scroll_position += (target - self.practice_scroll_position) * (1 - @exp(-elapsed * 18));
    if (@abs(self.practice_scroll_position - target) > 0.01) dvui.refresh(null, @src(), null);
    const line_height = font_size * 1.65;
    const clip = dvui.clip(panel.data().contentRectScale().r);
    defer dvui.clipSet(clip);
    for (ranges, 0..) |range, row_index| {
        const y = bounds.h / 2 - line_height / 2 + (@as(f32, @floatFromInt(row_index)) - self.practice_scroll_position) * line_height;
        if (y + line_height < 0 or y > bounds.h) continue;
        const row = dvui.box(@src(), .{}, .{ .id_extra = row_index, .rect = .{ .x = 8, .y = y, .w = bounds.w - 16, .h = line_height }, .padding = .{}, .background = row_index == active_line, .color_fill = .{ .color = t.control }, .corners = .all(8) });
        defer row.deinit();
        if (self.practice_mode == 1) dvui.label(@src(), "{d}", .{std.mem.count(u21, self.practice.reference[0..range.start], &.{'\n'}) + 1}, .{ .rect = .{ .x = 0, .y = 0, .w = 40, .h = line_height }, .font = dvui.Font.theme(.mono).withSize(14), .color_text = .{ .color = t.muted } });
        const count: f32 = @floatFromInt(range.end - range.start);
        const x = if (self.practice_mode == 1) @as(f32, 50) else @max(40, (bounds.w - 16 - count * cell) / 2);
        for (range.start..range.end) |i| letter(&self.practice, i, focus, .{ .x = x + @as(f32, @floatFromInt(i - range.start)) * cell, .y = 0, .w = cell, .h = line_height }, font_size, t, false);
    }
}
fn keyboard(self: anytype, t: ui.Theme, bounds: dvui.Rect, focus: usize) !void {
    const panel = dvui.box(@src(), .{}, .{ .rect = bounds, .background = true, .color_fill = .{ .color = t.bg }, .corners = .all(12), .padding = .{}, .tag = "practice.keyboard" });
    defer panel.deinit();
    const live = self.practice_source == 0 and self.practice_live_labels != null;
    const labels = if (live) self.practice_live_labels.? else try self.practiceLabels();
    var layer: usize = 0;
    var active: u16 = 1;
    var mods: Modifiers = .{};
    var pressed: [128]bool = @splat(false);
    const running_draft = self.practice_source == 1 and self.testing.state == .running;
    if (live) {
        if (self.practice_live_state) |state| {
            layer = state.highest_layer;
            active = state.active_layers;
            mods = state.modifiers;
            pressed = state.pressed;
        }
    } else if (running_draft) {
        for (self.testing.pressed, 0..) |down, i| pressed[i] = down;
        if (self.testing.last) |output| {
            layer = output.highest_layer;
            active = output.active_layers;
            mods = @bitCast(output.modifiers);
        }
    }
    layer = @min(layer, labels.layer_count - 1);
    const next = if (self.practice_active and focus < self.practice.reference_len) guide.hintActive(labels, layer, mods, self.practice.reference[focus], active) else null;
    if (!live and !running_draft) {
        if (next) |hint| {
            layer = hint.layer;
            mods = hint.mods;
            active = 1 | (@as(u16, 1) << @intCast(layer));
        }
    }
    const targets = guide.targets(labels, layer, if (!live and !running_draft) .{} else mods, next);
    const title = if (live) (if (self.practice_live_stale) "Companion · reconnecting" else "Live companion") else if (running_draft) "Draft companion · simulated key presses" else "Draft layout guide";
    const profile = if (live) std.mem.sliceTo(&self.practice_live_profile, 0) else self.model.document().name;
    caption(try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s} · {s} · layer {d} · gold = next key / modifier", .{ title, profile, layer }), .{ .x = 8, .y = 0, .w = bounds.w - 16, .h = 28 }, @min(18, bounds.h * 0.09), t.text, "practice.keyboard.source");
    if (next) |hint| {
        var mod_buffer: [96]u8 = undefined;
        const instruction = try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s}{s}{s}{s}", .{ if (hint.layer != 0) "Layer " else "", if (hint.layer != 0) try std.fmt.allocPrint(dvui.currentWindow().arena(), "{d} · ", .{hint.layer}) else "", if (hint.mods.toByte() != 0) @import("labels.zig").modifierNames(hint.mods.toByte(), &mod_buffer) else "", if (hint.mods.toByte() != 0) " + highlighted key" else "Highlighted key" });
        caption(instruction, .{ .x = 8, .y = 28, .w = bounds.w - 16, .h = 23 }, 14, ui.color(if (t.bg.r > 100) 0x8B6318 else 0xFFD179), null);
    } else if (self.practice_active and self.practice.state != .complete) caption("Use your layout's composition or custom action for this character", .{ .x = 8, .y = 28, .w = bounds.w - 16, .h = 23 }, 14, t.muted, null);
    try geometry.drawGuided(labels, layer, &pressed, mods, live and self.practice_live_stale, .{ .x = 18, .y = 52, .w = bounds.w - 36, .h = @max(0, bounds.h - 62) }, &targets, active);
}
pub fn draw(self: anytype, t: ui.Theme) !void {
    const screen = dvui.windowRect();
    // The editor canvas is zoomed; native window dimensions need to be converted
    // back to canvas coordinates to keep practice nearly full size when resized.
    const canvas_width = screen.w / self.content_scale;
    const canvas_height = screen.h / self.content_scale;
    const w = @min(1488, canvas_width - 48);
    const h = @min(960, canvas_height - 48);
    const window = ui.drawer(@src(), t, .{ .x = (canvas_width - w) / 2, .y = (canvas_height - h) / 2, .w = w, .h = h }, true);
    defer window.deinit();
    const now = self.practiceTime();
    const height = window.data().rect.h;
    const width = window.data().rect.w - 36;
    // A floating window acquires its measured bounds after its first frame.
    if (height < 400 or width < 600) return;
    // Consume exercise keys before controls; typing Space must not activate the
    // checkbox that happened to retain focus after a mouse click.
    try input(self, window.data(), now);
    const footer_y = height - 122;
    dvui.label(@src(), "Practice your layout", .{}, .{ .font = dvui.Font.theme(.body).withSize(27), .color_text = .{ .color = t.text } });
    {
        const row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .rect = .{ .x = 0, .y = 40, .w = width - 210, .h = 38 } });
        defer row.deinit();
        var changed = dvui.dropdown(@src(), &.{ "English", "Zig" }, .{ .choice = &self.practice_mode }, .{}, .{ .min_size_content = .{ .w = 125 } });
        changed = dvui.dropdown(@src(), if (self.practice_mode == 0) &.{ "Short · 2 sentences", "Normal · 5 sentences", "Long · 10 sentences" } else &practice.lesson_names, .{ .choice = &self.practice_level }, .{}, .{ .min_size_content = .{ .w = 240 } }) or changed;
        changed = dvui.dropdown(@src(), &.{ "OS keyboard text", "Unflashed draft layout" }, .{ .choice = &self.practice_source }, .{}, .{ .min_size_content = .{ .w = 225 } }) or changed;
        if (changed) {
            self.pausePractice();
            self.practice_active = false;
        }
    }
    _ = dvui.checkbox(@src(), &self.practice_show_keyboard, "Show companion", .{ .rect = .{ .x = width - 202, .y = 40, .w = 202, .h = 38 }, .tag = "practice.keyboard.toggle" });
    caption(try std.fmt.allocPrint(dvui.currentWindow().arena(), "{d:.0} WPM     {d:.1}% accuracy     {d:.1}s     {s}", .{ self.practice.wpm(now), self.practice.accuracy(), @as(f64, @floatFromInt(self.practice.duration(now))) / 1_000_000, if (!self.practice_active) "Ready" else @tagName(self.practice.state) }), .{ .x = 0, .y = 82, .w = width, .h = 26 }, 18, t.muted, "practice.metrics");
    const focus = view.focus(&self.practice);
    const work_height = footer_y - 132;
    const hero_height = @min(155, work_height * 0.28);
    const context_height = if (self.practice_show_keyboard) work_height * 0.28 else work_height - hero_height - 12;
    focusWord(self, t, .{ .x = 0, .y = 122, .w = width, .h = hero_height }, focus);
    context(self, t, .{ .x = 0, .y = 134 + hero_height, .w = width, .h = context_height }, focus, now);
    if (self.practice_show_keyboard) try keyboard(self, t, .{ .x = 0, .y = 146 + hero_height + context_height, .w = width, .h = @max(0, footer_y - (146 + hero_height + context_height) - 12) }, focus);
    self.practice_drawn_len = self.practice.len;
    if (ui.button(t, if (self.practice_active) "Restart" else "Start", "practice.start", .{ .x = 0, .y = footer_y, .w = 120, .h = 40 })) try self.startPractice(!self.practice_active);
    if (ui.button(t, "New exercise", "practice.new", .{ .x = 130, .y = footer_y, .w = 150, .h = 40 })) {
        self.practice_seed +%= 1;
        if (self.practice_mode == 1) self.practice_level = (self.practice_level + 1) % 3;
        try self.startPractice(true);
    }
    if (ui.button(t, if (self.practice.state == .paused) "Resume" else "Pause", "practice.pause", .{ .x = 290, .y = footer_y, .w = 120, .h = 40 }) and self.practice_active) {
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
    if (ui.button(t, "Stop", "practice.stop", .{ .x = 420, .y = footer_y, .w = 100, .h = 40 })) {
        self.pausePractice();
        self.practice_active = false;
    }
    if (ui.button(t, "Close", "practice.close", .{ .x = 530, .y = footer_y, .w = 100, .h = 40 })) {
        self.pausePractice();
        self.practice_open = false;
    }
    const progress = if (self.practice.reference_len == 0) @as(f32, 0) else @as(f32, @floatFromInt(self.practice.matched())) / @as(f32, @floatFromInt(self.practice.reference_len));
    {
        const bar = dvui.box(@src(), .{}, .{ .rect = .{ .x = 0, .y = footer_y + 52, .w = width, .h = 5 }, .padding = .{}, .background = true, .color_fill = .{ .color = t.control }, .corners = .all(3) });
        defer bar.deinit();
        const fill = dvui.box(@src(), .{}, .{ .rect = .{ .w = width * progress, .h = 5 }, .background = true, .color_fill = .{ .color = ui.color(0x287AF2) } });
        fill.deinit();
    }
    const code_speed = if (self.practice_mode == 1) try std.fmt.allocPrint(dvui.currentWindow().arena(), " · {d:.0} CPM", .{self.practice.wpm(now) * 5}) else "";
    caption(try std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}/{d} characters · {d} corrections · best {d:.0} WPM · {s}{s}", .{ self.practice.matched(), self.practice.reference_len, self.practice.corrected, self.practice_best[self.practice_mode][self.practice_level][self.practice_source], if (self.practice.scored) "scored" else "paste preview", code_speed }), .{ .x = 0, .y = footer_y + 63, .w = width, .h = 22 }, 14, t.muted, null);
    if (self.practice_source == 1 and self.practice_active and self.testing.state != .running) caption(try std.fmt.allocPrint(dvui.currentWindow().arena(), "Draft {s} · after preparation, press Resume", .{@tagName(self.testing.state)}), .{ .x = 0, .y = footer_y + 87, .w = width, .h = 22 }, 14, t.muted, null) else caption(std.mem.sliceTo(&self.diagnostic, 0), .{ .x = 0, .y = footer_y + 87, .w = width, .h = 22 }, 14, t.muted, null);
}
