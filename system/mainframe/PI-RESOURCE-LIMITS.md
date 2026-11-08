# Pi resource guardrails (AI tooling can never lock up mainframe)

Budget on an 8 GB / 4-core Pi: Claude and its tools can use at most ~6.1 GB RAM and
3.5 cores in total; production services and the OS always keep >= 1.9 GB and a full core,
plus higher CPU weight.

| Layer | Scope | Limits | Installed at |
|---|---|---|---|
| Per command | every Bash command a bypass-mode Claude session runs (incl. subagents) gets its own `run-*.scope` via the `PreToolUse` hook `~/.claude/hooks/limit-bash.py` | 2.4 GB RAM, 256 MB swap, 1.5 CPU, 1024 tasks, nice 5; heavy dev commands (tsc, tests, builds, playwright, docker build) also wait on the host-wide `flock /tmp/pi-heavy.lock` so only one runs at a time (not applied inside agent worktrees, which the harness must verify; those stay under the aggregate caps) | `~/.claude/settings.json` |
| All Claude sessions | `hapi-runner.service` (user) | 2.8 GB RAM hard (below the ~3.3 GB actually free with services running, so the cap fires before Pi-wide swapping), 512 MB swap, 2 CPU, weight 30 | `~/.config/systemd/user/hapi-runner.service.d/60-resource-limits.conf` (`hapi-runner-resource-limits.conf`) |
| Whole user | `user-1000.slice` | 4.2 GB RAM hard, 768 MB swap, 2 CPU, weight 40 | `/etc/systemd/system/user-1000.slice.d/60-mainframe-resource-limits.conf` (`user-resource-limits.conf`) |
| Docker work started by AI | `claude.slice/claude-heavy.slice`; default buildx builder `claude-limited` (container capped 1.8 GB / 1.5 CPU); familjen-ab Playwright container (`--cgroup-parent=claude-heavy.slice --memory=1800m --cpus=1.5`) | 1.9 GB RAM hard, 256 MB swap, 1.5 CPU, weight 20 | `/etc/systemd/system/claude-heavy.slice` |
| System-wide net | `earlyoom` | SIGTERM at <6% avail RAM & <15% swap free; prefers bun/node/vite/tsc/chromium/buildkit; never sshd, docker, Home Assistant, AdGuard, Tailscale, cloudflared, HAPI, Claude | `/etc/default/earlyoom` (`earlyoom.default`) |

Hard caps only (no `MemoryHigh` throttling): a runaway is OOM-killed inside its own cgroup within
seconds instead of slowly throttling every session.

Verified 2026-10-19: a 6 GB allocation from a fresh Claude session was OOM-killed in its scope at
~1.9 GB in ~11 s (load 1.6, production health 200 in 7 ms); 4 busy loops were held to 1.5 CPU.

Nightly housekeeping: `mainframe-maintenance.timer` (04:40) runs `mainframe-maintenance.sh`:
removes unused images beyond the newest 3 per repository once older than 7 days (images in
use and rollback targets stay), prunes build caches older than 3 days and stops idle buildkit
builders, kills dev processes (tsc, test runners, headless browsers, dev servers) older than 6 h,
restarts dockerd when it exceeds 900 MiB (Docker `live-restore` keeps every container running;
verified 2026-11-08: 1393 → 98 MiB, all containers and services stayed up), vacuums the journal
to 500 MB. Logs: `journalctl -u mainframe-maintenance`. `docker-daemon.json` also caps container
logs at 3 × 10 MB.

Restore on a fresh install:

    sudo cp claude-heavy.slice /etc/systemd/system/
    sudo cp user-resource-limits.conf /etc/systemd/system/user-1000.slice.d/60-mainframe-resource-limits.conf
    mkdir -p ~/.config/systemd/user/hapi-runner.service.d
    cp hapi-runner-resource-limits.conf ~/.config/systemd/user/hapi-runner.service.d/60-resource-limits.conf
    sudo install -m 644 docker-daemon.json /etc/docker/daemon.json && sudo systemctl reload docker
    sudo install -m 755 mainframe-maintenance.sh /usr/local/sbin/mainframe-maintenance
    sudo install -m 644 mainframe-maintenance.service mainframe-maintenance.timer /etc/systemd/system/
    sudo systemctl daemon-reload && sudo systemctl enable --now mainframe-maintenance.timer
    sudo apt-get install -y earlyoom && sudo cp earlyoom.default /etc/default/earlyoom
    sudo systemctl daemon-reload && systemctl --user daemon-reload && sudo systemctl restart earlyoom
    docker buildx create --name claude-limited --driver docker-container \
      --driver-opt memory=1800m --driver-opt cpu-quota=150000 --driver-opt cpu-period=100000 --bootstrap
    docker buildx use --default claude-limited

2026-11-08 (Pi hanging during heavy multi-agent development): parallel `tsc` runs from several
agents hit the user-slice cap (OOM-kills) and pushed ~1.5 GB into zram, whose compression ate CPU.
Changes: heavy commands serialized via the hook lock; per-command swap 512 → 256 MB; images and
tests build in GitHub CI only (see global CLAUDE.md), so the local buildx builders are stopped
and 33 GB build cache, 275 dangling images and old rollback tags (keep newest 3 per app) pruned.
dockerd had grown to ~1.7 GB RSS (422 images); it only shrinks on a docker restart.
