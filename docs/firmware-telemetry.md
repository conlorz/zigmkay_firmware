# LK7 bounded telemetry transport

USB/LK7 checkpoint against accepted G01 `5b092ec` and pure transport `b1af5aa`.
Coordinator offline integration checks and hardware acceptance remain pending.

`zigmkay.telemetry_transport.Transport` owns sixteen 32-byte delta slots, three
32-byte response slots, a single decoded control mailbox and a recovery flag.
`Observer.state` continuously tracks the sixteen-byte physical bitmap and stable
layers/modifiers even without a sink. The enabled sink updates transport state
regardless of session; disabled keys and combo components remain physical inputs.
Neither transport nor observer uses the keyboard action queue.

`receive` validates exact 32-byte framing and host direction. Hello replaces the
mailbox; snapshots cannot replace a pending Hello. Wrong session requests and
malformed controls increment a diagnostic counter. Callback work is one fixed
report decode with no allocation. `boundary` consumes at most one request after
processor processing. Hello resets old traffic and emits three identity parts.
Snapshots wait for control response completion, discard pre-cut deltas, capture
the current state and next sequence, and queue two parts before later deltas.

`pump` attempts at most one report per loop: control parts, recovery indication,
then deltas. A false endpoint return preserves bytes and queue head. The endpoint
must copy or take ownership before returning true. No spin, sleep or retry loop
exists. The HID driver returns false while its IN endpoint is busy; true means
`ep_writev` synchronously copied all 32 bytes into RP2xxx USB SRAM. Caller storage
can then be reused. Interrupt OUT uses direct `ep_readv` rather than the HID
`receive_report` helper, whose return hides received length. The shim uses a
64-byte zero-initialized scratch and accepts exactly 32 codec bytes.

Every session event attempt advances the wrapping u16 sequence, including signals
and events suppressed while unsynchronized. Full delta storage flushes obsolete
deltas, marks synchronization false and reserves recovery outside the queue.
Overflow during an unfinished snapshot additionally discards its remaining parts
and reports snapshot invalidation. Further bursts cannot overwrite recovery or
consume more storage. The next snapshot uses the continuously updated physical
state. Signal presses lost during overload are not reconstructed. Disconnect
forgets token/traffic but retains authoritative state for the next handshake.

Storage is fixed: 512 delta bytes, 96 response bytes, a 20-byte snapshot, one
Packet mailbox and identity/indices/counters. Observer retains another 20-byte
snapshot. Native aarch64 ABI totals measured with Zig 0.16.0: Transport 752 bytes,
Observer 56 bytes, Gate one byte. There is no heap storage. Target ABI and firmware
size/artifact hashes are coordinator integration outputs. One request dispatch
and one endpoint attempt per runner tick;
physical event work is constant per input and bounded by the existing input
queue. Control floods use one mailbox; there is no unbounded pending work.

Offline tests exercise byte preservation under 100 blocked attempts, snapshot
ordering, disconnect/held state, 1000-event saturation/recovery, partially sent
snapshot invalidation, 10000-control floods, strict lengths/directions/sessions,
sequence wrap, sequenced signals and replacement Hello. Real LK7 typing traces
produce identical six keyboard commands with disabled, enabled, saturated and
disconnected transport. A sink-free test covers disabled keys, combo retries,
physical bitmap and stable layers/modifiers.

## USB and runner integration

LK7 explicitly sets `telemetry_identity` from
`shared_keymap_3x5_2.identity(protocol)`. All other board configurations default
to null. Runner attaches the observer and separate signal sink after USB init,
then processes one control at the post-processor/post-USB-poll boundary and
attempts one vendor IN report. Identity comes from shared publication, with no
duplicate board/profile strings or digest. Pins, matrix mappings and existing
Rollercole callback behavior remain intact.

The first-party Zig `usb_control.Controller` wraps immutable MicroZig
`00fde43` (Zig 0.16 cache package ending `D20YSUgL4ADiSBUt_UcXeT9vQJmqvig4dYwWEaHnnGRE`).
MicroZig HID acknowledges SetReport without consuming data and the base core
ignores EP0 OUT. The shim intercepts vendor-interface Output SetReport only,
validates `bmRequestType=0x21`, request=9, exact interface index, Output type=2,
report ID=0 and length=32, then receives one exact EP0 OUT data packet before
sending the status ACK. Native macOS uses Output SetReport; native's prepended
zero report-ID byte is API metadata and is absent from codec data on USB.
Malformed setup/short or overlength data stall EP0; new setup cancels stale state.
The RP2xxx hook clears only EP0 completion flags, cancels its buffers/stalls and
resets OUT PID before the HAL toggles to DATA1. The base controller still handles
descriptors, keyboard, mouse, consumer, reset interface and their buffers.
Bus reset and deconfiguration clear telemetry traffic/session while physical
state remains current. The shim also handles exact interrupt OUT reports.

With telemetry attached, reserved custom IDs 253..255 (tap and hold) and public
`KC_COMPANION`/`KC_SHUTDOWN_COMPANION` keycodes become v2 Signal press/release
events. `send_raw_hid_signal` routes reserved IDs through this same bounded sink.
These do not consume keyboard queue capacity; combined normal actions emit their
signals only after fallible output work succeeds, preventing duplicate intents
on retries. Existing nonreserved custom callbacks still execute normally.
Legacy arbitrary raw reports are suppressed on LK7 v2, including explicitly
queued RawHidSignal commands; unsupported signal IDs have no v2 representation.
No legacy raw payload can mix with the versioned session. Default boards retain
their existing legacy path.

Fifteen scoped offline tests passed, including fake wrapper setup/data stages,
direction/report-type/ID/index/length rejection, cancellation, short and overlength
interrupt OUT, bus reset/deconfiguration, independent collection delegation,
reserved tap/hold/direct-key intents, and combined-action retry de-duplication.
Selected LK7 target compiled during coordinator feedback; final all-board builds,
root/standalone parity, check-full and artifact identification belong to the
stable integration revision.

Known limits: real macOS IOHIDDeviceSetReport and RP2xxx control timings are not
hardware-tested. The pinned HAL itself contains an existing hardware-availability
spin during polling; this transport adds no readiness waits. Existing keyboard,
consumer and mouse wrappers still discard their own send acceptance results and
the action executor retains its 10 ms throttle. These are baseline typing risks
to test explicitly in 04, not evidence that telemetry passed physical typing.
Absent companions consume bounded storage; physical unplug is observed through
the next bus reset/deconfiguration, since Polled exposes no separate VBUS callback.
