# 07 handover: schema/export contract and visual editing

State: **Not produced**. Export/model and UI are separately accepted partial results.
Producer: assigned 07A/07B workers, one writer per section/file at a time.
Plan: [07](../07-compiled-keymap-editor.md). Rules: [handover format](README.md).

## 07A: schema/export handover

Input: accepted [05 profile/selector](05-keymap.md) and
[06 architecture](06-architecture.md), reusing [01 identity](01-protocol.md).
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

07A: pending. 07B/full 07: pending. Fill separate [result sections](README.md).
