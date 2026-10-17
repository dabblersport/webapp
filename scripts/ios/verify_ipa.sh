#!/usr/bin/env bash
#
# Verify a signed IPA before it can be uploaded (KAN-568). Checks bundle id, versionName,
# build number, the embedded provisioning profile and the code signature, and writes only
# NON-SECRET metadata to the JSON file. Nothing from the profile or certificate bodies is printed.
#
#   scripts/ios/verify_ipa.sh <app.ipa> <bundle id> <versionName> <buildNumber> <team id> <profile name> <metadata.json>
#
# Environment: none required. Runs on macOS (uses unzip, plutil, codesign, security).
set -euo pipefail

IPA="${1:?ipa}"; BID="${2:?bundle id}"; VNAME="${3:?versionName}"; BUILD="${4:?build number}"
TEAM="${5:?team id}"; PROFILE_NAME="${6:?profile name}"; OUT="${7:?metadata.json}"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)"
[[ -d "$APP" ]] || { echo "::error::no .app inside the IPA"; exit 1; }

plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }
got_bid="$(plist "$APP/Info.plist" CFBundleIdentifier)"
got_vname="$(plist "$APP/Info.plist" CFBundleShortVersionString)"
got_build="$(plist "$APP/Info.plist" CFBundleVersion)"
fail=0
[[ "$got_bid" == "$BID" ]]       || { echo "::error::bundle id is '$got_bid', expected '$BID'"; fail=1; }
[[ "$got_vname" == "$VNAME" ]]   || { echo "::error::versionName is '$got_vname', expected '$VNAME'"; fail=1; }
[[ "$got_build" == "$BUILD" ]]   || { echo "::error::build number is '$got_build', expected '$BUILD'"; fail=1; }

# Embedded provisioning profile: name, team, application identifier, expiry, distribution type.
security cms -D -i "$APP/embedded.mobileprovision" > "$WORK/profile.plist" 2>/dev/null \
  || { echo "::error::cannot read the embedded provisioning profile"; exit 1; }
p_name="$(plist "$WORK/profile.plist" Name)"
p_team="$(plist "$WORK/profile.plist" TeamIdentifier:0)"
p_appid="$(plist "$WORK/profile.plist" Entitlements:application-identifier)"
p_expiry="$(plist "$WORK/profile.plist" ExpirationDate)"
p_taskallow="$(plist "$WORK/profile.plist" Entitlements:get-task-allow)"
p_devices="$(plist "$WORK/profile.plist" ProvisionedDevices)"
[[ "$p_name" == "$PROFILE_NAME" ]]        || { echo "::error::profile is '$p_name', expected '$PROFILE_NAME'"; fail=1; }
[[ "$p_team" == "$TEAM" ]]                 || { echo "::error::profile team is '$p_team', expected '$TEAM'"; fail=1; }
[[ "$p_appid" == "$TEAM.$BID" ]]           || { echo "::error::profile app id does not match $TEAM.$BID"; fail=1; }
[[ "$p_taskallow" == "false" ]]            || { echo "::error::get-task-allow must be false for an App Store build"; fail=1; }
[[ -z "$p_devices" ]]                      || { echo "::error::profile lists devices: this is not an App Store profile"; fail=1; }

# Code signature: valid, strict, and signed by an Apple Distribution identity of the team.
codesign --verify --deep --strict "$APP" 2>"$WORK/cs.err" || { echo "::error::codesign verification failed"; fail=1; }
codesign -dvv "$APP" 2>"$WORK/cs.info" || true
authority="$(sed -n 's/^Authority=\(Apple Distribution:.*\)$/\1/p' "$WORK/cs.info" | head -1)"
[[ -n "$authority" ]]                      || { echo "::error::not signed by an Apple Distribution identity"; fail=1; }
cs_team="$(sed -n 's/^TeamIdentifier=\(.*\)$/\1/p' "$WORK/cs.info" | head -1)"
[[ "$cs_team" == "$TEAM" ]]                || { echo "::error::signature team is '$cs_team', expected '$TEAM'"; fail=1; }
codesign -d --entitlements :- "$APP" > "$WORK/ents.plist" 2>/dev/null || true
e_aps="$(plist "$WORK/ents.plist" aps-environment)"
[[ "$e_aps" == "production" ]]             || { echo "::error::aps-environment is '$e_aps', expected production"; fail=1; }

(( fail == 0 )) || exit 1

cat > "$OUT" <<JSON
{
  "bundleId": "$got_bid",
  "versionName": "$got_vname",
  "buildNumber": "$got_build",
  "teamId": "$cs_team",
  "profileName": "$p_name",
  "profileExpires": "$p_expiry",
  "signingAuthority": "$authority",
  "getTaskAllow": false,
  "apsEnvironment": "$e_aps",
  "ipaSha256": "$(shasum -a 256 "$IPA" | cut -d' ' -f1)"
}
JSON
cat "$OUT"
