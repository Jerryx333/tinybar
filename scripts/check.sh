#!/bin/bash
# Validate planning-stage public documentation; run: bash scripts/check.sh
# Requires Python 3; no application or platform behavior is tested.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check_docs.py
