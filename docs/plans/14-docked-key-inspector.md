# 14: Docked key inspector and assignment editing

Status: **design selected; implementation pending**, 2026-10-06. The user chose
[mockup 2](mockups/key-creation/02-inspector-dark-macos.png) and requested this
implementation plan. This request covers planning and handover updates.

Base: `b9b660f`, containing the three concepts and
[repository findings](mockups/key-creation/README.md). Recheck HEAD and the
working tree before implementation. Follow the workspace agreement: Zig 0.16.0,
existing native DVUI/SDL editor, focused local commits, and offline checks.
Consumers start from the [editor handover](handovers/07-editor.md).

## Outcome and selected design

Replace the large key-action modal and separate key picker with a docked
inspector. Keep the keyboard visible while users configure Tap and Hold,
remove individual actions, disable a key, or restore inheritance.

Mockup 2 is the interaction and dark-mode appearance target. Preserve its
stacked Tap/Hold cards, removable chips, compact modifier controls, embedded
search, and fixed Apply/Cancel footer. Preserve the existing charcoal palette,
blue selection accent, colored layer identities, and native typography from
[the visual specification](06-editor-visual-specification.md).

This deliberately changes the former short inspector and full-width OS viewer:
the inspector spans the content height; the physical keyboard, OS viewer, and
test/callback panels share the remaining central column. Retain the toolbar and
layer sidebar. Generated key labels and selection inconsistencies in the mockup
are illustrative; source real assignments and geometry from the current project.

Deliver the macOS presentation first. Retain the existing light theme with the
same controls and hierarchy. Other operating systems need label fallbacks but
are not new platform acceptance targets for this change.

## Inspector structure

1. Header: selected key preview, physical identity, layer name, selected-key
   count, and Copy/Paste. Display assignment status as Custom, Inherited, or
   Unassigned; inherited previews identify their source layer.
2. Mode control: Tap, Hold, Tap / Hold, Repeat. Inherited and Unassigned states
   have no active editing mode until the user deliberately adds an action.
3. Independent Tap and Hold cards: every populated component has a visible chip
   and removal control. Each card has Clear and Add Action. Show No tap/No hold
   when empty. A card's selection sets the embedded picker's target.
4. Contextual settings: Tapping term in ms for Tap / Hold; initial delay and
   repeat interval for Repeat. Advanced expands only relevant rare settings.
5. Embedded picker: persistent search, short category labels, bounded result
   list, and an explicit Add to Tap or Add to Hold target. No modal opens for
   ordinary key, modifier, layer, media, or mouse selection.
6. Fixed footer: Unassign, Inherit, Cancel, Apply. Clearing choices include the
   short descriptions Do nothing and Lower active layer. Apply shows the
   selected count for bulk edits and is disabled when clean or invalid.

Keep header/footer visible; scroll only the middle inspector content. Tooltips,
accessible control names, and validation messages carry details without making
the default view a wall of explanatory text.

## Editing rules

### Clearing and inheritance

| Control | Staged result | Preserved data |
| --- | --- | --- |
| Unassign | Explicit `.none` on the selected layer | Other layers and keys |
| Inherit | `null` on the selected layer | Lower-layer assignments |
| Clear Tap | Hold-only when Hold remains; otherwise `.none` | All Hold components |
| Clear Hold | Tap-only when Tap remains; otherwise `.none` | All Tap components |
| Remove chip | Remove only that component; normalize an empty side | All other components |

Unassign blocks lower-layer fallback; Inherit removes the layer override. On
Base, Inherit has no lower layer and is disabled with a short explanation.
Existing transparent Base entries remain losslessly loadable.

Removing the last component must never silently select inheritance. Resolve
inherited previews separately from stored actions. Editing an inherited key
creates a local override based on its resolved preview and preserves untouched
components. The static draft preview identifies its lower-layer source; runtime
fallback still depends on which layers the real processor has active.

### Components and mode changes

Tap categories cover key/modifier chord, one-shot, media, mouse, callback, and
companion signals. Hold categories cover modifiers, layer, and callback. Hold
must not offer an ordinary letter key or media/mouse action. Preserve recovery
usage 252 and reserved tap signals 253–255 using existing validation and names.

