# 07 handover: schema/export contract and visual editing

State: **07A and 07B Accepted; full G07 released**. G07-export frozen at `016cf7d` on 2026-10-04.
Producer/reviewer: coordinator, with exclusive model/integration/document ownership.
Plan: [07](../07-compiled-keymap-editor.md). Rules: [handover format](README.md).

## 07A: schema/export handover

Input: accepted [04 baseline](04-hardware.md) and
[06 architecture](06-architecture.md), reusing [01 identity](01-protocol.md).
05 follows the editor under the revised order and is not an entry prerequisite.
Publish project schema/version, action/custom-callback preservation matrix,
parse/validate/export API and errors, limits, migration behavior, export path
ownership, deterministic module/build input, canonical identity/digest, and
literal export/processor/round-trip test results. Specify cancellation/result
semantics needed by consumers and actual coordinator build integration.

Coordinator acceptance releases **G07-export**. Freeze this interface before
[07B UI](../07-compiled-keymap-editor.md) and [08A backend](../08-build-and-flash-workflow.md)
run in parallel. The schema owner releases its lease or retains only an explicitly
assigned maintenance scope; consumers request amendments through the coordinator.

## 07B and complete milestone handover

Publish concrete edit/save/reopen/export workflow, undo/validation behavior,
live-versus-edited identity presentation, preserved unsupported actions, and
offline GUI/compile checks. Demonstrate a saved/reopened/exported LK7 modification.

Acceptance of all 07 criteria releases **G07** for 08B GUI integration. Transfer
GUI ownership explicitly. 07A acceptance alone does not complete 07 or permit
flashing. [09](../09-platform-and-board-expansion.md) consumes documented limits.

## Integrated result

### Accepted 07A contract freeze

Coordinator implementation/review: `ca76344`, `a5348e5`, `016cf7d` complete the
checkpoints below. Consumed accepted 04/06 and original 01 canonical identity.
Contract/schema/runner/build version 1 is frozen in
[the package contract](../../../keymap-project/README.md). This supersedes the
historical pending list below. APIs, bounds, ownership, errors, sources,
curated registration, shared build selection, explicit CLI workflow and consumer
job/reset/stale semantics are documented there.

Verification on the complete `016cf7d` code tree: `mise //:check-full` passed,
including all package/generated checks, ten-board artifacts, replay, offline
guard and standalone/root LK7 UF2 parity. Curated Danish create/save/reopen/
export built through the actual LK7 firmware path and native host runner with
the same manifest selector, which captures verified files into build caches.
Model package 22 tests, native runner 7 tests and process jobs 3 tests pass.
Generated literals cover all current actions, callback bytes/relative imports,
registered layer/Alt-Tab behavior, fresh-process reset and malformed frames;
real process tests cover cancellation, crash, timeout, bounded output and stale
results. Recorded warm-cache runner compilation: 1.536 s; startup 4.355 ms and
input roundtrip 3.251 ms. No hardware operation occurred.

Limits remain explicit: advisory reachability cannot prove opaque callback
behavior; original latent Gaming callback is preserved without new acceptance;
no cross-process writer locking or directory-sync power-loss claim; no arbitrary
dynamic imports/non-Zig embedded assets. These are defined contract limits,
not unfinished 07A consumers. Native OS text and visual/manual evidence belongs
to 07B. G07-export released; full G07 acceptance is recorded in the 07B section below. Coordinator retains
schema maintenance ownership and owns the 07B UI spike/editor files exclusively.

### Historical first checkpoints

Base: clean `eef2c45`, inspected before changes on 2026-10-04. Local code commits:

- `aa9b984`: typed schema/parser, stable IDs, full action-field lowering,
  validation and layer deletion constraints; package/root mise integration.
- `63b6144`: immutable source inventories, content-addressed bundles, atomic
  document replacement, save/load and canonical identity/freshness adaptation.
- `9347bbf`: lossless typed adapters, deterministic pure Zig generator,
  generated-module compilation/real processor traces and owning diagnostics.

Concrete API/bounds/ownership and current limitations:
[keymap-project README](../../../keymap-project/README.md),
[model](../../../keymap-project/src/root.zig),
[snapshot/persistence](../../../keymap-project/src/snapshot.zig),
[generator](../../../keymap-project/src/export.zig).
These APIs are provisional; no consumer may assume the complete export/runner
contract is frozen. Callback metadata is retained, not silently replaced by
no-op behavior. Source storage is immutable; editable external attachments and
curated resolution remain to implement. Current fixtures deliberately use a
tiny board-owned geometry rather than claiming existing LK7 profile acceptance.

