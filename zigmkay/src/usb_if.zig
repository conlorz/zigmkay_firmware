const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;
const usb = microzig.core.usb;
const USB_Device = rp2xxx.usb.Polled(.{});
const transport = @import("telemetry_transport.zig");
const control = @import("usb_control.zig");

pub const HID_KeymodifierCodes = enum(u8) {
    left_control = 0xe0,
    left_shift,
    left_alt,
    left_gui,
    right_control,
    right_shift,
    right_alt,
    right_gui,
};

pub const KeyboardInReport = extern struct {
    modifiers: u8,
    reserved: u8 = 0,
    keys: [6]u8,

    pub const empty: @This() = .{ .modifiers = 0, .keys = @splat(0) };
};

pub const KeyboardOutReport = packed struct(u8) {
    num_lock: bool,
    caps_lock: bool,
    scroll_lock: bool,
    padding: u5 = 0,
};

// HID Interrupt Driver for Standard Boot Keyboard
const Keyboard = usb.drivers.hid.InterruptDriver(.{
    .subclass = .Boot,
    .protocol = .Boot,
    .report_descriptor = &.{
        .{ .global_usage_page = .generic_desktop },
        .local_usage_enum(.{ .generic_desktop = .keyboard }),
        .{ .main_collection = .Application },
        // Input: modifier key bitmap
        .{ .data = .{
            .usage = .{ .global_page = .keyboard },
            .usage_range = .{ 0xE0, 0xE7 },
            .count = 8,
            .Child = bool,
            .dir = .In,
            .type = .dynamic,
        } },
        .{ .data_static = .{ .In, u8 } },
        // Input: up to 6 pressed key codes
        .{ .data = .{
            .usage = .{ .global_page = .keyboard },
            .usage_range = .{ 0x00, 0xff },
            .count = 6,
            .Child = u8,
            .dir = .In,
            .type = .selector,
        } },
        // Output: indicator LEDs
        .{ .data = .{
            .usage = .{ .global_page = .led },
            .usage_range = .{ 1, 5 },
            .count = 5,
            .Child = bool,
            .dir = .Out,
            .type = .dynamic,
        } },
        // Padding
        .{ .data_static = .{ .Out, u3 } },
        // End
        .main_collection_end,
    },
    .InReport = KeyboardInReport,
    .OutReport = KeyboardOutReport,
});

// Consumer Control (Media Keys)
pub const ConsumerInReport = extern struct {
    button: u16,
    pub const empty: @This() = .{ .button = 0 };
};

// HID Interrupt Driver for Consumer Control endpoints
const ConsumerControl = usb.drivers.hid.InterruptDriver(.{
    .subclass = .Unspecified,
    .protocol = .NoneRequired,
    .report_descriptor = &.{
        .{ .global_usage_page = @enumFromInt(0x0C) }, // Consumer Page
        .{ .local_usage = 0x01 }, // Consumer Control
        .{ .main_collection = .Application },
        .{ .data = .{
            .usage = .{ .global_page = @enumFromInt(0x0C) },
            .usage_range = .{ 0x00, 0x03FF },
            .count = 1,
            .Child = u16,
            .dir = .In,
            .type = .selector,
        } },
        .main_collection_end,
    },
    .InReport = ConsumerInReport,
    .OutReport = u8, // Dummy OutReport
});

// Mouse Implementation
pub const MouseInReport = extern struct {
    buttons: u8,
    x: i8,
    y: i8,
    wheel: i8,
    pan: i8,

    pub const empty: @This() = .{ .buttons = 0, .x = 0, .y = 0, .wheel = 0, .pan = 0 };
};

// HID Interrupt Driver for generic Mouse functionality
const Mouse = usb.drivers.hid.InterruptDriver(.{
    .subclass = .Unspecified,
    .protocol = .NoneRequired,
    .report_descriptor = &.{
        .{ .global_usage_page = .generic_desktop },
        .local_usage_enum(.{ .generic_desktop = @enumFromInt(0x02) }), // Mouse
        .{ .main_collection = .Application },
        .{ .local_usage = 0x01 }, // Pointer
        .{ .main_collection = .Physical },
        .{
            .data = .{
                .usage = .{ .global_page = @enumFromInt(0x09) }, // Button
                .usage_range = .{ 1, 5 },
                .count = 5,
                .Child = bool,
                .dir = .In,
                .type = .dynamic,
            },
        },
        .{ .data_static = .{ .In, u3 } }, // Padding
        .{ .global_usage_page = .generic_desktop },
        .{ .local_usage_range = .{ 0x30, 0x31 } }, // X, Y
        .{ .global_logical_range = .{ -127, 127 } },
        .{ .global_report_count = 2 },
        .{ .global_report_size = 8 },
        .{ .main_input = .{ .variable = true, .relative = true } },
        // Wheel — must be Relative so the OS maps it to REL_WHEEL, not ABS_WHEEL
        .{ .local_usage = 0x38 },
        .{ .global_logical_range = .{ -127, 127 } },
        .{ .global_report_count = 1 },
        .{ .global_report_size = 8 },
        .{ .main_input = .{ .variable = true, .relative = true } },
        // Pan — same: Relative maps to REL_HWHEEL
        .{ .global_usage_page = @enumFromInt(0x0C) }, // Consumer
        .{ .local_usage = 0x0238 },
        .{ .global_logical_range = .{ -127, 127 } },
        .{ .global_report_count = 1 },
        .{ .global_report_size = 8 },
        .{ .main_input = .{ .variable = true, .relative = true } },
        .main_collection_end,
        .main_collection_end,
    },
    .InReport = MouseInReport,
    .OutReport = u8, // Dummy
});

