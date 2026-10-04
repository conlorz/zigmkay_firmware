# USB/HID recovery: research first, then keyboard, custom codes and flashing

Status: **Research/design accepted and offline R3 integrated at `2e30e9d`;
R-keyboard and R-custom accepted on macOS; R5 implemented at `0aa2ca7`, final
updated root flashing run pending.** See the
[decision](../research/usb-hid-decision.md) and
[session preparation](../research/usb-hid-diagnostic-session.md).

User requested this reset on
2026-10-04. Stop the current trial-and-error hardware loop. This plan takes
priority over the remaining milestone/subagent workflow, including 04–09.
The next session starts with research, not another flash or speculative patch.

Read [the recovery handoff](handovers/11-usb-hid-recovery.md), repository and
workspace AGENTS.md, and [the tracker](TRACKING.md). Canonical implementation
checkout: `zigmkay_firmware/`, local branch `local/monorepo`, Zig 0.16.0.
Inspect actual HEAD/status; the implementation left by this session is `637fd71`.
Keep all changes and commits local. No pushes, PRs, sibling clones or worktrees.
Production code, build tools, diagnostics and tests remain Zig. New languages
or expansion of C interoperability require explicit user permission.

## Objective and order

Establish an evidence-backed USB device design that macOS can configure and use
as a keyboard, with Windows and Linux compatibility assessed explicitly. Only
after standard keyboard operation is established, implement the custom codes
and companion controls against the researched contract. Then complete the
root mise flashing utility and its verification behavior. Resume the original
roadmap only when this recovery work is accepted and the user requests it.

Treat these as distinct problems: malformed descriptors, unanswered control
requests, device-side initialization failure, OS driver matching, application
ownership/access permissions, bootloader filesystem behavior, and UF2 validity.
Do not call all of them “macOS blocking the device.” Identify the failing stage.

## Phase R1: reconstruct evidence before choosing changes

1. Reconcile commits, artifacts, package/build configuration and the handoff.
   Audit the patches since `ab66f12`; retain their evidence without assuming
   that each patch is necessary or sufficient. Do not reset the checkout.
2. Draw the complete path: reset/startup → descriptor discovery → configuration
   selection → endpoint/driver initialization → HID report discovery → typing
   → optional companion session → BOOTSEL → UF2 transfer → firmware restart.
   Map each step to first-party code and pinned MicroZig code.
3. Separate observations from hypotheses in an evidence table. In particular,
   a successful write and the USB product name prove neither configured HID
   interfaces nor working input. An old source revision compiled with today's
   toolchain is not a known-good historical Windows firmware binary.
4. Audit exact emitted bytes as well as Zig logical sizes. Reproduce the nested
   extern/align(1) constant discrepancy with minimal Zig sources for host and
   Cortex-M0+, compare constants and runtime paths, and inspect object/UF2 data.
   Check descriptor use inside controller/driver initialization as well as the
   bytes sent to the host. Explicit wire serialization fixed the observed
   malformed configuration, but configuration still times out.
5. Inventory every current keyboard, consumer, mouse, vendor HID and reset
   interface; report formats, endpoint addresses/sizes, strings, IDs and request
   handlers. Inventory custom actions/signals and all producers/consumers.

Output: `docs/research/usb-hid-evidence.md`, containing an annotated sequence,
source paths/revisions, actual bytes, uncertainties and discriminating checks.
Store generated probe outputs in build caches, not committed generated sources.

## Phase R2: deep primary-source platform and specification research

Produce `docs/research/usb-hid-platforms.md`. Record source versions, access dates,
direct links and supporting sections; separate normative requirements, platform
implementation details and reported bugs. Prefer USB-IF specifications, Apple
documentation/open-source drivers, Microsoft Learn/driver documentation, Linux
kernel documentation/source, RP2040 datasheet/boot ROM and pinned/upstream
MicroZig sources. Search results and forum anecdotes are leads, not conclusions.

Research and compare:

- USB 2.0 Chapter 9 state transitions and device/interface/endpoint requests:
  descriptor length/truncation, configuration numbering, Get/SetConfiguration,
  GetStatus, features, alternate settings, unsupported-request STALL behavior,
  addressing, reset and reconfiguration.
- EP0 transfer sequencing: SETUP cancellation, DATA0/DATA1, multi-packet IN,
  status IN/OUT, zero-length packets, stalled transfers, stale completions and
  host retries. Verify RP2040 register handling against its documented model.
- HID 1.11 and the applicable HID Usage Tables: descriptor grammar and report
  sizes, boot versus report protocol, the standard eight-byte boot keyboard
  report including its reserved byte, modifier/usage ranges, rollover, LEDs,
  Get/SetReport, Get/SetIdle, Get/SetProtocol, report IDs and interrupt/control
  delivery. Explain precisely which requests are required for each interface.
- Composite device matching and endpoint allocation for keyboard, consumer,
  mouse, vendor telemetry and RP2040 reset. Decide whether all existing
  interfaces are needed for the first reliable baseline. Check relative mouse
  fields, consumer usages and consistent input/output descriptor sizes.
- macOS: descriptor/configuration rejection versus HID parsing, IOUSBHost and
  IOHID matching, vendor HID access, app/device ownership, accessory approval,
  Input Monitoring/TCC where applicable, and browser/native access boundaries.
  Determine which rules apply to kernel keyboard input and which apply only to
  a companion reading reports. Do not prescribe broad permissions as a guess.
- Windows: composite/HID driver matching, boot/report behavior, vendor HID
  handling, driver binding and collection discovery; identify actual reference
  behavior where Windows previously worked.
- Linux: usbcore/usbhid/HID parsing, report handling, hidraw discovery and
  device permissions. Keep HID compatibility separate from hidraw permissions.
