# Mise monorepo task migration

User-authorized 2026-10-04. This tooling work is independent of pending hardware
acceptance. No flashing or HID enumeration is part of its verification.

## Design and tradeoffs

Mise owns task discovery, completion, package working directories, the Zig pin
and repository-wide scheduling. Each package retains its own Zig build, tests
and immutable dependency manifest. Root Zig owns only cross-package integration
tests and the offline source/hardware guard, not package test orchestration or
firmware/GUI/flash forwarding. TOML commands are declarative invocations of Zig;
new validation and generation logic remains Zig.

Use real monorepo mode with explicit configuration roots. Every package exposes
its own tasks; root aliases delegate to these tasks. Board and optimization
arguments have usage specifications with completion choices. No implicit board,
live HID, flashing, generated source updates or cache-based task skipping.

This is appropriate for Zig: mise schedules commands and Zig still owns compiler
dependencies and incremental builds. Costs: mise is required for aggregate
workflows, its monorepo syntax depends on the installed mise version, and separate
package builds may repeat work through their independent local caches. Do not
duplicate the compiler dependency graph in mise or expand shell glue into logic.

## Implementation sequence

1. Add root and package mise configurations, exact Zig 0.16.0 pin, descriptions,
   task dependencies, typed arguments, and offline defaults.
2. Reduce root build to integration checks. Add missing package test steps and
   a standalone headless build; move generated registry checking to its package.
3. Make the Zig guard run mise aggregate tasks while preserving compiler-version,
   source-inventory, no-hardware, all-board and artifact-parity checks.
4. Update README/development commands and install shell completion without
   changing shell startup files. Verify actual task discovery, argument choices,
   package working directories, aggregate tests, full checks and GUI smoke.
5. Commit focused changes locally; leave hardware acceptance pending.

Sources: [monorepo tasks](https://mise.jdx.dev/tasks/monorepo.html),
[task arguments](https://mise.jdx.dev/tasks/task-arguments.html),
[task configuration](https://mise.jdx.dev/tasks/task-configuration.html).

## Acceptance evidence

Implemented root monorepo config plus eleven package configs. Root Zig no longer
orchestrates package builds (implementation `447efb8`). It no longer
publishes the GUI, flasher, firmware matrix or package test runners; it imports
modules for integration and owns the guard. Packages retain native build/test
steps; headless replay now has a standalone build and manifest.

Passed: aggregate package/integration tests, guarded `mise //:check-full`, ten
boards, host artifacts, five flasher targets, Wasm checks, headless replay and
mise/standalone UF2 parity. Source inventory unchanged; no hardware tool ran.
Actual GUI smoke through the new typed root task passed. Board/optimization and
GUI flag help validated, as did actual Fish completion. Installed completion
files for Fish/zsh without editing startup files. Flash dependency scheduling
was inspected with dry-run only. Existing automatic-flash-restart investigation
remains pending; this migration does not claim hardware acceptance.
Root conversion and replay were exercised with repo-relative paths; conversion
outputs stayed in cache. CLI checks verify actual board and GUI completion on
every integration run, independently of Zig's incremental cache.

Version caveat: on validated mise 2026.9.14, canonical `//:task` names complete
arguments correctly; unqualified `mise run task` executes but falls back to file
completion. README uses canonical names. Root `test` has explicit package test
dependencies, not a wildcard that could recursively include itself.
