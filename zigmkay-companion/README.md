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

## Typing practice

Run `mise //zigmkay-companion:editor` and click **Practice** in **Try your draft**.
Use `mise //zigmkay-companion:editor --practice` to open practice directly.
Choose English (2, 5 or 10 generated sentences) or Zig (three complete, formatted
and tested Zig 0.16.0 files), then press Start. The typed buffer starts empty.
The current word stays large and centered. Its next character is boxed in blue;
mistakes turn red and show the typed character and correction needed. Surrounding
text scrolls smoothly with the current line centered; completed characters are
green and upcoming text is muted. The view fills the resized editor, including
at 900×600. Tab inserts four
spaces, Enter inserts a newline, and Backspace corrects a character. Completion
requires an exact copy of the entire exercise. Restart repeats it; New exercise
changes the English seed or selects the next Zig lesson.

OS keyboard text uses committed text from the selected macOS input source.
Unflashed draft layout compiles an immutable offline runner; wait for preparation,
then press Resume. Physical QWERTY keys use the existing LK7 position mapping.
Changing the draft pauses practice and requires Restart to prepare its new layout.
Focus loss and Escape pause; Resume is deliberate and simulated held keys are
released. Practice never flashes firmware or changes your keymap.

**Show companion** is enabled by default. It keeps the physical LK7 keyboard
below the text, with gold borders for the next key, modifier or layer access.
Standalone practice previews the selected draft and names its profile. When
practice is opened from a connected live companion, the embedded keyboard uses
that companion's verified running profile, pressed keys, active layers and
modifiers. Draft-runner practice shows its simulated pressed keys and layers.
The guide labels these sources separately. Hiding it gives the text more space
and does not pause or reset the exercise. Dead-key compositions and callbacks
without a directly matching label do not receive an invented key hint.

Results include WPM, accuracy, active duration, corrections, file progress, CPM
and the most troublesome expected character. Errors remain in accuracy after
correction. Paste produces an unscored preview. Personal bests are kept for this
editor session, separately for each mode/length/lesson/input source; they are not
saved to disk. Corpus version 1 uses original English templates and stable Zig
lesson IDs. There are no accounts, downloads or hardware requirements.
