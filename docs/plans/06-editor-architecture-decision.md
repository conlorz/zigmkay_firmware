# 06B: native editor architecture decision

State: accepted planning decision, 2026-10-04. Coordinator reviewed existing
06A research, accepted 03/04 handovers, current source at `63f7998`, and the user's
feature answers. No production source, dependency or device operation changed.
This releases G06 for later authorized implementation; it does not start 07/08.

## Selected route and alternatives

Extend the Zig DVUI/SDL3 companion with a separate native editor window and retain
the lightweight live overlay. The agreed scope is in
[editor requirements](06-editor-requirements.md). Reuse pinned dependencies without
updates or new first-party languages. Zig 0.16.0 owns models, persistence, export,
process orchestration and tests; retain imported upstream C bridges unchanged.

The [06A comparison](06-architecture-research.md) establishes native form/window
primitives, file-dialog options, native model reuse and local process support.
These fit the selected local, offline compiled-keymap workflow. The browser/local
service alternative adds a frontend/service boundary and lifecycle without
removing compiler installation; export-only browser editing separates the selected
test/build workflow into another local tool. Both remain possible future consumers
of the portable project model. Neither is selected. Safari device restrictions
are a constraint on direct browser device access, not on browser editing itself.

## Ownership and dependencies

Proposed paths below are implementation assignments, not existing commands/APIs.

| Owner | Boundary |
| --- | --- |
| `layout-model` | Existing portable actions and physical geometry; no UI/job ownership |
| New `keymap-project/` | Versioned document, callback metadata/source inventory, validation, atomic save/load, canonical identity adapter and deterministic Zig export |
| `zigmkay-companion` | Editor state, undo/redo, selection, rendering, label/text translation and bounded job-result reduction |
| `keyboards` build API | Shared board/profile selector; compile generated profile through the existing firmware path |
| New `apps/keymap-test/` | Generated host runner specializing the existing firmware processor for an immutable draft |
| New `companion-jobs/` | Reusable process/test/build/artifact jobs with fake adapters, cancellation and bounded event/output queues |
| `zig-flash` | Existing accepted physical recovery/copy/verification boundary, consumed by 08 |

Keep packages and user project storage in this monorepo. User projects belong in
a dedicated gitignored project area; explicit committed examples are fixtures.
Tests and ordinary exports/build intermediates stay in caches. Explicit export
to an owned source path is distinct from normal save/build. Root/mise integration
and package manifests must be updated when these packages actually exist.

## Document and callback contract

Select typed ZON data with a schema version. The project is a directory containing
the document and optional callback Zig sources. The document carries board/profile
and physical-layout references, stable key IDs, named ordered layers with stable
document IDs, all current action fields, ordered two-key combos, encoder actions,
and callback bindings. Document IDs map to firmware indices during export; layer
names are editor metadata. Preserve `null` versus explicit `.none`, simultaneous
tap fields, timing, modifier bits, custom IDs and action order.

07A freezes exact field names/API and bounds before GUI work. Proposed initial
caps: 1 MiB document, 1 MiB total callback sources, 64 callback files, 1024 combos,
127 keys and 15 layers (current dimension count types), and bounded names/path
lengths. Test limits before claiming capacity; board key count stays board-owned.
Reject unknown versions/fields, invalid references and unsupported actions without
overwriting input. Atomic document replacement and consistent source inventory
must survive failed saves. Define project/source snapshot consistency in 07A.

Use curated adapters for supported existing profiles, never arbitrary Zig keymap
parsing. Registered callbacks resolve unchanged trusted modules; attached modules
preserve source bytes, relative imports and digest with explicit missing/import
errors. Provide metadata for ABI, named custom IDs and required layer indices.
Source declarations are not proof of arbitrary behavior. Deleting a referenced
layer fails with an explanation; attached modules without sufficient constraints
lock index-changing deletion. Layer reordering is deferred. Layer duplication
must not imply duplication of callback-specific behavior.

