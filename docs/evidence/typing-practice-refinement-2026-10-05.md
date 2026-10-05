# Layout-first typing practice refinement

The user asked to learn the specific layout while practising, with an optional
companion view, a larger centered current word, an obvious next character and
moving text. [Open-Typer](https://open-typer.sourceforge.io/) was the requested
interaction reference. The implementation remains first-party Zig 0.16.0; no
application code, corpus or assets were imported from that project.

## Result

Practice uses a nearly full-window tutor view instead of two small copy columns.
The current word stays centered; the next Unicode scalar has a blue box. A
mistake remains red and in focus until corrected, with the actual typed character
and required Backspace count. Surrounding English or Zig text moves through a
centered current line with smooth time-based scrolling. Zig retains indentation,
source line numbers and explicit newline/space cues. WPM, accuracy, elapsed time,
progress and correction feedback update with input; completion retains results,
code CPM and the most troublesome expected character.

Show companion defaults on, keeping the physical LK7 map below the exercise.
Gold outlines mark the expected key, a needed modifier, or a direct layer-hold
access. Standalone practice previews the selected draft using the current native
input source and names its profile. Draft-runner practice displays simulated
physical presses, layers and modifiers. When opened from a verified live
companion, practice borrows that companion's running-profile labels and state,
so a different editor draft cannot replace the device's labels. Incompatible or
unverified sessions do not supply a live state. Pressed-state colors and expected
key hints remain distinct. Turning the keyboard off expands the text area without
resetting or pausing practice.

Transparent keys resolve through enabled layers, matching the processor's rules.
Dead keys and Control/Command shortcut chords do not receive false direct-text
hints. Space after clicking the visibility control remains practice input;
shortcut Enter does not count as a newline attempt. No new hardware access is
introduced. The direct offline entry is
`mise //zigmkay-companion:editor --practice`.

## Validation

- Companion tests pass, including deterministic word focus, Unicode correction,
  wrapped text coverage, modifier/layer hints, transparent active-layer lookup
  and suppression of dead-key/shortcut hints.
- Root `zig build check-full -j4` passed: every package, ten firmware boards,
  generated-source checks and standalone/root LK7 artifact parity. No hardware
  tool executed. Final component checks also cover subsequent presentation and
  hint-eligibility refinements.
- Native `editor-check` passed 142 captures, existing editor interactions, both
  themes and 1x/2x densities. New states include centered English, Zig, errors,
  hidden companion, live-state fixtures and visibility/input interactions.
- Focused final 900×600 checks cover practice input/completion, full-file Zig
  scrolling, companion hide/show while typing, Space after checkbox focus,
  shortcut suppression, mistake feedback and changing live-state fixtures.
  Screenshots/logs are in `.zig-cache/practice-redesign-*`; approved goldens
  were not regenerated.
- Manual screenshot inspection verified the large character glyphs, near-full
  resized view, centered word and readable embedded keyboard.

Live pressed-state verification uses fixtures here; it is not a new physical
keyboard acceptance claim. User hands-on review of the revised design is pending.
