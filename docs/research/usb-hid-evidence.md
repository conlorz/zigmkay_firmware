# USB/HID recovery evidence

Inspected 2026-10-04 with Zig 0.16.0. Starting revision `f953373` on
`local/monorepo`, clean tree. Firmware implementation baseline `637fd71`.
MicroZig is pinned in `keyboards/build.zig.zon` to
`00fde43fa3756790037b099baeafacc3e6bf9499`, hash
`microzig-0.15.2-D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`.
Another cached MicroZig package is not the dependency used by this checkout.

## Sequence and ownership

| Stage | First-party boundary | Pinned dependency boundary | Evidence / discriminating check |
| --- | --- | --- | --- |
| Startup | Board entry, `loops.run_primary_internal`, `CreateAndInitUsbCommandExecutor` | Cortex-M startup, RP2040 `Polled.init` | Target builds establish compilation, not execution |
| Bus reset / address | `usb_control.Controller.on_bus_reset/on_setup_req` | `Polled.poll`, controller deferred SetAddress | Check pending address cancellation and reset before stale completion |
| Descriptor discovery | `usb_if.wire_descriptors`, `usb_descriptor_bytes.encode` | Device/string/report descriptors, EP0 `ep_writev` | Inspect actual UF2 payload and runtime descriptor reads separately |
| Configuration selection | Wrapper delegates SetConfiguration | `DeviceController.process_set_config`, `ep_open`, HID `init` | Capture request entry, each endpoint open, initialization exit, status IN |
| HID discovery | Interface/report layout in `usb_if.zig` | HID class request parser | Check required request responses and explicit STALL |
| Typing | Processor → `OutputCommandQueue` → USB executor | HID `send_report`, completion sets readiness | Backpressure must preserve press/release; companion absent test |
| Companion | Telemetry observer/transport, protocol v2, live adapter | Separate vendor HID collection | Collection ownership is distinct from device configuration |
| BOOTSEL | ActivateBootMode / reset interface | RP2040 ROM reset | Requires explicit live session |
| Transfer | Root mise → `zig_flash`, immutable validated input | Mounted FAT/FSKit → boot ROM UF2 handler | Write/sync, restart and verified firmware are three separate observations |

## Observations versus hypotheses

Historical observations below come from the recovery handoff and 04 hardware
handover, not a new hardware run. No hardware has been accessed in this session.

| Observation | What it establishes | What remains unknown |
| --- | --- | --- |
| Original UF2 omitted family metadata; `2089219` repaired it | Boot ROM validity defect, independently tested | Does not establish HID operation |
| Transfer/write/sync followed by ZigMkay re-enumeration | Boot ROM accepted an image and firmware reached USB discovery | Running identity and typing not verified |
| Baseline source `ab66f12` rebuilt with current tools also failed | Failure is not isolated to telemetry changes | Not a historical known-good Windows binary |
| Apple diagnostic initially rejected zero-length descriptor | Aggregate bytes were malformed | Other control/runtime defects can coexist |
| `637fd71` diagnostic parsed 146 bytes, five interfaces, eight endpoints | Host-facing configuration serialization repaired | Still timed out at configuration; no HID children |
| Quitting Brave/reconnecting did not fix configuration | Browser ownership is not an established cause | Companion access may have separate rules after configuration |
| Pinned code leaves status OUT listen commented out | Source-level incomplete EP0 status handling | Earlier wrapper repair alone did not restore live operation |
| Pinned HID driver ACKs SetReport without receiving data | Source-level broken output control transfer | Timed-out live request number not captured |
| Keyboard advertises Boot subclass/protocol but has seven-byte report | Definite mismatch with HID boot contract | Cannot alone explain configuration initialization timeout |
| Executor discards `send_report` failure | A release can be lost under backpressure | Frequency on live hardware unmeasured |

