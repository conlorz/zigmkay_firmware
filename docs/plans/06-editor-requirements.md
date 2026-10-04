# Editor feature discovery

Status: draft for user discussion, 2026-10-04. Inspected clean revision
`0eeb958`. This document does not accept G06 or authorize editor implementation.
The accepted tracker supersedes historical G05 prerequisites in 06A: hardware
04 is accepted; personal profile 05 follows the finished editor/build workflow.

## Proposed initial workflow

Open a separate editor while retaining the small monitoring overlay. Choose LK7,
clone an existing profile or create a project, select a layer and physical key,
edit its actions, validate, save and reopen. Export and later build an identified
firmware artifact. Flash is a separate explicit action in milestone 08.

Proposed editor essentials: searchable action inspector, named layers, visible
tap/hold assignments, undo/redo, key copy/paste, duplicate profile, dirty-state
indicator, recoverable drafts, validation at the affected key, and keyboard
navigation. Layer duplication and bulk assignment are candidates to discuss.
Board geometry and wiring remain board-owned unless geometry editing is selected.

Preview should distinguish HID usage and modifier chord from host input-source
labels. Show transparent inheritance separately from explicit no-action. Edited
preview must remain distinct from the verified running device profile. Consider
an offline processor test area for representative tap/hold and combo sequences;
this is a candidate feature, not yet a committed simulator requirement.

## Existing feature boundary

Source inspected: `layout-model/src/types.zig`, companion profile adapter and
existing 06A audit. The document must preserve all fields of supported actions,
including simultaneous optional tap fields, even if uncommon controls are under
an advanced section.

| Feature | Existing representation | Proposed treatment |
| --- | --- | --- |
| Keys and shortcuts | HID key plus eight modifier bits and dead flag | Searchable keys, Mac modifier names, inspect raw usage |
| Tap/hold | Tap-only, hold-only, tap-hold; per-key term and retro tapping | Dedicated tap/hold fields and timing controls |
| Layers and one-shot | Hold layer/modifiers and optional one-shot hold | Layer selector, transparent inheritance, explicit no-action |
| Combos | Exactly two physical key indices, layer, timeout and full action | Separate combo view with highlighted member keys |
| Autofire | Initial delay and repeat interval | Advanced action control |
| Media and mouse | Defined media enum, mouse buttons and wheel | Expose actual supported enum entries |
| Encoders | Tap action definition | Preserve; expose where selected board provides an encoder |
| Companion/recovery controls | Reserved built-in codes/custom signals | Named built-ins; keep user custom IDs distinct |
| Custom callback logic | Native Zig callback module | Prefer registered named bindings; never silently drop logic |
| Macros, tap dance, app-triggered layers | No general representation established by this audit | Discuss separately; require firmware/model scope investigation |

Arbitrary Zig source import cannot be promised. Prefer curated adapters for
existing profiles and registered callback modules; a new user profile can use
ordinary declarative actions. Callback-dependent layer indices need an explicit
binding contract before allowing layer reordering/deletion.

## Research observations

Primary sources retrieved on 2026-10-04; documentation review only, no competitor
UI, browser, packaging, hardware or accessibility tests were performed.

- [Oryx](https://www.zsa.io/oryx) documents visual key selection, tap/hold,
  modified-key shortcuts, advanced settings and cloning existing layouts.
  Adopt the approachable editing pattern; its macros and layer capacity are
  not evidence of equivalent capabilities here.
- [Vial combos](https://get.vial.today/manual/combos.html) documents a dedicated
  combo editor with up to four trigger keys and a timing term. Our initial
  editor should reflect the actual two-key firmware contract.
- [Vial tap/hold](https://get.vial.today/manual/mod-tap-tapdance.html) separates
  mod-tap from tap dance and explains timing options. Expose our actual rules;
  do not label QMK-specific timing options as supported by zigmkay.
- [Keymapp](https://www.zsa.io/keymapp) combines a small live layout view with
  flashing and offers heatmaps and app-specific layers. The small-view workflow
  supports our existing direction; heatmaps/training/app automation are optional
  product ideas rather than initial requirements.
- [QMK macros](https://docs.qmk.fm/feature_macros) documents sequence/string
  actions as a distinct feature. A modifier chord should not be called a macro;
  sequence editing requires its own model/runtime investigation here.
- [WebKit policy](https://webkit.org/tracking-prevention/) still lists WebHID
  and WebUSB as unimplemented. Browser editing can work without these APIs,
  but Safari device integration needs a native boundary.
- [SDL open dialogs](https://wiki.libsdl.org/SDL3/SDL_ShowOpenFileDialog)
  documents asynchronous selection and callback-thread/lifetime requirements.
  Native architecture remains plausible; application window/focus/dialog behavior
  still needs an offline spike if it is decisive to the selected workflow.

## Decisions pending

User questions issued: first-release feature breadth, preferred editing workflow,
and whether browser access has a concrete priority over the native companion.
Further decisions: bulk editing/layer tools, custom callback policy, offline
testing/preview expectations, macros or other new runtime features, and project
sharing/import scope. Answers must be recorded before the final 06B decision
and concrete 07/08 revisions; no answer is inferred from silence.
