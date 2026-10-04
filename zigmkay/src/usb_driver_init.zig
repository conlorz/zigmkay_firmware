//! Runtime descriptor storage for the pinned MicroZig driver boundary.
const std = @import("std");
const wire = @import("usb_descriptor_bytes.zig");

pub fn Initializer(comptime usb: type, comptime config: usb.Config, comptime args: config.DriverArgs()) type {
    const drivers = @typeInfo(config.configurations[0].Drivers).@"struct".fields;
    const Descriptors = blk: {
        var types: [drivers.len]type = undefined;
        for (drivers, &types) |driver, *T| T.* = driver.type.Descriptor;
        break :blk std.meta.Tuple(&types);
    };
    const bytes = blk: {
        @setEvalBranchQuota(20000);
        var alloc = usb.DescriptorAllocator.init(config.unique_endpoints);
        _ = alloc.string(config.vendor.str);
        _ = alloc.string(config.product.str);
        _ = alloc.string(config.serial);
        _ = alloc.string(config.configurations[0].name);
        var types: [drivers.len]type = undefined;
        for (drivers, &types) |driver, *T| T.* = [wire.size(driver.type.Descriptor)]u8;
        var result: std.meta.Tuple(&types) = undefined;
        for (drivers, 0..) |driver, i| {
            const desc = driver.type.Descriptor.create(&alloc, config.max_supported_packet_size, @field(args[0], driver.name));
            result[i] = wire.encode(desc.descriptor);
        }
        break :blk result;
    };
    return struct {
        descriptors: Descriptors = undefined,

        pub fn configure(self: *@This(), base: anytype, device: *usb.DeviceInterface, number: u16) void {
            std.debug.assert(number <= 1);
            base.driver_data = null;
            base.cfg_num = number;
            if (number == 0) return;
            base.driver_data = @as(config.configurations[0].Drivers, undefined);
            inline for (drivers, 0..) |field, i| {
                const T = field.type.Descriptor;
                self.descriptors[i] = wire.decode(T, &bytes[i]);
                const desc = &self.descriptors[i];
                inline for (@typeInfo(T).@"struct".fields) |part| {
                    if (comptime part.type == usb.descriptor.Endpoint) {
                        const endpoint = &@field(desc, part.name);
                        if (endpoint.endpoint.dir == .Out) device.ep_open(endpoint);
                    }
                }
                const driver = &@field(base.driver_data.?, field.name);
                if (@hasField(@TypeOf(base.driver_alloc), field.name)) {
                    driver.init(desc, device, &@field(base.driver_alloc, field.name));
                } else driver.init(desc, device);
                inline for (@typeInfo(T).@"struct".fields) |part| {
                    if (comptime part.type == usb.descriptor.Endpoint) {
                        const endpoint = &@field(desc, part.name);
                        if (endpoint.endpoint.dir == .In) device.ep_open(endpoint);
                    }
                }
            }
        }
    };
}
