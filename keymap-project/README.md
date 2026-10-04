# Keymap project contract — schema 1 / G07-export

Frozen for editor/build consumers at `016cf7d`, 2026-10-04. Zig 0.16.0 typed ZON
only; opening, validating, saving, capturing and generating source never execute
attached code. Explicit build/test can execute Zig compile-time/runtime code.

## Commands

From the monorepo (all outputs below stay in caches):

```sh
mise //keymap-project:test
mise //companion-jobs:test
mise //apps/keymap-test:test
mise exec -- zig build --build-file keymap-project/build.zig run -- create danish .zig-cache/my-project
mise exec -- zig build --build-file keymap-project/build.zig run -- validate .zig-cache/my-project
mise exec -- zig build --build-file keymap-project/build.zig run -- export .zig-cache/my-project .zig-cache/my-export
```

`create` accepts `danish`, `qwerty`, `eurkey`; refuses an existing project.
User projects belong under gitignored `projects/`. These are curated typed
adapters; arbitrary Zig keymap parsing and personal profile 05 are outside 07.
An edited export is unflashed and distinct from the running profile.

Build the export with an **absolute** export directory:

```sh
mise exec -- zig build --build-file apps/keymap-test/build.zig -Dprofile=/absolute/export -p /absolute/cache/runner
mise exec -- zig build --build-file keyboards/build.zig firmware -Dkeyboard=lk7 -Dprofile=/absolute/export -p /absolute/cache/firmware
mise exec -- zig build --build-file zigmkay-companion/build.zig -Dprofile=/absolute/export
```

These build only. Shared `build_input.load` verifies the manifest/files and copies
verified bytes into cache before compiling; edits to the external export cannot
race the compiler. Default companion/firmware behavior retains the original
accepted Danish profile. Editor exports currently support LK7 only.

## Model, ownership and errors

`src/root.zig`: `Document`, `Board`, `Action`, `Tap`, `Hold`, `Layer`, `Combo`,
`Callback`, `Source`; `parse`, `serialize`, `validate`, `lowerAction/lowerTap/
lowerHold`, `layerIndex/keyIndex`, `canDeleteLayer`. `parse` owns its returned
strings/slices; call `deinit`. Optional `Diagnostics` owns its parser source;
start empty and call `Diagnostics.deinit` with the same allocator even on error.
`serialize`, `exporter.generate` and `Session.request` return owned byte slices.

Ordered layers have nonzero stable u32 IDs and UTF-8 names. Actions/combos refer
to stable IDs; lowering maps them to firmware indices. LK7 key IDs are stable
catalog-derived `lk7_XXXX` IDs in board-owned index order. Physical geometry,
sides, wiring and encoder counts are not editable document facts.

Every current action field is retained: null transparency versus none;
tap-only/hold-only/tap-hold/autofire; simultaneous optional tap fields;
one-shot; eight modifier bits; dead flag; custom IDs; media/mouse;
retro tapping; tapping term, initial delay, repeat interval; ordered two-key
combos; encoders. Typed lift/lower adapters guard model field counts against
silent future-field loss. Zero tapping terms/repeat intervals/combo timeouts
fail; initial delay may be zero. Duplicate unordered combo pairs within a layer
fail; overlapping combos stay ordered and legal.

Bounds: 1 MiB document and total callback bytes, 64 callback source entries,
127 keys, 15 layers, 1024 combos, 128-byte names, 240-byte source paths.
Unknown/executable ZON fields, future versions, bad geometry/IDs/references,
duplicates, undeclared custom IDs and invalid timing fail without a partial
usable document or destructive save. No implicit migrations.
`assessment.assess` reports declarative reachability/recovery and callback-review
requirements; it does not prove arbitrary callback/timing behavior safe.

Callback ABI 1 exposes `core.CustomFunctions` as `custom_functions`.
User IDs 1–252; built-in tap signal IDs 253–255 are not registrable hold callbacks.
Required layers and declared index constraints block unsafe deletion. Unconstrained
opaque callbacks block index-renumbering deletion. Base layer deletion fails;
remaining action/combo/encoder references also block deletion. Renaming is
metadata only; duplication never duplicates callback-specific behavior.

`profiles.create` returns owned `snapshot.Loaded` (call `deinit`): Danish lifts
all original actions/combos and preserves the complete registered module bytes;
QWERTY/EurKEY are representative six-layer drafts, not the user's final profile.
`profiles.callbackEntry` resolves only the curated registry binding with exact
bytes and constraints. The original Danish legacy Gaming callback targets index
4 outside its four-layer map; behavior is preserved, with review required, and
legacy Gaming acceptance remains unclaimed.

