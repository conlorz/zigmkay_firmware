const std = @import("std");
const protocol = @import("device-protocol");
const lk7 = @import("lk7-keymap");
const expected = "board=lk7\nkeys=34\nlayers=4\nreports=8\npressed=[]\nactive_layers=1\nhighest_layer=0\nmodifiers=0x00\nlast_sequence=7\nneeds_resync=false\n";
const Runner = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    fn run(r: Runner, argv: []const []const u8, success: bool, needle: []const u8) ![]const u8 {
        const result = try std.process.run(r.gpa, r.io, .{ .argv = argv, .cwd = .{ .path = r.root }, .timeout = .{ .duration = .{ .raw = .fromSeconds(60), .clock = .awake } }, .stdout_limit = .limited(4 * 1024 * 1024), .stderr_limit = .limited(4 * 1024 * 1024) });
        const ok = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        };
        const text = try std.mem.concat(r.gpa, u8, &.{ result.stdout, result.stderr });
        if (ok != success or std.mem.indexOf(u8, text, needle) == null) {
            std.debug.print("Process check failed: {s}\n{s}\n", .{ argv[0], text });
            return error.ProcessCheckFailed;
        }
        return result.stdout;
    }
};
pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len != 9) return error.Usage;
    const r = Runner{ .gpa = gpa, .io = init.io, .root = args[5] };
    const scratch = args[8];
    try std.Io.Dir.cwd().createDirPath(init.io, scratch);
    defer std.Io.Dir.cwd().deleteTree(init.io, scratch) catch {};
    var dir = try std.Io.Dir.cwd().openDir(init.io, scratch, .{});
    defer dir.close(init.io);
    const report = try std.fs.path.join(gpa, &.{ scratch, "reports.bin" });
    const trace = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], gpa, .limited(4096));
    try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = trace });
    const text = try r.run(&.{ args[1], report }, true, expected);
    try std.testing.expectEqualStrings(expected, text);
    try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = trace[0..128] });
    _ = try r.run(&.{ args[1], report }, true, "pressed=[30]\nactive_layers=3\nhighest_layer=1");
    var changed: [64]u8 = undefined;
    @memcpy(&changed, trace[0..64]);
    changed[11] = 0x22;
    try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = changed[0..32] });
    _ = try r.run(&.{ args[1], report }, true, "modifiers=0x22");
    try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = "" });
    _ = try r.run(&.{ args[1], report }, true, "last_sequence=none");
    try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = trace[0 .. trace.len - 1] });
    _ = try r.run(&.{ args[1], report }, false, "complete 32-byte boundaries");
    for ([_]struct { usize, u8 }{ .{ 0, 0 }, .{ 1, 2 }, .{ 2, 99 }, .{ 8, 2 }, .{ 9, 127 }, .{ 31, 1 } }) |mutation| {
        @memcpy(&changed, trace[0..64]);
        changed[mutation[0]] = mutation[1];
        try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = changed[0..32] });
        _ = try r.run(&.{ args[1], report }, false, "Replay report 0 at byte 0");
    }
    for ([_]u8{ 0, 3 }) |seq| {
        @memcpy(&changed, trace[0..64]);
        changed[36] = seq;
        try dir.writeFile(init.io, .{ .sub_path = "reports.bin", .data = &changed });
        _ = try r.run(&.{ args[1], report }, false, "SequenceDiscontinuity");
    }
    _ = try r.run(&.{args[1]}, false, "Usage:");
    const missing = try std.fs.path.join(gpa, &.{ scratch, "missing.bin" });
    _ = try r.run(&.{ args[1], missing }, false, "FileNotFound");
    // Session replay fixtures are generated only into the build scratch cache.
    // Independent literal wire fixtures are checked by test_protocol_session.
    const identity = comptime lk7.identity(protocol);
    const session: u32 = 0x11223344;
    const identity_packets = try protocol.identityPackets(identity, session, 1);
    var held = protocol.Snapshot{};
    held.pressed[0] = 1;
    const initial_snapshot = try protocol.snapshotPackets(held, lk7.dimensions, session, 2, 65535);
    const release_key = protocol.Packet{ .session = session, .sequence = 65535, .payload = .{ .key = .{ .pressed = false, .key_index = 0, .layer = 0, .modifiers = .{} } } };
    const gap = protocol.Packet{ .session = session, .sequence = 2, .payload = .{ .key = .{ .pressed = true, .key_index = 1, .layer = 0, .modifiers = .{} } } };
    held.pressed = @splat(0);
    held.pressed[3] = 0x40;
    const recovered_snapshot = try protocol.snapshotPackets(held, lk7.dimensions, session, 3, 3);
    const final_release = protocol.Packet{ .session = session, .sequence = 3, .payload = .{ .key = .{ .pressed = false, .key_index = 30, .layer = 0, .modifiers = .{} } } };
    const packets = identity_packets ++ initial_snapshot ++ .{ release_key, release_key, gap } ++ recovered_snapshot ++ .{final_release};
    var session_trace: [packets.len * protocol.report_size]u8 = undefined;
    for (packets, 0..) |packet, index| {
        const encoded = try protocol.encodePacket(packet, lk7.dimensions, .device_to_host);
        @memcpy(session_trace[index * protocol.report_size ..][0..protocol.report_size], &encoded);
    }
    const session_path = try std.fs.path.join(gpa, &.{ scratch, "lk7_session_recovery.bin" });
    try dir.writeFile(init.io, .{ .sub_path = "lk7_session_recovery.bin", .data = &session_trace });
    _ = try r.run(&.{ args[1], "--session", session_path }, true, "pressed=[]\nactive_layers=1\nhighest_layer=0");
    try dir.writeFile(init.io, .{ .sub_path = "lk7_session_recovery.bin", .data = session_trace[0 .. 9 * protocol.report_size] });
    _ = try r.run(&.{ args[1], "--session", session_path }, false, "");
    session_trace[14] ^= 1; // Corrupt echoed nonce while keeping report framing valid.
    try dir.writeFile(init.io, .{ .sub_path = "lk7_session_recovery.bin", .data = &session_trace });
    _ = try r.run(&.{ args[1], "--session", session_path }, false, "");
    const input = try std.fs.path.join(gpa, &.{ scratch, "keycodes_0.0.1_basic.hjson" });
    const output = try std.fs.path.join(gpa, &.{ scratch, "output.zig" });
    for ([_][]const u8{ "{}", "{\"0x0004\":{\"key\":\"KC_A\"", "not hjson" }) |bad| {
        try dir.writeFile(init.io, .{ .sub_path = "keycodes_0.0.1_basic.hjson", .data = bad });
        try dir.writeFile(init.io, .{ .sub_path = "output.zig", .data = "original" });
        _ = try r.run(&.{ args[3], input, output }, false, "");
        const original = try dir.readFileAlloc(init.io, "output.zig", gpa, .limited(4096));
        try std.testing.expectEqualStrings("original", original);
        try dir.deleteFile(init.io, "output.zig");
        _ = try r.run(&.{ args[3], input, output }, false, "");
        try std.testing.expectError(error.FileNotFound, dir.access(init.io, "output.zig", .{}));
    }
    _ = try r.run(&.{args[3]}, false, "Usage:");
    _ = try r.run(&.{ args[6], args[7], args[5], args[7], scratch }, false, "Expected Zig 0.16.0, got 0.15.2");
    try std.testing.expectError(error.FileNotFound, dir.access(init.io, "hardware-tool-executed", .{}));
    _ = try r.run(&.{ args[4], "build", "--build-file", "keyboards/build.zig", "-j4", "firmware" }, false, "Missing -Dkeyboard");
    _ = try r.run(&.{ args[4], "build", "--build-file", "keyboards/build.zig", "-j4", "firmware", "-Dkeyboard=does_not_exist" }, false, "Unknown keyboard 'does_not_exist'");
    const listing = try r.run(&.{ "mise", "run", "//:ls" }, true, "lk7: companion=lk7 offline");
    var lines = std.mem.splitScalar(u8, listing, '\n');
    var count: usize = 0;
    var last: []const u8 = "";
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const name = line[0..std.mem.indexOfScalar(u8, line, ':').?];
        try std.testing.expect(std.mem.order(u8, last, name) == .lt);
        last = name;
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), count);
    const alias_listing = try r.run(&.{ args[4], "build", "--build-file", "keyboards/build.zig", "-j4", "ls" }, true, "lk7: companion=lk7 offline");
    try std.testing.expectEqualStrings(listing, alias_listing);
    _ = try r.run(&.{ "mise", "run", "//:flash", "--help" }, true, "--mount");
    _ = try r.run(&.{ "mise", "run", "//:firmware", "does_not_exist" }, false, "does_not_exist");
    const firmware_help = try r.run(&.{ "mise", "run", "//:firmware", "--help" }, true, "ReleaseSafe");
    inline for (@import("board-catalog")) |entry| {
        if (std.mem.indexOf(u8, firmware_help, entry.name) == null) return error.MissingBoardCompletion;
    }
    const completion = try r.run(&.{ "mise", "__complete_word__", "--shell", "fish", "--line", "mise //:firmware " }, true, "lk7");
    inline for (@import("board-catalog")) |entry| {
        if (std.mem.indexOf(u8, completion, entry.name) == null) return error.MissingBoardCompletion;
    }
    _ = try r.run(&.{ "mise", "__complete_word__", "--shell", "fish", "--line", "mise //:companion-run --" }, true, "--session-replay");
    std.debug.print("Offline executable and build-boundary checks passed\n", .{});
}
