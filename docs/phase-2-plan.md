# Phase 2 handoff: Zig 0.16 root build and board registry

Status: ready for implementation; no phase 2 code has been applied. This plan is based on the local sources inspected on 2026-10-03. It is intended to let a new agent start without the earlier conversation.

## Objective and scope

Deliver one Zig 0.16.0 build graph for the completed phase 1 model, codec, processor, tests, generated keycodes, board firmware, and a usable headless companion executable. Expose `test`, `firmware`, `firmware-all`, `companion`, and `check-generated` from the repository root. Root and standalone package builds must use the same publication API, module instances, board definitions, and dependency pins.

The first compiler gate is the **full 201-test integration suite**, not the probe's 167-test subset. The second gate is all ten current board entry points. Preserve phase 1 behavior, including exact LK7 telemetry bytes and keyboard output equivalence.

Scope clarification: phase 1 delivered `companion-model`, not a native GUI application. In this phase, `companion` builds an explicitly named **headless offline executable**, linked to the real LK7 keymap/model/codec and able to replay reports from a file. An empty successful step or a generic DVUI example is not a companion deliverable. Porting the legacy GUI, native zkeymap, HID enumeration, and production device telemetry remains phase 3/4 work. This bounded choice makes the root command concrete without silently absorbing the GUI migration.

Production Hello/Snapshot/recovery, RawHID queues, editor UI, browser bridges, live configuration, and hardware flashing remain later work. Phase 2 does not require a working flash command or a zig-flash port. It must remove the old flasher from ordinary build dependencies and leave an extension point for a future explicit flash step receiving the selected UF2 `LazyPath`.

## Working agreement

Read `AGENTS.md` before editing. Implementation, comments, diagnostics, test names, documentation, and commit messages use English. Conversation may remain German. Work in a local branch and create local commits only. Do not push, create PRs, or modify remotes. Preserve existing uncommitted work and reference checkouts. No phase 2 check accesses devices, requests BOOTSEL, or writes firmware to a drive.

The upstream README's keymap-only contribution guidance does not restrict this authorized local fork. Do not restart from upstream main: the completed integration work is the base.

## Exact starting state

Workspace: `/Users/clorz/Documents/zigmkay`. That directory is **not** a Git repository; its child worktrees are.

| Worktree / ref | Starting revision | Use |
|---|---|---|
| `firmware-integration`, `local/integration` | `e76611c5114aa286669c7d8ee35bba9c3c0fb98a` before this handoff documentation commit | Complete phase 1: 201 tests, LK7 build, model/codec/reducer/observer |
| `firmware-integration-016`, `local/probe-016` | `73e3f6cf855b56a770535739737f9a70f11097d5` | Successful bounded 0.16 probe; selected changes only |
| Probe branch base | `94c203e` | Earlier model extraction, before final layout/codec/trace work |
| `firmware-keyboard-build-system` | `6969aee68c965b8a7e660440921a0fc7a675d71e` | Historical KeyboardBuilder/registry reference |
| Firmware ref `origin/build-on-root` | Resolve locally with `git rev-parse` | Historical publication API reference; not a merge base |
| `zigmkay_firmware`, `add-companion` | `12413b3d172d5710f4c1819ae6c9ad8918780b06` plus unfinished changes | Preserve; not the implementation base |

`local/integration` will also contain the documentation commit adding this plan. Start from its current HEAD so the plan is included; `e76611c` identifies the verified source baseline. The historical keyboard-build-system branch already contains the original companion commit. Do not copy it twice or merge historical branches wholesale.

Read first:

- `docs/milestone-1.md`, `docs/development.md`, and `docs/device-protocol.md` in the integration worktree.
- `docs/probe-016.md`, `docs/evidence/probe-016/results.json`, and `git show 73e3f6c` in the probe worktree.
- `../docs/02-branches-und-integration.md` and `../docs/05-teststrategie.md` in the workspace's research directory.
- Historical `keyboards/build_api.zig`, `keyboards/build.zig`, and `keyboards/tools/generate_registry.zig` in `firmware-keyboard-build-system`.
- `git show origin/build-on-root:build.zig` and relevant package publication functions from that ref.

