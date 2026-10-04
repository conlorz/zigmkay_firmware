# 09 handover: capabilities and selected target plans

## 09A documentation result

State: **Accepted**, documentation-only 09A, 2026-10-04.
Producer: inventory worker; reviewer: coordinator.
Base revision: `ab66f12`; dispatch tracker revision: `ed14722`.
Documentation commit: `99c1dbe`. Coordinator reviewed all four documents,
source-linked capability distinctions and local links; `git diff --check` passed.
No source change requires a new Zig check for this documentation-only result.
Contract/version: documentation inventory v1; no public API, wire, schema or
identity changes. No upstream implementation handover was accepted at dispatch.

Inputs consumed: workspace/repository AGENTS.md, [roadmap](../README.md),
[tracker](../TRACKING.md), [workflow](../SUBAGENT-WORKFLOW.md),
[09 plan](../09-platform-and-board-expansion.md), [handover rules](README.md),
actual ten-entry catalog/runner/keymap/build/USB/native bridge/GUI source,
and current official Apple, Microsoft, Raspberry Pi, SDL, HIDAPI and xkbcommon
sources linked with consultation date in the delivered documents.
Baseline offline claims use [development](../../development.md) and the roadmap;
historical Python-era evidence was not promoted into current milestone acceptance.

Exact changed paths and entry points:

- [Platform matrix](../09-platform-capabilities.md): macOS/Windows/Linux native
  build, labels, refresh/dead keys, HID, recovery, overlay, editing and flashing;
  dated sources, baseline scope and ordered P1-P6 gaps.
- [Board matrix](../09-board-capabilities.md): all ten catalog IDs, configured
  RP2040 target, pins/counts/layers, geometry/actions, split/encoders, shared USB,
  telemetry/profile/recovery and hardware availability; ordered B1-B6 gaps.
- [Setup/recovery](../09-setup-and-recovery.md): offline commands and native
  requirements, proposed identification/recovery/rollback worksheet and UF2 limits.
- This handover: 09A submission and explicit 09B gate.

## Consumer instructions

Preserve the distinction between recorded baseline offline tests, inspected
implementation, native runtime execution and actual device acceptance. No board
or host gains live support from this inventory. Only LK7 has physical metadata
and companion eligibility; all ten compile targets are configured as Pico/RP2040,
not verified controller hardware. Fixed source keymaps are not selectable profiles.
Shared USB serial/VID/PID cannot replace the accepted 01/05 identity contract.

Refresh matrices after accepted [04](04-hardware.md)/[05](05-keymap.md), then
[07](07-editor.md)/[08](08-build-flash.md) evidence. Check the actual integrated
revision before changing a state. Retain native boundaries and consume the accepted
portable contracts rather than duplicating them for a target. No source/build
integration is requested by 09A.

Coordinator reported an additional baseline macOS control-path limitation:
SDL macOS `hid_write` sends an IOHIDDeviceSetReport output while the pinned
MicroZig SetReport path acknowledges without delivering payload. Planned 02 work
must prove its repair with offline tests and later hardware acceptance. Current
bidirectional live telemetry is not operational evidence.

## Verification and remaining gates

Worker verification: read catalog and each of its ten runner sources, resolved
keymap imports and layer arrays, compared source flags against scanner/encoder
configuration, inspected publisher/USB/GUI/platform bridges, and checked linked
local paths with scoped shell file-existence checks. No Zig build, hardware tool,
Git/index operation, dependency install or new implementation language was used.
Coordinator owns final diff/Markdown review and hardware-free integration checks;
review accepted the documentation at `99c1dbe`. Source findings are inspection
evidence, not reproduced native failures.

Manual evidence: none. Native Windows/Linux execution and all device results are
pending. macOS baseline native labels are US-layout tests, not Danish/EurKEY Next
acceptance. Exact host OS/architecture/input-source versions were not measured
by this worker. Proposed recovery worksheet rows have no results.

Material findings: missing nine-board geometry; fixed profile imports; shared
nonunique USB identity; missing baseline session/reconnect/production sink;
Molekula actual38/five layers with stale40/encoder comments and unused absent-pin
references; encoder-demo click not scanned; Linux compose feed/status mismatch,
default-layout/locale handling and cross-host missing bridge; Windows native
link/layout/AltGr/dead-key scope unverified. Existing bridge expansion/fixes need
explicit user permission for new or expanded C implementation under AGENTS;
documentation alone authorizes none.

Tracker deliverable released: 09A documentation accepted; this does not accept
09B or parent live support. Worker ownership is released; coordinator owns future
matrix refresh assignment. G01 and every hardware gate remain pending.

## 09B selected target result

State: **Not produced**; deferred. No extra platform or board selected.
Candidates are grouped by dependency/test coverage in the matrices, without
claiming a user priority. Entry requires LK7/macOS baseline acceptance and the
user's concrete target/environment choice. Then create a child plan, tracker row,
exact source lease, accepted 01/02/03/05 input revisions, portable/native/hardware
gates, artifact/identity/rollback rules and its own durable handover.

Wireless, new MCU families, runtime remapping, browser flashing and replacement
of retained native C bridges remain separately scoped decisions. Next action:
review/commit 09A locally, continue ready offline milestones, and refresh observed
support when actual acceptance is available.
