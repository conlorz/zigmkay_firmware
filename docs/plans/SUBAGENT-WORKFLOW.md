# Fresh-session subagent workflow

This is a planning document, not an instruction to start implementation merely
by reading it. The user will initiate execution in a new session. Use the
[central tracker](TRACKING.md) for all status, gate, and assignment changes.

## Roles and startup

Use one coordinator and up to three workers when four agent slots are available.
Use fewer workers if capacity is lower or no independent task is ready. Never
split a dependency just to keep every slot busy.

The coordinator:

1. Reads workspace/repository AGENTS.md, roadmap, tracker, this workflow, relevant
   plans, and accepted input handovers. Inspects HEAD, branch, status, `.zigversion`,
   pinned Zig availability, and existing interrupted work.
2. Confirms the session's authorized scope from the user's starting instruction.
   A request to plan does not authorize implementation. An offline execution
   request does not authorize live device access, BOOTSEL, or flashing.
3. Reconciles any stale status, records the starting revision, and chooses ready
   tasks whose dependencies, interfaces, writable paths, and slot budget fit.
4. Grants exact write leases and dispatches self-contained worker instructions.
   Research uses current primary sources with links/dates; code stays Zig.
5. Integrates worker checkpoints, runs stable checks, makes frequent focused local
   commits, accepts handovers, and releases dependencies. Reports actual outcomes
   and pending gates to the user before ending a session.

Workers read both agreements, their plan, tracker, and required handovers. They
work only within the dispatch scope, request cross-owner edits through the
coordinator, and provide evidence at each checkpoint. They do not independently
expand the milestone, spawn more agents, or begin its dependent plans.

Each dispatch must include a complete brief rather than depend on earlier chat:

```text
Task ID and bounded deliverable: ...
Canonical checkout and base revision: ...
Read these plan/AGENTS/tracker/handover files: ...
Accepted input contract revision and APIs to consume: ...
Exclusive writable files (including dedicated tests and handover): ...
Files owned by coordinator/other workers; integration requests: ...
Offline check commands and output/check-lane constraints: ...
Checkpoint, required evidence, and stop condition: ...
No Git/index operations, hardware access, new languages, or nested agents.
Report when paused for coordinator review; do not start a dependent milestone.
```

## One shared checkout

All agents use `zigmkay_firmware/`. Do not create sibling clones, branch worktrees,
or separate package repositories. No worker stages, commits, stashes, resets,
changes branches, rebases, pushes, or creates pull requests. The coordinator is
the only Git/index writer and makes all focused commits inside the monorepo.

The coordinator exclusively owns:

- Root/package `build.zig`, `build.zig.zon`, `.zigversion`, catalog/registry changes,
  cross-package publication/import glue, and explicit generated-source updates.
- `AGENTS.md`, root README, roadmap, tracker, workflow, shared handover rules,
  changes to other milestones' plans, and shared integration tests/fixtures.
- Integration checks that install to shared `zig-out`, `check`, `check-full`,
  final artifact manifests, and manual-session coordination.

