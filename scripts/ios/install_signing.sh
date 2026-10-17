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
#   IOS_PROVISIONING_PROFILE_BASE64    the "Dabbler App Store" .mobileprovision, base64
#   RUNNER_TEMP                        GitHub's per-job temp dir
# Output (appended to $GITHUB_ENV): KEYCHAIN_PATH, IOS_PROFILE_UUID, IOS_PROFILE_NAME
set -euo pipefail

for n in IOS_DISTRIBUTION_CERT_P12_BASE64 IOS_DISTRIBUTION_CERT_PASSWORD IOS_PROVISIONING_PROFILE_BASE64; do
  [[ -n "${!n:-}" ]] || { echo "::error::a required iOS signing secret is empty (see docs/IOS_RELEASE.md for the secret names)"; exit 1; }
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

PROFILE="$RUNNER_TEMP/profile.mobileprovision"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE"
security cms -D -i "$PROFILE" > "$RUNNER_TEMP/profile.plist"
UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$RUNNER_TEMP/profile.plist")"
NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$RUNNER_TEMP/profile.plist")"
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
rm -f "$PROFILE" "$RUNNER_TEMP/profile.plist"

{
  echo "KEYCHAIN_PATH=$KC"
  echo "KEYCHAIN_PASSWORD=$KC_PASS"
  echo "IOS_PROFILE_UUID=$UUID"
  echo "IOS_PROFILE_NAME=$NAME"
} >> "$GITHUB_ENV"
echo "Installed the distribution identity (temporary keychain) and profile '$NAME'."
security find-identity -v -p codesigning "$KC" | sed -E 's/[0-9A-F]{40}/<sha1>/' | tail -3
