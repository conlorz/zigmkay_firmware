# Plan 07: local verification

Use the pinned Zig 0.16.0 through mise. Run these commands from the monorepo
root, `zigmkay_firmware`. All commands below are offline. Plan 12 remains deferred;
Build/Flash in this editor belong to plan 08.

## Automated checks

```sh
mise //:check-full
mise //zigmkay-companion:test
cd zigmkay-companion
mise exec -- zig build editor-check -j4
```

The full check validates packages, real generated processor traces, all ten
board artifacts, root/standalone LK7 parity and the hardware guard. Editor tests
cover validation, undo/redo, stable IDs, save/reopen, all action fields, Unicode
editing and real child-process preparation/cancellation/crash/staleness.
`editor-check` renders 16 states in both themes at both display densities,
checks the seven panel bounds and selected key dimensions, and dispatches actual
DVUI clicks for thumb selection, isolated layer duplication, undo/redo and form
application. Each child has a 20-second timeout. Outputs remain in root
`.zig-cache/editor-acceptance`; mockup reports and blended overlays accompany
the four normal captures. The fixture never executes callback source or uses HID.

After explicit screenshot approval, `zig build editor-golden-check -j4` in the
companion package checks approved normal screenshots too. It reads baselines;
it never refreshes them. Baselines distinguish theme and source density even
though all content captures normalize to 1536 × 1024. RGB mean difference must
be at most 0.5/255, with at most 0.5% of pixels differing by more than 12 in any
RGB channel. This tolerates small text antialiasing variations. Different fonts
or operating systems require review, not automatic replacement.

## Try the editor yourself

```sh
cd zigmkay-companion
mise exec -- zig build run -j4 -- --editor
```

1. Choose the QWERTY or EurKEY draft. Click a key; Shift-click several keys for
   a bulk selection. Click Tap or Hold to open the complete action form, set a
   key/modifier/layer/timing and Apply. One application is one undo operation.
   Canvas arrow keys select positions; Command/Ctrl-C/V copy/paste actions;
   Command/Ctrl-Z and Shift-Z undo/redo. Shortcuts apply while the canvas owns
   focus, allowing normal editing of text fields.
2. Add a layer with `+`; rename it using the sidebar field. Each card's `+`
   duplicates that layer and `×` deletes it. A referenced/callback-constrained
   layer refuses deletion with a diagnostic. The nine palette slots cycle for
   higher layers, with distinct persistent numbers/names and a selection border.
3. Open / Export opens the file workflow. Choose an empty project directory and
   Save. Make another edit, then Open the saved project: the original snapshot
   returns. Save/open preserves callback bytes and all supported action fields.
   Open itself is undoable. Dirty drafts also have a cache recovery snapshot;
   Restore recovery draft is explicit. Closing a dirty editor offers Save,
   recoverable close or continued editing.
4. Choose a separate empty export directory and Export Zig. Read `manifest.zon`
   and generated files there. Re-exporting the same snapshot is deterministic;
   conflicting existing files are refused. The drawer shows draft/export IDs,
   stale exports and advisory layer/recovery analysis. The shared-profile build
   commands are in [the project contract](../../keymap-project/README.md).
5. Click Prepare Test. This explicitly compiles the frozen draft and any attached
   Zig in an isolated native runner. Start then accepts clicks on physical keys
   or mapped QWERTY positions from the host keyboard. Details offers key Down/Up
   for held chords and displays actual commands/events/signals/layers and compiler
   diagnostics. Stop resets the runner. Any draft change makes preparation stale;
   focus loss/input-source change stops testing and clears held keys/composition.
   Media/mouse/recovery commands appear as data; they do not perform OS/device
   operations. Text uses the selected native EurKEY source on macOS.
6. Click the callback filename/Attach source to manage callbacks. Supply the
   callback IDs, source root and relative Zig entry. Attachment freezes the
   literal import closure. Save first, then Open externally checks out a mirror
   and invokes the external editor. Checking the mirror detects changed/missing
   bytes; Refresh explicitly imports edits as an undoable snapshot. Registered
   sources remain read-only. Source refresh is never implicit on Save.
7. Switch dark/light. Resize to the supported minimum 900 × 600; the 1536 × 1024
   reference canvas scales together with its dialogs and click targets. The default
   window is 1152 × 768. Whole-canvas scrolling was replaced by user request on
   2026-10-05. The companion's offline
   overlay has Open editor, preserving independent native windows.

LK7 has no encoder, so the encoder view explains that constraint. Its project
schema/export/runner still preserve encoder actions where the board supports
one. There is no embedded Zig editor, arbitrary keymap-source importer, drag
layer ordering, new macro runtime or device keymap readback in plan 07.

## Native macOS probes

From the companion package:

```sh
mise exec -- zig build run -j4 -- --editor-spike
mise exec -- zig build run -j4 -- --editor-spike --native-dialog
mise exec -- zig build run -j4 -- --native-text-check
mise exec -- zig build run -j4 -- --editor-overlay-smoke
```

Cancel the folder picker in the second probe and observe the independent overlay
counter. The text check reads the currently selected EurKEY source; select that
source yourself before running it. It checks Option characters, acute dead-key
composition, noncomposable multi-scalar fallback and composition reset. These
probes never select an input source or synthesize system-wide events.
