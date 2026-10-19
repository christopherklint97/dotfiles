#!/usr/bin/env python3
"""PreToolUse hook: run every Bash command Claude issues inside its own capped systemd scope,
so a runaway build/test is killed on its own instead of throttling Claude sessions or the Pi.
Only rewrites in bypassPermissions sessions (where the command would run unprompted anyway);
other sessions fall back to the aggregate cgroup caps. See ~/dotfiles/system/mainframe/PI-RESOURCE-LIMITS.md."""
import json
import re
import shlex
import sys

# A bare `cd` must run in Claude's persistent shell so the working directory sticks.
PLAIN_CD = re.compile(r"^\s*cd(\s+[^;&|<>`$()]*)?\s*$")

LIMITS = [
    "MemoryMax=3G",
    "MemorySwapMax=512M",
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
    # Worktree-isolated subagents: the harness must be able to verify their commands stay in
    # the worktree, which a wrapped command defeats. They remain bounded by the aggregate
    # hapi-runner / user-slice caps and earlyoom.
    if "/.claude/worktrees/" in str(event.get("cwd") or ""):
        return
    tool_input = dict(event.get("tool_input") or {})
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip() or command.lstrip().startswith(MARK):
        return
    if PLAIN_CD.match(command):
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
