---
id: TASK-1.2
title: Implement HID scan code to platform keycode translation tables
status: Done
assignee: []
created_date: '2026-02-22 16:35'
updated_date: '2026-02-22 17:01'
labels: []
dependencies: []
references:
  - src/root.zig
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create compile-time lookup tables in `src/hid_to_platform.zig` that map `ScanCode` (USB HID page 0x07) values to each platform's native keycode space.

**Background:** All three target platforms use different keycode numbering:
- Linux evdev: mostly `hid_usage + 8`, but ~10 exceptions (e.g. KC_APPLICATION, KC_PAUSE, media keys)
- Windows Virtual Key codes: no arithmetic relationship; requires a full lookup table
- macOS Carbon virtual key codes: no arithmetic relationship; requires a full lookup table

**Required output:**
- `hidToEvdev(ScanCode) u16` — returns evdev code for Linux
- `hidToWinVk(ScanCode) u8` — returns Windows VK code
- `hidToMacVk(ScanCode) u16` — returns macOS Carbon virtual key code

All three can be `switch` expressions over the `ScanCode` enum with comptime-known values. Use 0xFFFF / 0xFF as the "unmapped" sentinel.

**Reference sources:**
- USB HID Usage Tables 1.21, Section 10 (Keyboard/Keypad Page)
- Linux kernel `drivers/hid/hid-input.c` for HID→evdev
- Windows SDK `winuser.h` for VK_ constants
- macOS `HIToolbox/Events.h` for `kVK_` constants
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 hidToEvdev maps all ScanCode entries in root.zig correctly
- [x] #2 hidToWinVk maps all printable and control ScanCode entries
- [x] #3 hidToMacVk maps all printable and control ScanCode entries
- [x] #4 Unmapped codes return a defined sentinel value (not undefined behavior)
- [x] #5 Functions are comptime-evaluable (pure switch on enum values)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created `src/hid_to_platform.zig` with three comptime switch functions: `hidToMacVk`, `hidToWinVk`, `hidToXkbKeycode`. All ScanCode variants from root.zig are covered. Unmapped codes return UNMAPPED_U16 (0xFFFF) or UNMAPPED_U8 (0xFF) sentinels. Functions are comptime-evaluable.
<!-- SECTION:FINAL_SUMMARY:END -->