Each optional schema field has at most one component. Choosing another value
for that component updates it rather than adding an unsupported duplicate.
Selecting a key changes only `key_press`; selecting media changes only
`media_key`; adding a held layer preserves held modifiers and callbacks.
Show every populated field, including imported combinations. Never collapse a
compound action to the first field returned by the current label helpers.

Selecting a modifier toggles the corresponding left/right bit. A key's tap
modifier chord, a one-shot's modifiers, and Hold modifiers have separate editors.
Tap permits one-shot plus other tap fields; its one-shot editor supports
modifiers, a layer, and callback together.

Mode changes affect staged edits only. Conversions preserve all compatible
components. Tap / Hold retains tapping term and retro tapping when already
present; new tap/hold conversions use the existing 180 ms default. Repeat cannot
contain Hold. If a mode conversion removes populated fields, show a concise
removal summary before Apply; Cancel restores the original assignment. Merely
opening a card, changing search categories, or opening Advanced changes no data.

Advanced exposes HID usage, dead-key handling, one-shot details, declared custom
callback IDs, reserved companion signals, and retro tapping where applicable.
Keep callback source attachment/open/refresh in the existing callback workflow.
Invalid timing, missing callback IDs, and invalid layer references remain inline
errors; a rejected Apply leaves document identity and history intact.

### Staging, selection, and bulk editing

Use an editor-owned session bound to the starting snapshot, stable layer ID,
selected key IDs, original stored actions, and resolved inherited previews.
Apply constructs and validates one immutable snapshot and adds one undo entry.
If the resulting actions equal the originals, Apply adds no history entry.
Cancel discards the session. Editing widgets alone must not mark the project
dirty, invalidate a prepared runner, or schedule an automatic firmware build.
Successful Apply uses the existing document-change path for those effects.

For multiple keys, display Mixed where values differ and record edits by field.
Apply the explicit changes independently to each selected action, preserving
each key's untouched tap, hold, timing, and callback data. For example, adding
L ⌘ to Hold on A and S retains A and S as their respective Tap values. Do not
reuse `Model.apply(primary_action)` for a partial bulk edit; that replaces all
selected actions with one value. Whole-assignment Unassign/Inherit and deliberate
Paste may replace all selected actions in one operation.

Mixed modifier bits use a mixed visual state. Clicking a mixed bit sets it for
all selected keys; clicking a uniformly selected bit clears it. Preserve every
other modifier bit instead of inverting each key independently. Normalize empty
parts only after deliberate edits; viewing imported empty action variants must
not rewrite their representation.

Changing key/layer/profile, opening another project, Save/Build/Flash/Test,
document Undo/Redo, or closing the editor while inspector edits are pending must
resolve the session first. Use compact Apply / Discard / Keep editing choices;
do not silently apply or lose changes. A changed underlying snapshot invalidates
the session rather than applying it to different keys. Text-field shortcuts
retain normal text behavior while focused. Escape exits picker/search focus
without clearing assignments or discarding edits.

OS-keyboard drag/drop onto Tap/Hold stages the same component edit as the picker.
Canvas drag/drop retains the existing direct undoable behavior after resolving
any pending session. Copy/Paste uses committed actions; resolve pending edits
before these operations so the source is unambiguous.

## macOS labels and layout

Use ⌃ Control, ⇧ Shift, ⌥ Option, ⌘ Command, ↩ Return, ⌫ Backspace, ⇥ Tab, and
arrow glyphs. L/R tags identify modifier side; tooltips and accessible names
spell it out. Search accepts glyphs, full names, and aliases such as Ctrl,
Control, Command, Cmd, GUI, Alt, Option, and numeric HID usages. Store HID values
and modifier bits unchanged; host presentation belongs in the label layer.

Reuse `editor/fonts.zig` for local macOS fonts and glyph fallback. A small pure
display-convention helper can accept an explicit host enum for tests and use
the running host by default. Other hosts fall back to Ctrl, Shift, Alt, and
Win/Super as applicable; no new native bridge or dependency is needed.

At the 1536 × 1024 reference size, start with a roughly 440 px inspector and
12 px gutters. Derive central canvas and keyboard bounds from the remaining
space rather than retaining hard-coded positions from the wider old canvas.
Fit both real 17-key halves and the complete host keyboard without clipping.
Keep stable key IDs and board geometry independent of presentation transforms.

