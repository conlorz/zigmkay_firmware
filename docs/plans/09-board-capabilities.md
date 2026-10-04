# 09A board capabilities

Inventory date: 2026-10-04; inspected source baseline `ab66f12`. Names and flags
come from [boards.zon](../../keyboards/boards.zon), not historical sibling repos.
All ten entries use the [publisher](../../keyboards/build_api.zig)'s Raspberry Pi
Pico target (RP2040); actual PCB/controller variants are unverified. Baseline
[roadmap](README.md) records ten-board compilation. This worker ran no firmware
build and no device operation. No board has current milestone live acceptance;
LK7 is the first planned live target and the only hardware the user reports owning.
All other hardware availability is unknown.

GPIO numbers below are source configuration, not measured wiring. Matrix sizes
are scanner column/row arrays, not physical geometry. Nullable mappings identify
which half supplies an input. All matrix sources use col2row; full index-to-pin
mappings remain authoritative in their linked source.

| Catalog ID / entry source | Logical keys / layers | Wiring and split transport | Encoder | Geometry / actions |
| --- | --- | --- | --- | --- |
| [clacky_chan](../../keyboards/my_keyboards/rollercole/clacky_chan.zig) | 30 / 4, shared 28_1 | 1×15 each half; col GPIO6, rows 7,8,9,12,13,14,15,16,21,23,20,22,26,27,10; UART0 TX0/RX1 9600; GPIO19 detects primary (right mapping) | None | No physical metadata; shared custom actions/combos/sides |
| [lk1](../../keyboards/my_keyboards/rollercole/leonardo_keycaprio_0_1.zig) | 30 / 4, shared 28_1 | Unibody 5×6; cols 20,23,21,7,8; rows 27,26,22,4,5,6 | None | No physical metadata; shared custom actions/combos/sides |
| [lk2](../../keyboards/my_keyboards/rollercole/leonardo_keycaprio_0_2.zig) | 30 / 4, shared 28_1 | Unibody 12×8; left cols 2,3,4,8,9,13 / rows 7,12,6,5; right cols 29,28,27,23,21,26 / rows 20,16,22,15 | None | No physical metadata; shared custom actions/combos/sides |
| [lk6](../../keyboards/my_keyboards/rollercole/leonardo_keycaprio_0_6.zig) | 34 / 4, shared 3x5_2 | Unibody 14×6; main left cols 2,3,4,8,9 and thumbs 5,13 / rows 7,12,6; right cols 29,28,27,23,21 and thumbs 26,15 / rows 20,16,22 | None | No physical metadata; shared custom actions/combos/sides |
| [lk7](../../keyboards/my_keyboards/rollercole/leonardo_keycaprio_0_7.zig) | 34 / 4, shared 3x5_2 | Unibody 10×8; scanner cols right 29,28,27,23,21 then left 2,3,4,8,9; rows right 20,16,22,26 then left 7,12,6,5; source mapping preserves this order | None | Only explicit [physical layout](../../keyboards/my_keyboards/rollercole/lk7_physical_layout.zig); schematic, not measured; shared custom actions/combos/sides |
| [encoder_demo](../../keyboards/my_keyboards/rollercole/encoder_demo.zig) | 1 / 1, inline | Unibody 1×1 GPIO col0/row1; click GPIO8 declared but not in scanner | One GPIO23/21, sensitivity4; volume up/down | No physical metadata; one key emits code10, encoder separate from key count; no custom callback |
| [tuckytwotimes](../../keyboards/my_keyboards/rollercole/tuckytwotimes.zig) | 30 / 4, shared 28_1 | Direct 15 switches/half, nullable 30-entry arrays; primary UART0 RX1, secondary UART1 TX4, 9600; GPIO19 primary (left) | One/half GPIO27/26; left volume, right codes10/11 | No physical metadata; primary installs shared custom actions/combos/sides |
| [molekula](../../keyboards/my_keyboards/molekula/main.zig) | 38 / 5, own keymap | Unibody 5×8; cols26,27,28,29,1; rows22,20,23,21,9,8,7,6 | Catalog false; GPIO4/5 declarations commented, unused `encoder_pins` references absent accessors | No physical metadata; own custom gaming callback, combos, sides; comments incorrectly mention 40 keys and active encoders |
| [dasbob](../../keyboards/examples/dasbob/main.zig) | 36 / 3, own keymap | Direct18/half; primary UART0 RX1, secondary PIO TX1 9600; GPIO19 primary (left) | None | No physical metadata; no combos/custom/sides installed; tap-hold/layer/media actions |
| [yak](../../keyboards/examples/yak/main.zig) | 30 / 3, own keymap | Direct15/half; primary UART0 RX1, secondary UART1 TX4 9600; GPIO19 primary (left) | One/half GPIO27/26, same action classes as tuckytwotimes | No physical metadata; no combos/custom/sides installed; tap-hold/layer/media actions |

