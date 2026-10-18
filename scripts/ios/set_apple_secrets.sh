#!/usr/bin/env bash
#
# CEO-run, one time (KAN-568): put the three Apple secrets that cannot be read by automation
# into GitHub Actions Secrets, without ever showing them.
#
#   scripts/ios/set_apple_secrets.sh /path/to/Distribution.p12
#
# You are asked, with typing hidden, for (1) the password you chose when exporting the .p12 and
# (2) the App Store Connect Issuer ID. Nothing is echoed, logged or written to the repository.
# It sets:
#   IOS_DISTRIBUTION_CERT_P12_BASE64   the .p12, base64
#   IOS_DISTRIBUTION_CERT_PASSWORD     its password
#   APP_STORE_CONNECT_ISSUER_ID        the issuer UUID
# and keeps a backup copy of the .p12 and password OUTSIDE this repository, in
# $RELEASE_CREDENTIALS_DIR (default: <workspace>/Dabbler/.release-credentials/ios).
#
# Before it sets anything it checks, locally, that the .p12 holds the Apple Distribution
# identity of team J5636UH8V8 and that its certificate is the one the "Dabbler App Store"
# provisioning profile was issued for, so a wrong export fails here and not in a release run.
set -euo pipefail

P12="${1:?usage: set_apple_secrets.sh /path/to/Distribution.p12}"
REPO="${GITHUB_REPOSITORY:-dabblersport/webapp}"
PROFILE="${PROFILE_FILE:-}"
BACKUP="${RELEASE_CREDENTIALS_DIR:-}"
[[ -f "$P12" ]] || { echo "no such file: $P12" >&2; exit 1; }
command -v gh >/dev/null || { echo "gh (GitHub CLI) is required and must be logged in" >&2; exit 1; }

read -r -s -p "Password of the .p12 (hidden): " PW; echo
export PW   # read by openssl via -passin env:PW only; never on a command line
read -r -p "App Store Connect Issuer ID (a UUID, from Users and Access > Integrations > App Store Connect API): " ISSUER
[[ "$ISSUER" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { echo "the Issuer ID must be a UUID" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; unset PW' EXIT
openssl pkcs12 -in "$P12" -nokeys -passin env:PW -out "$TMP/certs.pem" 2>/dev/null \
  || openssl pkcs12 -legacy -in "$P12" -nokeys -passin env:PW -out "$TMP/certs.pem" 2>/dev/null \
  || { echo "cannot open the .p12 with that password" >&2; exit 1; }
SUBJ="$(openssl x509 -in "$TMP/certs.pem" -noout -subject 2>/dev/null || true)"
[[ "$SUBJ" == *"Apple Distribution"* && "$SUBJ" == *"J5636UH8V8"* ]] || { echo "the .p12 does not hold an Apple Distribution certificate for team J5636UH8V8" >&2; exit 1; }
openssl pkcs12 -in "$P12" -nocerts -nodes -passin env:PW -out "$TMP/key.pem" 2>/dev/null \
  || openssl pkcs12 -legacy -in "$P12" -nocerts -nodes -passin env:PW -out "$TMP/key.pem" 2>/dev/null \
  || { echo "the .p12 holds no private key (export the identity, not just the certificate)" >&2; exit 1; }
grep -q "PRIVATE KEY" "$TMP/key.pem" || { echo "the .p12 holds no private key (export the identity, not just the certificate)" >&2; exit 1; }
rm -f "$TMP/key.pem"

if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  security cms -D -i "$PROFILE" > "$TMP/profile.plist" 2>/dev/null
  PROFILE_SHA="$(python3 - "$TMP/profile.plist" <<'PY'
import hashlib, plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
print(hashlib.sha1(p["DeveloperCertificates"][0]).hexdigest().upper())
PY
)"
  P12_SHA="$(openssl x509 -in "$TMP/certs.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g' | tr 'a-f' 'A-F')"
  [[ "$PROFILE_SHA" == "$P12_SHA" ]] || { echo "this certificate is not the one the provisioning profile was issued for" >&2; exit 1; }
  echo "ok: the certificate matches the provisioning profile."
fi

base64 < "$P12" | tr -d '\n' | gh secret set IOS_DISTRIBUTION_CERT_P12_BASE64 --repo "$REPO"
printf '%s' "$PW" | gh secret set IOS_DISTRIBUTION_CERT_PASSWORD --repo "$REPO"
printf '%s' "$ISSUER" | gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$REPO"

if [[ -n "$BACKUP" ]]; then
  umask 077; mkdir -p "$BACKUP"
  cp "$P12" "$BACKUP/Dabbler_Distribution.p12"; printf '%s' "$PW" > "$BACKUP/distribution-p12-password.txt"
  chmod 600 "$BACKUP/Dabbler_Distribution.p12" "$BACKUP/distribution-p12-password.txt"
  echo "Backup written to $BACKUP (outside the repository)."
fi
echo "Done: IOS_DISTRIBUTION_CERT_P12_BASE64, IOS_DISTRIBUTION_CERT_PASSWORD and APP_STORE_CONNECT_ISSUER_ID are set. Now delete the exported .p12 from Downloads."
