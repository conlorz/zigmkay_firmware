# zkeycodes

Zig 0.16.0 keycode definitions and converter. Shared key and modifier types come
from the local `layout-model` package. `root.zig` exports `layouts`, `core`
(helper functions), and `model` (the shared types).

```sh
zig build test
zig build check-generated
zig build convert-all
zig build convert -- path/to/input.hjson path/to/output.zig
```

Tests generate fixtures in the build cache and compile their semantics.
`check-generated` compares all committed layouts and the export index without
writing sources. Only `convert-all` regenerates `keycodes/` from the sorted
`qmk_imports/*.hjson` inputs. Single conversions validate and format the complete
output before replacing the destination atomically; failed inputs preserve it.
The converter runs on the host even when a firmware target is selected.
