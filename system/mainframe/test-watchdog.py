import datetime
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('watchdog', Path(__file__).with_name('streamvault-watchdog.py'))
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)

class RecoveryTests(unittest.TestCase):
    def container(self, **overrides):
        state = dict(Running=True, Paused=False, StartedAt='2026-09-16T20:00:00Z')
        state.update(overrides)
        return {'State': state}

    def test_three_failures_and_cooldown(self):
        now = datetime.datetime.fromisoformat('2026-09-16T21:00:00+00:00').timestamp()
        state = {}
        for expected in (False, False, True):
            state, restart = w.recovery_needed(self.container(), False, False, state, now)
            self.assertEqual(restart, expected)
        self.assertFalse(w.recovery_needed(self.container(), False, False, {'failures': 10, 'last_restart': now-60}, now)[1])

    def test_skip_stopped_paused_startup_success_and_busy_work(self):
        now = datetime.datetime.fromisoformat('2026-09-16T20:01:00+00:00').timestamp()
        cases = [
            (self.container(), False, False, now),
            (self.container(Running=False), False, False, now + 1000),
            (self.container(Paused=True), False, False, now + 1000),
            (self.container(), True, False, now + 1000),
            (self.container(), False, True, now + 1000),
        ]
        for container, healthy, busy, t in cases:
            state, restart = w.recovery_needed(container, healthy, busy, {'failures': 10}, t)
            self.assertFalse(restart)
            self.assertEqual(state['failures'], 0)

    def test_database_signature_tracks_wal_progress(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database = root / 'streamvault.db'
            wal = root / 'streamvault.db-wal'
            database.write_bytes(b'db')
            container = {'Mounts': [{'Destination': '/app/data', 'Source': directory}]}
            first = w.database_signature(container)
            wal.write_bytes(b'progress')
            second = w.database_signature(container)
            self.assertNotEqual(first, second)
            self.assertIsNone(w.database_signature({'Mounts': []}))

unittest.main()
