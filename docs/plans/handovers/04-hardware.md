# 04 handover: observed LK7 live acceptance

State: **Waiting-user**. Offline entry gate accepted at `4fd4c66`;
the [worksheet](../04-manual-worksheet.md) identifies firmware, GUI, shared
identity and rollback. No hardware session has occurred for this milestone.
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
