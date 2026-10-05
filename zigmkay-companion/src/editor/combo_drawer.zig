const std = @import("std");
const dvui = @import("dvui");
const p = @import("keymap-project");
const forms = @import("forms.zig");
const ui = @import("ui.zig");
pub fn draw(self: anytype, t: ui.Theme) !void {
    const window = ui.editDrawer(@src(), t, 900);
    defer window.deinit();
    dvui.label(@src(), "Combos · stable physical positions and stable layer references", .{}, .{});
    {
        const body = dvui.scrollArea(@src(), .{}, .{ .rect = .{ .x = 0, .y = 36, .w = window.data().rect.w - 36, .h = window.data().rect.h - 160 } });
        defer body.deinit();
        {
            const row = dvui.box(@src(), .{ .dir = .horizontal }, .{});
            defer row.deinit();
            for (self.model.document().combos, 0..) |combo, i| if (dvui.button(@src(), try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s} + {s}", .{ combo.key_ids[0], combo.key_ids[1] }), .{}, .{ .id_extra = i })) {
                self.combo_index = i;
                for (p.profiles.key_ids, 0..) |id, ki| {
                    if (std.mem.eql(u8, id, combo.key_ids[0])) self.combo_keys[0] = ki;
                    if (std.mem.eql(u8, id, combo.key_ids[1])) self.combo_keys[1] = ki;
                }
                for (self.model.document().layers, 0..) |layer, li| if (layer.id == combo.layer_id) {
                    self.combo_layer = li;
                };
                self.combo_timeout = combo.timeout.ms;
                self.combo_draft = forms.Draft.from(combo.action);
            };
        }
        if (dvui.button(@src(), "New combo", .{}, .{})) self.combo_index = null;
        {
            _ = dvui.dropdown(@src(), &p.profiles.key_ids, .{ .choice = &self.combo_keys[0] }, .{}, .{ .expand = .horizontal });
            _ = dvui.dropdown(@src(), &p.profiles.key_ids, .{ .choice = &self.combo_keys[1] }, .{}, .{ .expand = .horizontal });
            var layer_names: [15][]const u8 = undefined;
            for (self.model.document().layers, 0..) |layer, li| layer_names[li] = layer.name;
            self.combo_layer = @min(self.combo_layer, self.model.document().layers.len - 1);
            _ = dvui.dropdown(@src(), layer_names[0..self.model.document().layers.len], .{ .choice = &self.combo_layer }, .{}, .{ .expand = .horizontal });
            dvui.label(@src(), "Combo timeout (ms)", .{}, .{});
            _ = dvui.textEntryNumber(@src(), u16, .{ .value = &self.combo_timeout }, .{});
            forms.draw(&self.combo_draft, self.model.document());
        }
    }
    if (ui.button(t, "Save combo", "combo.save", .{ .x = 0, .y = window.data().rect.h - 86, .w = 150, .h = 40 })) {
        const doc = self.model.document();
        const count = doc.combos.len + @intFromBool(self.combo_index == null);
        if (count > p.Limits.combos) return error.InvalidCombo;
        const combos = try self.gpa.alloc(p.Combo, count);
        defer self.gpa.free(combos);
        @memcpy(combos[0..doc.combos.len], doc.combos);
        const index = self.combo_index orelse doc.combos.len;
        combos[index] = .{ .key_ids = .{ p.profiles.key_ids[self.combo_keys[0]], p.profiles.key_ids[self.combo_keys[1]] }, .layer_id = doc.layers[self.combo_layer].id, .timeout = .{ .ms = self.combo_timeout }, .action = self.combo_draft.action() orelse {
            self.report(error.ComboCannotBeTransparent);
            return;
        } };
        self.model.setCombos(combos) catch |err| {
            self.report(err);
            return;
        };
        self.combo_index = index;
    }
    if (self.combo_index) |index| if (ui.button(t, "Delete combo", "combo.delete", .{ .x = 160, .y = window.data().rect.h - 86, .w = 150, .h = 40 })) {
        const doc = self.model.document();
        const combos = try self.gpa.alloc(p.Combo, doc.combos.len - 1);
        defer self.gpa.free(combos);
        @memcpy(combos[0..index], doc.combos[0..index]);
        @memcpy(combos[index..], doc.combos[index + 1 ..]);
        try self.model.setCombos(combos);
        self.combo_index = null;
    };
    dvui.labelNoFmt(@src(), std.mem.sliceTo(&self.diagnostic, 0), .{}, .{ .rect = .{ .x = 0, .y = window.data().rect.h - 120, .w = window.data().rect.w - 36, .h = 25 }, .color_text = .{ .color = t.text } });
    if (ui.button(t, "Close", "combo.close", .{ .x = 320, .y = window.data().rect.h - 86, .w = 100, .h = 40 })) self.combo_open = false;
}