Support the existing 1152 × 768 initial and 900 × 600 minimum windows with
automatic scaling, correct scaled hit targets, bounded local scrolling, and a
visible footer. Compact the test/callback row as needed without hiding its
actions or diagnostics. Update geometry assertions and visual comparison
regions for this deliberate layout change; do not suppress overlap or clipping
checks to make the old fixtures pass.

## Implementation checkpoints

1. **Action editing model.** Add a UI-independent Zig session/patch helper under
   `zigmkay-companion/src/editor/`, with component mutation, clearing,
   normalization, mixed-value aggregation, and atomic per-key bulk application.
   Extend `model.zig` with the required validated batch-commit entry point.
   Keep the version-1 project/export/runner schema frozen.
2. **Labels and picker.** Extend `labels.zig` and reuse `fonts.zig`; add a bounded,
   target-aware action catalog/picker with aliases and structured previews.
   Share the same component mutation path across search, modifier buttons, and
   drag/drop. Cover signal IDs and compound action summaries.
3. **Docked UI and lifecycle.** Add a dedicated inspector drawing module,
   integrate session ownership in `main.zig`, and revise `geometry.zig` and
   shared `ui.zig` helpers. Route ordinary key editing to the docked UI and
   retire its old modal/picker paths after feature parity. Retain reusable
   `forms.zig` support used by combo editing; audit consumers before removal.
4. **Offline interaction and visual evidence.** Extend `scenario.zig`, semantic
   interaction coverage, and comparison tooling for the new geometry and
   states. Update editor usage and verification documentation, run the checks
   below, and produce native screenshots in caches.
5. **Review and handover.** Record code revisions, passing checks, real captures,
   mockup deviations, and pending visual review in the editor handover. Keep
   approved old goldens until the user explicitly approves replacement captures.

Make focused local commits at these boundaries. The implementation owner owns
the agreed editor files and dedicated tests; shared build glue and integration
remain coordinator-owned. No firmware/protocol changes or new language are
expected. Do not modify personal project files during fixtures or verification.

## Acceptance and verification

Meaningful action-model cases must cover a compound Tap/Hold with every optional
field, individual chip removal, Clear Tap/Hold, explicit no action versus
inheritance, inherited editing, Repeat conversion, mixed-key bulk preservation,
validation failure, Cancel, stale sessions, no-op Apply, and one-step undo/redo.
Save/reopen/export must preserve the resulting actions and callback sources.
Use the existing real offline processor runner for representative traces:
explicit no action blocks a lower A; transparent inherits it when its layer is
active; clearing Hold retains the tap; clearing Tap retains the modifier/layer.

Native semantic scenarios must exercise separate Tap/Hold targets, filtered
search, symbol/alias lookup, L/R chords, combined modifier/layer Hold, media and
one-shot edits, per-chip removal, bulk Apply/Cancel, selection changes with
pending edits, validation, focus, keyboard shortcuts, and footer accessibility.
Capture ordinary, inherited, unassigned, mixed selection, advanced, Repeat,
validation, and pending-edit states in dark/light at 1×/2× and resized windows.
Preserve existing toolbar, combo/callback, draft-runner, practice, and profile
persistence coverage; fixtures must remain idle for hardware and auto-build.

Existing commands, from the monorepo root:

```sh
mise //zigmkay-companion:test
mise //zigmkay-companion:editor-check
mise //:check
git diff --check
```

Use the pinned compiler for `zig fmt --check` on changed Zig files. Run
`mise //keymap-project:test` and `mise //:check-full` if changes cross package,
export, firmware, or build boundaries. New captures go in `.zig-cache`; committed
generated sources are not regenerated. These are required future checks, not
results claimed by this planning document.

The existing `mise //zigmkay-companion:editor-golden-check` is expected to detect
the intentional redesign against old normal screenshots. Record that mismatch
and present actual new captures before requesting replacement-golden approval.
Do not auto-refresh baselines, increase tolerances, or bypass golden validation.
After approval, run the golden check against the approved replacements.

Completion requires functional checks, readable native captures close to mockup
2, preserved action data and history, and an updated handover identifying any
remaining visual review. Native accessibility claims require actual checks.
The next ready step is checkpoint 1 under an implementation request; no hardware
session is needed to implement or verify the inspector.
