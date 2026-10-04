# LK7 bounded telemetry transport

Pure transport checkpoint against accepted G01 `5b092ec`. USB and runner
integration are pending; no live delivery or hardware acceptance is claimed.

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
exists. USB send acceptance and exact received lengths remain integration gates.

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
snapshot. Native/target ABI totals and firmware size are to be recorded at USB
integration. One request dispatch and one endpoint attempt per runner tick;
physical event work is constant per input and bounded by the existing input
queue. Control floods use one mailbox; there is no unbounded pending work.

Offline tests exercise byte preservation under 100 blocked attempts, snapshot
ordering, disconnect/held state, 1000-event saturation/recovery, partially sent
snapshot invalidation, 10000-control floods, strict lengths/directions/sessions,
sequence wrap, sequenced signals and replacement Hello. Real LK7 typing traces
produce identical six keyboard commands with disabled, enabled, saturated and
disconnected transport. A sink-free test covers disabled keys, combo retries,
physical bitmap and stable layers/modifiers.
