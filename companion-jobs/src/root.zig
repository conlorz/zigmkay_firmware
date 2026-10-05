const std = @import("std");
pub const firmware = @import("firmware.zig");
pub const output_limit = 1024 * 1024;
pub const SnapshotId = [32]u8;
pub const Spec = struct { argv: []const []const u8, cwd: []const u8, snapshot_id: SnapshotId, timeout_ms: u32 = 60_000 };
pub const Result = struct {
    process: std.process.RunResult,
    snapshot_id: SnapshotId,
    elapsed_ns: i96,
    pub fn deinit(self: *Result, gpa: std.mem.Allocator) void {
        gpa.free(self.process.stdout);
        gpa.free(self.process.stderr);
        self.* = undefined;
    }
    pub fn successful(self: Result) bool {
        return switch (self.process.term) {
            .exited => |code| code == 0,
            else => false,
        };
    }
    pub fn fresh(self: Result, current: SnapshotId) bool {
        return std.mem.eql(u8, &self.snapshot_id, &current);
    }
};
fn execute(gpa: std.mem.Allocator, io: std.Io, spec: Spec) anyerror!std.process.RunResult {
    const timeout: std.Io.Timeout = .{ .duration = .{ .raw = .fromMilliseconds(spec.timeout_ms), .clock = .awake } };
    return std.process.run(gpa, io, .{ .argv = spec.argv, .cwd = .{ .path = spec.cwd }, .stdout_limit = .limited(output_limit), .stderr_limit = .limited(output_limit), .timeout = timeout.toDeadline(io) });
}
fn expire(io: std.Io, milliseconds: u32) anyerror!void {
    try std.Io.sleep(io, .fromMilliseconds(milliseconds), .awake);
}
/// Runs argv directly, concurrently drains stdout/stderr, and kills/reaps on timeout/cancel.
/// Includes a watchdog around wait too, even if a hung child closes its output pipes.
pub fn run(gpa: std.mem.Allocator, io: std.Io, spec: Spec) !Result {
    const start = std.Io.Clock.awake.now(io);
    const Completion = union(enum) { process: anyerror!std.process.RunResult, timeout: anyerror!void };
    var buffer: [2]Completion = undefined;
    var select = std.Io.Select(Completion).init(io, &buffer);
    defer {
        while (select.cancel()) |pending| if (pending == .process) {
            if (pending.process) |result| {
                gpa.free(result.stdout);
                gpa.free(result.stderr);
            } else |_| {}
        };
    }
    try select.concurrent(.process, execute, .{ gpa, io, spec });
    try select.concurrent(.timeout, expire, .{ io, spec.timeout_ms });
    const completed = try select.await();
    switch (completed) {
        .timeout => |status| {
            try status;
            return error.Timeout;
        },
        .process => |status| return .{ .process = try status, .snapshot_id = spec.snapshot_id, .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds },
    }
}
/// Stable-address owner for one asynchronous job. All args/cwd are copied before start.
pub const Job = struct {
    arena: std.heap.ArenaAllocator,
    gpa: std.mem.Allocator,
    io: std.Io,
    spec: Spec,
    done: std.atomic.Value(bool) = .init(false),
    future: ?std.Io.Future(anyerror!Result) = null,
    pub fn init(gpa: std.mem.Allocator, io: std.Io, spec: Spec) !Job {
        var arena: std.heap.ArenaAllocator = .init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();
        const args = try a.alloc([]const u8, spec.argv.len);
        for (spec.argv, args) |arg, *dest| dest.* = try a.dupe(u8, arg);
        const cwd = try a.dupe(u8, spec.cwd);
        var copied = spec;
        copied.argv = args;
        copied.cwd = cwd;
        return .{ .arena = arena, .gpa = gpa, .io = io, .spec = copied };
    }
    fn work(self: *Job) anyerror!Result {
        defer self.done.store(true, .release);
        return run(self.gpa, self.io, self.spec);
    }
    pub fn start(self: *Job) !void {
        if (self.future != null) return error.JobAlreadyStarted;
        self.future = try std.Io.concurrent(self.io, work, .{self});
    }
    pub fn poll(self: *Job) ?anyerror!Result {
        if (self.future == null or !self.done.load(.acquire)) return null;
        const result = self.future.?.await(self.io);
        self.future = null;
        return result;
    }
    pub fn cancel(self: *Job) void {
        if (self.future) |*future| {
            if (future.cancel(self.io)) |result| {
                var owned = result;
                owned.deinit(self.gpa);
            } else |_| {}
            self.future = null;
        }
    }
    pub fn deinit(self: *Job) void {
        self.cancel();
        self.arena.deinit();
        self.* = undefined;
    }
};

