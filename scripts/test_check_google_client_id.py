import unittest

import check_google_client_id as c

DOC = {"client": [{"oauth_client": [
    {"client_id": "android-id.apps.example", "client_type": 1},
    {"client_id": "web-id.apps.example", "client_type": 3},
]}]}


class CheckGoogleClientId(unittest.TestCase):
    def test_web_id_is_accepted(self):
        self.assertIsNone(c.check("web-id.apps.example", DOC))

    def test_empty_and_blank_are_refused(self):
        self.assertIn("empty", c.check("", DOC))
        self.assertIn("empty", c.check("   ", DOC))
        self.assertIn("empty", c.check(None, DOC))

    def test_android_id_is_refused_without_echoing_it(self):
        msg = c.check("android-id.apps.example", DOC)
        self.assertIn("ANDROID", msg)
        self.assertNotIn("android-id", msg)

    def test_doc_without_clients_accepts_any_non_empty_value(self):
        self.assertIsNone(c.check("anything.apps.example", {}))

    def test_android_client_ids_only_type_one(self):
        self.assertEqual(c.android_client_ids(DOC), {"android-id.apps.example"})


if __name__ == "__main__":
    unittest.main()
