# Next-step roadmap

Status: planned. User priorities agreed on 2026-10-04. This roadmap describes
future work; creating these plans does not implement or hardware-validate it.

Execution starts from the [central tracker](TRACKING.md), which owns status,
assignments, dependencies, and accepted evidence. Read the
[subagent workflow](SUBAGENT-WORKFLOW.md) for parallel waves, shared-checkout
ownership, and the fresh-session starting prompt. Each plan has a durable
[handover](handovers/README.md); all initial records are pending, not accepted.

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

## Current gaps

`zigmkay/src/telemetry.zig` provides an optional observer, but the LK7 runner does
not attach a production sink. `usb_command_executor.zig` still delivers legacy
RawHID signals through the keyboard output queue. The companion expects the new
32-byte codec, and its current `--live` path lacks handshake, initial snapshot,
reconnection, and recovery. Do not claim that current firmware and GUI already
communicate correctly.

The GUI also computes display positions from legacy side tags instead of using
the existing physical-layout geometry. Firmware and companion keymaps are
currently fixed imports. These are concrete work items below.

## Milestones and order

| ID | Plan | Depends on | Result |
| --- | --- | --- | --- |
| 01 | [Protocol and recovery](01-protocol-and-recovery.md) | Current baseline | Tested session, identity, snapshot, and recovery contract |
| 02 | [Firmware telemetry](02-firmware-telemetry.md) | 01 | Nonblocking LK7 delivery through the vendor HID interface |
| 03 | [macOS live overlay](03-macos-live-overlay.md) | 01; integrate with 02 | Small overlay with correct geometry and resilient connection handling |
| 04 | [LK7 hardware acceptance](04-lk7-hardware-acceptance.md) | 02, 03 | User-verified typing and live monitoring on real hardware |
| 05 | [EurKEY Next Mac keymap](05-eurkey-next-mac-keymap.md) | 04 | Selectable compiled QWERTY profile with Mac shortcuts |
| 06 | [Editor architecture research](06-editor-architecture-research.md) | Research may start now; final decision after 05 | Evidence-backed native/browser decision |
| 07 | [Compiled keymap editor](07-compiled-keymap-editor.md) | 05, 06 | Validated edit/save/export workflow; architecture conditional on 06 |
| 08 | [Build and flash workflow](08-build-and-flash-workflow.md) | Backend after accepted 07A; GUI after full 07 | Selected keymap builds and deliberate, identifiable firmware flashing |
| 09 | [Platforms and boards](09-platform-and-board-expansion.md) | Inventory may start now; target work separately gated | Staged Windows/Linux and additional-board support |

Implementation starts with 01, while independent 06A research and 09A inventory
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
