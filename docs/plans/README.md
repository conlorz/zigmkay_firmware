# Next-step roadmap

Status: user paused the remaining roadmap on 2026-10-04. The **direct next task**
is [11: USB/HID recovery](11-usb-hid-recovery.md), starting with deep research.
Read its [handoff](handovers/11-usb-hid-recovery.md). Offline milestones 01–03
remain accepted; live USB configuration/typing fails and G04 is unaccepted.

Execution starts from the [central tracker](TRACKING.md), which owns status,
assignments, dependencies, and accepted evidence. Read the
[subagent workflow](SUBAGENT-WORKFLOW.md) for parallel waves, shared-checkout
ownership, and the fresh-session starting prompt. Each plan has a durable
[handover](handovers/README.md); consult the tracker for accepted evidence.

## Starting point and decisions

Canonical checkout: `zigmkay_firmware`, branch `local/monorepo`. The inspected
implementation baseline is `0ab641c`. Recheck HEAD and working-tree state before
starting a milestone. Continue in this checkout; do not create sibling clones or
branch worktrees. Use Zig 0.16.0 and make frequent, focused local commits. Never
push or create pull requests. The workspace and repository AGENTS.md apply.

The consolidated baseline has 282 passing Zig tests, ten compiling firmware
boards, matching root/standalone LK7 UF2 bytes, and a working offline GUI/replay
smoke test. These are build and offline results, not hardware acceptance.

The user's decisions are:

- First deliver reliable live LK7 monitoring through the companion.
- macOS and LK7 are the first supported live target. Other systems and boards
  remain in the build matrix and are explicitly planned for later validation.
- Use a small keyboard overlay. A configuration/editor window can be added
  later; it should not replace the lightweight overlay.
- The user has an LK7 and will flash firmware manually and test with the agent.
- Rollercole's unusual Danish-based keymap is acceptable for initial monitoring
  tests. The user's later profile uses QWERTY letters, Mac shortcuts, and the
  Homebrew-installed EurKEY Next macOS input source. Keep the original profile
  available and unchanged as a reference.
- Editing may produce a compiled keymap followed by firmware flashing. Runtime
  remapping and on-device persistent configuration are not initial requirements.
- Thoroughly compare native companion editing with browser editing before
  choosing the editor architecture. Extending the existing companion is the
  current preference, not a completed research decision.
- First-party implementation and tests remain Zig. Any new non-Zig code requires
  explicit user permission; existing native C bridges may be retained.

## Original gaps and current boundary

Milestones 01–03 implemented the versioned session, shared identity, snapshots,
recovery, bounded firmware USB transport, native companion adapter and shared
physical geometry. At integrated revision `4fd4c66`, 325 tests, all ten board
builds, standalone checks and LK7 artifact parity pass. Native GUI offline and
replay smoke runs pass. Actual USB, typing, labels and window behavior await 04;
hardware troubleshooting has occurred without live acceptance. Firmware and companion profiles remain fixed until
the accepted hardware baseline and reviewed 05 assignments permit changes.

## Milestones and order

| ID | Plan | Depends on | Result |
| --- | --- | --- | --- |
| 11 | [USB/HID recovery — direct next task](11-usb-hid-recovery.md) | User starts new research session | Researched platform contract, working standard input, custom codes, verified mise flashing |
| 01 | [Protocol and recovery](01-protocol-and-recovery.md) | Current baseline | Tested session, identity, snapshot, and recovery contract |
| 02 | [Firmware telemetry](02-firmware-telemetry.md) | 01 | Nonblocking LK7 delivery through the vendor HID interface |
| 03 | [macOS live overlay](03-macos-live-overlay.md) | 01; integrate with 02 | Small overlay with correct geometry and resilient connection handling |
| 04 | [LK7 hardware acceptance](04-lk7-hardware-acceptance.md) | 02, 03 | User-verified typing and live monitoring on real hardware |
| 05 | [EurKEY Next Mac keymap](05-eurkey-next-mac-keymap.md) | 04 | Selectable compiled QWERTY profile with Mac shortcuts |
| 06 | [Editor architecture research](06-editor-architecture-research.md) | Research may start now; final decision after 05 | Evidence-backed native/browser decision |
| 07 | [Compiled keymap editor](07-compiled-keymap-editor.md) | 05, 06 | Validated edit/save/export workflow; architecture conditional on 06 |
| 08 | [Build and flash workflow](08-build-and-flash-workflow.md) | Backend after accepted 07A; GUI after full 07 | Selected keymap builds and deliberate, identifiable firmware flashing |
| 09 | [Platforms and boards](09-platform-and-board-expansion.md) | Inventory may start now; target work separately gated | Staged Windows/Linux and additional-board support |

