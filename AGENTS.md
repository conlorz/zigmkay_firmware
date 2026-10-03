# Local development agreement

- Keep implementation, comments, diagnostics, test names, and commit messages in English.
- This repository is a local fork. Create local commits only; do not push or publish pull requests.
- Preserve the other worktrees, including the unfinished companion checkout.
- Use explicit compiler paths and document dependency and SDK versions.
- Default builds and tests must never access hardware, enter BOOTSEL, or flash firmware.
- Keep generated test outputs in the build cache, not in source directories.
- Use Leonardo Keycaprio v0.7 (`lk7`) for the first integration milestone.
