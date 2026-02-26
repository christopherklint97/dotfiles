# dotfiles

One-command setup for macOS and Linux.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/christopherklint97/dotfiles/main/setup.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/christopherklint97/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./setup.sh
```

## What's included

| Config | Description |
|--------|-------------|
| `.zshrc` | oh-my-zsh with autosuggestions and vi-mode |
| `.config/nvim/` | Neovim (kickstart.nvim base, git submodule) |
| `.tmux.conf` | vi-mode, mouse, dracula theme, vim-tmux-navigator |
| `.wezterm.lua` | Dracula theme, macOS-friendly keybindings |
| `.gitconfig` | Aliases, fast-forward pulls, rerere, nvim editor |

## Machine-specific config

Create `~/.env.local` for environment variables that differ per machine (SDK paths, database users, work email overrides, etc.). It's sourced automatically by `.zshrc`.

## How it works

Symlinks are managed by [GNU Stow](https://www.gnu.org/software/stow/). The installer:

1. Installs Homebrew (macOS and Linux)
2. Installs core packages (neovim, tmux, fzf, ripgrep, etc.)
3. Installs oh-my-zsh + plugins, nvm, tmux plugin manager
4. Symlinks all dotfiles into `$HOME`
5. Sets zsh as the default shell
