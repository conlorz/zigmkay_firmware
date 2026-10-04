# Keymap project model (07A in progress)

Zig 0.16.0 typed ZON data only. Opening/parsing/validating a project does not
compile Zig, evaluate imports, execute callbacks, or access devices.

Run `mise //keymap-project:test` from the monorepo. Root aggregate tests include
this package. This is the first schema checkpoint; **G07-export is not frozen**.
Curated profile adapters, import/registry resolution, firmware export integration,
shared selection and native runner/jobs remain required
before 07B starts. Schema/API changes remain possible until that gate.

`src/root.zig` defines schema 1 and `parse`, `serialize`, `validate`,
`lowerAction`, `lowerTap`, `lowerHold`, `keyIndex`, `layerIndex` and
`canDeleteLayer`. `parse` owns allocated strings/slices; call `deinit` once.
Caller-supplied parser diagnostics start empty and must be deinitialized by the
caller. Without diagnostics the parser manages its own. Parse errors never
produce a partially usable document. Unknown fields and executable syntax fail;
unsupported versions fail, with no implicit migration or overwrite.

Ordered layers have nonzero stable `u32` document IDs and editable UTF-8 names.
Actions and combos refer to these IDs, never guessed firmware layer indices.
Lowering maps IDs to ordered firmware indices. Key IDs and sides come from a
board-owned `Board`, which must match exactly; normal documents cannot edit
wiring/geometry. The fixture board is deliberately tiny and does not claim LK7
catalog integration. Encoders must match the board-owned action count.

Actions preserve all model fields: null transparency versus explicit none,
tap-only/hold-only/tap-hold/autofire, all simultaneous optional tap fields,
one-shot, eight modifier bits, dead flag, custom IDs, media/mouse enums,
retro tapping, tapping term, initial delay and repeat interval. Zero tapping
terms/repeat intervals and zero combo timeouts are rejected; initial delay may
be zero. Shared-key combos remain legal; duplicate unordered pairs within a
layer fail. Combo order and pair order are retained.

Bounds: 1 MiB input/output document, 127 keys, 15 layers, 1024 two-key combos,
64 callback source entries, 128-byte UTF-8 names and 240-byte portable source
paths. Callback declarations carry ABI 1, registered/attached binding, custom
IDs 1–252, source path/SHA-256 metadata, required layers and optional explicit
index constraints. IDs 253–255 are built-in tap signals and cannot be registered
or used as opaque hold callbacks. Paths reject traversal, absolute paths,
backslashes and ambiguous components. Metadata does not prove source behavior;
source snapshot validation verifies bytes; import/registry resolution is pending.

Deletion fails for the base layer, references from remaining actions/combos/
encoders, required callback layers or declared affected indices. Unconstrained
opaque callbacks block deletion that renumbers retained layers. Renaming is
metadata only; duplication does not duplicate callback behavior. The editor
must validate before applying a deletion as a single undoable operation.

Tests include literal lowering assertions, lossless serialization, rejection of
executable/unknown/future data, malformed references, combo conflicts, unsafe
callback deletion, invalid paths and timing. Tests use temporary/cache outputs
only. No generated committed profile is changed.

## Immutable snapshots and persistence

`snapshot.zig` accepts a `Snapshot` with the document and caller-owned immutable
`SourceBytes` for every declared source. Missing, mismatched, extra or duplicate
entries fail. Total source bytes are bounded at 1 MiB. `identity` lowers actions
and calls the existing `device-protocol.computeIdentity`; callback behavior
declarations include ABI, binding and the ordered path/source digest. Both
registered and attached source bytes therefore affect identity. `projectDigest`
also hashes document metadata for job freshness. Neither is a build artifact
hash: compiler/target/build inputs still need the runner/build contract.

`save(allocator, io, project_dir, snapshot, board)` writes only `project.zon`
and `.sources/<bundle SHA-256>/<relative source path>` inside the selected
project directory. Relative file structure and raw bytes are preserved. It
validates the complete snapshot before filesystem writes, atomically creates
immutable source files, checks existing bundles byte-for-byte, synchronizes file
contents, then atomically replaces the single document. The prior document is
never deleted first. Failed saves may leave unreferenced bundles; they never
replace referenced bundles. Directory metadata is not synchronized, so this
does not yet claim power-loss durability. Concurrent writers must be serialized
by the consumer; last successful document replacement wins.

`load` reads the bounded document and all referenced bundle files, validates
digests and returns an owned `Loaded`; call its `deinit`. It never compiles or
executes source. Bundle paths are immutable storage, not external editing paths;
the editable attachment workspace/import-snapshot workflow is still pending.
Registered bindings are declarations until curated resolution is implemented.

Tests cover save/reopen, repeated atomic replacement, rejected digest changes,
filesystem failure with the previous project still readable, corrupted immutable
bundles, source bounds and identity/freshness invalidation. This API remains
provisional until the complete 07A contract passes G07-export.

## Typed adapters and deterministic Zig generation

`adapter.liftAction/liftTap/liftHold` preserve typed firmware actions and convert
indices back to stable layer IDs. They are building blocks for curated profile
adapters, not arbitrary source import. Compile-time model field-count guards
require a deliberate schema review if the portable action types gain fields.

`exporter.generate` returns owned deterministic Zig bytes for a verified
snapshot. It emits keymap, sides, dimensions, combos, encoder actions,
`custom_functions` and an `identity(protocol)` accessor. Metadata names never
enter executable source. Callback modules are named `callback_N` in document
order and must expose ABI-1 `custom_functions`; their handlers dispatch in that
same order. Consumers must bind those modules to the exact verified source
inventory. Registry/import resolution and the board build integration are still
pending, so this is a pure generator, not an end-user export/build command.

The package test build generates a tiny profile only into the Zig build cache,
compiles it, specializes the existing firmware processor and verifies literal
A and layer-held Left Arrow press/release traces. It also checks canonical
firmware identity equivalence. Separate compound-field export assertions and
Zig syntax checks cover timing, media/mouse, modifiers, autofire, combos and
transparency; compiled emitted traces for every action/callback remain pending.
