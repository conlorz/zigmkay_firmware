# USB/HID specification evidence review

Research date: 2026-10-04. Scope: normative contract and source audit; no hardware
operation or implementation. This document supports plan 11's R-HID-design
review and does not accept any live compatibility gate.

## Primary sources and versions

- [USB 2.0 specification archive](https://www.usb.org/sites/default/files/usb_20_20250603.zip),
  USB-IF distribution dated 2025-06-03, base specification revision 2.0 dated
  2000-04-27. Archive downloaded to `.zig-cache/usb-research/usb.zip`.
  [Readable copy of the same primary specification](https://0x04.net/~mwk/doc/usb/usb_20/usb_20.pdf)
  was used to inspect sections; the mirror is a transport, not an independent
  authority. Relevant sections: 5.5, 8.5.3, 8.6, 9.1, 9.2.6–9.2.7,
  9.3–9.4, 9.6.3–9.6.6.
- [HID 1.11](https://www.usb.org/sites/default/files/hid1_11.pdf),
  release 2001-06-27. Relevant sections: 4.4, 5.6, 6.2.1–6.2.2,
  7.1–7.2, 8; appendices B, C, F and G.
- [HID Usage Tables 1.7](https://www.usb.org/sites/default/files/hut1_7.pdf),
  release 2026-01-26. Relevant sections: 3 (usage page allocation),
  4 (Generic Desktop), 10 (Keyboard/Keypad), 11 (LED), 12 (Button),
  15 (Consumer). USB-IF's [HID source index](https://www.usb.org/hid)
  distinguishes allocated usages from host implementation support.
- Pinned [MicroZig USB controller](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/core/src/core/usb.zig)
  and [HID driver](https://github.com/ZigEmbeddedGroup/microzig/blob/00fde43fa3756790037b099baeafacc3e6bf9499/core/src/core/usb/drivers/hid.zig).
  Local cache verified against `keyboards/build.zig.zon` hash
  `microzig-0.15.2-D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`.

All sources accessed 2026-10-04. Specification requirements below are distinct
from observed source behavior and proposed engineering choices.

## Normative checkpoints

USB 2.0 sections 8.5.3 and 9 require SETUP to supersede an unfinished transfer.
SETUP uses DATA0; data begins DATA1, alternates, and status uses DATA1. Control
read status is OUT; control write/no-data status is IN. Reads stop at wLength
or a short packet; an exact packet multiple shorter than wLength needs a ZLP.
Unsupported requests require Request Error/STALL, not indefinite NAK.
SetAddress takes effect after status. Configuration zero deconfigures; valid
nonzero values come from bConfigurationValue, not descriptor index. Selecting
the current configuration resets relevant endpoint state. GetConfiguration
returns zero in Address state. GetStatus, features, alternate settings and
endpoint halt handling follow recipient/state restrictions. Reset restores
default addressing/configuration. Descriptor reads truncate to wLength;
configuration totals cover contiguous subordinate descriptors.

HID 1.11 appendix G requires GetReport for every HID interface. Keyboards
require GetIdle/SetIdle; boot keyboards additionally require GetProtocol/
SetProtocol. Any declared Output report requires SetReport(Output), including
devices with interrupt OUT. Appendix B's boot keyboard input is eight bytes:
modifier, reserved, six key slots. Report protocol may differ; default is
report protocol. Sections 7.2 define report type/ID and interface routing,
idle durations in 4 ms units, and protocol values zero/one. Appendix C defines
rollover indication. Report ID prefixes exist only when declared. Descriptor
bit counts determine report lengths. LED output has padding to a byte.

Usage Tables allocate page 0x07 to keyboard/keypad, 0x0C to consumer controls,
and 0xFF00–0xFFFF to vendor definitions. Reserved keyboard entries do not
establish a private protocol. Relative motion belongs in relative fields;
consumer and button fields must match their assigned meanings. Host support
for a usage requires separate evidence.

## Current source audit and implications

| Boundary | Observed source behavior | Proposed treatment and discriminating validation |
| --- | --- | --- |
| Keyboard input | `usb_if.zig` declares Boot subclass/protocol, but `KeyboardInReport` and report descriptor omit the reserved byte: seven bytes. | Use one eight-byte format in both protocols; independently check bytes `02 00 04 00 00 00 00 00` for Shift+A. This defect does not establish the cause of configuration timeout. |
| Keyboard output | Descriptor declares five LED bits; `KeyboardOutReport` represents three LEDs plus five padding bits. | Represent or intentionally consume all five declared bits; verify control OUT reception, acknowledgment after data, and state readback. |
| HID requests | Pinned `class_request` returns ACK for SetIdle, SetProtocol and SetReport without storing state or receiving OUT data. GetReport/GetIdle/GetProtocol fall through to `usb.nak`. | Implement actual supported operations; assert exact lengths/directions/interface/report type/ID, including unsupported feature requests. |
| Vendor output | Wrapper accepts interface-specific 32-byte SetReport(Output), no report ID; completes status after receiving a correctly sized packet. | Retain intent, but reject unknown class requests deterministically and test cancellation before data/status. Interrupt and control delivery must share the same validation. |
| Gate routing | `Gate.setup` intercepts request number 9 using low interface index before checking request type. | Route on type/recipient before interpreting request numbers: standard SetConfiguration also has number 9. Test malformed standard/class requests independently. |
| EP0 status | Wrapper arms OUT status after final IN completion; pinned controller's corresponding listen is commented out. | Keep the requirement; test packet boundaries and actual callback ordering rather than accepting a wrapper-only fake. |
| EP0 cancellation | Wrapper clears tx_slice and calls prepare on every SETUP, but does not clear the base's delayed new_address. | Cancel all pending transfer effects, including delayed addressing; inject new SETUP before SetAddress status completion. |
| Read termination | Wrapper stores only remaining bytes, not host-requested length or short-transfer termination requirement. Pinned continuation clears an empty slice without sending a ZLP. | Track requested/actual length and ZLP requirement. Cover 0, 1, 63, 64, 65, 128 and 146 byte responses, including host lengths smaller/equal/larger. |
| Standard requests | Wrapper supplies GetConfiguration. Base accepts arbitrary configuration values, short-circuits same configuration, lacks interface alternate-setting and endpoint recipient handling. | Explicit recipient/state dispatch; valid configuration 0/1 only, reset endpoints on reselection, alternate setting zero only, status/halt support. |
| Driver initialization | Base reads native nested `config_descriptor.drv` fields while opening endpoints and initializing drivers; wrapper serialization only replaces host-facing configuration/HID bytes. | Inspect target constants used by initialization. Contiguous host descriptor bytes do not prove those native field accesses are correct. |
| Unsupported requests | Source uses enumFromInt and optional/null returns; wrapper marks any delegated nonempty IN request as needing status. | Ensure malformed enum values cannot panic; only successful transfers create status expectations; STALL recovery starts with next SETUP. |
| Mouse | X/Y generated through generic data helper; wheel/pan explicitly relative. | Decode emitted X/Y flags; do not infer relative mode from signed values or comments. Compare runtime five-byte report with descriptor bit counts. |
| Consumer | One u16 array with page 0x0C range 0–0x03FF; dummy OutReport despite no Output item. | Test allocated usages actually produced; avoid exposing an unnecessary OUT endpoint solely for a dummy type. |
| Vendor/reset topology | Four HID interfaces plus RP2040 reset; dedicated 32-byte input/output on page 0xFF31 usage 0x74. | Preserve identity contract; baseline can suppress non-keyboard traffic without removing identity. Removing interfaces is a reviewed design amendment. |

The source audit concerns both first-party files and the exact pinned cache.
Neither the malformed boot report nor missing class requests proves the specific
timed-out request. macOS, Windows and Linux live behavior remains unverified;
the same specification contract applies to all three, while request order and
driver matching need platform evidence.

## Finite review/test contract

Before implementation review, integrate this audit with RP2040 register and
platform research. Prefer a bounded first-party controller fix that can invoke
real production request/packet logic in hardware-free tests. An upstream update
requires an immutable compatible pin and evidence for each resolved behavior;
replacement requires a maintenance/testability comparison.

Required independent cases: descriptor grammar and target constant bytes;
boot/report round trips; all mandatory class requests; declared outputs over
control and interrupt; invalid recipient/index/value/length; unsupported request
STALL and recovery; packet termination/ZLP; SETUP during each transfer phase;
stale completion after cancellation; delayed SetAddress; reset; 0→1, 1→0,
1→1 configuration transitions; interrupt backpressure and no lost release.
Validate exact expected wire bytes, not bytes regenerated by the implementation
under test. Live acceptance still requires actual configuration, attached HID,
press/release/modifiers, LEDs and unplug/replug recovery without companion.
