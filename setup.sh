#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/christopherklint97/dotfiles.git"

# --- Helpers ---

info()    { printf '\033[0;34m[info]\033[0m %s\n' "$1"; }
success() { printf '\033[0;32m[ok]\033[0m %s\n' "$1"; }
error()   { printf '\033[0;31m[error]\033[0m %s\n' "$1"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

OS="$(uname -s)"

# --- Install prerequisites (Linux only) ---

install_prerequisites() {
  if [[ "$OS" != "Linux" ]]; then return; fi
  if command_exists git && command_exists curl && command_exists gcc; then return; fi

  info "Installing prerequisites..."
  if command_exists apt-get; then
    sudo apt-get update
    sudo apt-get install -y git curl build-essential procps file
  elif command_exists dnf; then
    sudo dnf install -y git curl gcc make procps-ng file
  elif command_exists yum; then
    sudo yum install -y git curl gcc make procps file
  else
    error "Unsupported package manager. Install git, curl, and a C compiler manually."
  fi
  success "Prerequisites installed"
}

# --- Ensure git uses HTTPS for GitHub ---

ensure_git_https() {
  # The Homebrew installer (and other tools) clone from GitHub via git.
  # If the user's git config rewrites HTTPS URLs to SSH (url.git@github.com:.insteadOf),
  # clones will fail on machines without SSH keys.  Force HTTPS to avoid this.

  # Remove broken symlink left over from a previous install (e.g., stow linked
  # ~/.gitconfig → ~/dotfiles/.gitconfig, but the repo was later removed).
  if [[ -L "$HOME/.gitconfig" && ! -e "$HOME/.gitconfig" ]]; then
    rm "$HOME/.gitconfig"
  fi

  git config --global url."https://github.com/".insteadOf "git@github.com:"
}

# --- Install Homebrew ---

install_homebrew() {
  if command_exists brew; then
    success "Homebrew already installed"
    return
  fi

  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ "$OS" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # Install Homebrew's recommended build dependencies
    if command_exists apt-get; then
      sudo apt-get install -y build-essential
    elif command_exists dnf; then
      sudo dnf groupinstall -y 'Development Tools'
    elif command_exists yum; then
      sudo yum groupinstall -y 'Development Tools'
    fi
  fi
  success "Homebrew installed"
}

# --- Install packages ---

install_packages() {
  info "Installing packages via Homebrew..."
  local packages=(
    stow
    tmux
    neovim
    fzf
    ripgrep
    fd
    gh
    git-lfs
    direnv
    jq
    lazygit
    wget
    tree
    zsh
    cpulimit
  )

  if [[ "$OS" == "Darwin" ]]; then
    packages+=(gnu-sed reattach-to-user-namespace)
  else
    packages+=(gcc)
  fi

  brew install "${packages[@]}"

  # Casks (macOS only)
  if [[ "$OS" == "Darwin" ]]; then
    brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true
    brew install --cask karabiner-elements 2>/dev/null || true
  fi

  success "Packages installed"
}

# --- Install Nerd Font on Linux ---

install_font_linux() {
  if [[ "$OS" != "Linux" ]]; then return; fi

  local font_dir="$HOME/.local/share/fonts"
  if ls "$font_dir"/JetBrains*.ttf &>/dev/null; then
    success "JetBrains Mono Nerd Font already installed"
    return
  fi

  info "Installing JetBrains Mono Nerd Font..."
  mkdir -p "$font_dir"
  local tmp
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
  tar xf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir"
  rm -rf "$tmp"
  command_exists fc-cache && fc-cache -f "$font_dir"
  success "JetBrains Mono Nerd Font installed"
}

# --- Install oh-my-zsh ---

install_ohmyzsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "oh-my-zsh already installed"
  else
    info "Installing oh-my-zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "oh-my-zsh installed"
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    success "zsh-autosuggestions already installed"
  else
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    success "zsh-autosuggestions installed"
  fi
}

# --- Install nvm ---

install_nvm() {
  if [[ -d "$HOME/.nvm" ]]; then
    success "nvm already installed"
  else
    info "Installing nvm..."
    PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh)"
    success "nvm installed"
  fi
}

# --- Clone dotfiles ---

clone_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    success "Dotfiles already cloned"
  else
    info "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    success "Dotfiles cloned"
  fi

  info "Updating submodules..."
  git -C "$DOTFILES_DIR" submodule update --init --recursive
  success "Submodules updated"
}

# --- Install tmux plugin manager ---

install_tpm() {
  if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
    success "TPM already installed"
  else
    info "Installing tmux plugin manager..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    success "TPM installed"
  fi
}

# --- Create symlinks ---

create_symlinks() {
  info "Creating symlinks..."
  cd "$DOTFILES_DIR"
  stow --adopt .
  git checkout .
  success "Symlinks created"
}

# --- Set default shell to zsh ---

set_default_shell() {
  if [[ "$SHELL" == *"zsh"* ]]; then
    success "Default shell is already zsh"
    return
  fi

  info "Setting default shell to zsh..."
  local zsh_path
  zsh_path="$(which zsh)"
  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "$zsh_path" "$(whoami)"
  success "Default shell set to zsh"
}

# --- Main ---

main() {
  echo ""
  echo "  dotfiles installer"
  echo "  =================="
  echo ""

  install_prerequisites
  ensure_git_https
  install_homebrew
  install_packages
  install_font_linux
  clone_dotfiles
  install_ohmyzsh
  install_nvm
  install_tpm
  create_symlinks
  set_default_shell

  # Persist Homebrew in PATH for future bash sessions (Linux only; .zshrc handles zsh)
  if [[ "$OS" == "Linux" ]]; then
    if ! grep -q 'linuxbrew' "$HOME/.bashrc" 2>/dev/null; then
      echo >> "$HOME/.bashrc"
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> "$HOME/.bashrc"
    fi
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
  fi

  echo ""
  success "Done! Restart your terminal or run: exec zsh"
  echo ""
}

main
