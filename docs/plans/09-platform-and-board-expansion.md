# 09: Document and stage other platforms and keyboards

Status: planned. 09A documentation/inventory may start now; 09B target implementation
is deferred behind LK7/macOS acceptance and selection of a concrete next target.
Board compilation remains part of earlier checks; it does not establish live support.

Coordination: [tracker](TRACKING.md), [workflow](SUBAGENT-WORKFLOW.md), and
[09 handover](handovers/09-expansion.md). Early work is documentation-only and uses
its own files. Refresh matrices from actual accepted handovers as work progresses.

## Outcome

A documented capability matrix and staged implementation plans for additional
host platforms and every existing board, without overstating untested behavior.
Use the board catalog as the inventory rather than recreating sibling repos.

## Platform track

1. Create a support matrix for macOS, Windows, and Linux covering native build,
   tests, label translation, input-source refresh/dead keys, HID collection
   selection, reconnect/recovery, overlay window behavior, editing, and flashing.
   Each capability is implemented/tested, implemented/unverified, unsupported,
   or deferred, with evidence and environment details.
2. Document requirements from current official platform/dependency sources:
   toolchain/SDKs, HID permissions/drivers, desktop/window restrictions, layout
   translation, and UF2 volume discovery. Keep existing imported C bridges; any
   expansion or new non-Zig implementation needs explicit user permission.
3. Select the next host target with the user when a test environment is available.
   Preserve portable models and inject native boundaries; do not spread OS
   branches into codec/editor validation code.
4. Port one capability set at a time and keep offline fake adapters available.
   Cross-compilation checks syntax/link constraints where feasible; real native
   execution and device tests are recorded separately. Do not label a platform
   supported solely because it cross-compiles.
5. Prepare a platform-specific manual acceptance worksheet based on 04/05/08,
   including native layout behavior and recovery. Hardware/flashing remains an
   explicitly requested session, never a default CI/check dependency.

## Board track

1. Inventory every entry in `keyboards/boards.zon`: MCU, wiring, key/layer counts,
   physical geometry, shared/custom actions, split transport, encoders, recovery
   method, USB identity, telemetry, profile selection, and hardware availability.
   Derive names from the catalog and mark unknowns; do not guess from LK7.
2. Keep all ten existing entries compiling on the immutable MicroZig pin. Record
   current live acceptance as LK7-only until additional hardware passes a real
   worksheet. Catalog entries without verified geometry remain explicit gaps.
3. Generalize board/profile metadata and geometry without losing stable physical
   identity or GPIO mappings. Handle different dimensions, split halves, thumbs,
   and rotations. Define encoder visualization separately from physical keys.
4. Audit split boards: authoritative primary state, secondary input forwarding,
   event ordering/loss, reconnect, and final host-visible identity. Do not attach
   two competing telemetry sessions or assume LK7's input index mapping applies.
5. Select one next board with available hardware and a user priority. Prepare a
   board-specific implementation/acceptance plan covering pins, profile import,
   geometry, transport, root/standalone parity, recovery, and rollback.
6. Reuse bounded firmware telemetry/session machinery and editor schemas where
   applicable. Add explicit capabilities/limits rather than silently fitting
   every board into LK7's 34-key/four-layer UI.

## Acceptance and future plan files

Create two maintained matrices (platform capabilities and board capabilities),
setup/recovery documentation, and an ordered backlog with concrete gaps. When a
target is selected, create its implementation plan under `docs/plans/` with its
own dependencies, offline checks, artifact/identity rules, and manual worksheet.

The documentation milestone can complete before target implementation; an
individual support claim completes only after its listed checks run on the
actual platform/board. Attach evidence links and dates, and leave unavailable
hardware pending. Keep current LK7/macOS and ten-board checks green throughout.

Commit capability documentation; commit each portable/native/board adaptation
separately with suitable Zig checks; commit manual acceptance results only when
observed. Never push this local fork or create worktrees/clones as part of adding
targets. Wireless, new MCU families, runtime remapping, and replacement of native
C bridges require separate scoped decisions rather than joining this backlog
implicitly.

Incoming: catalog/source evidence for 09A, then actual 01-08 handovers as available.
Outgoing: honest matrices, gaps, and selected child plans with their own tracker
rows/leases/hardware gates. 09A acceptance cannot accept 09B or claim untested
support. Unselected platforms/boards remain deferred rather than auto-dispatched.
