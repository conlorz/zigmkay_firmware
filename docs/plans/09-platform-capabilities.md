# 09A platform capabilities

Inventory date: 2026-10-04. Source baseline: `ab66f12`; execution tracker started
at `ed14722`. This is documentation evidence, not a platform acceptance report.
Refresh this matrix only from integrated checks and accepted handovers.

States: **T** implemented/tested within the stated offline scope; **U** existing
implementation/unverified; **N** unsupported by the baseline; **D** deferred
behind a milestone or target decision. A dependency's support does not establish
application support. No platform has current milestone hardware acceptance.

| Capability | macOS | Windows | Linux | Baseline evidence and limits |
| --- | --- | --- | --- | --- |
| Native host build/tests | T, baseline offline | U | U | [Development](../development.md) and [roadmap](README.md) record macOS checks; no Windows/Linux native execution record consumed. Companion publication uses `b.graph.host`, not an arbitrary cross target. |
| Portable models/codecs and mapping tables | T, host/Wasm scope | U, native execution | U, native execution | Portable checks and HID mapping tables cover logic; they do not test native APIs or a desktop. |
| Native layout labels | T, US-layout tests only | U | U, known source gaps | [zkeymap build](../../zkeymap/build.zig), [KeyMap](../../zkeymap/src/KeyMap.zig), and platform bridges exist. Danish/EurKEY Next correctness is pending 04/05. |
| Input-source refresh | U, explicit API | U, explicit API | U, reloads defaults | `KeyMap.refresh` exists; baseline GUI has no input-source notification/refresh integration. Windows reads current thread HKL; Linux creates a default rules keymap rather than acquiring the compositor's active layout. |
| Dead keys/compose | T, bounded baseline tests; U for selected layout | U | U, known source gaps | [Native tests](../../zkeymap/src/root.zig) cover baseline behavior. Linux passes UTF-8 output length to compose feed and compares feed result with compose status; see gap P3. |
| HID collection selection | U | U | U | [GUI](../../zigmkay-companion/src/main.zig) enumerates VID/PID and opens usage page `FF31`, usage `0074`; no real collection-selection evidence. Multiple matching devices have no explicit chooser. |
| Handshake/snapshot/reconnect/recovery | N; D to 01-04 | N; D to selected target | N; D to selected target | Baseline opens once and reads reports; firmware/GUI codec mismatch and missing production sink are recorded in [roadmap](README.md). Portable recovery work is not a native device pass. |
| Ordinary offline window/replay/smoke | T, baseline offline | U | U | DVUI/SDL3 window exists; baseline smoke renders three frames without HID. Native Windows/Linux smoke still needed. |
| Compact physical overlay, click-through, placement, opacity, focus behavior | D to 03/04 | D | D | Baseline display derives positions from side tags; no accepted overlay behavior worksheet. Wayland positioning has an upstream restriction. |
| Edit/save/reopen/export compiled profiles | N; D to 06/07 | N; D | N; D | A displayed keymap is not an editor. Architecture remains undecided. |
| Explicit board firmware build | T, ten-board baseline | U, native host | U, native host | [Board publisher](../../keyboards/build_api.zig) and immutable MicroZig pin exist. Compilation says nothing about installed firmware behavior. |
| Flasher build | T, baseline plus cross compilation | U, runtime | U, runtime | [Development](../development.md) records supported OS compile checks; root `flash` deliberately fails. |
| UF2 discovery/transfer/identity/rollback UI | N; D to 08 | N; D | N; D | No accepted manifest/discovery/transfer session. Manual BOOTSEL is a device operation, outside 09A. |

Baseline environment recorded in development: Zig 0.16.0 at
`/Users/clorz/.zvm/0.16.0/zig`, Xcode 27.0 / SDK 27.0. OS version, architecture,
installed input-source version/ID, device identity and native Windows/Linux
environments were not measured by this worker. The roadmap reports 282 passing
Zig tests, ten boards and LK7 root/standalone parity at its consolidated baseline;
09A did not rerun those checks or attribute them to current WIP.

## Platform requirements and sourced constraints

