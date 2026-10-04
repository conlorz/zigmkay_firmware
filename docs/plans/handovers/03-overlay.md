# 03 handover: macOS live overlay

State: **Not produced**. No implementation commits or checks are recorded.
Producer: companion worker. Reviewer: coordinator.
Plan: [03](../03-macos-live-overlay.md). Rules: [handover format](README.md).

## Required input and output

Input: accepted [01 contract](01-protocol.md), shared physical geometry, and
[02 firmware metadata](02-firmware.md) for final joint integration. The worker
may implement fake-backed behavior before 02 is complete.

Publish HID adapter selection/error/report framing, session/reconnect behavior,
bounded report draining, physical-ID rendering, label/input-source refresh,
compact-window settings, and supported macOS fallback limitations. Provide
actual GUI/offline replay/smoke commands and fake adapter/render/label evidence.
Document explicit recording and manual-test instructions for 04.

## Consumers and gate

- [04 hardware](../04-lk7-hardware-acceptance.md): uses the integrated GUI/firmware
  revision and checks real attach/recovery, labels, geometry, and window behavior.
- [06 research](../06-editor-architecture-research.md): audits actual native UI
  capabilities and remaining constraints rather than assumed functionality.
- [07 editor](../07-compiled-keymap-editor.md): later reuses rendering/UI lifecycle.

Acceptance completes 03's offline criteria. With accepted 02 and joint checks,
it releases **G-live-offline**. Real device/window behavior remains pending 04.
Release companion ownership before profile/editor integration changes its files.

## Integrated result

Pending. Complete the [result template](README.md) at submission/integration.

## Portable adapter checkpoint

State: Submitted; worker paused before native/UI integration. Input G01
`5b092ec`; dispatch `8a1c9a8`. Changed paths at this checkpoint:
`zigmkay-companion/src/live_adapter.zig` and this handover. No frozen contract
edits, hardware operations, Git/index operations or new languages.

The portable generic `Driver(Transport)` owns Session, fresh-token allocation,
UI-thread action execution, reconnect status, bounded signal intents, and native
report normalization. Injected transport methods are `discover`, nonblocking
`read`, `write`, `close`, and monotonic `now`. Discovery selects only exact
FAFA:00F0 / FF31:0074 collections; ambiguous matches require an explicit path.
Native writes are 33 bytes with zero report ID. Reads accept exactly 32 bytes or
33 with zero prefix. Invalid lengths become malformed Session receives and
recovery, transport failure disconnects retaining explicitly stale state. Drain
limits are 32 reports and 2 ms per poll; reconnect discovery retries after 1 s.
Nonce counter skips zero and refuses exhaustion instead of reusing tokens; native
OS-random seeding is still the next checkpoint's responsibility.

Scoped Zig 0.16.0 command, run from canonical monorepo:

```sh
/Users/clorz/.zvm/0.16.0/zig test --dep device-protocol --dep companion-model --dep layout-model -Mroot=zigmkay-companion/src/live_adapter.zig --dep layout-model -Mdevice-protocol=device-protocol/src/root.zig --dep layout-model --dep device-protocol -Mcompanion-model=companion-model/src/root.zig -Mlayout-model=layout-model/src/root.zig
```

Six tests passed: deterministic collection/path selection; exact report-ID
framing; held attach/unplug/fresh negotiation; no device/identity mismatch/
malformed recovery/bounded draining; sequence gap/interrupted recovery/final
successful reconnect/silent restart timeout; ambiguity and nonce exhaustion.
`zig fmt` completed. Tests import no SDL and cannot enumerate hardware.

Limits: this is a portable checkpoint, not a GUI/native acceptance. Native SDL
adapter, command selection, physical rendering, label refresh, compact-window
settings and explicit timed capture/replay remain pending. Existing strict v1
replay and offline smoke sources are untouched. No recording command exists yet.
Coordinator must integrate this file into GUI test discovery before final checks.
Worker stops editing until coordinator review/commit and lease release.

## Native/UI/capture checkpoint

State: Submitted; worker paused. Portable checkpoint accepted/committed `241beaa`.
Frozen input remains G01 `5b092ec`; coordinator-owned build/geometry imports and
`zkeymap.hid_to_platform` publication are integration prerequisites in the working
tree. Final 02/03 joint gate and stable check/check-full remain coordinator work.

Changed leased paths since that commit:

- `zigmkay-companion/src/main.zig`, `lk7_keymap.zig`, `live_adapter.zig`;
- new `zigmkay-companion/src/input_source.zig`, `session_capture.zig`;
- `zigmkay-companion/src/components/layout.zig`, `cache.zig`, `key.zig`, `log.zig`;
- new `docs/live-overlay.md`; this handover.

Implemented native SDL transport only behind explicit `--live`, exact path
selection, visible diagnostics/mismatch/stale state, reconnect control, shared
stable physical rendering, compact/resizable configurable window, direct Zig
stateless Carbon labels/source refresh, bounded opt-in timed capture and offline
replay/control verification. Native C bridges and protocol/model are unchanged.
The log now reuses cached labels and includes a first event at key index zero.
Capture is bounded to 4096 records/196616 bytes and at most five minutes, default
30 s; stopping capacity/closing/timeout saves once. Commands and manual limits are
published in [the overlay guide](../../live-overlay.md).

Scoped checks using `/Users/clorz/.zvm/0.16.0/zig`, from companion directory:

```sh
zig build test --summary all
zig build run -- --smoke
zig build run -- --smoke --replay ../tests/fixtures/lk7_trace.bin
zig build run -- --smoke --session-replay .zig-cache/lk7-overlay-timed-fixture.bin
```

All succeeded: **32/32 component tests**, and each actual GUI smoke opened the
760×370 window, rendered three frames and exited. Timed fixture was generated by
a hardware-free Zig test into the build cache and retains a held key in a live
terminal reducer state. Additional fake evidence covers the 2 ms drain budget,
recorded attach/disconnect state equivalence, timed retries/fresh nonce controls,
size cap, stable thumbs/resized bounds/non-square rotated fitting, fixed/Shift/
Option/Command/dead fixtures and label cache replacement. `zig fmt` completed.
These are working-tree scoped checks with coordinator build/publication glue,
not evidence attributed to a partial code commit. No HID method was executed.

Remaining manual checks: actual vendor discovery and 32/33-byte reads/SetReport,
identity/held-key/restart/unplug behavior, Danish/EurKEY Next labels/source switch,
physical geometry and window opacity/topmost/focus/Space behavior. Click-through
has an explicit unsupported fallback; no unapproved glue. Native SDL writes are
synchronous OS USB calls, so the 2 ms read budget cannot promise bounded write
latency. Windows/Linux source-change detection remains deferred. Capture reproduces
portable session timing/control/state, not native scheduling or labels. Existing
headless --session remains deterministic device-only replay unchanged.

Worker stops all editing for review. Coordinator owns final integration, focused
local commits and gate acceptance. No Git/index operations or hardware access.
