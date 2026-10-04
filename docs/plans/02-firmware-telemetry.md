# 02: Nonblocking LK7 firmware telemetry

Status: planned. Depends on 01. Compile/test only until the joint hardware
session in 04.

Coordination: [tracker](TRACKING.md), [workflow](SUBAGENT-WORKFLOW.md), and
[02 handover](handovers/02-firmware.md). May run beside 03 after G01; use exclusive
firmware file leases and request shared build/identity edits from the coordinator.

## Outcome

LK7 attaches the observer to a bounded production transport and responds to the
session/snapshot contract over its dedicated vendor HID interface, while normal
keyboard, mouse, and consumer output continues independently.

## Inspect first

Read `zigmkay/src/loops.zig`, `processing.zig`, `telemetry.zig`, `usb_if.zig`,
`usb_command_executor.zig`, `generic_queue.zig`, the LK7 board entry point, and
`shared_keymap_3x5_2.zig`. Inspect the pinned MicroZig driver source for actual
send acceptance/readiness, report ownership/lifetime, output callbacks, and
polling behavior. Current wrappers discard `send_report` results; do not assume
that calling them guarantees transfer or permits dequeuing a telemetry report.

## Work

1. Add a bounded telemetry queue and lifecycle controller, separate from
   `core.OutputCommandQueue`. The observer's sink is nonblocking and cannot
   return transport errors into keyboard processing.
2. Track the authoritative physical pressed state continuously, including when
   there is no connected/subscribed companion. Use the existing once-per-input
   observation point or equivalent validated input tracking; retries must not
   duplicate presses/releases. Preserve stable post-processing layer/modifier
   observation and distinguish it from physical input state.
3. Attach this state/queue to LK7 runner configuration explicitly. Other boards
   should continue compiling with telemetry disabled/defaulted; do not add
   partially working native integrations to them in this milestone.
4. Receive and validate host control reports using the real descriptor/API.
   Reject wrong direction, unsupported requests, malformed lengths/fields, and
   incompatible identities without interrupting typing. No allocation or heavy
   processing in USB callbacks; schedule work in the normal polling loop.
5. Implement Hello, current-state snapshot, and recovery ordering exactly as 01
   specifies. Maintain a coherent snapshot boundary even when input changes
   while control responses are queued or the endpoint is busy.
6. Define priority and capacity for control/snapshot traffic versus telemetry
   deltas. A sustained event burst must not prevent recovery from completing.
   Document overflow behavior and sequence advancement; a failed enqueue must
   produce detectable loss and a reliable route back to current state.
7. Preserve queued bytes until the USB driver accepts them. Use bounded work per
   loop tick and bounded retry storage. Never sleep, spin-wait on HID readiness,
   allocate unbounded buffers, or block on an absent companion.
8. Decide the LK7 legacy-signal transition explicitly. Old RawHID signals and
   versioned telemetry must not be mixed on a live session and misdecoded.
   Preserve custom key behavior; route overlay control intents through the
   declared contract if required, rather than silently losing those actions.
9. Keep GPIO/scanner mappings and Rollercole's keymap actions intact. Publish
   board/profile identity through shared build metadata, not duplicate strings
   scattered through firmware and companion.
10. Record firmware size, queue/state RAM cost, scheduling budget, and known USB
    limitations. Treat defects found in ordinary typing as concrete blockers to
    04, with focused fixes rather than a speculative USB-stack rewrite.

## Acceptance

- Fake endpoint tests cover not-ready, accepted-send, disconnect, malformed OUT,
  sustained input bursts, full queue, and delayed snapshot/control delivery.
- Key/layer observation remains once-only across processor retries.
- A dropped event leads to resynchronization and accurate physical pressed state.
- Tests compare keyboard output with telemetry disabled, enabled, saturated, and
  disconnected. Backpressure must not alter intended keyboard actions or their
  queue processing order.
- Control floods consume bounded work/storage and never force a processor error.
- LK7 firmware and every other catalog entry compile on the existing MicroZig
  pin. Root/standalone LK7 UF2s match for the same configuration.
- `zig build check-full` passes without device access or source regeneration.

## Commit checkpoints and handoff

Commit pure queue/state machinery and overload tests; commit USB boundary and
control handling; commit LK7 integration and identity publication; then record
size/scheduling checks. Each commit is local and reviewable.

Provide the artifact path/hash and companion-compatible metadata for 03/04.
Do not run the flasher, request BOOTSEL, enumerate a live keyboard, change the
board's pins, or design keymap editing as part of this implementation task.

Incoming: accepted [01 contract](handovers/01-protocol.md). Outgoing: firmware
transport/budget/USB evidence and identified artifacts for 03/04. Acceptance is
offline; G-live-offline additionally needs accepted 03 and stable joint checks.
Actual device acceptance stays pending until the user-led 04 session.
