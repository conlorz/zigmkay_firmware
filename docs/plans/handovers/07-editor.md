# 07 handover: schema/export contract and visual editing

State: **Draft, 07A partially implemented**. G07-export is not frozen; 07B has not started.
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
