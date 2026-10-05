# 05 handover: accepted QWERTY/EurKEY Next Mac profile

State: **Offline candidate produced; manual acceptance pending**. The user
authorized autonomous preparation and continuation on 2026-10-05. See the
[candidate](../05-candidate.md) for provisional assignments, installed layout
provenance, checks and remaining acceptance. No personal hardware test recorded.
Producer: keymap worker; coordinator integrates and leads manual acceptance.
Plan: [05](../05-eurkey-next-mac-keymap.md). Rules: [handover format](README.md).

## Required input and output

Input: accepted [04 baseline](04-hardware.md), [01 identity](01-protocol.md),
user-reviewed concrete thumb/layer/action assignments, and selected EurKEY Next
layout/version provenance. QWERTY letters and Mac shortcuts are already settled.

Publish profile names, root/standalone/GUI/headless selector API, canonical
identity, 34-key diagrams/action tables, retained custom actions, symbol/dead-key
expectations, and mapping/compile/parity checks. Preserve Rollercole's profile.
Record exact native input-source ID/version and actual manual typing/shortcut/
overlay worksheet with matched artifacts; pending hardware is explicit.

## Consumers and gate

- [06 architecture](../06-editor-architecture-research.md): uses actual supported
  profile actions and selection requirements to finalize its recommendation.
- [07 editor](../07-compiled-keymap-editor.md): imports a concrete accepted profile
  and preserves actions/identity through save/export.
- [08 build/flash](../08-build-and-flash-workflow.md): invokes the shared selector
  and verifies the same board/profile identity.

All 05 criteria, including manual checks, release **G05**. Coordinator owns
selector/publication glue; profile source ownership transfers for editor work
only after the accepted reference and its provenance remain preserved.

## Integrated result

`eurmac` is available through the CLI and native editor's existing selector.
The existing absolute exported-profile selector builds candidate LK7 firmware
and the real offline processor. No duplicate firmware/companion keymap was added.
Project checks and full offline checks pass; processor evidence confirms Option
and shortcut modifier release and all three auxiliary layer enter/release paths.
Manual acceptance, selected host keyboard type and user comfort remain pending.
