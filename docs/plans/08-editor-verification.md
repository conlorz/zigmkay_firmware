# Plan 08 editor build and recovery verification

The editor's Build action captures the current validated draft and callback
source inventory, exports into the build cache, and starts the pinned Zig
compiler through a literal argument vector. It does not access hardware.
Compiler diagnostics retain source paths and line numbers. Cancel ends the
bounded build job; a failed or cancelled build does not restore an older
artifact as current. Editing the draft or compiler inputs invalidates its build.

Open the editor from the repository root:

```sh
mise //zigmkay-companion:editor
```

Build a representative profile and inspect the resulting artifact identity,
size and SHA-256. Preserve the original accepted Danish firmware as a rollback
before starting a separately authorized hardware session. Build status,
completed file transfer, matching running identity and user-verified typing are
separate observations.

For manual recovery, hold the physical LK7 boot combo (positions 0 and 4),
connect the keyboard, and identify its RP2040 BOOTSEL volume. The volume's
`INFO_UF2.TXT` proves an RP2 bootloader, not a unique LK7 serial number. With
multiple candidates, select the intended mounted volume explicitly; disconnect
unrelated RP2040 devices if its physical identity is uncertain.

The existing terminal fallback remains available:

```sh
mise //:flash-file /absolute/path/to/zigmkay.uf2 --mount /Volumes/RPI-RP2
```

Check `mise //:flash-file --help` for the installed task's argument syntax.
Transfer completion means the write and synchronization completed. It does not
prove binary readback or typing correctness. If a filesystem call stalls,
stop the writer once and reconnect in physical BOOTSEL; ensure the old writer
has exited before starting another.

The toolbar checkbox **Enter bootloader via HID** is enabled by default and can
be disabled before clicking **Flash**. After verifying the current built artifact,
Flash starts recovery-volume discovery and, when enabled, one bounded HID attempt.
This also works in the standalone editor: it opens a unique matching vendor HID
collection, verifies the LK7 board/key count, binds the running profile, obtains a
coherent snapshot and checks the advertised capability. The running profile can
differ from the unflashed draft; normal overlay identity checks remain exact.
An existing live session is paused while the bootloader session owns the device.

Missing/ambiguous devices, unsupported firmware, rejection and timeout display
a manual BOOTSEL fallback without cancelling the transfer's volume wait. Disable
the checkbox to use manual recovery directly, including an unprogrammed keyboard.
The HID attempt is bounded to 2.5 seconds and sends the bootloader command at most
once per Flash click. No timeout/reconnect automatically retries the command.
HID removal is expected after acceptance; recovery-volume validation remains
required. Startup, monitoring, saving, exporting and building never request
BOOTSEL. The existing flasher still verifies the artifact hash and RP2040 volume.

## Pending hardware worksheet

A separate user-requested hardware session must record:

- The reviewed small LK7 change, immutable build manifest and UF2 SHA-256.
- Selected device and explicit bootloader action; acknowledgment and validated
  recovery volume (or physical fallback).
- Explicit transfer action, completion/error, and preserved rollback artifact.
- Reconnected board/profile/layout identity and coherent telemetry snapshot.
- User typing, modifier/release and overlay checks.

These rows remain pending until observed; offline tests do not accept G08.