## Source snapshots, persistence and export

`snapshot.Snapshot`: document plus caller-owned immutable `SourceBytes`, each
entry indexed by callback and relative path. Validation checks exact inventory,
source hashes and byte limits. `clone` produces owned copies. `identity` lowers
through `device-protocol.computeIdentity`; ABI/binding/ordered transitive source
hashes participate in callback behavior metadata. Registered changes invalidate
identity too. `projectDigest` additionally includes document metadata for job
freshness; layer renames leave telemetry identity unchanged.

`save(allocator, io, project_dir, snapshot, board)` writes immutable
`.sources/<bundle SHA-256>/<relative path>` then synchronizes and atomically
replaces `project.zon`. The previous document is never deleted first; failures
can leave unreferenced bundles, not partially committed source inventories.
Existing differing bundles fail. `load` bounds/validates everything and returns
owned `Loaded`. Consumers serialize writers; replacement is atomic but directory
metadata sync/power-loss durability and cross-process writer locking are not
claimed. Normal save never alters accepted profile source files.

`sources.capture` copies a literal transitive source closure into an owned
`Bundle` (deinit it). Paths/imports reject absolute/escaping/unknown/dynamic imports;
permitted dependency modules are std, zigmkay, layout-model, zkeycodes. Relative
imports remain byte-identical. Opaque source is not evaluated. Missing imports
fail explicitly. Non-Zig embedded assets are outside this schema and fail.
`sources.attach` creates a new immutable snapshot. Explicit `checkout` creates
editable `callbacks/<index>/...` mirrors without overwriting existing edits;
`refresh` explicitly captures edited bytes into a new snapshot. Save/reopen
always reads the immutable source inventory, not mutable mirrors. Registered
callbacks are read-only. Source changes invalidate prepared/built results.

`exporter.generate` is pure deterministic Zig generation. `exporter.write`
explicitly materializes keymap and callback modules into an owned directory;
existing differing files cause `ExportOwnershipConflict`. `manifest.zon` is the
final commit marker (build contract 1). Consumers verify all listed files;
modules are `callback_N` in document order, preserving ABI dispatch order. No
ordinary build regenerates committed sources. Failed export may leave an
incomplete unaccepted directory; only a valid matching manifest is buildable.

## Runner and jobs — contract 1

`apps/keymap-test/protocol.zig` defines newline-framed typed ZON:
input version 1, strictly increasing sequence, monotonic absolute `time_us`,
key_down/key_up, encoder action index, advance, reset, stop. Input cap 4096 bytes.
Response cap 1 MiB; at most 256 processor events, commands and signals per input.
Outputs include immutable snapshot ID, matching sequence, state, full processor
trace, USB command data, companion signal data, layer mask/highest layer,
modifiers and optional diagnostic. No platform/device dispatch exists.

Runner emits initial ready/sequence 0. Malformed version/sequence/time/key or
encoder input fails explicitly and terminates. Output/event overflow fails;
crashes/EOF invalidate the session. Reset responds restart_required and exits;
consumer kills/reaps and starts the same immutable executable to clear callback
globals. Stop/focus loss releases UI mappings and stops the process. BOOTSEL,
media/mouse and companion effects are data/log entries, never OS/device actions.
`advance` performs one real processor tick at the supplied absolute time; it
retains existing firmware timing/retro semantics, not a duplicate simulator.

`companion-jobs` owns direct argv process execution with copied immutable args,
1 MiB stdout/stderr bounds, deadline/watchdog, cancellation and reaping.
`Job`/`Session` require stable addresses and serialized use; asynchronous `poll`
returns owned results. `Result.fresh` rejects a changed snapshot; `artifactKey`
also hashes compiler version, target, optimization and dependency/build inputs.
UI must reject old job results. `Session.request` bounds/read-times out framed
responses and terminates hung sessions. Subprocess isolation is not a sandbox.

Verification: full offline check/matrix/parity passed. Generated action traces
cover taps, holds, retro rules, autofire, transparency, none, layers, one-shot,
combos, dead chords, media/mouse, encoders, custom callbacks/signals and boot data.
Registered Danish layer/Alt-Tab traces and attached-global fresh-process reset
pass. Capacity/reference/round-trip/save-failure/source-edit/export-ownership and
real crash/timeout/cancel/stale tests pass. Measured registered runner build with
warm dependency caches: 1.536 s; startup 4.355 ms, input roundtrip 3.251 ms in the
recorded native fixture run. These are environment observations, not latency
budgets. Native text/input-source and GUI acceptance belong to 07B.
