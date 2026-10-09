# 07 handover: schema/export contract and visual editing

State: **07A and 07B Accepted; full G07 released**. G07-export frozen at `016cf7d` on 2026-10-04.
Producer/reviewer: coordinator, with exclusive model/integration/document ownership.
Plan: [07](../07-compiled-keymap-editor.md). Rules: [handover format](README.md).

## Follow-up: physical LK7 uses native text and verified telemetry (2026-10-09)

The user confirmed the physical LK7 on macOS works correctly in normal text
fields. The prior host-substitute fixes and their simulated test oracle did not
represent that case. The starting tree was clean `31b8dfc`; implementation
checkpoint `9949ca4` removes the second keymap pass from Free typing.
`c61e8f7` freezes matching captions at post-flash monitor startup; `5e52f03`
compares actual SDL event conversion with the ordinary text-entry oracle.

Free typing uses an ordinary DVUI TextEntry with committed OS text and standard
editing events. It neither starts an offline runner nor consumes SDL text/key
input for simulation. Native edits happen in their input frame even when draft
preparation has failed or is pending. Text survives draft edits and input-source
changes. Explicit draft Typing Test simulation remains available independently.

The free companion consumes actual telemetry, with captions from a frozen
matching layout after complete identity verification. Connect companion and
`--editor --live` explicitly enable that path; finite editor entry points also
support the connection. Missing/mismatched telemetry shows no fabricated draft
keyboard. Stale data clears held keys and momentary layers. Captions retain
Editor parity, including Mac Option and complete Tap/Hold actions.

New offline integration has two independent paths:

- A separate ordinary DVUI TextEntry and the free field receive the same native
  edits. Every step checks immediate text, including Unicode, caret edits,
  selection replacement, clipboard paste, one Backspace, repeat, Delete and
  foreign-window isolation. No runner job, sequence advance or simulated pressed
  key is allowed.
- The real firmware Processor receives physical key indices and timestamps;
  observer events are encoded/decoded through the device protocol before the
  native view reads them. A layer-only left thumb must appear and change layers
  despite emitting no OS key. Pinky index 19 taps Backspace once and holds Orange
  only after its tapping term. Active transparent layers, exact Editor captions,
  release, stale recovery and native text during stale telemetry are asserted.

Both are in the capture matrix across dark/light themes, 1×/2× density and
1536×1024, 1152×768 and 900×600 windows. Package tests/build and aggregate `check`
pass. The full native suite passes **235 captures**, panel geometry and semantic
interactions. The strengthened SDL route additionally passes all 12
theme/density/size combinations; offline smoke and tray checks pass. Hardware behavior is
not claimed as tested: no vendor HID connection, firmware flash or device
operation was performed by these checks. All worker leases are released.

## Follow-up: companion captions and Mac thumb input (2026-10-09)

The user confirmed the reported incorrect thumb display and layer changes occur
in Try it out with the Mac keyboard. Starting tree was clean `afebb85` on
`local/monorepo`. Caption checkpoint `752d52e`, input checkpoint `6297f46` and
guidance correction `3d1d210` are committed locally. The delegated caption worker
released its files; the coordinator owns all future integration.

Both companion caches now retain an Editor `labels.keycap` caption separately
from native translated output. The renderer shows the same complete Tap/Hold
action, layer IDs, custom callbacks and host modifier symbols as Editor, including
macOS ⌥ Option and ⌘ Command. It fits the full caption against actual pixel-snapped
font metrics and reserves space for TAP/HOLD guidance. The standalone companion
loads the same local macOS font fallbacks. Translated labels still drive practice
character matching; hold-only symbols cannot be mistaken for output characters.

Draft host input retains QWERTY finger positions and derives thumb substitutes
from base-layer tap usages. In the Mac candidate, Space→30, Tab→31, Return→32 and
Backspace→33 trigger the actions shown in Editor. Previously the fixed order
mapped Return→31, Backspace→32 and Tab→33. Explicit thumb taps reserve their host
keys first; duplicates or non-key taps receive unused Space/Return/Backspace/Tab
substitutes in that order. Mapping stays anchored to the base layer through
layer changes, so key-up releases the same physical position. The offline
processor determines tapping terms and layer/modifier transitions.

Verification on the complete source tree of `3d1d210`, using Zig 0.16.0:

- `mise //zigmkay-companion:test`, `:build`, `:smoke` and `mise //:check` pass.
  Aggregate checks report unchanged source contents/inventory and no hardware
  tool execution. Real processor tests cover all four Mac host thumb mappings,
  a tap before 180 ms, hold activation after the configured term, modifier holds
  and release to base state. Cache/guidance tests cover caption parity, custom
  Hold callbacks, Option and separate translated output.
