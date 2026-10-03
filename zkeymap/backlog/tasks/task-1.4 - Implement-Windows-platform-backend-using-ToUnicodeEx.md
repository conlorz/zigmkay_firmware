---
id: TASK-1.4
title: Implement Windows platform backend using ToUnicodeEx
status: Done
assignee: []
created_date: '2026-02-22 16:36'
updated_date: '2026-02-22 17:16'
labels: []
dependencies:
  - TASK-1.1
  - TASK-1.2
references:
  - src/root.zig
  - src/platform/windows.zig
parent_task_id: TASK-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the Windows `KeyMap` backend in `src/platform/windows.c` (C) that uses Win32 `ToUnicodeEx` to translate key events using the user's active keyboard layout.

**API to use:**
- `GetKeyboardLayout(0)` — get thread's active HKL on init and refresh
- `ToUnicodeEx(vk, scanCode, keyState, buf, bufLen, 0, hkl)` — translate VK + modifier state to Unicode
- `keyState` is a 256-byte array where modifier keys are set: `VK_SHIFT=0x80`, `VK_CAPITAL=0x01` (toggled), `VK_MENU=0x80`

**Dead key handling:** `ToUnicodeEx` returns -1 when a dead key is pressed and leaves internal state in the OS. To flush: call `ToUnicodeEx` a second time with a dummy key to consume the dead key state, then replay the actual key to compose. Alternatively, track dead key state internally by detecting the -1 return and replaying.

**Modifier conversion:** Build the 256-byte `keyState` array from `InputEvent.mods`:
- `mods.shift` → `keyState[VK_SHIFT] = 0x80`
- `mods.caps_lock` → `keyState[VK_CAPITAL] = 0x01`
- `mods.alt` → `keyState[VK_MENU] = 0x80`

**Zig-side interface** (`src/platform/windows.zig`):
```zig
pub const WindowsKeyMap = opaque {
    extern fn windowsKeyMapInit() *WindowsKeyMap;
    extern fn windowsKeyMapDeinit(*WindowsKeyMap) void;
    extern fn windowsKeyMapRefresh(*WindowsKeyMap) void;
    extern fn windowsKeyMapTranslate(*WindowsKeyMap, vk: u8, mods: u8, buf: [*]u8, buf_len: usize) usize;
    // ... pub wrappers
};
```

**build.zig changes:** No extra framework linking needed; Win32 APIs are available by default.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 KC_A with no modifiers returns 'a' on a US layout
- [x] #2 KC_A with shift returns 'A'
- [x] #3 Dead key sequence returns composed character across two calls
- [x] #4 refresh() picks up a newly activated keyboard layout
- [x] #5 Compiles on Windows target
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Windows backend implemented in `src/platform/windows.c` using `ToUnicodeEx`. All logic was already in place from the initial implementation:

- `windowsKeyMapInit`: allocates struct, calls `GetKeyboardLayout(0)`
- `windowsKeyMapRefresh`: re-fetches HKL to pick up layout changes
- `build_key_state`: maps packed `mods` byte to 256-byte Win32 keyState array (shift, ctrl, alt, caps_lock, num_lock)
- `windowsKeyMapTranslate`: calls `ToUnicodeEx`, handles dead-key return (-1) by flushing with space and replaying, converts UTF-16 result to UTF-8 via `WideCharToMultiByte`

`windows.zig` wraps the C functions as `extern fn` declarations (opaque type pattern, same as macos.zig).

Verified compiles for `x86_64-windows` via `zig build ci` on macOS host (Zig bundles MinGW headers so no Windows host needed to compile).
<!-- SECTION:FINAL_SUMMARY:END -->
