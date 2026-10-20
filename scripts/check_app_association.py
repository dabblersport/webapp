#!/usr/bin/env python3
"""Read-only check of the live app-association files (KAN-597). Prints only public facts.

    python3 scripts/check_app_association.py [host ...]      (default: app, alpha and canary .dabbler.pro)

For each host it fetches /.well-known/apple-app-site-association and /.well-known/assetlinks.json and verifies:
  * HTTP 200 and a JSON body;
  * the AASA assigns every shared-link path (game, post, venue, meetups, u) to THIS app: the Dabbler iOS app id
    (Team ID + bundle id, read from ios/Runner.xcodeproj, never hard-coded) must be in the appIDs/appID of the SAME
    details entry whose components/paths cover that path, so a host that gives the paths to another app fails;
  * assetlinks.json names com.dabbler.dabblerapp.
Exit code 0 only if every host passes. It does not prove a device opens the app; it proves the hosting side.
"""
import json
import os
import re
import sys
import urllib.request

PATHS = ("game", "post", "venue", "meetups", "u")
PACKAGE = "com.dabbler.dabblerapp"
DEFAULT_HOSTS = ("app.dabbler.pro", "alpha.dabbler.pro", "canary.dabbler.pro")


def fetch(host, name):
    req = urllib.request.Request(f"https://{host}/.well-known/{name}", headers={"User-Agent": "assoc-check"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.status, json.loads(r.read().decode())


PROJECT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ios", "Runner.xcodeproj", "project.pbxproj")


def app_id_from_project(pbxproj_text):
    """'TEAMID.bundle.id' of the Runner app target, read from the Xcode project: the build configurations that set
    CODE_SIGN_ENTITLEMENTS (the app target, not RunnerTests). Raises ValueError unless exactly one such app id exists."""
    ids = set()
    for block in re.findall(r"buildSettings = \{(.*?)\n\t\t\t\};", pbxproj_text, re.S):
        if "CODE_SIGN_ENTITLEMENTS" not in block:
            continue
        team = re.search(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", block)
        bundle = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.\-]+);", block)
        if team and bundle:
            ids.add(f"{team.group(1)}.{bundle.group(1)}")
    if len(ids) != 1:
        raise ValueError(f"expected exactly one app id in the Xcode project, found {sorted(ids)}")
    return ids.pop()


def entry_app_ids(detail):
    """The app ids one `details` entry applies to (new `appIDs` list or the older single `appID`)."""
    ids = list(detail.get("appIDs") or [])
    if detail.get("appID"):
        ids.append(detail["appID"])
    return ids


def entry_paths(detail):
    """The path patterns one `details` entry claims: `components` ('/' key) and the older `paths` list."""
    out = {c.get("/") for c in detail.get("components", []) if isinstance(c, dict)}
    out.update(p for p in detail.get("paths", []) if isinstance(p, str))
    return out


def missing_paths(aasa, app_id):
    """Shared-link paths NOT assigned to [app_id]: a path counts only if the same details entry names that app id."""
    details = aasa.get("applinks", {}).get("details", [])
    covered = set()
    for d in details:
        if app_id in entry_app_ids(d):
            covered |= entry_paths(d)
    return [p for p in PATHS if f"/{p}/*" not in covered]


def check_host(host, app_id):
    problems = []
    try:
        status, aasa = fetch(host, "apple-app-site-association")
        missing = missing_paths(aasa, app_id)
        if missing:
            problems.append(f"AASA does not assign {app_id} the paths: " + ", ".join(missing))
    except Exception as e:  # noqa: BLE001
        problems.append("AASA unreadable: " + type(e).__name__)
    try:
        status, links = fetch(host, "assetlinks.json")
        packages = [e.get("target", {}).get("package_name") for e in links]
        if PACKAGE not in packages:
            problems.append("assetlinks lacks " + PACKAGE)
    except Exception as e:  # noqa: BLE001
        problems.append("assetlinks unreadable: " + type(e).__name__)
    return problems


def main(argv):
    hosts = argv or list(DEFAULT_HOSTS)
    with open(PROJECT, encoding="utf-8") as fh:
        app_id = app_id_from_project(fh.read())
    print(f"expecting iOS app id {app_id} (from ios/Runner.xcodeproj)")
    bad = 0
    for h in hosts:
        problems = check_host(h, app_id)
        print(f"{h}: {'OK' if not problems else 'FAIL - ' + '; '.join(problems)}")
        bad += bool(problems)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
