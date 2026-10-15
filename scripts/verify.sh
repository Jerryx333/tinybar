#!/bin/bash
# Build and run noninteractive safety tests; run: bash scripts/verify.sh [--integration]
# Requires macOS Command Line Tools; integration briefly rearranges only test items.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
xcrun swiftc -O -whole-module-optimization -warnings-as-errors -target "$(uname -m)-apple-macosx13.0" Sources/Layout.swift tests/LayoutTests.swift -o build/test-layout
build/test-layout
xcrun clang -O2 -Wall -Wextra -Werror scripts/measure.c -o build/measure
build/measure --self-check
if [[ "${1:-}" == "--integration" ]]; then
  if pgrep -U "$UID" -x TinyBar >/dev/null || pgrep -U "$UID" -x TinyBarProbe >/dev/null; then echo 'Quit TinyBar and TinyBarProbe before integration tests.' >&2; exit 1; fi
  mkdir -p build/TinyBarProbe.app/Contents/MacOS reports
  xcrun swiftc -Osize -whole-module-optimization -warnings-as-errors -swift-version 5 -D TESTING -target "$(uname -m)-apple-macosx13.0" \
    Sources/*.swift tests/Probe.swift -framework AppKit -framework ServiceManagement \
    -o build/TinyBarProbe.app/Contents/MacOS/TinyBarProbe
  cp Info.plist build/TinyBarProbe.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.tinybar.probe' build/TinyBarProbe.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable TinyBarProbe' build/TinyBarProbe.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName TinyBarProbe' build/TinyBarProbe.app/Contents/Info.plist
  codesign --force --sign - build/TinyBarProbe.app
  for mode in integration reversed; do
    build/TinyBarProbe.app/Contents/MacOS/TinyBarProbe --probe "$mode" "reports/$mode.json"
  done
elif [[ $# -gt 0 ]]; then
  echo 'Usage: bash scripts/verify.sh [--integration]' >&2; exit 64
fi
