# USB HID platform matching and application access

Research date: 2026-10-04. This is an offline assessment, not hardware acceptance.
Baseline inspected: recovery handoff for `637fd71` and first-party source in
`zigmkay/src/usb_if.zig`, `layout-model/src/types.zig`,
`device-protocol/src/root.zig`, and `zigmkay-companion/src/live_adapter.zig`.
USB/HID normative and controller research is recorded separately. Platform
documentation describes implementation behavior; it does not relax USB/HID rules.

## Sources and scope

All sources below were accessed on 2026-10-04. Living documentation without a
published release is explicitly identified; its behavior must be checked against
the actual OS/build during an authorized session.

| ID | Primary source/version | Supporting section |
| --- | --- | --- |
| A1 | [Apple accessory approval](https://support.apple.com/en-us/102282), living support article | Allow accessories; Apple silicon **laptops**, locked state, approval settings |
| A2 | [Apple Input Monitoring](https://support.apple.com/en-au/guide/mac-help/mchl4cedafb6/26/mac/26), macOS 26 guide | App monitoring of keyboard/mouse/trackpad across applications |
| A3 | [IOHIDDeviceOpen](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen), living API reference | Discussion: ordinary open versus exclusive `kIOHIDOptionsTypeSeizeDevice` |
| A4 | [Advances in macOS Security](https://developer.apple.com/videos/play/wwdc2019/701/), WWDC 2019 session 701 | Input monitoring authorization; `IOHIDCheckAccess`/`IOHIDRequestAccess` |
| A5 | [Apple IOHIDInterface source](https://github.com/apple-oss-distributions/IOHIDFamily/blob/main/IOHIDFamily/IOHIDInterface.cpp), mutable published main | `matchPropertyTable`, `open`, `openGated`: interface/provider matching and owner open |
| A6 | [IOUSBHostDevice](https://developer.apple.com/documentation/usbdriverkit/iousbhostdevice), living DriverKit reference | System creates USB provider during matching; not a specification of current kernel configuration retry policy |
| W1 | [Composite enumeration](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/enumeration-of-the-composite-parent-device), living Microsoft Learn | Conditions for `USB\\COMPOSITE`, generic parent `Usbccgp.sys`, INF overrides |
| W2 | [Top-level collections](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/top-level-collections), updated 2024-06-27 | HIDClass creates separate PDO per top-level collection |
| W3 | [System-owned collections](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/top-level-collections-opened-by-windows-for-system-use), updated 2024-01-11 | Keyboard/mouse exclusive; consumer control shared |
| L1 | [Linux HID introduction](https://docs.kernel.org/hid/hidintro.html), living kernel docs | Parsing; reports; collections/report IDs; evdev; quirks |
| L2 | [Linux hidraw](https://docs.kernel.org/hid/hidraw.html), living kernel docs | Discovery, read/write, feature/output ioctls |
| L3 | [Linux usbmon](https://docs.kernel.org/usb/usbmon.html), living kernel docs | Capture model and limitations: URB requests/completions, not guaranteed bus-level truth |
| B1 | [Chrome WebHID documentation source](https://github.com/GoogleChrome/developer.chrome.com/blob/main/site/en/articles/hid/index.md), mutable published main | Protected top-level usages and device blocklists |

A5 and B1 are implementation references inspected at mutable URLs, not immutable
dependency candidates or proof of the installed macOS/Brave versions. Apple's
legacy [IOUSBFamily](https://github.com/apple-oss-distributions/IOUSBFamily) is
historical source and is not treated as the contemporary IOUSBHost implementation.
No platform bug report has been established as applicable to this device.

## macOS: distinguish the failure stages

The existing observation is a configuration selection followed by EP0 timeouts
and no configured HID interface children (handoff). Product-string discovery
precedes successful configuration and HID report parsing. It does not prove the
keyboard driver attached. A6 describes USB matching, and A5 shows a distinct HID
provider/interface matching and ownership layer. Neither source establishes the
exact request that timed out; capture or device instrumentation must do that.

A1 restricts its approval discussion to Apple silicon laptops. Whether this
machine meets that scope and whether an approval was denied must be recorded,
not guessed. Known descriptor/control traffic is evidence of some USB access;
it is not a blanket guarantee about every later access policy.

A2/A4 concern an **application monitoring input**, whereas the recovery baseline
requires keyboard typing without a companion. Therefore changing Input
Monitoring, Accessibility or Full Disk Access is not an evidence-backed remedy
for the observed configuration timeout. This is a stage-based inference, not a
claim that no macOS security policy can ever affect USB.

For companion access, match the vendor collection, use ordinary nonseizing HID
open, and report the exact native open/read/write result. A3 explicitly exposes
exclusive seizure; choosing it can change ownership. A5 delegates interface
open to its owner, so a successful device discovery does not guarantee open.
The vendor-only companion must not open the keyboard or mouse collection to
monitor ordinary input. Whether vendor-only access triggers a particular TCC
policy on the installed OS remains unverified; do not prescribe permissions
before observing its failure and authorization state.

Browser access has another policy layer. B1 blocks access to reports in protected
keyboard/mouse collections. A vendor collection is the appropriate WebHID target
if a browser companion is later selected, but browser permission and blocklists
still apply. The native SDL companion and WebHID are different clients. The
recorded Brave ownership conflict is evidence of an open conflict at that time,
not proof that Brave caused the firmware's configuration failure; quitting it
and reconnecting did not fix the failure.

## Windows and Linux

W1 requires multiple interfaces, one configuration and a suitable device class
for default composite parent matching. The current source declares one
configuration and an unspecified device triple. W2 discovers collections rather
than assuming every VID/PID match is a keyboard. W3 makes a separate vendor
collection essential for application communications: ordinary keyboard and
mouse collections are system-owned exclusively. Installing a WinUSB override
on the keyboard interface would change driver binding and is not the baseline.
No original known-good Windows binary or trace is available; rebuilding old
source with today's compiler is not that reference.

L1 places descriptor parsing and conversion to input events in the HID stack.
Wrong descriptor semantics can therefore produce wrong/missing input even when
raw bytes are observable. For a relative mouse, X/Y/wheel/pan must be described
consistently with delta reports. Vendor traffic should use hidraw, while normal
typing uses the input subsystem.

L2 documents dynamic hidraw node allocation; discover by properties rather than
hard-coded `/dev/hidraw0`. Access rights depend on distribution/udev policy and
the process's rights. A hidraw permission failure does not establish failure of
kernel keyboard input. Restrict any eventual rule to the intended identity and
collection; document it after checking the actual distribution.

Host API framing differs from firmware framing. L2's unnumbered `write` buffer
has a leading zero before report data; its input report does not. USB output goes
through interrupt OUT when available, otherwise `SET_REPORT` on control. Feature
reports use control. The existing companion constructs a 33-byte native write
for a 32-byte unnumbered vendor report. That prefix is API metadata, not a new
USB report byte; validate SDL/macOS handling independently. The current firmware
must accept its declared 32-byte report through both selected output paths.

## Platform matrix

`Unverified` means no accepted real device run on that platform. macOS failure
observations are from the handoff, not newly reproduced during this research.

| Requirement / contract | Current behavior | macOS | Windows | Linux | Evidence | Proposed treatment | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Valid descriptor bytes and successful configuration | Wire serialization repaired 146-byte parsing; configuration still times out | Observed failure before HID attachment | Unverified | Unverified | Handoff; A6; W1 | Repair production control/driver boundary before permissions changes | Exact SETUP/completion trace, configuration readback, interface children |
| Boot keyboard wire format and protocol | Advertises boot; seven-byte input lacks reserved byte | Unverified input | Unverified; earlier working claim has no reference binary | Unverified | `usb_if.zig`; normative HID research | Standard eight-byte keyboard and correct protocol requests | Offline byte/protocol checks, press/release/modifier run without companion |
| Report descriptor semantics agree with payload | Consumer two-byte selector; mouse five-byte report; X/Y generated dynamic fields need semantic audit | Unverified | Unverified | Unverified | Source; L1 | Explicitly relative mouse deltas; no dummy undeclared output acceptance | Independent parse and each input action |
| Separate vendor application collection | FF31:0074, 32-byte IN/OUT, no report IDs | Unverified native access | Unverified; avoids system keyboard ownership by design | Unverified hidraw access | Source; A3/A5; W2/W3; L2 | Preserve collection identity; ordinary nonseizing vendor-only open | Enumerate usage, inspect selected path, keyboard remains usable |
| Control and interrupt output agree | Wrapper handles vendor output; target timing unverified | SDL control output path unverified | Unverified | hidraw chooses interrupt OUT if available; device unverified | `docs/live-overlay.md`; L2 | Keep payload exactly 32 bytes; validate report type/ID/length | Both delivery routes; bad ID/type/length; reconnect |
| Permissions belong to the failing layer | No HID attachment in known macOS failure | Accessory approval applicability unknown; app monitoring separate | Driver/collection ownership distinct | hidraw node rights distinct | A1–A4; W3; L2 | Record actual denial and scope; no broad grants | USB configured first; then native open/read/write status |
| Multiple-device selection | VID/PID shared; serial fixed 00000001; adapter requires path when ambiguous | Unverified actual paths | Unverified | Unverified dynamic nodes | `live_adapter.zig`; `usb_if.zig`; L2 | Preserve explicit path selection, negotiate full identity | Two candidates, missing path, reconnect identity mismatch |
| Browser access independent of kernel typing | Brave opened after composite failure; restart without Brave still failed | No causal proof | Unverified | Unverified | Handoff; B1 | No browser required for baseline; vendor-only if used later | Kernel-only input first; native/browser sessions separately |

## Custom signal inventory and boundary

`layout-model/src/types.zig` defines internal tap sentinels FC (BOOT), FD (print
statistics), FE (companion toggle), FF (companion shutdown). `TapDef.custom`
reserves FD (log toggle), FE (shutdown), FF (overlay toggle); these are a distinct
namespace. `zigmkay/src/core.zig` maps custom actions to vendor protocol signals.
`device-protocol/src/root.zig` defines signal kinds 1 log toggle, 2 overlay toggle,
3 shutdown with a pressed boolean; the companion acts on these session packets.
Do not transmit these sentinels as proprietary keyboard-page usages. The
standard keyboard usage map, internal actions, vendor protocol and OS layout
must remain distinct. R4 needs a complete producer/consumer audit after typing
acceptance, including obsolete legacy paths and press/release behavior.

## Finite platform verification

The authorized diagnostic session should first identify OS/build, machine model,
firmware hash and selected physical device; capture configuration/HID attachment
without launching a companion. Test ordinary press/release/modifiers and unplug
recovery. Only after that gate, open the exact vendor collection, inspect native
read/write framing and output route, and verify typing continues during session
absence, failure and reconnect. Record native error codes before changing access
settings. Windows should record composite parent, collection paths and drivers;
Linux should record usbcore/usbhid attachment, descriptor, input events and
hidraw node rights. L3 usbmon can identify submitted control requests and their
completion status on Linux, but is not proof of individual wire packets or
device-side execution. OS logs alone cannot distinguish every firmware hang.

No hardware operations were performed for this document. macOS, Windows and
Linux functional compatibility and all companion live access remain unverified.
