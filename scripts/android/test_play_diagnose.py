import unittest

import play_diagnose as d

TRACKS = [
    {"track": "internal", "releases": [{"versionCodes": ["176"], "status": "completed", "name": "1.7.9 (176)"}]},
    {"track": "production", "releases": [{"versionCodes": ["174"], "status": "completed"}]},
    {"track": "beta"},
]


class PlayDiagnose(unittest.TestCase):
    def test_summarize_tracks_keeps_only_identifying_fields(self):
        s = d.summarize_tracks(TRACKS)
        self.assertEqual(s["internal"], [{"versionCodes": ["176"], "status": "completed", "name": "1.7.9 (176)"}])
        self.assertEqual(s["beta"], [])

    def test_where_is_absent_code(self):
        s = d.summarize_tracks(TRACKS)
        w = d.where_is(177, ["174", "175", "176"], s)
        self.assertEqual(w, {"versionCode": 177, "inCommittedBundles": False, "onTracks": []})

    def test_where_is_present_code(self):
        s = d.summarize_tracks(TRACKS)
        w = d.where_is(176, [176], s)
        self.assertTrue(w["inCommittedBundles"])
        self.assertEqual(w["onTracks"], [("internal", "completed")])

    def test_header_whitelist_drops_everything_else(self):
        class R:
            def items(self):
                return [("Date", "x"), ("Authorization", "secret"), ("X-Request-Id", "id")]

        self.assertEqual(d.whitelist_headers(R()), {"Date": "x", "X-Request-Id": "id"})


if __name__ == "__main__":
    unittest.main()
