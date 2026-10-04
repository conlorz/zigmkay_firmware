# Bounded LK7 recovery session

Prepared and run 2026-10-04 with explicit user authorization.
**Configuration/HID attachment succeeded; modifier/release checks remain pending.**
User confirmed a Mac only, with no SWD probe or USB protocol analyzer.
Implementation `2e30e9d`; research decision `2972bc6`; Zig 0.16.0.
All offline checks below passed before preparing this session.

## Identified artifacts and recovery

Candidate LK7/Danish ReleaseSafe:
`.zig-cache/manual-session/recovery-11/lk7-2e30e9d.uf2`, 130,560 bytes,
SHA-256 `6b5df9e387fae46b2b995d82670ddd9c78c7563d09456ea75aaf00f6a41dc391`.
This is a snapshot of `zig-out/firmware/lk7/zigmkay.uf2`.

Preserved baseline:
`.zig-cache/manual-session/recovery-11/baseline-ab66f12-rp2040.uf2`,
71,168 bytes, SHA-256
`c1ae70b5f442e0ece9a33d29e3b1db409a5e3da8bbd4131d59874b1ff71af232`.
This rebuilt source baseline has only its UF2 family metadata repaired and
previously failed live configuration. **There is no known-working rollback
keyboard image.** Keep an independent working keyboard available. Physical
BOOTSEL reconnect is the recovery route even if firmware USB stops responding.
Do not use the original metadata-free sibling UF2.

Caches may be deleted. If either snapshot is absent or its hash differs, rebuild
and identify artifacts again before a device write; never substitute a stale
image by filename alone. The pinned sources and maintained probes remain in Git.

## Questions answered by one run

1. Does the corrected runtime initialization reach its final configured event
   and respond to SetConfiguration, rather than failing at the old corrupt
   endpoint size?
2. Does macOS attach a HID keyboard and use the standard eight-byte report,
   without any companion or browser?
3. Do press/release/modifiers, LED control state and one unplug/replug work?
4. If failure remains, is there a responsive EP0 diagnostic snapshot identifying
   the last request and initialization stage?

No SWD/analyzer is available. Firmware records a bounded RAM event ring, exposed
through the reset interface's USB string 8, language 0409, prefix `USBREC1:`.
It is accessible at the device descriptor/control level without a configured
HID interface. macOS's diagnostic may fetch or cache this string; freshness and
availability must be observed, not assumed. The last eight-byte SETUP is printed
first as 16 hex characters; each subsequent ten characters is one chronological
event: event ID, argument A, argument B, low/high value bytes. The last eight
events are retained. Event IDs: 1 SETUP, 2 decoded driver, 3 opening OUT,
4 initializing driver, 5 opening IN, 6 configuration initialization returned,
7 status IN completed, 8 STALL, 9 bus reset, 10 abort/ownership timeout.

The diagnostic fetch itself does not replace the saved request/events. A hard
panic/hang or fail-closed ownership timeout makes EP0 unavailable; the RAM ring
then cannot be recovered with this equipment. A host timeout in that case does
not distinguish panic from deadlock. Stop and report this limit; do not choose
another speculative flash. B0/B1 RP2040 cannot safely revoke active buffers due
to RP2040-E2; the implementation deliberately fails closed there. Live silicon
revision and all controller timing remain unverified.

## Execution after explicit authorization

Use only the intended LK7, with one BOOTSEL volume. Record OS/build, machine,
USB topology and initial USB state. Close the companion/browser for the baseline.
If discovery is ambiguous, identify the exact device/mount before proceeding.
Record the volume's `INFO_UF2.TXT` identity and exact mount; reject an unexpected
bootloader or device. No default automated check accesses any of this hardware.

Capture output in `.zig-cache/manual-session/recovery-11/`, including one
`ioreg -p IOUSB -l -w 0`, relevant kernel USB logs and one Apple `usbdiagnose`
after the outcome. `/usr/bin/usbdiagnose` is present; **`-h` runs a diagnostic**
and must not be invoked as a help probe. Diagnostic collection may include
other devices; keep raw output in the ignored cache and record only relevant
sanitized evidence in the handover. If diagnostic access is denied, report the
specific limitation before proceeding; no guessed permission changes.

