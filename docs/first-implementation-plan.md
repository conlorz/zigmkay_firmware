# First implementation: a tested LK7 integration foundation

Status: proposed implementation, based on the local sources inspected on 2026-10-03. This document does not claim that the changes or checks below have already been executed.

The first milestone combines phases 0 and 1 of the existing roadmap. Its outcome is a clean local branch, working core and zkeycodes tests, shared portable types, and one real LK7 input trace passing through a protocol codec into a headless companion model. A small observation interface is brought forward from phase 3 to make that last test meaningful.

## Working agreement

- Write new code, comments, test names, technical documentation, diagnostics, and commit messages in English. Conversation can remain in German.
- Work as a local fork: local branches and local commits only. Publishing, pushing, and pull requests are outside this workflow.
- Keep the existing unfinished companion checkout and the research worktrees intact.
- Use Leonardo Keycaprio v0.7 (`lk7`) as the first integration target.
- Use explicit compiler paths. Zig 0.15.2 is the comparison baseline; Zig 0.16.0 is the intended target, subject to the dependency probe below.

## 1. Establish a clean, reproducible baseline

Create a worktree at `../firmware-integration` on `local/integration`, starting from `c5580be52119bb028588a3cc8329fe4fdecfbd27`:

```sh
git -C zigmkay_firmware worktree add \
  -b local/integration ../firmware-integration \
  c5580be52119bb028588a3cc8329fe4fdecfbd27
```

Check that the destination and branch are unused before executing this command. Preserve `zigmkay_firmware` and its uncommitted changes. Port individual ideas from the historical branches rather than merging them wholesale.

Add an English `AGENTS.md` recording the working agreement and a short `docs/development.md` recording compiler paths, dependency revisions, SDK requirements, and validation commands. Add `tools/check-local` as the eventual single entry point for this milestone's host checks. Allow explicit compiler and SDK overrides; print their resolved versions and fail clearly when a prerequisite is missing.

Reproduce the existing 165 core tests, root core test aggregation, and LK7 firmware build before changing source behavior. Save new logs separately from the study's evidence and record the baseline UF2 hash and size. Build only; hardware flashing is a later milestone.

The temporary SDK view and `xcrun` shim described in document 03 still exist locally. Treat them as an explicitly selected comparison workaround. Check the supported installed SDK/compiler combination first; if the workaround remains necessary, document that limitation instead of making `/tmp` paths a hidden project requirement.

**Acceptance:** clean integration worktree; baseline compiler/SDK and dependency revisions recorded; all 165 existing core tests pass; LK7 produces a UF2. Preserve the result before proceeding to behavioral changes.

## 2. Repair zkeycodes tests and generation

Change `zkeycodes/build.zig`, `src/core.zig`, `src/main.zig`, `test_generation.zig`, and `test_labels.zig`.

1. Supply the required module imports to every test root, including generation and label tests. Use the current firmware `KeyCodeFire` type instead of assuming that the local helper module declares it.
2. Update label matching to use the current nonoptional `Modifiers` value and its `toByte()` method. Preserve the existing modifier helpers' dead-key behavior.
3. Fix generated label code: `KeyCodeFire` belongs to the shared firmware types, while `LabelEntry` and `getLabel` belong to the zkeycodes helper. The inspected generator currently emits label references against the wrong module.
4. Generate test outputs into the build cache with declared output dependencies. Import those outputs and compile them as part of the tests. Replace relative imports such as `../src/core.zig` with named module imports so generated files work outside the source directory.
5. Remove `keycodes/all.zig` writes from build-graph construction. Keep ordinary tests read-only with respect to source files; explicit regeneration can remain a separate operation. Check generated fixtures in deterministic order.

Run the existing basic, US international, and German Mac ISO fixtures through the actual generator and label tests. Resolve errors exposed by the repaired imports without weakening assertions or skipping failing suites. Regenerate affected committed keycode files explicitly if their import contract changes.

**Acceptance:** every zkeycodes test group executes successfully, generated output compiles, modifier/dead-key/label expectations hold, and running the tests produces no source-file diff. Record actual test counts separately from the 165 core tests.

## 3. Extract one portable type model

