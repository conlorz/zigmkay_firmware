# 15: Unified Try it out view

Status: **design selected; implementation pending**, 2026-10-06.
The user selected **variant A, Companion below**, and requested this plan.
This request authorizes planning only. Implementation needs a subsequent request.

Baseline: `fed01c97c95f08ed0296c45fbbd9d8a0a421cd14` on `local/monorepo`.
Recheck HEAD and the working tree before implementation. Use Zig 0.16.0 and
the existing native DVUI/SDL application in this checkout. Follow both AGENTS.md
agreements and the [editor handover](handovers/07-editor.md).

## Selected outcome

Replace the separate draft-test panel and Practice overlay with two main views:
**Editor** and **Try it out**. In Try it out, default to a single-line free
typing field with the current draft's companion keyboard below it. A Reset text
button clears that field. A Typing Test button replaces the free typing area
with the existing typing-test presentation and controls. The companion stays
below both modes. Free typing returns to the baseline view.

The [selected mockup](mockups/try-it-out/01-companion-below.png) shows two
successive states of the same view: free typing above, typing test below.
They are not two simultaneous panels. Variant B was not selected.

The mockup defines placement and visual hierarchy, not new keyboard assignments
or changes to the test engine. Render real keys, thumb actions, layers and
modifier labels from the current project. Retain the existing current-word
focus, surrounding-text scrolling, correction feedback and next-key guidance;
the mockup's simplified exercise line does not replace those features.

## User-visible behavior

1. Open the application in Editor, retaining project selection, editing,
   Save/Open, history, callbacks and the existing build/flash workflow.
2. Keep Editor and Try it out available as persistent main navigation. Changing
   views preserves the selected project, applied draft, layer selection and
   undo/redo history. Resolve unapplied inspector edits through the existing
   inline Apply/Discard/Keep editing flow before previewing another snapshot.
3. Enter Try it out in Free typing on first use. Show the draft name, a focused
   single-line field, Reset text, Typing Test and the large companion beneath.
   Preserve the chosen mode during subsequent main-tab switches in this session.
4. Free typing defaults to the **unflashed current draft**, rather than silently
   typing through the currently installed firmware. Automatically prepare and
   start its offline runner on entering/focusing the view; show a compact
   Preparing state while compilation finishes. There is no separate Prepare Test
   or Start Test prerequisite in this mode. Capture input only when preparation
   has succeeded and the field is focused; do not queue keystrokes against an
   unknown snapshot during preparation.
5. Apply the existing host input-source validation and dead-key translation.
   Show actionable inline diagnostics if the source, draft or preparation fails.
   Offer an explicit retry after failure, without automatic retry loops.
6. Reset text clears the free buffer and caret, pending composition and simulated
   held state, then restores input focus. It does not change the layout, project
   history, exercise, score or personal best. Reuse a current prepared runner.
   Backspace and horizontal caret editing remain UTF-8 safe. A single-line field
   must not accumulate hidden newline/tab characters; route non-text output to
   the existing details view rather than executing host/device actions.
7. Typing Test pauses/stops free input and replaces its field and Reset text
   controls with the existing language/lesson, length, source, exercise, timing,
   scoring, progress and Start/Restart/New exercise/Pause/Resume/Stop controls.
   Keep their current defaults and behavior. Switching into this mode does not
   itself start a scored run. Preserve its separate typed buffer and options.
8. Free typing pauses an active test through the existing pause path. Returning
   to the test preserves its session and requires the existing deliberate Resume
   action. Preserve free text during mode/tab changes; only Reset text or a
   project/snapshot change clears it, with a short inline explanation for the latter.
9. Leaving Try it out or losing window focus releases simulated keys and stops
   the draft runner; a running test pauses. Tab/mode changes and focus recovery
   never resume scoring implicitly. Clicking a tab/button or a Space key after
   clicking a control must not accidentally insert text or activate that control.