Flash the identified snapshot through the authorized terminal entry point:

```text
mise //:flash-file .zig-cache/manual-session/recovery-11/lk7-2e30e9d.uf2 --mount /Volumes/RPI-RP2
```

Use the actually identified absolute mount if it differs. Observe the discovery,
open, write and sync stages separately. Stop after 60 seconds if transfer has not
finished; attempt process termination once and determine whether it exited.
A kernel-blocked FSKit syscall may not terminate. Do not start a second writer
or promise a polling deadline cancels that syscall; physical reconnect is the
recorded recovery route. No automatic baseline reflash is part of this run.

Allow at most ten seconds after restart for configuration/HID attachment. On
first failure, capture its diagnostics and stop the flash loop. Bound each
capture to 60 seconds; stop a capture that exceeds that limit and report whether
it terminated. Total session budget is ten minutes, one candidate flash and one
unplug/replug; do not use the remaining time for other firmware variants.

If configuration succeeds, record GetConfiguration/current configuration 1,
attached keyboard HID child and parsed eight-byte input descriptor. Ask the user
to type a short phrase in a local editor, exercise Shift/Ctrl/Alt/GUI as applicable,
press/release and Caps Lock LED/control behavior. Check recovery after a single
unplug/replug without launching the companion. Record actual outcomes per row
in the [manual worksheet](../plans/04-manual-worksheet.md).

Write/sync proves transfer only. Product name proves discovery only. Descriptor
`USBREC1` plus new report layout distinguishes this recovery design, but neither
is a cryptographic readback of the running binary. R5 must define its safe running
firmware verification contract after R-keyboard and R-custom; do not claim R-flash
or original G04 from this diagnostic session alone.

## Offline result and remaining gates

## Live evidence, 2026-10-04

Mac17,9, macOS 26.6.2 (25G83), Mac only. Exactly one RPI-RP2 volume
was identified: RP2 Boot VID 2e8a/PID 0003, bootloader v3.0, board RPI-RP2.
The companion was absent and Brave was closed for the baseline. The identified
candidate hash matched; one authorized mise transfer completed discovery/open/
write/sync in 3.88 seconds. No second flash was attempted.

At 17:48:19 local time macOS enumerated FAFA/00F0 at 12 Mbps and selected
configuration 1. IORegistry attached the keyboard HID/event driver plus consumer,
mouse and raw HID drivers. One Apple usbdiagnose parsed the 146-byte configuration,
five interfaces, eight endpoints, and the keyboard's 71-byte descriptor with
eight-byte input and one-byte output. Reset string 8 returned USBREC1; its
freshness is not established. Raw captures remain in the ignored session cache.

The user entered `WRRRRasta/n`; that is evidence of input, not yet a controlled
repeat/release test. They reported typing works after the single unplug/replug.
Post-reconnect IORegistry again reports configuration 1. The unfamiliar layout
prevented modifier testing; exact position-based instructions are being supplied.
Caps Lock has no binding in this candidate; its host LED state is still unverified.
R-keyboard remains waiting for controlled input/modifier observations. R-custom
and R-flash remain gated. Windows/Linux live checks remain unavailable.

`mise //:check-full` passed for the complete `2e30e9d` source tree: package and
integration tests, real pinned HID initialization, Cortex-M0+ probe, ten board
UF2s, independent parsing of their actual configuration/report payloads,
root/standalone LK7 parity and source/hardware-operation guards. Target assembly
inspection confirms the initializer uses contiguous serialized endpoint bytes
instead of the defective nested constant. It is not target runtime execution.

R-HID-design is recorded/accepted offline. R3 offline work is integrated;
R-keyboard awaits the remaining user-observed input/modifier checks. R-custom is gated on
R-keyboard. R-flash is gated on R-custom and still needs bounded discovery,
device ambiguity/identity, cancellation/failure fixtures and running verification.
Windows/Linux live checks are conditional on availability and remain unverified.
The original 05–09 roadmap remains deferred.
