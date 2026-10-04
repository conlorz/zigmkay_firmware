//! UI-thread document ownership and bounded snapshot history. Each edit commits
//! one validated immutable snapshot; refused edits leave history and dirty state intact.
const std = @import("std");
const p = @import("keymap-project");
pub const Model = struct {
    gpa: std.mem.Allocator,
    current: p.snapshot.Loaded,
    undo_stack: std.ArrayList(p.snapshot.Loaded) = .empty,
    redo_stack: std.ArrayList(p.snapshot.Loaded) = .empty,
    saved_id: [32]u8,
    layer: usize = 0,
    selected: [34]bool = @splat(false),
    primary: usize = 10,
    clipboard: ?p.Action = null,
    clipboard_set: bool = false,
    next_layer_id: p.LayerId = 100,
    pub fn init(gpa: std.mem.Allocator, profile: p.profiles.Profile) !Model {
        var loaded = try p.profiles.create(gpa, profile);
        errdefer loaded.deinit();
        var self = Model{ .gpa = gpa, .current = loaded, .saved_id = try p.snapshot.projectDigest(gpa, loaded.snapshot, p.profiles.board) };
        self.selected[self.primary] = true;
        return self;
    }
    pub fn deinit(self: *Model) void {
        self.current.deinit();
        self.clear(&self.undo_stack);
        self.clear(&self.redo_stack);
        self.undo_stack.deinit(self.gpa);
        self.redo_stack.deinit(self.gpa);
    }
    fn clear(_: *Model, stack: *std.ArrayList(p.snapshot.Loaded)) void {
        for (stack.items) |*loaded| loaded.deinit();
        stack.clearRetainingCapacity();
    }
    pub fn id(self: *const Model) ![32]u8 {
        return p.snapshot.projectDigest(self.gpa, self.current.snapshot, p.profiles.board);
    }
    pub fn dirty(self: *const Model) bool {
        const actual = self.id() catch return true;
        return !std.mem.eql(u8, &actual, &self.saved_id);
    }
    pub fn document(self: *const Model) p.Document {
        return self.current.snapshot.document;
    }
    pub fn action(self: *const Model) ?p.Action {
        return self.document().layers[self.layer].actions[self.primary];
    }
    pub fn select(self: *Model, index: usize, extend: bool) void {
        if (index >= self.selected.len) return;
        if (!extend) self.selected = @splat(false);
        self.selected[index] = if (extend) !self.selected[index] else true;
        self.primary = index;
    }
    pub fn commit(self: *Model, snapshot: p.snapshot.Snapshot) !void {
        try p.snapshot.validate(snapshot, p.profiles.board);
        try p.sources.verify(self.gpa, snapshot);
        var next = try p.snapshot.clone(self.gpa, snapshot);
        errdefer next.deinit();
        const old_id = try self.id();
        const new_id = try p.snapshot.projectDigest(self.gpa, next.snapshot, p.profiles.board);
        if (std.mem.eql(u8, &old_id, &new_id)) {
            next.deinit();
            return;
        }
        try self.undo_stack.append(self.gpa, self.current);
        if (self.undo_stack.items.len > 32) {
            var removed = self.undo_stack.orderedRemove(0);
            removed.deinit();
        }
        self.current = next;
        self.clear(&self.redo_stack);
        self.layer = @min(self.layer, self.document().layers.len - 1);
    }
    pub fn undo(self: *Model) !void {
        if (self.undo_stack.items.len == 0) return;
        try self.redo_stack.append(self.gpa, self.current);
        self.current = self.undo_stack.pop().?;
        self.layer = @min(self.layer, self.document().layers.len - 1);
    }
    pub fn redo(self: *Model) !void {
        if (self.redo_stack.items.len == 0) return;
        try self.undo_stack.append(self.gpa, self.current);
        self.current = self.redo_stack.pop().?;
        self.layer = @min(self.layer, self.document().layers.len - 1);
    }
    pub fn apply(self: *Model, value: ?p.Action) !void {
        var arena: std.heap.ArenaAllocator = .init(self.gpa);
        defer arena.deinit();
        var snapshot = self.current.snapshot;
        const layers = try arena.allocator().dupe(p.Layer, self.document().layers);
        const actions = try arena.allocator().dupe(?p.Action, layers[self.layer].actions);
        for (&self.selected, actions) |selected, *entry| if (selected) {
            entry.* = value;
        };
        layers[self.layer].actions = actions;
        snapshot.document.layers = layers;
        try self.commit(snapshot);
    }
    pub fn copy(self: *Model) void {
        self.clipboard = self.action();
        self.clipboard_set = true;
    }
    pub fn paste(self: *Model) !void {
        if (self.clipboard_set) try self.apply(self.clipboard);
    }
    pub fn rename(self: *Model, name: []const u8) !void {
        var layers: [p.Limits.layers]p.Layer = undefined;
        const count = self.document().layers.len;
        @memcpy(layers[0..count], self.document().layers);
        layers[self.layer].name = name;
        var snapshot = self.current.snapshot;
        snapshot.document.layers = layers[0..count];
        try self.commit(snapshot);
    }
    pub fn addLayer(self: *Model, duplicate: bool) !void {
        const doc = self.document();
        if (doc.layers.len == p.Limits.layers) return error.InvalidDimensions;
        var layers: [p.Limits.layers]p.Layer = undefined;
        @memcpy(layers[0..doc.layers.len], doc.layers);
        var empty: [34]?p.Action = @splat(null);
        var name_buffer: [128]u8 = undefined;
        const name = if (duplicate) try std.fmt.bufPrint(&name_buffer, "{s} copy", .{doc.layers[self.layer].name}) else "New layer";
        while (true) {
            var used = false;
            for (doc.layers) |existing| if (existing.id == self.next_layer_id) {
                used = true;
                break;
            };
            if (!used) break;
            self.next_layer_id = std.math.add(p.LayerId, self.next_layer_id, 1) catch return error.LayerIdExhausted;
        }
        layers[doc.layers.len] = .{ .id = self.next_layer_id, .name = name, .actions = if (duplicate) doc.layers[self.layer].actions else &empty };
        var snapshot = self.current.snapshot;
        snapshot.document.layers = layers[0 .. doc.layers.len + 1];
        try self.commit(snapshot);
        self.next_layer_id +%= 1;
        self.layer = doc.layers.len;
    }
    pub fn deleteLayer(self: *Model, index: usize) !void {
        const doc = self.document();
        if (index >= doc.layers.len) return error.InvalidLayer;
        try p.canDeleteLayer(doc, doc.layers[index].id);
        var layers: [p.Limits.layers]p.Layer = undefined;
        @memcpy(layers[0..index], doc.layers[0..index]);
        @memcpy(layers[index .. doc.layers.len - 1], doc.layers[index + 1 ..]);
        var snapshot = self.current.snapshot;
        snapshot.document.layers = layers[0 .. doc.layers.len - 1];
        try self.commit(snapshot);
    }
    pub fn setCombos(self: *Model, combos: []const p.Combo) !void {
        var snapshot = self.current.snapshot;
        snapshot.document.combos = combos;
        try self.commit(snapshot);
    }
    pub fn setEncoders(self: *Model, encoders: []const p.Tap) !void {
        var snapshot = self.current.snapshot;
        snapshot.document.encoders = encoders;
        try self.commit(snapshot);
    }
    pub fn save(self: *Model, io: std.Io, dir: std.Io.Dir) !void {
        try p.snapshot.save(self.gpa, io, dir, self.current.snapshot, p.profiles.board);
        self.saved_id = try self.id();
    }
    pub fn open(self: *Model, io: std.Io, dir: std.Io.Dir) !void {
        var loaded = try p.snapshot.load(self.gpa, io, dir, p.profiles.board);
        defer loaded.deinit();
        try self.commit(loaded.snapshot);
        self.saved_id = try self.id();
    }
};

