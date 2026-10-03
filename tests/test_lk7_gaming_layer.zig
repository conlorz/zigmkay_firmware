const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const lk7 = @import("lk7-keymap");
const Processor = zigmkay.processing.CreateProcessorType(&lk7.dimensions, &lk7.keymap, &lk7.sides, &lk7.combos, &lk7.custom_functions, &.{});

test "real LK7 gaming combo cannot activate an undefined fifth layer" {
    var input = core.MatrixStateChangeQueue.Create();
    var encoders = core.EncoderEventQueue.Create();
    var output = core.OutputCommandQueue.Create();
    var processor = Processor{ .input_matrix_changes = &input, .encoder_event_changes = &encoders, .output_usb_commands = &output };
    try input.enqueue(.{ .pressed = true, .key_index = 0, .time = core.TimeSinceBoot.from_absolute_us(0) });
    try input.enqueue(.{ .pressed = true, .key_index = 9, .time = core.TimeSinceBoot.from_absolute_us(1_000) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(2_000));
    try std.testing.expectEqual(@as(u32, 1), processor.layers_activations.rejected_activations);
    try std.testing.expectEqual(@as(core.LayerIndex, 0), processor.layers_activations.get_top_most_active_layer());
    try std.testing.expect(!processor.layers_activations.is_layer_active(4));
    try input.enqueue(.{ .pressed = false, .key_index = 0, .time = core.TimeSinceBoot.from_absolute_us(3_000) });
    try input.enqueue(.{ .pressed = false, .key_index = 9, .time = core.TimeSinceBoot.from_absolute_us(4_000) });
    try processor.Process(core.TimeSinceBoot.from_absolute_us(5_000));
    try std.testing.expectEqual(@as(usize, 0), output.Count());
    processor.layers_activations.activate(1);
    try std.testing.expect(processor.layers_activations.is_layer_active(1));
    processor.layers_activations.deactivate(1);
    try std.testing.expectEqual(@as(core.LayerIndex, 0), processor.layers_activations.get_top_most_active_layer());
}
