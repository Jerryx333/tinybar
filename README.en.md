# TinyBar

[中文](README.md) | [English](README.en.md)

Hide occasional macOS menu-bar icons and reveal them with one click. A small native utility without an extra runtime to install.

## What you get

- One arrow to reveal/hide; Command-drag icons left of the divider to hide, or right to keep visible.
- Reopen TinyBar to reveal items and recover a missing control. Quitting releases its hiding spacer.
- No screenshots, network calls, Accessibility or Screen Recording permission. No background scanning or repeating timers.
- Optional login startup, off by default.

## Status and limitations

**0.1 experimental native app, buildable and locally installable from source.** Repeated hide/reveal behavior has been tested with real menu-bar items. It is not yet a fully validated Ice replacement.

The app uses Swift/AppKit and system frameworks only. See [validation](docs/validation.md) for package size, CPU and memory measurements; scripts ship with the source. The system menu bar still has finite space: a notch or long application menu can obscure icons even when expanded. There is no separate floating icon panel.

Hiding relies on macOS layout behavior without a compatibility guarantee. Launch, wake and display changes favor revealing; unsafe layouts stay expanded. Do not run Ice, Bartender or another manager simultaneously. Existing manager groups are not imported.

## Get started

Requires macOS 13+ and Apple Command Line Tools. Real-device checks currently cover Apple Silicon / macOS 26.4 only; Intel, other OS versions and more display scenarios remain unverified. The app UI is currently Chinese.

```bash
git clone https://github.com/Jerryx333/tinybar.git
cd tinybar
bash scripts/build.sh
bash scripts/install.sh
open "$HOME/Applications/TinyBar.app"
```

Quit other managers, then Command-drag occasional icons left of `│`. Keep the TinyBar arrow on its right. Click the arrow to toggle; right-click for settings and quit.

This is a locally ad hoc signed build without notarization. Read the [guide](docs/guide.md) for upgrades, login startup, recovery and uninstall. The installer retains previous bundles and does not change other apps' settings.

## Develop and contribute

```bash
bash scripts/check.sh
bash scripts/verify.sh
```

[Product scope](docs/scope.md) · [Validation roadmap](docs/roadmap.md) · [Contributing](CONTRIBUTING.md). Include OS version, chip, screen layout and reproduction steps when reporting issues. Avoid private app inventories or complete screen captures.

Independent implementation, containing no Ice code. Companion project: [TinyStat](https://github.com/Jerryx333/tinystat), a small CPU/GPU/memory and temperature monitor.

License: [Apache-2.0](LICENSE). Copyright 2026 Jerry.
