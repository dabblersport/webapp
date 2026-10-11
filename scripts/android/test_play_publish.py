#!/usr/bin/env python3
"""Offline tests for the pure logic in play_publish.py (KAN-493). No network, no credentials.

    python3 scripts/android/test_play_publish.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_publish as pp  # noqa: E402


def track(name, *releases):
    return {"track": name, "releases": list(releases)}


def rel(status, *codes, **extra):
    return dict({"status": status, "versionCodes": [str(c) for c in codes]}, **extra)


class VersionCodeCheck(unittest.TestCase):
    def test_a_new_higher_code_is_accepted(self):
        self.assertTrue(pp.check_version_code(175, [173, 174])[0])
        self.assertTrue(pp.check_version_code(1, [])[0])

    def test_a_duplicate_is_refused(self):
        ok, why = pp.check_version_code(174, [173, 174])
        self.assertFalse(ok)
        self.assertIn("already uploaded", why)

    def test_a_lower_code_is_refused(self):
        ok, why = pp.check_version_code(170, [173, 174])
        self.assertFalse(ok)
        self.assertIn("lower than the highest", why)


class Stages(unittest.TestCase):
    def test_not_uploaded(self):
        r = pp.stage_report(175, [174], [track("internal", rel("completed", 174))])
        self.assertEqual(r["state"], "not-uploaded")
        self.assertFalse(r["uploaded"])
        self.assertEqual(r["available"], "unconfirmed")

    def test_uploaded_but_not_released(self):
        r = pp.stage_report(175, [174, 175], [track("internal", rel("completed", 174))])
        self.assertEqual(r["state"], "uploaded-not-released")
        self.assertTrue(r["uploaded"] and r["processed"])
        self.assertEqual(r["onTrack"], [])

    def test_internal_completed_is_available_without_review(self):
        r = pp.stage_report(175, [175], [track("internal", rel("completed", 175))])
        self.assertEqual(r["state"], "available")
        self.assertEqual(r["available"], "confirmed")
        self.assertEqual(r["review"], "not-exposed-by-api")

    def test_production_completed_is_not_available_until_the_store_page_shows_it(self):
        tr = [track("production", rel("completed", 175))]
        self.assertEqual(pp.stage_report(175, [175], tr, None)["available"], "unconfirmed")
        self.assertEqual(pp.stage_report(175, [175], tr, False)["state"],
                         "submitted-awaiting-availability")
        self.assertEqual(pp.stage_report(175, [175], tr, True)["state"], "available")

    def test_draft_and_halted_are_reported_as_such(self):
        self.assertEqual(
            pp.stage_report(175, [175], [track("production", rel("draft", 175))])["state"],
            "draft-on-track")
        self.assertEqual(
            pp.stage_report(175, [175], [track("production", rel("halted", 175))])["state"],
            "halted")

    def test_other_versions_on_the_track_are_ignored(self):
        r = pp.stage_report(175, [174, 175],
                            [track("production", rel("completed", 174), rel("draft", 175))])
        self.assertEqual([x["status"] for x in r["onTrack"]], ["draft"])


class Cli(unittest.TestCase):
    def test_upload_requires_a_known_track(self):
        with self.assertRaises(SystemExit):
            pp.main(["upload", "--package", "p", "--version-code", "1", "--credentials", "x",
                     "--aab", "a.aab", "--track", "alpha"])

    def test_the_script_never_prints_the_credentials_path_contents(self):
        src = open(pp.__file__, encoding="utf-8").read()
        self.assertNotIn("private_key", src)


if __name__ == "__main__":
    unittest.main()
