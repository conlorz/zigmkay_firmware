# 03: Small, resilient macOS live overlay

Status: planned. Depends on 01; end-to-end integration also requires 02.
Hardware behavior is accepted in 04, not by offline tests alone.

Coordination: [tracker](TRACKING.md), [workflow](SUBAGENT-WORKFLOW.md), and
[03 handover](handovers/03-overlay.md). May run beside 02 after G01 using fake
transport; real firmware integration consumes 02's accepted artifact/metadata.

## Outcome

A small LK7 keyboard overlay that highlights physical keys and shows the current
layer/modifiers, connects to compatible firmware, and recovers without exiting
or leaving stale highlights after packet loss or disconnection.

## Inspect first

Read `zigmkay-companion/src/main.zig`, `src/lk7_keymap.zig`, and component
layout/cache/log/key code. Read `companion-model`, `layout-model` geometry,
`keyboards/my_keyboards/rollercole/lk7_physical_layout.zig`, the shared keymap,
`zkeymap` native mapping, and the DVUI/SDL3 APIs from pinned package sources.

The present live path opens the first matching device, reads one report per
frame, and exits on connection/protocol errors. The display geometry is derived
from side tags. These are known starting limitations.

## Work

1. Separate native HID operations from the portable session model using a small
   adapter interface with a fake implementation for tests. Keep the existing
   SDL3 transport initially; introduce no new C/Objective-C glue without user
   permission. Capture actual API error/report-ID semantics in the adapter.
2. Select only the vendor telemetry collection (usage page 0xFF31, usage 0x0074)
   of the composite LK7 device. VID/PID alone are insufficient. Handle multiple
   matching devices deterministically; support explicit selection and expose
   identities rather than opening an arbitrary candidate silently.
3. Implement negotiation and identity comparison before rendering live labels.
   If board/profile/dimensions/version are incompatible, show an actionable
   status and do not claim that the displayed keymap matches the device.
4. Obtain the initial snapshot and drive 01's recovery/session transitions.
   Reconnect after unplug/replug and firmware restart. Clear or visibly mark
   stale pressed keys on disconnect; do not silently freeze a live-looking view.
5. Drain pending reports with a bounded batch/time budget, rather than one report
   every frame. Prevent starvation of UI work. Keep reducer/UI mutation on the
   UI thread or use a bounded transfer queue with explicit ownership if a worker
   proves necessary. Do not recreate unsynchronized shared globals.
6. Render existing physical-layout keys by stable ID/key_index, x/y, size, and
   rotation. Treat processing sides as behavior metadata. Remove LK7's legacy
   side-derived geometry as the authoritative display source and scale to the
   actual window bounds rather than a hardcoded center.
7. Make the default presentation a compact overlay. Implement supported DVUI/SDL
   window flags and configuration for positioning, opacity, always-on-top, and
   focus/click-through behavior. Verify real macOS behavior during 04; where the
   pinned APIs cannot provide a requested behavior, document the limitation and
   keep an explicit supported fallback instead of adding unapproved glue.
8. Keep connection/status controls discreet and an event log available for
   debugging. Preserve an accessible way to move/configure/close the overlay.
   Do not turn this milestone into the editor or a large configuration window.
9. Correctly separate physical press highlights, active firmware modifiers, HID
   keycodes, and OS-translated labels. Refresh labels on macOS input-source
   change; avoid changing native dead-key composition state while building a
   label cache. Fixed labels do not depend on OS layout. Show the profile/input
   source so Danish/EurKEY Next symbol mismatches are explainable during testing.
10. Preserve offline replay and smoke modes. Add session-aware recording/replay
    through the same decoder/reducer so live failures can be reproduced offline.
    Bound capture size and make recording explicit; do not record background
    typing outside the requested test session.

## Acceptance

- Fake adapter scenarios cover no device, multiple devices, mismatch, attach,
  held keys at attach, sequence loss, invalid report, disconnect during recovery,
  restart, and successful reconnection with correct final state.
- Render tests compare stable physical IDs/index mapping, thumbs, layer changes,
  and resized/scaled bounds against the shared LK7 geometry.
- Label tests cover fixed labels, Shift/Option/Command, dead-key labeling, and
  input-source cache refresh with deterministic fixtures; native translation
  assumptions remain documented rather than silently depending on a US host.
- Offline/session replay and three-frame smoke mode pass without HID discovery.
- Automatic tests do not call real enumeration/open/read methods. `zig build
  check` passes; build API changes also pass `check-full`.

## Commit checkpoints and handoff

Commit transport/session separation and fake adapter tests; commit reconnect and
identity handling; commit shared physical geometry; commit compact overlay and
label refresh; then record offline validation and outstanding macOS behaviors.

Handoff provides concrete firmware/GUI commands, displayed states, selection
rules, recording procedure, and the remaining manual checks for 04. Windows,
Linux, editor UI, browser support, and automatic flashing remain later work.

Incoming: accepted [01 contract](handovers/01-protocol.md); shared geometry;
[02 metadata](handovers/02-firmware.md) for joint integration. Outgoing: actual
GUI/replay commands, adapter/label/render evidence, and manual checks for 04;
native UI constraints also inform 06/07. Release GUI leases before later changes.
