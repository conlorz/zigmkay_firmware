//! Inspector drafts never mutate the document until one validated batch commit.
const std = @import("std");
const p = @import("keymap-project");
const types = @import("layout-model");
const Model = @import("model.zig").Model;
pub const Mode = enum { tap, hold, tap_hold, repeat };
pub const ModifierTarget = enum { tap, hold, one_shot };
pub const MixedBool = enum { off, on, mixed };
pub const Operation = union(enum) {
    tap_key: ?types.KeyCodeFire,
    tap_usage: u8,
    tap_dead: bool,
    tap_one_shot: ?p.Hold,
    tap_custom: ?u8,
    tap_media: ?types.MediaCode,
    tap_mouse: ?types.MouseAction,
    hold_layer: ?p.LayerId,
    hold_custom: ?u8,
    hold_modifiers: types.Modifiers,
    tap_modifiers: types.Modifiers,
    clear_tap,
    clear_hold,
    unassign,
    inherit,
    replace: ?p.Action,
    mode: Mode,
    tapping_term: u16,
    retro_tapping: bool,
    initial_delay: u16,
    repeat_interval: u16,
};
pub fn tapPart(action: ?p.Action) p.Tap {
    return if (action) |a| switch (a) {
        .tap_only => |t| t,
        .tap_hold => |t| t.tap,
        .tap_with_autofire => |t| t.tap,
        else => .{},
    } else .{};
}
pub fn holdPart(action: ?p.Action) p.Hold {
    return if (action) |a| switch (a) {
        .hold_only => |h| h,
        .tap_hold => |t| t.hold,
        else => .{},
    } else .{};
}
pub fn tapEmpty(t: p.Tap) bool {
    return t.key_press == null and t.one_shot == null and t.custom == null and t.media_key == null and t.mouse_action == null;
}
pub fn holdEmpty(h: p.Hold) bool {
    return h.hold_modifiers.toByte() == 0 and h.layer_id == null and h.custom == null;
}
fn equal(a: ?p.Action, b: ?p.Action) bool {
    return std.meta.eql(a, b);
}
fn compose(original: ?p.Action, tap: p.Tap, hold: p.Hold) p.Action {
    if (tapEmpty(tap)) return if (holdEmpty(hold)) .none else .{ .hold_only = hold };
    if (holdEmpty(hold)) {
        if (original) |a| if (a == .tap_with_autofire) return .{ .tap_with_autofire = .{ .tap = tap, .initial_delay = a.tap_with_autofire.initial_delay, .repeat_interval = a.tap_with_autofire.repeat_interval } };
        return .{ .tap_only = tap };
    }
    return .{ .tap_hold = .{ .tap = tap, .hold = hold, .tapping_term = if (original != null and original.? == .tap_hold) original.?.tap_hold.tapping_term else .{ .ms = 180 }, .retro_tapping = if (original != null and original.? == .tap_hold) original.?.tap_hold.retro_tapping else false } };
}
pub const Session = struct {
    starting_id: [32]u8,
    layer_id: p.LayerId,
    layer_index: usize,
    selected: [34]bool,
    primary: usize,
    originals: [34]?p.Action,
    drafts: [34]?p.Action,
    resolved: [34]?p.Action,
    source_layers: [34]?p.LayerId,
    lower_resolved: [34]?p.Action,
    lower_sources: [34]?p.LayerId,
    key_lengths: [34]usize,
    // Key IDs are copied into bounded storage so document replacement cannot dangle them.
    key_storage: [34][240]u8,
    pub fn init(model: *const Model) !Session {
        var result: Session = undefined;
        result.starting_id = try model.id();
        result.layer_id = model.document().layers[model.layer].id;
        result.layer_index = model.layer;
        result.selected = model.selected;
        result.primary = model.primary;
        for (model.document().key_ids, 0..) |id, index| {
            if (id.len > result.key_storage[index].len) return error.KeyIdTooLong;
            @memcpy(result.key_storage[index][0..id.len], id);
            result.key_lengths[index] = id.len;
            const original = model.document().layers[model.layer].actions[index];
            result.originals[index] = original;
            result.drafts[index] = original;
            result.resolved[index] = original;
            result.source_layers[index] = if (original != null) result.layer_id else null;
            result.lower_resolved[index] = null;
            result.lower_sources[index] = null;
            var lower = model.layer;
            while (result.lower_resolved[index] == null and lower > 0) {
                lower -= 1;
                result.lower_resolved[index] = model.document().layers[lower].actions[index];
                if (result.lower_resolved[index] != null) result.lower_sources[index] = model.document().layers[lower].id;
            }
            if (original == null) {
                result.resolved[index] = result.lower_resolved[index];
                result.source_layers[index] = result.lower_sources[index];
            }
        }
        return result;
    }
    pub fn first(self: *const Session) ?p.Action {
        return self.drafts[self.primary];
    }
    pub fn dirty(self: *const Session) bool {
        for (self.selected, self.originals, self.drafts) |selected, a, b| if (selected and !equal(a, b)) return true;
        return false;
    }
    pub fn cancel(self: *Session) void {
        self.drafts = self.originals;
        for (self.originals, 0..) |original, i| {
            self.resolved[i] = original orelse self.lower_resolved[i];
            self.source_layers[i] = if (original != null) self.layer_id else self.lower_sources[i];
        }
    }
    pub fn stale(self: *const Session, model: *const Model) !bool {
        const id = try model.id();
        if (!std.mem.eql(u8, &id, &self.starting_id)) return true;
        for (model.document().key_ids, 0..) |key, i| if (!std.mem.eql(u8, key, self.key_storage[i][0..self.key_lengths[i]])) return true;
        return false;
    }
    pub fn apply(self: *Session, model: *Model) !bool {
        if (try self.stale(model)) return error.StaleSession;
        if (!self.dirty()) return false;
        if (self.layer_index == 0) for (self.selected, self.drafts, self.originals) |selected, draft, original| {
            if (selected and draft == null and original != null) return error.BaseCannotInherit;
        };
        try model.applyBatch(self.starting_id, self.layer_id, &self.selected, &self.drafts);
        self.* = try init(model);
        return true;
    }
    pub fn mutate(self: *Session, op: Operation) void {
        for (self.selected, 0..) |selected, i| {
            if (!selected) continue;
            const old = self.drafts[i] orelse self.resolved[i];
            var t = tapPart(old);
            var h = holdPart(old);
            switch (op) {
                .unassign => {
                    self.drafts[i] = .none;
                    continue;
                },
                .inherit => {
                    if (self.layer_index != 0) {
                        self.drafts[i] = null;
                        self.resolved[i] = self.lower_resolved[i];
                        self.source_layers[i] = self.lower_sources[i];
                    }
                    continue;
                },
                .replace => |a| {
                    self.drafts[i] = a;
                    continue;
                },
                .tap_key => |v| t.key_press = v,
                .tap_usage => |v| {
                    var key = t.key_press orelse types.KeyCodeFire{};
                    key.tap_keycode = v;
                    t.key_press = key;
                },
                .tap_dead => |v| {
                    var key = t.key_press orelse types.KeyCodeFire{};
                    key.dead = v;
                    t.key_press = key;
                },
                .tap_one_shot => |v| t.one_shot = v,
                .tap_custom => |v| t.custom = v,
                .tap_media => |v| t.media_key = v,
                .tap_mouse => |v| t.mouse_action = v,
                .hold_layer => |v| h.layer_id = v,
                .hold_custom => |v| h.custom = v,
                .hold_modifiers => |v| h.hold_modifiers = v,
                .tap_modifiers => |v| {
                    var key = t.key_press orelse types.KeyCodeFire{};
                    key.tap_modifiers = v;
                    t.key_press = if (key.tap_keycode == 0 and v.toByte() == 0) null else key;
                },
                .clear_tap => t = .{},
                .clear_hold => h = .{},
                .mode => |mode| {
                    self.drafts[i] = switch (mode) {
                        .tap => .{ .tap_only = t },
                        .hold => .{ .hold_only = h },
                        .tap_hold => .{ .tap_hold = .{ .tap = t, .hold = h, .tapping_term = if (old != null and old.? == .tap_hold) old.?.tap_hold.tapping_term else .{ .ms = 180 }, .retro_tapping = old != null and old.? == .tap_hold and old.?.tap_hold.retro_tapping } },
                        .repeat => .{ .tap_with_autofire = .{ .tap = t, .initial_delay = if (old != null and old.? == .tap_with_autofire) old.?.tap_with_autofire.initial_delay else .{ .ms = 180 }, .repeat_interval = if (old != null and old.? == .tap_with_autofire) old.?.tap_with_autofire.repeat_interval else .{ .ms = 50 } } },
                    };
                    continue;
                },
                .tapping_term, .retro_tapping, .initial_delay, .repeat_interval => {
                    var action = old orelse continue;
                    switch (op) {
                        .tapping_term => |v| if (action == .tap_hold) {
                            action.tap_hold.tapping_term = .{ .ms = v };
                        },
                        .retro_tapping => |v| if (action == .tap_hold) {
                            action.tap_hold.retro_tapping = v;
                        },
                        .initial_delay => |v| if (action == .tap_with_autofire) {
                            action.tap_with_autofire.initial_delay = .{ .ms = v };
                        },
                        .repeat_interval => |v| if (action == .tap_with_autofire) {
                            action.tap_with_autofire.repeat_interval = .{ .ms = v };
                        },
                        else => unreachable,
                    }
                    self.drafts[i] = action;
                    continue;
                },
            }
            self.drafts[i] = compose(old, t, h);
        }
    }
    fn modifierBits(action: ?p.Action, target: ModifierTarget) u8 {
        return switch (target) {
            .tap => if (tapPart(action).key_press) |key| key.tap_modifiers.toByte() else 0,
            .hold => holdPart(action).hold_modifiers.toByte(),
            .one_shot => if (tapPart(action).one_shot) |h| h.hold_modifiers.toByte() else 0,
        };
    }
    pub fn modifierState(self: *const Session, target: ModifierTarget, bit: u3) MixedBool {
        var yes = false;
        var no = false;
        for (self.selected, 0..) |selected, i| if (selected) {
            if ((modifierBits(self.drafts[i] orelse self.resolved[i], target) & (@as(u8, 1) << bit)) != 0) yes = true else no = true;
        };
        return if (yes and no) .mixed else if (yes) .on else .off;
    }
    pub fn toggleModifier(self: *Session, target: ModifierTarget, bit: u3) void {
        const set = self.modifierState(target, bit) != .on;
        for (self.selected, 0..) |selected, i| {
            if (!selected) continue;
            const old = self.drafts[i] orelse self.resolved[i];
            var t = tapPart(old);
            var h = holdPart(old);
            var bits = modifierBits(old, target);
            const mask = @as(u8, 1) << bit;
            bits = if (set) bits | mask else bits & ~mask;
            switch (target) {
                .tap => {
                    var key = t.key_press orelse types.KeyCodeFire{};
                    key.tap_modifiers = @bitCast(bits);
                    t.key_press = if (key.tap_keycode == 0 and bits == 0) null else key;
                },
                .hold => h.hold_modifiers = @bitCast(bits),
                .one_shot => {
                    var shot = t.one_shot orelse p.Hold{};
                    shot.hold_modifiers = @bitCast(bits);
                    t.one_shot = if (holdEmpty(shot)) null else shot;
                },
            }
            self.drafts[i] = compose(old, t, h);
        }
    }
};

