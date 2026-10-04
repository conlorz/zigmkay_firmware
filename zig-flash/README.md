# zig-flash

Zig 0.16.0 UF2 volume-copy tooling. `zig build` compiles the native binary;
`zig build test` tests mount-path handling without hardware. `zig build ci`
compiles for macOS, Linux, and Windows. Root `zig build flash-tool` compiles only.

Manual usage: `zig_flash <firmware.uf2> [absolute mount path or volume label]`.
The firmware input is required. The default label is `RPI-RP2`. The tool waits
for the volume, then writes the input directly to `firmware.uf2` and synchronizes
the destination. It avoids atomic temporary-file renaming on the UF2 device.
Successful write/sync does not independently verify reboot or running identity.
Inputs are validated as complete RP2040 flash UF2 transfers before opening a
device file: magic, family flag/ID, payload, flash addresses and unique block
coverage. Unsupported/invalid UF2s fail before waiting for BOOTSEL. The exact
validated bytes are retained while waiting. Progress distinguishes volume
detection, opening, writing and synchronization; a stall at opening is a
filesystem operation rather than device discovery.
macOS uses `/Volumes/<label>`; Linux uses `/run/media/$USER/<label>`;
Windows queries volume labels through native Win32 APIs. No PowerShell is used.
Device operations require an explicit hardware task from the user.
