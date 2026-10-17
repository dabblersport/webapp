#!/usr/bin/env python3
"""Tracked mobile releases (KAN-568): parse and judge the list the status watcher reads.

The list lives in the repository variable MOBILE_RELEASE_TRACKING (JSON), so that starting or
ending the observation of a release needs no commit:

  [{"platform": "ios",     "versionName": "1.7.9", "buildNumber": "176"},
   {"platform": "android", "versionName": "1.7.9", "versionCode": "175", "track": "internal"}]

`judge` turns one status report (the JSON printed by asc_release.py status or
play_publish.py status) into a verdict the watcher shows and, for terminal states, fails on:

  available   confirmed on an independent signal  -> done, stop watching
  rejected    App Review rejection / halted release -> terminal, needs a person
  blocked     a blocker such as MISSING_EXPORT_COMPLIANCE or FAILED processing -> needs a person
  waiting     anything else (uploaded, processing, in review, unconfirmed) -> keep watching
"""
import json
import sys

PLATFORMS = ("ios", "android")


def parse(raw):
    """Return the validated list of tracked releases ([] when unset)."""
    if not raw or not raw.strip():
        return []
    items = json.loads(raw)
    if not isinstance(items, list):
        raise ValueError("MOBILE_RELEASE_TRACKING must be a JSON list")
    out = []
    for it in items:
        if it.get("platform") not in PLATFORMS:
            raise ValueError("platform must be ios or android: %r" % (it,))
        if not str(it.get("versionName", "")).strip():
            raise ValueError("versionName is required: %r" % (it,))
        key = "buildNumber" if it["platform"] == "ios" else "versionCode"
        if not str(it.get(key, "")).isdigit():
            raise ValueError("%s must be an integer: %r" % (key, it))
        out.append(it)
    return out


def judge(platform, report):
    """(verdict, why) for one status report."""
    if report.get("available") == "confirmed":
        return "available", "confirmed on an independent signal"
    if platform == "ios":
        if report.get("review") == "rejected":
            return "rejected", "App Review: %s" % report.get("submission")
        if report.get("testflightBlocker"):
            return "blocked", report["testflightBlocker"]
        if report.get("processing") in ("FAILED", "INVALID"):
            return "blocked", "processing %s" % report["processing"]
    else:
        for r in report.get("onTrack", []) or []:
            if r.get("status") == "halted":
                return "rejected", "release halted on %s" % r.get("track")
    if not report.get("uploaded"):
        return "waiting", "not uploaded yet"
    return "waiting", "uploaded; availability unconfirmed (no review duration is promised)"


def main(argv):
    if len(argv) == 2 and argv[1] == "parse":
        print(json.dumps(parse(sys.stdin.read())))
        return 0
    if len(argv) == 3 and argv[1] == "judge":
        v, why = judge(argv[2], json.load(sys.stdin))
        print(json.dumps({"verdict": v, "why": why}))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
