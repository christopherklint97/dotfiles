# prompt-queue.zsh — Task queue system for Claude Code
#
# Commands:
#   qq  "task" ["checkpoint"]  Add a task to the queue
#   qs                         Show queue status
#   qr                         Run next pending task
#   qra                        Run all pending tasks
#   qe                         Edit queue.md in $EDITOR
#   ql  [N]                    Show task log (latest or task N)
#   qc                         Archive queue and start fresh
#   qi                         Initialize queue directory

_PQ_DIR="$HOME/.prompt-queue"
_PQ_QUEUE="$_PQ_DIR/queue.md"
_PQ_LOGS="$_PQ_DIR/logs"
_PQ_ARCHIVE="$_PQ_DIR/archive"

# --- Init ---

_pq_init() {
  mkdir -p "$_PQ_LOGS" "$_PQ_ARCHIVE"
  if [[ ! -f "$_PQ_QUEUE" ]]; then
    cat > "$_PQ_QUEUE" <<'EOF'
# Prompt Queue

> Tasks for Claude Code to execute sequentially.

EOF
    echo "Initialized prompt queue at $_PQ_DIR"
  fi
}

# Auto-init on first source
[[ -d "$_PQ_DIR" ]] || _pq_init

# --- Helpers ---

_pq_task_count() {
  local n
  n=$(grep -c '^\## Task [0-9]' "$_PQ_QUEUE" 2>/dev/null) || true
  echo "${n:-0}"
}

_pq_next_num() {
  local count=$(_pq_task_count)
  echo $((count + 1))
}

_pq_next_pending() {
  # Returns the task number of the first [pending] task
  grep -m1 '^\## Task [0-9].* \[pending\]' "$_PQ_QUEUE" 2>/dev/null | sed 's/## Task \([0-9]*\).*/\1/'
}

# --- qq: Add task ---

_pq_add() {
  local desc="$1"
  local checkpoint="${2:-Code works correctly, no errors}"

  if [[ -z "$desc" ]]; then
    echo "Usage: qq \"task description\" [\"checkpoint\"]"
    return 1
  fi

  local num=$(_pq_next_num)

  cat >> "$_PQ_QUEUE" <<EOF

## Task $num [pending]

**Description:** $desc

**Checkpoint:** $checkpoint
EOF

  echo "Added task $num: $desc"
}

# --- qs: Status ---

_pq_status() {
  if [[ ! -f "$_PQ_QUEUE" ]]; then
    echo "No queue found. Run qi to init."
    return 1
  fi

  local pending=0 done=0 failed=0

  echo "--- Queue ---"
  while IFS= read -r line; do
    if [[ "$line" =~ '## Task ([0-9]+) \[([a-z]+)\]' ]]; then
      local num="${match[1]}"
      local task_status="${match[2]}"
      # Extract description from next lines
      local emoji
      case "$task_status" in
        pending) emoji="[pending]"; ((pending++)) ;;
        done)    emoji="[done]";  ((done++)) ;;
        failed)  emoji="[failed]";  ((failed++)) ;;
        *)       emoji="[$status]" ;;
      esac
      # Read ahead to get description
      local desc=""
      while IFS= read -r next; do
        if [[ "$next" =~ '^\*\*Description:\*\* (.+)' ]]; then
          desc="${match[1]}"
          break
        fi
        # Stop if we hit another task header
        [[ "$next" =~ '^\## Task' ]] && break
      done
      printf " %s %2d: %.50s\n" "$emoji" "$num" "$desc"
    fi
  done < "$_PQ_QUEUE"

  local total=$((pending + done + failed))
  echo ""
  echo "$total total | $pending pending | $done done | $failed failed"
}

# --- qr: Run next task ---

