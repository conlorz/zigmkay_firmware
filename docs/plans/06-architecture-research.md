# 06A: editor architecture research

State: Accepted 06A research; provisional recommendation. Inspected 2026-10-04.
Repository input: `ab66f12`; dispatch record: `ed14722`. This is a source audit,
not a browser, OS integration, packaging, performance, or hardware test.
No spike, new dependency, source implementation, or device operation was performed.
G06 remains pending accepted 03/04/05 and the separate 06B decision.

## Provisional recommendation and smallest scope

Extend the existing Zig DVUI/SDL3 companion with a separately opened editor
window. Keep the small monitoring overlay as the normal live view. First freeze
a UI-independent versioned document/export contract in 07A; then implement
07B forms and 08A build/flash backend against it. This recommendation follows
existing native APIs, shared model reuse and local tool access, rather than only
the user's preference. It is conditional on actual 05 actions and macOS window
behavior. Do not start 07/08 or revise their contracts from this early document.

Preserve browser export as a later consumer of the same document contract.
Defer a permanent local browser service: it duplicates frontend/session and
packaging work without removing the native Zig tool installation. Defer direct
browser device/flashing integrations: they neither replace current UF2 copying
nor provide a Safari-compatible monitoring path. These are deferred alternatives,
not evidence that a browser editor is impossible.

## Repository and pinned API audit

Repository links below identify inspected paths at the input revision. Protocol
and model code is being revised by 01; the final editor must consume its accepted
handover rather than treating this baseline audit as a frozen protocol API.
Coordinator integration finding during this research: macOS SDL HID output writes
use IOHIDDeviceSetReport, while the pinned MicroZig HID SetReport path acknowledges
without consuming payload and its core ignores endpoint-zero OUT. This finding
was supplied by the coordinator, not independently hardware-tested here. The
02/03 work must close that transport gap before live acceptance; available host
HID APIs alone do not prove bidirectional monitoring/control works.

| Area | Inspected evidence | Reuse and constraint |
| --- | --- | --- |
| Companion | [main](../../zigmkay-companion/src/main.zig), [package build](../../zigmkay-companion/build.zig) | Zig immediate-mode UI, host SDL3 backend, label cache and UI-thread reduction. Existing window is 1600×1000; it is not yet a small overlay/editor design. Current live handling lacks accepted recovery. |
| Geometry | [physical model](../../layout-model/src/physical_layout.zig), [LK7 geometry](../../keyboards/my_keyboards/rollercole/lk7_physical_layout.zig), [legacy GUI layout](../../zigmkay-companion/src/components/layout.zig) | Stable physical ID/index, position/size/rotation, hand/group and validators exist. GUI currently derives positions from legacy side tags. Reuse physical geometry for selection and preview; do not infer physical layout from logical actions or edit GPIO mappings. Geometry is schematic, not measured hardware evidence. |
| Actions | [types](../../layout-model/src/types.zig), [callback ABI](../../zigmkay/src/core.zig), [reference keymap](../../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig) | Typed action values are portable; callback implementation is arbitrary Zig with state and effects. See preservation boundary below. |
| Selection/build | [root build](../../build.zig), companion package build | Both import the Rollercole keymap by fixed path today. Board selection exists; shared selectable profile/export build ownership is future 05/07 integration. Do not invent an existing `-Dprofile` command. Root has portable Wasm object checks; these are not a browser application. |
| Flasher | [Zig tool](../../zig-flash/src/main.zig), [README](../../zig-flash/README.md) | Explicit source argument, volume label/absolute path, platform mount discovery, wait and UF2 copy exist. Label traversal validation exists. No bounded wait/cancellation, UF2 family/board verification, ambiguous-drive chooser, artifact manifest, reboot/identity acceptance or GUI progress API exists. A copied file is not acceptance. |
| Native labels | [zkeymap](../../zkeymap/src/root.zig), [platform code](../../zkeymap/src/platform/macos.zig) | Host input-source labels belong to native platform adapters. A browser cannot directly reuse macOS input-source lookup; browser preview must use explicit layout metadata or a local service. EurKEY labels do not change HID actions. |

