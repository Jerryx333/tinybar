# Product scope / 产品范围

[中文 README](../README.md) | [English README](../README.en.md)

Status: experimental native prototype. This file defines goals; actual coverage and limitations are recorded in [validation](validation.md).

## 用户需要 / User need

Hide occasional menu-bar items without losing access to them. Keep the reveal control reachable, remember arrangement, recover after screen changes, and keep resource use small.

## MVP

| Capability | Acceptance |
|---|---|
| Reveal/hide | One click changes visibility; repeated clicks do not wedge the main thread |
| Arrangement | User can place items in visible/hidden groups; restarts do not overwrite deliberate positioning |
| Displays | Validate internal/notched/external displays, main-display changes, scaling and unplugging |
| Recovery | A documented path reveals items after a failed operation; normal quit releases hiding controls |
| Startup | Off by default, optional and reversible |
| Privacy | Local-only; no telemetry, accounts, uploaded screenshots or stored app inventory |

No separate icon mirror panel in the first version. Clicks should reach the original app's status item where feasible. No promise that public AppKit APIs can implement every desired behavior; validate that boundary before selecting a mechanism.

## Engineering constraints

Prefer Swift/AppKit, one process, system frameworks and event-driven updates. Do not introduce a periodic screenshot/enumeration loop simply to discover whether anything changed. Bound caches and retry attempts; never wait synchronously on work that depends on the main queue.

Hiding other applications' status items may depend on undocumented OS behavior. The prototype uses a separator-width technique, which is not an established portable API. Validate conflicts with existing managers before adopting it. Do not assume status-item identity or accessibility permissions solve all layout operations.

Use least necessary permissions, with a reason tied to an implemented capability. Do not request screen recording for a design that never captures pixels. If experimentation shows another permission is required, document the evidence before adding it.

## Performance targets, not measurements

Initial budgets: app bundle ≤5 MB, steady idle CPU ≤0.1% of one core, idle physical footprint ≤30 MiB. Report RSS separately. Measure cold launch, long idle, repeated toggling, large item counts, screen transitions and wakeups. Targets may be revised with explicit evidence; see [measurements](validation.md).
