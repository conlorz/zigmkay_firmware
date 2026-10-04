# R4 custom action and companion contract

2026-10-04. R-keyboard is accepted on macOS. R-custom is not yet accepted.
This inventory retains protocol v2; no USB usage or packet migration is required.

## Producers and consumers

The LK7 shared profile's callback IDs 1–4 are internal actions, not USB usages:
gaming enable/disable, layer-thumb state, equal-column insertion, and Alt-Tab.
Layer thumbs select arrows, numbers or both; equal-column inserts space/colon/
equals/space; Alt-Tab releases Alt when its layer thumb is released. Gaming
references layer 4 while only four layers (0–3) exist: do not expose it as a
validated action or add another gaming binding without resolving that mismatch.
The profile has no reserved companion-control binding at this checkpoint.

`zigmkay/src/processing.zig` sends custom press/release intents through
`OutputCommandQueue.send_companion_custom`. Recognized reserved IDs become
log-toggle, overlay-toggle or shutdown signals in `telemetry_transport.zig`.
Other IDs remain callback-local. Legacy companion/shutdown key sentinels are
intercepted internally; they must never become keyboard-page USB usages.
`macros.SIG` creates a custom tap and thus uses the same reserved-ID dispatch;
it does not automatically assign meaning to arbitrary callback IDs.

The companion model checks session identity and event sequence, acts on pressed
edges and tracks releases. `zigmkay-companion/src/live_adapter.zig` bounds draining
and stops before its UI signal queue can overflow. `main.zig` consumes signals to
toggle the log, toggle visibility or close the app. Closing the app must leave
normal keyboard input operational.

## Wire boundary

Use VID FAFA/PID 00F0, vendor usage page FF31/usage 0074, interface 3. Reports
are unnumbered, exactly 32 bytes in and out, on interrupt endpoints 88/07.
The native SDL host API writes a leading zero report-ID byte plus those 32 bytes;
received frames permit exactly 32 bytes or 33 with leading zero. No nonzero ID
or shortened/oversized frame is accepted. HID control SetReport reaches the same
validated output cache/transport boundary; keyboard and vendor collections are
selected separately. Native collection discovery rejects ambiguous devices
unless the exact vendor collection path is supplied.

Protocol v2 hello/identity/snapshot/session, event sequencing and acknowledgment
remain unchanged. Identity/snapshot transactions have explicit request IDs;
signals are sequenced events, not independently acknowledged commands. Snapshot
recovery suppresses uncertain signal intent rather than replaying a toggle.
Firmware uses bounded telemetry queues, and keyboard reports have an independent
nonblocking path. Disconnected companions do not make typing wait for telemetry.

## Remaining execution

Review existing production regressions for malformed packets, identity mismatch,
absent/disconnected companion, overflow, recovery, acknowledgments and signals.
Scoped firmware, protocol, companion-model and GUI Zig tests passed. The user
used `mise run //:flash lk7`; the current output UF2 has the same SHA-256 as the
identified diagnostic candidate (no source changes intervened). This is artifact
and user-observed restart evidence, not cryptographic running-device readback.
Keymap placement for the absent companion controls is a pending user
preference; any addition changes the shared digest in both firmware and companion
and must be documented before integration. No new C bridge is needed.

R-custom needs actual callback/control behavior with the macOS companion and
concurrent usable typing. Windows/Linux companion access remains unverified.
