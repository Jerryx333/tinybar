#!/bin/bash
# Measure a running TinyBar process; run: bash scripts/benchmark.sh [seconds=300] [report.json]
# Requires macOS Command Line Tools; the sampler runs outside TinyBar.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports
xcrun clang -O2 -Wall -Wextra -Werror scripts/measure.c -o build/measure
build/measure --self-check
pid="$(pgrep -U "$UID" -x TinyBar)" || { echo 'TinyBar is not running.' >&2; exit 1; }
[[ "$pid" != *$'\n'* ]] || { echo 'Expected exactly one TinyBar process.' >&2; exit 1; }
report="${2:-reports/idle-$(date -u +%Y%m%dT%H%M%SZ).json}"
[[ ! -e "$report" ]] || { echo "Report already exists: $report" >&2; exit 1; }
stage="$(mktemp "${report}.XXXXXX")"
if build/measure "$pid" "${1:-300}" > "$stage"; then
  mv "$stage" "$report"
  cat "$report"
else
  echo "Measurement failed; incomplete output: $stage" >&2
  exit 1
fi