## Start here

From the workspace directory, inspect state and create a dedicated phase 2 worktree:

```sh
cd /Users/clorz/Documents/zigmkay
git -C firmware-integration status --short --branch
git -C firmware-integration-016 status --short --branch
git -C firmware-integration worktree list
git -C firmware-integration worktree add \
  -b local/phase-2 ../firmware-phase-2 local/integration
cd firmware-phase-2
```

Check that branch and destination do not already exist. If work has already started there, inspect and continue it instead of resetting or overwriting it. Keep the original integration and probe worktrees as comparison references.

Reproduce phase 1 once before porting:

```sh
ZIG_BIN=/Users/clorz/.zvm/0.15.2/zig \
ZIG_SYSROOT=/tmp/zigmkay-macos-sdk \
ZIG_XCRUN_DIR=/tmp/zigmkay-sdk-tools \
./tools/check-local --firmware
```

Expected: 201 tests, 94 host build steps, 20 LK7 build steps. The temporary SDK view/shim is a documented 0.15 workaround. If unavailable, use the preserved evidence and diagnose the environment without changing system SDKs. Do not overwrite existing evidence logs during reproduction.

Phase 2 target compiler: `/Users/clorz/.zvm/0.16.0/zig`. The successful 0.16 probe uses the installed Xcode SDK without the old shim. Inspect the current SDK with `xcrun --show-sdk-path`; keep old SDK/shim overrides out of the standard 0.16 commands.

## A. Port the full integration suite to 0.16

Apply the probe's changes to the **current phase 1 sources**, preserving later changes. Use `git show 73e3f6c -- <path>` as the reference; a blind cherry-pick would also remove old flash integration and introduce temporary sibling path dependencies without establishing the final graph.

Known successful changes:

1. `zigmkay/build_utils.zig`: pass `b.graph.io` to directory open, close, and walker iteration.
2. `zkeycodes/build.zig`: pass the build I/O context to directory enumeration. This fixes only build-time I/O, not the generator executable.
3. `zigmkay/src/usb_command_executor.zig` and keymaps: remove discarded switch payload captures such as `=> |_| {}` where required by 0.16.
4. `zigmkay/src/matrix_scanning.zig`: copy the constructed comptime mapping into an immutable value before the returned scanner type captures it.
5. LK7 and subsequently every firmware entry point: call `microzig.export_startup()` at comptime and provide embedded `microzig.std_options(.{})` or an appropriate embedded logger. Default host logging pulled `std.Io.Threaded` into the RP2040 USB path during the probe.
6. Set all owned package manifests' minimum Zig version to 0.16.0 and record the exact project compiler in one version file. Update the local check wrapper to validate this version and report the selected SDK/compiler.

Port `zkeycodes/src/main.zig` to the 0.16 program/I/O boundary. It currently uses `GeneralPurposeAllocator`, `std.process.argsWithAllocator`, `std.fs.cwd`, `readToEndAlloc`, and old file writer APIs. Keep parsing/generation logic pure where possible; pass the runtime I/O/allocator from the entry point rather than introducing globals. Inspect the installed 0.16 standard library for the actual APIs.

Preserve the existing three generation fixtures (basic, US international, German Mac ISO), modifier/dead-key/label semantics, named helper imports, and cache-only test outputs. Add focused error-path checks for bad input and generator failure. Generated files must compile, not merely match text. Complete the current 201-test suite on 0.16 before expanding the build graph; new tests increase the count and must not replace existing cases.

**Acceptance A:** all phase 1 tests and native/Wasm portability checks pass on 0.16; LK7 compiles on the new MicroZig pin; no generated source files change during tests. The 167-test probe result alone is insufficient.

## B. Establish reproducible dependency ownership

