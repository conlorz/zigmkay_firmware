# 05: Compiled LK7 QWERTY profile for EurKEY Next on macOS

Status: planned. Depends on 04. The user has selected EurKEY Next, QWERTY
letters, and Mac shortcuts. This profile must be usable before the editor exists.

## Outcome and references

A named, selectable LK7 profile that produces QWERTY letters and intended
symbols/shortcuts on the user's Mac with EurKEY Next selected. Preserve the
Rollercole Danish profile as a separate, buildable reference and rollback option.

Verified on 2026-10-04:

- Source: [felixfoertsch/EurKEY-Next](https://github.com/felixfoertsch/EurKEY-Next).
- Installation: [Homebrew eurkey-next](https://formulae.brew.sh/cask/eurkey-next).
  The [cask metadata](https://formulae.brew.sh/api/cask/eurkey-next.json) downloads
  releases from that repository.
- The bundle includes EurKEY Next and historical EurKEY variants. Target the
  user's selected **EurKEY Next** input source; do not silently use v1.2/v1.3/v1.4.

These are reference links, not a new vendored dependency. Do not clone the
repository into this workspace or run its non-Zig development scripts. If layout
data is needed for deterministic fixtures, record the immutable source revision,
selected layout file, provenance, and applicable license before importing it.

## Inspect first

Read `keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig`, the LK7 board
entry point and physical layout, `keyboards/build_api.zig`, root `build.zig`,
`zigmkay-companion/src/lk7_keymap.zig`, and `zkeycodes` modifier/layout definitions.
The firmware and companion currently use fixed imports; profile selection must
reach both without introducing two independently maintained keymaps.

## Work

1. Record the installed EurKEY Next version, input-source display name/ID, and
   macOS keyboard identification behavior for this LK7. Verify ANSI/ISO handling
   against actual HID usages; physical board shape alone does not select it.
2. Prepare a reviewable 34-key diagram and layer/action tables. Letters become
   QWERTY. Propose concrete thumb, number, symbol, navigation, and modifier
   assignments; ask the user about those assignments before implementing them.
   Keep the four-layer structure initially if it meets the user's needs.
3. Separate physical positions, USB HID usages, and host character translation.
   Regular letters use the appropriate QWERTY HID usages. EurKEY Next supplies
   host Option/dead-key behavior. The existing QMK-derived `us_international`
   constants are not a verified Mac/EurKEY Next mapping.
4. Specify Command-based shortcuts for copy/paste/cut/undo/select-all, relevant
   navigation, and access to Control/Option/Shift. Preserve Option access for
   accents/symbols. Distinguish shortcut chords from direct-character macros;
   verify left/right modifier behavior and clean modifier release.
5. Identify existing combos/custom callbacks that should be retained, adapted,
   or omitted in the new profile. Do not copy Danish-specific symbol macros or
   hidden BOOT combinations without documenting the resulting behavior.
6. Add a single validated profile selector to root and standalone LK7 builds,
   shared with GUI/headless selection and identity metadata from 01/02. A proposed
   option is `-Dkeymap=<profile>`; decide its exact spelling during implementation.
   Diagnose unsupported board/profile combinations before compilation proceeds.
7. Keep GPIO mapping, physical key indices/IDs, scanning, and telemetry unchanged.
   Derive profile identity from canonical keymap data plus declared custom-action
   revisions. Show clear mismatch status when firmware and companion profiles
   differ; never display the new labels over an old flashed profile silently.
8. Document separate steps to select the host input source, build the matching
   firmware/companion, and manually flash. Do not install/switch the user's
   system input source automatically. Prepare identified artifacts and rollback.

## Acceptance

- Zig tests cover all physical-index assignments, QWERTY letter usages, intended
  shortcut modifiers, layer reachability, and modifier release after macros.
- Symbol/dead-key fixtures reference the selected EurKEY Next data/version;
  deterministic checks do not assume the developer's active native input source.
- Both profiles build, have distinct identities, and match root/standalone UF2s
  for the same configuration. All other board builds and `check-full` still pass.
- In an explicitly started hardware session, the user manually flashes and
  verifies letters, digits, punctuation, coding symbols, desired accents,
  Command shortcuts, navigation, and layer transitions. Record the expected and
  actual results against a concrete worksheet.
- The compact overlay shows the selected profile, correct physical positions,
  and native labels; disconnect/recovery remains accepted after the new flash.

## Commit checkpoints and handoff

Commit shared profile selection and identity tests; commit the reviewed new
profile/action tables; commit deterministic mapping tests and user instructions;
then record manual acceptance and fixes in focused local commits.

Handoff supplies a usable profile, its build selector, reference diagrams,
symbol expectations, and a hardware report. Editor implementation, runtime
remapping, and automatic flashing are outside this milestone.