// RAWHID Implementation (QMK Style)
pub const RawHidReport = [32]u8;

// HID Interrupt Driver for the dedicated 32-byte bidirectional RAWHID channel (Companion App Telemetry)
const RawHid = usb.drivers.hid.InterruptDriver(.{
    .subclass = .Unspecified,
    .protocol = .NoneRequired,
    .report_descriptor = &.{
        .{ .global_usage_page = @enumFromInt(0xFF31) }, // Vendor Page 0xFF31
        .{ .local_usage = 0x0074 }, // Usage 0x0074
        .{ .main_collection = .Application },
        // Input: 32 bytes
        .{ .data = .{
            .usage = .{ .local_raw = 0x01 },
            .count = 32,
            .Child = u8,
            .dir = .In,
            .type = .dynamic,
        } },
        // Output: 32 bytes
        .{ .data = .{
            .usage = .{ .local_raw = 0x02 },
            .count = 32,
            .Child = u8,
            .dir = .Out,
            .type = .dynamic,
        } },
        .main_collection_end,
    },
    .InReport = RawHidReport,
    .OutReport = RawHidReport,
});

pub var usb_device: USB_Device = undefined;

const usb_config: usb.Config = .{
    .bcd_usb = .v2_00,
    .device_triple = .unspecified,
    .vendor = .{ .id = 0xFAFA, .str = "OpenKeyboardCollective" },
    .product = .{ .id = 0x00F0, .str = "ZigMkay" },
    .bcd_device = .v1_00,
    .serial = "00000001",
    .max_supported_packet_size = USB_Device.max_supported_packet_size,
    .configurations = &.{.{
        .attributes = .{ .self_powered = false },
        .max_current_ma = 500,
        .Drivers = struct {
            keyboard: Keyboard,
            consumer: ConsumerControl,
            mouse: Mouse,
            rawhid: RawHid,
            reset: rp2xxx.usb.ResetDriver(null, 0),
        },
    }},
};
const usb_args: usb_config.DriverArgs() = .{.{
    .keyboard = .{ .itf_string = "Keyboard", .poll_interval = 1 },
    .consumer = .{ .itf_string = "Consumer Control", .poll_interval = 10 },
    .mouse = .{ .itf_string = "Mouse", .poll_interval = 1 },
    .rawhid = .{ .itf_string = "RawHID", .poll_interval = 1 },
    .reset = "",
}};

pub const ControllerType = usb.DeviceController(usb_config, usb_args);

const wire = @import("usb_descriptor_bytes.zig");
const wire_descriptors = blk: {
    @setEvalBranchQuota(20000);
    const config = usb_config.configurations[0];
    var alloc: usb.DescriptorAllocator = .init(usb_config.unique_endpoints);
    _ = alloc.string(usb_config.vendor.str);
    _ = alloc.string(usb_config.product.str);
    _ = alloc.string(usb_config.serial);
    const name = alloc.string(config.name);
    const fields = @typeInfo(config.Drivers).@"struct".fields;
    var length = wire.size(usb.descriptor.Configuration);
    for (fields) |field| length += wire.size(field.type.Descriptor);
    var bytes: [length]u8 = undefined;
    var hid: [4][9]u8 = undefined;
    var hid_count: usize = 0;
    var offset: usize = wire.size(usb.descriptor.Configuration);
    for (fields) |field| {
        const descriptors = field.type.Descriptor.create(&alloc, usb_config.max_supported_packet_size, @field(usb_args[0], field.name)).descriptor;
        wire.append(&bytes, &offset, descriptors);
        if (@hasField(@TypeOf(descriptors), "hid")) {
            hid[hid_count] = wire.encode(descriptors.hid);
            hid_count += 1;
        }
    }
    var start: usize = 0;
    wire.append(&bytes, &start, @as(usb.descriptor.Configuration, .{
        .total_length = .from(length),
        .num_interfaces = alloc.next_itf_num,
        .configuration_value = 1,
        .configuration_s = name,
        .attributes = config.attributes,
        .max_current = .from_ma(config.max_current_ma),
    }));
    std.debug.assert(offset == length);
    break :blk .{ .configuration = bytes, .hid = hid };
};

