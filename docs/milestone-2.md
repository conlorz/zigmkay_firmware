# Milestone 2: Zig 0.16 root graph and offline companion

Completed locally on `local/phase-2`, based on `e754f5c` (`local/integration`);
phase 1's verified source baseline is `e76611c`. Implementation commits are local.
The other worktrees and their unfinished work are preserved. The two pre-existing
phase 2 ignore-file edits are preserved in their own local commit.

## Delivered behavior

One root graph publishes portable types, codec, reducer, original processor
corpus, keycode generator, catalog firmware, and the LK7 headless executable.
Root and standalone paths share exported publication APIs and package-owned
paths. Tests use one portable type identity; firmware creates processor modules
per MicroZig configuration. Host programs stay native under firmware target
options.

`test`, `check-generated`, `firmware`, `firmware-all`, `companion`, and
`list-keyboards` are concrete root commands. Default builds run host checks.
Selected firmware/companion commands require a board; selection errors are
attached only to those steps. `flash` has an explicit phase 2 failure.

The sorted catalog has ten targets: `clacky_chan`, `dasbob`, `encoder_demo`,
`lk1`, `lk2`, `lk6`, `lk7`, `molekula`, `tuckytwotimes`, and `yak`. Split boards
retain their runtime role choice. Every UF2 installs to a separate board folder.
The 0.16 port adds startup exports/embedded logging to every entry point and
adapts matrix capture, switch payload syntax, and the UART write return API.
GPIO mappings, scanners, USB processing, and keymap actions remain present.

The companion is `zig-out/bin/zigmkay-companion-headless-lk7`. It replays a file
through the actual decoder and reducer with LK7's actual dimensions. Final and
intermediate pressed/layer/modifier states, truncated/invalid reports, sequence
duplicates/gaps, empty input, and missing input are checked through process/file
I/O. The phase 1 literal trace is stored once in `tests/fixtures/lk7_trace.bin`
and used by both the processor golden test and executable checks.

Registry bootstrap is independent of the root graph. Cache-only stale checks
cover registry ordering, keycode bytes, export index, and missing/extra outputs.
Explicit converter regeneration aligned two existing files with the 0.16
formatting policy: one blank line and one trailing-space comment; keycode values
are unchanged. The stale failure before regeneration is preserved as evidence.

## Compiler, SDK, and dependencies

- Compiler: `/Users/clorz/.zvm/0.16.0/zig`, version `0.16.0`, pinned in `.zigversion`.
- Xcode: `27.0`, build `27A266a`; installed macOS SDK `27.0`.
- SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`.
- Python: `3.14.7` (tooling requires Python 3.9 or newer).
- MicroZig: `00fde43fa3756790037b099baeafacc3e6bf9499`.
- MicroZig package hash: `microzig-0.15.2-D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`.
- Root/standalone keyboard pins are identical; owned packages are repository-local.
- DVUI's later reference is `9b372ab0e3beca5060eb1f9ffe3e83ee61665e37`; it is not loaded by this graph.
- zig-flash and research sibling paths are absent from ordinary dependencies.

## Validation

The initial phase 1 reproduction passed **201 tests**, **94 host steps**, and
**20 LK7 steps** with its documented 0.15 SDK workaround. The initial 0.16 port
then passed all 201 preserved tests plus two new generator error-path tests.

The final full wrapper passed **203 Zig tests plus 31 Python boundary tests**
(234 cases total). These retain type identity, gaming-layer bounds, processing
retries, observer inputs, sink saturation, golden reports, and output equivalence.
Python checks cover registry (13), process adapters (10), root selection/build
boundaries (5), and compiler/source-inventory guards (3).

| Gate | Result |
|---|---|
| Root `test`, without selection | 99/99 build steps; 203/203 Zig tests; 31 Python cases |
| Root `check-generated`, without selection | 80/80 steps; sources untouched |
| Root selected LK7 firmware | 20/20 steps |
| Root `firmware-all`, without selection | 74/74 steps; ten distinct UF2 files |
| Root selected LK7 companion | 3/3 steps; real native executable |
| Default build, without selection | Same host suite passes |
| Standalone core | 165/165 tests; 62/62 steps |
| Standalone keycodes, firmware target option | 24/24 tests; 14/14 steps; generator/tests native |
| Standalone selected LK7 | 20/20 steps; UF2 bytes identical to root |
| Companion, firmware target option | 3/3 steps; installed binary replay passes |
| Independent bootstrap, missing registry | Missing check fails read-only; generation/check/compilation pass |
| Hardware-tool sentinel | No flasher or device tool executed |
| Source content and file inventory | Unchanged by full checks |

LK7 root/standalone SHA-256:
`4924493306b302a7c2019e948ce04c79225c7d08dba1711eafc3cccbc32380e8`.
All artifact sizes and hashes are recorded in
[evidence/phase-2/results.json](evidence/phase-2/results.json).
The actual commands and summaries are in
[evidence/phase-2/full-gate.log](evidence/phase-2/full-gate.log).
Independent bootstrap and a fresh detached checkout are additionally recorded
in the evidence directory. The fresh checkout uses the immutable dependencies
without the SDK shim, sibling research clones, or package-cache edits.

The completion commands were run with the explicit 0.16 compiler and no legacy
SDK overrides:

```sh
/Users/clorz/.zvm/0.16.0/zig build test -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build check-generated -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build firmware -Dkeyboard=lk7 -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build firmware-all -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build companion -Dkeyboard=lk7 -j4 --summary all
ZIG_BIN=/Users/clorz/.zvm/0.16.0/zig ./tools/check-local --full
```

## Handoff

[Development commands](development.md) describe standalone builds, compiler
selection, catalog bootstrap, explicit regeneration, and check modes.
Compile success is not hardware acceptance. No device was accessed or flashed.
The offline reducer intentionally refuses discontinuous sequences; it does not
implement production resynchronization. The legacy GUI, native HID collection
selection, transport scheduling, bounded telemetry recovery, Hello/Snapshot,
zkeymap migration, and flasher migration remain phase 3/4 work.