- `mise //zigmkay-companion:editor-check` passes all **211 captures**, panel
  geometry, Retina/non-Retina readback and semantic interactions. New
  `free_mac_thumbs` captures participate in all four theme/density combinations.
- Four additional `free_mac_thumbs` captures pass at 900×600 (dark 1×, light 2×)
  and 1152×768 (dark 2×, light 1×). The two minimum-size images were inspected;
  complete thumb and modifier captions remain visible. Outputs are under
  `.zig-cache/editor-acceptance/thumb-mac-*.png`.
- Changed Zig formatting and diff whitespace checks pass. Cached check logs are
  `.zig-cache/thumb-{companion-test,aggregate-check,editor-check,companion-build,companion-smoke}.log`.

No hardware access, firmware change, push, PR, new dependency/language or
committed golden replacement is included. Existing replacement-golden review
for the earlier editor redesign remains pending. A running desktop process must
be quit through the tray and restarted to load the corrected executable.

## Selected follow-up: unified Try it out view (2026-10-06)

The user selected [variant A, Companion below](../mockups/try-it-out/01-companion-below.png)
and requested [plan 15](../15-try-it-out.md). The plan replaces the draft-test
launcher and Practice modal with Editor/Try it out main navigation, a free draft
typing field with Reset text, and an inline Typing Test mode using the existing
engine and functions. It specifies input ownership, automatic free-preview
preparation, snapshot freshness, companion identity and native offline checks.
The subsequent full implementation request is complete locally. Starting tree:
clean `394f790` on `local/monorepo`. State/text checkpoint `438ea6c`, unified
presentation `f33c687`, cleanup/documentation `f65106c`, responsive width
`2e036ec`, snapshot/failure handling `e081fd3`, translation/source diagnostics
`183cadc` and valid-session probe handling `0743834` implement the selected view.
All delegated file leases are released; the coordinator owns future integration.

Editor and Try it out are persistent main views. Pending inspector edits use
the existing Apply/Discard/Keep editing path. Free typing prepares/starts the
immutable applied draft automatically while focused, validates EurKEY, ignores
input during preparation and offers explicit Retry after failure. Its separate
UTF-8 buffer preserves text across navigation; Reset clears bytes, caret,
composition and held state without changing history or the scored session.
Project/snapshot/input-source replacement clears it with an inline explanation.
Control characters and non-text commands stay diagnostic data. Field blur
releases physical input while retaining a valid session for explicit diagnostic
probes; a sequence boundary rejects older output on refocus. Mode/tab/window
departure stops the runner, releases holds and pauses a test without resuming it.

The existing test engine, corpora, scoring, correction feedback, word focus,
context scrolling, paste preview, source choices, TAP/HOLD guidance and session
bests remain intact. The former Practice modal, Close action and Editor draft
launcher are removed. Test controls sit above the generous embedded companion;
free guidance always uses the draft, while verified live guidance is labelled
separately and stale live sources remain visibly stale. Diagnostics expands
inline. Callback controls remain in Editor. `--practice` enters Try it out /
Typing Test; normal startup remains Editor. The preview fills available width
and retains the native canvas scaling at both supported sizes and densities.

Verification on production revision `0743834` (Zig 0.16.0 through mise):

- `mise exec -- zig version`: `0.16.0`.
- `mise //zigmkay-companion:test`: passed, including lifecycle tickets, Unicode
  editing/control filtering and the real offline processor trace for edited
  key 10 emitting B. Held-key release keeps that process running; Reset/restart
  reuses the prepared artifact and leaves the model identity unchanged.
- `mise //zigmkay-companion:editor-check`: passed 207 captures, containment,
  native pixel readback, duplicate-widget checks and semantic interactions.
  Both modes, themes, 1×/2× densities, 1152 × 768 and 900 × 600 are covered.
- Sixteen additional `zig build run -j4 -- --editor --fixture` runs passed with
  `--scenario free_input` / `practice_input`, both supported window sizes,
  `--density 1` / `2`, dark/light and `--screenshot` outputs prefixed
  `semantic-` in `.zig-cache/editor-acceptance/`. These exercise navigation,
  independent buffers, Unicode/composition reset, held state, Space after a
  control, test corrections, deliberate resume, focus loss and paste preview.
- `mise //:check`: passed all aggregate package/generated checks and the
  unchanged-source/hardware guard. No hardware tool executed.
- Pinned `zig fmt --check` on changed Zig files and `git diff --check`: passed.
- `mise //zigmkay-companion:editor-golden-check`: expected failure against the
  old dark 1× normal baseline (`GoldenImageMismatch`, mean RGB delta
  16.8837/255; 735627 significant pixels). Baselines and tolerances are unchanged.

