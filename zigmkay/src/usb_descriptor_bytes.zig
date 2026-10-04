//! Compile-time USB wire bytes must not depend on aggregate constant layout.
const std = @import("std");

pub fn size(comptime T: type) usize {
    return switch (@typeInfo(T)) {
        .int => |info| (info.bits + 7) / 8,
        .@"enum" => |info| size(info.tag_type),
        .array => |info| info.len * size(info.child),
        .@"struct" => |info| if (info.layout == .@"packed") size(info.backing_integer.?) else blk: {
            var result: usize = 0;
            for (info.fields) |field| result += size(field.type);
            break :blk result;
        },
        else => @compileError("Unsupported USB descriptor field " ++ @typeName(T)),
    };
}

pub fn encode(comptime value: anytype) [size(@TypeOf(value))]u8 {
    var result: [size(@TypeOf(value))]u8 = undefined;
    var offset: usize = 0;
    append(&result, &offset, value);
    std.debug.assert(offset == result.len);
    return result;
}

pub fn append(output: []u8, offset: *usize, comptime value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int => {
            inline for (0..comptime size(T)) |i| output[offset.* + i] = @truncate(value >> (8 * i));
            offset.* += size(T);
        },
        .@"enum" => append(output, offset, @intFromEnum(value)),
        .array => inline for (value) |element| append(output, offset, element),
        .@"struct" => |info| {
            if (info.layout == .@"packed") {
                append(output, offset, @as(info.backing_integer.?, @bitCast(value)));
            } else inline for (info.fields) |field| append(output, offset, @field(value, field.name));
        },
        else => @compileError("Unsupported USB descriptor field " ++ @typeName(T)),
    }
}
