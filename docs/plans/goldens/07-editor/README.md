# Approved editor regression images

The user explicitly approved the linked implemented dark/light screenshots and
both source-density variants on 2026-10-04. These PNGs are that approved fixture,
not the generated design mockups. Four baselines distinguish theme and native
1×/2× readback; each normalizes to 1536 × 1024 content pixels.

Environment: macOS 26.6.2 (25G83), SDL3 through pinned DVUI 0.5,
Zig 0.16.0, installed SFNS plus Arial Unicode fallback. Fixture: EurKEY Next
2026.03.22, Navigation layer 1, physical key index 10, Option preview,
Hello, Grüß dich! text and inert callback attachment. No native title bar,
HID/source execution or system input appears in the fixture.

Run `mise //zigmkay-companion:editor-golden-check` from the monorepo root.
The task captures into build caches and reads these files without modifying
them. It verifies the explicit antialiasing tolerance in
[the guide](../../07-editor-verification.md). Different OS/fonts or desired visual
changes require concrete image review and a new explicit user approval before
replacement. There is deliberately no automatic update command.

| File | SHA-256 |
| --- | --- |
| dark-1x-normal.png | `015d15d63b0c442373717f402f873fd6eb40102db338eca02ed74cc4549aec0d` |
| dark-2x-normal.png | `72f1b7e0ad45d466165a6d81fa57bbc5939e6d01b89e0d81147ffddaf46a4771` |
| light-1x-normal.png | `f1b5b1b822f80658b754fd79b3793b7ac6dac08c42eb29a8f8e1e552031f7c90` |
| light-2x-normal.png | `d78c69c481c36508f3c7681e910174a00742b20edcc30c63ae53ec22a8b1bb09` |
