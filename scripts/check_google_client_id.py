#!/usr/bin/env python3
"""KAN-568 / KAN-571: refuse a mobile build whose GOOGLE_WEB_CLIENT_ID cannot work as the Google serverClientId.

The app compiles GOOGLE_WEB_CLIENT_ID as the Google `serverClientId`. It must be the project's WEB OAuth client
(client_type 3 in android/app/google-services.json). The ANDROID client (client_type 1) in that variable makes Google
sign-in fail with ApiException 10. The check reads the value from the environment, never prints it, and fails when it
is empty or equals any Android (client_type 1) client id of the file.

    GOOGLE_WEB_CLIENT_ID=... python3 scripts/check_google_client_id.py android/app/google-services.json
"""
import json
import os
import sys


def android_client_ids(doc):
    ids = set()
    for client in doc.get("client", []):
        for oauth in client.get("oauth_client", []):
            if oauth.get("client_type") == 1 and oauth.get("client_id"):
                ids.add(oauth["client_id"])
    return ids


def check(value, doc):
    """Returns None when acceptable, otherwise a message that does not contain the value."""
    value = (value or "").strip()
    if not value:
        return "GOOGLE_WEB_CLIENT_ID is empty"
    if value in android_client_ids(doc):
        return "GOOGLE_WEB_CLIENT_ID is an ANDROID OAuth client id (client_type 1) from google-services.json; it must be the WEB client id (client_type 3)"
    return None


def main(argv):
    if len(argv) != 2:
        print("usage: check_google_client_id.py <google-services.json>", file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        doc = json.load(f)
    problem = check(os.environ.get("GOOGLE_WEB_CLIENT_ID"), doc)
    if problem:
        print(f"::error::{problem}")
        return 1
    print("GOOGLE_WEB_CLIENT_ID is set and is not an Android OAuth client id")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