The companion pins DVUI `9b372ab0e3beca5060eb1f9ffe3e83ee61665e37`,
version `0.5.0-dev`, with immutable hash in
[its manifest](../../zigmkay-companion/build.zig.zon). The cached package at that
hash was read directly. Its manifest pins SDL3's Zig build wrapper
`allyourcodebase/SDL` revision `0a9d5c36488aad32fcf989d465eb879db6e356b4`
(hash label `sdl-1.0.3+3.4.16`). The nested SDL archive was not separately audited;
that hash label is dependency metadata, not a runtime SDL version measurement.

Pinned upstream source references:

- [DVUI widgets/API](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/dvui.zig): `button`, `checkbox`, `dropdownEnum`, `textEntry`, `textEntryNumber`, `slider`, dialogs and drawing support action inspectors, layers and status/error presentation. These provide primitives, not an existing keymap editor or undo model.
- [OS windows](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/widgets/OsWindowWidget.zig) and [SDL backend](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/backends/sdl.zig): `dvui.osWindow` and `initWindowSecondary` support an OS child window, with floating fallback and a default five-window bound. Implementation has fixed initial positioning and error paths that panic. Verify focus, independent close, event routing and failure behavior before promising a production two-window UX.
- [Native dialogs](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/native_dialogs.zig) and [dependency build](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/build.zig): native open/save helpers use existing upstream tinyfiledialogs, block and are not thread safe. Desktop SDL3 defaults enable them. Calling them on the UI thread would pause HID polling. Prefer existing SDL3 asynchronous dialogs via Zig bindings, or isolate/serialize the blocking helper with a tested result queue; do not expand C bridges.
- [Accessibility](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/readme-accessibility.md): AccessKit supports macOS/Windows/Linux SDL3 according to the pin; default build option is off and the companion does not enable it. It is an existing optional upstream dependency, not a claim that this GUI is accessible. Web AccessKit is unavailable in this pin. Labels, focus order and real screen-reader checks remain application work.
- [Web backend](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/backends/web.zig) and [JS host](https://github.com/david-vanderson/dvui/blob/9b372ab0e3beca5060eb1f9ffe3e83ee61665e37/src/backends/web.js): a Zig canvas UI can use upstream JS host glue and upload/download hooks. This is not DOM form accessibility, a local process API or ready WebHID bindings. Retaining an upstream dependency is allowed; writing new first-party JS/HTML/CSS or modifying such glue needs explicit user permission.

Zig 0.16.0's installed standard library was inspected at
`/Users/clorz/.zvm/0.16.0/lib/std/`: `zon/parse.zig` provides `fromSlice` and
`fromSliceAlloc` with unknown-field rejection by default; `zon/stringify.zig`
provides serialization; `process.zig` has `spawn`, `spawnPath` and `run` using
`std.Io`; `process/Child.zig` has `wait` and `kill`. Thus document parsing and
native process control do not require another first-party language. Do not use
older `std.ChildProcess` examples. PATH's `zig env` resolved version 0.15.2 during
research; the coordinator was notified to use the explicit 0.16.0 toolchain.
No build was invoked with that PATH binary.

## Current primary platform sources

All sources in this section were fetched on 2026-10-04. No browser was launched,
no exact installed browser/OS version was tested, and no supported-version floor
for this product is established. Upstream availability is not product validation.
Some vendor documentation has old publication dates; these are current retrieved
pages, not a claim of freshly published API changes.

| Capability | Official evidence | Consequence |
| --- | --- | --- |
| WebHID | [Chrome guide](https://developer.chrome.com/docs/capabilities/hid), [WICG spec](https://wicg.github.io/webhid/) | User-selected permission and protected collections apply. Keyboard/mouse collections are blocked; a vendor telemetry collection may be usable, subject to actual descriptors/blocklists/OS permissions. macOS is listed among Chrome desktop support. This does not establish LK7 compatibility. |
| Safari HID/USB | [WebKit policy](https://webkit.org/tracking-prevention/) | WebKit explicitly lists WebHID and Web USB among APIs it has not implemented. Do not require direct browser device access for Safari users. |
| WebUSB | [Chrome guide](https://developer.chrome.com/docs/capabilities/usb), [WICG spec](https://wicg.github.io/webusb/) | Secure context and a user gesture are required for requesting a device. Access targets permitted USB interfaces, not a generic mounted-file copy interface. Replacing UF2 copying with a boot-ROM/vendor protocol requires a new, separately validated implementation. OS ownership may prevent interface claiming. |
| User-visible files | [Chrome File System Access guide](https://developer.chrome.com/docs/capabilities/web-apis/file-system-access), [WebKit local-files position](https://github.com/WebKit/standards-positions/issues/28) | Chromium picker support on macOS does not establish Safari support. Pickers require secure context/user action and permission. Upload/download fallbacks support exchange but do not guarantee overwrite. Origin-private storage is not the user's exported file or a BOOTSEL volume. |
| Wasm sandbox | [WebAssembly FAQ](https://webassembly.org/docs/faq/) | Wasm interacts with its host through imports and follows browser security rules. A Zig Wasm model cannot directly invoke the locally installed Zig compiler, native HID adapter or arbitrary filesystem paths. Native service/manual CLI remains required for the current build workflow. |
| UF2 | [Raspberry Pi C SDK documentation](https://www.raspberrypi.com/documentation/microcontrollers/c_sdk.html) | RP2040 BOOTSEL presents mass storage and accepts UF2 copying followed by reboot. Monitoring vendor HID and bootloader mass storage are different sessions. The general RP2040 procedure is not LK7-specific test evidence. |
| Native file picker | [SDL3 open dialog](https://wiki.libsdl.org/SDL3/SDL_ShowOpenFileDialog), [save dialog](https://wiki.libsdl.org/SDL3/SDL_ShowSaveFileDialog) | Asynchronous SDL3 dialogs exist since 3.2.0. Initiate on main thread, retain callback inputs, copy results and marshal to UI because callbacks can arrive on another thread. Cancellation and failure differ. Linux may require XDG portal/DBus event pumping. |
| macOS distribution | [Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) | Public distribution adds signing/notarization work. This local fork only needs identified local artifacts now; an app bundle, signing credentials and distribution are not assumed or performed. |

Browser device access is not required for a browser editor backed by native HID
in a local Zig service. That avoids the Safari HID restriction at the cost of a
service protocol, lifecycle and local installation. A browser export editor can
avoid hardware APIs completely. A Chromium user-approved save to a mounted
volume is conceptually a file operation, but unreliable suitability of special
bootloader volumes, picker behavior and disconnect during copy must be tested;
it cannot be presented as existing browser flashing support.

## Comparison

Each cell is either demonstrated source capability or a proposed consequence of
that capability. None reports UI/hardware acceptance.

| Criterion | Native companion | Browser + local Zig service | Browser export only |
| --- | --- | --- | --- |
| Zig-only implementation feasibility | Existing UI, parsers and process APIs permit first-party Zig. Retain upstream bridges. | Zig service feasible. Server-rendered forms generated in Zig could avoid authored JS but offer limited interaction; Wasm canvas can reuse upstream host. Rich new host glue requires permission. No service/frontend exists here. | Zig Wasm validation/export feasible; upstream host/UI can be reused. Browser bootstrap/save integration still needs scoped packaging or language permission. |
| macOS UI and packaging | Existing executable/backend. OS child window available but untested. Local toolchain still needed for compilation. | Native service plus browser, origin/port/lifecycle installation and bundled assets. Browser UI does not supply overlay behavior. | Bundled/offline browser assets plus a separate installed CLI/toolchain. No integrated small overlay. |
| Reuse of monitoring/state model | Direct in-process reuse of accepted 01/03 model and native labels; simplest single owner of HID. | Portable model may remain in service or Wasm; new transport and identity/version boundary. Retain companion overlay/native labels. | Reuse document/geometry only initially; live overlay remains native and separate. |
| Save/load and custom-action preservation | Zig typed format and native files. Losslessness requires callback registry/bundle below. | Same Zig schema backend; UI transport cannot serialize function pointers. Native service can own files. | Same schema in Wasm; upload/download fallback and callback bundle required. Browser private storage alone is insufficient. |
| Local compilation/error reporting | Native worker process, argv and captured output. Async design needed so telemetry continues. | Service invokes same native backend; bounded authenticated job API required. Browser cannot spawn local compiler. | Manual local CLI produces UF2/diagnostics; no one-click current local compiler integration. |
| Deliberate flashing/device selection | Extend native backend with selected artifact/device, cancellation and post-reboot identity. Existing flasher insufficient. | Native service does transfer; browser permission is not a substitute for deliberate artifact/device confirmation. | User manually transfers verified UF2; browser downloads keymap, not automatically ready firmware. |
| Offline operation/maintenance | Local UI and cached/pinned build deps; first uncached build may need network. One native app/model. | Local static assets/service can work offline; more protocol, origin and update coordination. Hosted assets are not offline by default. | Local assets can work offline; separate compiler/flash instructions and downloads need version coordination. |
| Later Windows/Linux | SDL3/upstream accessibility and existing native adapters provide starting points; label permissions, dialogs and mount discovery need real validation. | Same native backend platform work plus browser/local networking policy. Browser does not eliminate HID/volume OS differences. | Portable editing is plausible; local CLI/device instructions remain platform specific. |

## UI-independent action and callback preservation boundary

A candidate document is versioned typed ZON, parsed as data with bounded input,
not imported/executed as Zig source. 07A must choose exact schema/API and resource
limits after G05. Reuse accepted profile identity/digest; do not create an editor
identity competing with the protocol contract. Carry board/profile/physical
layout identity, layers, logical actions, combos, encoder actions and callback
binding metadata. Save/reopen retains logical data; generated Zig is a build
output, not the authoritative editable document. Preserve original profile source
and generate to a new owned path/cache only through explicit export/regeneration.

The baseline representable values are:

- Optional cell `null` and `KeyDef.none` remain distinct, as confirmed in
  [processor lookup](../../zigmkay/src/processing.zig); do not silently collapse
  transparent/fallback semantics into explicit no-action.
- All five union tags: none, tap-only, hold-only, tap-hold and tap-with-autofire.
- Every `TapDef` field: key press (u8 code, eight modifier bits and dead flag),
  optional one-shot hold, custom u8 ID, media enum and mouse enum. These are
  multiple optional fields, not an exclusive single-choice union; retain
  simultaneous fields supported by the processor instead of losing them.
- Hold modifiers, optional layer and custom ID; tapping term, retro tapping,
  autofire initial delay/repeat interval; two-key combos with order/index/layer,
  timeout and complete action; encoder tap actions. Preserve timing and IDs.
- Existing IDs are `KeyIndex=u7`, `LayerIndex=u4`, time milliseconds `u16`.
  Dimension counts share the narrow types, so do not promise 128 keys/16 layers
  as representable counts merely from array capacities. Existing validators check
  finite positive geometry, key identity/index uniqueness, layer references and
  combo indices; they do not settle all custom-ID, timing or action semantics.

The baseline reference callback updates global left/right-held state, activates
combined/navigation/number layers, retains modifiers for Alt-Tab, switches gaming
layers and emits different punctuation according to modifiers. `CustomFunctions`
contains an optional function pointer receiving processor event, layer state and
output queue. A custom u8 ID identifies a trigger, not its implementation.
Serializing that ID alone loses behavior; parsing arbitrary Zig into visual forms
is not a supported route.

Proposed bounded preservation options, to be selected in 06B/07A:

1. Registered callback module: document carries a stable allowlisted binding ID,
   immutable module revision/digest and available custom-ID names/parameters.
   Export resolves that trusted existing Zig module unchanged. Visual edits may
   change supported data while callback semantics remain read-only. Missing or
   mismatched module fails export/build, never substitutes a no-op.
2. Lossless bundle for advanced source: preserve the user's Zig callback module
   bytes and digest separately beside the typed document; reopen/export carries
   them unchanged with an explicit opaque-source label. No automatic parsing,
   normalization or execution during load. Compiling arbitrary bundled source is
   a trusted local build decision, not mere data validation. Only offer this if
   05 genuinely needs it and path/import ownership is specified.
3. Unsupported callback profile: keep source/reference available and display an
   explicit unsupported/edit-disabled reason. Never offer an apparently successful
   export that drops logic. An MVP may support only registered known callbacks.

Unknown schema versions/fields/actions should fail visibly without overwriting
the input. If a later schema chooses opaque forward-compatible preservation,
it must prove those bytes survive before allowing save; ignoring unknown fields
is not preservation. Define allocator/file-size/collection/string limits, invalid
ID and zero-timing policy, save atomicity, migration and deterministic output in
07A. Meaningful tests should compare behavior/data before and after save/reopen/
export, callback mismatch rejection and root/standalone build agreement.

## Proposed native boundaries for later planning

07A owns document validation/save/load/export and callback binding resolution,
independent of GUI. 07B consumes it for physical-key selection, layer navigation,
action inspectors, editable timing/modifier fields, dirty state, undo, preview and
explicit save/export. Offer searchable action labels and keyboard selection/tab
order; don't require pointer-only geometry interaction. Keep host label preview
separate from HID codes and show unsupported opaque callback semantics clearly.
Add geometry editing only if actual profile requirements justify it; initial
geometry may remain board-owned read-only placement.

08A owns a fake-tested Zig process/artifact/volume backend. Invoke explicit Zig
0.16.0 with argument arrays and selected board/profile, never a shell command
assembled from document content. Freeze inputs and produce artifact metadata
including accepted identity, source/profile digest, board, compiler and UF2 hash.
Capture bounded stdout/stderr, cancellation, exit status and actionable errors.
A failed build must never make an old artifact eligible as if it were current.
Compilation stays separate from Flash. Offline operation requires cached immutable
dependencies; avoid claiming first-time compilation is network-free.

08B integrates jobs without blocking UI/HID reduction. Backend results cross a
bounded queue; document/model changes remain UI-owned. Validate candidate volume
and UF2 family/board compatibility, handle multiple candidates and finite waits,
show selected target/artifact and deliberate user confirmation, then verify
running identity after reboot through accepted monitoring. Volume label alone is
not a board identity; UF2 family identifies an MCU family rather than an LK7
profile. Handle permission/copy/disconnect failures without claiming success.
Use fake processes/volumes for default tests. Real transfer and identity checks
remain an explicit user session. No autonomous BOOTSEL request is authorized.

A service alternative should reuse that backend rather than recreate build logic.
If chosen later, bind loopback only, validate Host/Origin, require a session token
for state-changing requests, disallow arbitrary commands/paths, enforce payload
and job bounds, and model lifecycle/cancellation. These are concrete design costs,
not implemented security claims. Serving UI and API from one local origin reduces
cross-origin policy complexity but still needs actual browser testing.

## Remaining evidence and 06B gate

No spike is necessary to submit this bounded comparison. Documentation establishes
native forms/windows/processes and browser constraints. It does not establish
multi-window focus, screen-reader usability, packaging, editor performance or
browser bootloader-volume writes. Request an assigned Zig offline spike only if
one of those uncertainties becomes decisive; do not implement a full editor here.

Before final decision: consume accepted 03/04/05, enumerate actual profile callback
requirements, reconcile live identity and host labels, and select the exact schema
and callback preservation policy. Verify native child-window close/focus and
asynchronous dialogs while monitoring with offline/fake transport; review failure
paths before production integration. Test VoiceOver/tab order if accessibility
is claimed. A browser alternative additionally needs exact browser/OS versions,
feature detection, offline asset serving and an explicitly authorized host-code
strategy. Direct device tests remain separate user-authorized hardware work.

The coordinator can accept 06A as research input. It cannot accept G06 from this
document alone. Final 06B must specify chosen dependencies, exporter path/API
ownership, UI/backend split, supported actions, limits and concrete 07/08 plan
revisions. Another first-party language or material workflow change requires the
user's concrete decision before that implementation.
