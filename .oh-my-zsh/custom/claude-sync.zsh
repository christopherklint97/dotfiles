# Restart Claude Code instances in all other tmux panes, preserving sessions.
# Useful after updating plugins, MCP servers, or the Claude Code version.
# Usage: claude-restart-others [--dry-run]
#
# Options:
#   -n, --dry-run   Show which panes would be restarted without doing anything
#   -h, --help      Show this help
function claude-restart-others() {
  local dry_run=false

  # --- Parse args ---
  for arg in "$@"; do
    case "$arg" in
      -n|--dry-run) dry_run=true ;;
      -h|--help)
        cat <<'EOF'
Usage: claude-restart-others [--dry-run]

Restart Claude Code instances in all other tmux panes, preserving sessions
via `claude --continue`. Useful after updating plugins, MCP servers, or
the Claude Code version.

Options:
  -n, --dry-run   Show which panes would be restarted without doing anything
  -h, --help      Show this help
EOF
        return 0
        ;;
      *)
        echo "❌ Unknown option: $arg"
        return 1
        ;;
    esac
  done

  # --- Sanity checks ---
  if [[ -z "${TMUX:-}" ]]; then
    echo "❌ Not inside a tmux session."
    return 1
  fi

  local current_pane
  current_pane="$(tmux display-message -p '#{pane_id}')"

  # --- Find all panes ---
  local pane_ids=()
  while IFS= read -r pane_id; do
    pane_ids+=("$pane_id")
  done < <(tmux list-panes -a -F '#{pane_id}')

  if [[ ${#pane_ids[@]} -le 1 ]]; then
    echo "ℹ️  No other panes found."
    return 0
  fi

  local restarted=0
  local skipped=0

  for pane_id in "${pane_ids[@]}"; do
    # Skip current pane
    [[ "$pane_id" == "$current_pane" ]] && continue

    # Get the pane's shell PID and working directory
    local pane_pid pane_path
    pane_pid="$(tmux display-message -t "$pane_id" -p '#{pane_pid}' 2>/dev/null)" || continue
    pane_path="$(tmux display-message -t "$pane_id" -p '#{pane_current_path}' 2>/dev/null)" || continue

    # Check if claude is running in this pane's process tree
    if ! pgrep -P "$pane_pid" -f claude >/dev/null 2>&1; then
      ((skipped++))
      continue
    fi

    local pane_label="pane $pane_id ($pane_path)"

    if [[ "$dry_run" == true ]]; then
      echo "🔍 Would restart: $pane_label"
      ((restarted++))
      continue
    fi

    echo "🔄 Restarting: $pane_label"

    # C-c clears input, second C-c exits Claude
    tmux send-keys -t "$pane_id" C-c
    tmux send-keys -t "$pane_id" C-c

    # Wait for claude process to exit (up to 60s)
    local waited=0
    local timeout=60
    while pgrep -P "$pane_pid" -f claude >/dev/null 2>&1; do
      sleep 1
      ((waited++))
      if [[ $waited -ge $timeout ]]; then
        echo "⚠️  Timeout waiting for Claude to exit in $pane_label — skipping."
        ((skipped++))
        continue 2
      fi
    done

    # Restart Claude with session resume in the original directory
    tmux send-keys -t "$pane_id" "cd $pane_path && claude --continue" Enter
    ((restarted++))
    echo "✅ Restarted: $pane_label"
  done

  echo ""
  if [[ "$dry_run" == true ]]; then
    echo "🔍 Dry run complete: $restarted pane(s) would be restarted, $skipped skipped."
  else
    echo "✨ Done: $restarted pane(s) restarted, $skipped skipped."
  fi
}
