//! Offline integration oracle: the free field must edit exactly like an ordinary
//! DVUI text entry, with OS text and editing events never entering the runner.
const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const sdl = @import("sdl-backend").c;

const Step = struct {
    input: union(enum) { text: [:0]const u8, key: dvui.Event.Key, paste: [:0]const u8 },
    expected: []const u8,
};
const command: dvui.enums.Mod = if (builtin.os.tag == .macos) .lcommand else .lcontrol;
const steps = [_]Step{
    .{ .input = .{ .text = "aéλZ" }, .expected = "aéλZ" },
    .{ .input = .{ .key = .{ .code = .left, .action = .down, .mod = .none } }, .expected = "aéλZ" },
    .{ .input = .{ .key = .{ .code = .backspace, .action = .down, .mod = .none } }, .expected = "aéZ" },
    .{ .input = .{ .key = .{ .code = .backspace, .action = .repeat, .mod = .none } }, .expected = "aZ" },
    .{ .input = .{ .key = .{ .code = .delete, .action = .down, .mod = .none } }, .expected = "a" },
    .{ .input = .{ .text = "ß" }, .expected = "aß" },
    .{ .input = .{ .key = .{ .code = .left, .action = .down, .mod = .none } }, .expected = "aß" },
    .{ .input = .{ .text = "X" }, .expected = "aXß" },
    .{ .input = .{ .key = .{ .code = .left, .action = .down, .mod = .lshift } }, .expected = "aXß" },
    .{ .input = .{ .text = "Ω" }, .expected = "aΩß" },
    .{ .input = .{ .key = .{ .code = .a, .action = .down, .mod = command } }, .expected = "aΩß" },
    .{ .input = .{ .text = "done" }, .expected = "done" },
    .{ .input = .{ .paste = "éλ" }, .expected = "doneéλ" },
    .{ .input = .{ .key = .{ .code = .backspace, .action = .down, .mod = .none } }, .expected = "doneé" },
    .{ .input = .{ .key = .{ .code = .backspace, .action = .up, .mod = .none } }, .expected = "doneé" },
};

