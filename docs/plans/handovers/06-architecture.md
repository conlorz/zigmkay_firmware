# 06 handover: editor architecture decision

06A state: **Accepted**, research only. 06B state: **Accepted planning decision**.
Producer: architecture worker. Reviewer: coordinator; user decides material scope changes.
Plan: [06](../06-editor-architecture-research.md). Rules: [handover format](README.md).

The 06A sections below retain historical baseline findings and old prerequisite
text. The final 06B section supersedes those gates and consumer instructions.

## 06A submitted result

Base revision: `ab66f12`; dispatch record: `ed14722`. Integration commit:
`2762d91`; coordinator reviewed source-backed comparison on 2026-10-04.
`git diff --check` and worker relative-link checks passed. No frozen implementation
API/schema or architecture contract was created.

Changed paths:

- [Research comparison](../06-architecture-research.md) (new).
- This handover, `docs/plans/handovers/06-architecture.md`.

Inputs consumed: workspace/repository AGENTS.md, roadmap, tracker, workflow,
06 plan and handover rules; current companion/layout/actions/build/flasher source;
immutable DVUI dependency cache and Zig 0.16.0 standard library; primary official
browser, SDL, Wasm, Raspberry Pi and Apple documentation fetched 2026-10-04.
No accepted 03/04/05 inputs exist yet, and no provisional wire API is frozen here.

Deliverable: pinned API audit, native/browser service/export-only/Wasm comparison,
platform/device/file/build restrictions, complete baseline action field inventory,
explicit custom callback preservation options, provisional native recommendation,
and bounded 07/08 integration proposals. Source URLs and evidence distinctions
are in the research document. Nested SDL archive/runtime version was not audited;
recorded SDL version label comes from the pinned DVUI manifest.

## Consumer instructions

Use this as 06B research input only. Provisional preference: a separate native
editor window in the companion, UI-independent typed ZON document/export module,
then native build/flash backend. The exact format and callback binding policy
remain undecided until G05. Do not claim arbitrary Zig callbacks round-trip through
forms, browser Wasm can launch local compilation, or vendor HID access equals
UF2 volume copying. Reuse accepted 01/05 identity rather than creating another
editor digest contract. 09 may cite constraints without claiming runtime support.

## Verification and remaining gates

Worker verification: read-only source/API inspection and official page retrieval;
scoped whitespace/link checks recorded in worker report. No Zig build/test,
GUI/browser launch, spike, packaging or device operation was performed. `zig env`
showed PATH Zig 0.15.2; coordinator notified to use explicit installed 0.16.0.
No tested browser/OS version or hardware evidence is claimed.

Manual evidence: none. Multi-window behavior, dialog concurrency, screen-reader
usability, platform permissions, browser file/volume behavior and firmware/device
acceptance are untested. Native recommendation remains provisional. No gate is
released; **G06 remains pending**. Research acceptance does not accept milestone 06.

Worker ownership released after accepted research review. Coordinator
owns commits, review/acceptance, tracker and any revised plans. Next action:
revisit as 06B after accepted 03/04/05; request a separate
Zig offline spike only if a material unresolved question needs one.

## 06B final input and output

State: **Accepted**, 2026-10-04, coordinator review with explicit user feature
answers. Source baseline `63f7998`; initial inspection `0eeb958`.
Consumed accepted 03/04 and current profile/action/processor/label source.
05 is not a prerequisite under the revised order.

Deliverables: [06B decision](../06-editor-architecture-decision.md),
[agreed requirements](../06-editor-requirements.md), revised 06/07/08 plans and
tracker. Native separate editor, full existing actions, named layer management,
multi-key editing, compiled offline runner with EurKEY text, and project-contained
externally edited callbacks are selected. Portable project and job boundaries,
identity reuse, source preservation, resource-cap proposals and future schema
freeze are documented. No new dependency/language is selected.

Verification: source/API review, current Apple/EurKEY primary documentation,
`git diff --check`. Documentation-only changes; no Zig source or build API changed,
so no new Zig build result is claimed. No hardware, GUI spike, native text test,
performance or packaging result. 07B owns bounded offline window/dialog/input
verification; 07A freezes exact schema/API/protocol before its consumer gate.
These implementation checks do not imply the architecture is already implemented.

G06 is released for separately authorized 07/08 implementation. Coordinator
retains integration ownership. Next action: start 07A when requested; G07-export,
G07 and G08 remain pending.

[07](../07-compiled-keymap-editor.md) and [08](../08-build-and-flash-workflow.md)
consume only the final accepted decision. Within agreed scope, coordinator
acceptance releases G06. New language/material workflow decisions wait for the
user before affected implementation begins.
