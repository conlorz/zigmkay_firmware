pub const Keyboard = extern struct {
    modifiers: u8 = 0,
    reserved: u8 = 0,
    keys: [6]u8 = @splat(0),
    pub const empty: @This() = .{};
};

pub const KeyboardState = struct {
    pressed: [0xe0]bool = @splat(false),
    modifiers: u8 = 0,

    pub fn press(self: *@This(), usage: u8) void {
        if (usage >= 4 and usage < self.pressed.len) self.pressed[usage] = true;
    }

    pub fn release(self: *@This(), usage: u8) void {
        if (usage < self.pressed.len) self.pressed[usage] = false;
    }

    pub fn report(self: *const @This()) Keyboard {
        var result = Keyboard{ .modifiers = self.modifiers };
        var count: usize = 0;
        for (self.pressed, 0..) |pressed, usage| {
            if (!pressed) continue;
            if (count == result.keys.len) {
                result.keys = @splat(1); // ErrorRollOver until six or fewer remain.
                return result;
            }
            result.keys[count] = @intCast(usage);
            count += 1;
        }
        return result;
    }
};
