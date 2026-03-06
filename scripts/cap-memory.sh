#!/bin/bash
# Kill targeted processes that exceed memory limits.
# gopls: editor auto-restarts it.
# claude: only kills child/worker processes, not the main CLI session.

MEM_LIMIT_KB=4000000 # ~4GB
TARGETS=("gopls" "claude" "combine" "compile" "go")

for target in "${TARGETS[@]}"; do
  ps -eo pid,rss,command | grep -i "$target" | grep -v grep | while read -r pid rss _rest; do
    if [ "$rss" -gt "$MEM_LIMIT_KB" ] 2>/dev/null; then
      logger -t cap-memory "Killing $target (PID $pid) using $((rss / 1024))MB (limit: $((MEM_LIMIT_KB / 1024))MB)"
      kill "$pid"
    fi
  done
done