test "bulk edits, metadata, constrained deletion and history survive save/reopen" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    const original = try model.id();
    model.select(11, true);
    try model.apply(.{ .tap_hold = .{ .tap = .{ .key_press = .{ .tap_keycode = 4, .dead = true } }, .hold = .{ .layer_id = 2 }, .tapping_term = .{ .ms = 180 }, .retro_tapping = true } });
    try std.testing.expect(model.dirty());
    try std.testing.expectEqual(model.document().layers[0].actions[10], model.document().layers[0].actions[11]);
    try model.undo();
    try std.testing.expectEqual(original, try model.id());
    try model.redo();
    try std.testing.expectError(error.LayerReferenced, model.deleteLayer(1));
    try model.addLayer(true);
    try model.rename("Copied draft");
    try model.deleteLayer(6);
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try model.save(std.testing.io, temporary.dir);
    try std.testing.expect(!model.dirty());
    const saved = try model.id();
    try model.apply(.none);
    try model.open(std.testing.io, temporary.dir);
    try std.testing.expectEqual(saved, try model.id());
    try std.testing.expect(!model.dirty());
    var exported = try temporary.dir.createDirPathOpen(std.testing.io, "export", .{});
    defer exported.close(std.testing.io);
    const manifest = try p.exporter.write(std.testing.allocator, std.testing.io, exported, model.current.snapshot, p.profiles.board);
    defer std.zon.parse.free(std.testing.allocator, manifest);
    try std.testing.expectEqual(saved, manifest.snapshot_id);
    const repeated = try p.exporter.write(std.testing.allocator, std.testing.io, exported, model.current.snapshot, p.profiles.board);
    defer std.zon.parse.free(std.testing.allocator, repeated);
    try std.testing.expectEqualDeep(manifest, repeated);
}

test "imported stable layer IDs cannot collide with new layers" {
    var model = try Model.init(std.testing.allocator, .eurkey);
    defer model.deinit();
    try model.addLayer(false);
    model.next_layer_id = 100;
    try model.addLayer(false);
    try std.testing.expectEqual(@as(p.LayerId, 101), model.document().layers[7].id);
    try model.undo();
    try model.redo();
    try p.validate(model.document(), p.profiles.board);
}
