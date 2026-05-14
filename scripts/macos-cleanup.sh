#!/usr/bin/env bash
# macOS cleanup tasks. Invoked from cron — also safe to run by hand.
#
# Usage:
#   macos-cleanup.sh daily        # all cleanup tasks
#   macos-cleanup.sh memory       # sudo purge (needs root)

set -uo pipefail

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
run() { log "→ $*"; "$@" || log "  (non-zero exit, continuing)"; }

cmd_daily() {
  log "=== macOS daily cleanup ==="

  if command -v brew >/dev/null; then
    run brew cleanup -s --prune=30
    run brew autoremove
  fi

  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    run docker container prune -f
    run docker image prune -af
    run docker builder prune -af
    run docker volume prune -f
  fi

  command -v pnpm >/dev/null && run pnpm store prune
  command -v npm  >/dev/null && run npm cache verify
  command -v uv   >/dev/null && run uv cache prune
  command -v pip3 >/dev/null && run pip3 cache purge
  command -v go   >/dev/null && run go clean -cache -modcache -testcache -fuzzcache

  # Xcode build artifacts (regenerated on next build)
  if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    run rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
  fi
  if [ -d "$HOME/Library/Developer/CoreSimulator/Caches" ]; then
    run rm -rf "$HOME/Library/Developer/CoreSimulator/Caches"/*
  fi

  # Trash — use Finder so Full Disk Access not required
  osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1 \
    && log "→ emptied Trash" \
    || log "  (Trash empty failed/skipped)"

  log "=== done ==="
}

cmd_memory() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "memory subcommand needs sudo (purge requires root)" >&2
    exit 1
  fi
  log "→ purge (free inactive memory)"
  purge
  log "done"
}

case "${1:-}" in
  daily)  cmd_daily ;;
  memory) cmd_memory ;;
  *) echo "usage: $0 {daily|memory}" >&2; exit 2 ;;
esac
