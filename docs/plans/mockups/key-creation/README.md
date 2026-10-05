# Key creation concepts

Created 2026-10-06 for discussion. These are generated visual concepts, not
implemented screens or a replacement for the accepted editor specification.
No production code, generated keycodes, or device state changed.

All three use the existing dark editor palette, colored layer sidebar, split
keyboard, and macOS modifier symbols. Generated background key labels and
selection details are illustrative; the actual keymap remains authoritative.

| Concept | Interaction | Tradeoff |
| --- | --- | --- |
| [1: Dialog](01-dialog-dark-macos.png) | Tap and Hold side by side, shared timing, explicit Apply | Easy to compare both behaviors; covers part of the keyboard |
| [2: Inspector](02-inspector-dark-macos.png) | Persistent stacked Tap/Hold cards with an embedded picker | Recommended starting point; keeps the keyboard visible but needs a wider inspector |
| [3: Popover](03-popover-dark-macos.png) | Both assignments remain visible while search targets Tap or Hold | Compact contextual editing; placement and small-window behavior need design work |

## Findings from the current implementation

- [forms.zig](../../../../zigmkay-companion/src/editor/forms.zig) already offers
  Transparent / inherited, Explicit no action, Tap only, Hold only, Tap / hold,
  and Tap with autofire. Clearing exists but is buried in the advanced mode
  dropdown.
- [main.zig](../../../../zigmkay-companion/src/editor/main.zig) opens the same
  advanced form from both Tap and Hold in the inspector. The basic picker is a
  separate long list; key selection preserves existing hold fields, whereas
  media, signal, and layer selections replace the whole action.
- [project actions](../../../../keymap-project/src/root.zig) permit simultaneous
  tap fields: key/chord, one-shot hold, callback/signal, media, and mouse. Hold
  can combine modifiers, a layer, and a callback. The redesigned editor must
  preserve these combinations and expose every populated field.
- Tap/hold has a tapping term and retro tapping. Autofire has initial delay and
  repeat interval and is a separate action variant without a Hold.
- [assignment.zig](../../../../zigmkay-companion/src/editor/assignment.zig)
  preserves sibling action fields when assigning a chord. Modifier hold
  assignment can convert a tap-only action into tap/hold.
- [model.zig](../../../../zigmkay-companion/src/editor/model.zig) applies an
  action to the selected positions as one undo operation. Bulk editing must
  retain that history behavior.
- [processing.zig](../../../../zigmkay/src/processing.zig) resolves transparent
  positions through active layers. Explicit no action stops that fallback.

## Proposed controls shared by the concepts

- **Unassign:** explicit no action on the current layer; pressing the key does
  nothing on that layer.
- **Inherit:** remove the current layer override; use a lower active layer.
  On Base there is no lower layer.
- **Clear Tap / Clear Hold:** remove only that part and preserve the other,
  converting to hold-only or tap-only as appropriate. If neither remains, use
  explicit no action; inheritance stays a deliberate separate choice.
- **Chip removal:** remove only the represented component, preserving its
  siblings. A populated component must never disappear just because another
  category is chosen or a panel is opened.
- **Add Action:** use a picker scoped to Tap or Hold. Tap categories include
  keys/chords, one-shot, media, mouse, callbacks, and companion signals. Hold
  categories include modifiers, layers, and callbacks.
- **Advanced:** reveal HID usage, dead-key handling, callback IDs, one-shot
  details, and retro tapping only where applicable. Repeat mode exposes its own
  initial/repeat timing. Switching modes must not silently lose configuration.
- **macOS labels:** use ⌃, ⇧, ⌥, ⌘, ↩, ⌫, ⇥, and arrow glyphs with L/R tags
  where side matters. Retain accessible names and searchable full key names.
  OS-dependent presentation is separate from the stored HID assignments.
- **Apply / Cancel:** stage edits and apply to the named selection in one undo
  operation. After applying, show the actual assignment or inherited result.

The next discussion should select the interaction model before preparing an
implementation plan. No new UI implementation is authorized by this document.
