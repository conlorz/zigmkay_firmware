# zigmkay_firmware

A local Zig 0.16.0 keyboard firmware monorepo. **Mise is the terminal entry
point**: it pins Zig, discovers package tasks, completes arguments and schedules
repository-wide work. Packages own their Zig builds; root Zig owns integration
tests and the offline guard. No sibling clones or package directory changes are
needed.

**Current task:** [07B native editor](docs/plans/07-compiled-keymap-editor.md), in progress; G07-export is frozen at `016cf7d`.
Read the [architecture research](docs/plans/06-architecture-research.md)
and the [tracker](docs/plans/TRACKING.md). USB/HID recovery and manual LK7
acceptance are complete for the agreed macOS baseline. The remaining order is
06 → 07 → 08 → 05 → 09; the personal EurKEY profile will be created through
the finished editor. Other platforms and boards retain separate acceptance gates.

## Setup and discovery

Use mise 2026.9.14 or newer. From this directory:

```sh
mise trust
mise install
mise tasks --all                    # descriptions for root and package tasks
mise tasks deps //:test              # inspect the aggregate test graph
mise //:firmware --help              # board and optimization choices
mise //:companion-run --help         # GUI options
mise //:ls                          # ten-board catalog
```

This is real mise monorepo mode: `//:task` selects a root task and
`//package:task` selects a package task, from anywhere inside the repo.
Use those names for reliable argument completion on the validated mise version.
For example, `mise //:firmware <TAB>` lists board IDs and
`mise //:companion-run --<TAB>` lists GUI options. Short commands such as
`mise run test` also execute, but unqualified argument completion is limited in
mise 2026.9.14.

Install completion once for your shell:

```sh
mise completion fish --install
# or:
mise completion zsh --install
```

Fish loads the installed completion automatically. Zsh prints its required
`fpath`/`compinit` setup; follow that output in your own shell configuration.
Task execution does not require shell activation. The root `mise.toml` pins
Zig to 0.16.0, matching `.zigversion`; it applies to package tasks too.

## Everyday tasks

```sh
mise //:test                         # each package test plus integration
mise //zigmkay:test                  # only processor tests
mise //zigmkay-companion:test        # only companion tests; no HID
mise //:check                        # tests/generated checks plus offline guard
mise //:check-full                   # full build matrix, replay and parity
mise //:firmware lk7                 # build only, no device access
mise //:firmware lk7 --optimize Debug
mise //:firmware-all
mise //:companion
mise //:companion-run --smoke
mise //:companion-run --replay tests/fixtures/lk7_trace.bin
mise //:companion-headless
mise //:replay tests/fixtures/lk7_trace.bin
mise //:flash-tool                   # build only
```

Artifacts stay in root `zig-out`: firmware in
`zig-out/firmware/<board>/zigmkay.uf2`, GUI at
`zig-out/bin/zigmkay_companion`, replay at
`zig-out/bin/zigmkay-companion-headless-lk7`, flasher at
`zig-out/bin/zig_flash`. Firmware defaults to ReleaseSafe; host tools remain
native. GUI/replay currently use the fixed LK7 Danish profile. GUI replay/capture
paths are relative to the monorepo root. Root `zig build` now runs integration
checks only; use `mise //:test` for the entire repository.

## Explicit hardware tasks

Only use these during an authorized device session:

```sh
mise //:flash lk7                    # selected firmware build, then zig_flash
mise //:flash lk7 --mount /Volumes/RPI-RP2
mise //:flash-file .zig-cache/manual-session/rollback-ab66f12/zigmkay-rp2040.uf2
mise //:companion-run --live
mise //:companion-run --live --capture /tmp/lk7.capture --capture-ms 30000
mise //:companion-run --session-replay /tmp/lk7.capture   # offline
```

Flash requires an explicit board or UF2, waits for BOOTSEL, and uses the Zig
utility. Write/sync success does not independently verify installed identity or
automatic restart; that device issue remains under investigation in
[04](docs/plans/handovers/04-hardware.md). Live HID, flashing and generated source
updates are excluded from aggregate tests/checks. No default task accesses hardware.

## Packages

| Task namespace | Ownership |
| --- | --- |
| `//zigmkay` | Processor and firmware behavior |
| `//keyboards` | Board catalog and firmware builds |
| `//layout-model` | Portable key and physical types |
| `//device-protocol` | Telemetry codec |
| `//companion-model` | Portable session/state model |
| `//keymap-project` | Versioned project, source snapshots, validation and Zig generation (07A accepted) |
| `//zkeycodes` | Keycodes, HJSON conversion and generated checks |
| `//zkeymap` | Native keyboard translation; existing C bridges |
| `//zigmkay-companion` | DVUI/SDL3 GUI and component tests |
| `//zig-flash` | Zig UF2 utility and offline platform checks |
| `//apps/headless` | Offline trace replay |
| `//tools/registry` | Registry validation/check/regeneration |
| `//:integration-test` | Cross-package identity/session/trace checks |

Codec/session behavioral fixtures remain cross-package integration tests;
their package test steps also compile their own portable module roots.
First-party implementation, generators and validation remain Zig. External
dependencies use immutable revisions and hashes in package `build.zig.zon`
files. All changes stay local: never push branches or create pull requests.

Regeneration is explicit:

```sh
mise //:check-generated              # compare only
mise //:registry-regenerate          # update committed registry
mise //:convert-all                  # update committed keycodes
mise //:convert input.hjson output.zig
```

See [development](docs/development.md), [mise migration](docs/plans/10-mise-monorepo.md),
[protocol](docs/device-protocol.md), [firmware telemetry](docs/firmware-telemetry.md),
and [overlay guide](docs/live-overlay.md).
