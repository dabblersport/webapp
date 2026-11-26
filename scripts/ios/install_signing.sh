#!/usr/bin/env bash
#
# Install the App Store signing material on an EPHEMERAL macOS runner (KAN-568): a temporary
# keychain holding the Apple Distribution certificate, and the App Store provisioning profile.
# Secrets are read from the environment (never printed), written only to the runner's temp dir,
# and removed again by scripts/ios/cleanup_signing.sh.
#
# Environment (set by the workflow from repository secrets; names only here):
#   IOS_DISTRIBUTION_CERT_P12_BASE64   the Apple Distribution certificate + private key, .p12, base64
#   IOS_DISTRIBUTION_CERT_PASSWORD     the .p12 password
#   IOS_PROVISIONING_PROFILE_BASE64    OPTIONAL FALLBACK (KAN-1047): an app .mobileprovision, base64.
#                                      The workflow normally fetches the ACTIVE profiles at build
#                                      time with scripts/ios/fetch_profiles.py instead.
#   RUNNER_TEMP                        GitHub's per-job temp dir
# Output (appended to $GITHUB_ENV): KEYCHAIN_PATH, KEYCHAIN_PASSWORD, IOS_CERT_SERIAL (the installed
# distribution certificate's serial, not secret) and, when the fallback secret is set,
# IOS_FALLBACK_PROFILE_UUID / IOS_FALLBACK_PROFILE_NAME
set -euo pipefail

for n in IOS_DISTRIBUTION_CERT_P12_BASE64 IOS_DISTRIBUTION_CERT_PASSWORD; do
  [[ -n "${!n:-}" ]] || { echo "::error::a required iOS signing secret is empty (see dabbler-docs/dabbler-code/IOS_RELEASE.md for the secret names)"; exit 1; }
done

umask 077
KC="$RUNNER_TEMP/dabbler-signing.keychain-db"
KC_PASS="$(uuidgen)$(uuidgen)"            # random, lives only for this job, never printed
echo "::add-mask::$KC_PASS"

security create-keychain -p "$KC_PASS" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KC_PASS" "$KC"

P12="$RUNNER_TEMP/dist.p12"
printf '%s' "$IOS_DISTRIBUTION_CERT_P12_BASE64" | base64 --decode > "$P12"
security import "$P12" -k "$KC" -P "$IOS_DISTRIBUTION_CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
rm -f "$P12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" >/dev/null
# Make the temporary keychain the only one searched for this job.
security list-keychains -d user -s "$KC"

# Serial of the installed Apple Distribution certificate, used to pick the profiles that include it.
SERIAL="$(security find-certificate -a -c "Apple Distribution" -p "$KC" | openssl x509 -noout -serial | sed 's/^serial=//')"
[[ -n "$SERIAL" ]] || { echo "::error::could not read the installed Apple Distribution certificate's serial"; exit 1; }

{
  echo "KEYCHAIN_PATH=$KC"
  echo "KEYCHAIN_PASSWORD=$KC_PASS"
  echo "IOS_CERT_SERIAL=$SERIAL"
} >> "$GITHUB_ENV"

if [[ -n "${IOS_PROVISIONING_PROFILE_BASE64:-}" ]]; then
  PROFILE="$RUNNER_TEMP/profile.mobileprovision"
  printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE"
  security cms -D -i "$PROFILE" > "$RUNNER_TEMP/profile.plist"
  UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$RUNNER_TEMP/profile.plist")"
  NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$RUNNER_TEMP/profile.plist")"
  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  cp "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
  rm -f "$PROFILE" "$RUNNER_TEMP/profile.plist"
  {
    echo "IOS_FALLBACK_PROFILE_UUID=$UUID"
    echo "IOS_FALLBACK_PROFILE_NAME=$NAME"
  } >> "$GITHUB_ENV"
  echo "Installed the fallback profile '$NAME' from the secret."
fi
echo "Installed the distribution identity (temporary keychain), certificate serial $SERIAL."
security find-identity -v -p codesigning "$KC" | sed -E 's/[0-9A-F]{40}/<sha1>/' | tail -3
