# Keymap project model (07A in progress)

Zig 0.16.0 typed ZON data only. Opening/parsing/validating a project does not
compile Zig, evaluate imports, execute callbacks, or access devices.

Run `mise //keymap-project:test` from the monorepo. Root aggregate tests include
this package. This is the first schema checkpoint; **G07-export is not frozen**.
Persistence, curated adapters, source inventory verification, canonical identity,
deterministic export, shared selection and native runner/jobs remain required
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
this checkpoint does not yet verify source bytes/imports or resolve registrations.

Deletion fails for the base layer, references from remaining actions/combos/
encoders, required callback layers or declared affected indices. Unconstrained
opaque callbacks block deletion that renumbers retained layers. Renaming is
metadata only; duplication does not duplicate callback behavior. The editor
must validate before applying a deletion as a single undoable operation.

Tests include literal lowering assertions, lossless serialization, rejection of
executable/unknown/future data, malformed references, combo conflicts, unsafe
callback deletion, invalid paths and timing. Tests use temporary/cache outputs
only. No generated committed profile is changed.
