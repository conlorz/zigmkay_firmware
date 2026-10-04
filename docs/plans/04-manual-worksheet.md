# LK7 manual acceptance worksheet

State: preparation only. No device has been accessed, flashed, or accepted.
Use this worksheet only after G-live-offline and an explicit user hardware
session. Coordinator fills artifact identities from the accepted 02/03 revision.

## Artifact and environment record

| Item | Value |
| --- | --- |
| Integrated source revision / protocol contract | Pending 02/03 acceptance |
| New firmware path / size / SHA-256 | Pending joint build |
| Companion path / source revision | Pending joint build |
| Expected board / profile / digest | Pending shared identity publication |
| Zig | 0.16.0 |
| MicroZig revision | `00fde43fa3756790037b099baeafacc3e6bf9499` |
| Baseline rollback source | `ab66f12`, Rollercole 34-key / four-layer profile |
| Baseline rollback path | `.zig-cache/manual-session/rollback-ab66f12/zigmkay.uf2` |
| Baseline rollback size | 71,168 bytes |
| Baseline rollback SHA-256 | `4924493306b302a7c2019e948ce04c79225c7d08dba1711eafc3cccbc32380e8` |
| Physical LK7 revision / controller recovery procedure | User verification pending |
| macOS version / input-source ID / cable or hub | User session pending |
| Overlay placement / opacity / focus settings | User session pending |

The rollback was freshly compiled offline from the unchanged implementation
baseline. It has no hardware validation in this session. The cache copy is local
and may be removed by cache cleaning; rebuild from its source revision if absent.
Confirm the controller's physical BOOTSEL/reset procedure and board wiring before
manual flashing. Software BOOT combos are not the first recovery method.

## Physical index reference and safe actions

The shared schematic geometry defines rows left to right as follows. Confirm
these positions against the actual device rather than changing GPIO assignments
to fit an assumption.

```text
  0  1  2  3  4       5  6  7  8  9
 10 11 12 13 14      15 16 17 18 19
 20 21 22 23 24      25 26 27 28 29
          30 31      32 33
```

Source: `keyboards/my_keyboards/rollercole/lk7_physical_layout.zig` and
`shared_keymap_3x5_2.zig`. Geometry is schematic, not a measured mechanical model.
Base tap labels are `Q W R P B / K L O U QUOT`,
`F A S T G / M N E I Y`, `Z X C D V / J H COMM DOT Z`,
with thumbs `SPACE ENTER / SPACE I`. Labels describe the Danish-based profile;
actual characters depend on the host input source.

Avoid simultaneous base-layer pairs `{24,25}`, `{0,4}`, and `{5,9}`: all three
are BOOT actions in the current source. Single-key coverage is performed one key
at a time, releasing fully between keys. Safe held-state attach testing can use
key 3 alone. Review custom thumb layer behavior with the source before testing
layer combinations. Do not type into sensitive applications during this session.

## Results

| Test | Expected result | Actual result |
| --- | --- | --- |
| Ordinary typing before monitoring | Baseline tap/hold/combo behavior remains usable | Pending |
| Boot / identity | Keyboard works and expected board/profile/digest is negotiated | Pending |
| Single keys 0–33, separately | Correct physical index highlights on press and clears on release | Pending |
| Layers / persistent modifiers | Stable layer mask and held modifiers match actions | Pending |
| Safe existing actions | Combo/tap/hold/autofire behavior preserved; physical state remains accurate | Pending |
| Attach while key 3 is held | Initial snapshot highlights key 3 without a fresh press | Pending |
| Companion restart | Typing continues; restarted companion synchronizes current state | Pending |
| USB unplug/replug | State becomes visibly stale and reconnect restores accurate state | Pending |
| Firmware restart | Old-session traffic discarded; new state synchronized | Pending |
| Safe burst / explicit diagnostic loss | Typing remains responsive; recovery clears any obsolete press | Pending |
| Overlay resize / movement / input-source switch | Geometry and labels refresh; limitations recorded | Pending |

Start capture only when explicitly requested and keep it bounded and sanitized.
If ordinary typing regresses, stop advanced tests and use the verified manual
rollback procedure. Record the failing row and artifact identity; reproduce the
defect offline before modifying firmware or keymap behavior.
