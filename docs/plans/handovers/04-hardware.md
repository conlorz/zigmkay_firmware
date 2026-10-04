# 04 handover: observed LK7 live acceptance

State: **Not produced**. No hardware session has occurred for this milestone.
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
