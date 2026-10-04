# 06 handover: editor architecture decision

State: **Not produced**. Research and final decision are separate partial results.
Producer: research worker. Reviewer: coordinator; user decides material scope changes.
Plan: [06](../06-editor-architecture-research.md). Rules: [handover format](README.md).

## 06A: research input and output

May start from the current repository and user requirements before live acceptance.
Publish dated primary sources, pinned API audit, native/browser comparison,
Zig-only feasibility, build/flash constraints, proposed action/schema boundaries,
and unresolved questions. Any necessary spike requires a separate assigned scope.
This section does not release G06 or authorize another language.

## 06B: final input and output

Use accepted [03](03-overlay.md)/[04](04-hardware.md) behavior and
[05 profile](05-keymap.md). Reconcile evidence against the actual custom actions,
host labels, profile selection, and export/build needs. Record the selected
architecture, rationale/alternatives, supported schema/actions, UI/backend split,
dependency changes, and coordinator-integrated revisions to 07/08 plans.

## Consumers and gate

[07 editor](../07-compiled-keymap-editor.md) and [08 build/flash](../08-build-and-flash-workflow.md)
consume the final decision and revised task specification. Within the agreed
scope, coordinator acceptance releases **G06**. A new language/material workflow
change waits for the user's decision; record the reason and exact affected scope.
09 uses platform constraints without treating research as native runtime testing.

## Integrated result

06A: pending. 06B: pending. Complete separate sections using the
[result template](README.md); accept them independently.
