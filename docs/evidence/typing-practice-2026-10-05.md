# Typing practice implementation evidence

Implemented English sentence generation and complete Zig-file copying in the
native editor with Zig 0.16.0. The Practice button is in Try your draft. Default
English length is five sentences; short/long use two/ten. Zig ships functions,
arrays/structs and error/optional lessons, each formatted and compiled by the
companion's ordinary offline test step.

The bounded Unicode session engine has injected time and seed, corrections,
CRLF normalization across input events, pause/resume, immutable references,
exact completion, explicit WPM/accuracy fixtures and paste invalidation. Errors
aggregate by expected character. The panel has synchronized reference/input
columns, line numbers, current-line emphasis, automatic caret scrolling and
fixed controls. OS committed text and native draft output are mutually exclusive.
Draft composition reuses the existing native input-source translator. Focus loss
stops the runner and releases held keys; changed draft identity requires Restart.

Validation:

- `zig build check-full -j4`: passed, including the offline aggregate, all ten
  boards and standalone/root LK7 UF2 parity. No hardware tool executed.
- Companion `zig build test -j4 --summary all`: 57/57 tests passed, including
  the three lesson compiler checks and real native draft-runner output fed into
  practice without changing the model. Later UI-only changes received native
  scenario checks; the final root check includes the final source revision.
- `zig build editor-check -j4`: 122 captures and existing editor interactions
  passed at both themes and densities. Practice states are included in the
  capture matrix; a subsequent full-file scrolling scenario extends that matrix.
- Final native `practice_input` and `practice_scroll` scenarios passed in all
  light/dark and 1x/2x combinations at 900×600. These cover committed text,
  correction, first input, Tab/newline, completion, restart, pause/resume,
  ignored paused input, focus loss, unscored paste, full Zig-file completion and
  scrolling the current line into view. Screenshot/log artifacts remain in
  `.zig-cache/practice-*`; approved goldens were not regenerated.

Limits: personal bests live only for the editor session; persistent history,
adaptive lessons, imported files and free-form coding remain follow-ups. Practice
simulates draft behavior offline; it does not claim flashed-device acceptance.
User hands-on acceptance is pending.
