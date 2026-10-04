# 06: Research the visual editor architecture

Status: planned. Depends on a stable live baseline; use 05's concrete profile
requirements. The current preference is extending the native companion.

## Outcome

An evidence-backed choice of editor architecture and a bounded implementation
specification for 07/08. Thorough research is required before treating either
native or browser editing as the selected approach.

## Required investigation

1. Audit the current DVUI/SDL3 companion, portable layout model, build/profile
   selection, and Zig flasher. Identify what can be reused for editable geometry,
   action inspectors, save/export, file dialogs, subprocesses, and status/error
   presentation. Check pinned APIs, not assumed framework capabilities.
2. Compare at least these alternatives: native editor in the existing companion;
   browser UI backed by a local Zig service; browser/offline editor that exports
   files for a separate local build/flash workflow. Include a Zig/Wasm path where
   practical, without presuming a JavaScript implementation is authorized.
3. Research current official browser/macOS support for HID/USB, file access,
   local build execution, and flashing. Capture source links, inspection date,
   tested browser/OS versions, and concrete restrictions. Native HID monitoring,
   UF2 volume copying, and browser device APIs are different capabilities.
4. Evaluate the editing format independently of the UI. A versioned typed ZON
   format is a candidate because validation/code generation can stay Zig.
   Determine which current actions are representable and how custom Zig
   callbacks remain lossless. Never claim arbitrary Zig source can round-trip
   through a visual editor without a supported representation.
5. Compare build/flash ownership: companion subprocesses, local service, or manual
   export. Assess offline use, device permissions, selecting the correct board,
   recovery from failed builds, and integration with accepted live monitoring.
6. Check usability for a small overlay plus a separate editor window: keyboard
   geometry, layers, action forms, shortcuts, preview, and accessible navigation.
   Identify performance, native packaging, and future Windows/Linux costs.
7. Produce a minimal technical spike only where reading documentation cannot
   settle a material uncertainty. Keep first-party spikes Zig and offline by
   default. Any new implementation in another language needs explicit user
   permission before it is written or executed. No live device or flash tests
   are part of the research task without a separate hardware session.

## Decision record

Write a repository document with the following comparison and a recommendation:

| Criterion | Native companion | Browser + local Zig service | Browser export only |
| --- | --- | --- | --- |
| Zig-only implementation feasibility | Evidence required | Evidence required | Evidence required |
| macOS UI and packaging | Evidence required | Evidence required | Evidence required |
| Reuse of monitoring/state model | Evidence required | Evidence required | Evidence required |
| Save/load and custom-action preservation | Evidence required | Evidence required | Evidence required |
| Local compilation and error reporting | Evidence required | Evidence required | Evidence required |
| Deliberate flashing and device selection | Evidence required | Evidence required | Evidence required |
| Offline operation and maintenance | Evidence required | Evidence required | Evidence required |
| Later Windows/Linux support | Evidence required | Evidence required | Evidence required |

Do not fill the table with guesses or use the user's current preference as a
substitute for evidence. Explain decisive tradeoffs, unknowns, prototype results,
dependency changes, and the smallest useful scope. If the recommended route
requires another language or materially changes the agreed native workflow,
bring that concrete choice to the user before dependent implementation.

## Acceptance and commits

Complete when sources and spikes settle the material questions, the recommendation
is explicit, supported actions/schema are described, and 07/08 can be revised
into concrete tasks for the selected route. Record alternatives deferred and
reasons, rather than silently removing them from future plans.

Commit research notes and source references; commit any necessary Zig spike with
appropriate offline checks; commit the architecture decision and adjusted plans.
Do not add a permanent browser service, vendor an entire UI framework, or start
the full editor while the architecture decision remains unresolved.
