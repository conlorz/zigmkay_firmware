# zkeymap

Zig 0.16.0 native keyboard-layout translation. The local `zkeycodes` package
provides definitions and shared `layout-model` types. Fixed-label keys return
the generated keycode label; layout-dependent keys use the active OS layout.

```sh
zig build test
zig build example
```

The public module exposes `KeyMap`, `KeyCodeFire`, `ScanCode`, and `TextResult`.
Initialize a `KeyMap`, call `keyToText`, then deinitialize it. `TextResult.slice()`
returns UTF-8 text; for fixed-label keys, use `isLabel()` and `getLabel()`.
`tap_modifiers` is a nonoptional shared `Modifiers` value, defaulting to `.{}.`
See [the runnable example](example/main.zig).

Existing C interoperability bridges are retained for Carbon on macOS,
ToUnicodeEx on Windows, and xkbcommon on Linux. Linux requires the host
xkbcommon development library. Native translation tests assume a US layout;
platform mapping tables also have pure Zig tests.
