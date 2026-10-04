# LK7 live overlay

The companion defaults to a 760 × 370 resizable window showing the shared LK7
physical geometry, compiled profile, active layer, firmware modifier byte, and
macOS input-source/layout IDs. Default and replay modes never enumerate HID.
Plan 11's Mac/LK7 input, agreed controls and root flash/verify checks passed.
Original milestone 04's broader worksheet remains unaccepted; offline smoke
alone is not hardware acceptance.

From the monorepo root, using mise's pinned Zig 0.16.0:

```sh
mise //zigmkay-companion:test
mise //:companion-run --smoke
mise //:companion-run --smoke --replay tests/fixtures/lk7_trace.bin
mise //:companion-run --smoke --session-replay zigmkay-companion/.zig-cache/lk7-overlay-timed-fixture.bin
```

The test command creates the timed fixture in its build cache. Both replay smoke
commands render exactly three frames and exit. `--replay` retains strict v1
32-byte framing and reducer behavior. `--session-replay` is the timed format
below and can intentionally end stale/disconnected. The headless executable's
`--session` remains a separate deterministic device-report fixture mode with
1 ms per report; it cannot reproduce arbitrary live recordings.

## Explicit live session

Only run these commands during an explicitly requested hardware session:

```sh
mise //:companion-run --live
mise //:companion-run --live --device-path 'PATH_PRINTED_BY_THE_OVERLAY'
```

Selection requires VID/PID FAFA:00F0 and usage FF31:0074. Keyboard, mouse and other
composite collections are excluded. A sole candidate opens automatically; multiple
candidates remain disconnected until an exact `--device-path` is supplied.
Up to eight candidate paths shorter than 512 bytes are shown; the ambiguity count
still considers all matching collections. A missing selected path displays
`path_not_found`. No candidate is chosen arbitrarily.

## LK7 companion keys

Hold the left Enter and right Space thumbs nearest the center gap for one second,
then tap the action key. Release the thumbs after each action.

| Action | Physical position on the base layout |
| --- | --- |
| Hide/show overlay | Right half, middle row, far-right Y |
| Show/hide event log | Left half, bottom row, innermost V |
| Close companion | Right half, bottom row, far-right Z |

On this both-thumbs layer, F12 is at the left bottom-row outermost key. Ordinary
base keys are unchanged. Firmware and companion must be rebuilt together because
these additions change the shared layout digest.

`mise run //:flash lk7` now verifies running board/profile/layout identity and a
coherent snapshot after transfer. `zig-out/bin/zigmkay_companion --verify-running`
performs that check without opening a window. It is not executable-byte readback.

The adapter sends Hello, compares the complete compiled board/profile/dimensions/
digest identity, and obtains a held-key snapshot before showing a current live
view. `negotiating` and `incompatible` suppress keyboard labels; mismatch tells
the user to install matching firmware and retry. The Reconnect button closes the
current device and schedules fresh negotiation. Missing devices, open/read/write
failure and unplugging keep the UI alive with status and an automatic 1 s retry.
Protocol diagnostics are historical and can remain displayed after recovery.

Disconnect, sequence loss, malformed framing, interrupted snapshots and timeout
leave the last complete state explicitly `STALE`; pressed highlights are suppressed
until a complete compatible replacement snapshot commits. Firmware modifiers,
physical presses, HID codes and OS labels remain separate. Layer/key labels use
stable physical IDs and key_index, not processor side tags. Shared positions,
width, height and degree rotation fit the resized window bounds. Geometry remains
schematic; physical accuracy and rotated raster presentation need manual review.

All mutation occurs on the UI thread. A poll drains at most 32 reports and 2 ms
of nonblocking reads, stopping early for UI signal handling. Native writes prepend
zero report ID, exactly 33 bytes. Reads accept exactly 32 bytes or a 33-byte form
with a zero prefix; other lengths trigger malformed-frame recovery. Actual macOS
SDL report-ID behavior is still a manual check. SDL's macOS Output SetReport write
is synchronous and can wait in the OS USB implementation; the read drain budget
does not bound native write latency. No application sleep/retry wait blocks the UI.
Nonce allocation starts from OS secure randomness, advances for negotiations,
skips zero, and refuses exhaustion instead of reusing queued-traffic tokens.

## Window and labels

Supported mise settings are `--position-x X --position-y Y`, `--opacity 0.1..1`, `--no-top`,
`--unfocusable`, and `--borderless`. Defaults are opacity 0.94, always-on-top,
focusable, and a title bar that supports moving/resizing/closing. Close and
Reconnect controls remain in the overlay. Borderless placement can be configured
through CLI; keep the title bar for interactive dragging. A failed SDL setter
produces a visible window fallback message. Preferences are not persisted.

`--click-through` displays an explicit unsupported fallback and retains ordinary
mouse interaction. The pinned API does not provide verified macOS whole-window
click-through here; no C/Objective-C glue was added. Focusability is configurable,
but focus stealing, Space/fullscreen behavior, opacity, topmost behavior and
unfocusable controls require manual macOS checks. A title bar and focusable mode
are the supported fallback.

macOS labels call existing Carbon/CoreFoundation system APIs directly from Zig.
Translation uses a local zero dead-key state and the no-dead-keys option, never
the imported C backend's stateful composition context. Shift/Option/Control/Command
are supplied to translation; fixed labels bypass OS translation. Both active
input-source and fallback keyboard-layout changes are polled every 500 ms, with
atomic replacement of the label cache. IME text composition and actual shortcut
output are not inferred from labels. Windows/Linux retain the existing backend
with isolated per-label reset; their input-source detection remains later work.
Event-log labels reuse the cache. Fixture tests cover fixed labels, Shift, Option,
Command, dead labels and rebuilding after a source change; Danish/EurKEY Next
native symbols and actual source switching still need the user's macOS session.

## Bounded recording and offline reproduction

Recording is explicitly opt-in and limited to the requested live test interval:

```sh
mise //:companion-run --live --capture /tmp/lk7-test.capture --capture-ms 30000
mise //:companion-run --session-replay /tmp/lk7-test.capture
```

`--capture` requires `--live`. Duration defaults to 30 s, accepts 1..300000 ms,
and recording stops earlier when its 4096-record capacity fills or the window
closes. The bounded allocation/file limit is 196616 bytes. A file is written once
on stopping/closing, never as background typing after the interval. The requested
output path is replaced if it exists. Save failure is visible. The in-memory
100-event debug log is independent and does not persist typing.

The binary format starts with ASCII `ZMKCAP01`, followed by fixed 48-byte records:
monotonic milliseconds u64 little endian, kind u8, length u8, up to 33 payload
bytes, then zero padding. Kinds are connect=1 (nonce u32), tick=2 (fresh nonce u32
or zero), receive=3 (portable decoder input), disconnect=4 (empty), send=5 (33-byte
zero-ID host report). Native invalid framing is captured as the empty malformed
portable input that entered recovery. No labels or OS composition are recorded.
Elapsed tick times and fresh negotiation tokens reproduce timeout/restart behavior;
host sends are checked byte-for-byte against replayed Session actions. Disconnects
reproduce stale retained state. Invalid versions, lengths, padding, time regression,
controls or file size fail explicitly. Capacity can end mid-transition; replay
retains that terminal stale state rather than claiming success.

The recording reproduces session/model behavior, not USB scheduling, OS window
behavior, labels or native write latency. The user should capture a short attach,
held-key, unplug/replug or restart scenario only during an agreed test session.
