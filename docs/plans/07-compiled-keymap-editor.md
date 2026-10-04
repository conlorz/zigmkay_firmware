# 07: Visual editing with validated compiled-keymap export

Status: accepted. 07A frozen at `016cf7d`; 07B accepted at `7168c13`, with
user-approved screenshots and passing offline/native/golden checks. See
[the evidence](07-editor-acceptance.md) and [verification guide](07-editor-verification.md).
Implement shared profile selection and identity plumbing here, using the accepted
existing profile and representative QWERTY/EurKEY fixtures. The user's personal
profile is created later in 05 through the finished editor; it is not an entry
gate. Older 05 acceptance/prerequisite references below are superseded.
The native companion is selected by the accepted
[06B decision](06-editor-architecture-decision.md). The agreed
[feature scope](06-editor-requirements.md) includes all existing firmware actions,
layer management, bulk editing, EurKEY draft testing and attached Zig callbacks.

## Selected implementation additions

07B must closely reproduce the selected layer-sidebar layout described in the
[visual specification](06-editor-visual-specification.md). Deliver deterministic
offline screenshot/scenario support in Zig, dark/light reference-size captures,
region comparisons and native-window checks. Record intentional correctness
deviations from generated labels/geometry; do not silently redesign the layout.

07A owns `keymap-project` and the immutable export/test-runner contracts described
in 06B. Freeze schema/bounds, registered and attached callback policies, canonical
identity adapter, shared selector, save/source snapshot consistency and literal
behavior fixtures before G07-export. Deliver the generated native host runner
and reusable process-job support needed by 07B; do not duplicate the processor
in a simulator. Registered and attached callbacks participate in source identity.

07B starts with the bounded Zig offline window/dialog/input spike specified by
06B, then implements named layer add/duplicate/delete, multi-key copy/paste,
all action inspectors, external callback attachment/diagnostics, and explicit
Prepare Test/Start/Stop draft testing. Tests use virtual or mapped host positions,
display processor events/layers and EurKEY text, and reset on focus/input-source
changes. No live LK7 input or system-wide synthetic events are needed.

Acceptance additionally requires callback bytes/import preservation, constrained
layer deletion, mapped-key focus/reset behavior, every existing action's literal
emitted traces, EurKEY composition/multi-scalar text, cancellation/crash/stale
runner handling and measured runner preparation/input latency. Native text
translation acceptance records the actual macOS input-source ID/version; default
tests use deterministic translation fixtures. No embedded source editor or new
macro/tap-dance runtime is included.

Coordination: [tracker](TRACKING.md), [workflow](SUBAGENT-WORKFLOW.md), and
[07 handover](handovers/07-editor.md). Split 07A schema/export from 07B editor UI.
After G07-export, 07B may run beside 08A backend on disjoint exact file leases.

## Outcome

Edit an LK7 profile visually, save a lossless project, validate it, and export a
deterministic compiled keymap. The small live overlay remains usable separately.
Flashing is integrated in 08; runtime device remapping is not required.

## Work

1. Revise the UI-specific tasks after 06. Reuse physical geometry, stable key IDs,
   key indices, and portable action definitions. Keep immutable board wiring and
   scanner configuration outside normal keymap editing.
2. Define a versioned project schema with board/profile identity, layers, actions,
   combos, timing settings where supported, and registered custom-action IDs.
   Specify limits, migrations, and handling of unsupported future schema versions.
   Parse data without evaluating arbitrary Zig source or executing callbacks.
3. Define the supported action set from real LK7 profiles: basic keys/modifiers,
   tap/hold, layers, combos, and applicable macro/one-shot/autofire/custom actions.
   Preserve every imported supported field. Unsupported custom callbacks must
   remain an explicitly preserved read-only reference or produce a lossless
   refusal to import; never erase them during save/export.
4. Implement editing in a dedicated editor view/window, with layer selection,
   physical-key selection, action inspector, combo selection, undo/redo, unsaved
   changes, and clear validation errors. Labels should distinguish HID usage,
   modifier chord, and host-translated EurKEY Next output.
5. Validate dimensions, indices, stable IDs, layer references, combo membership,
   duplicate/conflicting definitions, action constraints, timing values, and
   reachable recovery/layer actions. Explain conflicts at the affected key/action;
   do not promise that static checks prove all timing interactions safe.
6. Save/load atomically with bounded input and no destructive overwrite of the
   original Rollercole or accepted EurKEY Next profile. Use explicit save/export
   actions and preserve recoverable drafts. Do not mutate committed generated
   sources during ordinary builds or tests.
7. Generate deterministic Zig through a Zig implementation. Specify ownership
   headers and an explicit regeneration command. Export to a new profile/module,
   resolve registered callbacks deliberately, and compile it through the same
   board build path used by hand-written profiles.
8. Compute preview/profile identity from the same canonical representation used
   by firmware. Unsaved changes and unflashed exports must be visibly distinct
   from the currently connected firmware profile; never repaint live keys with
   unverified edited actions as if they were running on the device.

## Acceptance

- Representative Danish and EurKEY Next projects round-trip without lost action
  data, including explicitly supported custom references. Unsupported input is
  diagnosed with no partial/destructive save.
- Deterministic fixtures cover schema versions, malformed/bounded input, invalid
  references, conflicts, undo/redo, atomic-save failure, and canonical identity.
- Literal expected exports verify meaningful mappings; exported modules compile
  and produce expected processor behavior for representative action traces.
  Outputs for tests stay in caches and do not modify committed source inventory.
- UI checks cover physical selection, thumbs, layers, preview state, validation,
  and cancellation. Offline smoke/replay and `zig build check` still pass.
  Export/build API changes also pass `check-full`.
- The user can save, reopen, and export a concrete LK7 modification without
  hardware access. A compiled artifact alone is not marked flashed or accepted.
- Visual acceptance follows the linked specification: close panel proportions,
  colored sidebar, full OS viewer, readable inspector and both themes. Actual
  captures and documented deviations precede approval of regression goldens.

## Commit checkpoints and handoff

Commit schema/parser and validation; commit lossless profile adapters and Zig
export; commit editor UI and undo/save behavior; commit build integration and
offline workflow documentation. Keep each local commit reviewable.

Handoff supplies the project format, supported action matrix, export command,
artifact/profile identity, and concrete user workflow for 08. Arbitrary Zig
source editing, other boards, runtime configuration, and on-device persistence
remain deferred unless separately selected.

Incoming: accepted [04](handovers/04-hardware.md)/[06](handovers/06-architecture.md)
and existing identity. 07A publishes schema/actions, export path/API/digest,
validation/error/result contract, literal fixtures, and actual build integration.
Coordinator acceptance freezes G07-export for 07B/08A. Full 07 acceptance then
releases G07 and transfers GUI ownership to 08B; 07A alone cannot complete 07.