Add a small `layout-model` package with `src/root.zig`, `src/types.zig`, `src/physical_layout.zig`, and focused validation tests. Its first version represents today's firmware actions; editor commands, JSON documents, and undo/redo follow later.

Move the current definitions of `Modifiers`, `KeyCodeFire`, `KeyIndex`, `LayerIndex`, `KeymapDimensions`, `TimeSpan`, `MouseAction`, `MediaCode`, `TapDef`, `HoldDef`, `TapHoldDef`, `AutoFireDef`, `KeyDef`, `Combo2Def`, `EncoderAction`, and processing `Side` into that package. Move associated keymap constants as needed to preserve their type identity.

Reexport the definitions from `zigmkay/src/core.zig` so existing firmware callers retain their API. Keep queues, layer activation state, custom callback interfaces, clocks, USB commands, and hardware access in the firmware package. Keep native labels outside the portable model.

Wire the same module instance into the firmware and zkeycodes dependency graph. Update the root test build, standalone package builds, and `zigmkay/build_utils.zig` only as needed to run this milestone. The complete publish API, registry, and root firmware/GUI command surface remain phase 2 work.

**Acceptance:** the existing core and repaired zkeycodes suites remain green; cross-module checks establish type identity; LK7 still compiles. The model builds for a native target and a freestanding Wasm target without HAL, SDL, DVUI, native zkeymap, or OS I/O imports.

## 4. Describe and validate the actual LK7 layout

Add `keyboards/my_keyboards/rollercole/lk7_physical_layout.zig` and expose the existing `shared_keymap_3x5_2.zig` through a named module for host tests. Use the existing keymap and its custom callbacks, not a separately transcribed companion keymap.

The inspected keymap has **34 positions and four defined layers**. Assign an explicit stable ID to each position and map it to its existing key index. Record x/y, width/height, rotation, hand, and group separately from GPIO coordinates and processing `Side`. Use normalized key units for the initial schematic geometry; do not claim mechanical measurements without a source.

Validate duplicate IDs, duplicate/missing index mappings, positive key dimensions, keymap dimensions, combo indices, and layer references against the actual layout. Preserve `null` as layer fallthrough and `.none` as an explicit disabled action. In this keymap `_______` currently means `.none`; do not silently convert those entries to transparent keys.

Address two concrete existing problems before accepting real-keymap tests:

- The gaming custom action activates layer index 4, although only indices 0–3 exist. Add a regression reproducing the invalid activation. Reject that unavailable layer through the smallest bounds check consistent with the current callback behavior; record the behavior change in its own fix commit. A fifth gaming layer requires a separate keymap decision.
- `left_held` and `right_held` are file-global callback state. Isolate real-keymap scenarios in separate test processes initially and release all held inputs at the end of each trace. Converting all callbacks to per-instance state is later work; a fresh processor alone does not reset these globals.

**Acceptance:** all 34 keys resolve to unique stable IDs; changing geometry preserves identity; invalid indices/layers fail explicitly; representative transparent and disabled entries behave differently; the actual LK7 module compiles and runs headlessly with its real custom logic.

## 5. Implement the smallest real input-to-companion trace

Add portable `device-protocol` and `companion-model` modules plus `tests/test_lk7_trace.zig`. The headless model contains pressed keys, active layers, and modifiers with a deterministic event reducer. The native companion GUI and HID reader remain later work.

Use the 32-byte framing proposed in document 08: magic `0xA7`, major version, message kind, payload length, little-endian sequence number, reserved flags, and zero-padded payload. Write an English protocol specification with explicit message IDs, field offsets, and literal golden byte fixtures before implementing the codec. This milestone implements `KeyEvent` and `LayerState`; other message kinds remain explicitly unsupported until their contracts are implemented. Production device use requires the later Hello/Snapshot/recovery work.

The decoder validates exact report length, version, type, payload length, boolean encoding, reserved fields, and indices against the actual 34-key/four-layer layout before narrowing values. Keep HID report IDs outside the protocol body. Serialize fields explicitly rather than relying on struct memory layout.