test "session preserves compound components and clears each side explicitly" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    const compound: p.Action = .{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 4, .dead = true }, .media_key = .VolumeUp, .mouse_action = .LeftButton, .one_shot = .{ .layer_id = 2 } }, .hold = .{ .hold_modifiers = .{ .left_shift = true }, .layer_id = 2 }, .tapping_term = .{ .ms = 231 }, .retro_tapping = true } };
    try model.apply(compound);
    var session = try Session.init(&model);
    session.mutate(.{ .tap_media = null });
    try std.testing.expectEqualDeep(compound.tap_hold.hold, session.first().?.tap_hold.hold);
    try std.testing.expectEqualDeep(compound.tap_hold.tap.key_press, session.first().?.tap_hold.tap.key_press);
    try std.testing.expectEqual(@as(u16, 231), session.first().?.tap_hold.tapping_term.ms);
    session.mutate(.clear_hold);
    try std.testing.expect(session.first().? == .tap_only);
    session.cancel();
    session.mutate(.clear_tap);
    try std.testing.expectEqualDeep(compound.tap_hold.hold, session.first().?.hold_only);
    session.mutate(.clear_hold);
    try std.testing.expect(session.first().? == .none);
    session.cancel();
    try std.testing.expect(!session.dirty());
}

test "bulk mixed modifiers preserve independent taps and commit one undo entry" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    try model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } });
    model.select(11, false);
    try model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 22 } }, .hold = .{ .hold_modifiers = .{ .left_gui = true, .right_shift = true } }, .tapping_term = .{ .ms = 240 } } });
    model.select(10, true);
    const original = try model.id();
    const undo_count = model.undo_stack.items.len;
    var session = try Session.init(&model);
    try std.testing.expectEqual(MixedBool.mixed, session.modifierState(.hold, 3));
    session.toggleModifier(.hold, 3);
    try std.testing.expectEqual(MixedBool.on, session.modifierState(.hold, 3));
    try std.testing.expectEqual(@as(u8, 4), tapPart(session.drafts[10]).key_press.?.tap_keycode);
    try std.testing.expectEqual(@as(u8, 22), tapPart(session.drafts[11]).key_press.?.tap_keycode);
    try std.testing.expect(holdPart(session.drafts[11]).hold_modifiers.right_shift);
    try std.testing.expect(try session.apply(&model));
    try std.testing.expectEqual(undo_count + 1, model.undo_stack.items.len);
    const changed = try model.id();
    try std.testing.expect(!(try session.apply(&model)));
    try model.undo();
    try std.testing.expectEqual(original, try model.id());
    try model.redo();
    try std.testing.expectEqual(changed, try model.id());
}

