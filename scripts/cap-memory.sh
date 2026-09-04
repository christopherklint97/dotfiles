#!/bin/bash
# Kill targeted processes that exceed memory limits.
# gopls: editor auto-restarts it.
# claude: only kills child/worker processes, not the main CLI session.

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
acquire_lock cap-memory
lock_status=$?
[[ $lock_status -eq 1 ]] && exit 0
[[ $lock_status -eq 0 ]] || exit "$lock_status"
release_lock() { rm -f "$LOCK_FILE"; }
trap release_lock EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

MEM_LIMIT_KB=4000000 # ~4GB
TARGETS=("gopls" "claude" "combine" "compile" "go" "node")

for target in "${TARGETS[@]}"; do
  ps -eo pid,rss,command | grep -i "$target" | grep -v grep | while read -r pid rss _rest; do
    if [ "$rss" -gt "$MEM_LIMIT_KB" ] 2>/dev/null; then
      logger -t cap-memory "Killing $target (PID $pid) using $((rss / 1024))MB (limit: $((MEM_LIMIT_KB / 1024))MB)"
      kill "$pid"
    fi
  done
done
