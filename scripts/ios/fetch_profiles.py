#!/usr/bin/env python3
"""Fetch the ACTIVE App Store provisioning profiles at build time (KAN-1047).

A stale IOS_PROVISIONING_PROFILE_BASE64 secret broke run 45759510399: the profile it held had
gone INVALID and had no time-sensitive entitlement, and the DabblerLiveActivity extension
(KAN-1006) had no profile at all. This script asks App Store Connect for the ACTIVE
IOS_APP_STORE profiles of each bundle id, keeps only those that include the certificate that
was actually installed from the p12 (matched by serial number), installs the newest one per
bundle id, and exports its name and UUID to GITHUB_ENV. Nothing secret is printed: profile
bodies are written to disk only, and only names, UUIDs and expiry dates are logged.

    fetch_profiles.py install --cert-serial <hex> --key-file <p8> --key-id <id> --issuer-id <id>
        [--app-bundle-id app.dabbler.pro] [--ext-bundle-id app.dabbler.pro.DabblerLiveActivity]
        [--profiles-dir DIR] [--github-env FILE]
    fetch_profiles.py export-options --template <plist> --out <plist> <bundle id>=<profile name>...

GITHUB_ENV output: IOS_APP_PROFILE_NAME, IOS_APP_PROFILE_UUID, IOS_EXT_PROFILE_NAME,
IOS_EXT_PROFILE_UUID (and IOS_PROFILE_NAME / IOS_PROFILE_UUID for the app, as before).
"""
import argparse
import base64
import json
import os
import plistlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc_release  # noqa: E402

APP_BUNDLE_ID = "app.dabbler.pro"
EXT_BUNDLE_ID = "app.dabbler.pro.DabblerLiveActivity"
PROFILES_DIR = os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles")


class SelectionError(Exception):
    pass


def normalize_serial(raw):
    """'serial=0A:1B..' / '0a1b' / '00A1B' -> 'A1B' (uppercase hex, no separators, no leading zeros)."""
    s = (raw or "").strip()
    if "=" in s:
        s = s.split("=", 1)[1]
    s = s.replace(":", "").replace(" ", "").upper().lstrip("0")
    return s or "0"


def parse_profiles(payload):
    """Flatten a /v1/profiles response (include=bundleId,certificates) into simple dicts."""
    included = {(i.get("type"), i.get("id")): i.get("attributes") or {} for i in payload.get("included") or []}
    out = []
    for row in payload.get("data") or []:
        a = row.get("attributes") or {}
        rel = row.get("relationships") or {}
        bid_ref = ((rel.get("bundleId") or {}).get("data") or {})
        bundle = included.get(("bundleIds", bid_ref.get("id")), {}).get("identifier")
        serials = []
        for c in (rel.get("certificates") or {}).get("data") or []:
            ser = included.get(("certificates", c.get("id")), {}).get("serialNumber")
            if ser:
                serials.append(normalize_serial(ser))
        out.append({"id": row.get("id"), "name": a.get("name"), "uuid": a.get("uuid"),
                    "state": a.get("profileState"), "type": a.get("profileType"),
                    "expires": a.get("expirationDate") or "", "content": a.get("profileContent"),
                    "bundleId": bundle, "certSerials": serials})
    return out


def select_profile(profiles, bundle_id, cert_serial):
    """The newest ACTIVE IOS_APP_STORE profile for bundle_id that includes cert_serial."""
    want = normalize_serial(cert_serial)
    for_bundle = [p for p in profiles if p["bundleId"] == bundle_id
                  and p["state"] == "ACTIVE" and p["type"] == "IOS_APP_STORE"]
    if not for_bundle:
        raise SelectionError("no ACTIVE IOS_APP_STORE profile exists for %s" % bundle_id)
    matching = [p for p in for_bundle if want in p["certSerials"]]
    if not matching:
        raise SelectionError(
            "the installed distribution certificate (serial %s) is in none of the ACTIVE App Store "
            "profiles for %s (%s); regenerate a profile with that certificate or replace "
            "IOS_DISTRIBUTION_CERT_P12_BASE64" % (want, bundle_id, ", ".join(sorted(p["name"] for p in for_bundle))))
    return sorted(matching, key=lambda p: (p["expires"], p["name"]))[-1]


