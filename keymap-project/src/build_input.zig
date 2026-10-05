const std = @import("std");
const contract = @import("build_contract.zig");
pub const Selected = struct { module: *std.Build.Module, snapshot_id: [32]u8, manifest: contract.Manifest };
pub fn portablePath(path: []const u8) bool {
    return @import("portable_path.zig").valid(path, 512);
}
/// Shared selector used by host runner and firmware; hashes all files before adding modules.
pub fn load(b: *std.Build, path: []const u8, firmware: *std.Build.Module, keycodes: *std.Build.Module, model: *std.Build.Module) !Selected {
    const io = b.graph.io;
    const gpa = b.allocator;
    if (!std.fs.path.isAbsolute(path)) return error.ProfilePathMustBeAbsolute;
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{});
    defer dir.close(io);
    const bytes = try dir.readFileAlloc(io, "manifest.zon", gpa, .limited(1024 * 1024));
    const text = try gpa.dupeZ(u8, bytes);
    var diagnostics: std.zon.parse.Diagnostics = .{};
    defer diagnostics.deinit(gpa);
    const manifest = try std.zon.parse.fromSliceAlloc(contract.Manifest, gpa, text, &diagnostics, .{});
    if (manifest.version != contract.version or manifest.files.len == 0 or manifest.files.len > 65 or manifest.callbacks.len > 64 or !portablePath(manifest.keymap)) return error.InvalidExportManifest;
    const captured = b.addWriteFiles();
    var total: usize = 0;
    for (manifest.files, 0..) |file, index| {
        if (!portablePath(file.path)) return error.InvalidExportPath;
        for (manifest.files[0..index]) |earlier| if (std.mem.eql(u8, earlier.path, file.path)) return error.DuplicateExportFile;
        const data = try dir.readFileAlloc(io, file.path, gpa, .limited(4 * 1024 * 1024));
        total += data.len;
        if (total > 6 * 1024 * 1024) return error.ExportTooLarge;
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
        if (!std.mem.eql(u8, &hash, &file.digest)) return error.ExportSourceMismatch;
        _ = captured.add(file.path, data);
    }
    const imports: []const std.Build.Module.Import = &.{ .{ .name = "zigmkay", .module = firmware }, .{ .name = "zkeycodes", .module = keycodes }, .{ .name = "layout-model", .module = model } };
    const module = b.createModule(.{ .root_source_file = captured.getDirectory().path(b, manifest.keymap), .imports = imports });
    try listed(manifest, manifest.keymap);
    for (manifest.callbacks, 0..) |callback, index| {
        if (!portablePath(callback.entry)) return error.InvalidExportPath;
        try listed(manifest, callback.entry);
        const handler = b.createModule(.{ .root_source_file = captured.getDirectory().path(b, callback.entry), .imports = imports });
        module.addImport(b.fmt("callback_{d}", .{index}), handler);
    }
    return .{ .module = module, .snapshot_id = manifest.snapshot_id, .manifest = manifest };
}
fn listed(manifest: contract.Manifest, path: []const u8) !void {
    for (manifest.files) |file| if (std.mem.eql(u8, file.path, path)) return;
    return error.UnlistedExportFile;
}
