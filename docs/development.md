# Local development

Use Zig **0.16.0** (the exact `.zigversion` pin). All first-party build tooling
and automated tests are Zig. Existing zkeymap platform bridges remain C;
introducing another language requires explicit user permission.

The canonical checkout is `zigmkay_firmware`, on `local/monorepo`. Commit
frequently and locally. Never push or publish a pull request. Historical
integration and companion branches remain available in local Git history.
Removed clones and research notes were archived outside this workspace.

`zig build check` validates host tests, executable error paths, registry and
keycode freshness. `zig build check-full` additionally compiles all ten boards,
GUI and flasher, tests standalone packages, compiles the flasher for supported
operating systems, and compares root and standalone LK7 UF2 bytes. Both checks
reject an incorrect compiler version and hash the complete source inventory
before and after, including untracked and ignored source files. Explicit build
caches, outputs, and historical evidence are excluded. Native Zig sentinels
reject any accidental invocation of known hardware tools.

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
explicitly; device integration remains unverified. Root `flash` is disabled;
`flash-tool` builds without running the tool. Never run device operations without
an explicit hardware task from the user.

Earlier milestone plans and evidence describe historical checkouts and tools;
use the root README for current commands.
