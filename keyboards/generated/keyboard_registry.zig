// Generated from boards.json by tools/registry/registry.py. Do not edit.
pub const Entry = struct {
    name: []const u8,
    source: []const u8,
    split: bool,
    encoder: bool,
    companion: bool,
};

pub const entries = [_]Entry{
    .{ .name = "clacky_chan", .source = "my_keyboards/rollercole/clacky_chan.zig", .split = true, .encoder = false, .companion = false },
    .{ .name = "dasbob", .source = "examples/dasbob/main.zig", .split = true, .encoder = false, .companion = false },
    .{ .name = "encoder_demo", .source = "my_keyboards/rollercole/encoder_demo.zig", .split = false, .encoder = true, .companion = false },
    .{ .name = "lk1", .source = "my_keyboards/rollercole/leonardo_keycaprio_0_1.zig", .split = false, .encoder = false, .companion = false },
    .{ .name = "lk2", .source = "my_keyboards/rollercole/leonardo_keycaprio_0_2.zig", .split = false, .encoder = false, .companion = false },
    .{ .name = "lk6", .source = "my_keyboards/rollercole/leonardo_keycaprio_0_6.zig", .split = false, .encoder = false, .companion = false },
    .{ .name = "lk7", .source = "my_keyboards/rollercole/leonardo_keycaprio_0_7.zig", .split = false, .encoder = false, .companion = true },
    .{ .name = "molekula", .source = "my_keyboards/molekula/main.zig", .split = false, .encoder = false, .companion = false },
    .{ .name = "tuckytwotimes", .source = "my_keyboards/rollercole/tuckytwotimes.zig", .split = true, .encoder = true, .companion = false },
    .{ .name = "yak", .source = "examples/yak/main.zig", .split = true, .encoder = true, .companion = false },
};