10. Editing the draft, changing projects or refreshing external/input-source
    data invalidates the preview. Re-entering Free typing prepares the latest
    valid snapshot, never stale cached output. Keep the existing typing-test
    snapshot/restart rules unchanged.

## Companion and layout

- Use the native dark/light themes, blue control accents and existing typography.
  Main navigation is horizontal; the selected Try it out tab is visibly active.
- Give the typing/test area the full available content width. The companion is
  a generous, centered, full-width panel underneath, with readable split-keyboard
  keys. It is embedded in the main view, not a modal or another OS window.
- Show draft/source identity and current layer. Free typing always uses current
  draft labels and simulated layer/modifier/pressed state. It must not substitute
  a connected device's running layout for the edited draft.
- Preserve the test's OS-text versus draft-runner source choices and its verified
  live-companion behavior. Clearly label live running-profile guidance separately
  from draft guidance. A stale live source stays visibly stale.
- Keep Show companion enabled by default and available in both modes. Test
  guidance retains TAP/HOLD instructions and active-layer label behavior. Free
  typing shows actual presses without inventing a next target character.
- Retain usable geometry at 1152 × 768, 900 × 600, larger windows and both 1×/2×
  densities. Allocate the test's context and companion space responsively; avoid
  clipping the current character, action row or keyboard. Preserve horizontal
  caret visibility for long free text.
- Remove the old Try your draft/Practice launcher from Editor after migration.
  Keep callback controls in the editor's central column. Replace Details with a
  secondary inline expandable diagnostics section in Try it out, preserving
  runner state, commands/events/signals, source information and compiler errors.
  Keep low-level selected-key probes there, scoped to a valid preview session.

## Implementation map

| Area | Existing files | Planned change |
| --- | --- | --- |
| Main views, lifecycle and routing | `zigmkay-companion/src/editor/main.zig` | Add explicit Editor/Try it out and Free typing/Typing Test state; draw only the selected main view; route events by focused view and input source; remove modal-only flags and launcher wiring once migrated. |
| Embedded test presentation | `zigmkay-companion/src/editor/practice_drawer.zig` | Extract its input, word/context, actions and keyboard rendering into inline functions accepting content bounds; remove floating drawer and Close control. Keep test behavior intact. |
| Free preview text | `zigmkay-companion/src/editor/text.zig` | Reuse draft-output translation and UTF-8 editing; add an explicit clear operation. Existing `Text.reset()` clears composition/modifiers but does **not** clear bytes/caret. Keep free text separate from practice translation scratch storage. |
| Draft preparation | `zigmkay-companion/src/editor/testing.zig`, `build_inputs.zig` | Reuse immutable snapshots, bounded asynchronous jobs, sequence checks and freshness validation; automatically prepare/start only the selected free preview. Share one controller without routing output into the inactive mode. |
| Companion rendering | `practice_layout.zig`, `practice_view.zig`, `../components/layout.zig` | Reuse labels, physical geometry and guidance. Separate free-preview state from scored-session guidance without duplicating caches or changing key assignments. |
| Content bounds and diagnostics | `geometry.zig`, `test_drawer.zig`, `ui.zig` | Add tab/content bounds and responsive stacked preview layout; retain editor panel containment; convert runner details to an inline optional section. |
| Native scenarios and entry points | `states.zig`, `scenario.zig`, `capture_runner.zig`, `main.zig` | Migrate existing practice/test scenarios to the new view and add focused lifecycle scenarios. Preserve `--practice` as a compatible direct entry into Try it out / Typing Test; normal startup remains Editor. |
| Usage and integration | `zigmkay-companion/README.md`, package `mise.toml`, editor handover | Update navigation and CLI descriptions, document snapshot/preparation behavior and record actual verification. Adjust build integration only if needed for new Zig modules. |

Paths without a package prefix in the table are under
`zigmkay-companion/src/editor/`. Proposed module extraction/names are flexible;
keep first-party implementation and tests in Zig and inside the monorepo.

## Implementation checkpoints

