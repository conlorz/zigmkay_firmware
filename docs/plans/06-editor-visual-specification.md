# Editor visual specification and comparison workflow

Status: selected visual target, 2026-10-04. The user requests a close recreation
of the clean layer-sidebar concept, in light and dark mode. This is an
implementation/acceptance specification for 07B and 08B, not an implemented UI.

Primary dark reference: [dark layer sidebar](mockups/editor-04-dark-layer-sidebar.png).
Light counterpart: [light layer sidebar](mockups/editor-02-light-layer-sidebar.png).
Both reference images are 1536 × 1024 pixels. Prefer the dark reference when
resolving layout/style questions; retain the light version as the light-theme
target. Other earlier concepts are alternatives, not competing design targets.

## Overall composition

Recreate a restrained native desktop utility: a full-width toolbar, a narrow
vertical layer sidebar, a large physical keyboard canvas, a right-hand key
inspector, a full OS keyboard viewer underneath, and a compact bottom test and
callback row. Match panel proportions, alignment, density, hierarchy, colors and
spacing closely. Avoid a web dashboard appearance, decorative charts, large
marketing headings, heavy gradients, neon effects or glass effects.

The editor is a separate normal resizable window; the small companion overlay
remains separate. The reference fills the frame with the application. Implement
normal macOS window controls rather than drawing fake functional traffic lights.
Native title-bar decoration can differ from the generated reference; the app
content geometry must still match when the capture is normalized to content bounds.

The sidebar spans from below the toolbar to the bottom margin. To its right,
the upper row contains the physical canvas and inspector. The OS viewer spans
the width of both upper panels. The bottom row divides into a wider test panel
and narrower callback panel. Align all outer edges and use consistent gutters.

## Reference geometry

Coordinates below are approximate measurements from the raster, not claims of
an original design file. Use them as a starting layout grid, then compare actual
screenshots. Express application geometry in logical units; record display scale
and normalize screenshot pixels before comparisons.

| Region | Approximate reference rectangle x/y/w/h | Relationship |
| --- | --- | --- |
| Toolbar | 0 / 0 / 1536 / 67 | Full width; subtle bottom divider |
| Layer sidebar | 15 / 77 / 247 / 932 | Fixed narrow column |
| Physical keyboard panel | 273 / 77 / 869 / 445 | Main upper canvas |
| Key inspector | 1153 / 77 / 368 / 445 | Right upper column |
| OS keyboard viewer | 273 / 533 / 1248 / 380 | Spans canvas and inspector |
| Draft test panel | 273 / 923 / 785 / 87 | Left bottom area |
| Callback panel | 1068 / 923 / 453 / 87 | Right bottom area |

Outer content margins are about 15 px, inter-panel gutters 10–12 px. Panel
padding is generally 16–20 px. Panels have about 12 px corner radii and subtle
1 px borders; fields/buttons use 6–8 px radii. Match common baselines precisely.
Use an 8 px spacing rhythm where practical, allowing reference-specific offsets.

## Theme and typography

Dark window background: charcoal near `#191B1F`; panels near `#22252A`; controls
and keycaps near `#30343B`; quiet borders near `#424852`. These are intended
tokens, not sampled exact raster values. Primary text is near-white, secondary
text muted light gray. Blue is the general interaction accent and selected-key
outline. Shadows are soft and minimal. Ensure controls stay visually distinct
from panel backgrounds without thick outlines or oversized bevels.

Use a clean sans-serif with macOS-like proportions and verified distribution
rights. Reference starting sizes: app name 24 px semibold; panel headings 18–20
px semibold; controls/body 15–16 px regular; secondary metadata 13–14 px;
physical key labels 20–22 px; OS key labels 17–19 px. Scale consistently rather
than mixing arbitrary font sizes. Use suitable symbols for Command, Option,
Shift, Control, Return and arrows. Never show missing-glyph boxes.

The light theme uses off-white window/panel backgrounds, dark primary text,
light gray keycaps, thin gray borders and the same blue accent/layer identities.
Maintain the same spatial layout and hierarchy across themes.

## Toolbar

Left to right: native window controls, Zigmkay name, Keyboard label and model
dropdown, connection indicator/name, a quiet separator, Profile label/dropdown,
then right-aligned Save, Build and Flash. Controls are compact, about 38–40 px
high, with consistent internal padding. Flash is filled blue in the reference;
Save/Build use neutral surfaces. Disabled states must still communicate their
labels and why the action is unavailable.

The model dropdown selects project board geometry; the independent connection
status identifies the actual device. Never claim connection merely because LK7
is selected. Profile editing and running device identity remain distinguishable.
Dirty state, build progress and errors may use small badges/status text without
displacing this toolbar. 08 adds explicit Enter bootloader access in the device
action menu or adjacent compact control; it must not overload Build or Flash.

## Colored layer sidebar

