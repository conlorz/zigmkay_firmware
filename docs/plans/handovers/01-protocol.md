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
