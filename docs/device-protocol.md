# Device protocol: frozen proposal for v2

Checkpoint state: proposed; coordinator review pending. Existing v1 codec and
literal offline fixtures remain unchanged. V1 is explicitly offline-only; live
adapters require v2 and never guess legacy RawHID formats.

## Transport and framing

The vendor interface uses usage page `0xFF31`, usage `0x0074`, 32-byte interrupt
IN and OUT reports, with no report IDs in its descriptor. Portable codec reports
are exactly 32 bytes. Native HID writes prepend a zero report-ID byte (33 bytes);
native reads accept exactly 32 codec bytes, or an explicitly documented native
33-byte zero-ID form stripped by the adapter. Never strip arbitrary leading data.
Pinned MicroZig `00fde43` exposes `send_report()` (false on backpressure) and
`receive_report()` for interrupt OUT. Its SetReport control path only acknowledges
requests. SDL's macOS HID write implementation uses Output SetReport, so 02 must
provide a first-party Zig controller wrapper which validates vendor-interface
SetReport setup and receives its ep0 OUT data stage. Interrupt OUT reception must
also remain supported. No upstream dependency or C bridge edits are required.
Its receive API does not expose received length; firmware integration must ensure
short OUT transfers cannot expose uninitialized tail bytes (02 integration gate).

All integers are little endian. Unused payload bytes must be zero. V2 header:

| Offset | Size | Value |
| --- | --- | --- |
| 0 | 1 | Magic `A7` |
| 1 | 1 | Major version `02` |
| 2 | 1 | Kind below |
| 3 | 1 | Exact payload length, at most 20 |
| 4 | 4 | Nonzero session token, except Hello request |
| 8 | 2 | Delta sequence, snapshot next-delta boundary, otherwise zero |
| 10 | 2 | Nonzero host request ID for transactions; zero for deltas/indications |
| 12 | 20 | Payload and zero padding |

| Kind | Direction | Payload |
| --- | --- | --- |
| 10 Hello | host to device | nonce u32 (4 bytes) |
| 11 Identity | device to host | part index, count=3, body chunk (18/18/8 bytes including prefix) |
| 12 Snapshot request | host to device | empty |
| 13 Snapshot part | device to host | part index, count=2, 10 body bytes (12 bytes) |
| 14 Key | device to host | pressed bool, key index, pre-batch highest layer, pre-batch modifiers (4 bytes) |
| 15 Layers | device to host | active mask u16, highest layer, persistent modifiers (4 bytes) |
| 16 Recovery needed | device to host | reason: 1 queue overflow, 2 snapshot invalidated (1 byte) |
| 17 Signal | device to host | signal: 1 log toggle, 2 overlay toggle, 3 shutdown; pressed bool (2 bytes) |

Hello header session/sequence are zero; nonce and request are nonzero. Device
responds to Hello with a session token equal to the nonce. Host nonce allocation
must never reuse a token within the lifetime of queued native traffic: the native
adapter seeds a counter with OS randomness and increments for every negotiation,
including reconnect/recovery after exhaustion. Zero is skipped. There is one
active host session per device. Hello replaces the device's active session and
clears old telemetry/control transactions; firmware emits nothing until Hello.
The nonce is an isolation token, not authentication. A boot cannot silently resume
a session: firmware forgets it on boot. The host periodically requests a snapshot
and a silent reboot is detected by timeout followed by a fresh Hello token.

Identity body is nonce u32, board ID[8], profile ID[8], digest[16], key count u8,
layer count u8 (38 bytes). Three chunks contain bytes 0..15, 16..31, 32..37.
Part indices are zero based. IDs are 1..8 lowercase ASCII letters/digits/underscore,
zero padded, with no nonzero byte after a zero. Counts are 1..127 keys and 1..15
layers. Identity header session equals echoed nonce, sequence=0, and request
matches Hello. All three fragments share those fields. Exact repeated parts are
idempotent; conflicting duplicates invalidate the transaction. All identity fields
must match the companion's expected compiled identity before synchronization.
Unknown version/kind, invalid IDs/counts/masks, wrong lengths/padding and boolean
values fail explicitly before model mutation. Unsupported identity is incompatible.

## Canonical profile identity

`IdentityInput` supplies board/profile IDs, dimensions, layer-major key definitions,
sides, ordered combos, encoder actions, and declared custom callback identities.
`computeIdentity` explicitly serializes into SHA-256, retaining its first 16 bytes.
The domain is ASCII `zigmkay-profile-v1` followed by zero. Board/profile IDs use
fixed eight bytes; dimensions use two bytes. Ordered collection lengths use u16;
key definitions are exactly layers*keys, sides exactly keys. Enum tags are explicit
wire constants, never compiler enum representations. Scalars use little endian;
optional values are presence bool then value. Every TapDef option, HoldDef option,
tapping timeout/retro flag, autofire timing, keycode modifiers/dead flag, media and
mouse action, combo indexes/layer/timeout/action, side, and encoder tap is included.
Callbacks are ordered `(id u8, declared behavior name length u16, ASCII bytes)`;
names must be nonempty and stable across identical builds. IDs are unique and all
custom IDs used by actions must have declarations, except reserved built-in
companion signal IDs 253..255. A behavior change must change its declaration.
Function addresses, struct padding, compiler memory layout, and host labels are
never hashed. 05/07/08 reuse this digest; artifact hashes are separate.