Header: Layers at left, small square add button at right. Underneath are vertically
stacked rounded cards with about 7 px gaps, about 58–60 px height and about 224 px
width in the reference. Each card has a saturated number block at left, layer
name in the middle, duplicate and delete icons at right. Numbers are larger
than layer names. Keep icons aligned and hit areas comfortably usable.

Reuse the existing companion palette:

| Layer color slot | Hex |
| --- | --- |
| 0 red | `#FF3232` |
| 1 blue | `#3296FF` |
| 2 orange | `#FF9632` |
| 3 lime | `#96FF32` |
| 4 purple | `#B432FF` |
| 5 teal | `#32FFC8` |
| 6 green | `#32FF32` |
| 7 yellow | `#FFE632` |
| 8 pink | `#FF32B4` |

The mockup uses approximate shades; the established palette is authoritative.
In dark mode, inactive cards have dark color-tinted bodies and saturated number
blocks; the selected card fills with its layer color and has strong readable
text/icon contrast. Light mode uses light tinted card bodies. Include a clear
selection cue beyond color; names and numbers must always be present. Layers
beyond nine need a documented readable extension rather than array overflow or
indistinguishable white fallbacks. Scroll the list if it exceeds available height.

Example fixture names: Base, Navigation, Numbers, Symbols, Gaming, Media.
Names are editable metadata, not hard-coded behavior. Duplicate/delete buttons
must not select or mutate another layer accidentally. Show reference/callback
constraints when deletion is unavailable. Do not add drag reordering to this scope.

## Physical keyboard canvas

Header left: LK7 keymap, current layer number badge and name. Right: compact View
dropdown and overflow menu. Beneath, centered labels identify left and right
halves with 17 keys each. Leave generous breathing room around two keyboard
halves; avoid filling the panel with stretched keys.

For LK7, draw 3 rows × 5 keys per half and 2 thumb keys per half: 34 keys total.
Reference keycaps are roughly 66 × 66 px with narrow 5–7 px gaps; each half is
about 355 px wide, separated by a substantial middle gap. Preserve the real
catalog's schematic stagger/rotation and thumb placement. Mockup geometry is
guidance, not authority for GPIO, key indices or accurate physical measurements.

Keycaps use dark neutral faces, fine borders and subtle shadows. The selected
key has a crisp blue outline and slightly tinted face. Multi-selection needs a
matching readable selected treatment. Show tap action as the primary label and
compact hold/layer indicators where applicable. Distinguish transparent inherited
actions from explicit no-action. Actual Navigation assignments must render as
navigation actions: the mockup's QWERTY labels on that layer are illustrative.

Click selects; keyboard navigation provides equivalent selection. Copy/paste
and bulk edits form coherent undoable operations. Keep the physical canvas tied
to the draft, not to an unverified claim that its assignments are on the device.

## Key inspector

Header: Key inspector, with small Copy and Paste buttons at right. Top body row
contains a large selected keycap preview and Physical key metadata describing
half, row, column and stable/index identity. Then vertically aligned form rows:
Tap dropdown, Hold dropdown, timing numeric field with ms unit. Labels form a
consistent left column; fields form a consistent right column. A subtle divider
separates action configuration from the searchable action picker below.

The reference demonstrates Tap A, Hold Command and 180 ms. Label timing according
to actual firmware semantics, preferably Tapping term; do not imply every hold
waits exactly that long. All existing action fields need reachable controls:
one-shot, layer/modifiers, custom IDs, retro tapping, autofire, media/mouse and
combined optional tap fields. Use expandable advanced sections or inspector
scrolling rather than enlarging the default form and destroying composition.
Expose combo and encoder editing through the view/menu or inspector tabs while
preserving this primary layout. Attached Zig remains externally edited.

## Full OS keyboard viewer

Header left: OS keyboard and actual input-source name. Right: Show characters
with modifiers, with Shift and Option toggles. These preview modifiers belong
to OS character translation, not firmware layer selection. Additional modifier
controls can use a compact expanded area. Source changes refresh labels and
reset composition as specified in the test workflow.

Display the complete chosen standard host geometry: function row, number row,
alphabet rows, punctuation, Tab, Caps Lock, Return, both Shift keys, bottom
modifiers, space and arrow cluster. Use appropriate variable-width keycaps and
about 5 px gaps. OS keycaps are shorter than physical keycaps, roughly 47–50 px
high. Keep the entire keyboard visible at the reference size.

Primary character labels are near-white; modifier-preview/secondary characters
use blue with adequate contrast. Highlight active preview modifiers. Identify
ANSI/ISO host geometry explicitly when supported; use correct Return/extra-key
shape for that geometry. Draw each key once and source characters from the
installed layout. Do not reproduce duplicated letters, inaccurate accent symbols
or arbitrary function labels introduced by image generation. The viewer is a
host mapping reference, separate from LK7 firmware geometry/actions.

## Bottom test and callback row

Test panel: Try your draft heading, text output field and right-aligned blue
Prepare Test button. Reference sample: Hello, Grüß dich! The real implementation
must show prepared/running/stale state and Start/Stop controls when relevant.
Expandable test details show emitted actions/layers, timing and diagnostics;
retain the compact default composition. Input uses virtual keys or mapped host
positions; text reflects simulated processor output translated through EurKEY.