Native captures remain in `.zig-cache/editor-acceptance/`. Representative free,
long Unicode, test/context and diagnostics images were inspected against
variant A, including minimum-size and light/2× evidence. Keys, current character
and actions remain contained. Captures normalize to 1536 × 1024, so minimum 1×
images are upscaled for comparison. Replacement-golden visual review remains
pending; design selection is not approval to overwrite native goldens.
No firmware, dependency, shared build API, C bridge or committed generated source
changed. No hardware acceptance, push or PR is claimed.

## Selected follow-up: docked key inspector (2026-10-06)

The user selected [mockup 2](../mockups/key-creation/02-inspector-dark-macos.png).
Implementation plan: [14: Docked key inspector and assignment editing](../14-docked-key-inspector.md).
Implementation started at `fa8d71a`, with the planning baseline `b9b660f`.
Existing G07 acceptance and the frozen version-1 schema/export/runner contract
remain the inputs to this follow-up.

The plan specifies independent Tap/Hold cards, component-preserving bulk edits,
explicit Unassign versus Inherit, Mac symbols, staged Apply/Cancel, a contextual
embedded picker, responsive geometry, and offline validation/capture coverage.
The user explicitly wants minimal popups: remove the key-action and search
popups; Advanced, validation, and pending-edit choices stay inline in the
inspector. This follow-up adds no custom modal dialogs.
Implementation checkpoints: `1e70caa` (per-key staged session and atomic batch
commit), `929c54c` (host labels and bounded action catalog), `f176d3b` (docked
UI, geometry, lifecycle and offline scenarios), `5e790cc` (same-frame session
lifecycle and native scenario stabilization), and `10a9c2a` (Repeat timing
conversion summary). All worker leases are released.
No firmware, schema, native bridge, dependency or generated source changed.

The inspector shows all populated Tap/Hold components, stages individual edits,
supports independent one-shot fields, and commits one validated snapshot.
Bulk edits retain each key's untouched components, timing and callback data.
Unassign stores `.none`; Inherit stores `null`, with lower-layer previews kept
separate. Clean/invalid Apply and Base Inherit are disabled. Selection, layers,
profiles, history, Copy/Paste, Save/Build/Flash/Test and other document workflows
resolve pending drafts using inline Apply/Discard/Keep editing decisions.
Advanced and dirty-close decisions also stay in the inspector. The old action
and search modal implementations are removed; reusable combo forms remain.

Verification includes compound actions with every optional field, mixed bulk
modifiers and field preservation, inherited overrides, validation/staleness,
Cancel/no-op Apply, one-step undo/redo, and save/reopen/export with callback bytes.
Four new real offline runner traces confirm explicit no-action blocking lower A,
transparent fallback to A, Clear Hold retaining B, and Clear Tap retaining Command.
Native scripted input covers search, drag/drop, mixed bulk Apply, all pending
choices, rejected Apply, chip removal, Cancel and same-frame Copy/Paste.

Actual native captures remain under `.zig-cache/editor-acceptance/`. Selected
dark/light normal and practice captures are copied into `docs/screenshots/` and
embedded in the [root README](../../../README.md); these are running native app
captures using an inert project fixture, not generated mockups or device evidence.
The dark captures have descriptive comparisons with the selected step-14 mockup.

Presentation deviations: test and callback controls use two central rows to keep
their actions visible; mode and category controls use native dropdowns; compact
modifier controls show all eight left/right bits in one row. The inspector
middle scrolls for compound/Advanced content while header/footer remain fixed.
The native Advanced scenario scrolls to its configuration controls. Existing
approved goldens remain intact pending explicit replacement review. No native
accessibility, hardware acceptance, push or PR is claimed.

Checks on implementation revision `10a9c2a`:

- `mise //:check`: passed, including all package tests, generated comparisons,
  and the unchanged-source/hardware guard. An earlier run correctly rejected a
  concurrent handover edit; the frozen-tree rerun passed.
- `mise //zigmkay-companion:test`: passed during integration; the final aggregate
  check also runs this package, including all new session and real-runner cases.
- `mise //zigmkay-companion:editor-check`: passed all 158 dark/light, 1×/2× and
  resized captures, panel/key containment, native pixel readback and semantic
  interactions, including the 1152 × 768 and 900 × 600 windows.
- Pinned `zig fmt --check` on all changed Zig files and `git diff --check`: passed.
- `mise //zigmkay-companion:editor-golden-check`: expected failure against the
  pre-redesign dark 1× normal baseline (`GoldenImageMismatch`, mean RGB delta
  11.4988/255; 546191 significant pixels). Baselines and tolerances are unchanged.
  New captures are available for explicit replacement-golden review; the README
  illustrations do not imply that approval.

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