Reuse `device-protocol.computeIdentity` and its callback behavior declarations.
For attached source, a deterministic source/ABI digest participates in callback
behavior metadata, including transitive owned source files; registered source
changes likewise invalidate identity. Separately retain a full project/build hash
for metadata and artifact freshness. This is not a new telemetry wire contract.
Compiler version and build inputs belong in artifact metadata, not display labels.

## Editor and test behavior

Implement visual geometry, layer tabs, searchable inspectors for every existing
action, multi-key selection, copy/paste, add/duplicate/delete layers, undo/redo,
dirty state, validation and save/reopen/export. Keep board wiring immutable.
Use asynchronous file dialogs or a serialized worker for existing blocking
helpers. The UI owns document state; background results refer to snapshot IDs.
Live verified profile rendering stays distinct from draft/built profile rendering.

Testing freezes a draft and compiles a native runner with the real processor and
selected callbacks. Input protocol carries key down/up, encoder events where
applicable, deterministic monotonic time advancement and reset. Output protocol
carries bounded processor events, key/modifier output, layer state and diagnostics.
07A freezes the protocol/version and error handling. Restart the runner for reset
to clear callback globals; kill hung/crashed runners without taking down the UI.
Run callbacks only on explicit test/build, including compile-time execution.
Subprocess isolation is not a security sandbox. No runner executes device APIs.

Virtual presses and explicitly mapped host scancodes drive draft positions;
normal host text events do not substitute for simulated firmware output. Support
holds and multi-key sequences with deterministic recorded timing. Focus loss,
leaving test mode or stopping a test releases/resets mapped keys. While test mode
owns mapped keys, prevent those inputs from activating editor shortcuts; unrelated
keys retain normal UI navigation. Draft changes invalidate the prepared runner.

Translate emitted key/modifier sequences in a separate Zig macOS input-source
session with persistent dead-key state and bounded multi-scalar Unicode output.
Require/select by instruction the installed EurKEY source; display its actual ID
and reset composition on source changes. Do not change the system source or
inject OS key events. Handle text-area editing keys explicitly; log shortcuts,
media/mouse, BOOTSEL and companion signals rather than performing their effects.
This validates draft processor output and text translation, not every application's
shortcut behavior. Sources and existing translation limits are in the requirements.

## Build/flash split and implementation sequence

07A delivers project/export/shared selection, job/test-runner contracts and
behavior fixtures. At G07-export, 07B owns editor/test UI; 08A owns reusable
firmware build/artifact/flash backend. Shared jobs/test-runner support must be
integrated before consumers use it. 08B adds GUI build/flash stages after full 07.
All jobs use argument vectors and immutable snapshots; compilation and flashing
remain distinct explicit actions. Reuse plan 11 flasher and running-identity
verification. Preserve rollback artifacts and reject stale builds.

## Evidence and remaining implementation checks

This is a source/documentation-backed architecture decision, not an implemented
UI, packaging, performance or hardware acceptance. No new dependency is required
by the design. The selected additional features justify the native runner rather
than a speculative runtime processor refactor or a duplicate behavior simulator.

At the beginning of 07B, use a bounded Zig offline spike to verify two-window
focus/close/event handling, dialogs while fake telemetry is drained, mapped-key
capture and a prepared runner's latency. Run without HID or flashing. If the
pinned framework cannot meet these requirements, report the concrete limitation
before revising architecture. Do not silently collapse the editor into the overlay.
VoiceOver and public packaging remain unclaimed; keyboard navigation is required.

Meaningful acceptance covers every action's round-trip/export behavior,
callback preservation/mismatch, layer-reference constraints, emitted traces,
EurKEY composition/reset, stale runner/build results, save failures and cancellation.
Use deterministic fake text fixtures by default; validate native EurKEY translation
separately on the selected macOS layout before marking text preview accepted.
Measure runner preparation/input latency and report actual results. Appropriate
Zig checks and full build matrix/parity remain mandatory for source integration.
