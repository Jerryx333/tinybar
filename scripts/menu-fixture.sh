#!/bin/bash
# Build native targets for manual notch validation; run: bash scripts/menu-fixture.sh
# Requires macOS Command Line Tools; launch the output yourself, exit via F0 menu.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/MenuFixture.app/Contents/MacOS
xcrun swiftc -parse-as-library -Osize -whole-module-optimization -warnings-as-errors -target "$(uname -m)-apple-macosx13.0" \
  tests/MenuFixture.swift -o build/MenuFixture.app/Contents/MacOS/MenuFixture
cp Info.plist build/MenuFixture.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.tinybar.menufixture' build/MenuFixture.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable MenuFixture' build/MenuFixture.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Set :CFBundleName MenuFixture' build/MenuFixture.app/Contents/Info.plist
codesign --force --sign - build/MenuFixture.app
printf 'Built: build/MenuFixture.app (F0 native menu, F1 popover, F2 action menu)\n'
