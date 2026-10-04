# Recovery handoff for a fresh session

State: **Research accepted; offline R3 integrated; bounded hardware session
run with explicit authorization; configuration/HID and reconnect input succeeded;
controlled modifier/release checks passed; R-keyboard accepted on macOS.** Current implementation
`2e30e9d`, with full offline checks passing. See
[research decision](../../research/usb-hid-decision.md) and
[identified diagnostic session](../../research/usb-hid-diagnostic-session.md).

## Recovery execution, 2026-10-04

- Started clean at `f953373`, canonical branch `local/monorepo`, Zig 0.16.0.
- Three scoped research workers delivered primary-source specification,
  platform and RP2040 evidence; all leases released, no worker remains active.
- `2972bc6` records research and design. The target probe through the actual
  pinned controller proved runtime endpoint/size corruption, independently of
  the repaired host descriptor stream.
- `c9ea3a1` materializes persistent driver descriptors from explicit wire bytes.
  Real pinned HID initialization host test and Cortex-M0+ inspection cover it.
- `2e30e9d` implements standard/HID request validation, EP0 status/ZLP/cancel,
  address/reset/configuration lifecycle, eight-byte boot keyboard, relative mouse,
  LED state, halt/alternate zero behavior, bounded RP2040 buffer ownership and
  nonblocking ordered keyboard/secondary reports. Review findings and limits are
  recorded in the decision. Vendor v2/shared identity remain unchanged.
- `mise //:check-full` passed on the complete code tree: ten board builds,
  actual emitted descriptor/report parsing, parity and no-hardware/source guards.
- User reports Mac only, no SWD or USB analyzer. The session document identifies
  the candidate/rollback hashes, questions, capture route, limits and stop criteria.
  One authorized candidate flash completed in 3.88 seconds; macOS selected
  configuration 1 and attached all four HID drivers. Apple parsed the eight-byte
  keyboard input. User reports typing after one reconnect; controlled modifier/
  release and LED observations remain pending. See the session evidence.
- R-HID-design accepted offline; R-keyboard pending. R-custom and R-flash are
  gated on observed keyboard acceptance. Do not resume original 05–09.
- Important limits: no known-working rollback binary; B0/B1 abort fails closed;
  no USB diagnostic retrieval after a hard hang or boundary fault; Mac diagnostic
  string freshness unverified. Full tests do not prove live compatibility.

User confirmed all position-based input/modifier/release checks passed. Caps Lock
is not bound; LED state and Windows/Linux remain unverified. User also confirms
BOOTSEL 0+4 and successful `mise run //:flash lk7` with automatic keyboard
reconnect. Current output hash matches the diagnostic candidate; this is not
cryptographic running-device readback.

R4 inventory/contract is in `usb-hid-custom-contract.md`. `91cbdd5` adds agreed
both-thumbs controls 19/24/29 and preserves F12 at 20. Full offline checks pass.
The custom candidate flashed/configured successfully in 4.10 seconds. First live
GUI failed before handshake: SDL defaults HID enumeration to game controllers.
`bceadb0` disables that filter in live mode and logs discovery/open. Host-only
retry discovers and opens the exact vendor collection; full checks pass again.
`40e0afc` preserves valid state during healthy periodic refresh; `78d7443` fixes
full-capacity capture replay. User confirms stable live status, agreed controls
and typing. R-custom accepted on macOS; R5 now active. Existing gaming layer 4
is undefined and remains outside the validated controls. Next: finish bounded
flash discovery, failure handling and safe running verification.
Do not repeat the diagnostic flash.
Continue R4 and then R5 only after their entry gates. Never infer a hardware pass.

## Historical state before recovery execution

User stopped the
hardware retry loop on 2026-10-04 and requested a top-down research-led approach.
Direct next task: [plan 11](../11-usb-hid-recovery.md). Original later milestone
execution is paused by user direction. This file preserves evidence, not a pass.

## Starting state

- Canonical checkout `/Users/clorz/Documents/zigmkay/zigmkay_firmware`, branch
  `local/monorepo`, implementation HEAD `637fd71` before this planning commit.
  Recheck actual HEAD/status. Changes are locally committed; never push or PR.
- Zig 0.16.0; pinned MicroZig
  `00fde43fa3756790037b099baeafacc3e6bf9499`. Root mise tasks are implemented.
- Full offline checks passed for `637fd71`. No real typing acceptance exists.
- Firmware currently flashed by the agent: `637fd71` LK7/Danish,
  `zig-out/firmware/lk7/zigmkay.uf2`, 93,184 bytes, SHA-256
  `eee031c891b592740ddab62ee948728e329ecc7c2572eef184c33211de3caeb0`.
  Device re-enumerates as ZigMkay but has no configured HID interfaces.
- Last flash completed through `mise //:flash lk7` in about three seconds.
  No flash process remains from that run. Do not assume the device's state is
  unchanged when the new session starts. This plan does not initiate hardware.

## Observed results and limits

