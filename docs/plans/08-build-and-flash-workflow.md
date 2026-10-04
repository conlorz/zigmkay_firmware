# 08: Companion build and deliberate firmware flashing

Status: planned. 08A backend depends on accepted 06 and 07A export contract;
08B GUI integration depends on full 07 and accepted 08A. Manual flashing in 04/05
remains sufficient until this integration is implemented. Plan 05 now follows
this milestone: the user creates their profile through the finished editor.
Reuse plan 11's accepted terminal flasher/verification boundary; this milestone
adds project manifests, selected exported-profile builds and GUI integration.

Architecture is selected by [06B](06-editor-architecture-decision.md). Reuse the
07 process-job/test-snapshot boundary in `companion-jobs` rather than introducing
another process controller. Build manifests include the complete owned callback
source inventory/digest and frozen project snapshot. External callback edits
invalidate earlier artifacts; compiler errors retain file/line context. A failed
test or firmware build cannot promote an older artifact to current status.

Coordination: [tracker](TRACKING.md), [workflow](SUBAGENT-WORKFLOW.md), and
[08 handover](handovers/08-build-flash.md). 08A may run beside 07B with fake process/
volume boundaries and no GUI/hardware. Transfer GUI ownership before 08B starts.

## Outcome

A clear workflow from validated profile to identified firmware artifact and an
explicit user-triggered flash, with useful progress/errors and a rollback path.
For the preferred native architecture, extend the companion and existing Zig
flasher rather than introducing a second independent flashing implementation.

## Inspect first

Read `zig-flash` volume selection/copy behavior, root `build.zig`, board/profile
selection, editor export ownership, and live transport lifecycle. Audit existing
assumptions about mounted UF2 drives, file verification, and device identity.
Do not infer safe selection from a generic volume name alone.

## Work

1. Specify user-visible stages: validate/save, build, inspect artifact, select
   device/recovery mode, flash on explicit action, reconnect, verify identity.
   A build must not flash automatically. Keep unsaved/edited, built, flashed, and
   live-accepted profile states distinct.
2. Invoke Zig with an argument vector, controlled working directory, known
   compiler/version, and selected board/profile. Do not interpolate profile names
   or paths into a shell command. Capture bounded output and surface actionable
   compile errors without blocking the UI; support cancellation appropriately.
3. Use an immutable build manifest associating source/project digest, Git revision
   when available, board/profile identity, compiler/dependency versions, and UF2
   path/size/hash. Reject stale artifacts or changed profiles; never select the
   latest file in a directory merely by name or timestamp.
4. Reuse and harden the existing Zig flasher's selection boundary as necessary.
   Identify a compatible UF2 recovery volume and board metadata; handle multiple
   candidates through explicit selection. Validate UF2 structure/family and
   board compatibility to the extent available. Explain any board identity that
   cannot be proved in BOOTSEL rather than inventing a unique serial guarantee.
5. Add an explicit editor **Enter bootloader** action over the existing vendor
   HID channel, requested by the user during architecture planning. Extend the
   versioned protocol with capability detection, a session-bound correlated
   request and acceptance/error response. Enable only for the selected compatible,
   identity-verified connection; older firmware uses the physical combo fallback.
   Firmware validates through its bounded control mailbox and transitions from a
   main-loop boundary, reusing the ROM boot path used by `ActivateBootMode`.
   Define bounded acknowledgment/drain timing before disconnect; do not wait
   indefinitely or reboot from an arbitrary USB receive callback. Reject stale,
   malformed and duplicate requests, and never resend automatically after a
   timeout/reconnect. Session tokens are isolation, not authentication.
   Treat HID removal as expected but not proof of BOOTSEL: discover and validate
   the recovery volume through the existing flasher before offering transfer.
   Building, monitoring and editor startup never enter bootloader implicitly.
   Keep the physical combo/recovery instructions available when HID is unavailable.
6. Preserve the known-good rollback artifact and manifest. Handle device removal,
   insufficient space, permission/copy failure, and cancellation before flashing.
   During a copy, follow the actual transport's completion semantics; do not
   promise transactional rollback for a device operation that cannot provide it.
7. After copying, reconnect monitoring and negotiate board/profile/session
   identity. Distinguish successful file transfer from confirmed running firmware
   and from user-verified typing. Mismatch/timeouts show useful recovery steps.
8. Document macOS setup, manual fallback commands, logs, and physical recovery.
   Keep test/default build commands hardware-free. Do not expose an implicit
   flash dependency from firmware, editor export, check, or companion startup.
9. If 06 selects a browser route, specify the local Zig service/manual boundary
   before implementation. Limit any service to necessary local operations and
   explicit requests, with origin/path/process validation. Do not add a new
   language or remote build/upload service without user permission.

## Acceptance

- Fake process, filesystem, and device adapters cover successful build/selection,
  invalid export, failed/cancelled build, stale artifacts, identity mismatch,
  multiple/missing volumes, copy failure, removal, and reconnect timeout.
- Paths/profile names with spaces and metacharacters remain literal arguments;
  arbitrary paths cannot redirect a flash to an unrelated drive.
- Fake transport/ROM tests cover bootloader capability negotiation, explicit-only
  dispatch, old firmware fallback, wrong/stale session, duplicate/malformed
  requests, acknowledgment backpressure, expected disconnect and missing/ambiguous
  recovery volumes. A separately authorized device session verifies HID-requested
  BOOTSEL and successful recovery; planning does not authorize that operation.
- Offline tests prove that build/export/startup never calls the real flasher or
  requests BOOTSEL. Tests create artifacts/fake volumes in build caches only.
- `zig build check-full` passes. Manual CLI flashing remains available and
  documented, including rollback and limitations of verification.
- In an explicitly requested hardware session, the user selects and flashes one
  small reviewed LK7 edit. Record manifest/hash, transfer result, reconnect
  identity, and actual typing/overlay checks. Leave unperformed steps pending.

## Commit checkpoints

Commit build/artifact manifest handling; commit fake-tested flasher boundaries;
commit UI/process integration and recovery instructions; then commit the report
from the separately authorized hardware session. All commits remain local.

Automatic background updates, network artifact publishing, other MCU flash
protocols, and unattended firmware flashing are outside this milestone.

Incoming: accepted [04 baseline](handovers/04-hardware.md), shared selector/identity from 07,
[06 decision](handovers/06-architecture.md), and [07 export](handovers/07-editor.md).
08A publishes backend/manifest API and actual fake-test results for 08B; it does
not complete 08. Outgoing full workflow and separate observed hardware evidence
release G08 and inform 09. Copy success, running identity, and typing acceptance
remain distinct recorded results.
