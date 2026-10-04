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
