#!/bin/bash
# Check public docs; run: bash scripts/check.sh
# Requires Python 3; native build and tests use scripts/verify.sh on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check_docs.py