MicroZig target revision: `00fde43fa3756790037b099baeafacc3e6bf9499`. The local reference is `../microzig-016`. Resolve and record its package hash if using an immutable Git URL in the final manifest. Require the same revision across root and standalone firmware builds.

For local exploration, sibling paths or compiler-supported dependency overrides are acceptable. Before acceptance, make required paths explicit and documented, or replace reference-only paths with pinned dependencies. A fresh worktree must not require an undisclosed `/tmp` file, package-cache edit, or manual change in a research clone. Preserve package fingerprints for existing packages; generate valid new fingerprints when adding packages.

The existing owned packages are `layout-model`, `device-protocol`, `companion-model`, `zigmkay`, and `zkeycodes`. New build packages can include `keyboards`, registry tooling, and the headless application. Host tests and model consumers must use one shared portable type identity. Firmware gets hardware imports separately. Share portable modules once within each build graph; create hardware-bound processor modules per MicroZig configuration rather than mutating a host-test module with board-specific imports. Do not force native target options onto modules consumed by RP2040 firmware. Generator, registry/check tools, and companion executable are always host targets, even when a firmware target is selected.

The DVUI reference revision `9b372ab0e3beca5060eb1f9ffe3e83ee61665e37` is documented for later GUI work; DVUI is not a required dependency of the phase 2 headless executable. zig-flash is not part of the ordinary phase 2 graph.

## C. Introduce an explicit publication API

Refactor package `build.zig` entry points into thin standalone wrappers around exported publication functions. Use the historical `publish` design as a reference for API shape and path ownership, not for its obsolete optional modifier types or shared_types implementation.

Suggested roles:

- Portable packages publish their modules and native/Wasm validation steps.
- `zigmkay` publishes the processor module and original core test corpus, accepting the shared model/protocol modules.
- `zkeycodes` publishes helper/base-code modules, the host generator, generation tests, regeneration, and stale-check steps, accepting the same model module.
- `keyboards/build_api.zig` publishes firmware from catalog entries and returns the emitted UF2 path and installation/compile step. It accepts the selected MicroZig build instance, shared firmware/keycode/model modules, optimization, and artifact destination.
- The root creates the shared graph and wires the public steps. It no longer reaches into `builder.top_level_steps` by string and assumes a private step exists.

Pass explicit `LazyPath`s or package-owned roots for source paths. Do not rely on process CWD or string prefixes that only work from `keyboards`. Do not import package build helper files through a second root-relative path if they already belong to a dependency build module: that caused a "file exists in modules" error in phase 1. Use the dependency's build module/public API or a single owned build-support module.

Preserve standalone test/converter/firmware entry points through the same functions. Default root behavior should run host checks or show help; it must not implicitly select the first board, build a GUI, or execute a host flasher.

**Acceptance C:** root and standalone paths use the same API and pins; module identity tests still pass; selecting firmware never cross-compiles and attempts to execute host tools.

## D. Add a committed catalog and deterministic registry

Use a small explicit committed board catalog, for example `keyboards/boards.zon`, as the source of truth. Ten entry points do not require recursive plugin discovery. Generate a committed `keyboards/generated/keyboard_registry.zig` from it. The generator verifies target names, source paths, duplicates, file existence, and deterministic ordering. Keymap/helper files are not standalone board targets.

Include all current entry points, with IDs preserving existing names:

| Target ID | Source relative to `keyboards/` |
|---|---|
| `clacky_chan` | `my_keyboards/rollercole/clacky_chan.zig` |
| `lk1` | `my_keyboards/rollercole/leonardo_keycaprio_0_1.zig` |
| `lk2` | `my_keyboards/rollercole/leonardo_keycaprio_0_2.zig` |
| `lk6` | `my_keyboards/rollercole/leonardo_keycaprio_0_6.zig` |
| `lk7` | `my_keyboards/rollercole/leonardo_keycaprio_0_7.zig` |
| `encoder_demo` | `my_keyboards/rollercole/encoder_demo.zig` |
| `tuckytwotimes` | `my_keyboards/rollercole/tuckytwotimes.zig` |
| `molekula` | `my_keyboards/molekula/main.zig` |
| `dasbob` | `examples/dasbob/main.zig` |
| `yak` | `examples/yak/main.zig` |

