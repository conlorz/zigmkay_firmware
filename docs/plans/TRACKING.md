# Central milestone tracker

## Unified Try it out view planning (2026-10-06)

The user selected variant A, with the companion below the typing area, and
requested [plan 15](15-try-it-out.md). It combines draft testing and Practice
under two main views, Editor and Try it out, with free typing as the baseline
and the existing typing test available by button. The selected
[mockup](mockups/try-it-out/01-companion-below.png) is retained as design reference.
Planning is complete; implementation is pending a subsequent user request.
No application behavior, test-engine behavior or hardware gate has changed.

## Docked key inspector implementation (2026-10-06)

The user chose [key-creation mockup 2](mockups/key-creation/02-inspector-dark-macos.png)
and requested an implementation plan linked from the editor handover. See
[plan 14](14-docked-key-inspector.md) and [the follow-up handover](handovers/07-editor.md#selected-follow-up-docked-key-inspector-2026-10-06).
The implementation request covers the staged per-key editing session, docked
native UI, host labels, embedded picker and revised geometry. Session checkpoint
`1e70caa` and label/catalog checkpoint `929c54c` are committed. Final integration
checks and native capture evidence are recorded in the editor handover. Existing
approved goldens remain intact pending review of the intentional redesign.
No hardware session or golden replacement is authorized by this implementation.

## Save the selected dropdown project (2026-10-06)

Profile selection now opens its associated project file instead of regenerating
the built-in template. Save updates that selected directory. New dropdown
projects are materialized under `projects/<profile>/project.zon`, and custom
directories opened through Open are remembered per profile in the atomic local
`projects/profile-projects.zon` registry. Fixtures remain isolated from personal
files. Regression tests cover editing, saving, switching away and back, restart,
and refusing to replace an unreadable existing project with a template.

## Remember personal editor project (2026-10-05)

The user requested opening their real layout directly after restart. The editor
now restores the last successfully opened/saved project using an atomic absolute
path preference in `projects/startup-project.zon`. Before a preference exists,
the prepared `projects/eurmac` is the starting project when available. The
existing EurKEY draft remains fallback, with diagnostics for an unavailable
remembered project. Tests cover preference persistence and restoring edited
personal project data into a fresh model. Startup does not build or flash.

## Flash waits for a current build (2026-10-05)

The user requested rebuilding when Flash encounters an old build, unless a build
is already running. Flash now immediately builds missing/stale results, reuses a
running matching build and queues transfer of its verified result. Draft changes,
failed/cancelled builds and callback-review problems discard the queued transfer.
Freshness failures at transfer time rebuild the artifact. The queued request
captures the HID checkbox choice and is consumed once. Pure gate tests and the
real offline changed-layout UF2 test pass; no hardware session was started.

## Automatic firmware builds after layout edits (2026-10-05)

User-requested layout changes now schedule a firmware build after a 750 ms
debounce. Startup and deterministic UI fixtures remain idle. Transfer, bootloader
entry and reconnect verification defer builds; external callback changes require
review/refresh. No unchanged failure is retried automatically and no build flashes.
The scheduler regression cases and real changed-layout LK7 UF2 build pass in the
67-test companion suite. See [the workflow guide](08-editor-verification.md).

## Optional HID bootloader on Flash (2026-10-05)

The user requested completion of HID bootloader entry and an optional attempt
when clicking Flash; hardware acceptance remains deferred. The native editor
now provides **Enter bootloader via HID**, enabled by default. Standalone and
companion-hosted editors use one bounded attempt, bind the verified running
profile independently of the draft, require advertised support and never resend
the bootloader command automatically. Unsupported/absent devices use manual
BOOTSEL while the existing transfer keeps waiting for the recovery volume.
See [implementation evidence](../evidence/editor-hid-bootloader-2026-10-05.md).
Implementation `300b52a`: 65 companion-package tests, full offline checks and
142 native captures/semantic interactions pass. This does not accept the physical HID
transition, edited-profile typing or full G08.

## Autonomous personal-profile preparation (2026-10-05)

The user requested autonomous progress and immediate continuation to the next
offline step. The separate `eurmac` personal-profile candidate is implemented;
see [assignments, installed layout provenance and evidence](05-candidate.md).
It is available in the existing editor selector, with four reachable layers,
mirrored Mac modifiers, Command shortcuts and deliberate recovery. Existing
profiles remain unchanged. Project checks, full offline matrix, candidate export,
candidate LK7 firmware build and real offline processor traces pass.
This advances 05 offline; G05 and full G08 remain open. No hardware operation or
visual/user acceptance is implied. The successful toolbar transfer/reconnect at
`1c44788` is established evidence; older statements below that no such 08 run
exists are historical. Edited-profile typing and latest visual approval remain
unverified.

## Latest editor follow-ups (2026-10-05)

The separately requested real LK7 toolbar build/flash test passed after physical
BOOTSEL reconnect; see `1c44788` and the firmware workflow evidence. Toolbar
actions run directly and discover the recovery drive automatically. HID labels,
home row mod editing, layer labels and named companion signals are implemented.
Typing tryout duplicate widget IDs are fixed at `d58a508`.

The current follow-up adds taller scrollable editing windows with fixed footers,
editable key filtering, and OS-keyboard chord drag/drop to split keys and inspector
Tap/Hold fields. Native key-search and chord-assignment scenarios pass, including
modifier preservation and undo/redo; 900×600 combo/callback/file windows were
captured without duplicate widget errors. Root offline checks pass.

The user authorized implementation of [13 typing practice](13-typing-practice.md).
English sentence generation, complete Zig-file copying, OS/draft input, scoring,
pause/restart and the native Practice panel are now implemented. Offline and
native acceptance scenarios pass; user hands-on testing remains pending. See
[implementation evidence](../evidence/typing-practice-2026-10-05.md). Personal
bests are session-local; persistent history and typed-file saving are deferred.

User feedback prioritized learning the layout while practising. Practice now
centers a large current word, highlights the next character, scrolls the context
and embeds an optional companion keyboard, enabled by default. Live companion
sessions share verified running-profile telemetry; standalone practice names the
draft preview. Gold hints distinguish expected keys from actual pressed states.
See [refinement evidence](../evidence/typing-practice-refinement-2026-10-05.md).

## Recovery, G04, G06 and full G07 accepted; 08 integrated offline

Step 08 implementation was authorized on 2026-10-05 from clean `3543b42`.
Backend `0686909`, bootloader `888ed37` and native workflow `77a3dc4` are locally
committed. Full offline checks pass, including ten boards and LK7 artifact parity.
See the [08 handover](handovers/08-build-flash.md) for frozen APIs and evidence.
No worker remains active. G08 still requires new visual approval and a separately
authorized hardware session; no BOOTSEL, transfer or typing result is claimed.

07 implementation authorized on 2026-10-04, starting from clean planning HEAD
`eef2c45`. G07-export is frozen at `016cf7d`: versioned schema, lossless
adapters, immutable callback snapshots, atomic persistence, deterministic export,
shared profile selection, bounded jobs and the native real-processor runner.
Package checks and `mise //:check-full` passed, including ten-board artifacts,
standalone/root LK7 parity and literal callback/action traces. See the
[contract](../../keymap-project/README.md) and [handover](handovers/07-editor.md).
Full G07 is accepted at implementation `7168c13`: 40 companion tests, complete
`check-full`, 64 state/theme/scale captures, semantic interactions and approved
golden regression checks passed. Native EurKEY composition and independent-window
checks passed; the user confirmed dialog telemetry continuity and explicitly
approved the screenshots. See [evidence](07-editor-acceptance.md) and the
[self-verification guide](07-editor-verification.md). No parallel writer is active.
GUI ownership is released for future 08B after accepted 08A/explicit assignment.
Plan 12 and all hardware operations remain deferred.

Additional deferred milestone: [12 device keymap readback](12-device-keymap-readback.md).
User requests complete layer/combo/configuration transfer in 12A; custom Zig
source recovery is follow-up 12B with no current use case. No owner,
implementation start, hardware session or main-sequence change is implied.

06B finalized in the editor planning session on 2026-10-04: separate native
editor, full existing action set, named layers and bulk editing, offline draft
runner with EurKEY text, attached externally edited Zig callbacks. See the
[decision](06-editor-architecture-decision.md) and
[requirements](06-editor-requirements.md). That decision accepted planning only;
07 implementation is complete under the separate authorization above. Step 08 now
has the separate implementation authorization recorded above; no new hardware
session has started.

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
| 07 | [Editor](07-compiled-keymap-editor.md) / [handover](handovers/07-editor.md) | Accepted | G04 and G06 | Frozen contracts and approved native editor; future 08 integration | Coordinator / 07A `016cf7d`, 07B `7168c13` |
| 08 | [Build/flash](08-build-and-flash-workflow.md) / [handover](handovers/08-build-flash.md) | Integrated offline | 08A: G06, G07-export; 08B: G07 | Review new captures; separately authorize small edited-profile hardware acceptance | Coordinator / `77a3dc4` |
| 05 | [EurKEY Next](05-eurkey-next-mac-keymap.md) / [handover](handovers/05-keymap.md) | Integrated offline candidate | Autonomous candidate authorized; full acceptance still requires G08/manual checks | Candidate is editable at `projects/eurmac`; live host mapping and personal comfort remain pending | Coordinator / candidate, G05 open |
| 09 | [Expansion](09-platform-and-board-expansion.md) / [handover](handovers/09-expansion.md) | Planned | 09A may start now; target work needs selection and accepted baseline | Capability inventory and separately scoped target plans | Unassigned / none |

## Partial deliverables for parallel dispatch

| Task | Initial status | Writable scope | Acceptance / release |
| --- | --- | --- | --- |
| 06A | Accepted | Architecture research document; 06 handover | `2762d91`; sourced comparison; G04 now releases final editor decision |
| 06B | Accepted | Architecture decision; revised 07/08 plans | Source-backed native decision and explicit user feature answers; planning only |
| 07A | Accepted | Frozen model/export/source/selector/runner/jobs contract 1 | `016cf7d`; full offline matrix/parity and emitted traces; maintenance only |
| 07B | Accepted | Native editor, complete workflow and approved dark/light captures | `7168c13`; full checks, 40 tests, 64 captures and approved goldens; GUI lease released for future 08B |
| 08A | Accepted offline | Immutable build/artifact manifests and reused flasher/hash boundary | `0686909`, corrections in `77a3dc4`; seven jobs/backend tests and full checks pass |
| 08B | Integrated offline | Native selected-profile build/explicit transfer/reconnect/bootloader integration | `77a3dc4`; full checks and 88 captures; visual/manual G08 pending |
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
| G07-export | Accepted 07A: schema/version, action preservation, export/API/path ownership, existing identity/digest, errors and consumer instructions | Accepted `016cf7d`; [contract](../../keymap-project/README.md), full offline checks and native emitted traces |
| G07 | All 07 offline/editor acceptance, including save/reopen/export and matching build behavior | Accepted `7168c13`; [workflow/native/visual evidence](07-editor-acceptance.md), user-approved goldens and passing offline regression checks |
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
| 2026-10-05 | User authorized all code-review refactors, focused commits and a push to the fork | Integrated through `9c14cba`; [development evidence](../development.md): full offline matrix/parity, workspace/task checks and GUI golden/scenario acceptance passed. No hardware or milestone acceptance changes. |
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

| 2026-10-04 | Accept complete G07 | Frozen 07A `016cf7d`; native editor `7168c13`; full offline checks, 40 tests, 64 state captures/interactions and approved goldens pass; user confirms dialog continuity and approves both themes/scales; plan 12/hardware deferred |
