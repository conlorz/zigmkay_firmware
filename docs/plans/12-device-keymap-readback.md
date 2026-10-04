# 12: Complete device keymap readback

Status: deferred, requested 2026-10-04. Additional milestone outside the current
06 → 07 → 08 → 05 → 09 sequence. Return to it when the user requests execution.
Planning does not authorize implementation or hardware operations. Use Zig
0.16.0 and follow the workspace agreement, including local commits only.

## Outcome and dependencies

Retrieve the keyboard's complete compiled configuration over vendor HID without
requiring a matching local project. Recover an editable project wherever all
required configuration and source are available; clearly label partial recovery.
Readback is read-only and does not require runtime remapping or EEPROM writes.

Consume accepted 07 project/export/identity contracts, 08 artifact manifests and
the current protocol/recovery baseline. Reuse board catalog geometry and immutable
hardware configuration ownership. Current identity/live snapshots cannot recover
unknown assignments; a digest only helps locate an existing local project.

## 12A: Layers, combos and complete declarative configuration

1. Inventory all fields needed to recreate the running configuration: board,
   physical-layout/profile identity, named layers and stable IDs/order, every
   action field, transparent versus explicit no-action, modifiers, one-shot,
   tap/hold timing, autofire, media/mouse, ordered combos, encoder actions,
   callback bindings and applicable processor settings. Classify board-owned
   and compile-only settings explicitly; never silently omit configuration.
2. Generate a deterministic versioned recovery document from the exact exported
   project snapshot and embed it in firmware as read-only flash data. Include
   editor metadata such as layer names, which action arrays cannot reconstruct.
   Measure flash use and define board-specific budgets. Avoid a second writable
   keymap representation or requiring local files to recover declarative data.
3. Extend vendor HID capability negotiation with supported schema, total length
   and content digest. Freeze bounded chunk requests/responses with session and
   request correlation, offsets, integrity validation, timeout, cancellation,
   bounded retries and explicit errors. Reject excessive lengths or invalid
   chunks before allocation/import. Abort on disconnect/reboot and renegotiate.
4. Serve chunks through bounded fixed-storage firmware work, keeping typing,
   telemetry recovery and bootloader control responsive. No unbounded USB
   callbacks, queues or polling loops. Verify scheduling under fake load.
5. Import only complete validated data and reconcile its action identity with
   the running firmware. Create a new project; never overwrite an open draft.
   Distinguish device configuration, edits and incomplete/stale transfers.
6. Resolve registered callback modules by exact binding/version/source digest.
   Preserve unresolved bindings and explain why rebuilding is unavailable; never
   substitute a no-op. Older firmware falls back to explicitly labeled local
   identity lookup, not a claim of reading an unknown keymap.

Acceptance: every supported field round-trips with literal fixtures; fake tests
cover corrupt/missing/duplicate chunks, size limits, cancellation, stale sessions,
disconnect, unsupported schema, callback resolution and non-destructive import.
Demonstrate readback cannot block typing. Run appropriate Zig checks and full
board matrix/parity. A separately authorized Mac/LK7 session retrieves a known
configuration and verifies exact data/identity; unperformed hardware checks stay
pending. This phase does not promise original callback source recovery.

## 12B: Custom Zig source recovery — later follow-up

Deferred independently: the user has no current use case. Complete 12A first.
Compiled callback machine code cannot reconstruct original editable Zig source.

1. Embed exact original callback source bytes and necessary owned transitive
   imports alongside the recovery document. Carry inventory, relative paths,
   module ABI, bindings, content digests and immutable dependency/compiler
   requirements. Define the supported packaging boundary; arbitrary external
   files or unavailable imports cannot be promised recoverable.
2. Measure source-bundle flash/transfer costs and set explicit limits before
   implementation. If compression is selected, bound decompression and measure
   its costs. Source digests must participate in the accepted identity contract.
3. Transfer through the same bounded HID protocol. Validate paths, collisions,
   inventory, expanded size and digests before creating a new owned project.
   Reject traversal, missing imports and unsupported versions without destructive
   partial extraction. Preserve bytes and comments without normalization.
4. Read/import/save never compile or execute received source. Explicit test/build
   can execute compile-time and runtime Zig; preserve external source editing and
   compiler diagnostics. A subprocess is not a security sandbox.
5. Prove recovered project/source yields matching action/callback identity and
   processor behavior. Record all build inputs; source recovery alone does not
   prove byte-identical UF2. Registered modules also need exact recoverable source
   or a documented immutable dependency resolution boundary.

Acceptance: exact source/import/digest round trips, path/size rejection,
explicit-only execution, callback layer constraints and recovered build/behavior.
Hardware source recovery needs its own authorized session. Missing source or
dependencies produce an explicit partial-recovery state.

## Checkpoints and handoff

Commit inventory/schema/storage measurements; bounded fake-tested protocol and
firmware; companion import/UI and offline evidence; separately authorized 12A
hardware evidence. Schedule 12B later with its own acceptance. Publish exact
schema/protocol versions, budgets, field/source matrix, checks and limitations
in a durable handover when implementation starts. No worker is assigned now.

Related: [06B](06-editor-architecture-decision.md),
[requirements](06-editor-requirements.md),
[07](07-compiled-keymap-editor.md), [08](08-build-and-flash-workflow.md).

Editor mockups: [dark workbench](mockups/editor-01-dark-workbench.png),
[light layer sidebar](mockups/editor-02-light-layer-sidebar.png),
[side-by-side](mockups/editor-03-side-by-side.png). These are generated concepts,
not authoritative key labels, callback APIs or implemented behavior.
