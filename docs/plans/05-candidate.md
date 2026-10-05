# EurKEY Next Mac candidate

Prepared autonomously on 2026-10-05 after the user requested uninterrupted
offline progress. This is an editable candidate, not accepted personal hardware
configuration. The existing Danish, QWERTY and representative EurKEY profiles
remain available. Select **EurKEY Next Mac candidate** in the editor or create
`eurmac` with the project CLI. It uses the existing profile export/build contract.

## Installed host evidence

Read-only inspection found `/Library/Keyboard Layouts/EurKEY-Next.bundle` with
bundle and source version `2026.03.22`. The declared input source is
`de.felixfoertsch.keyboardlayout.EurKEY-Next.eurkeynext`, display name
`EurKEY Next`. This records installation, not the currently selected input source.
The installed `Contents/Resources/EurKEY Next.keylayout` SHA-256 is
`375df632d7114c16d0ed4d7ee07b4441af410e2d85b01b53094feb12995c2bb4`.
No layout file was imported or system setting changed. Upstream revision and
license provenance are required before any later vendoring of layout data.

The XML declares map set `16c` for keyboard types 0–17 and map set `994` for
several other types, with punctuation overrides. The candidate uses ordinary
QWERTY HID usages and US-style shifted punctuation intended for `16c`.
The actual LK7 macOS keyboard-type selection still requires manual verification;
physical split geometry does not establish ANSI/ISO translation.

## Concrete assignments

Physical indices and stable IDs are unchanged. Rows are shown left to right on
each half; slash separates tap and hold. All dual-role keys use 180 ms.

```text
indices  0  1  2  3  4        5  6  7  8  9
         Q  W  E  R  T        Y  U  I  O  P
indices 10 11 12 13 14       15 16 17 18 19
         A  S  D  F  G        H  J  K  L  ;
hold    Cmd Opt Ctrl Shift      Shift Ctrl Opt Cmd
indices 20 21 22 23 24       25 26 27 28 29
         Z  X  C  V  B        N  M  ,  .  /
thumbs       30           31            32             33
          Space/Nav   Tab/Symbols   Enter/Numbers   Backspace/Shift
```

| Layer | Assignments by physical index |
| --- | --- |
| Navigation | 0–4: Cmd+A/Z/X/C/V; 5: Cmd+Shift+Z; 6: Cmd+Tab; 7: Up; 8: Page Up; 9: Escape; 15: Cmd+Left; 16: Left; 17: Down; 18: Right; 19: Cmd+Right; 25: Backspace; 26: Delete; 27: Page Down |
| Numbers | 0–5: F1–F6; 9: F10; 10–14: F11/F12/F7/F8/F9; 6/7/8: 7/8/9; 16/17/18: 4/5/6; 26/27/28: 1/2/3; 25: 0; 19: plus; 29: minus; 24: decimal point |
| Symbols | 0–9: ! @ # $ % ^ & * ( ); 10–14: { } [ ] backslash; 15–19: _ + : double quote ~; 20–24: < > slash minus equals; 25–29: pipe question mark semicolon apostrophe grave |

Unassigned positions transparently fall through. All four thumb positions are
transparent on auxiliary layers, so held layers can always be released and
another layer accessed. Assigned home-row positions on auxiliary layers retain
their corresponding modifier hold. Both Option keys remain available for native
EurKEY accents and dead keys. This candidate does not embed Danish symbol macros,
legacy gaming, callback state, or automatic layer combinations.

Recovery is explicitly Q+T (indices 0+4), with the existing 40 ms combo timeout.
It requests BOOTSEL only when flashed and physically used. Offline runners expose
this as data. There are no other combos. Companion signals and media bindings
are omitted from this initial candidate and can be added in the editor.

## Remaining acceptance

Home-row timing is a provisional choice; native text and personal comfort are
unverified. Command+arrow navigation is application-dependent.
Hardware acceptance must verify the actual keyboard type,
all coding symbols, Option accents/dead keys, modifier release, shortcuts and
overlay profile identity. No new flash or hardware access is authorized by this
document. G05 remains open.

The toolbar hardware evidence at `1c44788` supersedes the old claim that no 08
transfer/reconnect run exists. It verifies Danish-profile build, synchronized
transfer, exact identity and coherent snapshot. It does not claim edited-profile
typing acceptance, current visual approval or full G08 acceptance.

## Offline evidence

Zig 0.16.0 project tests and `zig build check-full -j4` passed, including the
ten-board matrix and default LK7 mise/standalone parity. The candidate project
was created, validated, exported and built separately with
`zig build --build-file keyboards/build.zig firmware -Dkeyboard=lk7
-Dprofile=<absolute export directory> -p <cache output> -j4`.
Root Zig does not accept `-Dkeyboard`/`-Dprofile`; package builds own these options.
The first root invocation rejected those options before building; the corrected
package invocation passed. No profile option was added to mise in this change.

The exported profile's real offline processor trace verified Option activation,
a letter press/release under Option, clean Option release, Navigation activation,
Command+C with immediate clean modifier release, Numbers/Symbols activation and
release back to base. Final state was base-only with zero modifiers.
Transient project/export/runner/firmware/trace outputs are under
`.zig-cache/plan05-candidate-final/`; the editable project is `projects/eurmac/`.
Final telemetry identity is `d3b78b48d64d7c5d4b6b1fce10c91281` and the
candidate UF2 SHA-256 is
`8e31c52441896c82d3ba04add4f76fffb2e9d724f17a5877109978e721948c86`.
The final project suite passed 23/23 tests. Aggregate log is
`.zig-cache/plan05-check-full.log`. These are local cache evidence, not committed
generated sources or live host-character acceptance.

## Manual worksheet for a later authorized session

| Check | Expected | Actual |
| --- | --- | --- |
| Profile identity | Companion matches candidate firmware | Pending |
| Letters | QWERTY, all 26 letters | Pending |
| Thumb taps | Space, Tab, Enter, Backspace | Pending |
| Thumb holds | Navigation, Symbols, Numbers, Shift; release returns to base | Pending |
| Digits/function keys | 0–9 and F1–F12 reachable | Pending |
| Coding symbols | `[] {} () <> = + - _ / \\ \| : ; ' " ~` match selected host map | Pending |
| Mac shortcuts | Select all, undo, redo, cut, copy, paste, app switch | Pending |
| Option/dead keys | Intended native EurKEY accents; no stuck Option | Pending |
| Home-row rolls | Ordinary text causes no unintended holds | Pending |
| Recovery/reconnect | Deliberate Q+T enters BOOTSEL; verified rollback/reconnect | Pending |
