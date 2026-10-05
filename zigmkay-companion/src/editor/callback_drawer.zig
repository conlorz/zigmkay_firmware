const std = @import("std");
const dvui = @import("dvui");
const p = @import("keymap-project");
const dialog = @import("dialog.zig");
const ui = @import("ui.zig");
pub fn draw(self: anytype, t: ui.Theme) !void {
    const window = ui.drawer(@src(), t, .{ .x = 460, .y = 180, .w = 800, .h = 630 }, true);
    defer window.deinit();
    dvui.label(@src(), "Callbacks · immutable source snapshots · external Zig editing", .{}, .{});
    dvui.label(@src(), "Attaching/refreshing reads bytes only. Prepare Test explicitly executes compilation/callbacks.", .{}, .{});
    {
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.callback_root }, .placeholder = "Source root directory" }, .{ .expand = .horizontal });
        entry.deinit();
    }
    if (dvui.button(@src(), "Choose source root…", .{}, .{})) {
        self.dialog_target = .callback;
        dialog.start(self.backend_window.?) catch |err| self.report(err);
    }
    {
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.callback_entry }, .placeholder = "Relative entry module, e.g. callbacks.zig" }, .{ .expand = .horizontal });
        entry.deinit();
    }
    {
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.callback_ids }, .placeholder = "Callback IDs, e.g. 1,2 (1–252)" }, .{ .expand = .horizontal });
        entry.deinit();
    }
    if (dvui.button(@src(), "Attach callback ID and complete import closure", .{}, .{})) {
        var dir = std.Io.Dir.cwd().openDir(self.io, std.mem.sliceTo(&self.callback_root, 0), .{}) catch |err| {
            self.report(err);
            return;
        };
        defer dir.close(self.io);
        var bundle = p.sources.capture(self.gpa, self.io, dir, std.mem.sliceTo(&self.callback_entry, 0)) catch |err| {
            self.report(err);
            return;
        };
        defer bundle.deinit();
        var ids: [252]u8 = undefined;
        var count: usize = 0;
        var parts = std.mem.splitScalar(u8, std.mem.sliceTo(&self.callback_ids, 0), ',');
        while (parts.next()) |part| {
            if (count == ids.len) {
                self.report(error.InvalidCallback);
                return;
            }
            ids[count] = std.fmt.parseInt(u8, std.mem.trim(u8, part, " \t"), 10) catch |err| {
                self.report(err);
                return;
            };
            count += 1;
        }
        var loaded = p.sources.attach(self.gpa, self.model.current.snapshot, bundle, ids[0..count], &.{}) catch |err| {
            self.report(err);
            return;
        };
        defer loaded.deinit();
        try self.model.commit(loaded.snapshot);
        self.callback_state = .snapshot;
    }
    const doc = self.model.document();
    if (doc.callbacks.len > 0) {
        const names = try dvui.currentWindow().arena().alloc([]const u8, doc.callbacks.len);
        for (doc.callbacks, names) |callback, *name| name.* = callback.binding;
        self.callback_index = @min(self.callback_index, doc.callbacks.len - 1);
        _ = dvui.dropdown(@src(), names, .{ .choice = &self.callback_index }, .{}, .{ .expand = .horizontal });
        const callback = doc.callbacks[self.callback_index];
        dvui.label(@src(), "{s}; {d} source files; {d} registered IDs; opaque layer index constraints retained", .{ @tagName(callback.kind), callback.sources.len, callback.ids.len }, .{});
        if (callback.kind == .attached) {
            if (dvui.button(@src(), "Check external mirror against frozen snapshot", .{}, .{})) {
                var dir = std.Io.Dir.cwd().openDir(self.io, std.mem.sliceTo(&self.project_path, 0), .{}) catch |err| {
                    self.callback_state = .missing;
                    self.report(err);
                    return;
                };
                defer dir.close(self.io);
                var loaded = p.sources.refresh(self.gpa, self.io, dir, self.model.current.snapshot, self.callback_index) catch |err| {
                    self.callback_state = .missing;
                    self.report(err);
                    return;
                };
                defer loaded.deinit();
                const current = try self.model.id();
                const mirror = try p.snapshot.projectDigest(self.gpa, loaded.snapshot, p.profiles.board);
                self.callback_state = if (std.mem.eql(u8, &current, &mirror)) .snapshot else .changed;
            }
            if (dvui.button(@src(), "Checkout and open externally", .{}, .{})) {
                try self.openCallback(self.callback_index);
            }
            if (dvui.button(@src(), "Refresh edited source snapshot (undoable)", .{}, .{})) {
                var dir = std.Io.Dir.cwd().openDir(self.io, std.mem.sliceTo(&self.project_path, 0), .{}) catch |err| {
                    self.report(err);
                    return;
                };
                defer dir.close(self.io);
                var loaded = p.sources.refresh(self.gpa, self.io, dir, self.model.current.snapshot, self.callback_index) catch |err| {
                    self.report(err);
                    return;
                };
                defer loaded.deinit();
                try self.model.commit(loaded.snapshot);
                self.callback_state = .snapshot;
            }
        }
    }
    dvui.labelNoFmt(@src(), std.mem.sliceTo(&self.diagnostic, 0), .{}, .{});
    if (dvui.button(@src(), "Close callbacks", .{}, .{})) self.callback_open = false;
}
