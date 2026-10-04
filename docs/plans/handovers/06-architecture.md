# 06 handover: editor architecture decision

06A state: **Accepted**, research only. 06B state: **Not produced**.
Producer: architecture worker. Reviewer: coordinator; user decides material scope changes.
Plan: [06](../06-editor-architecture-research.md). Rules: [handover format](README.md).

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

State: **Not produced**. Consume accepted [03](03-overlay.md),
[04](04-hardware.md), and [05](05-keymap.md). Reconcile actual custom actions,
host labels, selected profiles, identity and export/build needs. Record final
architecture, supported schema/actions/callback policy, dependency changes,
UI/backend split and coordinator-integrated 07/08 plan revisions.

[07](../07-compiled-keymap-editor.md) and [08](../08-build-and-flash-workflow.md)
consume only the final accepted decision. Within agreed scope, coordinator
acceptance releases G06. New language/material workflow decisions wait for the
user before affected implementation begins.