pub var usb_controller: ControllerType = .init;
var driver_initializer = @import("usb_driver_init.zig").Initializer(usb, usb_config, usb_args){};
const configuration_bytes = wire_descriptors.configuration;
const hid_bytes = wire_descriptors.hid;
var vendor_controller = control.Controller(usb, ControllerType){
    .base = &usb_controller,
    .configuration_descriptor = &configuration_bytes,
    .hid_descriptors = &hid_bytes,
    .hooks = .{ .prepare = prepare_vendor_control, .reject = reject_vendor_control, .configure = configure_drivers },
};

fn configure_drivers(number: u16) void {
    const peripherals = microzig.chip.peripherals;
    // The pinned HAL has no endpoint-close API. Reset its noncontrol endpoint
    // registers and allocation arena at configuration boundaries, including a
    // repeated selection of configuration one. EP0 retains its fixed buffers.
    const controls: *volatile [30]u32 = @ptrCast(&peripherals.USB_DPRAM.EP1_IN_CONTROL);
    const buffers: *volatile [30]u32 = @ptrCast(&peripherals.USB_DPRAM.EP1_IN_BUFFER_CONTROL);
    for (0..30) |i| {
        controls[i] = 0;
        buffers[i] = 0;
    }
    peripherals.USB.BUFF_STATUS.raw = 0xfffffffc;
    const arena: [*]align(64) u8 = @ptrFromInt(@intFromPtr(peripherals.USB_DPRAM) + 0x180);
    usb_device.data_buffer = arena[0..3712];
    driver_initializer.configure(&usb_controller, &usb_device.interface, number);
}

// Polled resets only the IN PID on SETUP. A vendor Output SetReport starts
// a fresh OUT DATA1 stage, including after cancellation/stall. Keep the hardware
// adjustment here rather than modifying the immutable dependency.
fn prepare_vendor_control() void {
    const peripherals = microzig.chip.peripherals;
    // Polled processes SETUP before buffer completions. Cancel only EP0's
    // stale completion flags so old OUT bytes cannot satisfy a new data stage.
    peripherals.USB.BUFF_STATUS.raw = 0b11;
    peripherals.USB_DPRAM.EP0_OUT_BUFFER_CONTROL.modify(.{ .AVAILABLE_0 = 0, .FULL_0 = 0, .PID_0 = 0, .STALL = 0 });
    peripherals.USB_DPRAM.EP0_IN_BUFFER_CONTROL.modify(.{ .AVAILABLE_0 = 0, .FULL_0 = 0, .STALL = 0 });
    peripherals.USB.EP_STALL_ARM.modify(.{ .EP0_IN = 0, .EP0_OUT = 0 });
}

fn reject_vendor_control() void {
    const peripherals = microzig.chip.peripherals;
    peripherals.USB.EP_STALL_ARM.modify(.{ .EP0_IN = 1, .EP0_OUT = 1 });
    peripherals.USB_DPRAM.EP0_OUT_BUFFER_CONTROL.modify(.{ .STALL = 1 });
    peripherals.USB_DPRAM.EP0_IN_BUFFER_CONTROL.modify(.{ .STALL = 1 });
}

pub fn attach_telemetry(value: *transport.Transport) void {
    vendor_controller.telemetry = value;
}

pub fn init() void {
    usb_controller = .init;
    vendor_controller.telemetry = null;
    vendor_controller.gate = .{};
    vendor_controller.control_owned = false;
    vendor_controller.status_out_pending = false;
    usb_device = .init();
}

pub fn poll() void {
    usb_device.poll(&vendor_controller);
}

pub fn telemetry_endpoint() transport.Endpoint {
    return .{ .context = &usb_controller, .send = send_telemetry };
}

fn send_telemetry(context: *anyopaque, report: *const @import("device-protocol").Report) bool {
    const controller: *ControllerType = @ptrCast(@alignCast(context));
    if (controller.drivers()) |drivers| return drivers.rawhid.send_report(report);
    return false;
}

/// Dispatches a keyboard report over the first HID interface
pub fn send_keyboard_report(report: *const KeyboardInReport) void {
    if (usb_controller.drivers()) |drivers| {
        _ = drivers.keyboard.send_report(report);
    }
}

/// Dispatches a consumer layout report (Media Keys)
pub fn send_consumer_report(report: *const ConsumerInReport) void {
    if (usb_controller.drivers()) |drivers| {
        _ = drivers.consumer.send_report(report);
    }
}

/// Dispatches a mouse payload containing movement or clicks
pub fn send_mouse_report(report: *const MouseInReport) void {
    if (usb_controller.drivers()) |drivers| {
        _ = drivers.mouse.send_report(report);
    }
}

/// Pushes a custom 32-byte payload to the RAWHID interface for companion app signalling
pub fn send_raw_report(report: *const RawHidReport) void {
    if (vendor_controller.telemetry != null) return;
    if (usb_controller.drivers()) |drivers| {
        _ = drivers.rawhid.send_report(report);
    }
}
