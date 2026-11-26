#!/usr/bin/env bash
# Remove the temporary signing material from the runner (KAN-568). Safe to run when nothing was installed.
set -uo pipefail
if [[ -n "${KEYCHAIN_PATH:-}" && -e "${KEYCHAIN_PATH}" ]]; then
  security delete-keychain "$KEYCHAIN_PATH" || true
fi
for u in "${IOS_PROFILE_UUID:-}" "${IOS_APP_PROFILE_UUID:-}" "${IOS_EXT_PROFILE_UUID:-}" "${IOS_FALLBACK_PROFILE_UUID:-}"; do
  [[ -n "$u" ]] && rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/${u}.mobileprovision" || true
done
rm -rf "${RUNNER_TEMP:-/nonexistent}/asc" "${RUNNER_TEMP:-/nonexistent}/dist.p12" "${RUNNER_TEMP:-/nonexistent}/profile.mobileprovision" || true
rm -rf "${HOME}/.appstoreconnect/private_keys" 2>/dev/null || true
exit 0
