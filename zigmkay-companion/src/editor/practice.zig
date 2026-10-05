//! Hardware-free, bounded Unicode copy practice. Times are monotonic microseconds.
const std = @import("std");
pub const State = enum { ready, running, paused, complete };
pub const Source = enum { os, draft };
pub const lessons = [_][]const u8{ @embedFile("lessons/functions.zig"), @embedFile("lessons/arrays.zig"), @embedFile("lessons/errors.zig") };
pub const lesson_names = [_][]const u8{ "Functions and tests", "Arrays and a struct", "Errors and optionals" };
pub const corpus_version = 1;
pub const Session = struct {
    reference: [8192]u21 = undefined,
    reference_len: usize = 0,
    typed: [8192]u21 = undefined,
    len: usize = 0,
    state: State = .ready,
    source: Source = .os,
    attempts: usize = 0,
    correct_attempts: usize = 0,
    corrected: usize = 0,
    errors: [8192]u32 = @splat(0),
    scored: bool = true,
    started: ?u64 = null,
    segment: u64 = 0,
    active_us: u64 = 0,
    ended: u64 = 0,
    pub fn load(self: *Session, bytes: []const u8, source: Source) !void {
        var view = try std.unicode.Utf8View.init(bytes);
        var it = view.iterator();
        var count: usize = 0;
        while (it.nextCodepoint()) |cp| {
            if (count == self.reference.len) return error.ExerciseTooLong;
            self.reference[count] = cp;
            count += 1;
        }
        self.reference_len = count;
        self.source = source;
        self.restart();
    }
    pub fn restart(self: *Session) void {
        self.len = 0;
        self.state = .ready;
        self.attempts = 0;
        self.correct_attempts = 0;
        self.corrected = 0;
        self.errors = @splat(0);
        self.scored = true;
        self.started = null;
        self.active_us = 0;
        self.ended = 0;
    }
    pub fn insert(self: *Session, bytes: []const u8, now: u64, paste: bool) !void {
        if (self.state == .paused or self.state == .complete) return;
        var view = try std.unicode.Utf8View.init(bytes);
        var it = view.iterator();
        if (paste) self.scored = false;
        var previous_cr = false;
        while (it.nextCodepoint()) |raw| {
            if (raw == '\n' and previous_cr) {
                previous_cr = false;
                continue;
            }
            previous_cr = raw == '\r';
            const cp: u21 = if (raw == '\r') '\n' else raw;
            if (self.len == self.typed.len) return error.TextLimit;
            if (self.state == .ready) {
                self.state = .running;
                self.started = now;
                self.segment = now;
            }
            self.attempts += 1;
            if (self.len < self.reference_len and self.reference[self.len] == cp) self.correct_attempts += 1 else self.errors[@min(self.len, self.reference.len - 1)] += 1;
            self.typed[self.len] = cp;
            self.len += 1;
            if (self.len == self.reference_len and std.mem.eql(u21, self.typed[0..self.len], self.reference[0..self.reference_len])) {
                self.active_us += now -| self.segment;
                self.ended = now;
                self.state = .complete;
                break;
            }
        }
    }
    pub fn backspace(self: *Session) void {
        if (self.len == 0 or self.state == .paused or self.state == .complete) return;
        self.len -= 1;
        if (self.len >= self.reference_len or self.typed[self.len] != self.reference[self.len]) self.corrected += 1;
    }
    pub fn pause(self: *Session, now: u64) void {
        if (self.state == .complete or self.state == .paused) return;
        if (self.state == .running) self.active_us += now -| self.segment;
        self.state = .paused;
    }
    pub fn resumeRun(self: *Session, now: u64) void {
        if (self.state != .paused) return;
        self.state = if (self.started == null) .ready else .running;
        self.segment = now;
    }
    pub fn duration(self: *const Session, now: u64) u64 {
        return self.active_us + if (self.state == .running) now -| self.segment else 0;
    }
    pub fn matched(self: *const Session) usize {
        var count: usize = 0;
        for (self.typed[0..@min(self.len, self.reference_len)], self.reference[0..@min(self.len, self.reference_len)]) |a, b| {
            count += @intFromBool(a == b);
        }
        return count;
    }
    pub fn wpm(self: *const Session, now: u64) f64 {
        const us = self.duration(now);
        return if (us == 0) 0 else @as(f64, @floatFromInt(self.matched())) * 12_000_000 / @as(f64, @floatFromInt(us));
    }
    pub fn accuracy(self: *const Session) f64 {
        return if (self.attempts == 0) 100 else 100 * @as(f64, @floatFromInt(self.correct_attempts)) / @as(f64, @floatFromInt(self.attempts));
    }
};
pub fn english(buffer: []u8, seed: u64, length: usize) ![]const u8 {
    var random = std.Random.DefaultPrng.init(seed);
    const rng = random.random();
    const subjects = [_][]const u8{ "The quiet gardener", "A curious student", "The friendly baker", "A patient artist", "The young sailor", "A cheerful neighbor", "The careful teacher", "A busy writer" };
    const verbs = [_][]const u8{ "finds", "carries", "chooses", "shares", "keeps", "brings", "collects", "notices" };
    const objects = [_][]const u8{ "a small notebook", "a bright flower", "a fresh apple", "a wooden box", "a warm blanket", "a smooth stone", "a red umbrella", "a useful map" };
    const endings = [_][]const u8{ "near the old bridge", "before the evening rain", "beside the open window", "on a sunny morning", "after a long walk", "under the tall tree" };
    var writer: std.Io.Writer = .fixed(buffer);
    var previous_subject: usize = subjects.len;
    var previous_ending: usize = endings.len;
    for (0..length) |i| {
        var subject = rng.uintLessThan(usize, subjects.len);
        if (subject == previous_subject) subject = (subject + 1) % subjects.len;
        var ending = rng.uintLessThan(usize, endings.len);
        if (ending == previous_ending) ending = (ending + 1) % endings.len;
        try writer.print("{s}{s} {s} {s} {s}.", .{ if (i == 0) "" else " ", subjects[subject], verbs[rng.uintLessThan(usize, verbs.len)], objects[rng.uintLessThan(usize, objects.len)], endings[ending] });
        previous_subject = subject;
        previous_ending = ending;
    }
    return writer.buffered();
}
test "Unicode corrections, pauses and literal scoring" {
    var s: Session = .{};
    try s.load("é a\n", .os);
    try s.insert("é", 1_000_000, false);
    try std.testing.expectEqual(@as(f64, 0), s.wpm(1_000_000));
    try s.insert("x", 2_000_000, false);
    s.backspace();
    try s.insert(" ", 3_000_000, false);
    s.pause(4_000_000);
    try s.insert("ignored", 9_000_000, false);
    s.resumeRun(10_000_000);
    try s.insert("a\r\n", 11_000_000, false);
    try std.testing.expectEqual(State.complete, s.state);
    try std.testing.expectEqual(@as(u64, 4_000_000), s.duration(99_000_000));
    try std.testing.expectEqual(@as(f64, 12), s.wpm(99_000_000));
    try std.testing.expectEqual(@as(f64, 80), s.accuracy());
    try std.testing.expectEqual(@as(usize, 1), s.corrected);
    s.restart();
    try s.insert("é a\n", 1, true);
    try std.testing.expect(!s.scored);
}
test "English seed reproducibility and length" {
    var a: [4096]u8 = undefined;
    var b: [4096]u8 = undefined;
    const first = try english(&a, 42, 5);
    try std.testing.expectEqualStrings(first, try english(&b, 42, 5));
    try std.testing.expect(!std.mem.eql(u8, first, try english(&b, 43, 5)));
    try std.testing.expectEqual(@as(usize, 5), std.mem.count(u8, first, "."));
}
