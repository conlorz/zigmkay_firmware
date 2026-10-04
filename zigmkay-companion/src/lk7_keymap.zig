const firmware = @import("firmware_keymap");
pub const core = @import("zigmkay").core;
pub const keymap = firmware.keymap;
pub const key_count = firmware.key_count;
pub const identity = firmware.identity(@import("device-protocol"));
pub const COM_TOG = core.CUSTOM_ID_COMPANION_TOGGLE;
pub const COM_OFF = core.CUSTOM_ID_COMPANION_SHUTDOWN;

// Display placement is separate from the firmware's processing sides.
pub const Side = enum { L, R, TL, TR, E };
pub const sides = blk: {
    var result: [key_count]Side = undefined;
    var thumb_index: usize = 0;
    for (firmware.sides, 0..) |side, i| {
        result[i] = switch (side) {
            .L => .L,
            .R => .R,
            .X => thumb: {
                defer thumb_index += 1;
                break :thumb if (thumb_index < 2) .TL else .TR;
            },
        };
    }
    break :blk result;
};
