#!/bin/bash
# Cap CPU usage for targeted processes using cpulimit.
# Runs as a cron job every minute. Idempotent — skips already-managed PIDs.

acquire_lock() {
  local name="$1" owner_pid="" candidate create_status
  umask 077
  CACHE_DIR="$HOME/.cache"
  LOCK_ROOT="$CACHE_DIR/process-caps"
  [[ ! -L "$CACHE_DIR" && ! -L "$LOCK_ROOT" ]] || return 2
  mkdir -p "$LOCK_ROOT" || return 2
  chmod 700 "$CACHE_DIR" "$LOCK_ROOT" || return 2
  [[ -d "$CACHE_DIR" && -O "$CACHE_DIR" && -d "$LOCK_ROOT" && -O "$LOCK_ROOT" ]] || return 2
  LOCK_FILE="$LOCK_ROOT/$name.lock"
  candidate="$LOCK_ROOT/.$name.$$.$RANDOM"
  (set -o noclobber; printf '%s\n' "$$" > "$candidate") 2>/dev/null || return 2
  if ln "$candidate" "$LOCK_FILE" 2>/dev/null; then
    rm -f "$candidate"
    return 0
  fi
  rm -f "$candidate"
  [[ -f "$LOCK_FILE" && ! -L "$LOCK_FILE" && -O "$LOCK_FILE" ]] || return 2
  read -r owner_pid < "$LOCK_FILE" || owner_pid=""
  if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
    return 1
  fi
  rm -f "$LOCK_FILE" || return 2
  candidate="$LOCK_ROOT/.$name.$$.$RANDOM"
  (set -o noclobber; printf '%s\n' "$$" > "$candidate") 2>/dev/null || return 2
  ln "$candidate" "$LOCK_FILE" 2>/dev/null
  create_status=$?
  rm -f "$candidate"
  [[ $create_status -eq 0 ]] && return 0
  return 1
}

# Cron may start late under load.  Never allow delayed runs to overlap and
# amplify the resource pressure they are intended to reduce.  A private atomic
# lock directory is portable across Linux and macOS and cannot leak to children.
acquire_lock cap-cpu
lock_status=$?
[[ $lock_status -eq 1 ]] && exit 0
[[ $lock_status -eq 0 ]] || exit "$lock_status"
release_lock() { rm -f "$LOCK_FILE"; }
trap release_lock EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

CPU_LIMIT=300 # percent (100 = 1 core, 300 = 3 cores)
TARGETS=("gopls" "claude" "combine" "compile" "go" "node")

for target in "${TARGETS[@]}"; do
  pgrep -f "$target" 2>/dev/null | while read -r pid; do
    # Skip if cpulimit is already managing this PID
    if pgrep -f "cpulimit.*--pid $pid" > /dev/null 2>&1; then
      continue
    fi
    cpulimit --pid "$pid" --limit "$CPU_LIMIT" --background > /dev/null 2>&1
  done
done
