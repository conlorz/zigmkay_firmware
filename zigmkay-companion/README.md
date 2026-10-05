# Desktop companion

The Zig 0.16.0 DVUI/SDL3 companion uses the shared LK7 keymap, telemetry codec,
and state reducer. DVUI and icons are pinned dependencies; zkeymap is local.

From the monorepo root, `zig build companion -Dkeyboard=lk7` builds the GUI.
Run `zig-out/bin/zigmkay_companion` for offline mode, add `--replay <file>` to
replay consecutive 32-byte reports, or `--smoke` to render three frames and exit.
Only `--live` enumerates the keyboard's vendor telemetry HID interface.
All event reduction and UI changes occur on the UI thread.

This package also supports standalone `zig build`, `zig build test`, and
`zig build run -- --smoke`. Live hardware operation has not been validated.

The separate native LK7 editor is available with `mise //zigmkay-companion:editor`
(or standalone `zig build run -- --editor`). It supports complete action forms,
named layers, bulk edits, combos, undo/redo, atomic project persistence, immutable
callback snapshots, deterministic export and an explicit isolated native draft
test runner. Only LK7 geometry is selected in this milestone. Draft/export IDs
remain separate from running firmware. Build captures the selected draft into an
immutable export and builds an identified LK7 UF2 with Zig 0.16.0. Flash opens
the explicit transfer workflow with artifact hash, selected absolute recovery
volume and confirmation. No build or startup performs a device operation.
See [plan 08 verification](../docs/plans/08-editor-verification.md).

With the live overlay, compatible firmware advertises explicit Enter bootloader.
After transfer the overlay negotiates the frozen profile identity and displays
its labels. Transfer, coherent running identity and user-confirmed typing are
recorded separately. Physical boot positions 0 + 4 remain available. The exact
G04 accepted rollback is retained when present in the local cache; later
artifacts become rollback candidates only after typing confirmation.

Follow [the self-verification guide](../docs/plans/07-editor-verification.md)
for edit/save/reopen/export/testing and native macOS probes. Run
`mise //zigmkay-companion:editor-check` for 90 deterministic screenshots plus
geometry/interaction checks. Capture artifacts are under root
`.zig-cache/editor-acceptance`. `editor-golden-check` reads explicitly approved
baselines without updating them. Both screenshot commands remain offline and
never execute attached callbacks. The normal editor only compiles/executes draft
callbacks after explicit Prepare Test; it never sends resulting actions to HID.

The companion overlay's Open editor button opens a separate opaque normal
window. Its content preserves the running-profile adapter, while the editor
owns an independent draft. Closing either window leaves the other usable.

The editor opens at 1152 × 768 and resizes down to 900 × 600. Its complete
layout, dialogs and click targets scale automatically to fit the window, without
scrolling the whole canvas. Individual long lists/forms retain their own scrolling.
Use `--window-size <width> <height>` with `--editor` to choose an initial size.
