const std = @import("std");
pub const Stage = enum { opening, writing, synchronizing, completed };

/// Backend calls may block in the kernel. This budget bounds progress between
/// calls and detects an overrun after return; it is not syscall cancellation.
pub fn run(comptime Backend: type, backend: *Backend, contents: []const u8, stage: *Stage) !void {
    const deadline = backend.now() +| 60_000;
    stage.* = .opening;
    try backend.open();
    defer backend.close();
    stage.* = .writing;
    var offset: usize = 0;
    while (offset < contents.len) {
        try backend.checkCancellation();
        if (backend.now() >= deadline) return error.TransferDeadlineExceeded;
        const length = @min(4096, contents.len - offset);
        try backend.write(contents[offset..][0..length], offset);
        offset += length;
    }
    try backend.checkCancellation();
    if (backend.now() >= deadline) return error.TransferDeadlineExceeded;
    stage.* = .synchronizing;
    try backend.sync();
    if (backend.now() >= deadline) return error.TransferDeadlineExceeded;
    stage.* = .completed;
}

const Fake = struct {
    fault: enum { none, denied, readonly, disappeared, partial, sync_error, cancelled, blocked_return } = .none,
    clock: u64 = 0,
    written: usize = 0,
    closed: bool = false,
    synchronized: bool = false,
    fn now(self: *Fake) u64 {
        return self.clock;
    }
    fn open(self: *Fake) !void {
        switch (self.fault) {
            .denied => return error.AccessDenied,
            .readonly => return error.ReadOnlyFileSystem,
            .blocked_return => self.clock = 60_000,
            else => {},
        }
    }
    fn close(self: *Fake) void {
        self.closed = true;
    }
    fn checkCancellation(self: *Fake) !void {
        if (self.fault == .cancelled and self.written != 0) return error.Canceled;
    }
    fn write(self: *Fake, bytes: []const u8, offset: usize) !void {
        if (self.fault == .disappeared and offset != 0) return error.FileNotFound;
        if (self.fault == .partial) {
            self.written += bytes.len / 2;
            return error.InputOutput;
        }
        self.written += bytes.len;
    }
    fn sync(self: *Fake) !void {
        if (self.fault == .sync_error) return error.InputOutput;
        self.synchronized = true;
    }
};

test "production transfer distinguishes refusal partial write disappearance cancellation and sync failure" {
    const bytes: [9000]u8 = @splat(7);
    var stage: Stage = undefined;
    var backend = Fake{ .fault = .denied };
    try std.testing.expectError(error.AccessDenied, run(Fake, &backend, &bytes, &stage));
    try std.testing.expectEqual(Stage.opening, stage);
    try std.testing.expectEqual(@as(usize, 0), backend.written);
    backend = .{ .fault = .readonly };
    try std.testing.expectError(error.ReadOnlyFileSystem, run(Fake, &backend, &bytes, &stage));
    backend = .{ .fault = .partial };
    try std.testing.expectError(error.InputOutput, run(Fake, &backend, &bytes, &stage));
    try std.testing.expect(backend.closed and !backend.synchronized and backend.written < bytes.len);
    backend = .{ .fault = .disappeared };
    try std.testing.expectError(error.FileNotFound, run(Fake, &backend, &bytes, &stage));
    try std.testing.expectEqual(Stage.writing, stage);
    backend = .{ .fault = .cancelled };
    try std.testing.expectError(error.Canceled, run(Fake, &backend, &bytes, &stage));
    try std.testing.expect(backend.closed and !backend.synchronized);
    backend = .{ .fault = .sync_error };
    try std.testing.expectError(error.InputOutput, run(Fake, &backend, &bytes, &stage));
    try std.testing.expectEqual(Stage.synchronizing, stage);
    backend = .{ .fault = .blocked_return };
    try std.testing.expectError(error.TransferDeadlineExceeded, run(Fake, &backend, &bytes, &stage));
    try std.testing.expectEqual(@as(usize, 0), backend.written);
    backend = .{};
    try run(Fake, &backend, &bytes, &stage);
    try std.testing.expect(backend.closed and backend.synchronized);
    try std.testing.expectEqual(bytes.len, backend.written);
    try std.testing.expectEqual(Stage.completed, stage);
}
