# Plan 07B acceptance evidence

Implementation: local coordinator; Zig 0.16.0; macOS 26.6.2 (25G83).
07A remains frozen at `016cf7d`. Native editor/capture integration is in local
`8e4039f`. No first-party language/dependency update, hardware access, bootloader
request, flashing, push or PR occurred. Plan 12 remains deferred.

## Functional and native evidence

Companion component checks pass 40/40 tests. The document model demonstrates a
concrete two-key tap-hold/dead/retro edit, undo/redo, constrained deletion,
layer duplicate/rename/delete, atomic save, reopen and twice-identical export
with the saved snapshot ID. Imported layer IDs cannot collide with additions.
Forms preserve all simultaneous optional tap fields. Literal processor traces
and lossless Danish/callback exports remain covered by accepted 07A tests.

The editor controller actually compiles and starts the exported native runner,
checks literal A press, then verifies fresh-process reset, restart with no old
output replay, crash containment, cancelled preparation and changed-draft
staleness. Build-input/compiler/target identity participates in the cache key.
The actual command/event/signal details drawer is scrollable; media/mouse/BOOT
results remain data. Child processes, output and queued inputs are bounded.

The native separate-window probe verifies an opaque editor, independently routed
mapped key input, focus-loss reset, resize to 1024 × 700 and closing the child
without closing the parent. In the native folder-dialog run it recorded 1,970
telemetry ticks, including 1,958 while the dialog was open. The user explicitly
confirmed cancelling the picker while the independent overlay kept updating.
The actual companion/editor offline smoke additionally checks child flags:
opacity 1 and no always-on-top inheritance. No HID is opened.

Actual macOS input source:
`de.felixfoertsch.keyboardlayout.EurKEY-Next.eurkeynext`, installed bundle
Build/SourceVersion `2026.03.22`. Native literal translation checks read that
source without selecting it: Option+A → ä, Option+E → ë, Option+S → ß;
Option+quote starts acute dead state, then E → é; noncomposable Q yields `´q`
(two scalars); reset then E yields `e`. Fixture tests separately cover Unicode
cursor boundaries, insertion/delete/backspace and composition reset. These
checks translate processor output; no synthetic system input is sent.

Keyboard arrows and Command/Ctrl copy/paste/undo are scoped to canvas focus.
Mapped test inputs use window IDs and stop on focus/source change. Semantic
DVUI event scenarios exercise thumbs, per-card duplicate hit areas, Undo/Redo
and advanced-form Apply; owned fixture action data supplies the form edit.
Native mouse/key routing is separately covered by the spike. Screen-reader
and general accessibility audits were not performed; no accessibility claim is
made beyond these tested navigation/focus behaviors.

## Visual evidence

`editor-check` captures all 16 required 07 states in dark/light at 1×/2×: normal,
multiple selection, layer add/rename, deletion constraint, combo, advanced form,
dirty, no device, wrong identity, validation, callback missing/changed and test
preparing/running/stale/failed. Build/flash progress is deliberately reserved
for 08. Actual readback dimensions are 1536 × 1024 and 3072 × 2048; both normalize
to 1536 × 1024 content pixels. Capture occurs after rendering and before present;
SDL owns the readback surface until copied and destroyed. Captures use the
installed SFNS font with Arial Unicode glyph fallback; embedded Vera remains
the fallback on other systems. System fonts are read, never redistributed.
Synthetic bold and native antialiasing differ from the generated reference.

All seven tagged panel bounds match the reference rectangles exactly at both
scales (0 logical-pixel error), passing the ±4 px tolerance. The physical key
width is 65 px. Normal captures and comparison reports/half-blend overlays are
under root `.zig-cache/editor-acceptance`. The RGB means below are descriptive
mockup differences on 0–255 channels, not pixel-identical acceptance:

| Region | Dark mean | Light mean |
| --- | ---: | ---: |
| Toolbar | 20.80 | 25.21 |
| Sidebar | 15.06 | 26.56 |
| Physical canvas | 12.01 | 16.91 |
| Inspector | 13.34 | 14.86 |
| OS viewer | 12.74 | 14.88 |
| Test footer | 13.99 | 18.91 |
| Callback footer | 20.53 | 25.12 |

The reference and actual dark/light images were viewed, with additional advanced
and combo form captures checked. This caught and corrected empty-sized numeric
fields, abbreviated modifier controls and a clipped callback control. Primary
panels remain visible at reference size. Minimum normal content is 1280 × 900;
smaller-than-reference content scrolls at unchanged font/key sizes.

Intentional deviations from generated mockups:

- Catalog LK7 geometry is authoritative: two empty central columns, catalog
  thumb positions and actual 34 key indices replace generated stagger/rotation.
- Actual Navigation arrows, transparent inheritance cues, full ANSI geometry and
  installed EurKEY preview characters replace illustrative/duplicated labels.
- The existing saturated nine-color palette is authoritative. Higher layers
  cycle those slots with distinct number/name labels and a noncolor selection
  outline; list scrolling preserves readable cards. `+`/`×` provide separate
  duplicate/delete hit targets rather than generated icon artwork.
- Native window decoration remains outside captured content. The toolbar exposes
  one supported LK7 board, independent offline/fixture identity, profile choice,
  file workflow and Undo/Redo. Disabled Build/Flash say 08; they are inert.
- A rename field sits in the otherwise empty lower sidebar. Test Details and
  callback management remain reachable without changing the panel grid. Callback
  filename opens management; Open externally is directly available.
- Flat prescribed theme tokens, installed fonts and complete correct host labels
  replace generated gradients, shadows and typography. No missing-glyph boxes
  were observed in inspected normal/advanced/combo captures.

Screenshot approval and regression-golden acceptance are recorded separately
below when the user approves the concrete captures. The visual specification
requires that explicit decision; this document does not grant it automatically.

## Explicit visual approval

On 2026-10-04 the user selected **Approve these screenshots as goldens** for the
concrete linked dark/light captures, their documented deviations and their
1×/2× variants. Those four approved images are preserved in
[the golden directory](goldens/07-editor/README.md), with environment and SHA-256
records. The comparator accepts an identical capture with mean RGB delta 0 and
zero significant pixels; a deliberately wrong-theme comparison fails with
`GoldenImageMismatch` (mean 198.3196, 1,536,505 significant pixels). It never
updates a baseline. Native dialog continuity was separately user-confirmed.
