# Central milestone tracker

## Direct next task: bounded USB/HID recovery hardware session

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
| R-custom | Waiting-user | [Live custom run](../research/usb-hid-custom-contract.md): flash/configuration pass; SDL enumeration filter fixed at `bceadb0`, vendor collection opens; actual live/control/input results pending |
| R-flash | Planned | Only after R-custom; bounded discovery/failure fixtures, identity/ambiguity and running verification |

Research workers have stopped and released all leases. The coordinator owns
all integration. Source remains Zig 0.16.0 with the immutable MicroZig pin;
all commits are local. Original G04 and 05–09 remain unaccepted/deferred as before.

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
| 04 | [Live acceptance](04-lk7-hardware-acceptance.md) / [handover](handovers/04-hardware.md) | Waiting-user | G-live-offline; user starts session | Run the identified manual worksheet after explicit hardware task | Coordinator with user / none |
| 05 | [EurKEY Next](05-eurkey-next-mac-keymap.md) / [handover](handovers/05-keymap.md) | Planned | G04; reviewed assignments | Review QWERTY diagram, add shared selector and profile, then manual tests | Unassigned / none |
| 06 | [Architecture](06-editor-architecture-research.md) / [handover](handovers/06-architecture.md) | Planned | 06A may start now; final decision needs G05 | Sourced comparison, then reconcile actual profile requirements | Unassigned / none |
| 07 | [Editor](07-compiled-keymap-editor.md) / [handover](handovers/07-editor.md) | Planned | G05 and G06 | Schema/export contract first, editor UI second | Unassigned / none |
| 08 | [Build/flash](08-build-and-flash-workflow.md) / [handover](handovers/08-build-flash.md) | Planned | 08A: G05, G06, G07-export; 08B: G07 | Fake-tested backend, then serialized GUI integration/manual acceptance | Unassigned / none |
| 09 | [Expansion](09-platform-and-board-expansion.md) / [handover](handovers/09-expansion.md) | Planned | 09A may start now; target work needs selection and accepted baseline | Capability inventory and separately scoped target plans | Unassigned / none |

## Partial deliverables for parallel dispatch

| Task | Initial status | Writable scope | Acceptance / release |
| --- | --- | --- | --- |
| 06A | Accepted | Architecture research document; 06 handover | `2762d91`; sourced comparison; final editor decision awaits G05 |
| 06B | Planned | Architecture decision; revised 07/08 plan proposals | G05, source-backed decision, coordinator acceptance within agreed scope |
| 07A | Planned | New schema/export Zig source and dedicated tests | G05/G06, lossless format/API and G07-export accepted |
| 07B | Planned | Editor UI and dedicated UI tests | G07-export, supported save/edit/export workflow; completes 07 criteria |
| 08A | Planned | Build/flasher backend and dedicated fake tests | G05/G06/G07-export; no GUI/hardware; partial backend only |
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
| G04 | Actual passing typing/identity/snapshot/recovery worksheet from 04; optional overlay limits have explicit follow-ups | Pending user session |
| G05 | Reviewed key assignments, shared selector/identity, compiled profiles and actual EurKEY Next typing checks | Pending |
| G06 | Final architecture decision grounded in G05; alternatives/sources and 07/08 specifications | Pending |
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
4. **Personal profile:** after G04, review concrete assignments and implement 05.
   06 research may refine in parallel; accept its final decision only after G05.
5. **Editor/export:** after G05/G06, implement 07A. At G07-export, run 07B editor
   UI and 08A backend concurrently with disjoint leases.
6. **Build/flash UI:** after G07 and accepted 08A, transfer GUI ownership to 08B,
   integrate/check, then wait for its explicit manual flash/acceptance session.
7. **Expansion:** refresh 09A matrices against observed results. Only a selected,
   separately scoped 09B target begins implementation; others remain deferred.

## Completed leases and integration queue

| Agent / task | Exact writable paths | Base / contract revision | Next checkpoint | State |
| --- | --- | --- | --- | --- |
| protocol / 01 | Released to coordinator; frozen contract | `5b092ec` / v2 | Consumers request amendments | Accepted |
| firmware / 02 | Released to coordinator; exact changed paths in handover | `4fd4c66` / G-live-offline | Manual 04 only after user starts hardware task | Accepted |
| overlay / 03 | Released to coordinator; exact changed paths in handover | `4fd4c66` / G-live-offline | Manual 04 only after user starts hardware task | Accepted |
| architecture / 06A | Released; coordinator owns future 06B dispatch | `2762d91` / research | Final decision pending G05 | Accepted |
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
