# zigmkay_firmware

A local Zig 0.16.0 monorepo for keyboard firmware and its companion tools.
Use the compiler version pinned in `.zigversion`. Builds fetch third-party
packages through immutable URLs and hashes in `build.zig.zon`; sibling clones
are unnecessary. On macOS, use the installed Xcode SDK.

Start planning/execution from the [central tracker](docs/plans/TRACKING.md) and
[subagent workflow](docs/plans/SUBAGENT-WORKFLOW.md). The
[roadmap](docs/plans/README.md) covers LK7 live monitoring, the QWERTY/EurKEY Next
Mac profile, editor research, and later build/flash integration. The next
implementation milestone is [protocol and recovery](docs/plans/01-protocol-and-recovery.md).

```sh
zig build                    # host tests, including GUI components
zig build check              # tests, generated checks, source inventory guard
zig build check-full         # all boards, standalone packages, artifact parity
zig build list-keyboards
zig build firmware -Dkeyboard=lk7
zig build firmware-all
zig build companion -Dkeyboard=lk7
zig build companion-headless -Dkeyboard=lk7
zig build flash-tool          # compile only
```

Firmware outputs are `zig-out/firmware/<id>/zigmkay.uf2`. Firmware defaults to
ReleaseSafe. Selected firmware and companion builds require `-Dkeyboard`.
The desktop and replay companions currently support LK7. Host tools remain
native even when `-Dtarget=thumb-freestanding-eabi` is passed.

```sh
zig-out/bin/zigmkay-companion-headless-lk7 tests/fixtures/lk7_trace.bin
zig-out/bin/zigmkay_companion --replay tests/fixtures/lk7_trace.bin
zig-out/bin/zigmkay_companion --smoke
```

The GUI starts offline. `--live` explicitly enables the vendor telemetry HID
interface; live device operation has not been validated. Tests and check steps
never enumerate devices or flash firmware. Root `flash` remains disabled.
The separately built `zig_flash` requires an explicit firmware input and is
invoked manually when hardware work is authorized.

| Package | Purpose |
| --- | --- |
| `zigmkay` | Keyboard processor and firmware behavior |
| `keyboards` | Ten boards, catalog, shared LK7 keymap |
| `layout-model` | Portable key definitions and physical layout types |
| `device-protocol` | Versioned 32-byte telemetry codec |
| `companion-model` | Portable companion state reducer |
| `zkeycodes` | Keycode definitions, HJSON converter, generated layouts |
| `zkeymap` | Native keyboard layout translation; existing C bridges |
| `zigmkay-companion` | DVUI/SDL3 desktop companion |
| `zig-flash` | Explicit UF2 volume-copy tool |
| `apps/headless` | Offline replay executable |
| `tools`, `tests` | Zig validation tooling and integration fixtures |

Owned packages are normal source directories, with local path dependencies.
They are not separate Git repositories or Git submodules. Commit all changes
locally in this repository; never push this fork.

The board catalog is `keyboards/boards.zon`. Regenerate its registry explicitly:

```sh
zig run tools/registry/main.zig -- keyboards/boards.zon keyboards keyboards/generated/keyboard_registry.zig
```

That command also works if the committed registry is missing. Append `--check`
to compare without writing. To regenerate keycodes, run `zig build convert-all`
in `zkeycodes`. Ordinary builds and checks never regenerate committed sources.
See [development](docs/development.md) and [the protocol](docs/device-protocol.md).
