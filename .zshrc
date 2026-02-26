# Path to Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="amuse"

# Plugins
plugins=(
  git
  zsh-autosuggestions
  vi-mode
)

source $ZSH/oh-my-zsh.sh

# --- Keybindings ---

bindkey '\t' autosuggest-accept          # Tab: accept autosuggestion
bindkey '\e[1;3D' backward-word          # Option+Left: back one word
bindkey '\e[1;3C' forward-word           # Option+Right: forward one word
bindkey '\e\x7f'  backward-kill-word     # Option+Backspace: delete previous word
bindkey '\e[3;3~' kill-word              # Option+Delete: delete next word
bindkey '\e[H'    beginning-of-line      # Home
bindkey '\e[F'    end-of-line            # End
bindkey '^U'      kill-whole-line        # Ctrl+U: delete entire line
bindkey '^K'      kill-line              # Ctrl+K: delete to end of line

# vi-mode
VI_MODE_SET_CURSOR=false

# --- Homebrew ---

if [[ "$(uname -s)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
  # GNU make (Homebrew puts it outside PATH by default)
  [[ -d /opt/homebrew/opt/make/libexec/gnubin ]] && export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
else
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)"
fi

# --- Tool initialization (guarded) ---

# direnv
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# rbenv
command -v rbenv &>/dev/null && eval "$(rbenv init - zsh)"

# rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# go
export PATH="$HOME/go/bin:$PATH"

# pipx / local bins
export PATH="$PATH:$HOME/.local/bin"

# --- Local overrides (machine-specific config goes here) ---

[ -f ~/.env.local ] && source ~/.env.local
