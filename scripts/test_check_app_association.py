#!/usr/bin/env python3
"""Offline tests for scripts/check_app_association.py (KAN-597). No network.

    python3 scripts/test_check_app_association.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_app_association as c  # noqa: E402

APP = "J5636UH8V8.app.dabbler.pro"
OTHER = "ZZZZZZZZZZ.com.other.app"


def comps(*paths):
    return [{"/": f"/{p}/*"} for p in paths]


ALL = ("game", "post", "venue", "meetups", "u")


class MissingPaths(unittest.TestCase):
    def test_the_right_app_id_with_every_path_passes(self):
        aasa = {"applinks": {"details": [{"appIDs": [APP], "components": comps(*ALL)}]}}
        self.assertEqual(c.missing_paths(aasa, APP), [])

    def test_a_wrong_app_id_fails_every_path(self):
        aasa = {"applinks": {"details": [{"appIDs": [OTHER], "components": comps(*ALL)}]}}
        self.assertEqual(c.missing_paths(aasa, APP), list(ALL))

    def test_paths_split_across_entries_with_the_right_id_pass(self):
        aasa = {"applinks": {"details": [
            {"appIDs": [APP], "components": comps("game", "post")},
            {"appIDs": [OTHER, APP], "components": comps("venue", "meetups")},
            {"appID": APP, "paths": ["/u/*"]},
        ]}}
        self.assertEqual(c.missing_paths(aasa, APP), [])

    def test_paths_on_another_apps_entry_do_not_count(self):
        # game/post belong to the right app, the rest sit in an entry for a different app.
        aasa = {"applinks": {"details": [
            {"appIDs": [APP], "components": comps("game", "post")},
            {"appIDs": [OTHER], "components": comps("venue", "meetups", "u")},
        ]}}
        self.assertEqual(c.missing_paths(aasa, APP), ["venue", "meetups", "u"])

    def test_an_empty_or_malformed_file_misses_everything(self):
        self.assertEqual(c.missing_paths({}, APP), list(ALL))
        self.assertEqual(c.missing_paths({"applinks": {"details": [{}]}}, APP), list(ALL))


class AppIdFromProject(unittest.TestCase):
    def block(self, team, bundle, entitlements=True):
        ent = "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n" if entitlements else ""
        return (
            "\t\t\tbuildSettings = {\n" + ent +
            f"\t\t\t\tDEVELOPMENT_TEAM = {team};\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle};\n\t\t\t}};\n"
        )

    def test_the_app_target_is_read_and_the_test_target_ignored(self):
        text = self.block("ABCDE12345", "com.example.app") + self.block("ABCDE12345", "com.example.app.RunnerTests", False)
        self.assertEqual(c.app_id_from_project(text), "ABCDE12345.com.example.app")

    def test_two_different_app_ids_are_refused(self):
        text = self.block("AAAAAAAAAA", "com.a") + self.block("BBBBBBBBBB", "com.b")
        with self.assertRaises(ValueError):
            c.app_id_from_project(text)

    def test_no_app_target_is_refused(self):
        with self.assertRaises(ValueError):
            c.app_id_from_project(self.block("AAAAAAAAAA", "com.a", False))

    def test_the_real_project_gives_the_app_id_the_committed_aasa_names(self):
        import json
        with open(c.PROJECT, encoding="utf-8") as fh:
            app_id = c.app_id_from_project(fh.read())
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
        with open(os.path.join(root, "web", ".well-known", "apple-app-site-association"), encoding="utf-8") as fh:
            aasa = json.load(fh)
        self.assertEqual(c.missing_paths(aasa, app_id), [])


if __name__ == "__main__":
    unittest.main()