### Accepted 07A contract freeze

Coordinator implementation/review: `ca76344`, `a5348e5`, `016cf7d` complete the
checkpoints below. Consumed accepted 04/06 and original 01 canonical identity.
Contract/schema/runner/build version 1 is frozen in
[the package contract](../../../keymap-project/README.md). This supersedes the
historical pending list below. APIs, bounds, ownership, errors, sources,
curated registration, shared build selection, explicit CLI workflow and consumer
job/reset/stale semantics are documented there.

Verification on the complete `016cf7d` code tree: `mise //:check-full` passed,
including all package/generated checks, ten-board artifacts, replay, offline
guard and standalone/root LK7 UF2 parity. Curated Danish create/save/reopen/
export built through the actual LK7 firmware path and native host runner with
the same manifest selector, which captures verified files into build caches.
Model package 22 tests, native runner 7 tests and process jobs 3 tests pass.
Generated literals cover all current actions, callback bytes/relative imports,
registered layer/Alt-Tab behavior, fresh-process reset and malformed frames;
real process tests cover cancellation, crash, timeout, bounded output and stale
results. Recorded warm-cache runner compilation: 1.536 s; startup 4.355 ms and
input roundtrip 3.251 ms. No hardware operation occurred.

Limits remain explicit: advisory reachability cannot prove opaque callback
behavior; original latent Gaming callback is preserved without new acceptance;
no cross-process writer locking or directory-sync power-loss claim; no arbitrary
dynamic imports/non-Zig embedded assets. These are defined contract limits,
not unfinished 07A consumers. Native OS text and visual/manual evidence belongs
to 07B. G07-export released; full G07 acceptance is recorded in the 07B section below. Coordinator retains
schema maintenance ownership and owns the 07B UI spike/editor files exclusively.

### Historical first checkpoints

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

### Complete 07B implementation and acceptance

Authoritative current evidence supersedes the historical pending lists above:
[acceptance report](../07-editor-acceptance.md),
[self-verification workflow](../07-editor-verification.md),
[approved goldens](../goldens/07-editor/README.md).
Local implementation commits `1e16484`, `206d9a0`, `8e4039f`, `7168c13`
retain the frozen 07A schema/export/runner contract. No plan 08 or 12
implementation, hardware access, push or PR occurred.

The separate opaque/resizable editor owns a validated draft with 32-snapshot
undo/redo history, bulk selection/copy/paste, stable named layer management,
complete action forms and combo editing. LK7's encoder absence is explicit.
Save/open and callback source refresh are validated/undoable; saving uses the
07A atomic snapshot API. Export uses the same deterministic generator/manifest
consumed by the real firmware and runner builds. Draft/export identity and a
connected companion's verified running identity remain distinguishable; edited
actions never repaint the running overlay as if flashed. Cached recoverable
snapshots and dirty close choices preserve unsaved work.

Prepare Test explicitly snapshots/exports/builds the real processor, Start
creates a fresh bounded child and Stop/focus/source change resets it. Document
and first-party build-input/compiler/target identity invalidate cached/prepared
results. Output text uses native EurKEY dead-key translation; media/mouse/BOOT
commands remain displayed data. Full emitted commands/events/signals/layers and
compiler diagnostics are available in a bounded scrollable details drawer.
Attached Zig checkout/open/check/refresh remains explicit, registered sources
read-only, and callback bytes/imports are never interpreted as visual actions.

The user approved both themes and their 1×/2× variants as regression goldens,
and separately confirmed independent telemetry during native folder-dialog
cancellation. All reference panel bounds match exactly. Catalog-correct geometry,
actual host/action labels, inert offline/08 controls and typography differences
are documented. The golden task is read-only and rejects a wrong-theme image;
future replacement requires explicit screenshot approval. Default builds/tests
retain the offline guard and do not regenerate those approved assets.

Coordinator retains shared-schema maintenance; the editor GUI write lease is
released for future 08B after accepted 08A and an explicit assignment. No worker
or hardware session is active. 08 may consume the documented jobs/selector APIs
and composition; personal profile 05 follows accepted 08. Plan 12 stays deferred.

Final verification on `7168c13`: `mise //:check-full` passes, including ten-board
artifacts, LK7 parity and source/hardware guard; companion 40/40 tests pass;
`editor-check` and `editor-golden-check` pass all 64 captures plus expanded
interactions. Native text, separate-window and offline overlay/editor probes
pass. `zig fmt --check` and `git diff --check` pass. G07 is released.
