# Reload zsh config across all tmux panes
zsrc() {
  tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
    tmux send-keys -t "$pane" "source ~/.zshrc" Enter
  done
}