Primary sources consulted 2026-10-04 describe current upstream requirements;
repository pins remain authoritative for the actual build. Do not upgrade a pin
or replace a retained C bridge as part of this inventory.

- macOS: existing zkeymap links Carbon/libc and uses TIS Unicode layout data and
  UCKeyTranslate. Apple documents its dead-key state and currently discourages
  general event processing with this API; counterfactual key labels need their
  own justification and tests. SDL documents Xcode/SDK building and deployment
  requirements, which are upstream minima rather than a validated project minimum.
  [Apple UCKeyTranslate](https://developer.apple.com/documentation/coreservices/1390584-uckeytranslate),
  [SDL macOS build](https://wiki.libsdl.org/SDL3/README-macos).
- Windows: retained bridge uses GetKeyboardLayout/ToUnicodeEx and UTF-16 conversion.
  ToUnicodeEx requires User32 and can change dead-key buffer state. Native link,
  AltGr, foreground-versus-companion layout, Unicode and refresh tests are needed.
  HIDClass exposes separate top-level collections, so select vendor usage/path
  rather than opening the keyboard collection or replacing its driver.
  [ToUnicodeEx](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex),
  [HID collections](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/top-level-collections).
- Linux: native bridge needs xkbcommon development headers/library and layout data.
  SDL's dependencies vary with X11/Wayland and enabled backends. HIDAPI documents
  hidraw/libusb alternatives and unprivileged access rules; inspect the pinned SDL
  backend before writing a narrowly scoped udev rule. No root-only app workflow
  should be assumed. Compose takes a keysym and exposes feed result separately
  from composition status. Wayland does not permit ordinary toplevel windows to
  position themselves programmatically; overlay acceptance must name compositor
  and session type. [SDL Linux](https://wiki.libsdl.org/SDL3/README-linux),
  [HIDAPI upstream](https://github.com/libusb/hidapi),
  [xkbcommon compose](https://xkbcommon.org/doc/current/group__compose.html),
  [SDL Wayland](https://wiki.libsdl.org/SDL3/README-wayland).
- Window flags are requests with error returns, not guarantees on every desktop;
  SDL's always-on-top API runs on the main thread. Record actual focus, transparency,
  click-through and fullscreen behavior per target.
  [SDL always-on-top](https://wiki.libsdl.org/SDL3/SDL_SetWindowAlwaysOnTop).
- UF2 boot storage is documented by Raspberry Pi; it appears as RPI-RP2 on Pico
  and disappears after transfer/reboot. This is not a stable mount path or unique
  board identity. OS-specific enumeration and confirmation remain future work.
  [Pico documentation](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html).

macOS HID/privacy prompts, Windows access policy and Linux device permissions
must be observed on the chosen environment. No prompt was exercised, no driver
installed and no live HID call made in 09A.

## Ordered gaps and candidate environments

1. P1: accept 01-03 offline, then actual LK7/macOS 04; publish exact native version,
   input source, artifacts and recovery worksheet before any live support claim.
2. P2: finish reviewed profile identity/selection in 05 and decide 06 architecture;
   portable export/editor/build boundaries in 07/08 must stay OS-independent.
3. P3: a Linux source audit must resolve compose feed/status misuse, explicit locale
   handling, default-keymap versus active desktop layout and cross-host omitted C
   bridge in `zkeymap/build.zig`. These are inspection findings, not executed failures.
   New or expanded C implementation requires explicit user permission under AGENTS.
4. P4: a Windows audit must prove native User32 linkage and correct layout scope,
   AltGr/dead-key isolation, source changes and Unicode behavior. Cross-compilation
   alone cannot do this.
5. P5: choose Windows with a native desktop/device test environment, or Linux with
   named distribution/compositor/X11-or-Wayland, xkbcommon and permission setup.
   These are candidates, not ranked user priorities or selected work. Create one
   child plan only after the user's choice and available environment.
6. P6: complete native collection/reconnect/window tests, then explicit hardware
   and 08 transfer/rollback acceptance per selected platform.

Wireless, new MCU families, runtime remapping, browser flashing and C bridge
replacement remain deferred. See [setup/recovery](09-setup-and-recovery.md) and
[board inventory](09-board-capabilities.md).
