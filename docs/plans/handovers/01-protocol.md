# 01 handover: protocol, identity, and session recovery

State: **Not produced**. No implementation commits or checks are recorded.
Producer: protocol worker. Reviewer: coordinator.
Plan: [01](../01-protocol-and-recovery.md). Rules: [handover format](README.md).

## Required input and output

Input: inspected current codec/model, literal v1 fixtures, USB descriptor/API
constraints, and the preserved processor observation semantics.

Publish exact wire bytes/version, directions/report-ID boundary, identity/digest
representation, session/control API, snapshot cut-over ordering, sequence rules,
fragment/queue/time bounds, error/retry semantics, and literal offline fixtures.
List actual source/API entry points and native/Wasm check results. Record how
custom callback identity is declared and how legacy replay compatibility works.

## Consumers and gate

- [02 firmware](../02-firmware-telemetry.md): produces reports/control responses
  and coherent snapshots using the frozen contract.
- [03 overlay](../03-macos-live-overlay.md): consumes the same session API and
  identity with a fake/native transport boundary.
- [05 keymap](../05-eurkey-next-mac-keymap.md), [07 editor](../07-compiled-keymap-editor.md),
  and [08 build/flash](../08-build-and-flash-workflow.md): reuse this identity;
  they must not create incompatible profile digests.

Coordinator acceptance releases **G01** for parallel 02/03. Transfer protocol/model
ownership back to the coordinator; consumers request amendments rather than edit
the frozen interface. Hardware delivery remains unverified and outside this gate.

## Integrated result

Pending. Complete the [result template](README.md) at submission/integration.

## Contract checkpoint

State: Submitted (proposal only; implementation and G01 remain pending).
Producer: protocol worker; base `ab66f12`, lease checkpoint `ed14722`.
Changed paths: `docs/device-protocol.md`, `tests/test_protocol_session.zig`, this
handover. No production sources changed. Coordinator owns integration/commits.

Proposed v2 contract, canonical digest serialization, session/actions API,
resource bounds and transport requirements are specified in
[the protocol](../../device-protocol.md). Dedicated tests contain independent
literal Hello, three-part identity, snapshot request/two-part snapshot, key
release and overflow reports. Existing v1 literals and binary trace are untouched.

Scoped check: `/Users/clorz/.zvm/0.16.0/zig test tests/test_protocol_session.zig`
passed 1 test on the working tree. This verifies fixture framing/padding only;
codec/session acceptance and portable integrated checks remain pending.
`zig fmt tests/test_protocol_session.zig` completed. No hardware access.

Important downstream requirement: macOS SDL writes use Output SetReport, while
pinned MicroZig only ACKs that path. 02 must implement a first-party Zig controller
wrapper for validated vendor-interface setup and ep0 OUT data-stage reception,
alongside interrupt OUT reception. Its short-transfer validation is mandatory.
No C expansion or upstream dependency edit is authorized.

Ownership: worker paused at contract checkpoint awaiting coordinator review.
Next action: freeze/review contract, commit literal fixture checkpoint, then
release codec implementation. G01 remains pending.

## Codec checkpoint

State: Submitted; worker paused before Session implementation. Contract proposal
commit `c3db81a` consumed. Production change: `device-protocol/src/root.zig` adds
portable v2 framing, identity/snapshot bodies and fragment helpers, explicit
validation/directions, and canonical semantic SHA-256 identity hashing. Dedicated
tests/doc and this handover updated. Coordinator publication/build changes are
separate owned integration prerequisites, not worker changes.

Scoped checks on this working tree:

- Zig 0.16.0 `zig test --dep device-protocol --dep layout-model
  -Mroot=tests/test_protocol_session.zig --dep layout-model
  -Mdevice-protocol=device-protocol/src/root.zig
  -Mlayout-model=layout-model/src/root.zig`: 6 passed, including independent wire
  fixtures, complete canonical byte stream plus literal digest, action/callback
  changes, malformed data and exhaustive single-byte fixture mutations.
- `zig test --dep device-protocol --dep layout-model --dep companion-model
  -Mroot=tests/test_device_protocol.zig --dep layout-model
  -Mdevice-protocol=device-protocol/src/root.zig
  -Mlayout-model=layout-model/src/root.zig --dep layout-model --dep device-protocol
  -Mcompanion-model=companion-model/src/root.zig`: existing 6 v1 tests passed.
- `zig fmt device-protocol/src/root.zig tests/test_protocol_session.zig`: completed.

All commands use `/Users/clorz/.zvm/0.16.0/zig`; no hardware accessed. Coordinator
native/Wasm/LK7 publication checks pending. Session/recovery, replay, full acceptance
and G01 remain pending. Next: coordinator review/commit codec, release reducer.

## Session and replay checkpoint

State: Submitted; worker paused. Accepted input: codec/publication/build checkpoint
`c15d182` (coordinator reports 289/289 root tests and Wasm codec/hash compilation).
Worker changed `companion-model/src/root.zig`, `apps/headless/main.zig`, dedicated
`tests/test_protocol_session.zig`, protocol doc and this handover. Coordinator's
portable entrypoint and generated replay process fixture are separate integration
prerequisites. No Git/index changes or hardware access by worker.

Session API implements injected-time negotiation, identity compatibility, atomic
snapshot assembly/replacement, pre-cut and duplicate filtering, wraparound and
gap/overflow recovery, obsolete session/request rejection, bounded retries,
request exhaustion, explicit stale retention, and sequenced UI signals. Actions
capacity two; more than two pending signal presses abort the candidate atomically.
Native aarch64 sizes measured: Session 528, Actions 76, Packet 32 bytes; all buffers
are static. Unsupported version is incompatible; other malformed framing produces
bounded recovery actions and records last_error. Consumer details in protocol doc.

Replay `--session` infers initial token from first Identity, uses actual shared
LK7 identity, consumes device reports only at deterministic 1 ms/report and fails
unless terminal state is live/current. Default strict v1 replay remains intact.
Arbitrary live timing/disconnect recordings need an explicitly timed format in 03.

Scoped checks, working tree:

- Prior dedicated test command with companion-model dependency added: 15 passed.
  New traces cover held initialization, wrap/duplicates, gap/overflow/malformed
  recovery, atomic/stale state, fragments/conflicts/obsolete responses, bounded
  pending deltas, pre-cut events, timeout exhaustion/fresh negotiation, request
  wrap, identity mismatch, invalid snapshots, interrupted recovery and signals.
- `/Users/clorz/.zvm/0.16.0/zig build-obj -target wasm32-freestanding
  -fno-emit-bin --dep device-protocol --dep companion-model
  -Mroot=tests/protocol_portable.zig --dep layout-model
  -Mdevice-protocol=device-protocol/src/root.zig
  -Mlayout-model=layout-model/src/root.zig --dep layout-model --dep device-protocol
  -Mcompanion-model=companion-model/src/root.zig`: passed, including coordinator's
  actual Session/codec/hash entrypoints.
- Direct freestanding `zig test` attempt failed in standard-library OS/Io test
  runner, which is not freestanding; portable production build-obj above passed.
- `zig fmt` owned Zig files completed. Scoped tests passed before removal of an
  informational native-size print; no behavior changed afterward.

Remaining gate: coordinator root process/replay, check/check-full and stable-tree
integration evidence, then commit/final acceptance of G01. No hardware delivery
claim. Worker releases editing for review; next concrete action is coordinator
integration checks and contract freeze for 02/03.
