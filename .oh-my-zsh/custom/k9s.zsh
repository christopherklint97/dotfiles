# k9s config lives in ~/.config/k9s (stow-managed) instead of the macOS
# default ~/Library/Application Support/k9s.
export K9S_CONFIG_DIR="$HOME/.config/k9s"

# Regenerate the "auto" skin from the macOS system appearance:
# Dracula in dark mode, Catppuccin Latte in light mode (matches nvim/wezterm/tmux).
# k9s live-reloads skin files, so running this re-themes any running k9s instance.
# AppleInterfaceStyle only exists in Dark mode; a failed read => Light => latte.
k9s-theme-sync() {
  local skin=dracula
  if [[ "$(uname)" == "Darwin" ]] && ! defaults read -g AppleInterfaceStyle &>/dev/null; then
    skin=catppuccin-latte
  fi
  cp "$K9S_CONFIG_DIR/skins/$skin.yaml" "$K9S_CONFIG_DIR/skins/auto.yaml"
}

# Pick the skin matching the current appearance on every launch.
k9s() {
  k9s-theme-sync
  command k9s "$@"
}
