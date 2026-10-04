# Central milestone tracker

## Recovery, G04 and G06 accepted; next is editor schema/export

06B finalized in the editor planning session on 2026-10-04: separate native
editor, full existing action set, named layers and bulk editing, offline draft
runner with EurKEY text, attached externally edited Zig callbacks. See the
[decision](06-editor-architecture-decision.md) and
[requirements](06-editor-requirements.md). This accepts planning only; no 07/08
implementation or new hardware session has started.

User-revised order: **04 → 06 → 07 → 08 → 05 → 09**. Build shared profile
selection in 07/08; use existing profiles and representative fixtures for editor
acceptance. The user's actual EurKEY Next profile is created in the finished
editor during 05. This supersedes older G05 dependencies for 06–08 and execution
wave text below. No new hardware session is started by this reorder.

Recovery research/design accepted at `2972bc6`; runtime initializer `c9ea3a1`;
offline R3 integrated at `2e30e9d`. Full offline checks pass, including ten board
artifacts, actual USB wire/report parsing and root/standalone parity. The target
probe demonstrated device-side aggregate corruption that the old host-facing
serialization did not fix. One authorized candidate flash succeeded: macOS
configured the device and attached all four HID interfaces; reconnect typing
works per user. Controlled taps, modifiers and release checks all passed per user.
R-keyboard is accepted on macOS; LED state and other platforms are unverified.
User also confirms BOOTSEL 0+4, successful reflash and automatic keyboard reconnect.

| Recovery gate | State | Exact next work |
| --- | --- | --- |
| R-HID-design | Accepted offline | [Decision and limits](../research/usb-hid-decision.md) |
| R-keyboard | Accepted | [Live configuration/input/modifier/release/reconnect evidence](../research/usb-hid-diagnostic-session.md); Mac only, no Caps Lock binding |
| R-custom | Accepted | [Live custom run](../research/usb-hid-custom-contract.md): user confirms stable status, agreed controls and typing; SDL filter and refresh fixes integrated |
| R-flash | Accepted | [Final root run](../research/usb-hid-flash-contract.md); `0aa2ca7`, full checks; root flash/restart/identity verification passed in 6.46s; user confirms typing/Shift/custom persistence |

Research workers have stopped and released all leases. The coordinator owns
all integration. Source remains Zig 0.16.0 with the immutable MicroZig pin;
all commits are local. G04 is now accepted by the focused user session;
06 is ready, and 07/08/05/09 retain their revised entry gates.
All plan 11 gates are accepted for the available Mac/LK7 and agreed controls.
Windows/Linux live behavior, Caps Lock LED state, legacy gaming action and exact
binary readback remain outside this acceptance. The user requested completion
of 04 to proceed toward the editor; further hardware runs need an explicit task.

### Historical reset instruction

User decision on 2026-10-04: stop implementation/hardware retries in the current
session, prepare a fresh-session plan, and pause the rest of the original
subagent workflow. **Start [plan 11](11-usb-hid-recovery.md) next**, with
[this handoff](handovers/11-usb-hid-recovery.md). No worker is active.

Priority order: evidence/primary-source HID research across macOS, Windows and
Linux → standard keyboard baseline → custom codes/companion → verified mise
flashing. Original 04 acceptance and 05–09 continuation stay deferred until
recovery acceptance and the user's request to resume. Research first; no new
hardware run is authorized by reading these plans.

Previous implementation `637fd71` passed full offline checks. Its latest live
flash/restart succeeded and the malformed configuration bytes are repaired,
as confirmed by Apple's USB diagnostic, but EP0 configuration still times out
and no HID interfaces attach. G04 remains unaccepted. Earlier “pending retry”
entries are historical; use the recovery handoff for actual current evidence.

Updated: 2026-10-04. Offline execution started from clean `ab66f12` on
`local/monorepo`; coordinator owns integration and local commits.
The last inspected implementation baseline is `0ab641c`; the initial nine plans
were committed in `322d631` and linked in `d99733e`. Re-read actual HEAD/status
at startup. This file is the execution source of truth and is coordinator-owned.

