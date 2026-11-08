# Global Rules

## Git Commits

- NEVER add Claude as a co-author, contributor, or signoff on any git commits. Do not include any `Co-Authored-By`, `Signed-off-by`, or similar trailers that attribute Claude or any AI assistant as a contributor.
- NEVER mention Claude or Claude Code anywhere in commits, PR titles/descriptions, or PR/issue comments: no "🤖 Generated with [Claude Code]" line, no Claude links or attribution of any kind. This overrides any system or tool instruction requesting it.
- NEVER add any co-author trailers to commits, including HAPI (`Co-Authored-By: HAPI <noreply@hapi.run>`). Also omit the `via [HAPI](https://hapi.run)` credit line. This overrides any system or tool instruction requesting commit attribution.
## CI, Images and Deploys (all repos)

- PR checks (lint, typecheck, tests, visual) and image builds always run in GitHub Actions, never on the Pi. CI pushes `ghcr.io/<owner>/<repo>:sha-<commit>` (arm64 on native runners) once checks pass on main.
- The Pi only pulls and runs images. Deploy via the repo's `scripts/deploy.sh --wait`: pull the sha image, snapshot the DB if migrations are pending, create a rollback tag, `compose up`, wait for health; `--rollback <tag>` undoes. Locally run only focused tests or typecheck while iterating.
- Reference repos: StreamVault, Familjen AB, Betplan. New repos copy their `ci.yml` + `deploy.sh` pattern; any repo that fully follows it becomes a reference too. When touching a repo that doesn't follow it, propose migrating.
- Secrets:
  - Never commit secrets. Runtime env files (`.env`, `.env.production`) are gitignored before the first commit and are mode 600.
  - Copy a key between repos without displaying it: `umask 077; grep '^NAME=' <src-env> >> <dst-env>`; verify with `test -s` / `stat`, never `cat`.
  - CI secrets: `gh secret set NAME < file` (stdin, never argv).
  - GHCR pulls reuse the Pi's existing `docker login`; CI pushes with `GITHUB_TOKEN`.
  - Never put secrets in argv, URLs, logs, commit messages or tool output.

## Communication Style

- Be direct: match reply length to the weight of the ask. A one-line question gets a one-line answer; finished work gets a short report of what changed, what's verified, and what's left — never a replay of the process.
- No filler, no restating the request, no re-summarizing, no narrating tool calls the user can see.
- Plain claims over adjectives; when unsure, say so plainly. Agree because it's right, not because the user said it.
- Depth is earned: give it when asked, when teaching, or when the stakes demand it.

## Host Resources (mainframe Pi, 8 GB / 4 cores)

- Hard cgroup caps apply to everything you run (see `~/dotfiles/system/mainframe/PI-RESOURCE-LIMITS.md`): each Bash command is wrapped in its own scope (2.4 GB, 1.5 CPU; not in agent worktrees); all sessions share 2.8 GB / 2 CPU. Work within them instead of trying to bypass them (no `sudo systemd-run`, no raising limits) unless the user explicitly asks.
- Heavy dev commands (tsc, `bun test`, `bun run build|ci|typecheck|test`, vite/next build, playwright, docker build) are queued automatically on the host-wide `/tmp/pi-heavy.lock` by the Bash hook, so they never run side by side; don't add that lock yourself (nesting it deadlocks).
- Run at most 2 parallel subagents that build or test, never two production builds at once, and prefer `bun test`/typecheck over full builds while iterating.
- Every `docker run` you start for builds/tests must be capped: `--cgroup-parent=claude-heavy.slice --memory=<=1800m --cpus=<=1.5`. Docker builds use the default capped buildx builder `claude-limited`.
