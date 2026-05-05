#!/usr/bin/env bash
# Disk cleanup tasks invoked by /etc/cron.d/disk-cleanup.
# Subcommands run with the right user from cron — do not call directly.

set -euo pipefail

BUILDKIT_CONTAINER="buildx_buildkit_mybuilder0"

cmd_daily_docker() {
  docker container prune -f
  docker image prune -af
  docker builder prune -af

  # The buildx builder keeps its cache in a separate volume that
  # `docker builder prune` does not reach. Prune from inside the container.
  if docker ps -q -f "name=^${BUILDKIT_CONTAINER}$" | grep -q .; then
    docker exec "$BUILDKIT_CONTAINER" buildctl prune --keep-storage 2147483648
  fi
}

cmd_weekly_system() {
  apt-get -y autoremove --purge
  apt-get -y clean
  journalctl --vacuum-size=200M
}

cmd_weekly_user() {
  command -v pnpm >/dev/null && pnpm store prune || true
  command -v npm  >/dev/null && npm cache verify  || true
  command -v uv   >/dev/null && uv cache prune    || true
  command -v brew >/dev/null && brew cleanup -s --prune=30 || true
}

case "${1:-}" in
  daily-docker)  cmd_daily_docker ;;
  weekly-system) cmd_weekly_system ;;
  weekly-user)   cmd_weekly_user ;;
  *) echo "usage: $0 {daily-docker|weekly-system|weekly-user}" >&2; exit 2 ;;
esac