- MicroZig: exact pinned implementation, upstream changes/issues, toolchain
  compatibility and dependency options. Compare a bounded first-party fix,
  compatible immutable dependency update and a replacement USB implementation
  by evidence, maintenance cost and testability. No broad rewrite by default.

Include a matrix with specification requirement, current behavior, macOS,
Windows, Linux, evidence, proposed treatment and validation method. Lack of a
platform/device test must remain “unverified,” not “supported.”

Output: `docs/research/usb-hid-decision.md`: recommended interface/report layout,
request/state-machine contract, ownership boundaries, implementation approach,
rejected alternatives and a finite test plan. Resolve reserved/custom usage
questions explicitly rather than putting proprietary codes on the standard
keyboard usage page. Research completion is gate **R-HID-design**.

## Phase R3: implement and establish standard input first

After the research decision is recorded, implement the smallest coherent fix.
Audit or replace the earlier speculative patches according to evidence. Preserve
the shared identity/session contract unless an explicit amendment is documented.
Maintain first-party packages and immutable external dependency pins.

Required offline coverage includes independently specified descriptor bytes and
parsing, descriptor/report size consistency, boot/report operation, supported
and unsupported requests, EP0 packet/status sequences, cancellation, reset,
configuration/deconfiguration/reconfiguration and endpoint backpressure.
Exercise the real production boundary where possible; fake tests that only
restate the wrapper are insufficient evidence. Inspect target output so compiler
aggregate-layout mistakes cannot pass host-only tests unnoticed.

Run appropriate scoped mise/Zig tests, then `mise //:check-full` on a stable
tree. Default builds/checks must never access hardware. Keep all ten board builds
and root/standalone parity. Commit focused changes locally.

Prepare one bounded, instrumented hardware session after explicit user hardware
authorization in the new session. Before flashing, provide identified firmware,
rollback/recovery procedure, questions the run will answer, capture tools and
stop criteria. Choose observations that distinguish host rejection, missing
request response, panic/hang and driver/report failure. If diagnostic access or
equipment is unavailable, explain the limitation before choosing another probe.
Do not repeat minimally different speculative flash cycles.

Gate **R-keyboard** requires actual macOS configuration, attached HID keyboard
interface, key press/release and modifiers, usable typing without the companion,
LED/control behavior where supported, and recovery after unplug/replug. Record
the entire run. Windows/Linux hardware checks are conditional on availability;
offline assessment does not replace them.

## Phase R4: custom codes and companion controls

Proceed only after R-keyboard. Define “custom codes” from the inventory: internal
key actions, existing companion toggle/visibility signals and vendor protocol
commands; keep them distinct from standard USB keyboard usages and OS layout
mapping. The EurKEY Next profile/editor milestones remain deferred.

Specify the vendor usage page/usage, report sizes/IDs, control versus interrupt
transport and host collection selection based on R-HID-design. Preserve bounded
queues and nonblocking typing. Document any protocol/identity amendment and
consumer migration before integration. Test malformed requests, absent/disconnected
companions, overflow, reconnect, snapshot/recovery, command acknowledgment and
press/release sequencing. Review existing C bridge limits before any proposed
change to them; do not expand them silently.

Gate **R-custom**: actual custom actions work in the agreed macOS companion
while standard input remains usable, with offline regression coverage and
explicit limits for untested platforms.

## Phase R5: finish flashing through root mise

Research the RP2040 boot ROM's UF2 completion/restart behavior and supported
transport paths. Audit current direct write/sync, macOS FSKit FAT behavior,
volume discovery and disconnect/reconnect races. Determine which macOS disk
notifications are expected consequences of boot ROM restart and which can be
prevented by a supported transfer/eject sequence. Do not eject before transfer
completion or promise that an automatic restart notification can be removed.

Keep `mise //:flash <board>` and `mise //:flash-file <file>` as the terminal
entry points. No Finder/manual copy prerequisite. Validate UF2 family, headers,
block count/order/uniqueness and target/address compatibility before opening a
device. Identify both artifact and intended device, including multiple-device
ambiguity. Bound waits and report discovery/open/write/sync/restart failures
accurately. Plan cancellation/recovery for uninterruptible filesystem syscalls;
a polling timeout alone cannot terminate a kernel-blocked write.

Compare filesystem transfer and direct USB transport before selecting a backend.
Any dependency/tool addition must respect Zig, immutable pins and bridge rules.
Test missing/wrong volumes, access denial, read-only media, partial writes,
disappearance during transfer, source changes, cancellation, invalid UF2s and
multiple devices with hardware-free fixtures. Separate “transfer completed” from
“device restarted” and “firmware verified”; do not report stronger evidence than
observed. Verification must have a researched safe method and timeout.

Gate **R-flash**: root mise performs an identified flash without manual copying,
the intended firmware restarts and is verified, typing/custom behavior persists,
and failure/recovery instructions are tested. Record remaining macOS notification
behavior explicitly. Update the manual worksheet and user documentation.

## Coordination and completion

Research may use scoped subagents only when authorized by the new session's
execution request; one coordinator integrates evidence and owns Git/build glue.
Useful independent research scopes are specifications/control transfers,
platform matching/access, and RP2040/MicroZig/compiler/flash. Assign disjoint
research files and stop workers at evidence review before implementation.
Do not dispatch original 05–09 tasks or use their gates to divert this recovery.

At every gate update the tracker and recovery handoff with revisions, source
links, checks, hardware observations, remaining unknowns and exact next work.
Completion requires R-HID-design, R-keyboard, R-custom and R-flash. Original G04
is not automatically accepted: identify which worksheet checks remain. Ask the
user about resuming the old roadmap only after reporting recovery results.
