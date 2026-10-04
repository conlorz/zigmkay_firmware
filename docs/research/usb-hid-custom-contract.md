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
The accepted additions bind both-thumbs layer positions 19 to overlay toggle,
24 to log toggle and 29 to shutdown. Position 24 previously held F12 (the earlier
description as empty was incorrect); F12 moves to previously empty position 20.
All base keys stay unchanged. Both firmware and companion import this same keymap,
so their calculated digest changes together; older companions reject the new
identity. Protocol v2 and callback declarations are unchanged. Rebuild both
consumers; do not pair the new firmware with an older companion binary.

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
User approved those three positions. Production processor regression verifies all
three signals have ordered press/release, cannot enter keyboard output, and
absent companion signals do not block normal typing. `mise run //:check-full`
passed with all ten boards, actual wire/report parsing and LK7 standalone parity.
No new C bridge is needed.

## Prepared live custom run

LK7 UF2: 130,560 bytes, SHA-256
`c402a55066505d338162e120eac4f038a621d0cee925ca0618f17efe48492263`.
Matching companion SHA-256:
`fdca395e0e6056087d13da55ed30de230ffb1ced9be64673ea17739547471b2f`.
The previous keyboard-accepted candidate remains in the ignored diagnostic
cache as the identified recovery image. Physical BOOTSEL is the recovery route.

This is a separate custom run after the completed one-flash diagnostic. Use one
identified BOOTSEL volume and the root mise entry point, at most one transfer
with the same 60-second transfer and ten-second configuration bounds. Stop on
failure. Launch the matching companion explicitly in live mode. If recording
is enabled, keep its bounded capture in the ignored cache; type only test text.
Hold thumb positions 30 and 31 for one second, then tap 19 to hide/show twice,
24 to hide/show the log twice, and 29 last to close. Release thumbs after each
action; verify ordinary tap/Shift typing during and after companion use. Record
actual user-observed actions plus session identity/snapshot evidence. Do not
infer R-custom from an offline test or merely a window opening.

R-custom needs actual callback/control behavior with the macOS companion and
concurrent usable typing. Windows/Linux companion access remains unverified.

## Live run started

User confirmed BOOTSEL ready. Coordinator verified one writable RPI-RP2 mount,
RP2 bootloader v3.0/Board-ID RPI-RP2, and both prepared artifact hashes. One
`mise run //:flash-file zig-out/firmware/lk7/zigmkay.uf2 --mount /Volumes/RPI-RP2`
completed write/sync in 4.10 seconds. IORegistry subsequently reports ZigMkay,
configuration 1. Matching GUI started with explicit live access and a five-minute
bounded test capture at `.zig-cache/manual-session/recovery-11/custom-session.bin`.
Actual session identity and user-observed control/input results remain pending.

User reports `disconnected / STALE`; custom controls are not accepted. The saved
200-byte capture has four disconnect records and no connect, send or receive
records. The driver records connect immediately after successful collection open,
so failure occurs in discovery/open before protocol negotiation. IORegistry still
shows configuration 1 and vendor page FF31/usage 0074, with 32-byte reports.
Exact lower Connection/Transport text is requested. The pinned SDL backend uses
nonexclusive macOS HID opens; no permission change or firmware reflash is justified
by this capture alone. Added first-party native open-path/error logging for a
host-only retry. R4 remains active; R5 implementation remains gated.

Host-only tracing identified zero SDL candidates despite IORegistry's vendor
collection. Pinned SDL 3.4.0 `src/hidapi/SDL_hidapi.c`, `OnlyControllersChanged`,
defaults `SDL_HIDAPI_ENUMERATE_ONLY_CONTROLLERS` to true; its ignore predicate
filters FF31/0074. The companion now explicitly sets that existing SDL hint to
false in live mode before initialization. No upstream C or bridge changed.
Selection still requires the exact vendor collection; keyboard/mouse remain
unopened. A host-only retry enumerated FF31/0074 and successfully opened its path.
Matched firmware was not reflashed. User-observed session/control results are
pending; discovery/open alone is not R-custom acceptance.

Fixed companion SHA-256:
`0d2c51da513af2f3075ab9ee7fc8215af3fe3c0c7c2de3466fb03fe536373b34`.
New bounded capture: `.zig-cache/manual-session/recovery-11/custom-session-fixed.bin`.
