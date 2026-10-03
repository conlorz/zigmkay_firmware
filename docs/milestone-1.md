# Milestone 1: tested LK7 integration foundation

Completed locally on `local/integration`, starting from
`c5580be52119bb028588a3cc8329fe4fdecfbd27`. The unfinished companion checkout and
research worktrees remain intact. All implementation commits are local.

## Delivered behavior

The root `test` step runs the original core corpus, zkeycodes generation/label
fixtures, the portable model, layout validation, the gaming-layer regression,
protocol/reducer checks, and real LK7 observation traces. It also compiles the
model natively and for freestanding Wasm, and the codec/reducer for Wasm.

The real 34-key/four-layer LK7 keymap is shared with host tests. Its schematic
physical layout uses explicit stable IDs, while GPIO mapping and processing side
remain separate. Firmware validates the physical/logical layout at compile time.
The existing `_______` entries still explicitly mean `.none`.

The old gaming combo requested an unavailable layer. Processor layer activation
now rejects layers outside the actual keymap and counts those rejected requests.
Supported layer transitions retain their behavior.

An optional observer reports physical input exactly once across processing
retries, including combo and disabled keys. Separate events report stable layer
and modifier changes after custom callbacks. Observation uses a nonblocking sink,
never the ordinary keyboard output queue; dropped events advance the sequence.

The golden trace is real base-layer Q press/release, thumb hold selecting arrows,
arrows-layer EXLM press/release, then thumb release restoring base. It checks
eight exact 32-byte reports and the companion state along the way. Ordinary USB
commands match with observation enabled, disabled, and with a full sink.

## Validation

`tools/check-local --firmware`, with the explicit SDK settings in
[development.md](development.md), passed:

- **201/201 tests** and **94/94 host build steps**.
- Original core: 165 tests; zkeycodes: 22 tests; new model/integration checks: 14 tests.
- **20/20 LK7 firmware build steps**.
- No tracked source changes during checks.

Logs and the final UF2 digest are in `docs/evidence/integration`. The resulting
file is `keyboards/zig-out/firmware/zigmkay_firmware.uf2` (68,608 bytes).
No device was accessed or flashed.

The separate `local/probe-016` branch at `73e3f6c` passed the pre-trace core/model
suite (167 tests), minimal RP2040 and real LK7 firmware compilation, native DVUI
SDL3, and DVUI-Wasm under Zig 0.16.0. Reproduction and limitations are in the
probe worktree's `docs/probe-016.md` and `tools/check-probe-016`.

## Next work and current limits

Start phase 2 on Zig 0.16, using the successful dependency probe. The current
integration branch remains the verified 0.15.2 comparison until the full suite
and remaining host I/O are migrated. The probe excludes zig-flash and generator
runtime migration; it is not a full project port.

The companion is headless. Production RawHID scheduling, Hello/Snapshot,
reconnect/recovery, GUI, editor, and browser flashing remain later phases. The
LK7 custom callbacks still have file-global hold state; real-keymap tests finish
releasing their inputs and run in separate processes where needed. Geometry is
schematic, and successful builds do not establish hardware correctness.
