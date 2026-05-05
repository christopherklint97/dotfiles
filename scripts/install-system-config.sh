#!/usr/bin/env bash
# Install Linux-only system config (cron + journald) from the dotfiles repo
# into /etc. Idempotent. Requires sudo.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Skipping: Linux-only." >&2
  exit 0
fi

sudo install -m 644 "$DOTFILES/system/cron.d/disk-cleanup" /etc/cron.d/disk-cleanup
sudo install -d -m 755 /etc/systemd/journald.conf.d
sudo install -m 644 "$DOTFILES/system/journald.conf.d/00-disk.conf" \
  /etc/systemd/journald.conf.d/00-disk.conf
sudo systemctl restart systemd-journald

echo "Installed cron.d/disk-cleanup and journald drop-in."
echo "If you have a duplicate 'docker image prune' line in the root crontab,"
echo "remove it with: sudo crontab -e"
