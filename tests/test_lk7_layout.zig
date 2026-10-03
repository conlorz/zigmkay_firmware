const std = @import("std");
const model = @import("layout-model");
const geometry = model.physical_layout;
const lk7 = @import("lk7-keymap");
const physical = @import("lk7-physical");

test "real LK7 layout has a complete stable mapping and valid logical actions" {
    try std.testing.expectEqual(@as(usize, 34), physical.keys.len);
    try std.testing.expectEqual(@as(usize, 4), lk7.keymap.len);
    try geometry.validateKeys(&physical.keys, lk7.dimensions);
    try geometry.validateLogical(lk7.dimensions, &lk7.keymap, &lk7.combos);
    const original = physical.keys[30];
    var moved = physical.keys;
    moved[30].x += 2;
    moved[30].rotation = 20;
    try geometry.validateKeys(&moved, lk7.dimensions);
    const resolved = geometry.findById(&moved, original.id).?;
    try std.testing.expectEqual(original.key_index, resolved.key_index);
    try std.testing.expectEqual(model.Side.X, lk7.sides[30]);
    try std.testing.expectEqual(geometry.Hand.left, resolved.hand);
    // The existing placeholder explicitly disables its action; it is not fallthrough.
    try std.testing.expectEqual(model.KeyDef.none, lk7.keymap[1][20].?);
}

test "layout validation rejects ambiguous identities and invalid geometry" {
    var keys = physical.keys;
    keys[1].id = keys[0].id;
    try std.testing.expectError(error.DuplicateId, geometry.validateKeys(&keys, lk7.dimensions));
    keys = physical.keys;
    keys[1].key_index = keys[0].key_index;
    try std.testing.expectError(error.DuplicateIndex, geometry.validateKeys(&keys, lk7.dimensions));
    keys = physical.keys;
    keys[1].key_index = 34;
    try std.testing.expectError(error.InvalidKeyIndex, geometry.validateKeys(&keys, lk7.dimensions));
    keys = physical.keys;
    keys[1].width = 0;
    try std.testing.expectError(error.InvalidGeometry, geometry.validateKeys(&keys, lk7.dimensions));
    keys[1].width = std.math.nan(f32);
    try std.testing.expectError(error.InvalidGeometry, geometry.validateKeys(&keys, lk7.dimensions));
    try std.testing.expectError(error.WrongKeyCount, geometry.validateKeys(keys[0..33], lk7.dimensions));
}

test "logical validation rejects missing layers and invalid combos" {
    const invalid = model.KeyDef{ .tap_only = .{ .one_shot = .{ .hold_layer = 4 } } };
    try std.testing.expectError(error.InvalidLayer, geometry.validateAction(invalid, lk7.dimensions.layer_count));
    var combos = lk7.combos;
    combos[0].key_indexes[1] = 34;
    try std.testing.expectError(error.InvalidKeyIndex, geometry.validateLogical(lk7.dimensions, &lk7.keymap, &combos));
    combos = lk7.combos;
    combos[0].key_indexes[1] = combos[0].key_indexes[0];
    try std.testing.expectError(error.InvalidCombo, geometry.validateLogical(lk7.dimensions, &lk7.keymap, &combos));
    combos = lk7.combos;
    combos[0].layer = 4;
    try std.testing.expectError(error.InvalidLayer, geometry.validateLogical(lk7.dimensions, &lk7.keymap, &combos));
}