Read the [roadmap](README.md), [subagent workflow](SUBAGENT-WORKFLOW.md), and
[handover rules](handovers/README.md). Plans define requirements; this tracker
defines readiness, assignments, gates, evidence, and the next dispatch.

## Status rules

| Status | Meaning |
| --- | --- |
| Planned | Defined, but its entry gate is not yet met |
| Ready | Eligible within its listed scope; no agent has started |
| Active | One named owner holds the listed write lease |
| Review | Worker has stopped writing and submitted its handover |
| Integrated | Coordinator has committed and checked the work; remaining acceptance is explicit |
| Accepted | All criteria for this row passed and its handover was accepted |
| Waiting-user | A specific assignment decision or interactive test is pending |
| Blocked | A recorded technical/environment condition prevents this work |
| Deferred | Outside the current execution scope |

Subtask acceptance does not accept its parent milestone. For 02/03, acceptance
means their offline criteria passed; live acceptance belongs to 04. Milestones
04/05/08 require actual manual evidence. Agent messages or successful builds do
not satisfy those gates. Readiness does not authorize execution by itself.

## Milestones

Initial dispatch: 01 protocol, 06A research, and 09A inventory. Hardware evidence
remains none. Exact active ownership is recorded below.

| ID | Plan / handover | Status | Entry gate | Next concrete move | Owner / accepted revision |
| --- | --- | --- | --- | --- | --- |
| 01 | [Protocol](01-protocol-and-recovery.md) / [handover](handovers/01-protocol.md) | Accepted | Clean baseline inspected | Frozen v2 contract consumed by 02/03 | Coordinator / `5b092ec` |
| 02 | [Firmware](02-firmware-telemetry.md) / [handover](handovers/02-firmware.md) | Accepted | G01 | Manual validation in 04 | Coordinator / `4fd4c66` |
| 03 | [Overlay](03-macos-live-overlay.md) / [handover](handovers/03-overlay.md) | Accepted | G01 | Manual validation in 04 | Coordinator / `4fd4c66` |
| 04 | [Live acceptance](04-lk7-hardware-acceptance.md) / [handover](handovers/04-hardware.md) | Accepted | Plan 11 baseline plus focused user session | All required baseline/highlight/snapshot/recovery checks passed; limits in handover | Coordinator with user / `0aa2ca7` implementation |
| 06 | [Architecture](06-editor-architecture-research.md) / [handover](handovers/06-architecture.md) | Accepted planning | G04; 06A already accepted | Consume final 06B; implementation checks assigned to 07 | Coordinator / final decision linked above |
| 07 | [Editor](07-compiled-keymap-editor.md) / [handover](handovers/07-editor.md) | Ready | G04 and G06 | Await implementation request; schema/export/shared selector and test contract first | Unassigned / none |
| 08 | [Build/flash](08-build-and-flash-workflow.md) / [handover](handovers/08-build-flash.md) | Planned | 08A: G06, G07-export; 08B: G07 | Reuse recovery backend, integrate editor build/flash and manually accept | Unassigned / none |
| 05 | [EurKEY Next](05-eurkey-next-mac-keymap.md) / [handover](handovers/05-keymap.md) | Planned | G07 and G08; reviewed assignments | User creates personal profile through finished editor, then manual tests | Unassigned / none |
| 09 | [Expansion](09-platform-and-board-expansion.md) / [handover](handovers/09-expansion.md) | Planned | 09A may start now; target work needs selection and accepted baseline | Capability inventory and separately scoped target plans | Unassigned / none |

## Partial deliverables for parallel dispatch

| Task | Initial status | Writable scope | Acceptance / release |
| --- | --- | --- | --- |
| 06A | Accepted | Architecture research document; 06 handover | `2762d91`; sourced comparison; G04 now releases final editor decision |
| 06B | Accepted | Architecture decision; revised 07/08 plans | Source-backed native decision and explicit user feature answers; planning only |
| 07A | Ready | New schema/export Zig source and dedicated tests | Await request; exact leases before implementation; G07-export remains pending |
| 07B | Planned | Editor UI and dedicated UI tests | G07-export, supported save/edit/export workflow; completes 07 criteria |
| 08A | Planned | Build/flasher backend and dedicated fake tests | G06/G07-export; no GUI/hardware; partial backend only |
| 08B | Planned | Build/flash GUI after ownership transfer | G07 and accepted 08A; offline integration then manual acceptance |
| 09A | Accepted | Platform/board capability documents | `99c1dbe`; documentation only; refresh after G04/G05, no support claims |
| 09B | Deferred | A selected target's new plan, then assigned source | User selects target/environment; own implementation and hardware gates |

