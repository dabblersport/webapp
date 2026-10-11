#!/usr/bin/env bash
#
# Verify a built Android App Bundle before it can be published (KAN-493).
# Checks package, versionName, versionCode and the SIGNING CERTIFICATE of the .aab,
# against the values the release asked for and against the keystore it was signed with.
# Prints only non-secret metadata (package, versions, certificate SHA-256 fingerprints).
#
#   scripts/android/verify_aab.sh <app.aab> <package> <versionName> <versionCode> <metadata.json>
#
# Environment (all set by the release workflow; nothing is printed):
#   BUNDLETOOL_JAR           path to the pinned bundletool jar
#   KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS   the keystore the build was signed with
#   EXPECTED_UPLOAD_CERT_SHA256   optional: the recorded upload-certificate fingerprint
set -euo pipefail

AAB="${1:?aab path}"; PKG="${2:?package}"; VNAME="${3:?versionName}"; VCODE="${4:?versionCode}"; OUT="${5:?metadata.json}"
: "${BUNDLETOOL_JAR:?}" "${KEYSTORE_PATH:?}" "${KEYSTORE_PASSWORD:?}" "${KEY_ALIAS:?}"

norm() { tr -d ': \n' | tr 'a-f' 'A-F'; }

# 1. package / versionName / versionCode from the bundle's own manifest
manifest="$(java -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$AAB")"
first_match() { awk -v re="$1" 'match($0, re) { s = substr($0, RSTART, RLENGTH); sub(/^[^"]*"/, "", s); sub(/"$/, "", s); print s; exit }' <<<"$2"; }
got_pkg="$(first_match '[[:space:]]package="[^"]*"' "$manifest")"
got_vname="$(first_match 'android:versionName="[^"]*"' "$manifest")"
got_vcode="$(first_match 'android:versionCode="[^"]*"' "$manifest")"
fail=0
[[ "$got_pkg" == "$PKG" ]]     || { echo "::error::package is '$got_pkg', expected '$PKG'"; fail=1; }
[[ "$got_vname" == "$VNAME" ]] || { echo "::error::versionName is '$got_vname', expected '$VNAME'"; fail=1; }
[[ "$got_vcode" == "$VCODE" ]] || { echo "::error::versionCode is '$got_vcode', expected '$VCODE'"; fail=1; }

# 2. the certificate the bundle is signed with (jarsigner-style signature on the .aab)
cert_dump="$(keytool -printcert -jarfile "$AAB" 2>/dev/null || true)"
sha_line() { awk '/^[[:space:]]*SHA256:/ { print $2; exit }' <<<"$1" | norm; }
bundle_cert="$(sha_line "$cert_dump")"
[[ -n "$bundle_cert" ]] || { echo "::error::the bundle carries no signing certificate (unsigned or debug-signed)"; fail=1; }

# 3. the certificate of the keystore we meant to sign with
store_dump="$(keytool -list -v -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" -alias "$KEY_ALIAS" 2>/dev/null || true)"
store_cert="$(sha_line "$store_dump")"
[[ -n "$store_cert" ]] || { echo "::error::could not read the keystore certificate"; fail=1; }
[[ "$bundle_cert" == "$store_cert" ]] || { echo "::error::bundle certificate does not match the release keystore"; fail=1; }

expected="$(printf '%s' "${EXPECTED_UPLOAD_CERT_SHA256:-}" | norm)"
if [[ -n "$expected" && "$bundle_cert" != "$expected" ]]; then
  echo "::error::bundle certificate does not match the recorded upload certificate"; fail=1
fi

# 4. a debug-signed bundle must never pass
if grep -qi 'Android Debug' <<<"$cert_dump"; then
  echo "::error::bundle is signed with the Android debug certificate"; fail=1
fi

colon() { sed 's/../&:/g; s/:$//' <<<"$1"; }
sha256="$(shasum -a 256 "$AAB" 2>/dev/null || sha256sum "$AAB")"; sha256="${sha256%% *}"
cat > "$OUT" <<JSON
{
  "package": "$got_pkg",
  "versionName": "$got_vname",
  "versionCode": "$got_vcode",
  "aabSha256": "$sha256",
  "signingCertSha256": "$(colon "$bundle_cert")",
  "matchesReleaseKeystore": $([[ "$bundle_cert" == "$store_cert" && -n "$store_cert" ]] && echo true || echo false),
  "matchesRecordedUploadCert": $([[ -n "$expected" ]] && { [[ "$bundle_cert" == "$expected" ]] && echo true || echo false; } || echo null)
}
JSON
cat "$OUT"
exit "$fail"
