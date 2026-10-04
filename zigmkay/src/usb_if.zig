const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;
const usb = microzig.core.usb;
const USB_Device = rp2xxx.usb.Polled(.{});
const transport = @import("telemetry_transport.zig");
const control = @import("usb_control.zig");
const requests = @import("usb_requests.zig");
const diagnostics = @import("usb_diagnostics.zig");
const buffer_control = @import("usb_buffer_control.zig");
var diagnostic_record = diagnostics.Recorder{};
var pending_bootsel = false;
var boundary_failed = false;
var configuration_epoch: u32 = 0;

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

pub const KeyboardInReport = @import("usb_reports.zig").Keyboard;

pub const KeyboardOutReport = packed struct(u8) {
    num_lock: bool,
    caps_lock: bool,
    scroll_lock: bool,
    compose: bool,
    kana: bool,
    padding: u3 = 0,
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
            .usage_range = .{ 0x00, 0xe7 },
            .logical_range = .{ 0x00, 0xe7 },
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
    .reset = "USBREC1",
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
    const device: usb.descriptor.Device = .{
        .bcd_usb = usb_config.bcd_usb,
        .device_triple = usb_config.device_triple,
        .max_packet_size0 = 64,
        .vendor = .from(usb_config.vendor.id),
        .product = .from(usb_config.product.id),
        .bcd_device = usb_config.bcd_device,
        .manufacturer_s = 1,
        .product_s = 2,
        .serial_s = 3,
        .num_configurations = 1,
    };
    const string_descriptors = alloc.string_descriptors(usb_config.language);
    var strings: [string_descriptors.len][]const u8 = undefined;
    for (string_descriptors, &strings) |descriptor, *data| data.* = descriptor.data;
    break :blk .{ .configuration = bytes, .hid = hid, .device = wire.encode(device), .strings = strings };
};

pub var usb_controller: ControllerType = .init;
var driver_initializer = @import("usb_driver_init.zig").Initializer(usb, usb_config, usb_args){ .observe = observe_driver };
const configuration_bytes = wire_descriptors.configuration;
const hid_bytes = wire_descriptors.hid;
const device_bytes = wire_descriptors.device;
const string_bytes = wire_descriptors.strings;
var request_state = requests.Device{
    .device_descriptor = &device_bytes,
    .configuration_descriptor = &configuration_bytes,
    .strings = &string_bytes,
    .hid_descriptors = &hid_bytes,
    .report_descriptors = &.{ Keyboard.report_descriptor, ConsumerControl.report_descriptor, Mouse.report_descriptor, RawHid.report_descriptor },
    .endpoints = &.{ 0x01, 0x82, 0x03, 0x84, 0x05, 0x86, 0x07, 0x88 },
    .hooks = .{ .configure = configure_drivers, .address = set_address, .halt = endpoint_halt, .vendor_output = receive_vendor, .alternate = reset_alternate },
};
var last_input_ms: [4]u64 = @splat(0);
var vendor_controller = control.Controller(usb, ControllerType){
    .base = &usb_controller,
    .configuration_descriptor = &configuration_bytes,
    .hid_descriptors = &hid_bytes,
    .hooks = .{
        .prepare = prepare_vendor_control,
        .reject = reject_vendor_control,
        .configure = configure_drivers,
        .request = handle_request,
        .output = receive_control_output,
        .status_complete = status_complete,
        .reset = reset_requests,
        .interrupt_output = receive_interrupt_output,
        .ready = boundary_ready,
    },
};

fn handle_request(setup: control.Setup) @import("usb_ep0.zig").Reply {
    // Do not overwrite the captured failure while fetching the diagnostic.
    if (setup.request_type == 0x80 and setup.request == 6 and setup.value == 0x0308 and setup.index == 0x0409) return .{ .input = diagnostic_record.string() };
    diagnostic_record.setup(setup);
    // Preserve the reset interface's default BOOTSEL request; commit only after
    // status IN so the host does not lose its control-transfer acknowledgment.
    if (setup.request_type == 0x41 and setup.request == 1 and setup.index == 4 and setup.value == 0 and setup.length == 0 and request_state.configuration == 1) {
        pending_bootsel = true;
        return .ack;
    }
    const reply = request_state.setup(setup);
    if (boundary_failed) return .reject;
    if (setup.request_type == 0x00 and setup.request == 9 and reply == .ack) {
        if (vendor_controller.telemetry) |t| t.disconnect();
    }
    return reply;
}

