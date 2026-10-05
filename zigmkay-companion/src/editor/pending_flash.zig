//! Preserve the explicit Flash click while its exact draft is being built.
const std = @import("std");
pub const Gate = struct {
    id: ?[32]u8 = null,
    hid: bool = true,
    pub fn request(self: *Gate, id: [32]u8, hid: bool) void {
        self.id = id;
        self.hid = hid;
    }
    pub fn take(self: *Gate, current: [32]u8, ready: bool, failed: bool) bool {
        const expected = self.id orelse return false;
        if (failed or !std.mem.eql(u8, &expected, &current)) {
            self.id = null;
            return false;
        }
        if (!ready) return false;
        self.id = null;
        return true;
    }
};
test "Flash waits for the matching build and consumes the click exactly once" {
    var gate = Gate{};
    gate.request(@splat(1), false);
    try std.testing.expect(!gate.take(@splat(1), false, false));
    try std.testing.expect(gate.take(@splat(1), true, false));
    try std.testing.expect(!gate.hid);
    try std.testing.expect(!gate.take(@splat(1), true, false));
}
test "edits failed builds and cancellation discard pending Flash authorization" {
    var gate = Gate{};
    gate.request(@splat(1), true);
    try std.testing.expect(!gate.take(@splat(2), true, false));
    try std.testing.expect(gate.id == null);
    gate.request(@splat(2), true);
    try std.testing.expect(!gate.take(@splat(2), false, true));
    try std.testing.expect(!gate.take(@splat(2), true, false));
}
