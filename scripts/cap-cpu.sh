#!/bin/bash
# Cap CPU usage for targeted processes using cpulimit.
# Runs as a cron job every minute. Idempotent — skips already-managed PIDs.

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
