---
id: TASK-1.1
title: Redesign root.zig interface to add KeyMap context struct
status: Done
assignee: []
created_date: '2026-02-22 16:35'
updated_date: '2026-02-22 17:01'
labels: []
dependencies: []
references:
  - src/root.zig
  - example/ScreenCapture.zig
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update `src/root.zig` to replace the stateless `keyToText(InputEvent)` with a context-based `KeyMap` struct, following the same pattern as `example/ScreenCapture.zig`.

**Current state:** `src/root.zig` has a stub `keyToText` that takes an `InputEvent` and returns an empty `TextResult`. `ScanCode`, `Modifiers`, `InputEvent`, and `TextResult` are already defined.

**Required changes:**
1. Add `KeyMap` struct with an `os` field switching on `builtin.target.os.tag` (macos / windows / linux / else→dummy)
2. Add `init`, `deinit`, `refresh`, and `keyToText` methods on `KeyMap`
3. Remove the top-level `keyToText` free function
4. Import platform modules for each OS (they may be stubs initially)

**File layout to establish:**
```
src/
  root.zig             ← this task
  KeyMap.zig           ← the struct impl (can be @import'd by root)
  platform/
    macos.zig          ← stub
    windows.zig        ← stub
    linux.zig          ← stub
    dummy.zig          ← stub returning len=0
```

**Reference:** `example/ScreenCapture.zig` shows the exact pattern to follow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 KeyMap struct exists in public API with init, deinit, refresh, and keyToText methods
- [x] #2 os field uses comptime switch on builtin.target.os.tag
- [x] #3 Top-level free function keyToText is removed
- [x] #4 Library compiles on all platforms (stub platform modules are sufficient for now)
- [x] #5 DummyKeyMap returns TextResult with len=0 for all inputs
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented KeyMap context struct in `src/KeyMap.zig` following the ScreenCapture.zig pattern. Removed the stateless free function from root.zig. Added `canProduceText()` helper that filters navigation/function keys before calling the platform backend. All platform types are opaque with pointer fields; DummyKeyMap uses undefined pointer with no-op methods.
<!-- SECTION:FINAL_SUMMARY:END -->
