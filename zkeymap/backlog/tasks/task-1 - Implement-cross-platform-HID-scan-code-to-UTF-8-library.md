---
id: TASK-1
title: Implement cross-platform HID scan code to UTF-8 library
status: Done
assignee: []
created_date: '2026-02-22 16:35'
updated_date: '2026-02-22 17:17'
labels:
  - library
  - cross-platform
  - keyboard
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a Zig library that converts USB HID scan codes (page 0x07) to UTF-8 characters by querying the active keymap on the user's OS.

The library must respect whatever keyboard layout the user has active (e.g. AZERTY, Dvorak, Japanese IME), not assume US-QWERTY.

**Architecture decisions (from planning session):**
- Follow the ScreenCapture.zig pattern: a `KeyMap` struct owns an `os` field selected via `switch (builtin.target.os.tag)`
- Each OS interface is an opaque type wrapping extern C/ObjC functions
- A `DummyKeyMap` handles unsupported platforms (returns `len=0`)
- `keyToText` requires a `KeyMap` context (stateless design is impossible — all platforms need a handle to the current layout)
- Dead key state (e.g. ´ + e → é) is tracked inside the context
- Layout refresh is caller-driven via a `refresh()` method

**Open questions resolved for implementation:**
- Dead keys: persist `deadKeyState` in context; emit composed output only
- Layout changes: expose `refresh()`, caller is responsible for calling it on OS notification
- Thread safety: single-threaded use (no mutex)
- `TextResult` capacity: 4 bytes covers all BMP; `len=0` signals no text produced (control keys, function keys, etc.)
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All subtasks complete. Cross-platform library ships:

- `src/root.zig` — public API: `KeyMap`, `ScanCode`, `Modifiers`, `InputEvent`, `TextResult`
- `src/KeyMap.zig` — cross-platform wrapper with `canProduceText()` filter
- `src/hid_to_platform.zig` — HID→macOS VK / Windows VK / xkbcommon keycode tables
- `src/platform/macos.{zig,c}` — Carbon UCKeyTranslate, dead-key state, PUA filter
- `src/platform/windows.{zig,c}` — Win32 ToUnicodeEx, dead-key flush/replay
- `src/platform/linux.{zig,c}` — xkbcommon, headless US fallback
- `src/platform/dummy.zig` — no-op for other platforms

`zig build test` — 8 tests pass on macOS  
`zig build ci` — compiles aarch64-linux, x86_64-linux, x86_64-windows from macOS host
<!-- SECTION:FINAL_SUMMARY:END -->