The original sequence below is paused by user direction. Recovery plan 11 has
priority; do not dispatch later milestones until it is accepted and the user
requests resumption.

The original implementation started with 01, while independent 06A research and 09A inventory
can run in parallel. After its contract is accepted, 02 firmware and 03 overlay
can run concurrently. Later, accepted 07A export allows 07B UI and 08A backend
work in parallel. See the tracker for exact partial-task gates and owner leases.

Reading this roadmap does not start execution. When the user starts the subagent
flow, the coordinator dispatches ready tasks within that session's authorized
scope, integrates their results, and records handovers before releasing dependent
work. Report actual checks, limits, user gates, and next ready tasks.

## Shared acceptance rules

Preserve the existing core tests, observation semantics, literal v1 fixtures,
portable native/Wasm checks, and all ten firmware builds. Add behavior tests where
needed; do not substitute a smaller suite. The count can increase, but explain
intentional fixture or compatibility changes. After firmware behavior changes,
old UF2 hashes need not stay identical; root and standalone builds for the same
board/profile must still match each other.

Default builds, `test`, `check`, and `check-full` remain hardware-free. Use
`zig build check` for normal milestones and `zig build check-full` when a change
affects firmware, build integration, or package build APIs. New command names
shown in individual plans are proposed until implemented. Check the existing
root help and manifests instead of assuming they already exist.

Keep telemetry separate from the keyboard action queue. Overload, a missing
companion, malformed control traffic, or USB endpoint backpressure must never
block typing or force keyboard actions to fail.

Use named offline fixtures, fake transports, and deterministic clocks for
connection/recovery checks. Live captures and manual flash results belong to an
explicit user testing session; never hide device operations in an automated
check. The user flashes during 04 and 05. Agent-assisted live reads happen only
as part of that agreed session. This roadmap does not authorize autonomous
flashing, BOOTSEL requests, or writes to an arbitrary mounted drive.

Each implementation plan records concrete outputs, acceptance criteria, and
local commit checkpoints. Stop at a decision that materially changes scope;
bring a concrete result and explain the choice rather than inventing a preference.

## Open details and deferred work

The input source and letter arrangement are settled: EurKEY Next and QWERTY.
During 05, record the installed layout version and native input-source ID, and
review concrete thumb/layer/shortcut assignments with the user. Do not equate an
OS input source with the firmware's physical key arrangement. The upstream
[EurKEY Next repository](https://github.com/felixfoertsch/EurKEY-Next) is the one
used by the [Homebrew cask](https://formulae.brew.sh/cask/eurkey-next).

Overlay opacity, placement, and click-through behavior can use adjustable
sensible defaults and be tuned during 04. Capture user feedback before treating
schematic LK7 geometry as accurate physical measurements.

Browser editing/flashing, runtime configuration, on-device keymap storage,
wireless support, other MCUs, and replacing existing C interoperability bridges
are not hidden requirements of 01-05. Research and later plans must document
which are selected, rejected, or deferred.

Earlier phase/milestone documents are historical. They reference removed
worktrees and Python tooling. Use this roadmap and the current root README for
future execution; do not recreate those old environments.
