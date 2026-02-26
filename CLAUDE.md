# CLAUDE.md

## Repository Overview

Personal dotfiles for macOS and Linux, managed with [GNU Stow](https://www.gnu.org/software/stow/) for symlink management and [Homebrew](https://brew.sh/) for package installation. Owner: Christopher Klint.

Repository: `https://github.com/christopherklint97/dotfiles`

## Project Structure

```
dotfiles/
├── .config/nvim/             # Neovim config (git submodule → kickstart.nvim fork)
├── .oh-my-zsh/custom/        # Custom zsh functions and aliases
│   ├── alias.zsh             # Shell and git aliases
│   ├── ghprc.zsh             # GitHub PR creation function
│   ├── ghprm.zsh             # GitHub PR merge function
│   ├── ghprchecks.zsh        # GitHub PR checks watcher
│   ├── ghprcomments.zsh      # GitHub PR comment extraction (GraphQL)
│   └── kubeconf.zsh          # Kubernetes config helper (Convox)
├── .gitconfig                # Git aliases, user config, LFS, pull strategy
├── .tmux.conf                # Tmux: vi-mode, mouse, dracula theme, TPM plugins
├── .wezterm.lua              # WezTerm: Dracula theme, macOS keybindings
├── .zshrc                    # Zsh: oh-my-zsh, plugins, keybindings, tool init
├── .stow-local-ignore        # Files Stow should not symlink
├── setup.sh                  # Cross-platform installer (macOS + Linux)
└── README.md                 # User-facing documentation
```

## How Stow Works

All dotfiles live at the repo root. Running `stow --adopt .` from `~/dotfiles` creates symlinks in `$HOME` pointing back to the repo. Files listed in `.stow-local-ignore` are excluded from symlinking (e.g., `README.md`, `setup.sh`, `CLAUDE.md`).

**Important:** When adding new dotfiles, place them at the repo root mirroring the `$HOME` path structure. Stow will create the corresponding symlink automatically.

## Key Conventions

### Shell
- **Primary shell:** zsh with oh-my-zsh framework
- **Theme:** amuse
- **Plugins:** git, zsh-autosuggestions, vi-mode
- **Machine-specific config:** `~/.env.local` (sourced at end of `.zshrc`, not tracked in git)
- **Custom functions** go in `.oh-my-zsh/custom/*.zsh` — oh-my-zsh auto-sources all `.zsh` files in that directory

### Git
- **Default branch:** main
- **Pull strategy:** fast-forward only
- **Editor:** nvim
- **Rerere:** enabled
- **Push:** `autoSetupRemote = true`
- **URL rewriting:** SSH ↔ HTTPS for github.com (`.gitconfig` rewrites HTTPS→SSH; `setup.sh` temporarily forces HTTPS→HTTPS during install)

### Editor
- Neovim via a git submodule at `.config/nvim/` pointing to a fork of kickstart.nvim
- Aliased as `vim` in `alias.zsh`

### Terminal & Multiplexer
- **Terminal:** WezTerm with Dracula theme
- **Multiplexer:** tmux with Dracula theme, vi-mode, mouse support
- **Tmux plugins** managed by TPM (tmux plugin manager)

## Setup Script (`setup.sh`)

The installer runs these steps in order:

1. Install prerequisites (Linux: git, curl, gcc via apt/dnf/yum)
2. Configure git to use HTTPS for GitHub (for SSH-less environments)
3. Install Homebrew
4. Install packages: stow, tmux, neovim, fzf, ripgrep, gh, git-lfs, direnv, jq, lazygit, wget, tree, zsh (+ macOS-only: gnu-sed, reattach-to-user-namespace, JetBrains Mono Nerd Font cask)
5. Install JetBrains Mono Nerd Font (Linux: manual download)
6. Clone dotfiles repo and init submodules
7. Install oh-my-zsh + zsh-autosuggestions plugin
8. Install nvm (Node Version Manager)
9. Install tmux plugin manager (TPM)
10. Create symlinks via `stow --adopt .`
11. Set zsh as default shell

Script uses `set -euo pipefail` and colored helper functions (`info`, `success`, `error`).

## Custom GitHub CLI Functions

These are the custom shell functions in `.oh-my-zsh/custom/`:

| Function | Purpose |
|----------|---------|
| `ghprc [OPTIONS] [TITLE]` | Create a PR. Flags: `-c` (Claude post-update), `-r` (Copilot review), `-v` (open in browser). Title defaults to last commit message. |
| `ghprm [PR]` | Merge a PR non-interactively. Default: squash merge. Override with `GHMERGE_METHOD=merge\|rebase`. Auto-deletes branch. |
| `ghprchecks [--json]` | Watch PR checks or output JSON. |
| `ghprcomments [--jq FILTER] [--copy] [--json [PATH]]` | Fetch PR comments/reviews via GraphQL, filter bots, optional clipboard copy. |
| `kubeconf RACK` | Generate and merge Kubernetes config from a Convox rack. |

## Common Aliases (from `alias.zsh`)

**Git:** `ga` (add .), `gc` (commit -m), `gp` (push), `gpl` (pull), `gco` (checkout), `gcb` (checkout -b), `gs` (status), `gd` (diff), `gl` (log), `grsh` (reset --soft HEAD~1)

**GitHub CLI:** `ghprv` (view PR in browser), `ghrv` (view repo in browser), `ghconvox` / `ghdeploy` (watch workflow runs)

**Other:** `vim` → nvim, `pip` → pip3, `ls` → ls -lahG, `claude` → claude --dangerously-skip-permissions

## Development Workflow

### Adding a new dotfile
1. Place the file in `~/dotfiles` at the path it should appear relative to `$HOME`
2. Run `stow --adopt .` from `~/dotfiles` to create the symlink
3. Commit the file

### Adding a new custom zsh function
1. Create a new `.zsh` file in `.oh-my-zsh/custom/`
2. Define your function inside it
3. It will be auto-sourced by oh-my-zsh on shell startup

### Updating the Neovim config
The nvim config is a git submodule. To update:
```bash
cd .config/nvim
git pull origin main
cd ~/dotfiles
git add .config/nvim
git commit -m "Update nvim submodule"
```

### Adding a new Homebrew package
Add the package name to the `packages` array in `setup.sh` inside the `install_packages()` function.

## Files Excluded from Stow

These files exist in the repo but are **not** symlinked to `$HOME` (configured in `.stow-local-ignore`):
- `.git`, `.gitignore`, `.gitmodules`
- `README.md`, `CLAUDE.md`, `setup.sh`, `LICENSE`, `.stow-local-ignore`

## Platform Support

- **macOS:** Full support including cask fonts, gnu-sed, reattach-to-user-namespace
- **Linux:** Debian/Ubuntu (apt), Fedora (dnf), RHEL/CentOS (yum)

## Git Branching

- Default branch: `main`
- Feature branches with PRs for changes
- Use `ghprc` to create PRs and `ghprm` to merge them