### 15A — View state and lifecycle

- Add the two main views and two Try it out modes, with explicit focus/runner
  ownership and separate free/test buffers.
- Integrate pending inspector decisions with tab switching. Keep document state
  unchanged by view navigation.
- Define teardown/invalidation and async completion rules: jobs/results for a
  departed view or changed snapshot cannot start a runner or mutate text.
- Add behavioral tests for mode/tab transitions, pending edits, focus loss,
  snapshot replacement and stale completion rejection. Commit this checkpoint.

### 15B — Variant A and free draft preview

- Build persistent main navigation and the stacked Try it out surface.
- Wire automatic draft preparation, focused text input, Reset text, inline retry
  and source diagnostics. Use existing runner safeguards and cache identities.
- Render the current draft's companion and simulated layer/modifier/pressed
  state. Retain actual geometry/labels, including changes just applied in Editor.
- Verify an edited key emits its new output through the real offline processor;
  Reset text clears Unicode/composition and held state without changing history.
- Commit the coherent free-preview checkpoint.

### 15C — Inline typing test and cleanup

- Move existing practice presentation into the same content area. Preserve the
  engine in `practice.zig`, sentence generation, Zig lessons and scoring contract.
- Preserve word focus, context scroll, source selection, guide visibility,
  corrections, pause/resume/restart/new exercise/stop, paste preview and bests.
- Ensure every input/output has exactly one consumer. Remove the old modal,
  Close action and duplicate editor test launcher; retain details inline.
- Update `--practice`, documentation and native scenario tags. Commit this
  checkpoint after the existing tests and migrated scenarios pass.

### 15D — Verification and handover

- Run the checks below on a stable tree and capture both modes in both themes,
  densities and supported window sizes. Store generated output in build caches.
- Compare layout/hierarchy against variant A and explicitly inspect keyboard,
  current-character and action-row containment, focus and duplicate widget IDs.
- Record actual commands/results and pending visual review in the handover and
  tracker. Preserve existing approved goldens; a generated mockup is a design
  selection, not approval to replace native screenshots/goldens.
- Make focused local commits; do not push or create a pull request.

## Verification and acceptance

Use the pinned compiler through mise. Confirm `mise exec -- zig version` reports
`0.16.0`. Existing task names are verified in the root/package mise manifests:

```sh
mise //zigmkay-companion:test
mise //zigmkay-companion:editor-check
mise //:check
git diff --check
```

Run `mise exec -- zig fmt --check` with the changed Zig files. Run
`mise //:check-full` if firmware, shared build/package APIs or build integration
changes. The planned UI-only change does not require firmware changes.
`editor-golden-check` remains read-only: record expected intentional visual
differences from old baselines without weakening thresholds or rewriting them.

Acceptance requires:

- Exactly two main views; Free typing and Typing Test share Try it out with no
  Practice modal, scrim, Close button or Prepare Test launch sequence.
- Current applied draft works offline without a flash and displays matching
  companion identity, layers, modifiers, simulated presses and real key labels.
- Reset text and free/test buffers behave independently, including Unicode and
  composition. Existing draft translation and non-text output safeguards hold.
- Existing typing-test scenarios still pass: English and complete Zig files,
  immediate feedback, corrections, scoring/timing, paste preview, guidance,
  scroll, pause/resume/focus loss and session-local bests.
- No hidden editor shortcuts process typing; no late job/result updates the
  wrong mode, changed draft or inactive view; no simulated key stays held.
- Save/Open, profile selection, inspector Apply/Cancel, history, callbacks and
  build/flash controls retain their current behavior in Editor.
- Native offline screenshots and semantic interactions pass at minimum/default
  sizes in both themes and densities. Captures are evidence, not hardware tests.

No new dependencies, languages, firmware behavior, physical device access,
bootloader entry or flashing are required. Keep fixtures inert, personal project
files untouched and committed generated sources unchanged. Do not broaden this
work into new lessons, scoring changes, history persistence or a test redesign.
