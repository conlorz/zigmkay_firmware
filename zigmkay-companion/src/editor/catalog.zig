const std = @import("std");
const p = @import("keymap-project");
const model = @import("layout-model");
const labels = @import("labels.zig");

pub const Target = enum { tap, hold };
pub const Category = enum { all, key, modifier, layer, media, mouse, callback, one_shot, signal };
pub const Entry = union(enum) {
    key: u8,
    modifier: u8,
    layer: p.LayerId,
    media: model.MediaCode,
    mouse: model.MouseAction,
    callback: u8,
    one_shot,
    signal: u8,
};
pub fn available(target: Target, category: Category) bool {
    return target == .tap or switch (category) {
        .all, .modifier, .layer, .callback => true,
        else => false,
    };
}
pub fn label(entry: Entry, doc: p.Document, buffer: []u8) []const u8 {
    return switch (entry) {
        .key => |code| labels.hostUsage(labels.running_host, code, buffer),
        .modifier => |bit| labels.hostModifierNames(labels.running_host, @as(u8, 1) << @intCast(bit), buffer),
        .layer => |id| blk: {
            for (doc.layers) |layer| if (layer.id == id) break :blk std.fmt.bufPrint(buffer, "Layer {d}: {s}", .{ id, layer.name }) catch "Layer";
            break :blk std.fmt.bufPrint(buffer, "Layer {d}", .{id}) catch "Layer";
        },
        .media => |value| @tagName(value),
        .mouse => |value| @tagName(value),
        .callback => |id| std.fmt.bufPrint(buffer, "Callback {d}", .{id}) catch "Callback",
        .one_shot => "One-shot",
        .signal => |id| labels.signal(id, buffer),
    };
}
fn append(doc: p.Document, target: Target, category: Category, query: []const u8, entry: Entry, out: []Entry, count: *usize) void {
    const kind: Category = switch (entry) {
        .key => .key,
        .modifier => .modifier,
        .layer => .layer,
        .media => .media,
        .mouse => .mouse,
        .callback => .callback,
        .one_shot => .one_shot,
        .signal => .signal,
    };
    if (!available(target, kind) or (category != .all and category != kind) or count.* == out.len) return;
    var buffer: [256]u8 = undefined;
    const matches = switch (entry) {
        .key => |code| labels.matchesUsage(labels.running_host, code, query),
        .modifier => |bit| labels.matchesUsage(labels.running_host, 224 + bit, query),
        else => labels.containsIgnoreCase(label(entry, doc, &buffer), query),
    };
    if (matches) {
        out[count.*] = entry;
        count.* += 1;
    }
}
/// Caller-owned storage bounds results; no allocation or hidden picker state.
pub fn search(doc: p.Document, target: Target, category: Category, query: []const u8, out: []Entry) usize {
    var count: usize = 0;
    inline for (@typeInfo(@import("zkeycodes").layouts.keycodes.kc.basic).@"enum".fields) |field| {
        if (field.value < 224) append(doc, target, category, query, .{ .key = @intCast(field.value) }, out, &count);
    }
    append(doc, target, category, query, .{ .key = 252 }, out, &count);
    for (0..8) |bit| append(doc, target, category, query, .{ .modifier = @intCast(bit) }, out, &count);
    if (target == .hold) for (doc.layers) |layer| append(doc, target, category, query, .{ .layer = layer.id }, out, &count);
    inline for (@typeInfo(model.MediaCode).@"enum".fields) |field| append(doc, target, category, query, .{ .media = @enumFromInt(field.value) }, out, &count);
    inline for (@typeInfo(model.MouseAction).@"enum".fields) |field| append(doc, target, category, query, .{ .mouse = @enumFromInt(field.value) }, out, &count);
    var callbacks: [256]bool = @splat(false);
    for (doc.callbacks) |callback| for (callback.ids) |id| {
        callbacks[id] = true;
    };
    for (callbacks, 0..) |present, id| if (present) {
        append(doc, target, category, query, .{ .callback = @intCast(id) }, out, &count);
    };
    append(doc, target, category, query, .one_shot, out, &count);
    for (253..256) |id| append(doc, target, category, query, .{ .signal = @intCast(id) }, out, &count);
    return count;
}
