# Reload zsh config across all running shells via USR1 signal
TRAPUSR1() { source ~/.zshrc }

zsrc() {
  killall -USR1 zsh
}
