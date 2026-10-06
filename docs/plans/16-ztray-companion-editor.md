# 16: Native tray for the companion and editor

Status: implemented locally following the user's 2026-10-07 implementation
request. Offline verification is recorded in the central tracker. Hardware and
Windows/Linux desktop acceptance remain separate tasks.

## Goal and agreed behavior

One native ztray icon belongs to each running desktop process. On macOS it
appears in the top bar with a keyboard icon and tooltip “Zigmkay is running”.
Its presence means the application is running, independently of device state.

The context menu contains disabled companion-mode/device-status rows, Open
Editor, Show Companion / Hide Companion, a separator and Quit Zigmkay. Device
status distinguishes offline, connecting, live, stale, disconnected and
incompatible. Only changed displayed state rebuilds the menu.

Normal companion startup shows the companion; normal `--editor` startup shows
the editor and hides the companion. Open Editor creates it lazily or reveals
and focuses the existing window. Closing windows hides them and preserves the
editor draft, history and pending work. Hiding releases preview input and pauses
practice. Quit reveals the editor's existing pending-edit/unsaved-project
confirmation and respects native-dialog/transfer guards. Cancellation keeps the
process running; successful quit removes the tray and releases resources.

## Implementation

- Pin [ztray](https://github.com/StaffinityAI/ztray) revision
  `45877349ae4303a99008b86bf28411638889380e` with verified package hash
  `ztray-0.1.0-dev.1-HZHL7Ia4BwBeGve2XpCeCR0cQ_5xTdupgMzOyceJ6BeY`.
  The companion build publisher creates native zmenu/ztray modules using the
  dependency's builder and matching host/optimization settings. The current
  root delegates package builds through mise; no duplicate root dependency is
  needed. Existing editor menus/window styling remain intact.
- `zigmkay-companion/src/desktop.zig` owns stable action IDs, lifecycle state,
  cached status menus and a generic adapter with a fake backend. All native
  operations and state changes remain on the owning SDL UI thread.
- Normal editor startup shares the companion's desktop loop. Editor document
  lifetime is independent of visibility; child windows remain allocated while
  hidden. Existing fixture, screenshot, scenario and verification entry points
  retain the dedicated finite editor runner.
- SDL dispatches AppKit/Win32 events, including native tray callbacks. Avoid
  ztray's additional AppKit pump (up to 50 ms blocking) and Win32 pump (which
  could consume SDL messages). Pump ztray's shared D-Bus connection on Linux.
  Idle waits are bounded to 100 ms, including when both windows are hidden.
- Retain explicit `--live` startup opt-in and existing identity verification
  after a deliberately completed editor flash. Showing a window does not enable
  HID, build firmware, enter bootloader mode or flash.
- Installation/menu failure removes tray residency and retains accessible
  window behavior. Smoke/capture/editor acceptance modes disable tray residency.
  The explicit offline macOS `--tray-check` is a finite native integration probe
  using an inert editor fixture and real AppKit callbacks.
- `tray_icon.zig` embeds a compile-time Zig-generated RGBA PNG, with dark outlines
  and white keycaps. No new first-party language or bridge implementation is
  introduced; upstream native ztray bridges remain unchanged.

## Verification

Use the pinned Zig 0.16.0 compiler:

```sh
mise //zigmkay-companion:test
mise //zigmkay-companion:build
zig-out/bin/zigmkay_companion --tray-check
zig-out/bin/zigmkay_companion --smoke
zig-out/bin/zigmkay_companion --editor-overlay-smoke
mise //zigmkay-companion:editor-check
mise //:check
mise //:check-full
git diff --check
```

Run `zig fmt --check` for changed Zig files. Keep captures/logs in build caches;
do not regenerate approved screenshot goldens.

Fake-backend tests cover hidden residency, repeated Open Editor actions, canceled
quit, finite modes, install/menu failures, status-menu caching, action polling
and exactly-once teardown. Decode the embedded PNG to verify its dimensions and
transparency. The native probe checks real tray action callbacks, close/hide,
same-window reopening, retained draft/history/free text, SDL keyboard routing,
unsaved-quit cancellation, active-transfer rejection and final shutdown.

Native probe callbacks and semantic input do not substitute for user visual
approval of the top-bar icon or physical mouse interaction. Windows/Linux
native desktop behavior remains unvalidated. Linux requires a desktop
StatusNotifier watcher; ztray may install successfully without a visible icon
when that watcher is absent.

## Boundaries

No hardware session, autonomous flashing, push or pull request is included.
Login launch, installers, cross-process single-instance enforcement, new native
editor menus and tray flashing controls are outside this change. Keep upstream
bridges intact and all first-party implementation/tests in Zig.
