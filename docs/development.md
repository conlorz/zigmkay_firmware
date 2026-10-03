# Local development

Phase 2 is implemented on `local/phase-2` in `firmware-phase-2`, based on the
completed `local/integration` worktree. Commits stay local. The integration,
compiler probe, research, and unfinished companion worktrees remain intact.
See [milestone 2](milestone-2.md) for validation and [the implementation plan](phase-2-plan.md)
for scope. The phase 1 comparison is documented in [milestone 1](milestone-1.md).

## Requirements and dependency ownership

Use **Zig 0.16.0**, pinned in `.zigversion`. The verified local compiler is
`/Users/clorz/.zvm/0.16.0/zig`. `tools/check-local` rejects another compiler before
building. Python 3.9 or newer is required for registry and boundary tooling
(verified with Python 3.14.7). Git and network access are needed for a first
immutable dependency fetch; subsequent builds can use the ordinary Zig cache.

The verified macOS environment is Xcode 27.0 (`27A266a`), macOS SDK 27.0 at
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`.
Standard commands use the installed SDK. No SDK shim or `/tmp` prerequisite is
needed. The old 0.15.2 SDK view is only a historical phase 1 workaround.

Root and standalone keyboard manifests pin MicroZig to
`00fde43fa3756790037b099baeafacc3e6bf9499`, with package hash
`microzig-0.15.2-D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`.
The package name still contains its upstream `0.15.2` version; this revision is
the verified 0.16-compatible dependency. Its transitive dependencies retain
upstream immutable hashes. Owned dependencies use paths inside this repository;
there are no required sibling research clones or manual package-cache edits.
Existing package fingerprints are preserved.

DVUI `9b372ab0e3beca5060eb1f9ffe3e83ee61665e37` remains a later GUI reference.
DVUI, zig-flash, native HID, and zkeymap are outside the phase 2 dependency graph.

## Root commands

From `firmware-phase-2`, with Zig 0.16.0 selected:

```sh
zig build test -j4
zig build check-generated -j4
zig build list-keyboards
zig build firmware -Dkeyboard=lk7 -j4
zig build firmware-all -j4
zig build companion -Dkeyboard=lk7 -j4
zig-out/bin/zigmkay-companion-headless-lk7 tests/fixtures/lk7_trace.bin
ZIG_BIN=/Users/clorz/.zvm/0.16.0/zig ./tools/check-local
ZIG_BIN=/Users/clorz/.zvm/0.16.0/zig ./tools/check-local --full
```

Default builds run the host suite. `test` and `check-generated` need no board
selection. Firmware and companion require `-Dkeyboard`; their errors list
available IDs. The companion supports LK7 offline replay initially. Other boards
have firmware support and produce an explicit unsupported-companion diagnostic.
`flash` fails with `flash is not implemented in phase 2`.

Firmware installs to `zig-out/firmware/<id>/zigmkay.uf2`. `firmware` builds exactly
one selected entry; `firmware-all` builds ten entries to distinct paths.
`-Doptimize=ReleaseSafe` is the firmware default; another explicit optimization
applies to both root and standalone firmware. Board hardware fixes retain GPIO
mappings and keymap actions. Generator, registry tooling, tests, and companion
always execute on the host, even with `-Dtarget=thumb-freestanding-eabi`.

The headless executable reads consecutive 32-byte v1 reports from one file and
prints deterministic final state. It accepts the first sequence as a session
start and rejects gaps, duplicates, invalid reports, and incomplete boundaries.
Files are bounded to 64 MiB. An empty file prints initial state. It uses the real
LK7 dimensions and the shared protocol decoder/reducer; no HID/USB thread or GUI
starts. See [the protocol contract](device-protocol.md).

## Standalone packages and publication APIs

```sh
(cd zigmkay && /Users/clorz/.zvm/0.16.0/zig build test -j4)
(cd zkeycodes && /Users/clorz/.zvm/0.16.0/zig build test -j4)
(cd keyboards && /Users/clorz/.zvm/0.16.0/zig build firmware -Dkeyboard=lk7 -j4)
```

The root calls exported `publish` functions from dependency build modules and
passes package-owned `LazyPath` roots. Standalone wrappers call the same APIs.
Portable modules have no forced native target and retain one type identity
inside each graph. Each MicroZig firmware configuration gets a separate
hardware-bound processor module. `keyboards/build_api.zig` returns both the
emitted UF2 `LazyPath` and installation step, leaving a future explicit transport
integration point. The root never accesses private step tables by string.

## Catalog, bootstrap, and generated sources

`keyboards/boards.json` is the committed explicit catalog, including runtime split
role and encoder metadata. `keyboards/generated/keyboard_registry.zig` is its
sorted derivative. After a catalog change, regenerate explicitly:

```sh
python3 -B tools/registry/registry.py \
  keyboards/boards.json keyboards keyboards/generated/keyboard_registry.zig
python3 -B tools/registry/registry.py \
  keyboards/boards.json keyboards keyboards/generated/keyboard_registry.zig --check
zig build convert-all -j4
zig build check-generated -j4
```

The Python command is an independent bootstrap: it works when the registry is
missing and does not import the root Zig graph. Arguments can be absolute paths
from any working directory. Validation rejects duplicate/invalid names, missing
sources, absolute/traversing paths, and symlinks escaping the keyboard package.
Replacement uses a complete temporary file and atomic rename. A failed
replacement preserves the previous output.

`check-generated` renders registry/keycodes into the build cache and compares
bytes with committed outputs, including `keycodes/all.zig` and missing/extra
keycode files. It never writes sources. The converter uses Zig 0.16 AST rendering
as its formatting policy for every explicit and cache generation. Registry
formatting is the deterministic renderer's fixed output. The three generation
fixtures compile their outputs and test modifier/dead-key/label semantics.

## Check modes and evidence

The normal wrapper runs the short host suite. `--firmware` adds root LK7
compilation. `--full` also runs generated checks, selected/all firmware,
companion, default build, standalone core/keycodes/LK7, and host companion builds
under a firmware target option. It compares actual root/standalone UF2 bytes and
replays the installed executable. A temporary executable sentinel intercepts
known flash/device-tool commands throughout the checks.

Source snapshots include tracked, untracked, and ignored files, so additions,
deletions, and content changes are detected. Explicit exclusions are `.git`,
`.zig-cache`, `zig-out`, `zig-pkg`, `__pycache__`, `docs/evidence`, and the existing
`.slim/deepwork` task-note output. No test regenerates sources in place. Temporary
projects and sentinel scripts are created and removed by the checks themselves.

The wrapper reports the compiler and selected SDK. `ZIG_SYSROOT` and
`ZIG_XCRUN_DIR` remain explicit overrides for diagnosing historical environments;
leave them unset for standard 0.16 commands.
Evidence is preserved under `docs/evidence/phase-2`; earlier evidence is intact.
Build success does not establish board hardware correctness. Production
transport, queue recovery, Hello/Snapshot, GUI, and flashing remain later work.
