const std = @import("std");
const jobs = @import("companion-jobs");
test "direct argv bounded output crash timeout cancellation and snapshot freshness" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const exe = @import("options").helper_path;
    var spec = jobs.Spec{ .argv = &.{ exe, "literal;$(not-a-shell)" }, .cwd = ".", .snapshot_id = @splat(1), .timeout_ms = 1000 };
    var result = try jobs.run(gpa, io, spec);
    defer result.deinit(gpa);
    try std.testing.expectEqualStrings("literal;$(not-a-shell)", result.process.stdout);
    try std.testing.expect(result.successful());
    try std.testing.expect(!result.fresh(@splat(2)));
    spec.argv = &.{ exe, "crash" };
    var crashed = try jobs.run(gpa, io, spec);
    defer crashed.deinit(gpa);
    try std.testing.expect(!crashed.successful());
    spec.argv = &.{ exe, "flood" };
    try std.testing.expectError(error.StreamTooLong, jobs.run(gpa, io, spec));
    spec.argv = &.{ exe, "hang" };
    spec.timeout_ms = 50;
    try std.testing.expectError(error.Timeout, jobs.run(gpa, io, spec));
    spec.timeout_ms = 10000;
    var job = try jobs.Job.init(gpa, io, spec);
    defer job.deinit();
    try job.start();
    try std.Io.sleep(io, .fromMilliseconds(30), .awake);
    try std.testing.expect(job.poll() == null);
    job.cancel();
    try std.testing.expect(job.future == null);
}

test "hung runner session timeout terminates the child and clears session state" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const session = try gpa.create(jobs.Session);
    defer gpa.destroy(session);
    session.* = .{};
    defer session.stop(io);
    try session.start(io, &.{ @import("options").helper_path, "hang" });
    try std.testing.expectError(error.Timeout, session.request(gpa, io, null, 30));
    try std.testing.expect(session.child == null);
}
