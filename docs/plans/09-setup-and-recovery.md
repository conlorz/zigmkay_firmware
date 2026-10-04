# 09A setup and recovery inventory

Dated 2026-10-04 against `ab66f12`. This document prepares offline work and future
manual sessions. It does not authorize connecting, reading, resetting or flashing
a device. [Platform matrix](09-platform-capabilities.md) and
[board matrix](09-board-capabilities.md) state implemented/unverified boundaries.

## Offline setup

Use the canonical monorepo with Zig 0.16.0 from `.zigversion`; retain immutable
manifest revisions/hashes and existing C bridges. First-party implementation,
tests and generators stay Zig. Never create sibling clones/worktrees or publish
this local fork. Current commands are documented in [development](../development.md)
and [root README](../../README.md); old Python/worktree instructions are historical.

Coordinator owns the stable integration lane. On a paused tree, `zig build check`
is the normal hardware-free check; `zig build check-full` also builds all ten
boards/GUI/flasher, checks standalone packages and LK7 root/standalone parity.
Use `zig build firmware -Dkeyboard=lk7` for an explicitly selected offline UF2,
`zig build firmware-all` for the inventory, and `zig build list-keyboards` for
catalog IDs. These are builds; root `flash` remains disabled. Generated outputs
belong in caches; committed regeneration requires explicit authorization.

macOS baseline uses installed Xcode27/SDK27 and Carbon. Windows needs a native
Windows desktop/link environment for its imported API bridge; Linux needs native
xkbcommon headers/library/layout data and a named X11/Wayland desktop. SDL builds
have platform-specific dependencies. Read the dated primary links in the platform
matrix before choosing a test environment. No dependency installation occurred
in 09A. Cross-build success and upstream API availability cannot replace native
execution.

Offline GUI defaults are safe: replay supplies recorded protocol fixtures;
`--smoke` renders three frames; `--live` explicitly accesses HID and belongs only
to an agreed hardware session. Pending 01-03 work must be accepted before using
live mode for milestone acceptance.

## Future session preparation and identification

Before requesting 04 or a selected 09B session, prepare the accepted handovers,
exact source revision, board/profile ID/digest, compiler/dependency versions,
firmware/GUI artifact paths and hashes, last known good rollback UF2 and a worksheet.
Record host OS/architecture, desktop/compositor, input-source ID/version and
physical device/controller details. Verify root/standalone parity for the selected
board/profile; the baseline LK7 parity does not establish every board's parity.

Enumerate vendor collection `FAFA:00F0`, usage `FF31:0074`, with explicit selection
when multiple devices match. Shared serial `00000001` is not unique identity.
Permission/open failure must yield a visible disconnected/error state, never
open the keyboard collection by fallback. macOS privacy behavior, Windows access
policy and Linux hidraw/libusb permissions need real observation. Install no
replacement keyboard driver based on this plan; future Linux rules should target
the specific vendor interface and required user access after backend verification.

## Recovery worksheet for an authorized session

1. Confirm expected identity/profile before interpreting any inputs. Unknown
   protocol/version/profile stays visibly incompatible; no guessed LK7 mapping.
2. Capture initial authoritative snapshot, press/release and layer/hold state.
   Check loss/duplicate/out-of-order reports with offline fixtures first.
3. Unplug/replug and restart the companion. Record clearing stale pressed state,
   re-handshake/snapshot and time to recovery; don't call successful opening a pass.
4. On split targets, disconnect/rejoin the secondary and test held key/encoder
   events, loss and both-half reset/primary choice. Observe one host session.
5. For an explicitly requested flash: identify the selected board and boot volume,
   verify artifact/rollback, use the authorized deliberate flash action, then record
   transfer, disconnect/re-enumeration, running identity and ordinary typing.
6. If typing/identity fails, use the prepared rollback under the same explicit
   session authorization and record the actual outcome. Keep failures pending.

These are proposed worksheet rows, not observed results. 04/05/08 retain their
own concrete acceptance sheets and authority.

## BOOTSEL and mounted-volume limits

Raspberry Pi documents Pico BOOTSEL mass storage `RPI-RP2` and reboot/disappearance
after UF2 copy. The bootloader lives in ROM. That is generic MCU recovery evidence,
not proof that a catalog PCB exposes an accessible button or uses the presumed
controller. [Official Pico documentation](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html)
was consulted 2026-10-04. Windows drive letters, macOS `/Volumes` names and Linux
mount locations vary; discover and confirm a volume instead of hardcoding one.
Multiple boot devices, automount failure, read-only permissions, disappearing
volumes and copy errors are future fake-adapter and manual cases for 08/09B.
No BOOTSEL request, mount probing or write was performed here.

Keymap boot combos are inventoried per source in the board matrix. Their indices
are not physical button instructions until geometry/profile and actual firmware
are confirmed. ROM recovery avoids depending on a working keymap, but split-half
recovery and flashed identity still require board-specific evidence.

Next move: coordinator reviews 09A, keeps matrices current after accepted 04/05/07/08,
and asks for one additional target/environment when those gates allow it. All
unselected target implementation remains deferred.
