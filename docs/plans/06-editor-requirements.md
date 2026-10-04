# Editor feature discovery

Status: agreed feature scope, 2026-10-04. Initial inspected clean revision
`0eeb958`; source findings refreshed at `63f7998`. The accompanying
[06B decision](06-editor-architecture-decision.md) defines architecture acceptance.
This document does not authorize editor implementation.
The accepted tracker supersedes historical G05 prerequisites in 06A: hardware
04 is accepted; personal profile 05 follows the finished editor/build workflow.

## Proposed initial workflow

Confirmed by the user on 2026-10-04:

- Native editor in a separate companion window; retain the small live overlay.
- First release exposes the full existing firmware feature set, including layers,
  tap/hold, combos, timing, media/mouse and autofire.
- Visual keyboard with searchable action inspector, layer tabs and copy/paste.
- Named layers with add/duplicate/delete; multi-key selection and copy/paste.
- Draft testing also includes sample text using EurKEY output in the editor.
- Advanced workflow for attaching the user's own Zig callback module, alongside
  named registered callbacks for existing profiles.
- Test inputs come from virtual keys or another keyboard mapped to draft positions;
  display EurKEY text and tap/hold/combo events without flashing.
- Attached modules live inside the project and are edited in the user's usual
  external code editor. Preserve source on save/export and show compiler errors.
- Explicit editor Enter bootloader action over vendor HID is selected for 08;
  keep the physical board combo as recovery fallback.
- Colored numbered/named layer selector reuses the companion palette: red, blue,
  orange, lime, purple, teal, green, yellow and pink. Color complements names and
  numbers; define additional distinguishable presentation for layers beyond nine.
- Keyboard-model dropdown selects the project board/geometry. Connected firmware
  identity remains separate and must agree before device operations; changing the
  dropdown does not change or identify the physical device.
- Full OS keyboard visualization, like macOS Keyboard Viewer, shows the active
  input-source layout including function/number rows, punctuation, modifier keys,
  space and arrows. Shift/Option previews update character labels. Keep this
  standard OS keyboard separate from the editable LK7 physical geometry.

Open a separate editor while retaining the small monitoring overlay. Choose LK7,
clone an existing profile or create a project, select a layer and physical key,
edit its actions, validate, save and reopen. Export and later build an identified
firmware artifact. Flash is a separate explicit action in milestone 08.

Proposed editor essentials: searchable action inspector, named layers, visible
tap/hold assignments, undo/redo, key copy/paste, duplicate profile, dirty-state
indicator, recoverable drafts, validation at the affected key, and keyboard
navigation. Layer duplication and multi-key editing are selected requirements.
Layer reordering is not selected for the initial release. Deletion must diagnose
references and callback constraints; duplicate layers get distinct identities.
Board geometry and wiring remain board-owned unless geometry editing is selected.

Preview should distinguish HID usage and modifier chord from host input-source
labels. Show transparent inheritance separately from explicit no-action. Edited
preview must remain distinct from the verified running device profile. Draft
testing includes a text area for EurKEY output and actual processor simulation
from virtual keys or explicitly mapped keyboard positions.

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
| Custom callback logic | Native Zig callback module | Registered bindings plus attached source modules; preserve all logic |
| Macros, tap dance, app-triggered layers | No general representation established by this audit | Discuss separately; require firmware/model scope investigation |

Arbitrary Zig keymap source import cannot be promised. Use curated adapters for
existing profiles; attach callback source without attempting to convert it into
visual forms. Callback-dependent layer indices need an explicit binding contract
before allowing layer deletion. Standard declarative profiles need no callback.

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

## Scope boundary

Visual direction selected by the user: the clean
[light layer-sidebar concept](mockups/editor-02-light-layer-sidebar.png), with
vertical colored layer cards, central physical keyboard, right-hand inspector
and full OS keyboard viewer below. Preserve this composition in dark mode too.
Mockup text/key symbols remain illustrative; actual labels come from the active
input source and action model.

All issued feature questions have been answered and recorded above. Live LK7
telemetry is not the draft test input. No embedded Zig editor is selected.
Full existing-feature support does not select new macro/tap-dance implementations.
Additional sharing formats, geometry editing and layer reordering remain deferred.

## Additional source findings

`zigmkay/src/processing.zig` specializes `CreateProcessorType` at compile time
for the keymap, dimensions, combos, callbacks and encoder actions. An accurate
offline test area for arbitrary drafts therefore needs either a generated native
test runner compiled from the frozen draft or a carefully tested processor change
to accept runtime data. It cannot be promised as an immediate reuse of the current
processor in the editor. Prefer the generated runner if testing is selected,
subject to measured build latency; keep outputs in build caches.

Existing callback examples use mutable module-level state and fixed layer indices.
Test-runner isolation/reset and callback-bound layer constraints need explicit
design. Layer renaming can remain metadata-only; reordering/deleting callback
layers cannot be made safe merely by updating declarative layer references.

