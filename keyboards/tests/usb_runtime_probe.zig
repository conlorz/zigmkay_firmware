const std = @import("std");
const usb = @import("usb");
const D = usb.drivers.hid.InterruptDriver(.{ .subclass = .Unspecified, .protocol = @enumFromInt(0), .InReport = [8]u8, .OutReport = [1]u8, .report_descriptor = &.{.main_collection_end} });
const config: usb.Config = .{ .bcd_usb = .v2_00, .device_triple = .unspecified, .vendor = .{ .id = 1, .str = "A" }, .product = .{ .id = 2, .str = "B" }, .bcd_device = .v1_00, .serial = "1", .max_supported_packet_size = 64, .configurations = &.{.{ .attributes = .{ .self_powered = false }, .max_current_ma = 100, .Drivers = struct { hid: D } }} };
const args: config.DriverArgs() = .{.{ .hid = .{ .poll_interval = 1 } }};
const C = usb.DeviceController(config, args);
const Initializer = @import("zigmkay").usb_driver_init.Initializer(usb, config, args);
var initializer = Initializer{};
export var capture: [16]u16 = @splat(0);
var n: usize = 0;
fn open(_: *usb.DeviceInterface, d: *const usb.descriptor.Endpoint) void {
    capture[n] = @as(u8, @bitCast(d.endpoint));
    capture[n + 1] = d.max_packet_size.into();
    n += 2;
}
fn listen(_: *usb.DeviceInterface, e: usb.types.Endpoint.Num, l: usb.types.Len) void {
    capture[n] = @intFromEnum(e);
    capture[n + 1] = l;
    n += 2;
}
fn write(_: *usb.DeviceInterface, _: usb.types.Endpoint.Num, _: []const []const u8) usb.types.Len {
    return 0;
}
fn read(_: *usb.DeviceInterface, _: usb.types.Endpoint.Num, _: []const []u8) usb.types.Len {
    return 0;
}
fn address(_: *usb.DeviceInterface, _: u7) void {}
const vt: usb.DeviceInterface.VTable = .{ .ep_open = open, .ep_listen = listen, .ep_writev = write, .ep_readv = read, .set_address = address };
export fn run() void {
    n = 0;
    var c: C = .init;
    var i: usb.DeviceInterface = .{ .vtable = &vt };
    const s: usb.types.SetupPacket = @bitCast([8]u8{ 0, 9, 1, 0, 0, 0, 0, 0 });
    c.on_setup_req(&i, &s);
}
export fn run_fixed() void {
    n = 0;
    var c: C = .init;
    var i: usb.DeviceInterface = .{ .vtable = &vt };
    initializer.configure(&c, &i, 1);
}

test "real pinned HID initialization uses persistent decoded endpoint fields" {
    var c: C = .init;
    var i: usb.DeviceInterface = .{ .vtable = &vt };
    for (0..20) |_| {
        n = 0;
        initializer.configure(&c, &i, 1);
        try std.testing.expectEqualSlices(u16, &.{ 1, 1, 1, 1, 0x82, 8 }, capture[0..n]);
        try std.testing.expectEqual(@as(u16, 1), c.cfg_num);
        try std.testing.expectEqual(@as(u8, 0), c.drivers().?.hid.descriptor.interface.interface_number);
        try std.testing.expectEqual(@as(u16, 8), c.drivers().?.hid.descriptor.ep_in.max_packet_size.into());
        initializer.configure(&c, &i, 0);
        try std.testing.expect(c.drivers() == null);
        try std.testing.expectEqual(@as(u16, 0), c.cfg_num);
    }
}
pub const std_options: std.Options = .{ .logFn = quiet };
fn quiet(comptime _: std.log.Level, comptime _: @EnumLiteral(), comptime _: []const u8, _: anytype) void {}
