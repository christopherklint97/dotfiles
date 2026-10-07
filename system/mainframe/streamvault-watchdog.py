#!/usr/bin/python3
"""Recover a hung running StreamVault without restarting intentionally stopped containers."""
import datetime
import json
from pathlib import Path
import subprocess
import time
import urllib.request

STATE = Path('/run/streamvault-watchdog/state.json')

def recovery_needed(container, healthy, busy, state, now):
    status = container['State']
    started = datetime.datetime.fromisoformat(status['StartedAt'].replace('Z', '+00:00')).timestamp()
    if not status['Running'] or status.get('Paused') or now - started < 600 or healthy or busy:
        return {'failures': 0, 'last_restart': state.get('last_restart', 0)}, False
    state = {'failures': state.get('failures', 0) + 1, 'last_restart': state.get('last_restart', 0)}
    return state, state['failures'] >= 3 and now - state['last_restart'] >= 1800

def database_signature(container):
    """Return data-file activity without opening or scanning the live database."""
    mounts = container.get('Mounts') or []
    data_mount = next((m for m in mounts if m.get('Destination') == '/app/data'), None)
    if not data_mount or not data_mount.get('Source'):
        return None
    root = Path(data_mount['Source'])
    signature = []
    for name in ('streamvault.db', 'streamvault.db-wal'):
        try:
            stat = (root / name).stat()
            signature.append([name, stat.st_size, stat.st_mtime_ns])
        except OSError:
            continue
    return signature or None

def has_active_transcoder():
    try:
        result = subprocess.run(
            ['docker', 'top', 'streamvault-server', '-eo', 'comm'],
            capture_output=True, text=True, timeout=5, check=True,
        )
        return any(line.strip() == 'ffmpeg' for line in result.stdout.splitlines()[1:])
    except (OSError, subprocess.SubprocessError):
        # Failure to inspect activity must not itself make a restart more likely.
        return True

def main():
    try:
        result = subprocess.run(
            ['docker', 'inspect', 'streamvault-server'],
            capture_output=True, timeout=10, check=True,
        )
        container = json.loads(result.stdout)[0]
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'StreamVault watchdog inspection skipped: {error}', flush=True)
        return
    try:
        with urllib.request.urlopen('http://127.0.0.1:3002/api/health', timeout=5) as response:
            body = json.load(response)
            healthy = body.get('ok') is True and body.get('service') == 'streamvault'
    except (OSError, ValueError):
        healthy = False
    try:
        state = json.loads(STATE.read_text())
    except (OSError, ValueError):
        state = {}
    now = time.time()
    signature = database_signature(container)
    previous_signature = state.get('database_signature')
    database_progress = signature is not None and signature != previous_signature
    busy = database_progress or has_active_transcoder()
    state, restart = recovery_needed(container, healthy, busy, state, now)
    state['database_signature'] = signature
    if restart:
        # Save before attempting recovery so failures cannot cause a restart storm.
        state.update(failures=0, last_restart=now)
    STATE.parent.mkdir(parents=True, exist_ok=True)
    temp = STATE.with_suffix('.tmp')
    temp.write_text(json.dumps(state))
    temp.replace(STATE)
    if restart:
        print('StreamVault failed three consecutive idle checks; restarting (30-minute cooldown)', flush=True)
        subprocess.run(['docker', 'restart', '--time', '30', 'streamvault-server'], timeout=45, check=True)
    elif state['failures']:
        print(f"StreamVault health failures: {state['failures']}", flush=True)
    elif busy and not healthy:
        print('StreamVault is busy and making progress; restart suppressed', flush=True)

if __name__ == '__main__':
    main()
