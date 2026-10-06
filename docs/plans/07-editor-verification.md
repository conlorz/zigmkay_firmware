# Plan 07: local verification

## Personal project at startup

The editor reopens the last successfully opened or saved project. Its absolute
folder path is atomically stored in the gitignored workspace-local
`projects/startup-project.zon`; the layout itself stays in that folder's
`project.zon` and immutable source snapshots. Cache cleanup does not remove this
preference. Startup does not build or flash, and deterministic fixtures neither
read nor write the preference.

Before any project is remembered, an existing `projects/eurmac` is opened as a
personal starting point. Otherwise the built-in EurKEY draft is used. A missing
or invalid remembered project produces an editor diagnostic instead of silently
changing the remembered path. Choose **Open / Export**, select/open another
project folder, or save the current layout there to update the startup project.
Save changes before quitting to reopen those changes next time; unsaved recovery
drafts still use the separate recovery workflow. The profile selector displays
the loaded document's name.

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
`editor-check` renders all declared editor scenarios in both themes at both
display densities, checks the remaining editor panel bounds, embedded preview
controls and physical key containment,
and dispatches actual DVUI input for search, drag/drop, inspector editing,
layer duplication and history. Inherited, unassigned, mixed, Repeat, validation
and pending-edit states have dedicated captures. Each child has a 20-second
timeout. Outputs remain in root `.zig-cache/editor-acceptance`; a descriptive
report and blended overlay compare the dark normal captures with the selected
step-14 mockup. The fixture never executes callback source or uses HID.

After explicit screenshot approval, `zig build editor-golden-check -j4` in the
companion package checks approved normal screenshots too. It reads baselines;
it never refreshes them. Baselines distinguish theme and source density even
though all content captures normalize to 1536 × 1024. RGB mean difference must
be at most 0.5/255, with at most 0.5% of pixels differing by more than 12 in any
RGB channel. This tolerates small text antialiasing variations. Different fonts
or operating systems require review, not automatic replacement.

The docked inspector deliberately changes the panel geometry. The existing
approved screenshots predate step 14, so their golden comparison is expected
to fail until replacement captures receive explicit approval. Keep those
baselines intact; the screenshots in the root README document the current app
and do not authorize a regression-baseline replacement.

## Try the editor yourself

```sh
cd zigmkay-companion
mise exec -- zig build run -j4 -- --editor
```

1. Choose the QWERTY or EurKEY draft. Click a key; Shift-click several keys for
   a bulk selection. Use the docked inspector's Tap and Hold cards to choose an
   action target, search the embedded catalog, and edit modifiers and timing.
   Remove an individual chip or Clear a side without replacing the other side.
   Apply commits the staged changes as one undo operation; Cancel discards them.
   Bulk component edits preserve each selected key's untouched fields.
   Unassign explicitly does nothing; Inherit removes the override so a lower
   active layer can supply the action. Inherit is disabled on Base.
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
5. Choose Try it out in the main navigation. Apply or discard any pending
   inspector edits first. Free typing automatically compiles the frozen draft
   and attached Zig in an isolated native runner, then accepts mapped QWERTY
   positions while the field is focused. Select EurKEY on macOS. During
   preparation input is ignored; failures require Retry. Reset text clears the
   buffer, caret, composition and held state without changing history. The draft
   companion remains below. Diagnostics expands inline with commands, events,
   signals, layers, compiler errors and low-level key Down/Up probes.
   Choose Typing Test for the existing English/Zig exercises and OS/draft source
   choices. Switching modes preserves separate buffers and pauses a test;
   returning requires Resume. Leaving the view or losing focus releases the
   runner. A changed snapshot/input source clears free text with an explanation.
   Media/mouse/recovery commands remain data; they perform no OS/device actions.
6. Click the callback filename/Attach source to manage callbacks. Supply the
   callback IDs, source root and relative Zig entry. Attachment freezes the
   literal import closure. Save first, then Open externally checks out a mirror
   and invokes the external editor. Checking the mirror detects changed/missing
   bytes; Refresh explicitly imports edits as an undoable snapshot. Registered
   sources remain read-only. Source refresh is never implicit on Save.
7. Switch dark/light in Editor. Resize to the supported minimum 900 × 600;
   the editor canvas and navigation scale together with dialogs and click
   targets, while Try it out uses the full available content width. The default
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
