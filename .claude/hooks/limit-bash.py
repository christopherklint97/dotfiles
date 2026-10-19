#!/usr/bin/env python3
"""PreToolUse hook: run every Bash command Claude issues inside its own capped systemd scope,
so a runaway build/test is killed on its own instead of throttling Claude sessions or the Pi.
Only rewrites in bypassPermissions sessions (where the command would run unprompted anyway);
other sessions fall back to the aggregate cgroup caps. See ~/dotfiles/system/mainframe/PI-RESOURCE-LIMITS.md."""
import json
import shlex
import sys

LIMITS = [
    "MemoryMax=2G",
    "MemorySwapMax=256M",
    "CPUQuota=150%",
    "CPUWeight=30",
    "TasksMax=1024",
]
MARK = "systemd-run --user --scope --quiet --collect"

def main() -> None:
    try:
        event = json.load(sys.stdin)
    except Exception:
        return
    if event.get("tool_name") != "Bash" or event.get("permission_mode") != "bypassPermissions":
        return
    tool_input = dict(event.get("tool_input") or {})
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip() or command.lstrip().startswith(MARK):
        return
    props = " ".join(f"-p {p}" for p in LIMITS)
    tool_input["command"] = (
        f"{MARK} {props} -- nice -n 5 \"${{SHELL:-/bin/sh}}\" -c {shlex.quote(command)}"
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "bypass session; command wrapped in a capped scope",
                "updatedInput": tool_input,
            }
        },
        sys.stdout,
    )

if __name__ == "__main__":
    main()
