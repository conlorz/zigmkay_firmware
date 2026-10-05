# Local development

Use Zig **0.16.0** (the exact `.zigversion` pin). All first-party build tooling
and automated tests are Zig. Existing zkeymap platform bridges remain C;
introducing another language requires explicit user permission.

The canonical checkout is `zigmkay_firmware`, on `local/monorepo`. Commit
frequently and locally. Push only to the fork's `origin` when requested, and
create pull requests only when requested. Historical
integration and companion branches remain available in local Git history.
Removed clones and research notes were archived outside this workspace.

Use `mise tasks --all` to explore the monorepo and `mise //:test` to run its
tests. Every package owns a `mise.toml` task that invokes its own Zig test step;
root test depends on those tasks and the root integration task. Root Zig does
not republish package tests or forward production commands. Zig builds still
own compiler dependencies and incremental caches. Mise pins Zig 0.16.0.

`mise //:check` validates package tests, executable error paths, registry and
keycode freshness. `mise //:check-full` additionally compiles all ten boards,
GUI and flasher, compiles the flasher for supported operating systems, and
compares mise's root-output and standalone LK7 UF2 bytes. The guard itself is
Zig; it schedules the aggregate mise tasks inside the monitored interval. Both checks
reject an incorrect compiler version and hash the complete source inventory
before and after, including untracked and ignored source files. Explicit build
caches, outputs, and historical evidence are excluded. Native Zig sentinels
reject any accidental invocation of known hardware tools.

`mise //:workspace-check` verifies actual package discovery, explicit aggregate
test/generated-check coverage and exact board completion choices. Integration
tests run the same check and inspect flash dependency schedules using dry-run
only. Root/package firmware and GUI tasks inherit shared mise templates.

`MISE_JOBS` overrides the default two scheduled tasks. `ZIGMKAY_BUILD_JOBS`
overrides the default four compiler jobs per command, including guard-launched
standalone builds. The guard inherits mise's scheduler setting instead of
hardcoding another limit. Leave package caches local; measure aggregate runtime
before changing cache placement or concurrency.

Run `mise //:gui-acceptance` after editor changes. It renders every scenario in
both themes and densities, compares approved normal-state goldens, and exercises
semantic interactions and resizing. It opens offline native windows and is
separate from `check-full`; neither task refreshes committed generated sources
or approved goldens.

MicroZig is pinned to `00fde43fa3756790037b099baeafacc3e6bf9499`, DVUI to
`9b372ab0e3beca5060eb1f9ffe3e83ee61665e37`, and icons to
`b7299b19fa11caa5be93ef49743d8fc31a4bf9a0`. The immutable hashes are in the
owning manifests. MicroZig's upstream package version still reads `0.15.2`;
that revision supports Zig 0.16.0. No downloaded package is edited locally.

On macOS the validated environment uses the installed Xcode 27.0 / SDK 27.0.
No Python, sibling repository, old SDK shim, or custom package cache is needed.
Linux zkeymap uses the host `xkbcommon` library. Native layout translation tests
assume a US keyboard layout, as in the imported package.

The GUI defaults to offline mode, accepts `--replay <reports.bin>`, and offers
`--smoke` for three rendered frames without HID access. `--live` opts into HID
explicitly; device integration remains unverified. `mise //:flash <board>`
builds and runs the Zig utility; `mise //:flash-tool` only builds it.
Never run device operations without
an explicit hardware task from the user.

Earlier milestone plans and evidence describe historical checkouts and tools;
use the root README for current commands. Raw package Zig builds remain usable,
but root `zig build` means integration only. Aggregate checks require mise
2026.9.14 or newer; task execution works without shell activation. Prefer
canonical `//:task` and `//package:task` names for argument completion. Completion
files can be installed through `mise completion fish --install` or the zsh
equivalent; shell startup files are not edited by the repository.

The review refactors are integrated through `9c14cba`: shared board signaling,
modifier/path helpers, named default-profile/physical-layout publication,
runner builders, caller-policy source traversal, mise templates and workspace
consistency checks, and extracted editor drawers. The complete source tree
passed `mise //:check-full` and `mise //:gui-acceptance` on Zig 0.16.0 with mise
2026.9.14. Verification included all catalog boards, cross-target checks,
UF2 validation/parity, 88 editor scenario captures, approved normal-state
goldens, semantic interactions and resizing. Package completion, conditional
flash schedules and `ZIGMKAY_BUILD_JOBS=1` were also verified. No hardware ran;
committed generated sources and goldens were unchanged. The full check used
the existing caches; this is verification evidence, not a cold-build benchmark.