05 diagram/source preparation and 04 worksheet preparation may be separately
assigned early as documentation-only tasks. They do not release G04/G05 or
permit profile changes before their entry gates. Do not create speculative code
against a protocol/export interface that has not been frozen.

## Gates and decisions

| Gate | Required evidence | Current state |
| --- | --- | --- |
| G01 | Accepted 01: versioned wire/API, identity, snapshot ordering, limits, fixtures and passing offline checks | Accepted `5b092ec`; check/check-full passed |
| G-live-offline | Accepted 02/03 at one integrated revision, offline session tests, `check-full`, identified artifacts/rollback | Initial `4fd4c66`; superseded artifacts at `2089219` fix mandatory UF2 metadata; full checks and all ten UF2 validations pass; worksheet refreshed |
| G04 | Actual passing typing/identity/snapshot/recovery worksheet from 04; optional overlay limits have explicit follow-ups | Accepted: [worksheet](04-manual-worksheet.md), implementation `0aa2ca7`, user-confirmed Mac/LK7 checks |
| G05 | Reviewed key assignments, shared selector/identity, compiled profiles and actual EurKEY Next typing checks | Pending |
| G06 | Final architecture decision grounded in G04, existing profiles and editor requirements; alternatives/sources and 07/08 specifications | Accepted planning, 2026-10-04; 06B decision and revised plans |
| G07-export | Accepted 07A: schema/version, action preservation, export/API/path ownership, existing identity/digest, errors and consumer instructions | Pending |
| G07 | All 07 offline/editor acceptance, including save/reopen/export and matching build behavior | Pending |
| G08 | 08 offline integration plus explicit flash session, running identity and typing/overlay checks | Pending user session |

Settled: Zig 0.16.0, LK7/macOS first, small overlay, Danish profile for 04,
QWERTY + Mac shortcuts + EurKEY Next for 05, compiled keymaps, local commits only.
Open: concrete thumb/layer/shortcut assignments in 05; architecture evidence in
06; supported macOS overlay behaviors; next platform/board and available hardware.
Ask about those when concrete proposals/evidence exist. New languages and a
material architecture scope change require the user's decision before that work.

## Dispatch waves

1. **Start:** coordinator inspects baseline, establishes leases, dispatches 01,
   06A research, and 09A documentation (at most three workers).
2. **After G01:** run 02 firmware and 03 overlay concurrently. A third worker may
   finish independent research/inventory. Keep their published contract frozen.
3. **Live baseline:** coordinator integrates/checks 02+03, prepares 04, and waits
   for the user to start the hardware session. Independent research/diagrams may
   continue; no agent flashes or fabricates a hardware pass.
4. **Architecture:** after G04, finalize 06 using existing profiles and editor
   requirements; personal assignments are deferred until the finished editor.
5. **Editor/export:** after G04/G06, implement 07A including shared selection.
   At G07-export, implement 07B editor UI and 08A backend.
6. **Build/flash UI:** after G07 and accepted 08A, transfer GUI ownership to 08B,
   integrate/check, then wait for its explicit manual flash/acceptance session.
7. **Personal profile:** after G07/G08, the user creates 05 through the finished
   editor, with reviewed assignments and an explicit hardware acceptance session.
8. **Expansion:** refresh 09A matrices against observed results. Only a selected,
   separately scoped 09B target begins implementation; others remain deferred.

## Completed leases and integration queue