fn receive_control_output(bytes: []const u8) bool {
    return request_state.receiveOutput(bytes);
}

fn receive_vendor(bytes: []const u8) void {
    if (vendor_controller.telemetry) |t| t.receive(bytes);
}

fn status_complete() void {
    diagnostic_record.record(.status, 0, 0, 0);
    request_state.statusComplete();
    if (pending_bootsel) rp2xxx.rom.reset_to_usb_boot();
}

fn set_address(address: u7) void {
    usb_device.interface.set_address(address);
}

fn reset_requests() void {
    diagnostic_record.record(.reset, 0, 0, 0);
    pending_bootsel = false;
    request_state.reset();
}

fn boundary_ready() bool {
    return !boundary_failed;
}

fn begin_revoke(mask: u32) bool {
    const peripheral = microzig.chip.peripherals;
    const controls: *volatile [32]u32 = @ptrCast(&peripheral.USB_DPRAM.EP0_IN_BUFFER_CONTROL);
    var active: u32 = 0;
    for (0..32) |bit| {
        const flag = @as(u32, 1) << @intCast(bit);
        if (mask & flag != 0 and controls[bit] & (1 << 10) != 0) active |= flag;
    }
    if (active == 0) return true;
    // RP2040-E2: B0/B1 cannot safely revoke an owned buffer. Fail closed
    // instead of pretending cancellation succeeded on those revisions.
    if (peripheral.SYSINFO.CHIP_ID.read().REVISION < 2) {
        boundary_failed = true;
        diagnostic_record.record(.abort_timeout, 0, 0, 0);
        return false;
    }
    peripheral.USB.EP_ABORT.raw |= active;
    const start = rp2xxx.time.get_time_since_boot().to_us();
    while (peripheral.USB.EP_ABORT_DONE.raw & active != active) {
        if (rp2xxx.time.get_time_since_boot().to_us() -| start >= 1000) {
            boundary_failed = true;
            diagnostic_record.record(.abort_timeout, 0, 0, @truncate(active));
            return false;
        }
    }
    return true;
}

fn end_revoke(mask: u32) void {
    const peripheral = microzig.chip.peripherals;
    peripheral.USB.EP_ABORT_DONE.raw = buffer_control.abortDoneAck(mask);
    peripheral.USB.EP_ABORT.raw &= ~mask;
}

fn reset_alternate(interface: u8) void {
    if (interface >= 4) return;
    _ = endpoint_halt(request_state.endpoints[@as(usize, interface) * 2], false);
    _ = endpoint_halt(request_state.endpoints[@as(usize, interface) * 2 + 1], false);
}

fn observe_driver(event: u8, interface: u8, endpoint: u8, size: u16) void {
    diagnostic_record.record(@enumFromInt(event), interface, endpoint, size);
}

fn receive_interrupt_output(endpoint: u8, bytes: []const u8) u16 {
    if (usb_controller.drivers()) |drivers| {
        inline for (.{ "keyboard", "consumer", "mouse", "rawhid" }, 0..) |name, index| {
            const descriptor = @field(drivers, name).descriptor;
            if (@intFromEnum(descriptor.ep_out.endpoint.num) == endpoint) {
                _ = request_state.interruptOutput(index, bytes);
                return descriptor.ep_out.max_packet_size.into();
            }
        }
    }
    return 0;
}

fn endpoint_halt(address: u8, change: ?bool) bool {
    const number = address & 0x0f;
    const direction: usize = if (address & 0x80 != 0) 0 else 1;
    const peripheral = microzig.chip.peripherals;
    const buffer_controls: *volatile [32]u32 = @ptrCast(&peripheral.USB_DPRAM.EP0_IN_BUFFER_CONTROL);
    const register = &buffer_controls[@as(usize, number) * 2 + direction];
    if (change) |halted| {
        const mask = @as(u32, 1) << @intCast(@as(usize, number) * 2 + direction);
        if (!begin_revoke(mask)) return true;
        if (halted) {
            register.* |= 1 << 11; // STALL
        } else {
            // Drop old ownership/full state and restore the next packet DATA0.
            register.* = 1 << 13; // PID_0 is flipped by write/listen.
            end_revoke(mask);
            peripheral.USB.BUFF_STATUS.raw = @as(u32, 1) << @intCast(@as(usize, number) * 2 + direction);
            if (usb_controller.drivers()) |drivers| {
                inline for (.{ "keyboard", "consumer", "mouse", "rawhid" }) |name| {
                    const driver = &@field(drivers, name);
                    if (direction == 0 and @intFromEnum(driver.descriptor.ep_in.endpoint.num) == number) driver.tx_ready.store(true, .seq_cst);
                    if (direction == 1 and @intFromEnum(driver.descriptor.ep_out.endpoint.num) == number) usb_device.interface.ep_listen(@enumFromInt(number), @intCast(driver.descriptor.ep_out.max_packet_size.into()));
                }
            }
        }
        if (halted) end_revoke(mask);
    }
    return register.* & (1 << 11) != 0;
}

