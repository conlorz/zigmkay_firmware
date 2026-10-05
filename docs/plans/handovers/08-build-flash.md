# 08 handover: build, transfer, and running firmware verification

2026-10-05 follow-up: Flash now optionally requests bootloader entry over HID,
including in the standalone editor. The enabled-by-default toolbar checkbox
can be disabled for manual recovery. See [current behavior and offline evidence](../../evidence/editor-hid-bootloader-2026-10-05.md).
The running profile may differ from the draft in the dedicated bootloader
session; normal overlay identity matching remains exact. This supersedes the
old inspection-popup and verified-live-editor prerequisite descriptions below.
Hardware acceptance of this follow-up remains deferred.

08A offline backend: **Accepted**. 08B offline integration: **Integrated**.
Full G08: **pending a separately authorized hardware session and visual approval**.
Producer/reviewer: coordinator with scoped backend, protocol and editor workers;
all write leases released. Started from clean `3543b42` on 2026-10-05 under the
user's request to continue step 08. No hardware operations, pushes or PRs.

Code checkpoints: `0686909` immutable backend; `888ed37` bootloader wire/firmware;
`77a3dc4` native editor/transfer/reconnect integration and backend corrections.
Inputs: accepted G04 macOS/LK7 recovery, G06 native decision, frozen G07-export
`016cf7d` and full G07 `7168c13`. Plan 05 remains gated on full G08.

## 08A contract

`companion-jobs/src/firmware.zig` exposes `Inputs`, `Command`, `Manifest`, `key`
and `digest`. Literal owned argv selects LK7, Zig 0.16.0 and ReleaseSafe in the
canonical checkout, with absolute export/install paths. Existing `Job` handles
bounded output, cancellation, deadlines and reaping. Builds cannot flash.

Manifest version 1 freezes project/source/build/compiler digests, board/profile
identity, compiler/target/optimization, available Git revision and exact UF2
path/size/SHA-256. Complete callback inventory participates in project/source
identity. Dependency manifests and first-party build/compiler inputs participate
in build freshness. Failed/cancelled/stale builds cannot promote old artifacts.
The existing RP2040 UF2 validator is shared, without a second flasher.

`zig_flash <UF2> <absolute recovery volume> --expected-sha256 <hex>` additionally
checks the exact bytes retained by the flasher before discovery. Existing volume
metadata, ambiguous discovery and transfer failure/removal checks still apply.
RP2 metadata does not prove a unique LK7 serial number. Terminal fallback remains.

## 08B consumer and UI integration

`editor/firmware.zig` owns frozen snapshots, asynchronous build/transfer jobs,
atomic synchronized sibling `.manifest.zon` persistence, current/stale/error
states, reconnect deadlines and rollback. Output stays in
`.zig-cache/editor-firmware/<build key>/`. The pinned executable's actual version
is checked, and its bytes are hashed. External callback changes invalidate builds.

Build captures the selected draft, exports and compiles; Flash opens inspection.
The transfer button requires an absolute selected mounted volume and explicit
confirmation. Build cancellation is available; ordinary editor close/build actions
are refused during an active transfer. Kernel filesystem calls retain the existing
flasher's interruption limits; a device transfer is not transactional.

After transfer, live mode negotiates the frozen board/profile/layout identity
and coherent snapshot, and the overlay uses that frozen profile's labels.
Transfer, running identity and user-confirmed typing remain distinct. An identity
mismatch or timeout cannot become accepted typing. The exact cached G04 accepted
Danish UF2 is retained as rollback when present and hash-matching; a later artifact
replaces that candidate only after explicit typing confirmation. Cache cleanup can
remove artifacts, so preserve a rollback before a real session.

Bootloader capability/action APIs and optional v2 messages 18–21 are documented
in [the protocol](../../device-protocol.md#plan-08-capability-and-bootloader-extension).
Requests require verified live identity, capability, current session and correlated
nonzero request. USB callbacks enqueue only; firmware transitions from the main
loop after bounded acceptance/drain. Stale/malformed/duplicate requests fail;
backpressure abandons entry. No timeout/reconnect automatically retries. Older
firmware retains physical positions 0 + 4. Timed captures include pure capability
and explicit bootloader inputs and never execute hardware during replay.

## Verification and remaining gates

At `77a3dc4`, pinned Zig 0.16.0 `zig build check-full -j4` passes: aggregate package
checks, generated/source inventory guards, all ten board artifacts and matching
root/standalone LK7 UF2 bytes. No hardware tool executes. Logs remain in
`.zig-cache/plan08-check-full.log`. Companion package has 43 passing tests;
companion-jobs has seven passing tests (three process, four manifest).

Tests cover literal metacharacters, immutable manifest ownership, source/compiler
freshness, corrupt UF2/hash, failed/cancelled jobs, actual selected exported LK7
firmware compilation, unconfirmed transfer refusal, changed draft rejection,
fake reconnect identity mismatch/timeout/success, capability negotiation, old
firmware fallback, explicit-only boot requests, session/correlation/duplicate/
malformed rejection, ack backpressure/drain and capture replay. Existing flasher
fake-volume and transfer tests retain missing/multiple volumes, removal/copy
failure and bounded process failure coverage.

`editor-check` exercises 88 captures across dark/light and 1x/2x, plus panel
geometry and semantic interactions. Added build failure/stale/building,
bootloader fallback, transferred and reconnect-timeout states. Screenshots/logs
stay in `.zig-cache/editor-acceptance` and `.zig-cache/plan08-editor-check.log`.
The approved plan 07 golden files remain unchanged; the newly active toolbar
intentionally differs, so updated screenshot approval is pending. No new golden
baseline has been silently accepted.

The [verification guide](../08-editor-verification.md) contains the manual
worksheet. HID-requested BOOTSEL, actual transfer, reconnect identity, typing and
overlay behavior remain unobserved for this implementation. No compilation,
fake result or screenshot releases G08. Next work is the user's explicit small
reviewed LK7 edit/hardware session; personal profile 05 and plan 12 remain deferred.
