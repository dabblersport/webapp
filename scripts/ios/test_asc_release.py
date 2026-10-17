#!/usr/bin/env python3
"""Offline checks of the iOS release logic (KAN-568). No network, no credentials, no PyJWT needed."""
import io
import json
import os
import sys
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(__file__))
import asc_release as r  # noqa: E402
import prepare_manual_signing as p  # noqa: E402

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "..", "ios", "Runner.xcodeproj", "project.pbxproj")


class FakeClient:
    """Answers the few GETs the commands make; records every write."""

    def __init__(self, builds, versions, beta=None):
        self.builds, self.versions, self.beta, self.writes = builds, versions, beta, []

    def get(self, path, params=None):
        if path == "/v1/apps":
            return {"data": [{"id": "APP1"}]}
        if path == "/v1/builds":
            return self.builds
        if path.endswith("/buildBetaDetail"):
            return {"data": {"attributes": self.beta}} if self.beta else {"data": None}
        if path.endswith("/appStoreVersions"):
            return {"data": self.versions}
        raise AssertionError("unexpected GET " + path)

    def request(self, method, path, params=None, body=None):
        self.writes.append((method, path))
        return {"data": {"id": "SUB1"}}


def builds_payload(*rows):
    return {"data": [{"id": "B%s" % n, "attributes": {"version": str(n), "processingState": st, "expired": False,
                                                       "uploadedDate": "2026-10-18"},
                      "relationships": {"preReleaseVersion": {"data": {"id": "PV" + v}}}}
                     for n, st, v in rows],
            "included": [{"type": "preReleaseVersions", "id": "PV" + v, "attributes": {"version": v}}
                         for v in sorted({v for _, _, v in rows})]}


class BuildNumberGuard(unittest.TestCase):
    def test_new_higher_number_is_ok(self):
        self.assertTrue(r.check_build_number(176, ["174", "175"])[0])

    def test_duplicate_refused(self):
        ok, why = r.check_build_number(175, ["174", "175"])
        self.assertFalse(ok)
        self.assertIn("already uploaded", why)

    def test_lower_refused(self):
        self.assertFalse(r.check_build_number(10, ["174"])[0])

    def test_first_build_ok(self):
        self.assertTrue(r.check_build_number(1, [])[0])

    def test_next_number(self):
        self.assertEqual(r.next_build_number(["174", "175", "x"]), 176)
        self.assertEqual(r.next_build_number([]), 1)

    def test_build_number_must_be_a_positive_integer(self):
        for bad in ("", "0", "-1", "1.5", "abc", "1 2"):
            with self.assertRaises(ValueError):
                r.build_number_value(bad)
        self.assertEqual(r.build_number_value(" 42 "), 42)