fn configure_drivers(number: u16) void {
    const peripherals = microzig.chip.peripherals;
    if (!begin_revoke(0xfffffffc)) return;
    configuration_epoch +%= 1;
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
    end_revoke(0xfffffffc);
    const arena: [*]align(64) u8 = @ptrFromInt(@intFromPtr(peripherals.USB_DPRAM) + 0x180);
    usb_device.data_buffer = arena[0..3712];
    last_input_ms = @splat(0);
    driver_initializer.configure(&usb_controller, &usb_device.interface, number);
}

// Polled resets only the IN PID on SETUP. A vendor Output SetReport starts
// a fresh OUT DATA1 stage, including after cancellation/stall. Keep the hardware
// adjustment here rather than modifying the immutable dependency.
fn prepare_vendor_control() void {
    const peripherals = microzig.chip.peripherals;
    request_state.cancel();
    pending_bootsel = false;
    if (!begin_revoke(3)) return;
    // Polled processes SETUP before buffer completions. Cancel only EP0's
    // stale completion flags so old OUT bytes cannot satisfy a new data stage.
    peripherals.USB.BUFF_STATUS.raw = 0b11;
    peripherals.USB_DPRAM.EP0_OUT_BUFFER_CONTROL.raw = buffer_control.prepareSetup(peripherals.USB_DPRAM.EP0_OUT_BUFFER_CONTROL.raw);
    peripherals.USB_DPRAM.EP0_IN_BUFFER_CONTROL.raw = buffer_control.prepareSetup(peripherals.USB_DPRAM.EP0_IN_BUFFER_CONTROL.raw);
    peripherals.USB.EP_STALL_ARM.modify(.{ .EP0_IN = 0, .EP0_OUT = 0 });
    end_revoke(3);
}

fn reject_vendor_control() void {
    if (boundary_failed) return;
    diagnostic_record.record(.stall, 0, 0, 0);
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
    vendor_controller.transfer.reset();
    usb_device = .init();
    boundary_failed = false;
    request_state.reset();
}

pub fn poll() void {
    poll_usb_events();
}

pub fn configuration_generation() u32 {
    return configuration_epoch;
}

pub fn configured() bool {
    return !boundary_failed and usb_controller.drivers() != null;
}

pub fn idle(pending: [4]bool) void {
    if (boundary_failed) return;
    // Idle duration is in 4 ms units. Repeat only the last successfully sent
    // report and only when its endpoint has completed the previous transfer.
    const now = rp2xxx.time.get_time_since_boot().to_us() / 1000;
    if (usb_controller.drivers()) |drivers| {
        inline for (.{ "keyboard", "consumer", "mouse", "rawhid" }, 0..) |name, index| {
            const driver = &@field(drivers, name);
            if (!pending[index] and request_state.idleDue(index, now, last_input_ms[index]) and driver.tx_ready.load(.seq_cst) and !endpoint_halt(request_state.endpoints[index * 2 + 1], null)) {
                driver.tx_ready.store(false, .seq_cst);
                _ = driver.device.ep_writev(driver.descriptor.ep_in.endpoint.num, &.{request_state.input[index][0..requests.Device.input_sizes[index]]});
                last_input_ms[index] = now;
            }
        }
    }
}