pub const Driver = struct {
    reference: [8192]u8 = @splat(0),
    reference_len: usize = 0,
    clipboard: ?[]u8 = null,
    clipboard_window: ?*dvui.Window = null,
    sequence: u64 = 0,
    initialized: bool = false,
    pub const capture_frame = 48;

    pub fn deinit(self: *Driver, allocator: std.mem.Allocator) void {
        if (self.clipboard) |bytes| {
            if (self.clipboard_window) |window| window.backend.clipboardTextSet(bytes) catch |err| std.log.warn("Could not restore integration clipboard: {s}", .{@errorName(err)});
            allocator.free(bytes);
        }
    }

    pub fn beforeDraw(self: *Driver, editor: anytype, window: *dvui.Window, backend: *@import("sdl-backend"), frame: usize) !void {
        if (!self.initialized) {
            self.initialized = true;
            self.sequence = editor.testing.sequence;
            self.clipboard = try editor.gpa.dupe(u8, dvui.clipboardText());
            self.clipboard_window = window;
            editor.main_view = .try_it_out;
            editor.try_mode = .free_typing;
            editor.free_text.clear();
            editor.free_focus = false;
            editor.free_focus_requested = false;
        }
        const start: usize = if (frame < 26) 4 else 28;
        if (frame == start - 1) {
            const tag = dvui.tagGet(if (start == 4) "native.reference" else "free.input") orelse return error.NativeInputMissingField;
            window.focusWidget(tag.id, null, null);
            if (start == 28) editor.free_focus = true;
        }
        if (frame >= start and frame < start + steps.len) {
            const step = steps[frame - start];
            if (start == 28) {
                // A failed or preparing preview cannot delay ordinary text edits.
                editor.testing.state = if ((frame - start) % 2 == 0) .preparing else .failed;
                if (step.input == .paste) dvui.clipboardTextSet(step.input.paste);
                const event = try assertRawPassThrough(editor, step.input);
                _ = try backend.addEvent(window, event);
            }
            if (start == 4) switch (step.input) {
                .text => |text| _ = try window.addEventText(.{ .text = text }),
                .key => |key| _ = try window.addEventKey(key),
                .paste => |text| {
                    dvui.clipboardTextSet(text);
                    _ = try window.addEventKey(.{ .code = .v, .action = .down, .mod = command });
                },
            };
        }
        if (frame == 44) {
            var foreign = std.mem.zeroes(sdl.SDL_Event);
            foreign.type = sdl.SDL_EVENT_TEXT_INPUT;
            foreign.text.windowID = editor.window_id + 1000;
            foreign.text.text = @constCast("FOREIGN");
            if (try editor.raw(foreign)) return error.ForeignWindowInputConsumed;
            if (!sdl.SDL_PushEvent(&foreign)) return error.NativeInputEventPushFailed;
        }
        if (frame == 46) editor.testing.state = .idle;
    }

    pub fn drawReference(self: *Driver, frame: usize) void {
        if (frame >= 26) return;
        const entry = dvui.textEntry(@src(), .{ .text = .{ .buffer = &self.reference } }, .{
            .rect = .{ .x = 16, .y = 108, .w = 320, .h = 40 },
            .tag = "native.reference",
        });
        defer entry.deinit();
        self.reference_len = entry.textGet().len;
    }

    pub fn afterDraw(self: *Driver, editor: anytype, frame: usize) !void {
        const start: usize = if (frame < 26) 4 else 28;
        if (frame >= start and frame < start + steps.len) {
            const actual = if (start == 4) self.reference[0..self.reference_len] else editor.free_text.value();
            const expected = steps[frame - start].expected;
            if (!std.mem.eql(u8, actual, expected)) {
                std.log.err("Native text integration frame {d}: expected '{s}', received '{s}'", .{ frame, expected, actual });
                return error.NativeTextEditingMismatch;
            }
        }
        if (editor.testing.sequence != self.sequence or editor.testing.job != null) return error.NativeTextEnteredRunner;
        for (editor.testing.pressed) |pressed| if (pressed) return error.NativeTextSimulatedPhysicalKey;
        if (frame == 46) {
            try std.testing.expectEqualStrings(self.reference[0..self.reference_len], editor.free_text.value());
            std.log.info("Native free field matches ordinary text entry: Unicode, single Backspace, repeat, Delete, caret, selection replacement, paste, runner failures and foreign-window isolation", .{});
        }
    }
};

fn assertRawPassThrough(editor: anytype, input: @FieldType(Step, "input")) !sdl.SDL_Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    switch (input) {
        .text => |text| {
            event.type = sdl.SDL_EVENT_TEXT_INPUT;
            event.text.windowID = editor.window_id;
            event.text.text = @constCast(text.ptr);
        },
        .key => |key| {
            event.type = if (key.action == .up) sdl.SDL_EVENT_KEY_UP else sdl.SDL_EVENT_KEY_DOWN;
            event.key.windowID = editor.window_id;
            event.key.repeat = key.action == .repeat;
            event.key.key = switch (key.code) {
                .backspace => sdl.SDLK_BACKSPACE,
                .delete => sdl.SDLK_DELETE,
                .left => sdl.SDLK_LEFT,
                .a => sdl.SDLK_A,
                else => unreachable,
            };
            event.key.mod = if (key.mod == .lshift) sdl.SDL_KMOD_LSHIFT else if (key.mod == command) (if (builtin.os.tag == .macos) sdl.SDL_KMOD_LGUI else sdl.SDL_KMOD_LCTRL) else 0;
            event.key.scancode = switch (key.code) {
                .backspace => sdl.SDL_SCANCODE_BACKSPACE,
                .delete => sdl.SDL_SCANCODE_DELETE,
                .left => sdl.SDL_SCANCODE_LEFT,
                .a => sdl.SDL_SCANCODE_A,
                else => unreachable,
            };
        },
        .paste => {
            event.type = sdl.SDL_EVENT_KEY_DOWN;
            event.key.windowID = editor.window_id;
            event.key.scancode = sdl.SDL_SCANCODE_V;
            event.key.key = sdl.SDLK_V;
            event.key.mod = if (builtin.os.tag == .macos) sdl.SDL_KMOD_LGUI else sdl.SDL_KMOD_LCTRL;
        },
    }
    if (try editor.raw(event)) return error.NativeTextInterceptedForSimulation;
    return event;
}
