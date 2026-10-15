# Validation plan / 验证计划

[中文 README](../README.md) | [English README](../README.en.md)

The native 0.1 prototype is runnable. Stage 1 is implemented with bounded safety checks; stages 2–5 retain the outstanding gates below. See [current evidence](validation.md).

## 1. Prove the smallest reversible prototype

Build a native status item and a reversible hide/reveal mechanism in a disposable local prototype. Confirm the reveal control remains reachable. Do not replace the user's existing manager or enable login startup automatically.

Record which APIs are public, which behaviors are undocumented, which permissions are required and what fails on unsupported systems. Reject any mechanism that requires permanently losing item positions or cannot provide recovery instructions.

## 2. Validate real display behavior

Test one display, multiple displays, a notched display, main-display switching, resolution changes, unplug/replug, sleep/wake and menu-bar auto-hide. Test interactions with full-screen spaces and existing managers one scenario at a time. Unknown states must remain unknown, not be reported as success.

## 3. Add only essential persistence and controls

Persist user arrangement and startup preference without taking over unrelated applications' settings. Add bounded retry and visible failure feedback. Validate quit and restart recovery. No icon mirrors or app inventory database in this stage.

## 4. Measure before claiming lightweight

Publish reproducible benchmark scripts and sanitized summaries, including wall time, CPU time, RSS, physical footprint and wakeup definitions. Test repeated toggling and cold/warm behavior. Run independent review of lifecycle, concurrency and recovery before release.

## 5. First release gate

A release needs a runnable build path, passing relevant tests, real-machine validation evidence, known OS/hardware coverage, privacy documentation and installation/removal instructions. Packaging/signing/notarization status must be explicit. Until broader real-device gates pass, the README remains labeled experimental; no signed/notarized distribution is claimed.
