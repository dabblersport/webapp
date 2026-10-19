#!/usr/bin/env python3
"""App Store Connect / TestFlight tooling for the iOS release workflow (KAN-568).

Uses the App Store Connect API with a team API key. Credentials arrive as FILES and values the
workflow supplies: --key-file (the AuthKey .p8), --key-id, --issuer-id. Nothing secret is ever
printed. Every command prints one JSON object.

Commands
  check   --bundle-id B --build-number N
      Refuse a duplicate or older build number: N must be higher than every build number
      already uploaded for this app (App Store Connect rejects a duplicate for the same
      version anyway; requiring a strictly higher number also keeps the sequence monotonic).
  next    --bundle-id B
      Print the next unused build number (highest uploaded + 1). Read-only.
  wait    --bundle-id B --version-name V --build-number N [--timeout-minutes 45]
      Poll until Apple finished processing the build (VALID) or it failed (FAILED/INVALID).
  status  --bundle-id B [--version-name V] [--build-number N]
      Read-only. Reports the distinct stages below.
  submit  --bundle-id B --version-name V --build-number N [--confirm]
      Attach the build to the App Store version and submit it for App Review. WITHOUT
      --confirm it is a dry run that only reports what it would do. Public release is the
      CEO's explicit, immutable-ref decision: the workflow never passes --confirm unless the
      production approval string matched.

Stages, kept distinct on purpose:
  uploaded    the build exists in App Store Connect
  processing  Apple's processing state: PROCESSING | VALID | FAILED | INVALID
  testflight  the internal TestFlight state: READY_FOR_BETA_TESTING | IN_BETA_TESTING | ...
              (MISSING_EXPORT_COMPLIANCE and PROCESSING_EXCEPTION are blockers, reported as such)
  submission  the App Store version / review submission state for the versionName
  review      WAITING_FOR_REVIEW | IN_REVIEW | REJECTED (UNRESOLVED_ISSUES) | approved states
  available   "confirmed" only on an independent signal: the App Store version is
              READY_FOR_SALE AND the public iTunes lookup shows that versionName.
              Otherwise "unconfirmed". Never announce "ready to update" on "unconfirmed".
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"
TOKEN_SECONDS = 600
TERMINAL_BAD = ("FAILED", "INVALID")
BLOCKING_TESTFLIGHT = ("MISSING_EXPORT_COMPLIANCE", "PROCESSING_EXCEPTION", "IN_EXPORT_COMPLIANCE_REVIEW")
REJECTED_STATES = ("REJECTED", "UNRESOLVED_ISSUES", "METADATA_REJECTED", "INVALID_BINARY", "DEVELOPER_REJECTED")
APPROVED_STATES = ("PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE",
                   "PROCESSING_FOR_DISTRIBUTION", "READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "ACCEPTED")
REVIEW_STATES = ("WAITING_FOR_REVIEW", "IN_REVIEW", "READY_FOR_REVIEW", "COMPLETING")


# ---- pure logic (unit-tested offline) --------------------------------------------------

def build_number_value(raw):
    """Build numbers must be plain integers here; anything else is refused loudly."""
    s = str(raw).strip()
    if not s.isdigit() or int(s) < 1:
        raise ValueError("build number must be a positive integer, got %r" % (raw,))
    return int(s)


def check_build_number(new_number, uploaded_numbers):
    """Return (ok, reason). Strictly higher than every build already in App Store Connect."""
    nums = sorted({int(n) for n in uploaded_numbers if str(n).strip().isdigit()})
    if new_number in nums:
        return False, "build number %d is already uploaded" % new_number
    if nums and new_number < nums[-1]:
        return False, "build number %d is lower than the highest uploaded (%d)" % (new_number, nums[-1])
    return True, "build number %d is new (highest uploaded: %s)" % (new_number, nums[-1] if nums else "none")


def next_build_number(uploaded_numbers):
    nums = [int(n) for n in uploaded_numbers if str(n).strip().isdigit()]
    return (max(nums) if nums else 0) + 1


def parse_builds(payload):
    """Flatten a /v1/builds response (with included preReleaseVersions) into plain dicts."""
    versions = {}
    for inc in payload.get("included", []) or []:
        if inc.get("type") == "preReleaseVersions":
            versions[inc["id"]] = (inc.get("attributes") or {}).get("version")
    out = []
    for b in payload.get("data", []) or []:
        a = b.get("attributes") or {}
        rel = ((b.get("relationships") or {}).get("preReleaseVersion") or {}).get("data") or {}
        out.append({
            "id": b["id"],
            "buildNumber": str(a.get("version", "")),
            "versionName": versions.get(rel.get("id")),
            "processingState": a.get("processingState"),
            "expired": bool(a.get("expired")),
            "uploadedDate": a.get("uploadedDate"),
            "usesNonExemptEncryption": a.get("usesNonExemptEncryption"),
        })
    return out


def find_build(builds, build_number, version_name=None):
    for b in builds:
        if b["buildNumber"] == str(build_number) and (not version_name or b["versionName"] in (None, version_name)):
            return b
    return None


def version_state(v):
    a = v.get("attributes") or {}
    return a.get("appVersionState") or a.get("appStoreState")


def classify_review(state):
    """Map an App Store version / review-submission state to a distinct review stage."""
    if state is None:
        return "none"
    if state in REJECTED_STATES:
        return "rejected"
    if state in REVIEW_STATES:
        return "in-review" if state == "IN_REVIEW" else "waiting-for-review"
    if state in APPROVED_STATES:
        return "approved"
    return "not-submitted"


def stage_report(build, beta, versions, public_version):
    """Build the distinct-stage report. `build` None means not uploaded (yet)."""
    rep = {
        "uploaded": build is not None,
        "processing": build["processingState"] if build else None,
        "testflight": None,
        "testflightBlocker": None,
        "submission": None,
        "review": "none",
        "available": "unconfirmed",
        "availableReason": "no independent availability signal yet",
    }
    if build:
        rep["buildExpired"] = build["expired"]
    if beta:
        ib = beta.get("internalBuildState")
        rep["testflight"] = ib
        if ib in BLOCKING_TESTFLIGHT:
            rep["testflightBlocker"] = ib
    vname = build["versionName"] if build else None
    match = [v for v in versions if (v.get("attributes") or {}).get("versionString") == vname] if vname else []
    if match:
        st = version_state(match[0])
        rep["submission"] = st
        rep["review"] = classify_review(st)
        if st == "READY_FOR_SALE" and public_version == vname:
            rep["available"] = "confirmed"
            rep["availableReason"] = "App Store version is READY_FOR_SALE and the public lookup shows %s" % vname
        elif st == "READY_FOR_SALE":
            rep["availableReason"] = "READY_FOR_SALE but the public lookup does not show the version yet"
    return rep


def jwt_claims(issuer_id, now):
    return {"iss": issuer_id, "iat": int(now), "exp": int(now) + TOKEN_SECONDS, "aud": "appstoreconnect-v1"}


# ---- API plumbing -----------------------------------------------------------------------

def make_token(key_file, key_id, issuer_id, now=None):
    import jwt  # PyJWT, installed from requirements.txt by the workflow
    with open(key_file, "r", encoding="utf-8") as fh:
        key = fh.read()
    return jwt.encode(jwt_claims(issuer_id, now or time.time()), key, algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})


class Client:
    def __init__(self, key_file, key_id, issuer_id, opener=None):
        self.key_file, self.key_id, self.issuer_id = key_file, key_id, issuer_id
        self._opener = opener or urllib.request.urlopen

    def request(self, method, path, params=None, body=None):
        url = API + path + ("?" + urllib.parse.urlencode(params, safe="[],") if params else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": "Bearer " + make_token(self.key_file, self.key_id, self.issuer_id),
            "Content-Type": "application/json"})
        try:
            with self._opener(req, timeout=60) as resp:
                raw = resp.read().decode()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as err:
            detail = ""
            try:
                detail = ",".join(e.get("code", "?") for e in json.loads(err.read().decode()).get("errors", []))
            except Exception:  # noqa: BLE001
                pass
            raise SystemExit(json.dumps({"ok": False, "reason": "App Store Connect API HTTP %d %s" % (err.code, detail)}))

    def get(self, path, params=None):
        return self.request("GET", path, params)


def find_app(client, bundle_id):
    res = client.get("/v1/apps", {"filter[bundleId]": bundle_id, "limit": "2"})
    data = res.get("data", [])
    if len(data) != 1:
        raise SystemExit(json.dumps({"ok": False, "reason": "expected exactly one app for bundle id %s, found %d" % (bundle_id, len(data))}))
    return data[0]["id"]


def list_builds(client, app_id):
    builds, params = [], {
        "filter[app]": app_id, "limit": "200", "sort": "-uploadedDate", "include": "preReleaseVersion",
        "fields[builds]": "version,uploadedDate,processingState,expired,usesNonExemptEncryption,preReleaseVersion",
        "fields[preReleaseVersions]": "version"}
    res = client.get("/v1/builds", params)
    builds += parse_builds(res)
    return builds


def beta_detail(client, build_id):
    try:
        res = client.get("/v1/builds/%s/buildBetaDetail" % build_id)
    except SystemExit:
        return None
    return (res.get("data") or {}).get("attributes")


def app_store_versions(client, app_id):
    res = client.get("/v1/apps/%s/appStoreVersions" % app_id, {"filter[platform]": "IOS", "limit": "20"})
    return res.get("data", [])


def public_lookup_version(bundle_id):
    """Best effort: the version the public App Store lists. None if unreachable."""
    url = "https://itunes.apple.com/lookup?bundleId=" + urllib.parse.quote(bundle_id)
    try:
        with urllib.request.urlopen(url, timeout=20) as resp:
            res = json.loads(resp.read().decode())
        return (res.get("results") or [{}])[0].get("version")
    except Exception:  # noqa: BLE001 - any failure means "no signal"
        return None


# ---- commands ---------------------------------------------------------------------------

def cmd_check(args, client):
    n = build_number_value(args.build_number)
    app_id = find_app(client, args.bundle_id)
    ok, reason = check_build_number(n, [b["buildNumber"] for b in list_builds(client, app_id)])
    print(json.dumps({"command": "check", "ok": ok, "reason": reason}))
    return 0 if ok else 1


def cmd_next(args, client):
    app_id = find_app(client, args.bundle_id)
    nxt = next_build_number([b["buildNumber"] for b in list_builds(client, app_id)])
    print(json.dumps({"command": "next", "ok": True, "nextBuildNumber": nxt}))
    return 0


def read_report(client, args):
    app_id = find_app(client, args.bundle_id)
    builds = list_builds(client, app_id)
    build = find_build(builds, args.build_number, args.version_name) if args.build_number else None
    beta = beta_detail(client, build["id"]) if build else None
    versions = app_store_versions(client, app_id)
    public = public_lookup_version(args.bundle_id) if args.version_name else None
    rep = stage_report(build, beta, versions, public)
    rep.update({"bundleId": args.bundle_id, "versionName": args.version_name, "buildNumber": args.build_number})
    return rep


def cmd_status(args, client):
    rep = read_report(client, args)
    rep.update({"command": "status", "ok": bool(rep["uploaded"])})
    print(json.dumps(rep, indent=2))
    return 0 if rep["uploaded"] else 1


def cmd_wait(args, client):
    deadline = time.time() + float(args.timeout_minutes) * 60
    rep = None
    while True:
        rep = read_report(client, args)
        if rep["processing"] == "VALID":
            rep.update({"command": "wait", "ok": rep["testflightBlocker"] is None})
            break
        if rep["processing"] in TERMINAL_BAD:
            rep.update({"command": "wait", "ok": False})
            break
        if time.time() > deadline:
            rep.update({"command": "wait", "ok": False, "reason": "timed out waiting for processing"})
            break
        time.sleep(30)
    print(json.dumps(rep, indent=2))
    return 0 if rep["ok"] else 1


def cmd_submit(args, client):
    rep = read_report(client, args)
    plan = {"command": "submit", "dryRun": not args.confirm, "ok": False}
    if not rep["uploaded"] or rep["processing"] != "VALID":
        plan["reason"] = "build %s is not uploaded and VALID (processing: %s)" % (args.build_number, rep["processing"])
        print(json.dumps(plan))
        return 1
    app_id = find_app(client, args.bundle_id)
    versions = [v for v in app_store_versions(client, app_id) if (v.get("attributes") or {}).get("versionString") == args.version_name]
    if len(versions) != 1:
        plan["reason"] = "expected exactly one App Store version %s in App Store Connect (create it, with honest release notes and metadata, first); found %d" % (args.version_name, len(versions))
        print(json.dumps(plan))
        return 1
    if version_state(versions[0]) != "PREPARE_FOR_SUBMISSION":
        plan["reason"] = "App Store version %s is in state %s, not PREPARE_FOR_SUBMISSION" % (args.version_name, version_state(versions[0]))
        print(json.dumps(plan))
        return 1
    plan.update({"ok": True, "wouldAttachBuild": args.build_number, "wouldSubmitVersion": args.version_name})
    if not args.confirm:
        plan["note"] = "dry run: nothing was changed"
        print(json.dumps(plan))
        return 0
    builds = list_builds(client, app_id)
    build = find_build(builds, args.build_number, args.version_name)
    client.request("PATCH", "/v1/appStoreVersions/%s/relationships/build" % versions[0]["id"],
                   body={"data": {"type": "builds", "id": build["id"]}})
    sub = client.request("POST", "/v1/reviewSubmissions", body={"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    sub_id = sub["data"]["id"]
    client.request("POST", "/v1/reviewSubmissionItems", body={"data": {
        "type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": versions[0]["id"]}}}}})
    client.request("PATCH", "/v1/reviewSubmissions/%s" % sub_id, body={"data": {
        "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    plan["note"] = "submitted for App Review; follow it with the status command (review is asynchronous, no duration is promised)"
    print(json.dumps(plan))
    return 0


def main(argv=None, client=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    for name in ("check", "next", "wait", "status", "submit"):
        p = sub.add_parser(name)
        p.add_argument("--bundle-id", required=True)
        p.add_argument("--key-file", required=True, help="path to the AuthKey .p8 file")
        p.add_argument("--key-id", required=True)
        p.add_argument("--issuer-id", required=True)
        if name in ("check", "wait", "status", "submit"):
            p.add_argument("--build-number", required=(name != "status"))
        if name in ("wait", "status", "submit"):
            p.add_argument("--version-name", required=(name != "status"))
        if name == "wait":
            p.add_argument("--timeout-minutes", default="45")
        if name == "submit":
            p.add_argument("--confirm", action="store_true")
    args = ap.parse_args(argv)
    client = client or Client(args.key_file, args.key_id, args.issuer_id)
    return {"check": cmd_check, "next": cmd_next, "wait": cmd_wait, "status": cmd_status,
            "submit": cmd_submit}[args.command](args, client)


if __name__ == "__main__":
    sys.exit(main())