1. Original UF2s lacked RP2040 family metadata. `2089219` fixed generation and
   added input validation. The boot ROM had ignored the original invalid files.
2. Filesystem transfer initially stalled in `openat` on macOS's FSKit FAT mount;
   separate directory access/unmount also stalled. Physical reconnect cleared
   that state. AccessDenied occurred separately and was not conclusively traced.
3. Corrected UF2 transfer/write/sync and automatic firmware restart now work.
   macOS displays “Disk Not Ejected Properly” for RPI-RP2. This notification does
   not explain the subsequent keyboard failure by itself.
4. macOS logs show configuration 1 selection followed by repeated EP0 timeouts,
   status `0xe00002d6`, zero bytes. IORegistry has the USB product and a failed
   composite driver attachment, but no HID interface children.
5. Brave opened the device after composite attachment failed. Quitting Brave
   and reconnecting did not restore typing. In later logs Brave initially failed
   to obtain exclusive access because the composite driver owned the device.
   Browser ownership is not an established root cause.
6. Preserved source baseline `ab66f12`, compiled with the current toolchain and
   with only UF2 family headers repaired, also timed out at configuration.
   This is not the historical working Windows binary; do not treat it as one.
7. `4688fe1` added descriptor OUT status arming and SETUP cancellation;
   `43a5ff7` added GetConfiguration. Each passed offline checks but neither
   restored live HID configuration. Audit their necessity and correctness.
8. Apple's `usbdiagnose -h` actually runs a diagnostic, taking several seconds;
   it is not merely help output. Its first dump reported a zero-length illegal
   descriptor and padding within the 146-byte configuration. A minimal Zig
   Cortex-M0+ object reproduced nested aggregate padding despite logical sizes.
9. `637fd71` serializes configuration/HID descriptors at compile time. Target
   object and actual UF2 inspection show contiguous bytes. The latest live USB
   diagnostic confirms all 146 bytes parse: five interfaces, eight interrupt
   endpoints, four HID descriptors, reset interface. No illegal descriptor is
   reported. **Configuration still times out and current configuration cannot
   be read; no HID interfaces attach.** This is progress, not a solved keyboard.
10. Host logs alone do not identify the timed-out request number or whether the
    device panics/hangs during endpoint initialization. That must be established
    with researched diagnostics. Do not choose the next fix by another guess.

## Relevant source and evidence

- `zigmkay/src/usb_if.zig`: interface/report definitions, controller construction,
  wire descriptor generation, RP2040 EP0 hooks, polling and report submission.
- `zigmkay/src/usb_control.zig`: first-party controller wrapper and candidates.
- `zigmkay/src/usb_descriptor_bytes.zig`: compile-time field serialization.
- `zigmkay/src/loops.zig`, `usb_command_executor.zig`,
  `telemetry_transport.zig`: initialization/order and typing/telemetry behavior.
- `tests/test_telemetry_transport.zig` and
  `zigmkay/tests/test_usb_descriptor_bytes.zig`: offline regressions; audit their
  limits, especially fake-only control/driver behavior and target runtime paths.
- `keyboards/build_api.zig`: firmware generation/UF2 family selection.
- `zig-flash/src/main.zig`, `uf2.zig`: discovery/transfer/input validation.
- [04 evidence](04-hardware.md) and [worksheet](../04-manual-worksheet.md).
  Earlier pending-retry wording is superseded by the latest result above.
- Cached Zig probes: `.zig-cache/usb-layout-probe*.zig`, corresponding object,
  `.zig-cache/check-usb-wire.zig`, `.zig-cache/flash-stall.sample.txt`.
  Caches may disappear; reconstruct important probes as maintainable tests.
- Preserved rollback `.zig-cache/manual-session/rollback-ab66f12/zigmkay-rp2040.uf2`
  is header-corrected but also fails configuration; it is not a working recovery
  keyboard. The original sibling `zigmkay.uf2` lacks metadata and must not flash.

Current reports include a seven-byte keyboard input advertised as boot keyboard,
consumer input, mouse input, 32-byte vendor input/output and a reset interface.
These are facts to audit against specifications, not accepted design choices.
Existing custom companion codes and v2 session behavior require inventory and a
reviewed transport design after a working standard keyboard baseline.

## Historical fresh-session starting prompt

> Read AGENTS.md, docs/plans/TRACKING.md,
> docs/plans/11-usb-hid-recovery.md and its recovery handoff. Execute plan 11
> starting with deep primary-source USB/HID/platform research and an evidence
> audit. Work top down: establish standard macOS keyboard configuration and
> input first, then custom codes/companion controls, then verified root mise
> flashing. Do not resume the original later subagent milestones. Use Zig
> 0.16.0 in zigmkay_firmware and make focused local commits only. Begin offline;
> prepare a bounded diagnostic session before requesting live hardware access.
> Report observed evidence separately from hypotheses and support claims.

That offline session has now run, as recorded above. This historical prompt does
not authorize new hardware retries; use the concrete bounded session next.