## EurKEY text test design proposal

Source inspected: `zigmkay-companion/src/input_source.zig`,
`zkeymap/src/platform/macos.zig`, existing imported `macos.c`, and
`zigmkay/src/core.zig`. Overlay labels use an isolated state and no-dead-keys
translation. The existing native bridge has stateful translation, but its
four-byte result and explicit `dead` handling are not sufficient evidence for
arbitrary composed output. Processor output contains key presses/releases and
modifier changes; the action's `dead` flag does not survive as a distinct output
event. Translate the resulting key/modifier sequence according to the input
source, rather than inventing an output dead-key flag.

For simulated text, add a Zig-owned translation session calling existing macOS
framework APIs, separate from labels. Preserve composition state between output
key presses, handle UTF-16/multiple-scalar results with bounded buffers, and reset
on test restart or input-source change. Identify the active input source and
layout; show an explicit mismatch when EurKEY is not selected. Initially use the
installed active layout, without bundling upstream layout data or changing the
system input source automatically. Display non-text actions and shortcuts in an
event log. Ordinary text entry tests the active OS layout, but by itself cannot
validate an unflashed draft's key assignments or timing.

Simulated output stays within the test area: media, mouse, BOOTSEL and companion
signals are displayed as events. This proposal does not require system-wide key
injection or live hardware. A telemetry-driven test mode would need a separately
scoped hardware workflow and must address the keyboard's simultaneous real output.

Primary sources retrieved 2026-10-04:

- [Apple UCKeyTranslate](https://developer.apple.com/documentation/coreservices/1390584-uckeytranslate)
  documents stateful dead-key translation and bounded output.
- [EurKEY Next README](https://github.com/felixfoertsch/EurKEY-Next/blob/main/README.md)
  documents installed layout variants and dead-key composition. Record the actual
  selected layout/version during acceptance; no installed version was audited here.

## Attached callback design proposal

Use a project directory containing a versioned typed ZON document and owned
callback source files. Attaching a module copies its bytes into that directory;
save/reopen/export preserves the bytes and records their digest. Editing callback
source invalidates prior build/test results. Missing files or digest mismatches
produce actionable diagnostics; never replace a callback with a no-op.

Define a Zig module ABI based on existing `CustomFunctions`, plus binding metadata
for named tap/hold custom IDs, reserved-ID restrictions, and required layer indices.
Metadata is data; source is opaque until an explicit build/test. Treat metadata as
a declared contract, not proof of arbitrary code behavior. Unconstrained attached
modules conservatively lock layer deletion that would renumber existing indices.
Surface compiler file/line diagnostics. Keep imported first-party callback files
inside the monorepo project area; pin any separately approved external dependency
through `build.zig.zon`. Reject unresolved imports with a useful error.

Offline callback tests use a generated native runner process, allowing reset by
restarting it and capturing bounded events/errors without running callback code
in the UI process. A subprocess isolates crashes and mutable callback state; it
is not a security sandbox for arbitrary Zig. Code may run at compile time as well
as runtime. Opening, attaching and saving do not compile or execute source.
Do not create an embedded source editor unless the user selects it.

## Device keymap readback investigation

The current HID protocol exposes identity/digest, live key/layer state and
snapshots, not complete action assignments. A digest can locate an exact local
project/build snapshot but cannot reconstruct an unknown map. Prefer this lookup
for the simplest local workflow, explicitly showing when no matching project is
available. Do not infer key assignments from observed keystrokes.

Read-only keymap transfer over the existing vendor HID channel is feasible as a
separate protocol extension: export a versioned portable action/metadata blob at
build time and serve bounded requested chunks with total length, digest,
session/request correlation, cancellation and capability negotiation. Pace reads
so typing and recovery telemetry retain priority. It does not require dynamic
remapping or EEPROM. Legacy firmware needs a first flash adding that capability.
Board geometry can resolve from the local catalog; unknown versions must fail
clearly. Report missing metadata rather than invent layer names.

Compiled callback machine code cannot reconstruct original editable Zig source.
Readback can preserve registered binding IDs/digests and action data; full project
recovery also requires embedding the exact project metadata and attached source
bundle in firmware, with an explicit storage-size budget. Without that bundle or
a matching local callback module, imported custom behavior remains read-only or
export-disabled. The user selected this as the separate deferred
[plan 12](12-device-keymap-readback.md): complete configuration first, custom Zig
source recovery later. It does not expand the initial editor implementation scope.

Primary transport precedent retrieved 2026-10-04:
[QMK Raw HID](https://docs.qmk.fm/features/rawhid) documents bidirectional fixed
32-byte reports. Our existing protocol already uses that transport shape; QMK is
supporting precedent, not a dependency or proof of implemented readback here.