fn poll_usb_events() void {
    const peripheral = microzig.chip.peripherals;
    const controls: *volatile [32]u32 = @ptrCast(&peripheral.USB_DPRAM.EP0_IN_BUFFER_CONTROL);
    const interrupts = peripheral.USB.INTS.read();
    // Reset supersedes SETUP and completion events from the old bus state.
    if (interrupts.BUS_RESET != 0) {
        peripheral.USB.SIE_STATUS.modify(.{ .BUS_RESET = 1 });
        peripheral.USB.EP_ABORT.raw = 0;
        peripheral.USB.EP_ABORT_DONE.raw = buffer_control.abortDoneAck(0xffffffff);
        for (0..32) |i| controls[i] = 0;
        peripheral.USB.BUFF_STATUS.raw = 0xffffffff;
        boundary_failed = false;
        usb_device.interface.set_address(0);
        vendor_controller.on_bus_reset(&usb_device.interface);
        return;
    }
    if (boundary_failed) return;
    if (interrupts.SETUP_REQ != 0) {
        const setup: usb.types.SetupPacket = @bitCast([2]u32{
            peripheral.USB_DPRAM.SETUP_PACKET_LOW.raw,
            peripheral.USB_DPRAM.SETUP_PACKET_HIGH.raw,
        });
        peripheral.USB.SIE_STATUS.modify(.{ .SETUP_REC = 1 });
        vendor_controller.on_setup_req(&usb_device.interface, &setup);
        if (boundary_failed) return;
    }
    // Read fresh after cancellation; acknowledge each completion before its
    // callback so a newly completed/rearmed packet is not erased afterward.
    const completed = peripheral.USB.BUFF_STATUS.raw;
    inline for (0..32) |bit| {
        const mask = @as(u32, 1) << bit;
        if (completed & mask != 0) {
            const start = rp2xxx.time.get_time_since_boot().to_us();
            while (controls[bit] & (1 << 10) != 0) {
                if (rp2xxx.time.get_time_since_boot().to_us() -| start >= 1000) {
                    boundary_failed = true;
                    diagnostic_record.record(.abort_timeout, @intCast(bit), 1, 0);
                    return;
                }
            }
            peripheral.USB.BUFF_STATUS.raw = mask;
            const endpoint: usb.types.Endpoint = comptime .{ .num = @enumFromInt(bit / 2), .dir = if (bit % 2 == 0) .In else .Out };
            if (bit < 2 or usb_controller.drivers() != null) vendor_controller.on_buffer(&usb_device.interface, endpoint);
        }
    }
}

pub fn telemetry_endpoint() transport.Endpoint {
    return .{ .context = &usb_controller, .send = send_telemetry };
}

fn send_telemetry(context: *anyopaque, report: *const @import("device-protocol").Report) bool {
    if (boundary_failed) return false;
    const controller: *ControllerType = @ptrCast(@alignCast(context));
    if (controller.drivers()) |drivers| {
        if (endpoint_halt(0x88, null)) return false;
        if (drivers.rawhid.send_report(report)) {
            record_input(3, report);
            return true;
        }
    }
    return false;
}

/// Dispatches a keyboard report over the first HID interface
pub fn send_keyboard_report(report: *const KeyboardInReport) bool {
    if (boundary_failed) return false;
    if (usb_controller.drivers()) |drivers| {
        if (endpoint_halt(0x82, null)) return false;
        if (drivers.keyboard.send_report(report)) {
            record_input(0, std.mem.asBytes(report));
            return true;
        }
    }
    return false;
}

/// Dispatches a consumer layout report (Media Keys)
pub fn send_consumer_report(report: *const ConsumerInReport) bool {
    if (boundary_failed) return false;
    if (usb_controller.drivers()) |drivers| {
        if (endpoint_halt(0x84, null)) return false;
        if (drivers.consumer.send_report(report)) {
            record_input(1, std.mem.asBytes(report));
            return true;
        }
    }
    return false;
}

/// Dispatches a mouse payload containing movement or clicks
pub fn send_mouse_report(report: *const MouseInReport) bool {
    if (boundary_failed) return false;
    if (usb_controller.drivers()) |drivers| {
        if (endpoint_halt(0x86, null)) return false;
        if (drivers.mouse.send_report(report)) {
            record_input(2, std.mem.asBytes(report));
            // Relative deltas must not be replayed by idle/GetReport.
            @memset(request_state.input[2][1..5], 0);
            return true;
        }
    }
    return false;
}

/// Pushes a custom 32-byte payload to the RAWHID interface for companion app signalling
pub fn send_raw_report(report: *const RawHidReport) bool {
    if (boundary_failed) return false;
    if (vendor_controller.telemetry != null) return true;
    if (usb_controller.drivers()) |drivers| {
        if (endpoint_halt(0x88, null)) return false;
        if (drivers.rawhid.send_report(report)) {
            record_input(3, report);
            return true;
        }
    }
    return false;
}

fn record_input(index: u8, bytes: []const u8) void {
    request_state.recordInput(index, bytes);
    last_input_ms[index] = rp2xxx.time.get_time_since_boot().to_us() / 1000;
}

pub fn keyboard_leds() KeyboardOutReport {
    return @bitCast(request_state.output[0][0]);
}