def fetch_profiles(client):
    payload = client.get("/v1/profiles", {
        "filter[profileType]": "IOS_APP_STORE", "filter[profileState]": "ACTIVE",
        "include": "bundleId,certificates", "limit": "200", "limit[certificates]": "50"})
    return parse_profiles(payload)


def install(profile, profiles_dir):
    if not profile.get("content") or not profile.get("uuid"):
        raise SelectionError("profile %s came back without content or UUID" % profile.get("name"))
    os.makedirs(profiles_dir, exist_ok=True)
    path = os.path.join(profiles_dir, "%s.mobileprovision" % profile["uuid"])
    old = os.umask(0o077)
    try:
        with open(path, "wb") as fh:
            fh.write(base64.b64decode(profile["content"]))
    finally:
        os.umask(old)
    return path


def env_lines(app, ext):
    return ["IOS_APP_PROFILE_NAME=%s" % app["name"], "IOS_APP_PROFILE_UUID=%s" % app["uuid"],
            "IOS_EXT_PROFILE_NAME=%s" % ext["name"], "IOS_EXT_PROFILE_UUID=%s" % ext["uuid"],
            "IOS_PROFILE_NAME=%s" % app["name"], "IOS_PROFILE_UUID=%s" % app["uuid"]]


def cmd_install(args, client=None):
    client = client or asc_release.Client(args.key_file, args.key_id, args.issuer_id)
    profiles = fetch_profiles(client)
    chosen = {}
    try:
        for role, bid in (("app", args.app_bundle_id), ("ext", args.ext_bundle_id)):
            chosen[role] = select_profile(profiles, bid, args.cert_serial)
    except SelectionError as err:
        print("::error::%s" % err)
        return 1
    for role, p in chosen.items():
        install(p, args.profiles_dir)
        print("installed %s profile '%s' (%s, expires %s)" % (role, p["name"], p["uuid"], p["expires"]))
    if args.github_env:
        with open(args.github_env, "a", encoding="utf-8") as fh:
            fh.write("\n".join(env_lines(chosen["app"], chosen["ext"])) + "\n")
    print(json.dumps({r: {"name": p["name"], "uuid": p["uuid"], "expires": p["expires"]} for r, p in chosen.items()}))
    return 0


def export_options(template, mapping):
    with open(template, "rb") as fh:
        d = plistlib.load(fh)
    d["provisioningProfiles"] = dict(mapping)
    return d


def cmd_export_options(args):
    mapping = {}
    for pair in args.mapping:
        bid, sep, name = pair.partition("=")
        if not sep or not bid or not name:
            raise SystemExit("mapping must be <bundle id>=<profile name>: %r" % pair)
        mapping[bid] = name
    with open(args.out, "wb") as fh:
        plistlib.dump(export_options(args.template, mapping), fh)
    print("wrote %s for %s" % (args.out, ", ".join(sorted(mapping))))
    return 0


def main(argv=None, client=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    i = sub.add_parser("install")
    i.add_argument("--cert-serial", required=True)
    i.add_argument("--key-file", required=True)
    i.add_argument("--key-id", required=True)
    i.add_argument("--issuer-id", required=True)
    i.add_argument("--app-bundle-id", default=APP_BUNDLE_ID)
    i.add_argument("--ext-bundle-id", default=EXT_BUNDLE_ID)
    i.add_argument("--profiles-dir", default=PROFILES_DIR)
    i.add_argument("--github-env", default=os.environ.get("GITHUB_ENV"))
    e = sub.add_parser("export-options")
    e.add_argument("--template", required=True)
    e.add_argument("--out", required=True)
    e.add_argument("mapping", nargs="+")
    args = ap.parse_args(argv)
    if args.command == "install":
        return cmd_install(args, client)
    return cmd_export_options(args)


if __name__ == "__main__":
    sys.exit(main())
