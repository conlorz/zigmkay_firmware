# Desktop companion

The Zig 0.16.0 DVUI/SDL3 companion uses the shared LK7 keymap, telemetry codec,
and state reducer. DVUI and icons are pinned dependencies; zkeymap is local.

From the monorepo root, `zig build companion -Dkeyboard=lk7` builds the GUI.
Run `zig-out/bin/zigmkay_companion` for offline mode, add `--replay <file>` to
replay consecutive 32-byte reports, or `--smoke` to render three frames and exit.
Only `--live` enumerates the keyboard's vendor telemetry HID interface.
All event reduction and UI changes occur on the UI thread.

This package also supports standalone `zig build`, `zig build test`, and
`zig build run -- --smoke`. Live hardware operation has not been validated.