class Stages(unittest.TestCase):
    def build(self, state="VALID"):
        return r.parse_builds(builds_payload((176, state, "1.7.9")))[0]

    def test_not_uploaded(self):
        rep = r.stage_report(None, None, [], None)
        self.assertFalse(rep["uploaded"])
        self.assertEqual(rep["available"], "unconfirmed")

    def test_processing_vs_testflight_are_distinct(self):
        rep = r.stage_report(self.build("PROCESSING"), None, [], None)
        self.assertEqual((rep["uploaded"], rep["processing"], rep["testflight"]), (True, "PROCESSING", None))
        rep = r.stage_report(self.build("VALID"), {"internalBuildState": "IN_BETA_TESTING"}, [], None)
        self.assertEqual((rep["processing"], rep["testflight"]), ("VALID", "IN_BETA_TESTING"))
        self.assertEqual(rep["review"], "none")
        self.assertEqual(rep["available"], "unconfirmed")

    def test_compliance_blocker_is_reported(self):
        rep = r.stage_report(self.build(), {"internalBuildState": "MISSING_EXPORT_COMPLIANCE"}, [], None)
        self.assertEqual(rep["testflightBlocker"], "MISSING_EXPORT_COMPLIANCE")

    def version(self, state, name="1.7.9"):
        return {"id": "V1", "attributes": {"versionString": name, "appVersionState": state}}

    def test_review_stages(self):
        for state, review in (("PREPARE_FOR_SUBMISSION", "not-submitted"), ("WAITING_FOR_REVIEW", "waiting-for-review"),
                              ("IN_REVIEW", "in-review"), ("REJECTED", "rejected"), ("UNRESOLVED_ISSUES", "rejected"),
                              ("PENDING_DEVELOPER_RELEASE", "approved"), ("READY_FOR_SALE", "approved")):
            rep = r.stage_report(self.build(), None, [self.version(state)], None)
            self.assertEqual(rep["review"], review, state)
            self.assertEqual(rep["submission"], state)

    def test_available_needs_an_independent_signal(self):
        v = [self.version("READY_FOR_SALE")]
        self.assertEqual(r.stage_report(self.build(), None, v, None)["available"], "unconfirmed")
        self.assertEqual(r.stage_report(self.build(), None, v, "1.7.8")["available"], "unconfirmed")
        self.assertEqual(r.stage_report(self.build(), None, v, "1.7.9")["available"], "confirmed")
        # approved but not on sale yet is never "available"
        self.assertEqual(r.stage_report(self.build(), None, [self.version("PENDING_DEVELOPER_RELEASE")], "1.7.9")["available"], "unconfirmed")

    def test_other_version_does_not_leak_in(self):
        rep = r.stage_report(self.build(), None, [self.version("READY_FOR_SALE", name="1.7.8")], "1.7.8")
        self.assertEqual(rep["submission"], None)
        self.assertEqual(rep["available"], "unconfirmed")


class Commands(unittest.TestCase):
    def run_cmd(self, argv, client):
        out = io.StringIO()
        with redirect_stdout(out):
            code = r.main(argv + ["--key-file", "/nonexistent.p8", "--key-id", "KID", "--issuer-id", "ISS"], client=client)
        return code, json.loads(out.getvalue().strip().splitlines()[0] if out.getvalue().startswith("{\"") else out.getvalue())

    def test_check_refuses_duplicate(self):
        c = FakeClient(builds_payload((175, "VALID", "1.7.9")), [])
        code, rep = self.run_cmd(["check", "--bundle-id", "app.dabbler.pro", "--build-number", "175"], c)
        self.assertEqual(code, 1)
        self.assertFalse(rep["ok"])

    def test_check_accepts_new(self):
        c = FakeClient(builds_payload((175, "VALID", "1.7.9")), [])
        self.assertEqual(self.run_cmd(["check", "--bundle-id", "app.dabbler.pro", "--build-number", "176"], c)[0], 0)

    def test_next(self):
        c = FakeClient(builds_payload((175, "VALID", "1.7.9")), [])
        code, rep = self.run_cmd(["next", "--bundle-id", "app.dabbler.pro"], c)
        self.assertEqual((code, rep["nextBuildNumber"]), (0, 176))

    def test_submit_is_a_dry_run_without_confirm_and_never_writes(self):
        versions = [{"id": "V1", "attributes": {"versionString": "1.7.9", "appVersionState": "PREPARE_FOR_SUBMISSION"}}]
        c = FakeClient(builds_payload((176, "VALID", "1.7.9")), versions)
        code, rep = self.run_cmd(["submit", "--bundle-id", "app.dabbler.pro", "--version-name", "1.7.9",
                                  "--build-number", "176"], c)
        self.assertEqual(code, 0)
        self.assertTrue(rep["dryRun"])
        self.assertEqual(c.writes, [])

    def test_submit_refuses_unprocessed_build_and_wrong_state(self):
        versions = [{"id": "V1", "attributes": {"versionString": "1.7.9", "appVersionState": "PREPARE_FOR_SUBMISSION"}}]
        c = FakeClient(builds_payload((176, "PROCESSING", "1.7.9")), versions)
        self.assertEqual(self.run_cmd(["submit", "--bundle-id", "b", "--version-name", "1.7.9", "--build-number", "176"], c)[0], 1)
        versions[0]["attributes"]["appVersionState"] = "WAITING_FOR_REVIEW"
        c = FakeClient(builds_payload((176, "VALID", "1.7.9")), versions)
        self.assertEqual(self.run_cmd(["submit", "--bundle-id", "b", "--version-name", "1.7.9", "--build-number", "176"], c)[0], 1)
        self.assertEqual(c.writes, [])

    def test_submit_with_confirm_writes_in_the_documented_order(self):
        versions = [{"id": "V1", "attributes": {"versionString": "1.7.9", "appVersionState": "PREPARE_FOR_SUBMISSION"}}]
        c = FakeClient(builds_payload((176, "VALID", "1.7.9")), versions)
        code, _ = self.run_cmd(["submit", "--bundle-id", "b", "--version-name", "1.7.9", "--build-number", "176", "--confirm"], c)
        self.assertEqual(code, 0)
        self.assertEqual([w[0] for w in c.writes], ["PATCH", "POST", "POST", "PATCH"])


