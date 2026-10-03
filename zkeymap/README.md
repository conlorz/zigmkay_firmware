# zkeymap

Converts USB HID scan codes to UTF-8 using the active OS keyboard layout. Handles dead keys, modifiers, and Caps Lock like typing into a text field.

## Platforms

| Platform | Backend | Status |
|----------|---------|--------|
| macOS | Carbon TIS + `UCKeyTranslate` | done |
| Windows | `ToUnicodeEx` | done |
| Linux | xkbcommon | done |
| Other | no-op | — |

Linux: install and link `libxkbcommon` on build host and target. **Zig 0.15.2+**.

## Installation

```bash
zig fetch --save git+https://codeberg.org/BSF/zkeymap.git
```

`build.zig`:

```zig
const zkeymap_dep = b.dependency("zkeymap", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zkeymap", zkeymap_dep.module("zkeymap"));
if (target.result.os.tag == .linux) exe.root_module.linkSystemLibrary("xkbcommon", .{});
```

## Example

```zig
const std = @import("std");
const zkeymap = @import("zkeymap");

pub fn main() !void {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const events: []const zkeymap.KeyCodeFire = &.{
        .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_H), .tap_modifiers = .{ .left_shift = true } },
        .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_F1) },
        .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_I) },
        .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_1), .tap_modifiers = .{ .left_shift = true } },
    };

    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    for (events) |ev| {
        const text = km.keyToText(ev);
        if (text.isLabel()) {
            std.log.debug("label key: {s}", .{text.getLabel()});
        } else if (text.len > 0) {
            try fbs.writer().writeAll(text.slice());
        }
    }
    std.debug.print("{s}\n", .{fbs.getWritten()}); // "Hi!" (US QWERTY)
}
```

Output:
```
debug: label key: F1
Hi!
```

Call `km.refresh()` when the user switches OS input method.

## API

**KeyMap** — `init(km)`, `deinit(km)`, `refresh(km)`, `keyToText(km, input)`. One instance per keyboard context.

**KeyCodeFire** — `tap_keycode: u8`, `tap_modifiers: ?Modifiers`, `dead: bool`. `tap_keycode` is the HID scancode value. `tap_modifiers` uses left/right split modifiers.

**Modifiers** — `left_ctrl`, `left_shift`, `left_alt`, `left_gui`, `right_ctrl`, `right_shift`, `right_alt`, `right_gui` (packed struct, 8 bits total). Use `toPlatformMods()` to convert to platform 8-bit format.

**TextResult** — `data: [4]u8`, `len: u8`. Three cases:
- `isLabel() == true` — named key (F1–F24, arrows, ESC, TAB, BACKSPACE, ENTER, …). Call `.getLabel()` for the string (e.g. `"BACKSPACE"`). `slice()` returns `""`.
- `len > 0` — layout-translated text. Call `.slice()` for `[]const u8`.
- `len == 0`, not a label — dead-key first press; no output yet.

**ScanCode** — USB HID page-0x07 enum: `KC_A`…`KC_Z`, `KC_F1`…`KC_F24`, `KC_ENTER`, etc. Full list in [`src/root.zig`](src/root.zig). Convert to HID value with `@intFromEnum(ScanCode.KC_XXX)`.

## Behaviour

- **Label result** — F-keys, arrows, Home/End/PgUp/PgDn, Insert, Delete, Caps/Num/Scroll Lock, Print Screen, Pause, Application, Power, Escape, Tab, Enter, Backspace. `isLabel()` returns `true`; use `getLabel()` for the name string.
- **Dead keys** — first press → `len == 0`, not a label (OS accumulates state); second press → composed char (e.g. `^` then `e` → `ê`).
- **Shift + letter** — produces uppercase output.

## Tests

```sh
zig build test
```

Tests in [`src/root.zig`](src/root.zig), [`src/KeyMap.zig`](src/KeyMap.zig), and [`example/main.zig`](example/main.zig); assume US QWERTY. Coverage: `TextResult.slice`/`isLabel`/`getLabel`, basic text, modifiers, label keys, dead keys, numpad, `refresh`.

## License

MIT — see [LICENSE](LICENSE).