/// One runner pipe session. A stable-address owner serializes requests; timeouts kill it.
/// No response or input can grow without a bound. Reset means stop and spawn a new process.
pub const Session = struct {
    pub const reply_limit = 1024 * 1024;
    child: ?std.process.Child = null,
    buffer: [reply_limit]u8 = undefined,
    reader: ?std.Io.File.Reader = null,
    pub fn start(self: *Session, io: std.Io, argv: []const []const u8) !void {
        if (self.child != null) return error.SessionAlreadyStarted;
        self.child = try std.process.spawn(io, .{ .argv = argv, .stdin = .pipe, .stdout = .pipe, .stderr = .ignore });
        self.reader = self.child.?.stdout.?.readerStreaming(io, &self.buffer);
    }
    fn exchange(self: *Session, gpa: std.mem.Allocator, io: std.Io, frame: ?[]const u8) anyerror![]u8 {
        if (frame) |line| {
            if (line.len > 4096 or std.mem.indexOfScalar(u8, line, '\n') != null) return error.InvalidInputFrame;
            try self.child.?.stdin.?.writeStreamingAll(io, line);
            try self.child.?.stdin.?.writeStreamingAll(io, "\n");
        }
        const line = try self.reader.?.interface.takeDelimiter('\n') orelse return error.RunnerExited;
        return gpa.dupe(u8, line);
    }
    pub fn request(self: *Session, gpa: std.mem.Allocator, io: std.Io, frame: ?[]const u8, timeout_ms: u32) ![]u8 {
        if (self.child == null) return error.SessionNotStarted;
        errdefer self.stop(io);
        const Completion = union(enum) { reply: anyerror![]u8, timeout: anyerror!void };
        var buffer: [2]Completion = undefined;
        var select = std.Io.Select(Completion).init(io, &buffer);
        defer {
            while (select.cancel()) |pending| if (pending == .reply) {
                if (pending.reply) |bytes| gpa.free(bytes) else |_| {}
            };
        }
        try select.concurrent(.reply, exchange, .{ self, gpa, io, frame });
        try select.concurrent(.timeout, expire, .{ io, timeout_ms });
        const completed = try select.await();
        return switch (completed) {
            .reply => |result| try result,
            .timeout => |status| blk: {
                try status;
                break :blk error.Timeout;
            },
        };
    }
    pub fn stop(self: *Session, io: std.Io) void {
        if (self.child) |*child| child.kill(io);
        self.child = null;
        self.reader = null;
    }
};

pub const ArtifactInput = struct { snapshot_id: SnapshotId, build_inputs_digest: [32]u8, zig_version: []const u8, target: []const u8, optimize: []const u8 };
/// Separate from telemetry identity: compiler/dependency/target changes invalidate artifacts.
pub fn artifactKey(input: ArtifactInput) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("zigmkay-artifact-v1\x00");
    hash.update(&input.snapshot_id);
    hash.update(&input.build_inputs_digest);
    for ([_][]const u8{ input.zig_version, input.target, input.optimize }) |field| {
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, field.len, .little);
        hash.update(&length);
        hash.update(field);
    }
    return hash.finalResult();
}
