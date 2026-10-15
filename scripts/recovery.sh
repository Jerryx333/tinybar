#!/bin/bash
# Verify surviving icons after reopen/quit/crash; run: bash scripts/recovery.sh
# Requires macOS GUI session; quit TinyBar/other managers and run verify.sh --integration first.
set -euo pipefail
cd "$(dirname "$0")/.."
if pgrep -U "$UID" -x TinyBar >/dev/null || pgrep -U "$UID" -x TinyBarProbe >/dev/null; then echo 'Quit TinyBar and TinyBarProbe first.' >&2; exit 1; fi
[[ -x build/TinyBarProbe.app/Contents/MacOS/TinyBarProbe ]] || { echo 'Run verify.sh --integration first.' >&2; exit 1; }
xcrun swiftc -Osize -whole-module-optimization -target "$(uname -m)-apple-macosx13.0" Sources/Layout.swift tests/Survivor.swift -o build/survivor
python3 - <<'PY'
import json, subprocess, time
from pathlib import Path
for mode in ('reopen', 'quit', 'kill'):
    output = Path(f'reports/recovery-{mode}.json')
    hold = Path(f'reports/hold-{mode}.json')
    for p in (output, hold):
        if p.exists(): p.unlink() # Script-owned reports, never app preferences or user data.
    fixture = subprocess.Popen(['build/survivor', str(output)])
    manager = None
    try:
        time.sleep(2)
        if fixture.poll() is not None: raise RuntimeError('Fixture failed before test')
        manager = subprocess.Popen(['build/TinyBarProbe.app/Contents/MacOS/TinyBarProbe', '--probe', 'hold', str(hold)])
        deadline = time.monotonic() + 15
        while not hold.exists():
            if manager.poll() is not None: raise RuntimeError('Manager exited before collapsed checkpoint')
            if time.monotonic() > deadline: raise RuntimeError('Manager did not reach collapsed checkpoint')
            time.sleep(.1)
        if json.loads(hold.read_text())['result'] != 'collapsed': raise RuntimeError('Manager not collapsed')
        time.sleep(2)
        if fixture.poll() is not None or output.exists(): raise RuntimeError('Fixture restored before manager exit; recovery not established')
        if mode == 'reopen':
            subprocess.run(['open', 'build/TinyBarProbe.app'], check=True)
        elif mode == 'quit':
            # NSRunningApplication.terminate invokes the normal application termination path.
            subprocess.run(['xcrun', 'swift', '-e', 'import AppKit; let p=NSRunningApplication(processIdentifier: Int32(CommandLine.arguments[1])!)!; if !p.terminate() { exit(1) }', str(manager.pid)], check=True)
        else:
            manager.kill() # Only the still-owned child, never a discovered/reused process.
        if mode != 'reopen': manager.wait(timeout=10)
        if fixture.wait(timeout=15) != 0: raise RuntimeError('Recovery fixture failed')
        if json.loads(output.read_text())['result'] != 'restored after recovery action': raise RuntimeError('Recovery not established')
        print(f'{mode}: surviving icons restored')
    finally:
        for process in (manager, fixture):
            if process is not None and process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
PY
