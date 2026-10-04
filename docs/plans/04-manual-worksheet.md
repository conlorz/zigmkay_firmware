# LK7 manual acceptance worksheet

Current recovery candidate and bounded run:
[plan 11's diagnostic session](../research/usb-hid-diagnostic-session.md),
implementation `2e30e9d`. Use its SHA-256 and stop criteria after explicit hardware
authorization. R-keyboard does not automatically accept the original G04
identity/session/overlay rows below; companion tests wait for R-keyboard.

State: hardware troubleshooting in progress; G04 acceptance is pending.
One authorized recovery flash, automatic reboot, configuration 1 and all four HID
attachments succeeded. User reports typing after reconnect; controlled modifier/
release checks and host LED state remain pending.
Use this worksheet only after G-live-offline and an explicit user hardware
session. Coordinator fills artifact identities from the accepted 02/03 revision.

## Artifact and environment record

| Item | Value |
| --- | --- |
| Integrated implementation / firmware build / protocol | `2e30e9d` / USB recovery / G01 `5b092ec`, unchanged v2 |
| New firmware path / size | `.zig-cache/manual-session/recovery-11/lk7-2e30e9d.uf2` / 130,560 bytes |
| New firmware SHA-256 | `6b5df9e387fae46b2b995d82670ddd9c78c7563d09456ea75aaf00f6a41dc391` |
| Companion path / build revision / size | `zig-out/bin/zigmkay_companion` / integrated `2e30e9d` tree / 42,245,536 bytes |
| Companion SHA-256 | `4c612468ce0c9aee29d669123c99eb20b6de988615da642176612a6b9dc00db0` |
| Expected board / profile / digest | `lk7` / `danish` / `1ba43aa9b78a280faf77cdf41d0a42eb` (34 keys, 4 layers) |
| Zig | 0.16.0 |
| MicroZig revision | `00fde43fa3756790037b099baeafacc3e6bf9499` |
| Baseline rollback source | `ab66f12`, Rollercole 34-key / four-layer profile |
| Baseline rollback path | `.zig-cache/manual-session/rollback-ab66f12/zigmkay-rp2040.uf2` |
| Baseline rollback size | 71,168 bytes |
| Baseline rollback SHA-256 | `c1ae70b5f442e0ece9a33d29e3b1db409a5e3da8bbd4131d59874b1ff71af232` |
| Physical LK7 revision / controller recovery procedure | User verification pending |
| macOS version / input-source ID / cable or hub | 26.6.2 (25G83), Mac17,9 / input source and cable or hub unverified |
| Overlay placement / opacity / focus settings | User session pending |

Offline recovery acceptance: Zig 0.16.0 scoped tests and check-full, all ten
boards, actual USB artifact parsing and LK7 UF2 byte parity passed. Companion offline,
legacy and timed-replay smoke runs each rendered three frames. On an explicitly
authorized session, start the matching GUI with
`mise //:companion-run --live`; use `--device-path` only if multiple
matching collections are found. See [the overlay guide](../live-overlay.md).
Recording requires an explicit `--capture` path and is bounded.
For the first recovery run use the exact snapshot/command in the bounded session;
do not start the companion before R-keyboard. Later build/flash uses
`mise //:flash lk7`; baseline transfer uses
`mise //:flash-file .zig-cache/manual-session/rollback-ab66f12/zigmkay-rp2040.uf2`.
The firmware was rebuilt with mandatory RP2040 family metadata at `2089219`;
all ten UF2s now pass structural validation. The GUI was
rebuilt from its standalone package with mise's pinned compiler. Automatic
flash/restart behavior is observed; typing remains unresolved in the 04 handover. Do not interpret
a successful utility write/sync as observed hardware acceptance.

The original rollback was compiled from the unchanged implementation baseline,
but lacked the RP2040 family flag/ID. A cached Zig utility added only that header
metadata to every block, preserving the firmware payload, and validated the
complete transfer. The original `zigmkay.uf2` and hash
`4924493306b302a7c2019e948ce04c79225c7d08dba1711eafc3cccbc32380e8`
are retained for evidence and must not be used to flash. Neither corrected
artifact has hardware acceptance in this session. The cache copy is local
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
If ordinary typing regresses, stop advanced tests and recover through physical
BOOTSEL. The preserved baseline also failed configuration and is not a known-working
rollback keyboard. Record the failing row and artifact identity; reproduce the
defect offline before modifying firmware or keymap behavior.
