# Reload zsh config across all tmux panes
zshsource() {
  tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
    tmux send-keys -t "$pane" "source ~/.zshrc" Enter
  done
}
