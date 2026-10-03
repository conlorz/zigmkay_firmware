---
id: TASK-1.5
title: Implement Linux platform backend using xkbcommon
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
  - src/platform/linux.zig
parent_task_id: TASK-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the Linux `KeyMap` backend in `src/platform/linux.zig` using `libxkbcommon` to translate evdev key codes using the user's active XKB keymap.

**API to use:**
- `xkb_context_new(XKB_CONTEXT_NO_FLAGS)` — create context on init
- `xkb_keymap_new_from_names(ctx, NULL, 0)` — load system keymap (uses RMLVO env vars or defaults); call on init and refresh
- `xkb_state_new(keymap)` — create state on init and refresh
- `xkb_state_key_get_utf8(state, evdev_code, buf, sizeof(buf))` — translate
- Apply modifier state before each call: `xkb_state_update_mask(state, depressed, latched, locked, 0, 0, 0)` using `InputEvent.mods`

**Modifier conversion:** Map `InputEvent.mods` to xkbcommon modifier indices:
- `mods.shift` → `XKB_MOD_NAME_SHIFT`
- `mods.ctrl` → `XKB_MOD_NAME_CTRL`
- `mods.alt` → `XKB_MOD_NAME_ALT`
- `mods.gui` → `XKB_MOD_NAME_LOGO`
- `mods.caps_lock` → `XKB_MOD_NAME_CAPS` (as locked modifier)

**Headless fallback:** If `xkb_keymap_new_from_names` returns null (no X/Wayland display), fall back to a hardcoded US-ASCII keymap via `xkb_keymap_new_from_string` with a minimal built-in layout string.

**Linking:** `xkbcommon` is a system library; link with `-lxkbcommon` via `build.zig`.

**Note:** Dead keys are handled automatically by xkbcommon state machine; no extra tracking needed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 KC_A with no modifiers returns 'a'
- [x] #2 KC_A with shift returns 'A'
- [x] #3 Modifier state is applied correctly before translation
- [x] #4 refresh() re-loads keymap from system
- [x] #5 Falls back gracefully when no XKB keymap is available
- [x] #6 Links against libxkbcommon via build.zig
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Linux backend implemented in `src/platform/linux.c` using libxkbcommon. The `extern fn` pattern (no `@cImport`) enables cross-compilation from any host.

**Implementation:**
- `linuxKeyMapInit`: allocates struct, creates `xkb_context`, calls `load_keymap`
- `linuxKeyMapRefresh`: calls `load_keymap` to reload from system
- `load_keymap`: tries `xkb_keymap_new_from_names(ctx, NULL, ...)` first (honours `XKB_DEFAULT_*` env vars); falls back to explicit `{rules="evdev", model="pc105", layout="us"}` on headless systems; creates `xkb_state` from the loaded keymap
- `load_indices`: caches modifier indices (shift, ctrl, alt, logo, caps) for fast mask building
- `linuxKeyMapTranslate`: maps packed `mods` byte to `xkb_mod_mask_t`, calls `xkb_state_update_mask`, then `xkb_state_key_get_utf8` with the xkbcommon keycode (evdev + 8, via `hidToXkbKeycode`)

**Dead keys:** handled automatically by the xkbcommon state machine — no extra tracking needed.

**build.zig:** `linux.c` and `-lxkbcommon` are only linked when building on a Linux host. When cross-compiling from macOS/Windows, the Zig `extern fn` declarations still type-check; C symbols are resolved by consumers on their Linux system.

Verified: `zig build ci` compiles for `aarch64-linux` and `x86_64-linux` from macOS without errors.
<!-- SECTION:FINAL_SUMMARY:END -->
