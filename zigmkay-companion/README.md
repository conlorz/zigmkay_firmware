# zigmkay-companion

Desktop overlay for the Leonardo Keycaprio v0.7 (`lk7`), showing its active
layer and physical key presses over the firmware's RawHID interface.
The companion and firmware use the same local 34-key keymap and firmware core.

## Build and run

Use Zig 0.15.2 (`zvm install 0.15.2`). The `tools/zig` wrapper selects this
version and handles the macOS SDK compatibility issue without modifying Apple
SDKs. From this repository:

```sh
cd keyboards
../tools/zig build -Dkeyboard=lk7
../tools/zig build flash -Dkeyboard=lk7
```

For flashing, the RP2040 must be in BOOTSEL mode, mounted as `RPI-RP2`.
The existing keymap includes bootloader combos at key indices 0+4, 5+9,
and 24+25 on the base layer.

Build and launch the companion separately:

```sh
cd zigmkay-companion
../tools/zig build
../tools/zig build run
```

The overlay starts visible. ESC closes the application. The lk7 keymap does
not currently assign an overlay toggle key; the firmware supports the reserved
`core.CUSTOM_ID_COMPANION_TOGGLE` custom action for a future assignment.

## Validation

```sh
cd zigmkay
../tools/zig build test
cd ../zigmkay-companion
../tools/zig build test
```

The desktop UI uses DVUI's SDL3 backend and displays the shared keymap through
zkeymap. Dependencies are pinned in `build.zig.zon`.
