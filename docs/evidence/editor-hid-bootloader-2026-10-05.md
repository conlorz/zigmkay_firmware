# Optional HID bootloader entry from editor Flash

User request: complete bootloader entry through the HID channel and attempt it
on Flash, with an optional path for keyboards without supporting firmware.
Hardware acceptance was explicitly deferred; this work is offline.
Implementation commit: `300b52a`.

## Implemented behavior

The toolbar has an enabled-by-default **Enter bootloader via HID** checkbox.
A successful explicit Flash click first verifies the immutable artifact and
launches the existing flasher's recovery-volume wait. With the checkbox enabled,
the editor also starts a dedicated 2.5-second HID attempt. With it disabled, no
bootloader connection/request starts and the manual BOOTSEL instructions appear.
No request is queued after missing/stale artifact or transfer-launch failure.

Both standalone and companion-hosted editor paths use the same attempt. It
refuses ambiguous vendor collections, correlates the session/identity transaction,
checks board identity and physical key count, then binds the actual running
profile and validates its coherent snapshot. Capability advertisement is required
before sending `enter_bootloader`. The unflashed draft may have a different
profile or layer count. This discovery policy is limited to the dedicated
bootloader session; ordinary overlay sessions retain exact identity matching.
The regular live driver is disconnected/paused to avoid competing HID sessions.

The command is sent at most once per attempt. Accepted acknowledgment closes the
HID handle and leaves recovery-volume discovery to the flasher. No device, old
firmware, wrong board, failed transport, rejected command or timeout ends the HID
attempt with manual-recovery guidance, without cancelling the volume wait.
A later Flash click creates a fresh attempt and clears the previous status.

The existing firmware implementation remains unchanged: messages 18–21 provide
capabilities and bootloader control; USB callbacks only enqueue, and the main
loop calls `rp2xxx.rom.reset_to_usb_boot()` after acknowledged bounded drain.
Existing firmware tests cover malformed/stale/duplicate requests and failed
acknowledgment delivery. No protocol version or report layout changed.

## Verification

- Zig 0.16.0 companion package suite: 65/65 tests passed (62 companion and three
  executable Zig lessons). New fake-transport tests cover a differing running
  profile/layer count, exact overlay mismatch rejection, supported entry,
  absent/ambiguous devices, wrong board, zero/missing capabilities, stale
  acknowledgments, rejection, timeout and no retransmission.
- Companion-model package tests passed.
- `zig build check-full -j4` passed: package tests, generated/source inventory
  checks, all ten boards and LK7 mise/standalone UF2 parity. No hardware tool ran.
- Final `zig build editor-check -j4` passed: 142 captures, dark/light themes,
  1×/2× readback, panel geometry, 1152×768 and 900×600 windows and semantic
  interactions. The real checkbox is toggled off and back on; fixtures remain
  inert with no pending bootloader request or native HID attempt.
- `zig build check -j4` at implementation `300b52a` passed with unchanged source
  inventory and no hardware tool execution.

Local final logs: `.zig-cache/hid-bootloader-companion-tests-final.log`,
`.zig-cache/hid-bootloader-check-full-final.log`, and
`.zig-cache/hid-bootloader-editor-check-final.log`. The initial editor check
captured all 140 states but exposed a semantic test clicking before initial
resize settled or immediately after a modal closed. The scenario now toggles
after layout settles and before opening the modal; focused standard/resized
interaction runs pass. Earlier logs remain available for diagnosis.
The final source check log is `.zig-cache/hid-bootloader-check-300b52a.log`.
Screenshots remain in
`.zig-cache/editor-acceptance/`; committed goldens were not regenerated.

No HID device was opened and no BOOTSEL request, firmware transfer or actual
keyboard restart was performed in these tests. Physical acceptance remains
pending for both checkbox modes and the actual supported-firmware transition.