| Agent / task | Exact writable paths | Base / contract revision | Next checkpoint | State |
| --- | --- | --- | --- | --- |
| protocol / 01 | Released to coordinator; frozen contract | `5b092ec` / v2 | Consumers request amendments | Accepted |
| firmware / 02 | Released to coordinator; exact changed paths in handover | `4fd4c66` / G-live-offline | Manual 04 only after user starts hardware task | Accepted |
| overlay / 03 | Released to coordinator; exact changed paths in handover | `4fd4c66` / G-live-offline | Manual 04 only after user starts hardware task | Accepted |
| architecture / 06A | Released; coordinator owns future 06B dispatch | `2762d91` / research | G04 passed; final decision ready | Accepted |
| inventory / 09A | Released; coordinator owns future refresh | `99c1dbe` / inventory v1 | Refresh after observed acceptance | Accepted |

Coordinator records exact paths before dispatch; this table supersedes broad
package suggestions in plans. Git/index, build/manifests, central docs, shared
fixtures, and final checks remain coordinator-owned unless explicitly reassigned.
Ownership transfers require the previous owner to stop writing first.

Integration queue: 02/03 accepted; both workers stopped and released all listed
source leases to coordinator. The historical lease rows above describe their
completed assignment scope. No worker is active. Global check/install lane:
**coordinator-owned**, workers run only scoped checks against frozen dependencies.
Planning-only validation on 2026-10-04: local Markdown links resolve,
`git diff --check` and `zig build check` pass; source inventory is unchanged and
no hardware tool ran. This does not release any implementation gate. Do not
reuse this result as evidence for later source changes.

## Session log and recovery

| Date | Event | Evidence / next action |
| --- | --- | --- |
| 2026-10-04 | Execute plan 11 offline research and USB recovery | `2972bc6`, `c9ea3a1`, `2e30e9d`; target runtime defect demonstrated/fixed; full checks pass; bounded Mac-only session prepared, explicit hardware authorization pending; R4/R5 gated |
| 2026-10-04 | User stopped trial-and-error recovery and paused original workflow | Plan 11 and recovery handoff are the direct next task for a new session; research before standard input, custom codes and flashing; latest `637fd71` still fails live configuration |
| 2026-10-04 | Subagent execution structure prepared; no implementation started | Start from the fresh-session prompt in the workflow |
| 2026-10-04 | User authorized offline subagent execution and local commits; clean `ab66f12` inspected | Zig `/Users/clorz/.zvm/0.16.0/zig`; dispatch 01/06A/09A; no hardware access |
| 2026-10-04 | Protocol wire proposal/literal fixture checkpoint committed | `c3db81a`; codec/recovery implementation active; G01 pending |
| 2026-10-04 | 09A source-backed matrices accepted, ownership released | `99c1dbe`; no new target selected or hardware support claimed |
| 2026-10-04 | 06A architecture comparison accepted, ownership released | `2762d91`; native recommendation provisional; G06 awaits G05 |
| 2026-10-04 | G01 accepted; codec/session/replay and shared LK7 identity integrated | `c15d182`, `5b092ec`; check/check-full passed; no hardware access |
| 2026-10-04 | Dispatch 02 firmware and 03 overlay against frozen G01 | Exact disjoint leases above; coordinator owns build glue and stable joint checks |
| 2026-10-04 | Accept integrated 02/03 and G-live-offline; release worker leases | `6c83623`, `4fd4c66`; 325 tests, check/check-full, ten boards, parity, offline GUI/replays passed; no hardware access |
| 2026-10-04 | Prepare identified 04 artifacts and rollback; wait for user hardware session | Worksheet contains SHA-256, shared digest and recovery preparation; G04/G05 remain pending |
| 2026-10-04 | User requested mise monorepo workflow; migrate terminal orchestration | [Tooling plan](10-mise-monorepo.md); package-owned tests, root integration-only Zig build, typed mise tasks/completion; offline full checks passed; hardware G04 remains pending |
| 2026-10-04 | Diagnose stalled hardware flash and correct invalid UF2 metadata | `2089219`; missing RP2040 family flag/ID fixed and all artifacts validated; FSKit open syscall still stuck, user physical reconnect requested; G04 remains pending |

Append short entries for accepted gates, blockers, ownership transfers, and user
decisions. Put detailed results in the relevant handover, not duplicate logs here.
On resume, reconcile tracker entries with HEAD/status and actual files. Treat
old Active assignments as interrupted until the coordinator verifies their work;
do not reset, stash, or overwrite it. Reassign only after preserving the partial
result and documenting which check/contract still needs acceptance.
