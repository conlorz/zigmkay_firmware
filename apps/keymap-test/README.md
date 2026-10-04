# Native draft runner

Specializes the real firmware processor from a verified editor export. No device
APIs or OS input injection. Contract 1 and build commands are in
[the project contract](../../keymap-project/README.md#runner-and-jobs--contract-1).
`mise //apps/keymap-test:test` runs generated all-action, registered callback,
protocol/reset and latency fixtures. Default builds use a cache-generated EurKEY
draft; `-Dprofile=/absolute/export` selects a verified immutable export instead.
