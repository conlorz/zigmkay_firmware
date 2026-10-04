# Companion jobs

Zig 0.16.0 offline process support. Contract 1 is documented in
[the project contract](../keymap-project/README.md#runner-and-jobs--contract-1).
Run `mise //companion-jobs:test`. `Job` and `Session` must have stable addresses;
serialize session requests, release returned bytes/results and deinitialize owners.
Only explicit callers launch processes. No hardware or shell-command API exists.
