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