Callback panel: Callbacks heading, status dot and filename/attachment state,
Open externally control, relative path and short secondary description. Show
source mismatch or compiler errors here with access to full diagnostics. Opaque
Zig code is not converted into visual action forms. Longer filenames truncate
with full text available on focus/hover; do not overlap the external-editor button.

## Required states and resizing

Design and capture: normal selected layer/key, multi-selection, layer add/rename,
deletion constraint, combo editor, advanced action form, dirty project, no device,
wrong device/profile, validation error, callback missing/changed, test preparing,
running/stale/failed, and build/flash progress in 08. Preserve the hierarchy and
use inline messages or bounded drawers rather than unplanned full-screen views.

At the reference viewport, all default panels remain visible without scrolling.
User amendment, 2026-10-05: replace whole-canvas scrolling with automatic window
scaling. Start at 1152 × 768 and support resizing down to 900 × 600, preserving
panel proportions and scaling text, dialogs and click targets together. Long
lists and forms retain local scrolling. Check panel visibility and semantic
interaction at the smaller sizes on Retina and non-Retina renderers.
The editor uses a normal opaque window; overlay opacity and
always-on-top behavior do not carry into the editor.

## Visual verification implementation plan

Current environment inspection: macOS 26.6.2; built-in `screencapture` and `sips`
exist. No desktop automation connector is available in this session. Browser
preview tools do not inspect the native SDL window. The current GUI only has
the overlay and three-frame smoke mode; editor capture/scenario APIs do not yet
exist. Do not claim a comparison has already run.

Preferred 07B tooling is app-owned Zig offline fixture/scenario support. Load a
fixed project and fake connection, deterministic clock, selected layer/key and
known input-source fixture; use repeatable window size, font, scale and theme.
Capture after layout/render stabilization through the pinned SDL backend's
`readPixels` API. Its implementation calls SDL_RenderReadPixels. Verify readback
timing and output ownership against this exact renderer. Encode/save image data
in Zig using retained dependencies where available; add no first-party language.
Never access HID, flash, invoke callbacks or select a live source implicitly in
the screenshot fixture. Save generated captures/comparisons in build caches.

Expose test-owned semantic action IDs and control rectangles so a Zig scenario
runner can exercise selection, layer operations, form edits and focus using
application events. Geometry assertions should check panel bounds, clipping and
selected controls. This does not replace native focus/dialog/accessibility tests.
A later native desktop automation helper is optional; no installation is needed
to begin app-owned capture/scenario work.

For end-to-end native window checks, macOS `screencapture -l <window-id> -o`
can capture the selected application window. Obtain/verify the correct window ID;
do not capture unrelated desktop contents. Screen Recording permission may be
required for the process responsible for capture. Native synthetic mouse/key
automation may additionally need Accessibility permission. Identify that process
when requested by macOS rather than guessing T3/terminal permission is sufficient.
Permissions and desktop interaction have not been tested in this planning task.

Comparison process:

1. Render the reference fixture at normalized 1536 × 1024 content pixels with
   fixed scale/fonts. Capture dark and light separately and record exact settings.
2. View reference and actual image together; compare toolbar, sidebar, canvas,
   inspector, OS viewer and bottom row individually. Produce a concise mismatch
   list with measured bounds/color/text differences and concrete fixes.
3. Use a Zig-generated overlay/difference artifact when useful. Initial generated
   mockup comparison is perceptual plus geometry, not a zero-difference pixel
   test: generated typography, symbols and native decoration differ. Aim for
   panel edges/gutters within roughly 4 px at the reference size; record intentional
   correctness/accessibility deviations explicitly. This is a target tolerance,
   not evidence of current fidelity.
4. Once the user accepts implemented screenshots, explicitly approve those as
   golden images for automated regression checks. Keep separate goldens per
   theme, viewport and scale; account for text antialiasing. No automatic golden
   refresh that hides a layout regression.
5. Verify interaction scenarios and native focus/close/resize/dialog behavior,
   including fake telemetry continuity. Native EurKEY labels/composition need
   their separate real-input-source acceptance. Report visual and functional
   evidence separately; a screenshot alone cannot prove behavior.

Sources inspected 2026-10-04:
[pinned SDL readback implementation](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/backends/sdl.zig),
[SDL_RenderReadPixels](https://wiki.libsdl.org/SDL3/SDL_RenderReadPixels),
[Apple screen recording permissions](https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac).

## Acceptance and scope

07B supplies actual dark/light captures, region-by-region comparison, measured
layout results, interaction checks, accessibility/navigation results actually
performed, and explicit deviations. 08B preserves the accepted composition while
adding jobs/device states. The user requested close recreation: material visual
departures need concrete comparison and review, not silent reinterpretation.
This task creates the specification only; no production code or capture tooling
is implemented here.
