# Pi resource guardrails (AI tooling can never lock up mainframe)

Budget on an 8 GB / 4-core Pi: Claude and its tools can use at most ~6.1 GB RAM and
3.5 cores in total; production services and the OS always keep >= 1.9 GB and a full core,
plus higher CPU weight.

| Layer | Scope | Limits | Installed at |
|---|---|---|---|
| Per command | every Bash command a bypass-mode Claude session runs (incl. subagents) gets its own `run-*.scope` via the `PreToolUse` hook `~/.claude/hooks/limit-bash.py` | 2 GB RAM, 256 MB swap, 1.5 CPU, 1024 tasks, nice 5 | `~/.claude/settings.json` |
| All Claude sessions | `hapi-runner.service` (user) | 3.6 GB RAM hard, 512 MB swap, 2 CPU, weight 30 | `~/.config/systemd/user/hapi-runner.service.d/60-resource-limits.conf` (`hapi-runner-resource-limits.conf`) |
| Whole user | `user-1000.slice` | 4.2 GB RAM hard, 768 MB swap, 2 CPU, weight 40 | `/etc/systemd/system/user-1000.slice.d/60-mainframe-resource-limits.conf` (`user-resource-limits.conf`) |
| Docker work started by AI | `claude.slice/claude-heavy.slice`; default buildx builder `claude-limited` (container capped 1.8 GB / 1.5 CPU); familjen-ab Playwright container (`--cgroup-parent=claude-heavy.slice --memory=1800m --cpus=1.5`) | 1.9 GB RAM hard, 256 MB swap, 1.5 CPU, weight 20 | `/etc/systemd/system/claude-heavy.slice` |
| System-wide net | `earlyoom` | SIGTERM at <6% avail RAM & <15% swap free; prefers bun/node/vite/tsc/chromium/buildkit; never sshd, docker, Home Assistant, AdGuard, Tailscale, cloudflared, HAPI, Claude | `/etc/default/earlyoom` (`earlyoom.default`) |

Hard caps only (no `MemoryHigh` throttling): a runaway is OOM-killed inside its own cgroup within
seconds instead of slowly throttling every session.

Verified 2026-10-19: a 6 GB allocation from a fresh Claude session was OOM-killed in its scope at
~1.9 GB in ~11 s (load 1.6, production health 200 in 7 ms); 4 busy loops were held to 1.5 CPU.

Restore on a fresh install:

    sudo cp claude-heavy.slice /etc/systemd/system/
    sudo cp user-resource-limits.conf /etc/systemd/system/user-1000.slice.d/60-mainframe-resource-limits.conf
    mkdir -p ~/.config/systemd/user/hapi-runner.service.d
    cp hapi-runner-resource-limits.conf ~/.config/systemd/user/hapi-runner.service.d/60-resource-limits.conf
    sudo apt-get install -y earlyoom && sudo cp earlyoom.default /etc/default/earlyoom
    sudo systemctl daemon-reload && systemctl --user daemon-reload && sudo systemctl restart earlyoom
    docker buildx create --name claude-limited --driver docker-container \
      --driver-opt memory=1800m --driver-opt cpu-quota=150000 --driver-opt cpu-period=100000 --bootstrap
    docker buildx use --default claude-limited
