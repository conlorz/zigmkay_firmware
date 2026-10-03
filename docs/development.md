# Local development

This is a local fork, developed on `local/integration` from
`c5580be52119bb028588a3cc8329fe4fdecfbd27`. The other worktrees are references.
Code, comments, tests, diagnostics, and commit messages use English. Commits
stay local. The milestone is described in [the plan](first-implementation-plan.md).

## Compiler and SDK

The comparison compiler is Zig 0.15.2, installed locally at
`/Users/clorz/.zvm/0.15.2/zig`. Zig 0.16.0 is installed at
`/Users/clorz/.zvm/0.16.0/zig` and is evaluated on a separate probe branch.

The installed SDK did not link Zig 0.15.2's build runner: unresolved libc symbols
are recorded in `evidence/baseline/installed-sdk-core.log`. For baseline checks
explicitly select the study's private SDK view and xcrun shim:

```sh
ZIG_BIN=/Users/clorz/.zvm/0.15.2/zig \
ZIG_SYSROOT=/tmp/zigmkay-macos-sdk \
ZIG_XCRUN_DIR=/tmp/zigmkay-sdk-tools \
./tools/check-local --firmware
```

These temporary paths are a local workaround, not a portable prerequisite.
`ZIG_BIN`, `ZIG_SYSROOT`, and `ZIG_XCRUN_DIR` are independently configurable;
without SDK/shim overrides the compiler uses its installed SDK selection.
`--firmware` compiles LK7. No check invokes the flash step or searches for devices.

## Baseline dependency revisions

- MicroZig: `bd650e87a808385d3f05d365d128c58956b91bfe`.
- zig-flash: `da54a2e130e1ed4aaa8cb1fb0854e532ed497cb7` (compile dependency only).
- zigmkay and zkeycodes: local sibling packages in this repository.
- Baseline core: 165 tests; root aggregation executes the same core corpus.

Baseline logs and the reference UF2 digest are in `docs/evidence/baseline`.
Hardware behavior is not inferred from successful compilation.

## Completed first milestone

See [milestone-1.md](milestone-1.md) for results and current limits, and
[device-protocol.md](device-protocol.md) for the exact offline wire contract.
The root `test` step now includes every host suite delivered in this milestone.
`tools/check-local --firmware` passes 201 tests and compiles LK7, while verifying
that tracked files are unchanged by the checks. Generated test fixtures live in
the build cache; `zig build convert-all` in zkeycodes is the explicit source
regeneration step.

The bounded 0.16 dependency probe is on `local/probe-016` in the sibling
`firmware-integration-016` worktree. It passed core/model tests, minimal RP2040,
LK7, native SDL3 DVUI, and DVUI-Wasm. It does not yet migrate all host tools or
include the final integration trace. Phase 2 should use the successful 0.16 pins.
