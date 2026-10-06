//! Descriptive mockup comparison, never an automatic golden-image refresh.
const std = @import("std");
const dvui = @import("dvui");
const geometry = @import("geometry.zig");
/// Read-only regression check. Approval/copying baselines is an explicit workflow.
pub fn golden(gpa: std.mem.Allocator, io: std.Io, path: []const u8, actual: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(32 * 1024 * 1024));
    defer gpa.free(bytes);
    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    const loaded = dvui.c.stbi_load_from_memory(bytes.ptr, @intCast(bytes.len), &width, &height, &channels, 4) orelse return error.GoldenImageDecodeFailed;
    defer dvui.c.stbi_image_free(loaded);
    if (width != 1536 or height != 1024 or actual.len != 1536 * 1024 * 4) return error.GoldenImageDimensions;
    var sum: u64 = 0;
    var changed: usize = 0;
    for (0..1536 * 1024) |pixel| {
        var significant = false;
        for (0..3) |channel| {
            const offset = pixel * 4 + channel;
            const delta = @abs(@as(i16, actual[offset]) - @as(i16, loaded[offset]));
            sum += delta;
            significant = significant or delta > 12;
        }
        if (significant) changed += 1;
    }
    const mean = @as(f64, @floatFromInt(sum)) / (1536 * 1024 * 3);
    std.log.info("Golden {s}: mean RGB delta {d:.4}; significant pixels {d}", .{ path, mean, changed });
    if (mean > 0.5 or changed > (1536 * 1024) / 200) return error.GoldenImageMismatch;
}
const Region = struct { panel: geometry.Panel, expected: geometry.Rect, actual: geometry.Rect, mean_absolute_rgb_difference: f64 };
pub fn write(gpa: std.mem.Allocator, io: std.Io, reference_path: []const u8, actual: []const u8, output_path: []const u8, light: bool, scale: f32) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, reference_path, gpa, .limited(32 * 1024 * 1024));
    defer gpa.free(bytes);
    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    const loaded = dvui.c.stbi_load_from_memory(bytes.ptr, @intCast(bytes.len), &width, &height, &channels, 4) orelse return error.ReferenceImageDecodeFailed;
    defer dvui.c.stbi_image_free(loaded);
    if (width != 1536 or height != 1024 or actual.len != 1536 * 1024 * 4) return error.ReferenceImageDimensions;
    const reference = loaded[0..actual.len];
    var regions: std.ArrayList(Region) = .empty;
    defer regions.deinit(gpa);
    for (geometry.reference, 0..) |bounds, i| {
        const name = @as(geometry.Panel, @enumFromInt(i));
        // The retired draft launcher has no native panel to compare.
        if (name == .testing) continue;
        const tag = dvui.tagGet(@tagName(name)) orelse return error.MissingPanelTag;
        const a = tag.rect;
        var sum: u64 = 0;
        var count: u64 = 0;
        const x_start: usize = @intFromFloat(bounds.x);
        const y_start: usize = @intFromFloat(bounds.y);
        for (y_start..y_start + @as(usize, @intFromFloat(bounds.h))) |y| for (x_start..x_start + @as(usize, @intFromFloat(bounds.w))) |x| {
            const offset = (y * 1536 + x) * 4;
            for (0..3) |channel| {
                sum += @abs(@as(i16, actual[offset + channel]) - @as(i16, reference[offset + channel]));
                count += 1;
            }
        };
        try regions.append(gpa, .{ .panel = name, .expected = bounds, .actual = .{ .x = a.x / scale, .y = a.y / scale, .w = a.w / scale, .h = a.h / scale }, .mean_absolute_rgb_difference = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(count)) });
    }
    var reference_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &reference_hash, .{});
    var pixels_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(actual, &pixels_hash, .{});
    var encoded: std.Io.Writer.Allocating = .init(gpa);
    defer encoded.deinit();
    try std.zon.stringify.serializeMaxDepth(.{ .version = @as(u16, 1), .viewport = [2]u32{ 1536, 1024 }, .native_scale = scale, .theme = if (light) "light" else "dark", .font = "macOS system SFNS + installed Arial Unicode glyph fallback; retained Vera elsewhere", .fixture = "EurKEY Next 2026.03.22; inert callback bytes", .reference_sha256 = reference_hash, .actual_rgba_sha256 = pixels_hash, .regions = regions.items, .comparison = "Descriptive RGB differences; generated mockup typography and correctness deviations require visual review; no zero-difference acceptance implied" }, .{}, &encoded.writer, 32);
    const report = try std.fmt.allocPrint(gpa, "{s}.report.zon", .{output_path});
    defer gpa.free(report);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = report, .data = encoded.written() });
    const overlay = try gpa.alloc(u8, actual.len);
    defer gpa.free(overlay);
    for (actual, reference, overlay) |a, b, *out| out.* = @intCast((@as(u16, a) + b) / 2);
    var png: std.Io.Writer.Allocating = .init(gpa);
    defer png.deinit();
    try png.ensureTotalCapacity(4096);
    try dvui.PNGEncoder.writeWithResolution(&png.writer, overlay, 1536, 1024, 0);
    const overlay_path = try std.fmt.allocPrint(gpa, "{s}.overlay.png", .{output_path});
    defer gpa.free(overlay_path);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = overlay_path, .data = png.written() });
}
