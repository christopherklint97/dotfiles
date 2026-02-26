# Copy stdin or arguments to local clipboard via OSC 52 escape sequence.
# Works over SSH in terminals that support OSC 52 (e.g., Termius, WezTerm, iTerm2).
osc-copy() {
  local data
  if [ $# -gt 0 ]; then
    data=$(printf '%s' "$*" | base64)
  else
    data=$(base64)
  fi
  printf '\033]52;c;%s\a' "$data"
}
