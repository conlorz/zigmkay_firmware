# Zig workspace agreement

This workspace is a Zig project. The canonical monorepo is `zigmkay_firmware/`.
Use Zig 0.16.0, pinned by its `.zigversion`, and implement as much as possible
in Zig: production code, build logic, utilities, generators, and tests.

- Other languages may be introduced or used for new implementation only with
  explicit user permission. Existing imported C interoperability bridges and
  upstream dependencies may be retained; do not expand them without permission.
- This fork uses `origin` at `git@github.com:conlorz/zigmkay_firmware.git`
  for fetches and pushes. Keep `upstream` at
  `git@github.com:zigmkay/zigmkay_firmware.git` for reference; upstream pushes
  remain disabled. Push only to the fork, never upstream. Do not create pull
  requests unless the user asks. Make frequent, focused commits inside
  `zigmkay_firmware` so mistakes can be rolled back easily.
- Keep first-party packages inside the monorepo. Pin external dependencies in
  `build.zig.zon` with immutable revisions and hashes. Do not recreate sibling
  clones or branch worktrees unless the user asks for them.
- Default builds and automated tests must not access hardware or flash firmware.
  Device operations require an explicit hardware task from the user.
- Run appropriate Zig checks for each change. Keep generated test outputs in
  build caches; update committed generated sources only by explicit regeneration.
- Keep code, comments, diagnostics, test names, and commit messages in English.

For milestone coordination, read [the central tracker](docs/plans/TRACKING.md)
and [the subagent workflow](docs/plans/SUBAGENT-WORKFLOW.md). Respect exclusive
file ownership, coordinator-owned Git/build integration, and accepted handovers.
Planning files alone do not authorize implementation or device operations.