Add an optional observation interface independent of `CustomFunctions`, with a default disabled observer. It supplies physical input changes and layer/modifier changes to a fake sink in the test. Define physical notifications at an input-ingestion boundary, exactly once per matrix event, including combo and disabled keys. Do not emit from a repeatedly retried Tap/Hold decision. Observe layer changes after custom callbacks complete, including tick-driven hold decisions.

The observer never adds reports to `OutputCommandQueue`. A full or disabled sink cannot propagate an error into keyboard processing. Production scheduling, queue recovery, and RawHID delivery are phase 3 work.

Use a fixed synthetic clock for this trace:

1. Press and release a simple base-layer key from the real LK7 map, for example index 0 (`Q`).
2. Press thumb index 30, then advance beyond its 150 ms tapping term and combo timeout. Its real custom hold activates the arrows layer.
3. Press and release index 0 again and verify the real arrows-layer action (`EXLM`).
4. Release the thumb and verify return to the base layer with no remaining pressed keys or modifiers.

Check the ordinary keyboard command sequence, literal protocol bytes, decoded events, and companion state after every relevant step. Repeat the trace with observation disabled and with a full fake sink; keyboard output must match exactly. Add focused malformed-report cases and verify repeated processing ticks do not duplicate physical press/release notifications.

**Acceptance:** actual LK7 keymap → real processor observation → codec bytes → headless reducer is deterministic without USB or GUI. Press/release and custom layer activation are both exercised; telemetry cannot change keyboard output. The original core test corpus remains intact and passing.

## 6. Run the bounded Zig 0.16 dependency probe

Use a separate worktree, such as `../firmware-integration-016`, on `local/probe-016` from the portable-model commit. Keep probe changes and logs distinct from the integration baseline. Execute this probe early, before expanding build or host I/O work; it does not depend on the trace being complete.

Pin MicroZig to `00fde43fa3756790037b099baeafacc3e6bf9499`, using the existing `microzig-016` checkout for local dependency development. Apply the already documented core syntax adjustment. Port only build/I/O boundaries required to compile a minimal RP2040 target and the actual LK7 target. Separately compile current DVUI's native SDL example with the installed SDK and its Wasm example using the documented DVUI revision.

Record each command, exact revision, SDK/compiler version, exit status, and first actionable failure. A missing SDK or dependency-fetch failure is an environment result, not proof of source incompatibility. Compilation success is not hardware or GUI runtime acceptance.

**Decision:** if minimal RP2040, LK7, and native DVUI compile with bounded API fixes, carry subsequent phase 2 work onto 0.16 in separate commits. Otherwise identify the specific blocker and retain 0.15.2 as the short comparison baseline while fixing it. The milestone requires a reproducible probe result, not a claim that the full project migration is finished.

## Local commit sequence and completion gate

Keep each implementation commit reviewable and validate it with the relevant checks:

| Order | Suggested English commit message | Required evidence |
|---|---|---|
| 1 | `chore: document local development and baseline checks` | 165 core tests and baseline LK7 UF2 |
| 2 | `fix: repair zkeycodes tests and isolate generated outputs` | All existing generator and label tests; no source writes |
| 3 | `refactor: share portable keyboard action types` | Core/zkeycodes tests, native/Wasm model build, LK7 compile |
| 4 | `feat: define the LK7 physical layout and validation` | Stable IDs, mapping, transparent/none and bounds tests |
| 5 | `fix: reject unavailable LK7 custom layers` | Gaming-layer regression and unchanged supported layers |
| 6 | `feat: add a portable telemetry codec and companion state model` | Golden bytes, malformed input, reducer checks |
| 7 | `test: verify an LK7 input trace through companion state` | Real processor observer, real custom callback, output equivalence |

Probe commits stay on `local/probe-016` until their changes are ready to integrate. During implementation, copy this plan into the integration repository so it can be versioned locally.

The first milestone is complete when `tools/check-local` runs all host suites, the model's freestanding compile check, and the real LK7 trace; a separate explicit firmware compile produces LK7's UF2; test runs leave tracked source unchanged; and the 0.16 dependency decision has reproducible evidence. The check script never discovers devices or flashes firmware.

Phase 2 then builds the unified root package graph and board registry. Phase 3 adds the production telemetry queue, handshake/snapshot/recovery, native HID adapter, and GUI connection. Editor and browser flashing follow their existing roadmap phases.
