# 04 handover: observed LK7 live acceptance

**Latest status:** user stopped retries and requested a research-led reset.
See [recovery handoff](11-usb-hid-recovery.md) and [plan 11](../11-usb-hid-recovery.md).
Latest `637fd71` flash/restart and descriptor parsing succeed, but configuration
still times out and no HID interfaces attach. G04 remains unaccepted. Do not
continue the retry instructions below; they are investigation history.

State: **Waiting-user**. Offline entry gate accepted at `4fd4c66`;
the [worksheet](../04-manual-worksheet.md) identifies firmware, GUI, shared
identity and rollback. Hardware troubleshooting has started; acceptance is pending.
Producer: coordinator with the user. Reviewer: coordinator records observed results.
Plan: [04](../04-lk7-hardware-acceptance.md). Rules: [handover format](README.md).

## Required input and output

Input: accepted [02](02-firmware.md)/[03](03-overlay.md), integrated offline checks,
identified Danish-profile firmware/GUI, recovery/rollback preparation, and an
explicitly started user testing session.

Record actual board/OS/input source, artifact/code revisions and hashes, manual
flash outcome, every worksheet row, typing/action behavior, identity/snapshot/
recovery results, and overlay feedback. Link sanitized reproductions and fixes
with rechecked results. Leave unperformed checks pending, with a concrete reason.

## Consumers and gate

- [05 keymap](../05-eurkey-next-mac-keymap.md): relies on accepted wiring,
  physical-index correspondence, typing baseline, and live recovery.
- [06 research](../06-editor-architecture-research.md): uses actual macOS constraints.
- [09 expansion](../09-platform-and-board-expansion.md): updates LK7/macOS evidence.

Only observed acceptance releases **G04**. Offline artifacts or a waiting user
do not release it. Reproducible defects go back to 02/03 with explicit write
leases and targeted offline tests before the user reflashes.

## Integrated result

Pending user session. Complete the [result template](README.md) with actual evidence.

## Flash investigation, 2026-10-04

User observed that the bootloader volume remains after flashing. Original utility
reported copy success but USB still enumerated RP2 Boot. After sync/eject and
physical reconnect, user reports keyboard operation and a combo returning it to
BOOTSEL; this does not identify which firmware is running. Revised utility uses
direct final-name writes plus file sync instead of Zig atomic copy/rename.
Offline chunk/truncation tests and five-platform compilation passed. Live retry
reported successful write/sync, but RP2 Boot and its mount remained immediately
afterward. Automatic reboot and installed firmware identity remain unresolved;
do not release G04 or attribute this conclusively to macOS caching.

Follow-up: user ran mise flash and it stalled after finding the volume. Process
sampling identified `dirCreateFilePosix -> openat` on the FSKit FAT mount, not
device discovery. Separate directory access also blocked. Cancellation and
normal/forced unmount did not release the flasher's uninterruptible syscall;
physical reconnect requested. No second writer was started against this mount.

A separate definite defect was found: generated UF2 flags/family were zero.
The RP2040 boot ROM ignores blocks lacking its family flag and ID (see
[upstream virtual_disk.c](https://github.com/raspberrypi/pico-bootrom/blob/master/bootrom/virtual_disk.c)).
`2089219` explicitly emits RP2040 family metadata, validates inputs before any
device file access, preserves the validated bytes while waiting and logs each
write stage. Full offline checks and all ten UF2 validations passed. The
worksheet now identifies corrected firmware and a baseline rollback with only
UF2 header metadata repaired. Live retry is pending physical connection reset;
earlier copy success did not establish that new firmware ran.

After physical reconnect, corrected firmware wrote and synchronized successfully
through `mise //:flash lk7`, and automatically re-enumerated as ZigMkay. The user
reported no typing. macOS logs show configuration 1 selection followed by EP0
timeouts (`0xe00002d6`, zero bytes); no HID interfaces appear in IORegistry.
Quitting Brave and reconnecting did not resolve it. Flashing the preserved
`ab66f12` rollback with repaired UF2 headers reproduced the same configuration
timeouts. This isolates the failure below the new telemetry integration.

The pinned MicroZig controller leaves the descriptor OUT status phase unarmed
(its `on_buffer` contains a commented-out `ep_listen(.ep0, 0)`). The first-party
control wrapper now arms this phase after the final IN completion, cancels
stale EP0 buffers/descriptor slices on every SETUP, and runs for boards without
telemetry as well. A regression covers multi-packet completion, single status
arming, cancellation and bus reset. `mise //:check-full` passes, including all
ten firmware builds. Live confirmation remains pending; this is a candidate
fix, not established hardware acceptance.

Live retry of `4688fe1` completed write/sync and automatic reboot, but still
produced EP0 timeouts and no HID interfaces. The status-phase change alone is
insufficient. Further source review found standard GetConfiguration (request 8)
missing from the pinned controller's device request switch. The wrapper now
returns the actual configuration byte for a valid query and completes its OUT
status stage. A regression checks unconfigured/configured/deconfigured values
and malformed-query delegation. Host logs do not identify the timed-out request
number, so this remains a compatibility candidate until live verification.

Live retry of `43a5ff7` again completed flash/reboot but produced the same EP0
timeouts. Apple's `usbdiagnose` provided the missing evidence: the configuration
has padding after its nine-byte header, interface records and inside HID
records, and terminates with `Illegal Descriptor: Length of 0`. A minimal Zig
0.16.0 Cortex-M0+ object reproduces the padding in nested extern constants with
align(1) words despite the logical structure sizes. The compiler/layout issue
is independent of Finder's disk notification and telemetry.

The first-party USB boundary now generates configuration and HID descriptor
byte arrays from typed values at compile time, without copying aggregate
memory. It uses the same MicroZig descriptor allocator, driver options and
endpoint numbering as the controller. GET_DESCRIPTOR serves these bytes with
host length limits and upstream multi-packet progression. Tests cover nested
unaligned words, contiguous records, configuration prefixes, packet splitting
and HID interface selection. `mise //:check-full` passes. A cached Zig inspection
of the actual LK7 UF2 finds the contiguous 146-byte configuration with all five
interfaces, eight endpoints and four HID descriptors. Live retry is pending.
