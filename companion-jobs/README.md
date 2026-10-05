# Companion jobs

Zig 0.16.0 offline process support. Contract 1 is documented in
[the project contract](../keymap-project/README.md#runner-and-jobs--contract-1).
Run `mise //companion-jobs:test`. `Job` and `Session` must have stable addresses;
serialize session requests, release returned bytes/results and deinitialize owners.
Only explicit callers launch processes. No hardware or shell-command API exists.

`firmware` publishes the plan 08 offline selected-build contract: immutable
`Inputs`, literal owned `Command`, and frozen `Manifest` with validated UF2
path/size/hash. See the [08 handover](../docs/plans/handovers/08-build-flash.md).
Failure, cancellation, changed compiler/source inputs or changed UF2 bytes cannot
promote a stale artifact. The package test step runs both process and manifest
suites without hardware access.
