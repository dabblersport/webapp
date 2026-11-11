#!/usr/bin/env python3
"""Safety regression for the KAN-887 disposable proof workspace."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name('kan887_part2_after_kan794_test.sh').resolve()


class CleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='kan887_cleanup_', dir='/private/tmp')
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.sentinel = self.root / 'untouched'
        self.sentinel.write_text('original')
        (self.bin / 'pg_ctl').write_text('#!/bin/sh\necho called >> "' + str(self.root / 'pg_called') + '"\n')
        (self.bin / 'pg_ctl').chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_proof(self, path):
        return subprocess.run(['bash', str(SCRIPT), str(path), '55987'], env=self.env,
                              capture_output=True, text=True, timeout=15)

    def fake_git(self, body):
        git = self.bin / 'git'
        git.write_text('#!/bin/sh\n' + body + '\n')
        git.chmod(0o755)

    def test_existing_and_symlinks_are_rejected(self):
        existing = self.root / 'existing'
        existing.mkdir()
        (existing / 'data').write_text('keep')
        link = self.root / 'link'
        link.symlink_to(existing, target_is_directory=True)
        dangling = self.root / 'dangling'
        dangling.symlink_to(self.root / 'absent', target_is_directory=True)
        for path in (existing, link, dangling, link / 'nested'):
            with self.subTest(path=path):
                self.assertNotEqual(self.run_proof(path).returncode, 0)
                self.assertEqual((existing / 'data').read_text(), 'keep')
        self.assertTrue(link.is_symlink())
        self.assertTrue(dangling.is_symlink())
        self.assertFalse((self.root / 'pg_called').exists())

    def test_failure_removes_only_owned_workspace(self):
        self.fake_git('exit 42')
        work = self.root / 'new'
        self.assertNotEqual(self.run_proof(work).returncode, 0)
        self.assertFalse(work.exists())
        self.assertEqual(self.sentinel.read_text(), 'original')
        self.assertFalse((self.root / 'pg_called').exists())

    def test_failed_stop_preserves_workspace(self):
        work = self.root / 'new'
        self.fake_git('mkdir -p "' + str(work / 'cluster') + '"\ntouch "' +
                      str(work / 'cluster/postmaster.pid') + '"\nexit 42')
        pg_ctl = self.bin / 'pg_ctl'
        pg_ctl.write_text('#!/bin/sh\necho called > "' + str(self.root / 'pg_called') + '"\nexit 1\n')
        result = self.run_proof(work)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not stop cluster', result.stderr)
        self.assertTrue((work / 'cluster/postmaster.pid').exists())
        self.assertTrue((self.root / 'pg_called').exists())
        self.assertEqual(self.sentinel.read_text(), 'original')

    def test_interrupt_removes_only_owned_workspace(self):
        ready = self.root / 'ready'
        self.fake_git('touch "' + str(ready) + '"\nsleep 2\nexit 42')
        work = self.root / 'new'
        proc = subprocess.Popen(['bash', str(SCRIPT), str(work), '55987'], env=self.env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(.02)
            self.assertTrue(ready.exists())
            proc.send_signal(signal.SIGTERM)
            self.assertNotEqual(proc.wait(timeout=10), 0)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
        self.assertFalse(work.exists())
        self.assertEqual(self.sentinel.read_text(), 'original')
        self.assertFalse((self.root / 'pg_called').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