A worker may own a whole portable package while defining a contract (01's
protocol/model or 07A's schema). Freeze it before its consumers begin. Existing
`layout-model` types/physical geometry and profile identity publication are shared
boundaries; changes need an explicit exclusive lease or coordinator integration.

Suggested source ownership, narrowed to exact files in each dispatch:

| Worker | Source ownership | Own tests/docs | Cross-owner requests |
| --- | --- | --- | --- |
| 01 | `device-protocol/src/`, `companion-model/src/`, agreed headless replay source | Dedicated protocol/session tests, protocol doc, 01 handover | Build glue, shared types/fixtures |
| 02 | Agreed `zigmkay/src/` telemetry/USB/loop files and LK7 integration entry point | Dedicated firmware transport tests/docs, 02 handover | Protocol changes, identity build publication |
| 03 | `zigmkay-companion/src/` adapter/UI, agreed Zig native-label files | Dedicated adapter/render tests/docs, 03 handover | Shared geometry/model API, C bridges, GUI build files |
| 05 | New named keymap profile and agreed profile data files | Dedicated mapping tests/diagram, 05 handover | Shared selector, firmware/GUI imports, identity glue |
| 06A/06B | Dedicated architecture research/decision document | Source notes and 06 handover | Spikes/new dependencies/languages, 07/08 plan revisions |
| 07A | Agreed new Zig schema/export source | Dedicated model/export tests and 07A handover section | Package build integration, shared identity/types |
| 07B | Agreed editor UI files | Dedicated UI tests and 07B handover section | Export API changes, build glue |
| 08A | Agreed Zig build-process/flasher backend files | Dedicated fake-process/volume tests and 08A handover section | Shared build API/manifest glue, GUI |
| 08B | GUI files after 07B releases them | Dedicated integration docs/tests and 08 handover | Backend changes, real hardware session |
| 09A | Dedicated platform/board capability documents | Inventory evidence and 09 handover | Catalog/source edits, new target implementation |

04 is coordinator-led interactive acceptance; worker preparation/fixes require
separate leases. 05/08 manual acceptance is also coordinator-led. Names of new
packages/files are decided before dispatch, not invented independently by two
workers. Multiple tasks sharing one handover file run serially or the coordinator
collects their sections; only one writer owns that file at a time.

## Contract freezes and change requests

G01 freezes wire/version/API, snapshot ordering, identity, limits, and fixtures.
02 and 03 consume the same accepted revision. G05 adds shared profile selection
and builds on G01 identity. G07-export adds editor schema/export and reuses that
identity. 08 adds artifact/transfer manifests rather than a competing digest.

If a consumer discovers a defect, report the affected contract, minimal proposed
change, downstream impact, and tests. The coordinator pauses affected consumers,
assigns one writer, integrates/checks the amendment, versions the handover, and
redispatches against the updated revision. Never silently patch another agent's
contract or keep two locally divergent protocol definitions.

## Checks, checkpoints, and commits

Workers may run scoped, hardware-free checks against frozen dependencies. List
the exact proposed commands in the dispatch. Package checks must not overwrite
another worker's outputs or run shared source-inventory/install checks while
files are changing. Request the coordinator's check lane where needed.

At an integration checkpoint:

1. Worker stops editing the submitted files and reports changed paths, contract
   changes, commands/results, limitations, and the handover draft. It remains
   paused until the coordinator releases or reassigns its lease.
2. Coordinator reviews the exact diff and verifies no unrelated files entered it.
   Integration into build files/shared fixtures happens under its exclusive lease.
3. For final checks, all writers pause; the tree must stay stable for the entire
   check and artifact build. Run appropriate Zig checks, normally `check`, plus
   `check-full` for firmware/build/API changes. Do not run redundant full checks
   without new changes or a remaining concern.
4. Stage explicit owned paths, inspect the staged diff, and make focused local
   commits. Never use `git add .` to sweep in another worker's unfinished work.
   If a checkpoint requires multiple workers' changes, state that integration
   boundary explicitly and commit only the coherent checked result.
5. Finalize the handover with actual code commit IDs, verification commands and
   outcomes, accepted contracts, pending manual work, and ownership release.
   Commit tracking/handover updates separately if needed to reference code commits.
6. Accept the gate only when its criteria pass, then dispatch newly ready tasks.

Gate evidence must correspond to the complete source/build tree of the recorded
integrated revision. A paused shared tree can still contain another worker's
uncommitted prerequisites. Integrate all necessary paths as a coherent checked
result before accepting it; otherwise label that check working-tree-only, keep
the gate pending, and check after integration. Never attribute a WIP-dependent
passing result to a partial commit that cannot reproduce it.

Pause an affected lane on failures; preserve its changes and reproduce the
defect offline. Other independent lanes can continue. Source-inventory guards,
generated checks, portable checks, and ten-board compilation remain meaningful.
Do not hide failures by shrinking tests or making live operations automatic.

## User gates and continuation

Run ready work within the session's authorized scope until it is complete or
only a real dependency/user gate remains. Waiting for 04 does not prevent
06A/09A or separately assigned diagrams. Waiting for a selected extra target
does not authorize implementing all catalog boards.

Before a manual session, prepare reviewable identified firmware/GUI/rollback,
instructions, and worksheet. Ask for the concrete missing decision/session,
explaining the relevant gate. Never count elapsed time as approval. Keep pending
rows honest and do not leave idle agents running to wait for user hardware input.

At session end, record integrated revisions, completed checks, pending work,
leases released/interrupted, and the exact next ready move. A fresh coordinator
can resume from files alone without the previous chat or agent mailboxes.

## Suggested starting message for the new session

```text
Start the offline subagent workflow in zigmkay_firmware.
Read AGENTS.md, docs/plans/TRACKING.md, docs/plans/SUBAGENT-WORKFLOW.md,
the roadmap, and required plans/handovers first.
Act as coordinator with up to three workers in the shared checkout.
Start 01 protocol, 06A architecture research, and 09A capability documentation.
Accept the protocol handover before dispatching 02 firmware and 03 overlay
in parallel. Continue ready offline tasks through their documented gates;
prepare 04 and report when a user decision or hardware session is needed.
Keep implementation Zig, make focused local commits, never push or create
worktrees, and do not access or flash hardware in this offline flow.
```

This starts the initial implementation flow when the user sends it. Later waves
resume from the tracker after their user/hardware gates are resolved; they do not
need a recreated workspace or a different orchestration design.
