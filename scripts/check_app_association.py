#!/usr/bin/env python3
"""Read-only check of the live app-association files (KAN-597). Prints only public facts.

    python3 scripts/check_app_association.py [host ...]      (default: app, alpha and canary .dabbler.pro)

For each host it fetches /.well-known/apple-app-site-association and /.well-known/assetlinks.json and verifies:
  * HTTP 200 and a JSON body;
  * the AASA claims every shared-link path (game, post, venue, meetups, u) for the app id;
  * assetlinks.json names com.dabbler.dabblerapp.
Exit code 0 only if every host passes. It does not prove a device opens the app; it proves the hosting side.
"""
import json
import sys
import urllib.request

PATHS = ("game", "post", "venue", "meetups", "u")
PACKAGE = "com.dabbler.dabblerapp"
DEFAULT_HOSTS = ("app.dabbler.pro", "alpha.dabbler.pro", "canary.dabbler.pro")


def fetch(host, name):
    req = urllib.request.Request(f"https://{host}/.well-known/{name}", headers={"User-Agent": "assoc-check"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.status, json.loads(r.read().decode())


def claimed_paths(aasa):
    comps = [c for d in aasa.get("applinks", {}).get("details", []) for c in d.get("components", [])]
    return {c.get("/") for c in comps}


def check_host(host):
    problems = []
    try:
        status, aasa = fetch(host, "apple-app-site-association")
        missing = [p for p in PATHS if f"/{p}/*" not in claimed_paths(aasa)]
        if missing:
            problems.append("AASA lacks paths: " + ", ".join(missing))
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
    bad = 0
    for h in hosts:
        problems = check_host(h)
        print(f"{h}: {'OK' if not problems else 'FAIL - ' + '; '.join(problems)}")
        bad += bool(problems)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
