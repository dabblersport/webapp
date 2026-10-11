#!/usr/bin/env python3
"""Google Play publishing for the Android release workflow (KAN-493).

Uses the Google Play Android Developer API with the app-scoped service account.
Credentials: the service-account JSON FILE named by --credentials (the workflow writes the
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON secret to a temp file). Nothing secret is ever printed.

Commands (each prints one JSON object; exit code 0 = the stated condition holds):

  check   --package P --version-code N
      Refuse a duplicate or older versionCode: N must be higher than every versionCode
      already uploaded to Play for this app.
  upload  --package P --aab FILE --track internal|production --version-code N
          [--status completed|draft] [--user-fraction 0.1]
      Upload the bundle, put it on the track, commit the edit, then READ BACK to verify.
  status  --package P --version-code N [--version-name V] [--track T]
      Read-only. Reports the distinct stages below; never writes.

Release stages, kept distinct on purpose (Play does NOT expose "in review" through the API):
  uploaded     the bundle is in Play's bundle list (Play accepted it; processing is done
               once it is listed)
  processed    same as uploaded for this API: a bundle is only listed after processing
  on_track     a release containing the versionCode exists on the track, with its status
               (draft | inProgress | completed | halted)
  review       NOT OBSERVABLE through the API: always reported as "not-exposed-by-api"
  available    "confirmed" only when an independent signal says so:
                 internal track: the release is `completed` (internal testing has no review;
                                 testers still need to be on the tester list/opt in)
                 production:     the public store page shows the versionName (best effort)
               otherwise "unconfirmed". Never announce "ready to update" on "unconfirmed".
"""
import argparse
import json
import re
import sys
import urllib.request

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TRACKS = ("internal", "production")
RELEASE_STATUSES = ("completed", "draft", "inProgress", "halted")


# ---- pure logic (unit-tested offline) --------------------------------------------------

def check_version_code(new_code, uploaded_codes):
    """Return (ok, reason). New code must be strictly higher than any code already in Play."""
    codes = sorted({int(c) for c in uploaded_codes})
    if new_code in codes:
        return False, "versionCode %d is already uploaded to Play" % new_code
    if codes and new_code < codes[-1]:
        return False, "versionCode %d is lower than the highest uploaded (%d)" % (
            new_code, codes[-1])
    return True, "versionCode %d is new (highest uploaded: %s)" % (
        new_code, codes[-1] if codes else "none")


def releases_for(tracks, version_code):
    """[(track, release_dict)] for every track release that contains `version_code`."""
    found = []
    for t in tracks:
        for r in t.get("releases", []) or []:
            if str(version_code) in [str(c) for c in (r.get("versionCodes") or [])]:
                found.append((t.get("track"), r))
    return found


def stage_report(version_code, bundle_codes, tracks, store_page_has_version=None):
    """The distinct stages for one versionCode. `store_page_has_version` is the best-effort
    public-listing signal (True/False/None)."""
    uploaded = int(version_code) in {int(c) for c in bundle_codes}
    on = releases_for(tracks, version_code)
    on_track = [{"track": t, "status": r.get("status"), "userFraction": r.get("userFraction"),
                 "name": r.get("name")} for t, r in on]
    available, why = "unconfirmed", "no independent availability signal yet"
    for t, r in on:
        if t == "internal" and r.get("status") == "completed":
            available, why = "confirmed", "internal testing release is completed (no review step)"
        if t == "production" and r.get("status") == "completed" and store_page_has_version:
            available, why = "confirmed", "public store page shows the version"
    if not uploaded:
        state = "not-uploaded"
    elif not on_track:
        state = "uploaded-not-released"
    elif any(x["status"] == "halted" for x in on_track):
        state = "halted"
    elif available == "confirmed":
        state = "available"
    elif any(x["status"] == "draft" for x in on_track):
        state = "draft-on-track"
    else:
        state = "submitted-awaiting-availability"
    return {
        "versionCode": int(version_code),
        "state": state,
        "uploaded": uploaded,
        "processed": uploaded,
        "onTrack": on_track,
        "review": "not-exposed-by-api",
        "available": available,
        "availableReason": why,
    }


# ---- API access -------------------------------------------------------------------------

def service(credentials_path):
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    creds = service_account.Credentials.from_service_account_file(credentials_path, scopes=[SCOPE])
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def list_bundle_codes(api, package, edit_id):
    res = api.edits().bundles().list(packageName=package, editId=edit_id).execute()
    return [b["versionCode"] for b in res.get("bundles", [])]


def list_tracks(api, package, edit_id):
    res = api.edits().tracks().list(packageName=package, editId=edit_id).execute()
    return res.get("tracks", [])


