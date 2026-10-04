# 04: Joint LK7 hardware acceptance on macOS

Status: planned. Depends on 02 and 03. The user has an LK7 and will flash and
verify it with the agent. This is an interactive hardware milestone.

## Outcome and roles

A recorded real-device result for ordinary keyboard behavior and reliable live
monitoring. The user flashes the supplied firmware manually, presses keys,
and reports visible/typed results. The agent prepares identified artifacts,
explains test steps, observes/captures agreed live telemetry where available,
and fixes reproducible problems through focused local commits.

The existing Rollercole Danish-based profile is accepted for this session. Do
not replace it with a guessed US profile or interpret unusual letter placement
as a telemetry defect. No editor is required to complete this milestone.

## Prepare before the session

1. Run `zig build check-full` and build matching LK7 firmware/companion artifacts.
   Record Git revision, Zig/MicroZig versions, profile identity, UF2 path, size,
   SHA-256, and expected negotiated protocol/session data. Do not reuse an old
   artifact merely because its filename matches.
2. Prepare a known rollback UF2 and explain the board's physical recovery/BOOTSEL
   procedure. Hardware mappings must match the user's LK7 revision before a
   flash. Keep user flashing instructions concrete and local.
3. Inspect/document the profile's key positions, layers, custom actions, and BOOT
   combos. The current source includes BOOT on pairs {24,25} and {0,4}; verify
   the current source before the session. Avoid activating reset/BOOT shortcuts
   accidentally while testing simultaneous keys.
4. Record the exact macOS input source, keyboard identification settings where
   relevant, OS version, cable/hub arrangement, and overlay configuration. Explain
   which Danish symbol results require a matching host input source. Telemetry
   highlights can be checked independently of the produced character.
5. Provide a small test worksheet with expected physical indices, profile labels,
   held/released state, active layers/modifiers, and actual results. Select safe
   test text, avoiding sensitive input. Start live recording only explicitly.

## Session sequence

| Test | User action | Required result |
| --- | --- | --- |
| Boot and identity | Manually flash, reconnect, start companion live mode | Keyboard works; expected board/profile/session identity shown |
| Single-key coverage | Press/release each of 34 keys individually | Correct physical key highlighted and released; no swapped halves/thumbs |
| Layer/modifier coverage | Use documented thumb and home-row actions | Stable active layer/modifiers agree with firmware behavior |
| Existing actions | Exercise safe combos, tap/hold, one-shot/autofire if present | Typing behavior preserved; physical telemetry remains coherent |
| Late companion attach | Hold safe keys/layer, then start companion | Initial snapshot shows held state without waiting for another key event |
| Companion restart | Quit/reopen while keyboard stays connected | Typing continues; new session synchronizes |
| USB reconnect | Release keys, unplug/replug; repeat agreed held-key case | Overlay shows disconnect/stale state and recovers correctly |
| Firmware restart | User restarts via agreed physical procedure | Old-session data discarded; correct new state restored |
| Burst and recovery | Type safe rapid sequences; use an explicit diagnostic fault mode only if available | No typing degradation; reported loss recovers without stuck highlights |
| Overlay behavior | Move/scale/configure overlay and switch input source | Compact view remains usable; labels/status update as specified |

Verify ordinary typing first. If it regresses, stop the advanced session, retain
logs, and use the rollback workflow as needed. Do not compensate by changing
debounce/pins/keymap actions without identifying a specific cause.

## Evidence and completion

Keep a concise milestone report inside the repository with actual results,
failures, environment, artifact hashes, and a link to bounded, sanitized capture
fixtures when useful. Avoid committing personal typing logs. A device simulator
or successful compilation does not count as passing these rows.

Turn reproducible failures into offline Zig tests where the boundary allows it.
Commit fixes locally, rerun relevant checks, rebuild and identify the new UF2,
and let the user flash it. Recheck affected manual rows; do not silently mark an
untested fix successful.

Complete when typing/action regressions are absent, identity and snapshots work,
and attach/restart/reconnect/loss recovery produce correct highlights. Record
specific unresolved overlay limitations and their follow-up tasks. If the user
cannot perform a row yet, leave it pending rather than marking it accepted.

Autonomous flashing, remote BOOTSEL requests, unrestricted drive copying,
Windows/Linux validation, other boards, and keymap editing are outside this
session. The next usability milestone is 05's QWERTY/EurKEY Next Mac profile.