Do not infer TCC, accessory policy or malformed HID parsing from an EP0 timeout.
Do not infer panic from a host timeout. Candidate runtime aggregate corruption,
HAL stale completions and missing requests need distinct evidence.

## Current interface inventory at baseline

Identity: VID `FAFA`, PID `00F0`, bcdUSB `0200`, bcdDevice `0100`, serial
`00000001`; manufacturer `OpenKeyboardCollective`, product `ZigMkay`.
One configuration, value 1, bus powered, advertised 500 mA, no remote wakeup.
String indices 1/2/3 are manufacturer/product/serial; 4–7 name HID interfaces.
Unique endpoint numbering consumes eight nonzero endpoint numbers.

| Interface | Class/subclass/protocol | OUT / IN | Reports without IDs | Usage |
| --- | --- | --- | --- | --- |
| 0 Keyboard | 03/01/01 | 01 / 82, 1 ms | Output 1 byte, input 7 bytes | Desktop Keyboard; keyboard modifier bitmap + six usages; LED bits 1–5 |
| 1 Consumer | 03/00/00 | 03 / 84, 10 ms | Dummy OUT 1 byte, input 2 bytes | Consumer Control, selector 0000–03FF |
| 2 Mouse | 03/00/00 | 05 / 86, 1 ms | Dummy OUT 1 byte, input 5 bytes | Five buttons, X/Y, wheel/pan; X/Y helper currently emits absolute fields |
| 3 Vendor | 03/00/00 | 07 / 88, 1 ms | Input/output 32 bytes | Vendor page FF31, application usage 0074 |
| 4 Reset | FF/00/01 (confirm from serialized descriptor) | None | Vendor reset requests | RP2040 reset driver |

Configuration header bytes are `09 02 92 00 05 01 00 80 FA`. First interface
starts `09 04 00 00 02 03 01 01 04`. Every HID record has nine bytes and each
endpoint record seven. These prefixes identify the baseline; independently
specified parsing and target checks must be updated for any new layout.

## Custom actions and consumers

`layout-model/src/types.zig` reserves internal special keys FC (BOOTSEL), FD
(stats), FE (companion toggle), FF (shutdown), and a separate `TapDef.custom`
namespace FD (log toggle), FE (shutdown), FF (overlay toggle). The equal numeric
values do not make these USB keyboard usages. `core.OutputCommandQueue` diverts
companion keys only when a signal sink is attached; auditing the sink-absent path
is required before R-custom. Generic custom IDs 01–FC belong to keymap callbacks.

`processing.zig` produces custom enter/exit events. `core.zig` routes reserved
signals to the bounded telemetry sink, or legacy `RawHidSignal` commands.
`telemetry_transport.zig` produces sequenced v2 signal packets.
`device-protocol/src/root.zig` defines overlay/log/shutdown signal kinds and
hello, snapshot, acknowledgment and recovery commands. `companion-model` consumes
session packets; `zigmkay-companion/src/live_adapter.zig` exposes accepted intents
to `main.zig`. The v2 report remains 32 bytes with no HID report ID. Host APIs may
require a leading synthetic zero ID byte, which is not firmware payload.

R4 is gated on observed R-keyboard; inventory is not authorization to resume
EurKEY/editor work or silently change the shared identity/session contract.

## Regression limits and patch audit

Retain UF2 family repair and explicit field serialization: both have concrete
evidence. Retain the requirement for status OUT and GetConfiguration, but audit
the wrapper implementation against cancellation, short/ZLP termination and
required request validation. The old fake base in
`tests/test_telemetry_transport.zig` only increments counters; tests manually
set `tx_slice` and cannot establish real controller initialization or HAL safety.
The existing descriptor test specifies bytes independently but runs only on
the host. Promote target probes into reproducible Zig checks with cache outputs.

Research sources and request contract are recorded in
[specifications](usb-hid-specifications.md), [platforms](usb-hid-platforms.md),
[RP2040](usb-hid-rp2040.md) and the [decision](usb-hid-decision.md).
