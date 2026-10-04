# 02 handover: LK7 firmware transport

State: **Accepted offline** at integrated revision `4fd4c66`.
Pure machinery `b1af5aa`; USB/LK7 implementation `6c83623`.
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

Coordinator accepted 02/03 at `4fd4c66`: root 325/325 tests, check/check-full,
all ten boards, standalone packages, portable Wasm checks and matching LK7 UF2
bytes passed. The joint processor/firmware/adapter test covers held attach,
backpressure, overflow recovery and disconnect/reconnect without hardware.
RP2040 ABI: Transport 732 bytes, Observer 40. UF2 95,232 bytes (baseline 71,168).
Artifact hash/identity and rollback are in the [worksheet](../04-manual-worksheet.md).
No hardware operation ran. Source ownership released to coordinator. Next is 04.

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

## USB and LK7 checkpoint

State: **Submitted for review**; worker paused and releases source for stable
coordinator checks. Input G01 `5b092ec`, pure transport `b1af5aa`.
Owned changes since pure checkpoint: `zigmkay/src/usb_control.zig` (new),
`usb_if.zig`, `core.zig`, `processing.zig`, `telemetry.zig`,
`telemetry_transport.zig`, `loops.zig`, `root.zig`,
`keyboards/my_keyboards/rollercole/leonardo_keycaprio_0_7.zig`,
`tests/test_telemetry_transport.zig`, `docs/firmware-telemetry.md`, this handover.
No `usb_command_executor.zig` change was needed: USB boundary suppresses its
legacy RawHID path whenever telemetry is attached. No protocol/cache/C edits.

First-party generic controller shim consumes validated vendor Output SetReport
setup and its exact EP0 OUT data stage, plus direct exact-length interrupt OUT.
RP2xxx hook resets vendor EP0 PID/buffers/stalls and stale EP0 completion flags;
other endpoint completions remain intact. Identity is the existing shared helper;
LK7 attaches it explicitly, all other board runners default telemetry off.
Reserved custom tap/hold IDs and companion special keycodes send sequenced v2
signals independently of keyboard queue capacity, after successful fallible
combined-action work. Existing Rollercole callback behavior/pins are unchanged.

Scoped command from the pure checkpoint was rerun after final changes:
**15/15 passed**. Additional fake-boundary tests cover validated control ACK only
after data, wrong direction/type/report ID/interface/length, cancelled setup,
short/overlength data, other collections, interrupt OUT, bus reset/deconfiguration,
full keyboard queue intents, custom+normal-key/modifier retry de-duplication.
Owned Zig files formatted. Coordinator selected `zig build firmware -Dkeyboard=lk7`
passed before final EP0 completion/intent refinements; this is WIP compile feedback,
not final integrated evidence. Worker ran no shared install/check lane or hardware.

Measured native aarch64 ABI: Transport 752 bytes, Observer 56, Gate one; fixed
report storage 608 bytes, two physical/stable snapshots 40 bytes, no allocation.
One request dispatch and one telemetry send attempt per runner iteration, plus
bounded USB-report validation. Driver true send acceptance synchronously copies
32 bytes to RP2xxx SRAM; false preserves exact bytes. Documentation records the
pinned HAL's preexisting readiness spin and keyboard/mouse/consumer acceptance
limitations. Real macOS SetReport/control PID behavior and typing remain 04 gates.

Final target RAM/firmware size, all-ten-board compilation, root/standalone parity,
check/check-full, shared integration tests and identified Danish LK7 UF2/hash are
pending coordinator stable-tree integration. No hardware acceptance claimed.
Next: review exact scoped diff, run joint stable checks, make focused local commits,
record artifacts/budgets and accept the offline handover if all criteria pass.
