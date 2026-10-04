# 02 handover: LK7 firmware transport

State: **Not produced**. No implementation commits or checks are recorded.
Producer: firmware worker. Reviewer: coordinator.
Plan: [02](../02-firmware-telemetry.md). Rules: [handover format](README.md).

## Required input and output

Input: accepted [01 contract](01-protocol.md), existing LK7 wiring/keymap, and
the actual pinned MicroZig send/receive semantics.

Publish telemetry/control entry points, queue and RAM/loop budgets, authoritative
physical-state tracking, overflow/recovery behavior, USB acceptance/lifetime
rules, legacy-signal transition, and shared identity publication requirements.
Record saturation/disconnect/typing-regression tests, all-board compilation,
root/standalone parity, and coordinator integrated `check-full` evidence.

Supply identified LK7 UF2/build metadata for the Danish profile and concrete
matching companion requirements. Hardware rows are **pending**, not passed.

## Consumers and gate

- [03 overlay](../03-macos-live-overlay.md): consumes actual firmware identity,
  supported transport/control behavior, and any documented limitations.
- [04 hardware](../04-lk7-hardware-acceptance.md): consumes firmware artifacts,
  rollback/recovery preparation, expected reports, and regression evidence.
- [09 expansion](../09-platform-and-board-expansion.md): reuses transport design
  later without claiming other boards have live support.

Acceptance completes 02's offline criteria. Together with accepted 03 and a
stable joint build, it releases **G-live-offline**. Coordinator retains shared
build/identity ownership; firmware source lease is released at the checkpoint.

## Integrated result

Pending. Complete the [result template](README.md) at submission/integration.

## Pure transport checkpoint

State: **Submitted for review**; worker paused before USB/LK7 integration.
Accepted input G01 `5b092ec`, dispatch `8a1c9a8`. No protocol amendment.
Changed owned paths: `zigmkay/src/telemetry.zig`, `telemetry_transport.zig`,
`processing.zig`, `root.zig`, `tests/test_telemetry_transport.zig`,
`docs/firmware-telemetry.md`, this handover. Root test-loop build glue belongs to
coordinator and is required for integrated checks.

Fixed-storage controller separates physical state, response priority, deltas and
recovery; sequence advances on attempted events; endpoint false preserves bytes.
Bounded mailbox processing runs at a coherent processor boundary. Observer tracks
physical/stable state continuously with no sink. Saturation cannot fail keyboard
processing. Budgets and ordering are in [firmware telemetry](../../firmware-telemetry.md).

Scoped Zig 0.16.0 command (all imports explicit, no installation/hardware):

```text
/Users/clorz/.zvm/0.16.0/zig test --dep zigmkay --dep lk7-keymap --dep device-protocol -Mroot=tests/test_telemetry_transport.zig --dep layout-model --dep device-protocol -Mzigmkay=zigmkay/src/root.zig --dep layout-model --dep zigmkay --dep zkeycodes -Mlk7-keymap=keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig --dep layout-model -Mdevice-protocol=device-protocol/src/root.zig -Mlayout-model=layout-model/src/root.zig --dep layout-model --dep keycode-helpers --dep base-keycodes -Mzkeycodes=zkeycodes/root.zig --dep layout-model -Mkeycode-helpers=zkeycodes/src/core.zig --dep layout-model --dep keycode-helpers -Mbase-keycodes=zkeycodes/keycodes/keycodes.zig
```

Result: **8/8 passed**. Covered fake acceptance/backpressure, malformed direction
and lengths, wrong sessions, bounded control floods, delayed snapshot overflow,
physical held state/disconnect, sequence wrap/signals and real LK7 typing parity
in disabled/enabled/saturated/disconnected modes. Owned Zig files formatted.
USB exact-length reception, macOS ep0 SetReport wrapper, LK7 attachment, reserved
legacy-signal transition, target size/all-board compilation/parity/check-full and
identified artifacts remain pending. Worker made no Git/index/hardware operations.
Next: coordinator review/commit pure checkpoint, then release USB integration.
