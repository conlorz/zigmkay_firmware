# RP2040, MicroZig and UF2 evidence

Access date: 2026-10-04. This is research and offline evidence; no hardware
operation or platform acceptance is claimed.

## Sources and exact implementation

- [RP2040 datasheet](https://datasheets.raspberrypi.org/rp2040/rp2040-datasheet.pdf),
  build 3184e62-clean, 2025-02-20: sections 4.1.2.7.1, 2.8.4 and 2.8.5.
- [Pinned core controller](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/core/src/core/usb.zig)
  and [RP2xxx USB HAL](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/port/raspberrypi/rp2xxx/src/hal/usb.zig).
- [Pinned HID driver](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/core/src/core/usb/drivers/hid.zig)
  and [atomic implementation](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/port/raspberrypi/rp2xxx/src/hal/atomic.zig).
- [Upstream core, retrieved main](https://raw.githubusercontent.com/ZigEmbeddedGroup/microzig/main/core/src/core/usb.zig)
  still contains the same aggregate-dependent configuration initialization and
  missing driver deinitialization. A moving main branch is comparison evidence,
  never a dependency recommendation or immutable pin.

The actual keyboards dependency hash is
`microzig-0.15.2-D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`.
Another cached MicroZig package exists and must not be confused with this pin.
Zig is 0.16.0. The pin contains the 0.16 `@Struct` migration.

## Discriminating compiler/controller result

`keyboards/tests/usb_runtime_probe.zig` imports the exact pinned core controller,
constructs one real HID driver, drives real `on_setup_req` with SetConfiguration
1, and captures values dereferenced by fake DeviceInterface endpoint callbacks.
The HID inputs are independently specified as eight-byte IN and one-byte OUT;
unique endpoints allocate OUT 1 and IN 2. Expected capture pairs are:

| Callback | Endpoint/address | Size |
|---|---:|---:|
| Open OUT | 1 | 1 |
| Listen OUT from real HID init | 1 | 1 |
| Open IN | 130 (`0x82`) | 8 |

With Zig 0.16.0, `thumb-freestanding-eabi`, `cortex_m0plus`, `ReleaseSmall`,
the emitted assembly instead writes **7, 769, 7, 769, 0, 33285**.
Generated evidence is `.zig-cache/usb-runtime-probe.{zig,s,o}`. Assembly
constant-folding makes the erroneous runtime callback arguments visible without
running firmware. This proves the controller initialization boundary remains
corrupt even when the host configuration stream is explicitly serialized.
It does not alone prove which failing callback was last reached on the device.

The production path is `usb_if` wrapper → pinned `process_set_config` → nested
`config_descriptor.drv` field → `ep_open` OUT → HID `init`/`ep_listen` →
`ep_open` IN → EP0 ACK. The HAL asserts packet sizes at most 64; the probe's 769
is a concrete route to failure before ACK. Compile-time descriptor serialization
cannot repair those runtime descriptor references.

Recommended bounded fix: retain the pinned HAL and driver/report machinery,
initialize drivers from persistent first-party descriptor instances populated
field by field from the reviewed wire contract, and own configuration lifecycle
and EP0 semantics. Verify the same callback witness after the change. Do not
assume a dependency upgrade fixes this; upstream comparison supplies no such
evidence. A USB-stack replacement would introduce broader integration and
testing costs without addressing a narrower demonstrated boundary first.

## Controller/HAL audit

Pinned core does not implement GetConfiguration; unsupported requests return
null without a HAL STALL. It accepts any nonzero configuration number, does not
deinitialize drivers, and returns early on repeated configuration. HAL endpoint
allocation consumes its remaining buffer slice and is not reset by core
deconfiguration. Reconfiguration therefore needs explicit teardown/reuse.

The core leaves EP0 OUT status arming commented out and does not terminate an
IN transfer with a ZLP when a short descriptor ends on a packet boundary. Its
pending SetAddress/descriptor state is not universally canceled on SETUP.
The existing wrapper addresses some of these gaps but delegates much of the
state machine and sets status expectations from request direction rather than
an accepted response. HID SetIdle/SetProtocol only ACK, and SetReport ACKs
without receiving its data. Interface dispatch dereferences configured driver
state without guarding an unconfigured request.

HAL poll snapshots interrupt status, handles SETUP, then buffer completions,
then reset. The first-party setup hook clears EP0 completion bits before the
HAL reads BUFF_STATUS, so an already cleared EP0 bit is not necessarily
dispatched: inspect the actual fresh buffer-status read, not just INTS.
Concurrent reset/completion and new status events still require explicit tests.
The unbounded AVAILABLE and abort-done waits need bounded diagnostic evidence.
Clearing AVAILABLE directly during SETUP also merits review against abort
ownership; do not silently assume clearing a bit cancels an active transaction.

The datasheet's buffer ownership protocol writes metadata before AVAILABLE,
with a clock separation. The HAL default is three NOPs; verify board clock
ratios. DPSRAM lacks register set/clear aliases. These constraints come from
section 4.1.2.7.1 of the [datasheet](https://datasheets.raspberrypi.org/rp2040/rp2040-datasheet.pdf).

HID initialization uses `.init` atomic value constructors, not atomic stores.
A separate Cortex-M0+ probe confirms later seq_cst bool operations call
`__atomic_load_1`/`__atomic_store_1`. Pinned RP2040 HAL exports these using a
spinlock and interrupt critical section; this is not evidence of an unsupported
atomic panic. Check final linked symbols and spinlock initialization if a later
report-path hang is observed. Probe outputs are in `.zig-cache/usb-atomic-probe.*`.

## Boot ROM and flashing treatment

The ROM exposes a virtual FAT16 disk and restarts after seeing all valid UF2
blocks. It requires family `0xe48bff56`, 256-byte payloads and compatible target
ranges. Duplicate blocks are written once; changed totals/type abandon the
transfer. Flash pages need 256-byte alignment; physical capacity still matters.
RP2040-E14 affects partially filled intermediate sectors. PICOBOOT provides
direct memory/flash operations, exclusivity and reboot. See datasheet sections
2.8.4–2.8.5.

Inference: restart can remove the mounted volume before a normal OS eject;
an unsafe-removal notification alone cannot distinguish flash failure.
No primary source inspected establishes a macOS FSKit-specific fix or guarantees
notification suppression. Direct PICOBOOT avoids FAT transfer but needs a
researched Zig USB backend and cannot silently expand the imported C bridge.
Retain filesystem transfer initially with honest outcome reporting; evaluate
direct transport independently if bounded filesystem behavior cannot be met.

Current `zig-flash/src/main.zig` validates a snapshot before opening destination,
writes directly, then syncs. Discovery loops are unbounded, default discovery
assumes a mount label/path, no bootloader identity or multiple-device check is
performed, and no restart or firmware identity verification follows sync.
The existing regular-file fixture proves chunk preservation only. Polling a
deadline cannot interrupt a blocked filesystem syscall; a supervised worker
process can bound parent responsiveness, but must report whether the worker
actually terminated. Do not claim cancellation or safe recovery until tested.

## Finite diagnostic contract

Before an explicitly authorized live session: identify artifact hash, firmware
build identity, intended board and rollback method. Record a bounded RAM event
ring with SETUP fields, transfer generation, configuration driver/open stages,
actual endpoint fields, buffer completions, reset, bounded-wait failures and
panic reason. Prefer SWD retrieval when available so failed enumeration cannot
hide its own diagnostic channel. A USB debug endpoint is insufficient when
SetConfiguration fails. Explain equipment limits before choosing observation.

One run should establish: last request received; whether its status packet was
armed/completed; whether initialization returned; whether host HID attachment
followed; and whether a standard key press/release arrived. Stop after one
instrumented outcome or its finite deadline. A successful filesystem sync is
transfer evidence; a disappearing volume is restart evidence at most; observed
expected firmware identity plus configured keyboard/input is stronger evidence.
