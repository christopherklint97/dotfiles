# Reload zsh config across all tmux panes, skipping panes running Claude or k9s
zshsource() {
  tmux list-panes -a -F '#{pane_id} #{pane_pid}' | while read -r pane pane_pid; do
    if pgrep -P "$pane_pid" -f 'claude|k9s' >/dev/null 2>&1; then
      continue
    fi
    tmux send-keys -t "$pane" "source ~/.zshrc" Enter
  done
}
