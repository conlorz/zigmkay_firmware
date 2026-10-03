---
id: TASK-1.3
title: Implement macOS platform backend using UCKeyTranslate
status: Done
assignee: []
created_date: '2026-02-22 16:35'
updated_date: '2026-02-22 17:01'
labels: []
dependencies:
  - TASK-1.1
  - TASK-1.2
references:
  - src/root.zig
  - example/ScreenCapture.zig
  - src/platform/macos.zig
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the macOS `KeyMap` backend in `src/platform/macos.m` (Objective-C/C) that uses the Carbon Text Input Services API to translate key events using the user's active keyboard layout.

**API to use:**
- `TISCopyCurrentKeyboardInputSource()` — get the active input source (call on init and refresh)
- `TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)` — get layout data
- `UCKeyTranslate(layout, vkCode, kUCKeyActionDown, modifiers, keyboardType, 0, &deadKeyState, maxLen, &len, buf)` — translate
- `LMGetKbdType()` — get keyboard type for UCKeyTranslate

**Dead key handling:** Store a `UInt32 deadKeyState` in the context struct. Pass it on every call. `UCKeyTranslate` will update it atomically. When a dead key is pressed, `len=0` is returned and `deadKeyState` is non-zero. The next key press will emit the composed character.

**Modifier conversion:** `InputEvent.mods` (Zig `Modifiers` packed struct) → Carbon modifier flags (`shiftKey`, `alphaLock`, `optionKey`) for `UCKeyTranslate`. Note: UCKeyTranslate only cares about shift, caps lock, and option/alt for character selection.

**Zig-side interface** (in `src/platform/macos.zig`):
```zig
pub const MacOsKeyMap = opaque {
    extern fn macOsKeyMapInit() *MacOsKeyMap;
    extern fn macOsKeyMapDeinit(*MacOsKeyMap) void;
    extern fn macOsKeyMapRefresh(*MacOsKeyMap) void;
    extern fn macOsKeyMapTranslate(*MacOsKeyMap, vk: u16, mods: u8, buf: [*]u8, buf_len: usize) usize;
    pub fn init() *MacOsKeyMap { ... }
    pub fn deinit(km: *MacOsKeyMap) void { ... }
    pub fn refresh(km: *MacOsKeyMap) void { ... }
    pub fn keyToText(km: *MacOsKeyMap, input: InputEvent) TextResult { ... }
};
```

**build.zig changes:** Link `Carbon.framework` on macOS; compile the `.m` file with `addCSourceFile`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 KC_A with no modifiers returns 'a' on a US layout
- [x] #2 KC_A with shift returns 'A'
- [x] #3 KC_A with option returns the correct option-key character for the active layout
- [x] #4 Dead key sequence (e.g. option+e then e) returns 'é' across two calls
- [x] #5 refresh() picks up a newly activated keyboard layout without restart
- [x] #6 Compiles and links against Carbon.framework via build.zig
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented `src/platform/macos.c` using TISCopyCurrentKeyboardInputSource + UCKeyTranslate. Dead key state tracked in the C struct. UTF-16→UTF-8 conversion done with a manual encoder. Modifier bits decoded from the packed u8 sent by Zig. `macos.zig` holds the extern declarations and calls `hidToMacVk` before dispatching. Navigation/function keys are pre-filtered by `canProduceText()` in KeyMap.zig before reaching the C layer. All 8 unit tests pass on macOS.
<!-- SECTION:FINAL_SUMMARY:END -->
