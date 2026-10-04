# 03 handover: macOS live overlay

State: **Not produced**. No implementation commits or checks are recorded.
Producer: companion worker. Reviewer: coordinator.
Plan: [03](../03-macos-live-overlay.md). Rules: [handover format](README.md).

## Required input and output

Input: accepted [01 contract](01-protocol.md), shared physical geometry, and
[02 firmware metadata](02-firmware.md) for final joint integration. The worker
may implement fake-backed behavior before 02 is complete.

Publish HID adapter selection/error/report framing, session/reconnect behavior,
bounded report draining, physical-ID rendering, label/input-source refresh,
compact-window settings, and supported macOS fallback limitations. Provide
actual GUI/offline replay/smoke commands and fake adapter/render/label evidence.
Document explicit recording and manual-test instructions for 04.

## Consumers and gate

- [04 hardware](../04-lk7-hardware-acceptance.md): uses the integrated GUI/firmware
  revision and checks real attach/recovery, labels, geometry, and window behavior.
- [06 research](../06-editor-architecture-research.md): audits actual native UI
  capabilities and remaining constraints rather than assumed functionality.
- [07 editor](../07-compiled-keymap-editor.md): later reuses rendering/UI lifecycle.

Acceptance completes 03's offline criteria. With accepted 02 and joint checks,
it releases **G-live-offline**. Real device/window behavior remains pending 04.
Release companion ownership before profile/editor integration changes its files.

## Integrated result

Pending. Complete the [result template](README.md) at submission/integration.