def store_page_has_version(package, version_name):
    """Best effort: does the public Play page mention this versionName? None if unreachable."""
    if not version_name:
        return None
    url = "https://play.google.com/store/apps/details?id=%s&hl=en&gl=US" % package
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            html = resp.read().decode("utf-8", "replace")
    except Exception:  # noqa: BLE001 - any failure means "no signal"
        return None
    return bool(re.search(r'"%s"' % re.escape(version_name), html))


def read_only_edit(api, package):
    edit = api.edits().insert(packageName=package, body={}).execute()
    return edit["id"]


def discard_edit(api, package, edit_id):
    try:
        api.edits().delete(packageName=package, editId=edit_id).execute()
    except Exception:  # noqa: BLE001 - an abandoned read-only edit expires by itself
        pass


# ---- commands ---------------------------------------------------------------------------

def cmd_check(args):
    api = service(args.credentials)
    edit_id = read_only_edit(api, args.package)
    try:
        codes = list_bundle_codes(api, args.package, edit_id)
        track_codes = [c for t in list_tracks(api, args.package, edit_id)
                       for r in t.get("releases", []) or [] for c in r.get("versionCodes", []) or []]
    finally:
        discard_edit(api, args.package, edit_id)
    ok, reason = check_version_code(int(args.version_code), list(codes) + list(track_codes))
    print(json.dumps({"command": "check", "ok": ok, "reason": reason,
                      "highestUploaded": max([int(c) for c in list(codes) + list(track_codes)] or [0])}))
    return 0 if ok else 1


def cmd_upload(args):
    from googleapiclient.http import MediaFileUpload
    code = int(args.version_code)
    api = service(args.credentials)
    edit = api.edits().insert(packageName=args.package, body={}).execute()
    edit_id = edit["id"]
    committed = False
    try:
        codes = list_bundle_codes(api, args.package, edit_id)
        ok, reason = check_version_code(code, codes)
        if not ok:
            print(json.dumps({"command": "upload", "ok": False, "reason": reason}))
            return 1
        media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
        up = api.edits().bundles().upload(packageName=args.package, editId=edit_id,
                                          media_body=media).execute()
        if int(up["versionCode"]) != code:
            print(json.dumps({"command": "upload", "ok": False,
                              "reason": "uploaded bundle has versionCode %s, expected %d"
                                        % (up["versionCode"], code)}))
            return 1
        release = {"versionCodes": [str(code)], "status": args.status}
        if args.release_name:
            release["name"] = args.release_name
        if args.user_fraction:
            release["status"] = "inProgress"
            release["userFraction"] = float(args.user_fraction)
        api.edits().tracks().update(packageName=args.package, editId=edit_id, track=args.track,
                                    body={"track": args.track, "releases": [release]}).execute()
        api.edits().commit(packageName=args.package, editId=edit_id).execute()
        committed = True
    finally:
        if not committed:
            discard_edit(api, args.package, edit_id)
    # Read back with a fresh edit: the committed state, not what we sent.
    return read_back(api, args, expect_track=args.track)


def read_back(api, args, expect_track=None):
    edit_id = read_only_edit(api, args.package)
    try:
        codes = list_bundle_codes(api, args.package, edit_id)
        tracks = list_tracks(api, args.package, edit_id)
    finally:
        discard_edit(api, args.package, edit_id)
    page = None
    if expect_track in (None, "production") and getattr(args, "version_name", None):
        page = store_page_has_version(args.package, args.version_name)
    report = stage_report(args.version_code, codes, tracks, page)
    verified = report["uploaded"] and (
        expect_track is None or any(x["track"] == expect_track for x in report["onTrack"]))
    report.update({"command": args.command, "ok": bool(verified), "package": args.package})
    print(json.dumps(report, indent=2))
    return 0 if verified else 1


def cmd_status(args):
    api = service(args.credentials)
    return read_back(api, args, expect_track=args.track)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    for name in ("check", "upload", "status"):
        p = sub.add_parser(name)
        p.add_argument("--package", required=True)
        p.add_argument("--version-code", required=True)
        p.add_argument("--credentials", required=True, help="path to the service-account JSON file")
        if name in ("upload", "status"):
            p.add_argument("--version-name")
        if name == "upload":
            p.add_argument("--aab", required=True)
            p.add_argument("--track", required=True, choices=TRACKS)
            p.add_argument("--status", default="completed", choices=("completed", "draft"))
            p.add_argument("--user-fraction", default="")
            p.add_argument("--release-name", default="")
        if name == "status":
            p.add_argument("--track", choices=TRACKS)
    args = ap.parse_args(argv)
    return {"check": cmd_check, "upload": cmd_upload, "status": cmd_status}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
