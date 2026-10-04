# 08 handover: build, transfer, and running firmware verification

State: **Not produced**. Backend, GUI integration, and hardware results are separate.
Producer: assigned 08A/08B workers; coordinator leads the hardware session.
Plan: [08](../08-build-and-flash-workflow.md). Rules: [handover format](README.md).

## 08A: offline backend handover

Input: accepted [05 selector/identity](05-keymap.md),
[06 decision](06-architecture.md), and [07A export contract](07-editor.md).
Publish argv/process API, validation/export ownership, cancellation/error
semantics, manifest fields linking existing profile/project identity to UF2 hash,
selection/verification limits, fake process/filesystem/volume adapters, and
offline failure/cancellation/stale/multiple-device test results.

This backend may run alongside 07B on disjoint files. No GUI changes, real device
enumeration, BOOTSEL, or flashing belong to 08A. Partial acceptance does not
release G08; record its contract for 08B instead.

## 08B and complete milestone handover

Input: accepted full [07](07-editor.md) and accepted 08A; GUI ownership transferred.
Publish user build/select/flash/reconnect workflow, exact commands and recovery
instructions, integrated offline checks, and actual separately requested manual
session. Record artifact manifest/hash, file transfer, running negotiated identity,
and user typing results distinctly. Pending manual steps remain pending.

All 08 criteria release **G08**. [09 expansion](../09-platform-and-board-expansion.md)
uses the implementation/verification boundaries for future platform/board plans.
No unattended updates or other flash protocols are implied.

## Integrated result

08A: pending. 08B/offline: pending. Manual/full 08: pending user session.
Complete separate sections using the [result template](README.md).
