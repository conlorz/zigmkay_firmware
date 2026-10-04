const std = @import("std");

// Independent literals: they precede codec implementation and define the wire.
pub const hello: [32]u8 = .{ 0xA7, 2, 10, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0x44, 0x33, 0x22, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
// Board "lk7", profile "danish", digest bytes 00..0f, dimensions 34/4.
pub const identity_parts: [3][32]u8 = .{
    .{ 0xA7, 2, 11, 18, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 0, 3, 0x44, 0x33, 0x22, 0x11, 'l', 'k', '7', 0, 0, 0, 0, 0, 'd', 'a', 'n', 'i', 0, 0 },
    .{ 0xA7, 2, 11, 18, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 1, 3, 's', 'h', 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 0 },
    .{ 0xA7, 2, 11, 8, 0x44, 0x33, 0x22, 0x11, 0, 0, 1, 0, 2, 3, 12, 13, 14, 15, 34, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
};
pub const snapshot_request: [32]u8 = .{ 0xA7, 2, 12, 0, 0x44, 0x33, 0x22, 0x11, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
// Keys 0 and 30 held, arrows active, persistent left control. Next delta=65535.
pub const snapshot_parts: [2][32]u8 = .{
    .{ 0xA7, 2, 13, 12, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 2, 0, 0, 2, 1, 0, 0, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0xA7, 2, 13, 12, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 2, 0, 1, 2, 0, 0, 0, 0, 0, 0, 3, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
};
pub const release: [32]u8 = .{ 0xA7, 2, 14, 4, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xFF, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
pub const overflow: [32]u8 = .{ 0xA7, 2, 16, 1, 0x44, 0x33, 0x22, 0x11, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

test "v2 independent fixtures define complete report boundaries and zero padding" {
    const reports = .{hello} ++ identity_parts ++ .{snapshot_request} ++ snapshot_parts ++ .{ release, overflow };
    for (reports) |report| {
        try std.testing.expectEqual(@as(u8, 0xA7), report[0]);
        try std.testing.expectEqual(@as(u8, 2), report[1]);
        try std.testing.expect(report[3] <= 20);
        for (report[12 + report[3] ..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

const protocol = @import("device-protocol");
const model = @import("layout-model");
const dimensions = model.KeymapDimensions{ .key_count = 34, .layer_count = 4 };
const fixture_identity = protocol.Identity{ .board_id = .{ 'l', 'k', '7', 0, 0, 0, 0, 0 }, .profile_id = .{ 'd', 'a', 'n', 'i', 's', 'h', 0, 0 }, .digest = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }, .dimensions = dimensions };

test "v2 codec matches independent identity snapshot recovery and control literals" {
    const hello_packet = protocol.Packet{ .session = 0, .request = 1, .nonce = 0x11223344, .payload = .hello };
    try std.testing.expectEqual(hello, try protocol.encodePacket(hello_packet, dimensions, .host_to_device));
    const identities = try protocol.identityPackets(fixture_identity, 0x11223344, 1);
    for (identities, identity_parts) |packet, literal| {
        try std.testing.expectEqual(literal, try protocol.encodePacket(packet, dimensions, .device_to_host));
        try std.testing.expectEqualDeep(packet, try protocol.decodePacket(&literal, dimensions, .device_to_host));
    }
    var snapshot = protocol.Snapshot{ .active_layers = 3, .highest_layer = 1, .modifiers = .{ .left_ctrl = true } };
    snapshot.pressed[0] = 1;
    snapshot.pressed[3] = 0x40;
    const snapshots = try protocol.snapshotPackets(snapshot, dimensions, 0x11223344, 2, 65535);
    for (snapshots, snapshot_parts) |packet, literal| {
        try std.testing.expectEqual(literal, try protocol.encodePacket(packet, dimensions, .device_to_host));
        try std.testing.expectEqualDeep(packet, try protocol.decodePacket(&literal, dimensions, .device_to_host));
    }
    try std.testing.expectEqualDeep(snapshot, try protocol.decodeSnapshotBody(try protocol.encodeSnapshotBody(snapshot, dimensions), dimensions));
    for ([_]protocol.Report{ snapshot_request, release, overflow }) |literal| {
        const direction: protocol.Direction = if (literal[2] == 12) .host_to_device else .device_to_host;
        try std.testing.expectEqual(literal, try protocol.encodePacket(try protocol.decodePacket(&literal, dimensions, direction), dimensions, direction));
    }
    try std.testing.expectEqualDeep(fixture_identity, try protocol.decodeIdentityBody(try protocol.identityBody(fixture_identity, 0x11223344), 0x11223344));
}

test "v2 invalid framing dimensions transaction fields and fragments reject" {
    try std.testing.expectError(error.InvalidDimensions, protocol.decodePacket(&hello, .{ .key_count = 0, .layer_count = 4 }, .host_to_device));
    try std.testing.expectError(error.WrongDirection, protocol.decodePacket(&hello, dimensions, .device_to_host));
    try std.testing.expectError(error.InvalidLength, protocol.decodePacket(hello[0..31], dimensions, .host_to_device));
    const cases = .{ .{ 0, 0, error.InvalidMagic }, .{ 1, 1, error.UnsupportedVersion }, .{ 2, 0, error.UnsupportedKind }, .{ 3, 3, error.InvalidPayloadLength }, .{ 4, 1, error.InvalidSession }, .{ 8, 1, error.InvalidReserved }, .{ 10, 0, error.InvalidRequest }, .{ 31, 1, error.InvalidPadding } };
    inline for (cases) |case| {
        var bad = hello;
        bad[case[0]] = case[1];
        try std.testing.expectError(case[2], protocol.decodePacket(&bad, dimensions, .host_to_device));
    }
    for ([_]u8{ 0, 4, 255 }) |count| {
        var bad = identity_parts[0];
        bad[13] = count;
        try std.testing.expectError(error.InvalidPart, protocol.decodePacket(&bad, dimensions, .device_to_host));
    }
    var bad = snapshot_parts[0];
    bad[12] = 2;
    try std.testing.expectError(error.InvalidPart, protocol.decodePacket(&bad, dimensions, .device_to_host));
    var body = try protocol.encodeSnapshotBody(.{}, dimensions);
    body[15] = 0x80;
    try std.testing.expectError(error.InvalidKeyIndex, protocol.decodeSnapshotBody(body, dimensions));
    body = try protocol.encodeSnapshotBody(.{}, dimensions);
    body[16] = 0;
    try std.testing.expectError(error.InvalidLayerMask, protocol.decodeSnapshotBody(body, dimensions));
    var identity_body = try protocol.identityBody(fixture_identity, 0x11223344);
    identity_body[5] = 0;
    identity_body[6] = 'a';
    try std.testing.expectError(error.InvalidIdentity, protocol.decodeIdentityBody(identity_body, 0x11223344));
    identity_body = try protocol.identityBody(fixture_identity, 0x11223344);
    identity_body[36] = 128;
    try std.testing.expectError(error.InvalidDimensions, protocol.decodeIdentityBody(identity_body, 0x11223344));
}

const base_keys = [_]?model.KeyDef{.{ .tap_only = .{ .key_press = .{ .tap_keycode = 4 } } }};
const base_input = protocol.IdentityInput{ .board_id = .{ 't', 'e', 's', 't', 0, 0, 0, 0 }, .profile_id = .{ 'b', 'a', 's', 'e', 0, 0, 0, 0 }, .dimensions = .{ .key_count = 1, .layer_count = 1 }, .keys = &base_keys, .sides = &.{.L}, .combos = &.{}, .encoders = &.{}, .callbacks = &.{} };

test "canonical profile digest uses independent semantic bytes" {
    const literal = "zigmkay-profile-v1\x00" ++ "test\x00\x00\x00\x00" ++ "base\x00\x00\x00\x00" ++ [_]u8{ 1, 1, 1, 0, 1, 1, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(literal, &digest, .{});
    const identity = try protocol.computeIdentity(base_input);
    try std.testing.expectEqualSlices(u8, digest[0..16], &identity.digest);
    try std.testing.expectEqual([_]u8{ 0x11, 0xb5, 0x59, 0x62, 0xb8, 0x78, 0x55, 0xf9, 0x41, 0xde, 0x48, 0x43, 0x92, 0xa9, 0x66, 0x50 }, identity.digest);
}

test "identity changes cover optional actions sides combos encoders and callback declarations" {
    const original = (try protocol.computeIdentity(base_input)).digest;
    const variants = [_]?model.KeyDef{ null, .none, .{ .tap_only = .{ .key_press = .{ .tap_keycode = 4, .dead = true } } }, .{ .tap_only = .{ .key_press = .{ .tap_keycode = 4, .tap_modifiers = .{ .left_shift = true } } } }, .{ .tap_only = .{ .one_shot = .{ .hold_modifiers = .{ .left_ctrl = true } } } }, .{ .tap_only = .{ .media_key = .VolumeUp } }, .{ .tap_only = .{ .mouse_action = .WheelLeft } }, .{ .hold_only = .{ .hold_layer = 0 } }, .{ .tap_hold = .{ .tap = .{}, .hold = .{}, .tapping_term = .{ .ms = 150 }, .retro_tapping = true } }, .{ .tap_with_autofire = .{ .tap = .{}, .initial_delay = .{ .ms = 10 }, .repeat_interval = .{ .ms = 20 } } } };
    for (variants) |variant| {
        var input = base_input;
        input.keys = &.{variant};
        try std.testing.expect(!std.mem.eql(u8, &original, &(try protocol.computeIdentity(input)).digest));
    }
    var input = base_input;
    input.sides = &.{.R};
    try std.testing.expect(!std.mem.eql(u8, &original, &(try protocol.computeIdentity(input)).digest));
    input = base_input;
    input.encoders = &.{.{ .tap = .{ .custom = 1 } }};
    input.callbacks = &.{.{ .id = 1, .behavior = "combined-tap-hold-v1" }};
    const callback_v1 = try protocol.computeIdentity(input);
    input.callbacks = &.{.{ .id = 1, .behavior = "combined-tap-hold-v2" }};
    try std.testing.expect(!std.mem.eql(u8, &callback_v1.digest, &(try protocol.computeIdentity(input)).digest));
    input.callbacks = &.{};
    try std.testing.expectError(error.InvalidCallback, protocol.computeIdentity(input));
    input = base_input;
    input.keys = &.{.{ .hold_only = .{ .hold_layer = 1 } }};
    try std.testing.expectError(error.InvalidLayer, protocol.computeIdentity(input));
    input = base_input;
    input.callbacks = &.{ .{ .id = 1, .behavior = "a" }, .{ .id = 1, .behavior = "b" } };
    try std.testing.expectError(error.InvalidCallback, protocol.computeIdentity(input));
    input = base_input;
    input.dimensions.key_count = 2;
    input.keys = &.{ base_keys[0], base_keys[0] };
    input.sides = &.{ .L, .L };
    const no_combo = try protocol.computeIdentity(input);
    input.combos = &.{.{ .key_indexes = .{ 0, 1 }, .timeout = .{ .ms = 40 }, .layer = 0, .key_def = .none }};
    try std.testing.expect(!std.mem.eql(u8, &no_combo.digest, &(try protocol.computeIdentity(input)).digest));
}

test "v2 arbitrary mutations either fail or reencode exactly" {
    for ([_]protocol.Report{ hello, identity_parts[0], identity_parts[2], snapshot_parts[0], release, overflow }) |seed| {
        const direction: protocol.Direction = if (seed[2] == 10) .host_to_device else .device_to_host;
        for (0..32) |index| for (0..256) |value| {
            var report = seed;
            report[index] = @intCast(value);
            const decoded = protocol.decodePacket(&report, dimensions, direction) catch continue;
            try std.testing.expectEqual(report, try protocol.encodePacket(decoded, dimensions, direction));
        };
    }
}
