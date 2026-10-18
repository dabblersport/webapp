#!/usr/bin/env python3
"""Offline checks of the mobile release watcher logic (KAN-568)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import mobile_tracking as t  # noqa: E402


class Parse(unittest.TestCase):
    def test_empty_is_no_work(self):
        self.assertEqual(t.parse(""), [])
        self.assertEqual(t.parse(None), [])

    def test_valid(self):
        got = t.parse('[{"platform":"ios","versionName":"1.7.9","buildNumber":"176"},'
                      '{"platform":"android","versionName":"1.7.9","versionCode":"175","track":"internal"}]')
        self.assertEqual(len(got), 2)

    def test_invalid_rejected(self):
        for bad in ('{"a":1}', '[{"platform":"web","versionName":"1","buildNumber":"1"}]',
                    '[{"platform":"ios","versionName":"","buildNumber":"1"}]',
                    '[{"platform":"ios","versionName":"1.0.0","buildNumber":"x"}]',
                    '[{"platform":"android","versionName":"1.0.0","buildNumber":"1"}]'):
            with self.assertRaises(ValueError):
                t.parse(bad)


class Judge(unittest.TestCase):
    def test_available_only_when_confirmed(self):
        self.assertEqual(t.judge("ios", {"available": "confirmed", "uploaded": True})[0], "available")
        self.assertEqual(t.judge("ios", {"available": "unconfirmed", "uploaded": True})[0], "waiting")

    def test_ios_rejection_and_blockers(self):
        self.assertEqual(t.judge("ios", {"review": "rejected", "submission": "REJECTED", "uploaded": True})[0], "rejected")
        self.assertEqual(t.judge("ios", {"testflightBlocker": "MISSING_EXPORT_COMPLIANCE", "uploaded": True})[0], "blocked")
        self.assertEqual(t.judge("ios", {"processing": "INVALID", "uploaded": True})[0], "blocked")

    def test_android_halted_is_terminal(self):
        rep = {"uploaded": True, "onTrack": [{"track": "production", "status": "halted"}], "available": "unconfirmed"}
        self.assertEqual(t.judge("android", rep)[0], "rejected")

    def test_in_review_keeps_waiting(self):
        rep = {"uploaded": True, "review": "in-review", "available": "unconfirmed"}
        self.assertEqual(t.judge("ios", rep)[0], "waiting")

    def test_not_uploaded_waits(self):
        self.assertEqual(t.judge("ios", {"uploaded": False})[1], "not uploaded yet")


if __name__ == "__main__":
    unittest.main(verbosity=2)
