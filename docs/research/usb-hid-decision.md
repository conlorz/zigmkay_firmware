# USB/HID recovery decision

Design recorded 2026-10-04 before implementation, starting at `f953373`.
Read the [evidence](usb-hid-evidence.md), [USB/HID requirements](usb-hid-specifications.md),
[platform assessment](usb-hid-platforms.md) and [RP2040 audit](usb-hid-rp2040.md).

## Chosen boundary

Keep the immutable MicroZig pin and RP2040 HAL. Introduce a bounded first-party
configuration initializer which decodes explicit descriptor bytes into stable
runtime driver storage before endpoint opening. This is supported by the target
probe: the actual pinned controller's SetConfiguration reads endpoint/size
captures `7,769,7,769,0,33285` instead of `1,1,1,1,82h,8` for a simple HID.
Valid host-facing bytes do not repair those device-side accesses.

Keep the existing VID/PID/serial, vendor page FF31/usage 0074, unnumbered 32-byte
v2 session and shared identity unchanged. Keyboard is the only interface needed
for the standard input gate. Retain the current composite allocation for this
bounded repair so the first diagnostic isolates initialization and control
behavior without an unrelated collection migration. Consumer/mouse/vendor/reset
are optional functions, not prerequisites for typing. Do not launch a companion
for the keyboard acceptance stage. Remove dummy consumer/mouse OUT endpoints
only in a separately reviewed transport/layout amendment after that gate.

Keyboard boot and report protocols use the same standard eight-byte layout:
modifier bitmap, zero reserved byte, six keyboard usages. LED output has five
bits and three padding bits. Mouse X/Y/wheel/pan are relative. Consumer stays a
two-byte selector. Proprietary actions remain internal or on the vendor page;
reserved internal FC–FF sentinels must not become custom keyboard-page usages.

## Request and state contract

SETUP cancels prior data/status, pending address and stale EP0 completions;
clear stalls and restart DATA1. IN responses truncate at wLength, send packets
of at most 64 bytes and a terminating ZLP only when actual response is shorter
than wLength and an exact packet multiple. Arm DATA1 zero-length status OUT
after final IN completion and consume it once. OUT data is received before
status IN; malformed data stalls. Unsupported or invalid requests stall rather
than silently NAK forever. Apply SetAddress only after its status completion.

Support and validate device GetStatus, SetAddress, Get/SetConfiguration and
GetDescriptor; reject unsupported qualifiers/features. Support configured
interface GetStatus, Get/SetInterface (alternate zero only), HID/report
descriptors and HID GetReport/SetReport, Get/SetIdle, boot-only Get/SetProtocol.
Only declared report types, ID zero and exact output lengths are accepted.
Input GetReport returns current input, output GetReport current output.
Keyboard/vendor outputs accept interrupt and control delivery. No phantom
consumer/mouse output reports. Endpoint GetStatus/ClearFeature/SetFeature must
track halt and reset data toggle on clear, or remain a documented unresolved
contract item before hardware acceptance. Reset restores address/configuration,
idle/protocol and transport session. Configuration zero disables noncontrol
endpoints; selecting one again resets them and allocator storage even if already
configured. Backpressure preserves ordered press/release and modifiers.

This defines the intended contract; acceptance requires implemented/tested
behavior. Do not label incomplete request coverage as R3 complete.

## Alternatives

An immutable upstream update is not selected without a compatible revision
that passes the same target witness and control tests. It would alter more than
the demonstrated fault. A replacement USB stack or new C bridge is not selected:
neither is needed to repair evidenced first-party boundaries, and added language
or bridge scope requires explicit permission. A broad permissions change is
rejected because configuration timeout precedes companion access. Another blind
flash is rejected: capture must distinguish request handling from device hang.

## Finite validation and gates

1. Reproduce nested layout on host and Cortex-M0+; compare actual production
   initialization reads with independently specified endpoint values. Store
   generated objects/assembly/UF2 payloads in caches.
2. Independently parse configuration/report bytes and verify sizes, endpoints,
   boot layout, relative fields, output grammar and report IDs.
3. Exercise the real pinned controller plus repaired initialization through a
   fake DeviceInterface; cancellation/status/ZLP/request/reset/configuration and
   backpressure cases must cross the production boundary, not just counters.
4. Run scoped Zig checks and stable `mise //:check-full`, retaining ten board
   builds and root/standalone parity.
5. Prepare identified LK7 firmware and one bounded diagnostic session. A physical
   SWD probe or bus analyzer is preferred for exact request/panic evidence. Host
   logs alone cannot show every device-side transition. Record available capture
   capability before selecting the instrumented artifact. Stop on first timeout
   and inspect the captured transition; do not cycle speculative images.
6. R-keyboard requires live macOS configuration, HID attachment, typing/modifiers,
   press/release, LED/control and unplug/replug without companion. Windows/Linux
   remain unverified unless actually tested. R-custom follows R-keyboard;
   R-flash follows custom behavior and requires verified running identity.

## Integrated result

Research `2972bc6`, runtime initializer `c9ea3a1`, complete offline recovery
`2e30e9d`. Endpoint status/halt, alternate zero reset, full Chapter 9/HID dispatch,
EP0 transfer sequencing and bounded ownership waits are implemented. The
first-party poll dispatcher retains pinned HAL endpoint I/O and gives reset
priority, discards canceled EP0 completions, and acknowledges completion flags
before callbacks. Both EP0 PIDs reset before the HAL flips them to DATA1.
EP_ABORT_DONE is acknowledged with write-one-to-clear masks. B0/B1 cancellation
fails closed, an explicit silicon compatibility limit.

Changed input takes priority over idle repeats independently per interface.
Keyboard command backpressure preserves ordered transitions. Consumer/mouse
have independent bounded 16-report queues; overflow discards queued history and
enqueues neutral then latest state, increments a counter and never blocks
keyboard release. Relative motion history can be lost on secondary overflow.
While disconnected, the executor consumes changes into current held state and
does not replay obsolete taps. Reconfiguration restores held state. Legacy
optional vendor signals are best effort; v2 remains on its existing bounded
transport. No custom protocol or identity migration has been implemented at R3.

All five declared keyboard LED bits are retained and queryable; physical LED
mapping is board-specific and must not be claimed without a live test. The
default reset-interface BOOTSEL command commits after status IN; unsupported
reset options and reboot-to-flash are rejected rather than silently mapped to
BOOTSEL. Diagnostic string 8 is an explicit descriptor amendment, with unchanged
interface count/endpoint allocation and unchanged shared v2 identity.

`mise //:check-full` passes, including actual UF2 report/configuration parsing,
ten boards and parity. Full fake tests exercise production request/transfer and
executor code; real pinned HID initialization is tested separately. RP2040
register timing, hard panic recovery, host diagnostic string freshness and
Windows/Linux live behavior remain unverified. USB diagnostics are unavailable after
a hard hang or fail-closed boundary error with the user's Mac-only equipment.

R-HID-design is accepted. Subsequent authorized Mac/LK7 sessions accepted
[R-keyboard](usb-hid-diagnostic-session.md), [R-custom](usb-hid-custom-contract.md)
and [R-flash](usb-hid-flash-contract.md), including user-observed input and custom
persistence after root flashing. Original G04 and 05–09 remain deferred; their
separate worksheet requirements are not automatically accepted.
