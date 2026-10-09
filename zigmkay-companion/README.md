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
`mise //zigmkay-companion:editor-check` for deterministic screenshots plus
geometry/interaction checks. Capture artifacts are under root
`.zig-cache/editor-acceptance`. `editor-golden-check` reads explicitly approved
baselines without updating them. Both screenshot commands remain offline and
never execute attached callbacks. The normal editor only compiles/executes draft
callbacks when starting an explicit draft Typing Test;
it never sends resulting actions to HID.

The companion overlay's Open editor button opens a separate opaque normal
window. Its content preserves the running-profile adapter, while the editor
owns an independent draft. Closing either window leaves the other usable.

The editor opens at 1152 × 768 and resizes down to 900 × 600. Its complete
layout, dialogs and click targets scale automatically to fit the window, without
scrolling the whole canvas. Individual long lists/forms retain their own scrolling.
Use `--window-size <width> <height>` with `--editor` to choose an initial size.

## Try it out

Run `mise //zigmkay-companion:editor` and choose **Try it out** in the main
navigation. **Free typing** is an ordinary single-line DVUI text entry. It uses
committed OS text and standard editing commands, including Unicode, selection,
clipboard paste, Delete and Backspace. The physical LK7 has already processed
its layout and tap/hold actions; this field does not run those inputs through a
second keymap simulation or wait for draft compilation. Reset text clears the
field. No particular macOS input source is required.

Choose **Connect companion** (or start the editor with `--live`) to explicitly
connect vendor HID telemetry. Open the project matching the installed firmware
first. The connection freezes its layout and requires the complete firmware
identity to match before displaying physical key positions and layers. An
unverified or mismatched device shows no guessed draft layout. Stale telemetry
clears held-key and momentary-layer highlights. A layer-only thumb is visible
through telemetry even though it produces no OS text. Native typing remains
available while the companion is disconnected or stale.

Editor and companion keycaps share action captions, including complete thumb
Tap/Hold actions and macOS ⌥ Option / ⌘ Command symbols. Physical pressed keys
and layer changes come from the device, rather than host scancodes. QWERTY host
position and thumb substitutes are used only by the explicit draft Typing Test
simulation; they do not represent physical LK7 input.

Choose **Typing Test** for the scored exercise below. The two modes keep separate
buffers. Switching modes or leaving Try it out pauses a test and releases the
runner; returning requires deliberate Resume. Free text survives navigation,
draft edits and input-source changes. Opening a different project clears it with
an explanation.
Diagnostics expands inline, including compiler errors, source identity and
selected-key probes during valid runner sessions. Editor retains editing,
callbacks, history and the build/flash workflow. Pending inspector edits must be
applied or discarded before switching to Try it out.

Use `mise //zigmkay-companion:editor --practice` to enter Try it out / Typing Test directly.
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

Normal desktop runs now install a native keyboard tray icon (the macOS top bar).
Its menu reports companion/device status and provides **Open Editor**,
**Show/Hide Companion**, and **Quit Zigmkay**. Closing a window hides it while
monitoring and the process continue. Open Editor restores the same draft and
history. Quit uses the existing unsaved-edit and transfer safeguards. Tray
failure falls back to the usual visible-window lifecycle.

`--editor` starts with the editor visible and companion hidden; `--light` and
`--practice` retain their normal startup behavior. Showing a window does not
enable HID access. `--live` remains the startup opt-in; deliberate flashing
retains its existing post-transfer identity verification.

Smoke, fixture, screenshot and acceptance modes keep their finite lifecycle
without a tray. After `mise //zigmkay-companion:build`, run
`zig-out/bin/zigmkay_companion --tray-check` from the repository root for the
explicit finite offline macOS tray probe. It uses an inert editor fixture and
never accesses a keyboard. Windows/Linux desktop validation is deferred; Linux
tray visibility requires a StatusNotifier watcher. See [plan 16](../docs/plans/16-ztray-companion-editor.md).

Native acceptance includes a step-by-step comparison against an ordinary DVUI
text entry, plus real processor → encoded telemetry → companion → native view
traces. These cover a layer-only left thumb, a pinky Backspace tap, its timed
Orange-layer hold, stale-state recovery and text input independent of telemetry.
Both run in dark/light themes, at both pixel densities and supported sizes.
These are offline integration checks; they do not claim attached-device testing.
