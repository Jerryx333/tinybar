#!/bin/bash
# Install locally with backup; run: bash scripts/install.sh
# Requires a built app; no administrator rights or startup changes.
set -euo pipefail
cd "$(dirname "$0")/.."
dest="$HOME/Applications/TinyBar.app"
codesign --verify --strict build/TinyBar.app
mkdir -p "$HOME/Applications"
if [[ -e "$dest" ]] && diff -qr build/TinyBar.app "$dest" >/dev/null; then
  printf 'Already installed: %s\n' "$dest"; exit 0
fi
if pgrep -U "$UID" -x TinyBar >/dev/null; then echo 'Quit TinyBar before upgrading.' >&2; exit 1; fi
stage="$(mktemp -d "$HOME/Applications/.tinybar-stage.XXXXXX")"
cleanup() {
  if ! rmdir "$stage" 2>/dev/null; then printf 'Staged files retained: %s\n' "$stage" >&2; fi
}
trap cleanup EXIT
ditto build/TinyBar.app "$stage/TinyBar.app"
codesign --verify --strict "$stage/TinyBar.app"
backup=""
if [[ -e "$dest" ]]; then
  backupRoot="$HOME/Library/Application Support/TinyBar/Backups"
  mkdir -p "$backupRoot"
  backup="$backupRoot/TinyBar.$(date -u +%Y%m%dT%H%M%SZ).zip"
  [[ ! -e "$backup" ]] || { echo 'Backup already exists; retry later.' >&2; exit 1; }
  ditto -c -k --keepParent "$dest" "$backup"
  mv "$dest" "$stage/previous.app"
fi
if ! mv "$stage/TinyBar.app" "$dest"; then
  if [[ -e "$stage/previous.app" ]]; then mv "$stage/previous.app" "$dest"; fi
  echo "Installation failed; staged files kept at $stage" >&2; exit 1
fi
if [[ -e "$stage/previous.app" ]]; then
  # Keep the original bundle too, outside LaunchServices discovery; no deletion is needed.
  retained="$(mktemp -d "$backupRoot/retained.XXXXXX")"
  mv "$stage/previous.app" "$retained/previous.bundle"
  printf 'Previous bundle retained: %s/previous.bundle; zip: %s\n' "$retained" "$backup"
fi
printf 'Installed: %s\n' "$dest"
