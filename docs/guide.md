# User guide

[Back to README](../README.en.md) | [中文指南](guide.zh-CN.md)

## Install and use

Requires macOS 13+ and Apple Command Line Tools. Only Apple Silicon / macOS 26.4 has been exercised on real hardware. Intel builds are possible; runtime behavior remains unverified.

```bash
bash scripts/check.sh
bash scripts/build.sh
bash scripts/install.sh
open "$HOME/Applications/TinyBar.app"
```

The build uses system frameworks without downloads or dependency installation. It targets the host architecture; use `TINYBAR_ARCH=arm64` or `TINYBAR_ARCH=x86_64` to cross-compile. Signing is local ad hoc signing, without Developer ID or notarization. This is a local build, not a signed distribution. Gatekeeper may block binaries downloaded from someone else.

Installation targets `~/Applications/TinyBar.app`. Quit before updating; previous bundles are retained under `~/Library/Application Support/TinyBar/Backups`. Reinstalling the identical build does not create another backup.

1. Quit other managers such as Ice or Bartender.
2. Reveal the icons and hold Command to drag native menu-bar items.
3. Put occasional items left of `│`, and frequent items to its right. Keep the TinyBar arrow to the right of the divider too.
4. Left-click the arrow to reveal/hide. Right-click or Control-click for settings.

macOS preserves the arrangement. TinyBar does not import Ice groups; arrange its divider once. Launch, restart, wake and display-parameter changes leave items expanded until you hide them again. There is no hover reveal or automatic rehide that could interrupt an open item menu.

## Recovery and quit

Reopen TinyBar from Finder or Spotlight if its control is missing. It reveals items and opens a recovery window. “找回入口” resets only TinyBar's own arrow and divider positions, without writing other apps' preferences.

Choose “展开并退出 TinyBar” from the right-click menu, or “退出” in the recovery window. If unresponsive, end TinyBar in Activity Monitor; macOS removes its status-item windows. Revealing cannot create more screen space: notches and long application menus can still obscure items. This version has no separate floating icon panel.

To return to your previous manager, quit TinyBar first, then open that app. TinyBar does not uninstall it or change its login preference or settings.

## Login startup and uninstall

Login startup is off by default. Enable it manually in the right-click menu; macOS is the source of truth for its state. A pending-approval state includes a link to System Settings, and clicking the toggle again cancels registration. Install in Applications before enabling; do not register a temporary build. A changed ad hoc signature may require approval again; consider disabling before an upgrade and reenabling afterward.

To uninstall, disable login startup, quit, then move `~/Applications/TinyBar.app` to Trash. Preferences remain in the `local.tinybar.app` domain and backups remain in the directory above. The app does not remove them automatically.

## Mechanism, permissions and limits

Two native `NSStatusItem` objects are used. Widening the divider moves items on its left outside the visible bar; reveal restores its width. `NSStatusItem` is public, but this hiding behavior and the initial `NSStatusItem Preferred Position` preference key have no Apple compatibility guarantee. The app checks anchor order and position before hiding, then performs one delayed verification; unsafe layouts stay expanded.

No Accessibility, Screen Recording or administrator permission is requested. No screenshots, network traffic or persisted app inventory. No continuous scanning, global mouse monitoring, helper process or repeating timer. Running bundle IDs are compared transiently at launch/click; app-launch/exit notifications handle later conflicts.

Conflict detection covers only the known IDs in the source, not all managers. The Ice ID was verified from an installed bundle. Candidate IDs for Bartender, Hidden Bar and Dozer have not undergone real-device compatibility testing here. Quit other managers yourself. Newly launched apps may put icons into the hidden group while collapsed.

Horizontal desktop spans above 4488 points are rejected, avoiding displacement onto another screen when the OS limits oversized items. Physical unplugging, main-screen switches, automatic menu-bar hiding, fullscreen and real sleep/wake still need broader coverage. See [validation](validation.md).

## Development checks

```bash
bash scripts/verify.sh
# Run in a logged-in desktop; quit TinyBar and other managers first
bash scripts/verify.sh --integration
bash scripts/recovery.sh
# Sample the running app externally; close its help window and leave it idle
bash scripts/benchmark.sh 300 reports/idle.json
```

Integration uses separate bundle/defaults identity and real fixture items, directly invoking production behavior. It does not simulate Command-drag or establish compatibility for every screen layout. Reports and captures are excluded from Git. The external sampler checks CPU units, guards against PID reuse using process start time, and reports footprint, RSS, CPU and package idle wakeups. It is not shipped inside TinyBar.