Direct tuckytwotimes/yak left input order is
`5,7,2,15,23,6,8,13,16,20,9,14,21,22,12`; right mapping mirrors the logical
positions. Dasbob left order is `13,28,12,29,0,22,14,26,4,27,21,23,7,20,6,16,9,8`;
right mappings differ and must be consumed from source. Null entries must not
be packed into a new identity/index space.

## Shared boundaries and recovery

All runners use [USB descriptors](../../zigmkay/src/usb_if.zig): VID `FAFA`, PID
`00F0`, manufacturer OpenKeyboardCollective, product ZigMkay, serial `00000001`,
keyboard/consumer/mouse/vendor RawHID plus reset interface. Vendor usage is
`FF31:0074`; these shared values do not distinguish boards, profiles or two
connected keyboards. Only LK7 has catalog `companion=true`; that flag is build
eligibility, not proof of telemetry. At baseline no listed runner attaches a
production telemetry observer sink. Legacy custom RawHID signals are not the
new session protocol. New identity must consume accepted 01/05 contracts.

Profiles are fixed source imports, not runtime or shared build-selectable
profiles. [shared 28_1](../../keyboards/my_keyboards/rollercole/shared_keymap_28_1.zig)
and [shared 3x5_2](../../keyboards/my_keyboards/rollercole/shared_keymap_3x5_2.zig)
contain Danish-based taps, holds, layers, shortcuts/custom callbacks and combos.
Their boot combos are respectively base indices `(23,24),(0,4),(5,9)` and
`(24,25),(0,4),(5,9)`. Molekula installs boot combos `(0,4),(5,9)` on base.
Encoder demo, dasbob and yak install no boot combo. Availability of those actions
in compiled code does not verify physical execution or reset propagation to a
secondary half. Pico ROM BOOTSEL/UF2 is the generic recovery fallback; physical
button accessibility, exact controller and rollback are unknown per PCB.
See [setup/recovery](09-setup-and-recovery.md) before a separately authorized session.

## Ordered gaps and candidate boards

1. B1: obtain accepted LK7/macOS 04/05 evidence and stable identity; validate
   schematic geometry against hardware without changing physical index/GPIO identity.
2. B2: define explicit per-board key/layer/encoder/geometry/profile capabilities;
   no other board inherits LK7's 34-key/four-layer UI. Preserve opaque/custom action
   semantics in the accepted editor schema before editing these keymaps.
3. B3: resolve missing geometry for the nine other catalog entries using verified
   PCB/layout evidence. Source array formatting is insufficient for rotations or
   physical dimensions. Inspect Molekula stale encoder declarations/comments and
   encoder-demo click separately; neither warrants silently activating hardware.
4. B4: split-board work must establish one authoritative primary session, secondary
   event ordering/loss, key and encoder forwarding, reconnect/release behavior and
   host identity. Check GPIO19 primary choice, one-way UART/PIO setup and reset of
   both halves on real hardware. Two USB connections must not create competing sessions.
5. B5: ask the user to choose an available target. LK6 is a candidate for a similar
   34-key unibody mapping; lk1/lk2 test 30-key dimensions; encoder_demo tests a small
   encoder capability; clacky_chan/dasbob/tuckytwotimes/yak test split boundaries;
   Molekula tests 38 keys/five layers. This is a dependency grouping, not a target
   selection or authorization to implement any board.
6. B6: selected child plan must cover pins, imported profile/custom actions,
   geometry, encoder visualization, bounded telemetry, split behavior if present,
   root/standalone artifact parity, recovery/rollback and a device worksheet.
   Keep all ten compiling at the immutable MicroZig pin throughout.

No extra board is selected. New families, wireless, runtime remapping and new C
interop remain outside 09A/09B unless separately scoped by the user.