`yak` exists but is absent from the current keyboard_samples array. Include it. Audit for any additional true entry points introduced after this plan. Record split/encoder capability metadata where needed; do not invent left/right binaries for a board that chooses its role at runtime.

Provide a standalone registry-tool build or equivalent bootstrap command that works even when the committed generated registry is missing. A root build importing a missing registry cannot first run its own generator to repair that import. Document an independent command under `tools/registry/` for regeneration/bootstrap.

Registry generation goes to a cache output for checks. Source updates require a distinct explicit regeneration operation. If the tool writes a source file, use temp-file-plus-rename; a failure must preserve the old file. Escape Zig strings or restrict catalog paths to a validated format. Reject absolute paths and traversal outside the keyboard package.

Port every listed firmware target to 0.16, including startup/logging options and any lazy declarations not exercised by LK7. Fix actual API/type errors; do not remove troublesome boards or stub out scanners/USB to obtain a green matrix. Preserve board pin mappings and keymap actions except for a separately tested bug fix.

**Acceptance D:** all ten entries compile; every UF2 has its own output location; the registry is stable regardless of catalog input order; missing/stale/duplicate/invalid entries have actionable diagnostics. Compile success is not hardware acceptance.

## E. Publish root commands and concrete artifacts

| Root command | Required behavior |
|---|---|
| `zig build test` | All host suites including the preserved 201-test corpus, registry/build checks, and native/Wasm portability checks; no devices |
| `zig build firmware -Dkeyboard=lk7` | Build exactly the selected board; install `zig-out/firmware/lk7/zigmkay.uf2` |
| `zig build firmware-all` | Compile/install all ten catalog entries into distinct target directories |
| `zig build companion -Dkeyboard=lk7` | Build/install `zig-out/bin/zigmkay-companion-headless-lk7` |
| `zig build check-generated` | Read-only stale check for registry and committed generated keycodes; fail if anything differs |
| `zig build list-keyboards` | Print sorted valid target IDs and available companion support |

Firmware and companion requests require explicit selection. Missing or unknown selection must fail with the available IDs; it must not cause `test`, default build, or `firmware-all` to fail merely because no selection was provided. Attach selection errors to the relevant steps rather than unconditionally panicking while constructing the entire graph.

The headless companion supports LK7 initially. It reads a file containing consecutive 32-byte v1 reports, uses the actual protocol decoder and companion reducer, and exposes the final state in a deterministic textual form. Require complete report boundaries and report decoder/sequence errors clearly. Startup and file replay are offline; no HID/USB thread or GUI is started. Reject an unsupported companion board explicitly even if that board supports firmware builds.

Reuse the phase 1 literal trace to test this executable through real process/file I/O in temporary directories. Do not duplicate a second keymap or reducer in the application. File replay is an adapter around `companion-model`; the latter remains freestanding and portable.

`check-generated` compares generator outputs in the cache against committed files. Include `keycodes/all.zig` and detect missing/extra outputs, not just changed contents. Define and use one formatting policy for both explicit generation and checks. It must not rewrite or reformat source to make a check pass. Ordinary test builds may read committed outputs but do not regenerate them in place.

If retaining a placeholder `flash` command, it must fail with an explicit "not implemented in phase 2" diagnostic, rather than silently succeeding or attaching itself to install/test. Actual flasher migration belongs to the later roadmap.

## F. Verify the integration boundaries

Add tests that catch real boundary failures, using temporary minimal catalogs/project fixtures and fake tools rather than rebuilding full firmware for every negative case:

- Duplicate target, unknown target, missing selection, invalid path, and missing entry source produce clear errors.
- `test`, default, and `check-generated` work without `-Dkeyboard`; selected firmware and LK7 headless companion require it.
- Changing catalog order leaves generated registry bytes unchanged; changed/removed entries are detected by stale checks.
- An interrupted generation leaves an existing output intact; check mode leaves existing and missing files untouched.
- Root and standalone LK7 builds with identical compiler, pin, and options yield the same UF2 bytes. Compare UF2, not path-sensitive ELF/debug files.
- All ten target artifacts have unique paths; firmware-all cannot overwrite a previous board's UF2.
- The headless executable replays the exact LK7 fixture to the expected pressed/layer/modifier state and rejects truncated/invalid reports.
- A fake flash/host-tool sentinel proves that default/test/firmware builds never execute a flasher. No check enumerates disks or opens a device.
- The phase 1 type identity, gaming-layer bounds, processing retries, sink saturation, and golden reports remain unchanged.

Strengthen `tools/check-local` to use the new root firmware command. Add a `--full` mode for tests, check-generated, firmware-all, and headless executable checks. Verify the compiler pin early. Its current tracked-file digest catches changed tracked files but misses new ignored files under source directories; extend verification to detect source additions/deletions, excluding only explicit cache/output/evidence locations.

Retain the short host suite as the normal check. Run the full matrix at the final gate and again only after changes/failures justify it. Preserve existing evidence and write phase 2 logs to a new location such as `docs/evidence/phase-2/`.

## Suggested local commit sequence

1. `build: port the complete integration suite to Zig 0.16`
2. `refactor: publish shared modules and package build steps`
3. `feat: add a deterministic board catalog and registry tooling`
4. `build: publish all board targets from the repository root`
5. `feat: add the LK7 headless companion executable`
6. `test: verify generated sources and build graph boundaries`
7. `docs: record phase 2 validation and local development commands`

Reorder or split commits where a dependency requires it, but keep compiler changes, build API changes, board fixes, and application behavior independently reviewable. Every behavioral bug fix needs its targeted regression. Do not squash existing phase 1 or probe history.

## Completion gate and handoff to phase 3

From the phase 2 repository root, with Zig 0.16.0 selected and no old SDK overrides, these commands must work:

```sh
/Users/clorz/.zvm/0.16.0/zig build test -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build check-generated -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build firmware -Dkeyboard=lk7 -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build firmware-all -j4 --summary all
/Users/clorz/.zvm/0.16.0/zig build companion -Dkeyboard=lk7 -j4 --summary all
ZIG_BIN=/Users/clorz/.zvm/0.16.0/zig ./tools/check-local --full
```

Also exercise standalone core/zkeycodes tests, standalone LK7 firmware build, independent registry bootstrap in a temporary project, and missing/invalid target diagnostics. Do not use the reference worktrees as temporary test projects.

Completion requires:

- The existing 201 cases plus meaningful new checks execute successfully under the pinned 0.16 compiler.
- Ten firmware targets build with unique artifacts; root/standalone LK7 UF2 comparison passes.
- The headless companion is a real host executable that passes file-replay checks.
- Registry and keycode checks detect staleness without source mutation, including missing outputs.
- No default/test/build step executes hardware actions or relies on hidden external paths.
- SDK/compiler/dependency revisions, actual commands, test counts, artifact hashes, and unsupported features are recorded in `docs/milestone-2.md` and the new evidence directory.
- Implementation changes are locally committed; the phase 2 worktree is clean. Update README/development links and leave both prior worktrees intact.

Do not mark phase 2 complete if a board is skipped, a test is disabled, a command is a no-op, or the full suite still depends on 0.15. Report a concrete failing boundary and the reproducible command if a genuine blocker remains. No hardware operation is required to satisfy this phase.

Phase 3 then adds production transport, bounded telemetry queue recovery, Hello/Snapshot, native HID collection selection, and GUI integration on top of this graph. The successful phase 2 builds alone do not establish keyboard hardware correctness or a completed migration of every external tool.
