# LK7 manual acceptance worksheet

State: ready for user session; G-live-offline accepted at `4fd4c66`.
No device has been accessed, flashed, or accepted.
Use this worksheet only after G-live-offline and an explicit user hardware
session. Coordinator fills artifact identities from the accepted 02/03 revision.

## Artifact and environment record

| Item | Value |
| --- | --- |
| Integrated implementation / current build / protocol | `4fd4c66` / mise migration `447efb8` / G01 `5b092ec`, v2 |
| New firmware path / size | `zig-out/firmware/lk7/zigmkay.uf2` / 95,232 bytes |
| New firmware SHA-256 | `0b9284b423f4918fcb6f769fc0132f33e03e30e8cbd554b16bf55d132c213bda` |
| Companion path / build revision / size | `zig-out/bin/zigmkay_companion` / `447efb8` / 42,245,536 bytes |
| Companion SHA-256 | `25814eedbcff3249e247da90a9f6a4dda05c2796dc1a8b393db7cbf35bb12e94` |
| Expected board / profile / digest | `lk7` / `danish` / `1ba43aa9b78a280faf77cdf41d0a42eb` (34 keys, 4 layers) |
| Zig | 0.16.0 |
| MicroZig revision | `00fde43fa3756790037b099baeafacc3e6bf9499` |
| Baseline rollback source | `ab66f12`, Rollercole 34-key / four-layer profile |
| Baseline rollback path | `.zig-cache/manual-session/rollback-ab66f12/zigmkay.uf2` |
| Baseline rollback size | 71,168 bytes |
| Baseline rollback SHA-256 | `4924493306b302a7c2019e948ce04c79225c7d08dba1711eafc3cccbc32380e8` |
| Physical LK7 revision / controller recovery procedure | User verification pending |
| macOS version / input-source ID / cable or hub | User session pending |
| Overlay placement / opacity / focus settings | User session pending |

Offline acceptance: Zig 0.16.0 root 325/325 tests, check/check-full, all ten
boards, standalone checks and LK7 UF2 byte parity passed. Companion offline,
legacy and timed-replay smoke runs each rendered three frames. On an explicitly
authorized session, start the matching GUI with
`mise //:companion-run --live`; use `--device-path` only if multiple
matching collections are found. See [the overlay guide](../live-overlay.md).
Recording requires an explicit `--capture` path and is bounded.
Build/flash through `mise //:flash lk7`; rollback through
`mise //:flash-file .zig-cache/manual-session/rollback-ab66f12/zigmkay.uf2`.
The current firmware hash is unchanged by the tooling migration; the GUI was
rebuilt from its standalone package with mise's pinned compiler. Automatic
flash/restart behavior remains unresolved in the 04 handover. Do not interpret
a successful utility write/sync as observed hardware acceptance.

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
