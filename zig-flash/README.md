# zig-flash

Zig 0.16.0 UF2 volume-copy tooling. `zig build` compiles the native binary;
`zig build test` tests mount-path handling without hardware. `zig build ci`
compiles for macOS, Linux, and Windows. Root `zig build flash-tool` compiles only.

Manual usage: `zig_flash <firmware.uf2> [absolute mount path or volume label]`.
The firmware input is required. The default label is `RPI-RP2`. The tool waits
for the volume, then copies the input to `firmware.uf2` on that volume.
macOS uses `/Volumes/<label>`; Linux uses `/run/media/$USER/<label>`;
Windows queries volume labels through native Win32 APIs. No PowerShell is used.
Device operations require an explicit hardware task from the user.
