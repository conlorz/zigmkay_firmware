//! Offline firmware build contract. Callers capture verified exports and all
//! compiler/dependency/build inputs before invoking the existing Job boundary.
const std = @import("std");
const uf2 = @import("firmware-uf2");
pub const Digest = [32]u8;
pub fn digest(bytes: []const u8) Digest {
    var result: Digest = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

pub const Inputs = struct {
    project_digest: Digest,
    source_digest: Digest,
    build_inputs_digest: Digest,
    board: []const u8 = "lk7",
    profile_id: [8]u8,
    identity_digest: [16]u8,
    zig_version: []const u8 = "0.16.0",
    compiler_digest: Digest,
    target: []const u8 = "thumb-freestanding-eabi",
    optimize: []const u8 = "ReleaseSafe",
    git_revision: ?[]const u8 = null,
};

fn field(hash: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    var len: [8]u8 = undefined;
    std.mem.writeInt(u64, &len, bytes.len, .little);
    hash.update(&len);
    hash.update(bytes);
}

/// Includes the complete owned source inventory digest, independently of live
/// telemetry identity (metadata changes still invalidate a build).
pub fn key(input: Inputs) Digest {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("zigmkay-firmware-manifest-v1\x00");
    hash.update(&input.project_digest);
    hash.update(&input.source_digest);
    hash.update(&input.build_inputs_digest);
    hash.update(&input.compiler_digest);
    hash.update(&input.profile_id);
    hash.update(&input.identity_digest);
    for ([_][]const u8{ input.board, input.zig_version, input.target, input.optimize }) |value| field(&hash, value);
    hash.update(&.{@intFromBool(input.git_revision != null)});
    if (input.git_revision) |revision| field(&hash, revision);
    return hash.finalResult();
}

fn validateInputs(input: Inputs) !void {
    if (!std.mem.eql(u8, input.board, "lk7")) return error.UnsupportedBoard;
    if (!std.mem.eql(u8, input.zig_version, "0.16.0")) return error.UnsupportedCompilerVersion;
    if (!std.mem.eql(u8, input.target, "thumb-freestanding-eabi")) return error.UnsupportedTarget;
    if (!std.mem.eql(u8, input.optimize, "ReleaseSafe")) return error.UnsupportedOptimization;
}

pub const Command = struct {
    arena: std.heap.ArenaAllocator,
    argv: []const []const u8,
    cwd: []const u8,
    uf2_path: []const u8,
    build_key: Digest,

    /// Every path is an absolute literal argument. There is no shell, flash
    /// step, device discovery or bootloader dispatch in this command.
    pub fn init(gpa: std.mem.Allocator, input: Inputs, compiler: []const u8, repository: []const u8, export_directory: []const u8, install_directory: []const u8) !Command {
        try validateInputs(input);
        for ([_][]const u8{ compiler, repository, export_directory, install_directory }) |path| {
            if (!std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidBuildPath;
        }
        var arena: std.heap.ArenaAllocator = .init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();
        const args = try a.alloc([]const u8, 10);
        args[0] = try a.dupe(u8, compiler);
        args[1] = "build";
        args[2] = "--build-file";
        args[3] = "keyboards/build.zig";
        args[4] = "firmware";
        args[5] = "-Dkeyboard=lk7";
        args[6] = try std.fmt.allocPrint(a, "-Dprofile={s}", .{export_directory});
        args[7] = "-Doptimize=ReleaseSafe";
        args[8] = "-p";
        args[9] = try a.dupe(u8, install_directory);
        return .{ .arena = arena, .argv = args, .cwd = try a.dupe(u8, repository), .uf2_path = try std.fs.path.join(a, &.{ install_directory, "firmware", "lk7", "zigmkay.uf2" }), .build_key = key(input) };
    }

    pub fn deinit(self: *Command) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Completion = enum { succeeded, failed, cancelled };

/// An owned frozen value: it never aliases editable input strings. A failed or
/// cancelled job cannot manufacture a manifest around an earlier UF2 file.
pub const Manifest = struct {
    arena: std.heap.ArenaAllocator,
    version: u32 = 1,
    inputs: Inputs,
    build_key: Digest,
    uf2_path: []const u8,
    uf2_size: usize,
    uf2_hash: Digest,

    pub fn complete(gpa: std.mem.Allocator, completion: Completion, prepared_key: Digest, captured: Inputs, current: Inputs, path: []const u8, bytes: []const u8) !Manifest {
        switch (completion) {
            .failed => return error.BuildFailed,
            .cancelled => return error.BuildCancelled,
            .succeeded => {},
        }
        try validateInputs(captured);
        if (!std.mem.eql(u8, &prepared_key, &key(captured)) or !std.mem.eql(u8, &prepared_key, &key(current))) return error.StaleBuild;
        if (!std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidArtifactPath;
        try uf2.validate(gpa, bytes);
        var arena: std.heap.ArenaAllocator = .init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();
        var owned = captured;
        owned.board = try a.dupe(u8, captured.board);
        owned.zig_version = try a.dupe(u8, captured.zig_version);
        owned.target = try a.dupe(u8, captured.target);
        owned.optimize = try a.dupe(u8, captured.optimize);
        if (captured.git_revision) |revision| owned.git_revision = try a.dupe(u8, revision);
        return .{ .arena = arena, .inputs = owned, .build_key = prepared_key, .uf2_path = try a.dupe(u8, path), .uf2_size = bytes.len, .uf2_hash = digest(bytes) };
    }

    pub fn fresh(self: Manifest, current: Inputs) bool {
        return std.mem.eql(u8, &self.build_key, &key(current));
    }

    /// Persist this versioned record beside the UF2. Filesystem ownership and
    /// atomic replacement stay with the caller, never with the build process.
    pub fn serialize(self: Manifest, gpa: std.mem.Allocator) ![]u8 {
        var out: std.Io.Writer.Allocating = .init(gpa);
        errdefer out.deinit();
        try std.zon.stringify.serializeMaxDepth(.{
            .version = self.version,
            .inputs = self.inputs,
            .build_key = self.build_key,
            .uf2_path = self.uf2_path,
            .uf2_size = self.uf2_size,
            .uf2_hash = self.uf2_hash,
        }, .{}, &out.writer, 32);
        return out.toOwnedSlice();
    }

    /// Re-read the exact recorded path through the caller's filesystem adapter
    /// and check these bytes immediately before offering a transfer.
    pub fn verify(self: Manifest, gpa: std.mem.Allocator, current: Inputs, bytes: []const u8) !void {
        if (!self.fresh(current)) return error.StaleBuild;
        if (bytes.len != self.uf2_size or !std.mem.eql(u8, &self.uf2_hash, &digest(bytes))) return error.ArtifactChanged;
        try uf2.validate(gpa, bytes);
    }

    pub fn deinit(self: *Manifest) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

fn fixture() [512]u8 {
    var bytes: [512]u8 = @splat(0);
    for ([_]struct { usize, u32 }{ .{ 0, 0x0a324655 }, .{ 4, 0x9e5d5157 }, .{ 8, 0x2000 }, .{ 12, 0x10000000 }, .{ 16, 256 }, .{ 24, 1 }, .{ 28, 0xe48bff56 }, .{ 508, 0x0ab16f30 } }) |entry| std.mem.writeInt(u32, bytes[entry[0]..][0..4], entry[1], .little);
    return bytes;
}

fn inputs() Inputs {
    return .{ .project_digest = @splat(1), .source_digest = @splat(2), .build_inputs_digest = @splat(3), .compiler_digest = @splat(4), .profile_id = @splat(5), .identity_digest = @splat(6) };
}

test "firmware argv preserves literal metacharacters and selects build only" {
    var command = try Command.init(std.testing.allocator, inputs(), "/compiler with spaces/zig", "/repo", "/export ; $(touch nope)", "/cache ; output");
    defer command.deinit();
    try std.testing.expectEqualStrings("-Dprofile=/export ; $(touch nope)", command.argv[6]);
    try std.testing.expectEqualStrings("/cache ; output", command.argv[9]);
    try std.testing.expectEqualStrings("/cache ; output/firmware/lk7/zigmkay.uf2", command.uf2_path);
    try std.testing.expectError(error.InvalidBuildPath, Command.init(std.testing.allocator, inputs(), "zig", "/repo", "/export", "/cache"));
}

test "manifest rejects failures cancellation stale input and corrupt artifact" {
    const a = std.testing.allocator;
    const captured = inputs();
    var bytes = fixture();
    try std.testing.expectError(error.BuildFailed, Manifest.complete(a, .failed, key(captured), captured, captured, "/cache/firmware.uf2", &bytes));
    try std.testing.expectError(error.BuildCancelled, Manifest.complete(a, .cancelled, key(captured), captured, captured, "/cache/firmware.uf2", &bytes));
    var current = captured;
    current.source_digest[0] ^= 1;
    try std.testing.expectError(error.StaleBuild, Manifest.complete(a, .succeeded, key(captured), captured, current, "/cache/firmware.uf2", &bytes));
    var manifest = try Manifest.complete(a, .succeeded, key(captured), captured, captured, "/cache/firmware.uf2", &bytes);
    defer manifest.deinit();
    const record = try manifest.serialize(a);
    defer a.free(record);
    try std.testing.expect(std.mem.indexOf(u8, record, "compiler_digest") != null);
    try manifest.verify(a, captured, &bytes);
    try std.testing.expectError(error.StaleBuild, manifest.verify(a, current, &bytes));
    bytes[32] ^= 1;
    try std.testing.expectError(error.ArtifactChanged, manifest.verify(a, captured, &bytes));
    bytes[0] = 0;
    try std.testing.expectError(error.InvalidUf2Magic, Manifest.complete(a, .succeeded, key(captured), captured, captured, "/cache/firmware.uf2", &bytes));
}

test "every compiler build project identity input invalidates manifests" {
    const original = inputs();
    inline for (.{ "project_digest", "source_digest", "build_inputs_digest", "compiler_digest", "profile_id", "identity_digest" }) |name| {
        var changed = original;
        @field(changed, name)[0] ^= 1;
        try std.testing.expect(!std.mem.eql(u8, &key(original), &key(changed)));
    }
    var changed = original;
    changed.git_revision = "new revision";
    try std.testing.expect(!std.mem.eql(u8, &key(original), &key(changed)));
}

test "manifest freezes provenance and rejects an unpinned compiler" {
    const a = std.testing.allocator;
    var revision = [_]u8{ 'a', 'b', 'c' };
    var captured = inputs();
    captured.git_revision = &revision;
    const bytes = fixture();
    var manifest = try Manifest.complete(a, .succeeded, key(captured), captured, captured, "/cache/firmware.uf2", &bytes);
    defer manifest.deinit();
    revision[0] = 'z';
    try std.testing.expectEqualStrings("abc", manifest.inputs.git_revision.?);
    try std.testing.expect(!manifest.fresh(captured));
    captured.zig_version = "0.15.2";
    try std.testing.expectError(error.UnsupportedCompilerVersion, Command.init(a, captured, "/zig", "/repo", "/export", "/cache"));
}
