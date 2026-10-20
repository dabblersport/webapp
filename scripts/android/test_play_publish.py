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


class SigningFingerprints(unittest.TestCase):
    """KAN-571: public certificate fingerprints only."""

    def test_colon_fingerprint_formats_hex(self):
        self.assertEqual(pp.colon_fingerprint("0ee1b2e9"), "0E:E1:B2:E9")
        self.assertEqual(pp.colon_fingerprint("0E:E1:b2:e9"), "0E:E1:B2:E9")
        self.assertIsNone(pp.colon_fingerprint(""))
        self.assertIsNone(pp.colon_fingerprint(None))
        self.assertIsNone(pp.colon_fingerprint("abc"))  # odd length is not a fingerprint

    def test_keytool_output_is_parsed(self):
        text = "Signer #1:\n\nCertificate:\nOwner: CN=x\nCertificate fingerprints:\n\t SHA1: 0E:E1:B2:E9\n\t SHA256: AA:BB:CC:DD\n"
        self.assertEqual(pp.parse_keytool_fingerprints(text), {"sha1": "0E:E1:B2:E9", "sha256": "AA:BB:CC:DD"})
        self.assertEqual(pp.parse_keytool_fingerprints("no certificate"), {})

    def test_a_failing_api_is_reported_not_raised(self):
        class Boom:
            def generatedapks(self):
                raise RuntimeError("secret detail must not appear")
        r = pp.signing_report(Boom(), "com.example", "1")
        self.assertFalse(r["checked"])
        self.assertEqual(r["reason"], "list-failed:RuntimeError")
        self.assertNotIn("secret", str(r))



    def test_apk_signing_block_cert_hashes(self):
        import hashlib, struct, tempfile
        der = b"FAKE-CERT-DER-BYTES"
        def item(b):
            return struct.pack("<I", len(b)) + b
        signed_data = item(item(b"digest")) + item(item(der)) + item(b"")
        signer = item(signed_data) + item(b"sigs") + item(b"pubkey")
        v2 = item(item(signer))
        pair = struct.pack("<I", pp._V2_ID) + v2
        pairs = struct.pack("<Q", len(pair)) + pair
        size = len(pairs) + 24
        block = struct.pack("<Q", size) + pairs + struct.pack("<Q", size) + pp._SIG_BLOCK_MAGIC
        local = b"PK\x03\x04" + b"x" * 20
        cd = b"PK\x01\x02" + b"y" * 42
        eocd = b"PK\x05\x06" + b"\0" * 8 + struct.pack("<II", len(cd), len(local) + len(block)) + b"\0\0"
        with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as fh:
            fh.write(local + block + cd + eocd)
        got = pp.apk_signing_cert_hashes(fh.name)
        os.unlink(fh.name)
        self.assertEqual(got["sha1"], pp.colon_fingerprint(hashlib.sha1(der).hexdigest()))
        self.assertEqual(got["sha256"], pp.colon_fingerprint(hashlib.sha256(der).hexdigest()))

    def test_an_apk_without_a_signing_block_raises(self):
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as fh:
            fh.write(b"PK\x05\x06" + b"\0" * 18)
        with self.assertRaises(ValueError):
            pp.apk_signing_cert_hashes(fh.name)
        os.unlink(fh.name)

if __name__ == "__main__":
    unittest.main()