test "inheritance previews stage local overrides while invalid and stale applies are atomic" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    try model.apply(.{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } });
    model.layer = 1;
    try model.apply(null);
    var session = try Session.init(&model);
    try std.testing.expect(session.first() == null);
    try std.testing.expectEqual(@as(u8, 4), tapPart(session.resolved[10]).key_press.?.tap_keycode);
    session.mutate(.{ .hold_layer = 2 });
    try std.testing.expectEqual(@as(u8, 4), session.first().?.tap_hold.tap.key_press.?.tap_keycode);
    session.mutate(.{ .hold_layer = 999999 });
    const original = try model.id();
    const count = model.undo_stack.items.len;
    if (session.apply(&model)) |_| return error.ExpectedValidationFailure else |_| {}
    try std.testing.expectEqual(original, try model.id());
    try std.testing.expectEqual(count, model.undo_stack.items.len);
    session.cancel();
    session.mutate(.unassign);
    try std.testing.expect(session.first().? == .none);
    try std.testing.expect(try session.apply(&model));
    session.mutate(.inherit);
    try std.testing.expect(session.first() == null);
    try std.testing.expect(try session.apply(&model));
    session.mutate(.{ .tap_key = .{ .tap_keycode = 5 } });
    try model.rename("Changed underlying snapshot");
    try std.testing.expectError(error.StaleSession, session.apply(&model));
}

test "repeat conversions preserve tap fields and save reopen export identity" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    try model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 252 }, .media_key = .VolumeUp }, .hold = .{ .layer_id = 2 }, .tapping_term = .{ .ms = 231 } } });
    var session = try Session.init(&model);
    session.mutate(.{ .mode = .repeat });
    try std.testing.expectEqual(@as(u8, 252), session.first().?.tap_with_autofire.tap.key_press.?.tap_keycode);
    session.mutate(.{ .repeat_interval = 75 });
    try std.testing.expect(try session.apply(&model));
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try model.save(std.testing.io, temporary.dir);
    const identity = try model.id();
    try model.apply(.none);
    try model.open(std.testing.io, temporary.dir);
    try std.testing.expectEqual(identity, try model.id());
    var exported = try temporary.dir.createDirPathOpen(std.testing.io, "export", .{});
    defer exported.close(std.testing.io);
    const manifest = try p.exporter.write(std.testing.allocator, std.testing.io, exported, model.current.snapshot, p.profiles.board);
    defer std.zon.parse.free(std.testing.allocator, manifest);
    try std.testing.expectEqual(identity, manifest.snapshot_id);
}
