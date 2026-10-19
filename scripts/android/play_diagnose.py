#!/usr/bin/env python3
"""KAN-568 / KAN-572: read-mostly diagnosis of a Google Play API refusal.

Used when `edits.commit` answers 403 although the Play Console shows the package as registered. It records, without
printing any secret (only the service-account e-mail and project id, which are identifiers):

  1. who is calling (service-account e-mail, project id)
  2. what Play holds right now for the package: every committed bundle versionCode and every track's releases
     (so "is versionCode N already published on any track?" has an evidence-backed answer)
  3. the FULL error body, status and a whitelist of response headers (date, request-id style headers) of any refusal
  4. a harmless probe: create an edit with no change and try to commit it; if the commit is refused the edit is
     deleted, if it is accepted it changed nothing

It never uploads a bundle, never changes a track and never touches production.

    python3 scripts/android/play_diagnose.py --package P --credentials FILE [--version-code N]
"""
import argparse
import json
import sys

HEADER_WHITELIST = ("date", "server", "x-guploader-uploadid", "x-goog-request-params", "x-request-id",
                    "x-cloud-trace-context", "alt-svc", "content-type", "www-authenticate", "vary")
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def summarize_tracks(tracks):
    """{track: [{versionCodes, status, name}]} - only fields that identify releases."""
    out = {}
    for t in tracks or []:
        out[t.get("track")] = [
            {"versionCodes": [str(c) for c in (r.get("versionCodes") or [])], "status": r.get("status"),
             "name": r.get("name")} for r in (t.get("releases") or [])]
    return out


def where_is(version_code, bundle_codes, track_summary):
    code = str(version_code)
    in_bundles = code in {str(c) for c in bundle_codes}
    on = [(trk, rel["status"]) for trk, rels in track_summary.items() for rel in rels if code in rel["versionCodes"]]
    return {"versionCode": int(code), "inCommittedBundles": in_bundles, "onTracks": on}


def whitelist_headers(resp):
    try:
        items = dict(resp.items())
    except Exception:  # noqa: BLE001
        return {}
    return {k: v for k, v in items.items() if k.lower() in HEADER_WHITELIST}


def describe_http_error(err):
    body = None
    try:
        body = json.loads(err.content.decode("utf-8", "replace"))
    except Exception:  # noqa: BLE001
        body = {"raw": (err.content or b"")[:2000].decode("utf-8", "replace")}
    return {"status": getattr(err.resp, "status", None), "reason": getattr(err, "reason", None),
            "body": body, "headers": whitelist_headers(err.resp)}


def run(args):
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError

    with open(args.credentials, encoding="utf-8") as f:
        raw = json.load(f)
    report = {"caller": {"client_email": raw.get("client_email"), "project_id": raw.get("project_id"),
                         "type": raw.get("type")}, "package": args.package}
    creds = service_account.Credentials.from_service_account_file(args.credentials, scopes=[SCOPE])
    api = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    seen_headers = []

    def call(label, request):
        request.add_response_callback(lambda resp, *_: seen_headers.append((label, whitelist_headers(resp))))
        return request.execute()

    # 1 + 2: what Play holds now (read-only edit, deleted afterwards)
    edit = call("edits.insert", api.edits().insert(packageName=args.package, body={}))
    edit_id = edit["id"]
    try:
        bundles = call("bundles.list", api.edits().bundles().list(packageName=args.package, editId=edit_id))
        codes = [b["versionCode"] for b in bundles.get("bundles", [])]
        tracks = call("tracks.list", api.edits().tracks().list(packageName=args.package, editId=edit_id))
        summary = summarize_tracks(tracks.get("tracks", []))
        report["play_now"] = {"committedBundleVersionCodes": sorted(int(c) for c in codes), "tracks": summary}
        if args.version_code:
            report["version_code"] = where_is(args.version_code, codes, summary)
        try:
            details = call("details.get", api.edits().details().get(packageName=args.package, editId=edit_id))
            report["details_keys"] = sorted(details.keys())
        except HttpError as e:
            report["details_error"] = describe_http_error(e)
    finally:
        try:
            api.edits().delete(packageName=args.package, editId=edit_id).execute()
        except Exception:  # noqa: BLE001
            pass

    # 3 + 4: the empty-edit probe
    probe = {}
    edit2 = call("edits.insert(probe)", api.edits().insert(packageName=args.package, body={}))
    committed = False
    try:
        try:
            call("edits.commit(probe)", api.edits().commit(packageName=args.package, editId=edit2["id"]))
            committed = True
            probe["commit"] = "accepted (an empty edit; nothing changed)"
        except HttpError as e:
            probe["commit"] = "refused"
            probe["error"] = describe_http_error(e)
    finally:
        if not committed:
            try:
                api.edits().delete(packageName=args.package, editId=edit2["id"]).execute()
                probe["probe_edit"] = "deleted"
            except Exception:  # noqa: BLE001
                probe["probe_edit"] = "left to expire"
    report["empty_edit_probe"] = probe
    report["response_headers_seen"] = seen_headers[:12]
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True)
    ap.add_argument("--credentials", required=True)
    ap.add_argument("--version-code")
    args = ap.parse_args(argv)
    print(json.dumps(run(args), indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
