# TinyBar

[中文](README.md) | [English](README.en.md)

A planned lightweight, reliable macOS menu-bar manager: hide less-used icons and reveal them with a click.

## Why it exists

Menu-bar space is limited, especially on notched displays and across multiple monitors. When a manager stops responding or cannot enumerate items, hidden apps can become hard to reach. TinyBar aims to prioritize reliable reveal, recovery and low overhead.

## Current status

**Planning stage: no runnable app, installer or verified compatibility claims yet.** This repository currently publishes product scope, technical validation plans and contribution guidance. It is not a finished Ice replacement.

This is an independent implementation plan, not an Ice fork, and contains no Ice code. Any future third-party code reuse must retain its license and provenance.

## First-version scope

- One menu-bar control to reveal or hide items.
- Visible and hidden groups, preserving user arrangement and using native Command-drag where feasible.
- A reachable control after display, resolution and sleep/wake changes.
- Prefer restoring visibility on exit or failure, with an explicit recovery path.
- Native implementation, event-driven where possible; avoid continuous scanning, screenshot caches and unnecessary permissions.

These are planned features requiring verification. The first version excludes separate icon panels, visual themes, search and complex automation. See [product scope](docs/scope.md).

## Get involved

Read the [validation plan](docs/roadmap.md), report reproducible behavior through Issues, or discuss the smallest useful feature set. Include macOS version, chip, display count and exact behavior. Avoid complete menu-bar screenshots or private application lists.

Check repository documentation with `bash scripts/check.sh`. App build instructions will be added when a runnable prototype exists. There is no need to quit or uninstall your current manager now.

Companion project: [TinyStat](https://github.com/Jerryx333/tinystat), a small CPU/GPU/memory and temperature monitor.

License: [Apache-2.0](LICENSE). Copyright 2026 Jerry.
