# R5 flashing and running verification contract

2026-10-04, Zig 0.16.0. R-custom accepted on macOS. R5 offline implementation
integrated pending a final live run through the updated root mise entry point.

## Transport decision and evidence

The [RP2040 research](usb-hid-rp2040.md) cites boot ROM sections 2.8.4–2.8.5:
the ROM virtual FAT16 drive consumes valid UF2 blocks and restarts on completion.
[Raspberry Pi's board documentation](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html)
documents mass-storage programming. The [UF2 specification](https://github.com/microsoft/uf2)
defines family metadata and block numbering/counts. Accessed 2026-10-04.

Retain direct filesystem write/sync: two identified coordinator transfers and a
user-operated root mise transfer already restarted this LK7 successfully.
PICOBOOT direct USB could avoid FAT/FSKit but needs a maintained Zig USB backend
and additional interface ownership/transport work. No dependency or C bridge is
added for this recovery. Atomic rename/eject before transfer completion is not
a boot-ROM contract. Restart can remove the mounted drive before macOS eject;
unsafe-removal notifications remain possible. No notification-suppression claim
is made, and no guessed disk settings are changed.

## Preflight, transfer and failure behavior

Validate a retained input snapshot before destination access. Print its path,
byte count and SHA-256. Require complete UF2 headers/trailers, exact RP2040 family
flag/ID, 256-byte payloads, unique complete block numbering, and contiguous
number-to-address mapping starting at 10000000. Support at most 2 MiB of payload;
this is a conservative tool policy, not capacity detection from the 16 MiB XIP
window. Out-of-order file blocks remain valid when their addresses match numbers.

Discovery polls for at most 30 seconds. macOS/Linux label discovery considers
numeric suffixes and rejects multiple candidates; Windows label discovery checks
all matching drives before choosing. An explicit absolute mount selects that
specific volume. Open and hold its directory handle, require exact RP2 model and
RPI-RP2 board lines in INFO_UF2.TXT, and recheck immediately before destination
creation. Generic ROM identity does not identify a keyboard's wiring: the user
must select the intended physical board. This session has one known LK7.

Write directly to firmware.uf2 in chunks, then sync. Production transfer stages
are opening, writing, synchronizing and completed. Errors retain their exact stage.
Check cancellation and a 60-second progress budget between calls and after sync.
Do not label a partial write, failed sync or returned deadline overrun completed.
Keep the exact input snapshot even if another build replaces the source path.

Kernel-blocked open/write/sync cannot be forcibly canceled by these checks.
Ctrl-C is one termination attempt, not proof the syscall stopped. If the process
remains stuck, physically reconnect through BOOTSEL, check that the old writer
exited, then start a fresh identified transfer. Never run a second writer while
the first remains alive. Do not automatically retry or reflash a baseline.

Hardware-free fixtures cover invalid UF2s/address aliasing/flags, absent/wrong
boot identity, missing/unique/multiple volume discovery, access denial, read-only
media, partial writes, disappearance, cancellation between chunks, sync failure,
deadline overrun on return and source replacement. Cross compilation covers
macOS/Linux/Windows; only this Mac has actual device evidence.

## Running verification

`mise run //:flash lk7` builds the matched companion and invokes its headless
`--verify-running` after successful transfer. `flash-file` is transfer-only unless
the user passes `--verify-lk7`, which explicitly checks the current LK7 profile.
Other board/profile verification remains unsupported and must not be reported
as verified. A missing verifier executable fails before destination access.

The existing [SDL enumeration API](https://wiki.libsdl.org/SDL3/SDL_hid_enumerate)
is used with the game-controller-only filter disabled. Select exactly one
FAFA/00F0, FF31/0074 collection, open nonexclusively, use a fresh random session
nonce, then verify board/profile/digest/dimensions and commit a coherent snapshot.
There is no GUI, keyboard collection access, boot request or capture in this mode.
Poll for at most ten seconds; mismatch, ambiguity and timeout return failure.
Native I/O calls can still block; the deadline is not a claim of syscall preemption.

The current accepted identity is LK7/Danish, 34 keys/four layers, digest
`bbf087c054cfb061e04b9dd9e232e0a3`. A live standalone verification passed in
0.48 seconds against the custom candidate. It verifies the running configuration
and responsive protocol, not a cryptographic readback of every executable byte.
Report these three outcomes separately: transfer completed, running identity/
snapshot verified, user-observed typing/custom behavior passed. No exact binary
readback or unsupported-platform success is implied.

## Remaining live acceptance

One identified unchanged custom candidate, one intended BOOTSEL volume, updated
`mise run //:flash lk7`. Stop on first transfer/verification failure; no variants.
Record transfer stages, automatic restart/headless verification, then ask for
ordinary typing and one overlay toggle. The previously accepted candidate remains
available in the ignored recovery cache; physical BOOTSEL is the recovery route.
R-flash is pending this updated entry-point run and user-observed persistence.

## Final root run, 2026-10-04

User entered BOOTSEL on the intended LK7. Exactly one RPI-RP2 volume and its
RP2/v3.0 identity were verified; the artifact hash matched the prepared custom
candidate `c402a55066505d338162e120eac4f038a621d0cee925ca0618f17efe48492263`.
`mise run //:flash lk7` built the matching consumers, validated input, discovered
and identified the volume, opened/wrote/synced successfully, and automatically
ran the headless verifier. The vendor device appeared after restart, expected
LK7/Danish digest and coherent snapshot verified. Entire root command exited 0
in 6.46 seconds (flash/verify task 6.08 seconds). IORegistry reports configuration
1 after restart. No second writer, alternate image or retry was needed.

Companion reopened successfully against the new USB session. User persistence
check (typing/Shift and physical overlay toggle) is pending. Actual disk-removal
notification behavior was not independently observed; notification suppression
remains unsupported. Firmware was unchanged from the previously accepted custom
image; this run validates the updated transfer/verification pipeline.
