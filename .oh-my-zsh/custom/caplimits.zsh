# Set up cron jobs for CPU and memory capping (idempotent).
# Ensures cpulimit is available and cron entries exist.

_setup_cap_limits() {
  # Require cpulimit
  if ! command -v cpulimit &>/dev/null; then
    return
  fi

  local cap_cpu="$HOME/scripts/cap-cpu.sh"
  local cap_mem="$HOME/scripts/cap-memory.sh"

  # Ensure scripts exist
  if [[ ! -f "$cap_cpu" || ! -f "$cap_mem" ]]; then
    return
  fi

  # Make scripts executable
  chmod +x "$cap_cpu" "$cap_mem" 2>/dev/null

  local current_crontab
  current_crontab=$(crontab -l 2>/dev/null || echo "")

  local needs_update=false
  local new_crontab="$current_crontab"

  if ! echo "$current_crontab" | grep -q "cap-cpu.sh"; then
    new_crontab="$new_crontab
* * * * * /bin/bash $cap_cpu"
    needs_update=true
  fi

  if ! echo "$current_crontab" | grep -q "cap-memory.sh"; then
    new_crontab="$new_crontab
* * * * * /bin/bash $cap_mem"
    needs_update=true
  fi

  if $needs_update; then
    echo "$new_crontab" | crontab -
  fi
}

_setup_cap_limits