_pq_run() {
  local num=$(_pq_next_pending)

  if [[ -z "$num" ]]; then
    echo "No pending tasks."
    return 1
  fi

  # Extract task description and checkpoint
  local in_task=0 desc="" checkpoint="" task_block=""
  while IFS= read -r line; do
    if [[ "$line" =~ "## Task $num \[pending\]" ]]; then
      in_task=1
      task_block="$line"
      continue
    fi
    if ((in_task)); then
      # Stop at next task header
      [[ "$line" =~ '^\## Task [0-9]' ]] && break
      task_block="$task_block
$line"
      [[ "$line" =~ '^\*\*Description:\*\* (.+)' ]] && desc="${match[1]}"
      [[ "$line" =~ '^\*\*Checkpoint:\*\* (.+)' ]] && checkpoint="${match[1]}"
    fi
  done < "$_PQ_QUEUE"

  if [[ -z "$desc" ]]; then
    echo "Could not parse task $num."
    return 1
  fi

  local timestamp=$(date +%Y%m%d-%H%M%S)
  local logfile="$_PQ_LOGS/task-${num}-${timestamp}.log"

  echo "Running task $num: $desc"
  echo "Log: $logfile"
  echo ""

  local prompt="You have a task to complete from a prompt queue.

TASK #$num
Description: $desc
Checkpoint: $checkpoint

INSTRUCTIONS:
1. First, read the relevant code and understand the codebase context before making changes.
2. Implement the task described above thoroughly and carefully.
3. Verify the checkpoint: $checkpoint
   - Run any tests, linters, or build commands needed to confirm the checkpoint passes.
   - If the checkpoint fails, debug and fix until it passes or determine it cannot be completed.
4. After completing the task, update the queue file at $_PQ_QUEUE:
   - If the checkpoint PASSES: change \"## Task $num [pending]\" to \"## Task $num [done]\"
   - If the checkpoint FAILS and you cannot fix it: change to \"## Task $num [failed]\" and add a \"**Failure reason:**\" line below explaining why.
5. Do NOT modify any other tasks in the queue file.

Be thorough. Read before writing. Test your changes."

  command claude --dangerously-skip-permissions -p "$prompt" \
    2>&1 | tee "$logfile"

  echo ""
  _pq_status
}

# --- qra: Run all ---

_pq_run_all() {
  echo "Running all pending tasks..."
  echo ""

  while true; do
    local num=$(_pq_next_pending)
    [[ -z "$num" ]] && break

    _pq_run
    local exit_code=$?

    # Check if the task we just ran is still pending or failed
    if grep -q "## Task $num \[failed\]" "$_PQ_QUEUE" 2>/dev/null; then
      echo ""
      echo "Task $num failed. Stopping queue."
      return 1
    fi

    if grep -q "## Task $num \[pending\]" "$_PQ_QUEUE" 2>/dev/null; then
      echo ""
      echo "Task $num still pending after run (Claude may not have updated status). Stopping."
      return 1
    fi

    echo ""
    echo "---"
    echo ""
  done

  echo "All tasks complete."
}

# --- qe: Edit ---

_pq_edit() {
  ${EDITOR:-nvim} "$_PQ_QUEUE"
}

# --- ql: Log ---

_pq_log() {
  local task_num="$1"

  if [[ -n "$task_num" ]]; then
    # Show log for specific task
    local logfile=$(ls -t "$_PQ_LOGS"/task-${task_num}-*.log 2>/dev/null | head -1)
    if [[ -z "$logfile" ]]; then
      echo "No log found for task $task_num."
      return 1
    fi
    less "$logfile"
  else
    # Show latest log
    local logfile=$(ls -t "$_PQ_LOGS"/*.log 2>/dev/null | head -1)
    if [[ -z "$logfile" ]]; then
      echo "No logs found."
      return 1
    fi
    less "$logfile"
  fi
}

# --- qc: Clear/archive ---

_pq_clear() {
  if [[ ! -f "$_PQ_QUEUE" ]]; then
    echo "No queue to archive."
    return 1
  fi

  local timestamp=$(date +%Y%m%d-%H%M%S)
  mv "$_PQ_QUEUE" "$_PQ_ARCHIVE/queue-${timestamp}.md"
  echo "Archived to $_PQ_ARCHIVE/queue-${timestamp}.md"

  # Create fresh queue
  cat > "$_PQ_QUEUE" <<'EOF'
# Prompt Queue

> Tasks for Claude Code to execute sequentially.

EOF
  echo "Queue cleared."
}

# --- qh: Help ---

_pq_help() {
  cat <<'EOF'
Prompt Queue — task queue for Claude Code

  qq  "task" ["checkpoint"]  Add task (default checkpoint: no errors)
  qs                         Show queue status
  qr                         Run next pending task
  qra                        Run all pending tasks
  qe                         Edit queue.md in $EDITOR
  ql  [N]                    View log (latest or task N)
  qc                         Archive queue and start fresh
  qi                         Init ~/.prompt-queue/
  qh                         Show this help
EOF
}

# --- Public aliases ---

alias qq='_pq_add'
alias qs='_pq_status'
alias qr='_pq_run'
alias qra='_pq_run_all'
alias qe='_pq_edit'
alias ql='_pq_log'
alias qc='_pq_clear'
alias qi='_pq_init'
alias qh='_pq_help'