class Token(unittest.TestCase):
    def test_claims_are_short_lived_and_scoped(self):
        c = r.jwt_claims("ISSUER", 1000)
        self.assertEqual((c["iss"], c["aud"], c["exp"] - c["iat"]), ("ISSUER", "appstoreconnect-v1", 600))
        self.assertLessEqual(c["exp"] - c["iat"], 1200)  # Apple's 20 minute ceiling

    def test_no_secret_in_source(self):
        with open(r.__file__, encoding="utf-8") as fh:
            src = fh.read()
        for needle in ("BEGIN PRIVATE KEY", "BEGIN EC PRIVATE KEY", "AuthKey_"):
            self.assertNotIn(needle, src)


class ManualSigning(unittest.TestCase):
    def setUp(self):
        with open(PBXPROJ, encoding="utf-8") as fh:
            self.text = fh.read()

    def test_only_runner_release_and_profile_change(self):
        new, patched = p.patch(self.text, "app.dabbler.pro", "Dabbler App Store")
        self.assertEqual(sorted(patched), ["Profile", "Release"])
        self.assertEqual(new.count("CODE_SIGN_STYLE = Manual;"), 2)
        self.assertEqual(new.count('PROVISIONING_PROFILE_SPECIFIER = "Dabbler App Store";'), 2)
        self.assertEqual(new.count('"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'), 2)
        # Debug (Runner) and the RunnerTests targets keep automatic signing.
        self.assertEqual(self.text.count("CODE_SIGN_STYLE = Automatic;") - new.count("CODE_SIGN_STYLE = Automatic;"), 2)
        self.assertIn("app.dabbler.pro.RunnerTests", new)

    def test_second_run_refuses(self):
        new, _ = p.patch(self.text, "app.dabbler.pro", "Dabbler App Store")
        with self.assertRaises(SystemExit):  # already manual: refuse rather than patch twice
            p.patch(new, "app.dabbler.pro", "Dabbler App Store")

    def test_unknown_bundle_patches_nothing(self):
        _, patched = p.patch(self.text, "com.example.other", "X")
        self.assertEqual(patched, [])


class ExportOptions(unittest.TestCase):
    def test_export_options_match_the_project(self):
        import plistlib
        path = os.path.join(os.path.dirname(__file__), "..", "..", "ios", "ExportOptions-AppStore.plist")
        with open(path, "rb") as fh:
            d = plistlib.load(fh)
        self.assertEqual(d["method"], "app-store-connect")
        self.assertEqual(d["signingStyle"], "manual")
        self.assertEqual(d["teamID"], "J5636UH8V8")
        self.assertEqual(d["provisioningProfiles"], {"app.dabbler.pro": "Dabbler App Store"})
        self.assertEqual(d["destination"], "export")  # export only: the workflow uploads explicitly


if __name__ == "__main__":
    unittest.main(verbosity=2)
