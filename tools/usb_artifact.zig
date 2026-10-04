//! Independent parser for USB bytes actually emitted into RP2040 UF2 payloads.
const std = @import("std");

fn word(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

pub fn validate(gpa: std.mem.Allocator, uf2: []const u8) !void {
    const image = try gpa.alloc(u8, uf2.len / 2);
    defer gpa.free(image);
    for (0..uf2.len / 512) |i| @memcpy(image[i * 256 ..][0..256], uf2[i * 512 + 32 ..][0..256]);
    const header = [_]u8{ 9, 2, 146, 0, 5, 1, 0, 0x80, 250 };
    var found = false;
    var report_lengths: [4]u16 = undefined;
    var search: usize = 0;
    while (std.mem.indexOfPos(u8, image, search, &header)) |offset| {
        search = offset + 1;
        if (offset + 146 > image.len) continue;
        report_lengths = validateConfiguration(image[offset..][0..146]) catch continue;
        found = true;
        break;
    }
    if (!found) return error.NoValidUsbConfiguration;
    const lengths = [4]usize{
        try report(image, &.{ 0x05, 0x01, 0x09, 0x06, 0xa1, 0x01 }, 64, 8, .keyboard),
        try report(image, &.{ 0x05, 0x0c, 0x09, 0x01, 0xa1, 0x01 }, 16, 0, .consumer),
        try report(image, &.{ 0x05, 0x01, 0x09, 0x02, 0xa1, 0x01 }, 40, 0, .mouse),
        // FF31 is encoded as a four-byte positive global Usage Page by this pin.
        try report(image, &.{ 0x07, 0x31, 0xff, 0x00, 0x00, 0x09, 0x74, 0xa1, 0x01 }, 256, 256, .vendor),
    };
    for (lengths, report_lengths) |actual, advertised| if (actual != advertised) return error.InvalidHidDescriptorLength;
}

fn validateConfiguration(bytes: []const u8) ![4]u16 {
    var offset: usize = 9;
    var interfaces: u8 = 0;
    var endpoints: usize = 0;
    var hids: usize = 0;
    var lengths: [4]u16 = undefined;
    const addresses = [_]u8{ 1, 0x82, 3, 0x84, 5, 0x86, 7, 0x88 };
    const sizes = [_]u16{ 1, 8, 1, 2, 1, 5, 32, 32 };
    while (offset < bytes.len) {
        const length = bytes[offset];
        if (length < 2 or offset + length > bytes.len) return error.InvalidUsbDescriptor;
        const descriptor = bytes[offset..][0..length];
        switch (descriptor[1]) {
            4 => {
                if (length != 9 or descriptor[2] != interfaces or descriptor[3] != 0 or descriptor[4] != (if (interfaces == 4) @as(u8, 0) else 2)) return error.InvalidUsbInterface;
                if (interfaces == 0 and !std.mem.eql(u8, descriptor[5..8], &.{ 3, 1, 1 })) return error.InvalidBootInterface;
                interfaces += 1;
            },
            5 => {
                if (length != 7 or endpoints >= addresses.len or descriptor[2] != addresses[endpoints] or descriptor[3] != 3 or word(descriptor, 4) != sizes[endpoints]) return error.InvalidUsbEndpoint;
                endpoints += 1;
            },
            0x21 => {
                if (length != 9 or hids >= 4 or word(descriptor, 2) != 0x0111 or descriptor[5] != 1 or descriptor[6] != 0x22 or word(descriptor, 7) == 0) return error.InvalidHidDescriptor;
                lengths[hids] = word(descriptor, 7);
                hids += 1;
            },
            else => return error.UnexpectedUsbDescriptor,
        }
        offset += length;
    }
    if (interfaces != 5 or endpoints != 8 or hids != 4) return error.InvalidUsbDescriptorCounts;
    return lengths;
}

const Kind = enum { keyboard, consumer, mouse, vendor };
fn report(image: []const u8, prefix: []const u8, expected_in: usize, expected_out: usize, kind: Kind) !usize {
    const start = std.mem.indexOf(u8, image, prefix) orelse return error.MissingHidReport;
    const bytes = image[start..];
    var offset: usize = 0;
    var count: usize = 0;
    var size: usize = 0;
    var depth: usize = 0;
    var input: usize = 0;
    var output: usize = 0;
    var input_fields: usize = 0;
    var relative_fields: usize = 0;
    while (offset < bytes.len) {
        const header = bytes[offset];
        const length: usize = if (header & 3 == 3) 4 else header & 3;
        if (offset + 1 + length > bytes.len or header == 0xfe) return error.InvalidHidReport;
        var value: u32 = 0;
        for (0..length) |i| value |= @as(u32, bytes[offset + 1 + i]) << @intCast(8 * i);
        switch (header & 0xfc) {
            0x74 => size = value,
            0x94 => count = value,
            0x84 => return error.UnexpectedReportId,
            0xa0 => depth += 1,
            0xc0 => {
                if (depth == 0) return error.UnbalancedHidCollection;
                depth -= 1;
                if (depth == 0) break;
            },
            0x80 => {
                const bits = count * size;
                if (kind == .keyboard) {
                    const expected = [_]usize{ 8, 8, 48 };
                    if (input_fields >= expected.len or bits != expected[input_fields] or (input_fields == 1 and value & 1 == 0)) return error.InvalidBootReport;
                }
                if (kind == .mouse and value & 4 != 0) relative_fields += 1;
                input_fields += 1;
                input += bits;
            },
            0x90 => output += count * size,
            0xb0 => return error.UnexpectedFeatureReport,
            else => {},
        }
        offset += 1 + length;
    }
    if (depth != 0 or input != expected_in or output != expected_out) return error.InvalidHidReportSize;
    if (kind == .mouse and relative_fields != 3) return error.MouseIsNotRelative;
    return offset + 1;
}

test "independent configuration parser rejects bad boot packet size and padding" {
    const valid = [_]u8{ 9, 2, 146, 0, 5, 1, 0, 0x80, 250 } ++
        [_]u8{ 9, 4, 0, 0, 2, 3, 1, 1, 4, 9, 0x21, 0x11, 1, 0, 1, 0x22, 65, 0, 7, 5, 1, 3, 1, 0, 1, 7, 5, 0x82, 3, 7, 0, 1 };
    try std.testing.expectError(error.InvalidUsbEndpoint, validateConfiguration(&valid));
    var padded = valid;
    padded[9] = 0;
    try std.testing.expectError(error.InvalidUsbDescriptor, validateConfiguration(&padded));
}