Inputs read: both AGENTS.md files, root README, central tracker, 06B decision,
06 handover, 07 plan, visual specification, feature requirements, subagent and
handover rules; current portable action/identity/processor/build/profile code.
No additional dependency, first-party language, clone or worktree was introduced.

Verification at the complete code tree `9347bbf`:

- `mise //keymap-project:test`: passed; 14 model/snapshot/export/diagnostics tests
  plus one generated-profile compilation/processor test.
- `mise //:check`: passed after the schema checkpoint.
- `mise //:check-full`: passed after persistence and again at the final code
  checkpoint. Aggregate package/generated checks, all ten board artifacts,
  standalone/root LK7 UF2 parity and replay passed. Source inventory unchanged
  by checks; offline guard observed no hardware tool execution.
- `zig fmt` (through mise Zig 0.16.0) and `git diff --check`: passed.

Literal runtime traces: exported fixture key 0 emits A press/release (usage 4);
holding its layer key then pressing key 0 emits Left Arrow press/release (usage
80). Generated identity equals canonical firmware identity. Compound actions
have round-trip/lowering/export-field assertions; complete per-action emitted
traces and actual registered/attached callback compilation are still pending.

Remaining before G07-export: curated Danish/representative EurKEY adapters and
callback registry; transitive import validation and editable-source snapshot
capture; shared selector and actual board-path export compilation; native runner
protocol/executable and reusable bounded process jobs, cancellation/crash/stale
tests and measured latency; complete literal action/callback traces and final
schema/build/API review. Atomic replacement is tested, but directory metadata
sync/power-loss durability and concurrent-writer protection are not claimed.

07B/full 07: pending. No native editor/spike/screenshot, native EurKEY text,
accessibility or hardware evidence is claimed. Dark/light visual acceptance must
follow the specification after G07-export. No gate released. Coordinator retains
ownership for the next 07A checkpoint; plan 12 remains deferred.

### Complete 07B implementation and acceptance

Authoritative current evidence supersedes the historical pending lists above:
[acceptance report](../07-editor-acceptance.md),
[self-verification workflow](../07-editor-verification.md),
[approved goldens](../goldens/07-editor/README.md).
Local implementation commits `1e16484`, `206d9a0`, `8e4039f`, `7168c13`
retain the frozen 07A schema/export/runner contract. No plan 08 or 12
implementation, hardware access, push or PR occurred.

The separate opaque/resizable editor owns a validated draft with 32-snapshot
undo/redo history, bulk selection/copy/paste, stable named layer management,
complete action forms and combo editing. LK7's encoder absence is explicit.
Save/open and callback source refresh are validated/undoable; saving uses the
07A atomic snapshot API. Export uses the same deterministic generator/manifest
consumed by the real firmware and runner builds. Draft/export identity and a
connected companion's verified running identity remain distinguishable; edited
actions never repaint the running overlay as if flashed. Cached recoverable
snapshots and dirty close choices preserve unsaved work.

Prepare Test explicitly snapshots/exports/builds the real processor, Start
creates a fresh bounded child and Stop/focus/source change resets it. Document
and first-party build-input/compiler/target identity invalidate cached/prepared
results. Output text uses native EurKEY dead-key translation; media/mouse/BOOT
commands remain displayed data. Full emitted commands/events/signals/layers and
compiler diagnostics are available in a bounded scrollable details drawer.
Attached Zig checkout/open/check/refresh remains explicit, registered sources
read-only, and callback bytes/imports are never interpreted as visual actions.

The user approved both themes and their 1×/2× variants as regression goldens,
and separately confirmed independent telemetry during native folder-dialog
cancellation. All reference panel bounds match exactly. Catalog-correct geometry,
actual host/action labels, inert offline/08 controls and typography differences
are documented. The golden task is read-only and rejects a wrong-theme image;
future replacement requires explicit screenshot approval. Default builds/tests
retain the offline guard and do not regenerate those approved assets.

Coordinator retains shared-schema maintenance; the editor GUI write lease is
released for future 08B after accepted 08A and an explicit assignment. No worker
or hardware session is active. 08 may consume the documented jobs/selector APIs
and composition; personal profile 05 follows accepted 08. Plan 12 stays deferred.

Final verification on `7168c13`: `mise //:check-full` passes, including ten-board
artifacts, LK7 parity and source/hardware guard; companion 40/40 tests pass;
`editor-check` and `editor-golden-check` pass all 64 captures plus expanded
interactions. Native text, separate-window and offline overlay/editor probes
pass. `zig fmt --check` and `git diff --check` pass. G07 is released.
