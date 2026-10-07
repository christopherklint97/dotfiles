#!/usr/bin/python3
"""Recover the mainframe's tailnet DNS after repeated failures."""

from __future__ import annotations

import json
import os
from pathlib import Path
import random
import socket
import struct
import subprocess
import sys
import time

SERVER = "100.81.170.62"
STATE_DIR = Path("/var/lib/mainframe-dns-watchdog")
STATE_FILE = STATE_DIR / "state.json"
FAILURES_BEFORE_RECOVERY = 3
RECOVERY_COOLDOWN_SECONDS = 300


def dns_works() -> tuple[bool, str]:
    """Require a valid recursive UDP reply (success or NXDOMAIN)."""
    transaction_id = random.SystemRandom().randrange(0, 65536)
    # A unique name prevents AdGuard's optimistic cache from masking upstream loss.
    labels = [f"watch-{time.time_ns():x}".encode(), b"example", b"com"]
    question = b"".join(bytes([len(label)]) + label for label in labels) + b"\0"
    packet = struct.pack("!HHHHHH", transaction_id, 0x0100, 1, 0, 0, 0)
    packet += question + struct.pack("!HH", 1, 1)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(3.0)
            sock.sendto(packet, (SERVER, 53))
            reply, _ = sock.recvfrom(4096)
    except OSError as error:
        return False, f"transport:{type(error).__name__}"
    if len(reply) < 12:
        return False, "short-response"
    reply_id, flags = struct.unpack("!HH", reply[:4])
    rcode = flags & 0x000F
    if reply_id != transaction_id or not flags & 0x8000:
        return False, "invalid-response"
    if rcode not in (0, 3):
        return False, f"rcode:{rcode}"
    return True, f"rcode:{rcode}"


def load_state() -> dict[str, int]:
    try:
        value = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return {
            "failures": max(0, int(value.get("failures", 0))),
            "last_recovery": max(0, int(value.get("last_recovery", 0))),
        }
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return {"failures": 0, "last_recovery": 0}


def save_state(state: dict[str, int]) -> None:
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = STATE_FILE.with_suffix(f".tmp.{os.getpid()}")
    data = json.dumps(state, sort_keys=True, separators=(",", ":")) + "\n"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, STATE_FILE)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def run(command: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=timeout,
        check=False,
    )


def tailscale_is_ready() -> bool:
    active = run(["systemctl", "is-active", "--quiet", "tailscaled.service"], 5)
    if active.returncode != 0:
        return False
    address = subprocess.run(
        ["tailscale", "ip", "-4"],
        text=True,
        capture_output=True,
        timeout=5,
        check=False,
    )
    return address.returncode == 0 and SERVER in address.stdout.split()


def main() -> int:
    working, detail = dns_works()
    state = load_state()
    now = int(time.time())
    if working:
        if state["failures"]:
            print(f"DNS recovered without intervention ({detail})")
        if state["failures"]:
            save_state({"failures": 0, "last_recovery": state["last_recovery"]})
        return 0

    failures = state["failures"] + 1
    print(f"DNS health check failed ({detail}); consecutive_failures={failures}")
    if failures < FAILURES_BEFORE_RECOVERY:
        save_state({"failures": failures, "last_recovery": state["last_recovery"]})
        return 0
    if now - state["last_recovery"] < RECOVERY_COOLDOWN_SECONDS:
        save_state({"failures": failures, "last_recovery": state["last_recovery"]})
        return 0

    # Persist cooldown before intervention, including when a subprocess times out.
    save_state({"failures": 0, "last_recovery": now})
    if not tailscale_is_ready():
        print("Tailscale is not ready; restarting tailscaled")
        result = run(["systemctl", "restart", "tailscaled.service"], 30)
        if result.returncode != 0:
            print("tailscaled restart failed", file=sys.stderr)
        time.sleep(5)

    print("Restarting AdGuard Home after repeated end-to-end DNS failures")
    result = run(["docker", "restart", "adguard-home"], 45)
    save_state({"failures": 0, "last_recovery": now})
    if result.returncode != 0:
        print("AdGuard Home restart failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
