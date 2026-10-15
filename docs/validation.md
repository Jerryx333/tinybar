# Validation / 验证记录

[中文 README](../README.md) | [English README](../README.en.md)

Experimental 0.1, measured 2026-10-15. Native Swift/AppKit, no third-party runtime. Three independent read-only reviews covered architecture, implementation and final state-machine/test changes; concrete findings were fixed and the strengthened tests rerun. Hardware: Apple M1 Max, macOS 26.4 (25E246), two displays: internal notched 1728 × 1117 points and external 2560 × 1440 above it. These observations do not establish support for other OS versions or display layouts.

## Functional evidence

| Check | Evidence / boundary |
|---|---|
| Hide/reveal | 20 cycles with five real fixture NSStatusItems; all hidden rectangles must have zero intersection with every screen; relative arrangement restored. Whole-group translation is allowed because system icons may change width. |
| Reversed anchors | Both anchors visible; reversed-order precondition and specific rejection message checked before hide; reset then successfully hides. |
| Fast clicks | Immediate reveal/hide queues a bounded layout wait; subsequent reveal cancels it. No repeated timer. |
| Failed postcheck | Fixture forces short divider after hide; settled verification reveals again. |
| Screen/wake handler | Synthetic notifications invoke the real observers; fixture rectangles restore. This does **not** prove physical unplug or sleep/wake. |
| Reopen recovery | Real LaunchServices `open` on the running, collapsed test bundle restores a separate process’s hidden fixtures; the recovery window opens. A deliberately inaccessible control and Finder/Spotlight UI paths still need wider verification. |
| Normal quit | Separate fixture process observes visible → hidden → visible across NSRunningApplication termination of the manager. |
| Forced end | Same independent fixture remains alive across SIGKILL of the owned manager child; icons become visible again. |
| Installer | Fresh install, no-op repeat, and upgrade retaining the previous bundle/archive checked locally. |
| Permissions | No permission prompt or privacy API in application code. Test automation uses the developer's existing automation environment, not app permissions. |

The integration suite operates its own fixtures. It does not reposition other apps programmatically. A failed assertion exits nonzero; timeouts are bounded. Test binaries use a separate bundle/defaults domain and do not ship in TinyBar.

## Resource measurements

Sampling is external (`scripts/measure.c`), once per second, guarded by process start time. CPU means process user+system CPU divided by elapsed time, as a percentage of one core. CPU timebase conversion is checked against `getrusage` with a brief busy loop before sampling. Memory numbers are MiB (2²⁰ bytes). Package idle wakeups are a kernel counter, **not all run-loop wakeups or all machine wakeups**.

Early native build before final menu/recovery fixes, app window closed:

| State | Duration | CPU time | CPU / one core | Footprint at end | Sampled peak footprint | RSS at end | Sampled peak RSS | Package idle wakeups |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Fresh process, expanded | 120.005 s | 0.116176 s | 0.096809% | 15.50 MiB | 15.80 MiB | 32.23 MiB | 44.19 MiB | 0 |
| Warm idle, expanded | 300.004 s | 0.222735 s | 0.074244% | 15.69 MiB | 16.17 MiB | 33.28 MiB | 39.84 MiB | 0 |

These runs were on a working desktop, not an isolated laboratory. Interaction-heavy exploratory runs reached higher CPU and memory; they are not idle baselines. Retained help-window memory was removed afterward. Final runtime build (same behavior as the final source except an accessibility label/comment), expanded with help closed: 120.005 s, 0.063676 s CPU, **0.053062% of one core**, end footprint **14.97 MiB**, sampled peak footprint 15.20 MiB, lifetime peak footprint 15.52 MiB, end RSS 36.33 MiB, sampled peak RSS 42.59 MiB, package idle wakeups 0.

Final arm64 app bundle: **147,684 logical bytes**, approximately **152 KiB allocated**. Binaries, samplers and test fixtures are not committed. Collapsed-state idle and extended UI-session peaks have not yet been measured in this record.

Budgets: bundle ≤5 MB, idle CPU ≤0.1% of one core, idle footprint ≤30 MiB. Do not interpret any result as zero impact. No comparable controlled Ice baseline was collected. Host WindowServer/compositor costs, cold filesystem-cache launch, energy use and end-to-end click latency are not measured by the process sampler. There is one app process and no helper; reports do not include external sampler cost or system process work. Fixture integration elapsed time includes intentional settling delays and is not a toggle latency benchmark.

## Reproduce

```bash
bash scripts/verify.sh
# Quit TinyBar and any other menu-bar manager; use a logged-in desktop
bash scripts/verify.sh --integration
bash scripts/recovery.sh
# Launch the actual app, close its help window, then keep the state unchanged
bash scripts/benchmark.sh 300 reports/idle.json
```

Do not reuse an existing output filename; raw reports stay ignored. Report files may include local fixture geometry. Only this sanitized summary is published.

## Outstanding coverage

Physical sleep/wake, display unplug/replug, resolution/main-display changes, automatic menu-bar hiding, fullscreen Spaces, many icons exceeding available space, other notched screen layouts, Intel runtime, macOS 13–15 runtime, login-item enable/disable across rebuilt signatures, and conflicts beyond the known manager ID checks remain unverified. The app therefore stays an experimental prototype, without a signed/notarized release.