Canonical order: domain, board, profile, dimensions, key definitions, sides,
combos, encoders, callback declarations. Each collection starts with u16 length.
Key tags: none=0, tap_only=1, hold_only=2, tap_hold=3, autofire=4. Tap fields are
key_press, one_shot, custom, media_key, mouse_action in that order. KeyPress fields
are keycode u8, modifiers u8, dead bool. Hold fields are modifiers u8, optional
layer u8, optional custom u8. TapHold is tap, hold, term u16, retro bool; autofire
is tap, initial u16, repeat u16. Side tags L=0/R=1/X=2. Combo is indexes[2], timeout
u16, layer u8, key definition. Encoder is tap. Media uses its USB u16 usage value;
mouse tags Left=0/Right=1/Middle=2/Button4=3/Button5=4/WheelUp=5/WheelDown=6/
WheelLeft=7/WheelRight=8. Optional presence and all booleans are one byte 0 or 1.

## Snapshot, ordering, and memory budgets

Snapshot body is pressed bitmap[16] (index i uses bit i%8 of byte i/8), active
layer mask u16, highest layer u8, persistent modifiers u8. Bits at/above key count
must be zero. Layer mask includes base bit and matches highest layer. The bitmap
tracks physical ingestion, including disabled keys and combo components, rather
than USB output/release-map state. Persistent modifiers exclude shifted-character
output pulses. Snapshot parts share session, request and next-delta sequence.

Device atomically captures current physical/stable state and next sequence at a
processor boundary, queues both snapshot parts ahead of subsequent deltas, then
continues typing. Controls/identity/snapshot responses do not advance sequence.
Key, Layers and Signal advance u16 sequence on every attempted event, even if
queue insertion fails. After capture the first delta has the snapshot boundary
sequence. Sequence wraps modulo 65536. Recovery indication bypasses a full delta
queue; a reserved control slot or flag is required. Any overflow during snapshot
transmission invalidates that snapshot, flushes pending fragments/deltas, and
schedules recovery indication. Firmware never blocks typing on delivery.

Host stores one identity assembly (38 bytes), one snapshot assembly (20 bytes),
and at most eight pending deltas while synchronizing. No allocations are needed.
Parts may arrive out of order; exact duplicates are ignored, conflicting duplicates
abort recovery. Parts from other sessions/obsolete requests are ignored. A different
boundary within one transaction aborts it. Atomic commit waits for both parts,
validates the complete body, then verifies/applies pending contiguous deltas on a
candidate state. Buffer overflow or gaps aborts without changing visible state.
A failed snapshot leaves the last complete state explicitly stale.

For live deltas, next expected sequence is last+1; the initial expected value is
snapshot boundary. A modular difference in 1..32767 is a forward gap and starts
recovery. Difference in 32768..65535 is stale/duplicate and ignored. Exactly 32768
is conservatively treated as discontinuity. More than half the sequence space
without synchronization is outside the order window; periodic snapshot refresh
bounds it. Wrong-session deltas never affect state.

## Portable API and lifecycle

Existing `Message`, `encode`, `decode`, `State.init/apply/receive` retain strict v1
semantics. New `Packet`, `encodePacket`, `decodePacket`, `Identity`, `IdentityInput`,
`computeIdentity`, `Snapshot`, `encodeSnapshotBody` and `decodeSnapshotBody` form
the v2 codec API. Packet payload is a tagged union and direction validation is
explicit. New `Session.init(expected_identity)`, `connect(now, nonce)`,
`disconnect()`, `receive(bytes, now)`, and `tick(now, fresh_nonce)` expose the pure
reducer. `Session.state` remains the last complete model; `phase` is disconnected,
negotiating, synchronizing, live, recovering or incompatible; `stale` is explicit.
Each call returns bounded `Actions` (at most two actions): `send(Packet)` or
`signal(Signal)`. Adapter executes them; model never imports SDL/MicroZig.

Time units are injected monotonic milliseconds. Transaction timeout is 500 ms,
at most three attempts per negotiation/snapshot, periodic snapshot interval
1000 ms. Every retry uses a new nonzero request ID; identity retries use the same
nonce while already negotiating. Exhaustion leaves phase recovering, state stale,
and emits no further retries until explicit reconnect or fresh-nonce negotiation
via tick after a 1000 ms cooldown. Request counter exhaustion restarts Hello with
a fresh token supplied to tick. Interrupted recovery/disconnect discards assemblies
and pending deltas and retains stale state. Incompatible requires reconnect to
retry; malformed packets return errors without applying partial visible state.

Connection example: connect -> Hello -> three matching Identity fragments ->
Snapshot request -> two snapshot fragments -> live at boundary -> contiguous
deltas. Gap/overflow -> recovering/stale -> Snapshot request -> atomic replacement
-> live. Reboot/silent device -> snapshot timeout/retries -> fresh Hello -> identity
-> snapshot. Signal press emits one adapter intent; release is sequenced but does
not execute an action. Signals lost during overload are not reconstructed.

Headless default remains strict v1 replay. Explicit `--session` reads v2 reports
against the compiled LK7 identity; it runs a deterministic clock (1 ms/report),
prints session/stale state, and requires a live terminal state. It executes no
transport/device I/O. Literal session fixtures reside in dedicated Zig tests.

## Preserved v1 literals

V1 header remains magic/version/kind/length, sequence u16, reserved zero u16;
key kind=3/layer kind=1 each has four payload bytes and twenty zero padding bytes.
Literal Q press is `A7 01 03 04 00 00 00 00 01 00 00 00`; Q release changes sequence
to 1 and pressed to 0. Existing eight-report `tests/fixtures/lk7_trace.bin` and
independent golden-byte tests remain authoritative and unchanged. V1 first event
sets the start sequence; any duplicate/gap permanently requires a new State.
