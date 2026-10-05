# Editor toolbar firmware verification

The Build and Flash toolbar buttons execute their actions directly. The firmware
popup, path field and readiness checkbox are removed. Progress appears beneath
the buttons; failures appear inline. Flash uses the existing flasher's automatic
RPI-RP2 discovery and exact artifact hash verification. Standalone editor mode
checks the transferred profile's identity and coherent snapshot on reconnect.

## Verified offline

- `zig build check-full -j4`: package tests, generated checks, all ten boards,
  standalone/root LK7 artifact parity passed.
- Native semantic interactions and toolbar capture passed.
- A regression test checks that the resolved cached flasher executable is an
  absolute path and exists, independent of the process working directory.

## Live reproduction

The user explicitly authorized end-to-end flashing. The dedicated command
`zig build run -j4 -- --editor --flash-ui-check` in `zigmkay-companion` clicks the
real Build and Flash toolbar buttons through DVUI input. It builds the existing
Danish profile, transfers through the editor controller, then verifies the exact
expected identity and coherent snapshot over vendor HID. This command is never
part of default builds or automated tests.

The first run reproduced `FileNotFound` after a successful UI build. The generated
flasher executable path was relative to the package build directory, while the
job's working directory was the monorepo root. Commit `7ce6a74` resolves it against
the build root before spawning; the offline regression passes in both build modes.

The next run launched the correct absolute executable and reached device writing.
Artifact SHA-256: `fc1c3ad3890c084b940e3c155a2ff61014d08307d90b76ccad68bf18963e68f9`.
The flasher blocked in macOS `pwritev`, confirmed by a process sample saved in
`.zig-cache/ui-flash-blocked.sample.txt`. A recovery-volume directory listing also
blocked. One SIGINT was sent. No second writer was started while it remained alive.

Physical unplug/reconnect in BOOTSEL was requested from the user. Successful
transfer, automatic restart and running identity verification remain pending that
reconnect and a fresh explicit acceptance run. No typing acceptance is claimed.
