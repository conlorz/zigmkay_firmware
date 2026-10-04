# 07: Visual editing with validated compiled-keymap export

Status: planned and conditional on 06's architecture decision. Depends on 05/06.
The native companion is the preferred starting route, not yet a final decision.

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

## Commit checkpoints and handoff

Commit schema/parser and validation; commit lossless profile adapters and Zig
export; commit editor UI and undo/save behavior; commit build integration and
offline workflow documentation. Keep each local commit reviewable.

Handoff supplies the project format, supported action matrix, export command,
artifact/profile identity, and concrete user workflow for 08. Arbitrary Zig
source editing, other boards, runtime configuration, and on-device persistence
remain deferred unless separately selected.

Incoming: accepted [05](handovers/05-keymap.md)/[06](handovers/06-architecture.md)
and existing identity. 07A publishes schema/actions, export path/API/digest,
validation/error/result contract, literal fixtures, and actual build integration.
Coordinator acceptance freezes G07-export for 07B/08A. Full 07 acceptance then
releases G07 and transfers GUI ownership to 08B; 07A alone cannot complete 07.
