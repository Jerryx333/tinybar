#!/bin/bash
# Check on-demand AX enumeration/cancellation; run: bash scripts/catalog.sh
# Requires macOS and existing Accessibility permission for the test launcher; grants nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -Osize -whole-module-optimization -warnings-as-errors -target "$(uname -m)-apple-macosx13.0" \
  Sources/OverflowCatalog.swift tests/CatalogProbe.swift -o build/catalog-probe
build/catalog-probe
