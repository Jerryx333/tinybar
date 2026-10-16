# Notch overflow prototype / 刘海浮层原型

[中文 README](../README.md) | [English README](../README.en.md)

Work in progress on `feat/notch-overflow`. The requirement changed after the native 0.1 baseline: items must be accessible even when the native menu bar has insufficient space around a notch. The separator-only mechanism does not satisfy that requirement.

## Implemented for evaluation

- Left click on a notched display toggles the single icon strip below the menu bar (40 points high, at most 800 points wide, horizontal scrolling). On a display without a notch, left click directly expands/collapses the original menu bar without AX enumeration. The clicked display determines behavior, including when an external display is connected. Option-click or the right-click menu opens the popover on either display. Native expansion alone cannot make every item fit around a notch.
- The popover is a compact native single icon row without headings, item captions or a footer. Reopening within five minutes shows the previous nonempty list immediately, explicitly labeled as updating, while a fresh scan runs. The displayed strip stays fixed for that opening so targets cannot move under a click; the new snapshot is used on the next opening. Explicit refresh replaces the strip with a loading view. The latest metadata snapshot and up to 4 MiB / 128 compact original images are retained for warm opens. Image identity includes the retained AX element, PID, launch date, identifier and size; position changes alone do not invalidate the same item. Images expire after five minutes (evicted on access), or on appearance change, loss of either permission, sleep/wake, display changes or explicit refresh. Views are released on close. Cached images are labeled in tooltips while refreshing and dimmed if refreshing fails; they are not live telemetry. There is no idle timer. Older metadata is discarded on next open; selection always revalidates the original element before acting. The first open and explicit refresh still need enumeration.
- Enumerates original AXExtrasMenuBar items on demand. Each retains its actual AX element and process launch identity; multiple items per application remain separate.
- Shows only the divider’s left group. On macOS 14+, original status-window images are captured once per opening with the public CoreGraphics window-list snapshot API after the user grants Screen Recording. Missing/ambiguous images show short item names; application icons are no longer substituted. These are snapshots, not continuously updated graphs. macOS 13 uses text labels.
- Hovering for 150 ms shows an event-driven application-name label without activating TinyBar. Labels are canceled on exit, scroll, refresh and close; there is no idle timer.
- Selection retains the visible button rectangle and selected display for future placement work, but still opens the original menu through AXPress after revealing the separator. Third-party menus remain anchored to their original status items; in-place opening is unresolved. A local-menu-copy experiment was rejected for shipping because closed menu trees can be stale and dynamic/custom menus are not reliably represented.
- No automatic retry after an ambiguous AX timeout. Reopening the panel invalidates queued clicks. Closing releases panel content and cancels future reads; in-flight IPC is bounded by per-element timeouts.
- No network, disk screenshot files, capture streams or idle scan. Accessibility enumerates/operates original items. Optional Screen Recording reads individual menu-bar windows; the user grants it in System Settings. Capture is serial on a dedicated queue, capped at 128 items with bounded window geometry, with a four-second deadline for starting captures after enumeration. In-flight system requests may finish after cancellation.
- Mouse leaving the strip and its anchor closes it after 250 ms; entering again cancels closure. Pointer position is checked again at the deadline. Mouse event monitors exist only while open.
- Capture matches fresh AX positions to unique layer-25 windows, accepts original owners or Control Center proxies, and rechecks position plus window/process identity after capture. The window-list API uses a null capture rectangle to include offscreen pixels; ScreenCaptureKit returned errors or transparent images for fully offscreen windows on the tested notch display. This deprecated public API is isolated at one compatibility boundary and may need replacement on future macOS versions. Offscreen capture and proxy identity remain OS compatibility limitations requiring real-device validation.

## Verification boundaries

Native builds and baseline layout/CPU-unit checks pass. The enumeration probe reads nonzero offscreen items under the **test launcher's** existing Accessibility permission. This does not establish permission or interaction for the installed TinyBar app launched by Finder/LaunchServices.

The raw AXPress success result does not prove a menu is visible. Popovers anchored to an offscreen item may still fail. Apps with custom mouse handling, missing AXPress, zero-sized AX placeholders, or processes absent from NSWorkspace are not guaranteed usable. The panel reports incomplete enumeration and never replaces a failed menu operation with launching its app.

Do not publish a claim that all notch-hidden items work until these are tested on the installed authorized app:

1. Original NSMenu, action-based menu and NSPopover targets: visible, behind notch, and offscreen.
2. Real application's menus open in a usable onscreen position; multiple status items remain distinguishable.
3. Permission denied/revoked, stale item, restarted process, slow/unresponsive process, repeated open/close/cancel.
4. No click-through or immediate reopening on dismissal; no resource retention after close.
5. Fresh measurement of idle, open panel, repeated open/close and click latency.

## Developer commands

For an installed development build, use an existing Keychain code-signing identity:

```bash
TINYBAR_SIGNING_IDENTITY='<Keychain signing identity or certificate hash>' bash scripts/build.sh
```

Keep the same certificate and bundle identifier for upgrades. The default ad hoc signature is appropriate for build checks, but its designated requirement contains a code hash that changes with the executable. macOS can then show an enabled Accessibility toggle for an old build while denying the current build. Switching from ad hoc to certificate signing requires the user to remove the old Accessibility entry and add the installed app again. Never alter the TCC database or grant permissions automatically. Local signing does not imply notarization or suitability for public distribution.

```bash
bash scripts/build.sh
bash scripts/verify.sh
bash scripts/catalog.sh
bash scripts/menu-fixture.sh
open build/MenuFixture.app
```

`catalog.sh` needs the test launcher's existing Accessibility authorization and does not request or grant permission. `menu-fixture.sh` builds three native targets: F0 original NSMenu, F1 NSPopover, F2 action-based NSMenu. Exit through F0. These fixtures and reports stay outside the shipped application. The application now needs a permission-aware guide before this feature can move to main; the existing README describes the published 0.1 baseline.
