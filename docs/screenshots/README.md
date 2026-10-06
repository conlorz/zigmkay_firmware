# Native application screenshots

Captured from the macOS DVUI/SDL editor at the 1536 × 1024 reference size,
using its isolated offline EurKEY project fixture. Implementation: `10a9c2a`.

- `editor-dark.png`: `dark-1x-normal.png`.
- `editor-light.png`: `light-1x-normal.png`.
- `practice.png`: `dark-1x-practice_guidance.png`.

The source captures are produced by `mise //zigmkay-companion:editor-check`
in `.zig-cache/editor-acceptance`. These README illustrations are separate
from the explicitly approved regression goldens in `docs/plans/goldens/07-editor`.
They do not replace those baselines or claim live device or accessibility
acceptance. Fonts are read from the host and are not bundled here.
