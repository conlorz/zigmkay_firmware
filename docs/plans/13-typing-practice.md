# Typing practice: English sentences and Zig files

Status: researched and planned on 2026-10-05; implementation follows the editor usability fixes. All production code, generation and tests use Zig 0.16.0.

## Research and design decision

[Monkeytype](https://github.com/monkeytypegame/monkeytype) demonstrates immediate character feedback, speed/accuracy displays, different test lengths and punctuation modes. [Keybr](https://github.com/aradzie/keybr.com) focuses on learning individual keys and building practice around weaker letters. These are useful interaction references; implement our own small engine and original sentence templates without importing their application code or datasets.

The [Zig 0.16.0 language reference](https://ziglang.org/documentation/0.16.0/) is the version-specific source for valid lesson syntax and built-in testing. Developer practice should use complete, first-party Zig files checked with our pinned compiler, rather than arbitrary token sequences that merely resemble code.

Use a dedicated Practice panel in the editor, with English and Zig modes. Keep the existing draft tryout for testing firmware behavior. Practice can use either actual OS text input or the prepared draft runner, clearly indicating its source. This distinction lets someone practice the connected keyboard or try an unflashed layout without confusing a draft result with device behavior.

## User experience

1. Choose English or Zig, then a length/difficulty and input source. Start opens the exercise inline. Timing begins on the first accepted character.
2. Show the reference text, current caret, correct characters and mistakes using the existing theme. Keep Restart, New exercise and Stop visible. Focus loss pauses and releases simulated draft keys; resume requires a deliberate action.
3. English defaults to five grammatical sentences, with punctuation and capitals. Offer short, normal and long exercises. Generate offline from an original vocabulary and grammatical templates using a stored seed; retry repeats the same exercise and New changes the seed. Avoid immediately repeating templates and subjects.
4. Zig starts with an empty input buffer beside a complete reference file. The user types the whole file, including indentation, punctuation and newlines. Provide line numbers, visible current-line emphasis and synchronized scrolling. No autocomplete, automatic closing brackets or automatic indentation in the default scored mode. Tab inserts four spaces and remains in the exercise; Escape leaves input focus.
5. Allow Backspace corrections. Completion requires matching the full reference. Incorrect characters remain visibly wrong and count as attempts even after correction. Results show WPM, accuracy, duration, corrected errors and the most troublesome characters. For code, also show characters per minute and file completion because WPM is less intuitive for punctuation-heavy input.
6. Paste may populate a preview but invalidates a scored run. Key repeat is handled consistently. Shortcuts and modifier presses are not character attempts; committed OS text, including composed characters, is the scoring source.

## Scoring contract

- WPM = correctly matched characters / 5 / elapsed minutes, with spaces and newlines included. Display zero before elapsed time is positive.
- Accuracy = correct character insertion attempts / all character insertion attempts. Backspace and navigation do not inflate the denominator; correcting an earlier error does not erase that attempt.
- Keep monotonic elapsed time excluding explicit pauses. Store active duration separately from wall duration.
- Compare Unicode scalars, normalize CRLF to LF at input boundaries, and never count UTF-8 bytes as characters. Initial generated lessons use ASCII, but OS composition must remain valid UTF-8.
- Report error counts by expected character and input source. Timing and errors are observations; do not infer physical finger use or hardware key position from text alone.

## Zig lessons

Include three original, small complete files: basic functions and a test; arrays/loops and a struct; an error union with optional handling. Prefer `zig test` lessons so examples avoid unnecessary platform I/O boilerplate. Each has a stable ID, display name, difficulty, reference bytes and compiler version. Keep target files around 15–60 lines, formatted with `zig fmt` and compiled by offline tests.

Initially ship these curated files rather than generating arbitrary Zig programs. Add seeded variants only once a generator can guarantee both validity and useful exercises. A completed typed file may be explicitly saved by the user. Completion checks text equality; optional compiler validation runs only on explicit request, in a cache directory with captured diagnostics.

## Implementation sequence

1. Add `editor/practice.zig`: a UI-independent session state machine (ready/running/paused/complete), UTF-8-safe edits, monotonic timing, counters, seeded exercise selection and result calculation. Inject the clock and seed for tests.
2. Add a sentence generator and original Zig lesson assets within the companion package. Use immutable reference text separate from typed text. Register lesson formatting/compilation checks in the existing hardware-free build steps.
3. Add `editor/practice_drawer.zig` and a Practice entry in the current editor. Use responsive layout, bounded scrolling and fixed controls, reusing theme/button helpers. English and Zig share the session engine; Zig adds line/indentation rendering.
4. Connect actual text input through DVUI committed-text events. Refactor the existing `editor/text.zig` adapter to expose inserts/deletes from draft-runner output to the same engine, preserving its native layout/dead-key translation. Prevent both input sources from feeding a session simultaneously.
5. Keep any optional history local and separate from keymap undo/snapshots. Start with the current result and personal best per mode/difficulty/input source; identify corpus versions so different exercises remain distinguishable.
6. Add semantic native scenarios for start, first-character timing, errors/corrections, pause/resume, restart, completion, Tab/newline and scrolling a full Zig file. Verify small windows, light/dark themes and both display densities. Confirm draft practice never flashes or changes the draft.

## Acceptance checks

- Generated English is grammatical, capitalized, punctuated and reproducible by seed; New changes content and Retry preserves it.
- Every Zig reference is formatted and passes `zig test` with 0.16.0. The initial editor buffer is empty and the complete file can be typed without focus leaving on Tab.
- Deterministic timing tests cover zero duration, pause/resume, correction counters, Unicode composition, completion and paste invalidation.
- Native interaction tests verify actual committed input and prepared-draft input independently, including focus-loss release behavior and no duplicated events.
- Result formulas have explicit fixtures. Editing a keymap while using draft input pauses the exercise and requires preparing a fresh snapshot; a run never combines two layouts silently.
- No hardware, network account or downloaded corpus is required for generation or default tests.

## Defaults to revisit after the first working version

Use exact-copy Zig exercises with manual indentation and local generation of English sentences. Free-form coding challenges, adaptive weak-key lessons, arbitrary user-file import and longer-term progress charts can follow once the core practice is usable. These are follow-ups, not prerequisites for the requested two modes.
