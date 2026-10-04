# 01: Production protocol and recoverable companion state

Status: planned. Depends on the consolidated baseline. This milestone is fully
offline and is the next implementation task.

## Outcome

A documented, portable protocol and session reducer that can establish identity,
obtain a complete current state, consume ordered deltas, and recover from loss
or reconnection. Firmware and native adapters in 02/03 consume this contract.

## Inspect first

Read `docs/device-protocol.md`, `device-protocol/src/root.zig`,
`companion-model/src/root.zig`, `zigmkay/src/telemetry.zig`,
`tests/test_device_protocol.zig`, `tests/test_observer_inputs.zig`, and
`tests/test_lk7_trace.zig`. Also inspect the existing USB descriptor in
`zigmkay/src/usb_if.zig` and the pinned MicroZig HID API before specifying control
traffic. Current metadata bounds are 127 keys and 15 layers; LK7 uses 34/4.

## Work

1. Specify host/device message direction, request correlation, legal connection
   states, and wire layouts before wiring firmware. Required capabilities are
   Hello/identity, snapshot request/response, key/layer deltas, and recovery.
2. Identify protocol compatibility, board ID, dimensions, keymap/profile identity,
   and a session/generation identifier. A count match alone does not establish
   that the GUI's key labels match the firmware. Define a canonical identity
   representation that both builds can compute; custom callback behavior must
   have a declared identity rather than hashing function-pointer addresses.
3. Keep 32-byte vendor reports and little-endian encoding. Specify HID report-ID
   handling at the transport boundary, including the native write prefix. Do not
   include that prefix in portable codec bytes.
4. Decide whether additive v1 kinds suffice or a new major version is required.
   Preserve the existing v1 key/layer golden bytes as explicit compatibility
   tests. Reject unsupported legacy/versioned data deliberately; do not add
   ambiguous heuristic legacy decoding.
5. Define the complete snapshot: physical pressed keys, active layer mask,
   highest layer, persistent modifiers, and the sequence/session boundary at
   which it becomes authoritative. Physical presses include disabled keys and
   combo components; this is not the six-key USB output report or release map.
6. Specify packet budgets. If identity/snapshot metadata requires multiple
   reports, define transaction IDs, part indices/counts, limits, duplicate rules,
   timeout, and atomic commit. Partial, interleaved, or obsolete snapshots must
   never leave a partly updated model.
7. Define a coherent ordering rule between the snapshot and subsequent deltas.
   Cover events occurring while a snapshot is requested or transmitted. No
   missing release may survive recovery as a permanently highlighted key.
8. Add pure session state around the existing reducer: disconnected, negotiating,
   synchronizing, live, recovering, and incompatible, or an equivalent compact
   design. State transitions produce bounded transport intents for adapters to
   execute; portable code must not import SDL or MicroZig.
9. Define sequence wraparound, first-event handling, gaps, duplicates, stale
   responses, boot/session changes, and host reconnect. Bound retries and state
   storage; model timeouts with injected time. Keep strict legacy offline replay
   behavior explicit while adding a session-aware replay fixture/runner.
10. Update the protocol document with exact bytes, lifecycle examples, supported
    limits, and ownership of sequence numbers. Do not infer persistent keyboard
    modifiers from temporary shifted-character output pulses.

## Acceptance

- Independent literal fixtures encode/decode identity, snapshot, and recovery;
  tests do not only round-trip bytes emitted by the same encoder.
- A new connection with already-held keys initializes correctly from a snapshot.
- Gap, duplicate, sequence wrap, queue overflow indication, stale old-session
  traffic, fragmented/partial snapshot, and interrupted recovery are exercised.
- Invalid lengths, versions, kinds, IDs, dimensions, masks, padding, and excessive
  part counts fail without applying partial state or growing allocations.
- Snapshot failure leaves the last complete state explicitly stale; successful
  recovery replaces it atomically and restores contiguous delta processing.
- No fabricated time sleeps or native device access are needed in tests.
- Current processor/observer tests and literal LK7 trace remain meaningful.
  Portable native/Wasm compilation and `zig build check` pass.

## Commit checkpoints and handoff

Commit the agreed wire contract and literal fixtures; commit codec additions;
commit session/recovery model; then commit replay integration and documentation.
These are focused local commits in the existing checkout.

Handoff includes exact message layouts, transport actions, memory/queue budgets,
and the snapshot cut-over algorithm required by 02/03. Hardware delivery,
overlay polish, flashing, editor UI, and runtime remapping are outside this plan.
