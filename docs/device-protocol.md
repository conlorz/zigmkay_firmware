# Device protocol v1: offline foundation

This milestone implements KeyEvent and LayerState for deterministic host tests.
There is no production HID transport, device handshake, or snapshot yet. A report
is exactly 32 bytes. The HID report ID is transport metadata outside these bytes.
All multibyte values use little endian; reserved fields and padding must be zero.

| Offset | Size | Meaning |
|---|---|---|
| 0 | 1 | Magic `0xA7` |
| 1 | 1 | Major version `1` |
| 2 | 1 | Kind: `1` LayerState, `3` KeyEvent |
| 3 | 1 | Payload length: exactly `4` for both supported kinds |
| 4 | 2 | Sequence, wraps modulo 65536 |
| 6 | 2 | Reserved flags, zero |
| 8 | 4 | Payload |
| 12 | 20 | Zero padding |

KeyEvent payload: pressed (`0` or `1`), key index, current highest layer,
modifier mask. It describes physical input at processor ingestion, before that
input's action is decided. Layer/modifier values are the state before processing
the newly ingested batch. All batch inputs are observed in arrival order exactly
once, including disabled keys and combo components, even if Tap/Hold processing
must retry them. Ingestion assumes that the processor exclusively consumes the
input queue; scanner and split adapters may append events.

LayerState payload: active layer mask (`u16`, including base layer bit 0),
highest active layer (`u8`), modifier mask (`u8`). Emit only when the stable layer
or modifier state changes, after custom callbacks complete. Tick-driven changes
are included. Temporary modifier pulses used to type a shifted character remain
keyboard output commands, rather than persistent modifier state.

Validate nonzero dimensions, key/layer indices, active mask range, base bit, and
agreement between highest layer and mask. LK7 supplies 34 keys and four layers.
The codec supports the model's present bounds of 127 keys and 15 layers without
silently changing firmware index/count types. Message kinds other than 1 and 3
are unsupported. There is no legacy auto-detection.

Literal fixtures (remaining 20 bytes zero):

```text
Q press, base, sequence 0:
A7 01 03 04 00 00 00 00 01 00 00 00
Q release, base, sequence 1:
A7 01 03 04 01 00 00 00 00 00 00 00
Thumb press, base, sequence 2:
A7 01 03 04 02 00 00 00 01 1E 00 00
Arrows active, sequence 3:
A7 01 01 04 03 00 00 00 03 00 01 00
Index 0 press, arrows, sequence 4:
A7 01 03 04 04 00 00 00 01 00 01 00
Index 0 release, arrows, sequence 5:
A7 01 03 04 05 00 00 00 00 00 01 00
Thumb release, arrows, sequence 6:
A7 01 03 04 06 00 00 00 00 1E 01 00
Base restored, sequence 7:
A7 01 01 04 07 00 00 00 01 00 00 00
```

The headless reducer accepts the first sequence as the offline session start,
then requires contiguous sequences, including wraparound. A duplicate or gap
marks the model as needing resynchronization without applying the event. Further
updates are refused until a new model/session is created. Device-driven recovery
will require the later Hello/Snapshot contract; no automatic recovery is claimed.

Observation is optional and independent of CustomFunctions. A sink reports
acceptance with a boolean. Full sinks increase a dropped-event counter, while
sequence numbers advance for every attempted event. Observation never uses the
ordinary USB command queue and cannot return errors into keyboard processing.
