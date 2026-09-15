#!/usr/bin/env bash
#
# run.sh — run Maestro flows on the connected Android emulator/device and
# return PASS/FAIL. Text only; no screenshots enter any agent's context.
#
#   npm run test:maestro                      smoke flows
#   bash tests/maestro/run.sh flows/<dir>     a folder or a single flow file
#
# What it needs, and what it says when it is missing (each is an exit 2 —
# a test-infrastructure failure, never a Product failure):
#   - maestro on PATH
#   - one Android device visible to adb (an emulator booted headless is fine:
#       emulator -avd Dabbler_test -no-window -no-audio -no-boot-anim)
#   - the app installed, or a debug APK to install:
#       flutter build apk --debug --dart-define-from-file=.env
#
# iOS simulators are not a target on this machine: `xcrun simctl` sits behind
# an unaccepted Xcode licence that no agent may accept. The flows are
# platform-neutral YAML; iOS becomes a target when a licensed simulator exists.
#
# Results: JUnit XML at tests/maestro/.results/junit.xml (gitignored). The
# Thebes QA layer reads the exit code and the last lines; a human opens the XML.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="${ANDROID_HOME}/platform-tools:${PATH}"

APP_ID="com.dabbler.dabblerapp"
APK="build/app/outputs/flutter-apk/app-debug.apk"
TARGET="${1:-${HERE}/flows/smoke}"
[[ "${TARGET}" != /* ]] && TARGET="${HERE}/${TARGET#tests/maestro/}"

echo "==> Dabbler Maestro runner"
echo "    Target: ${TARGET}"

if ! command -v maestro >/dev/null 2>&1; then
  echo "FAIL: maestro is not on PATH (install: curl -Ls https://get.maestro.mobile.dev | bash)" >&2
  exit 2
fi
if ! command -v adb >/dev/null 2>&1; then
  echo "FAIL: adb is not on PATH and ANDROID_HOME=${ANDROID_HOME} has no platform-tools" >&2
  exit 2
fi
if ! adb devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
  echo "FAIL: no Android device/emulator connected. adb devices:" >&2
  adb devices >&2
  echo "      boot one: ${ANDROID_HOME}/emulator/emulator -avd Dabbler_test -no-window -no-audio -no-boot-anim" >&2
  exit 2
fi
if ! adb shell pm list packages 2>/dev/null | tr -d '\r' | grep -q "^package:${APP_ID}$"; then
  if [[ -f "${APK}" ]]; then
    echo "==> ${APP_ID} not installed; installing ${APK}"
    adb install -r "${APK}" >/dev/null || { echo "FAIL: adb install failed" >&2; exit 2; }
  else
    echo "FAIL: ${APP_ID} is not installed and ${APK} does not exist." >&2
    echo "      Build it: flutter build apk --debug --dart-define-from-file=.env" >&2
    exit 2
  fi
fi

mkdir -p "${HERE}/.results"
echo "==> maestro test ${TARGET}"
maestro test --format junit --output "${HERE}/.results/junit.xml" "${TARGET}"
STATUS=$?
echo
if [[ "${STATUS}" -eq 0 ]]; then
  echo "PASS  maestro ${TARGET}"
else
  echo "FAIL  maestro ${TARGET}  (exit ${STATUS}) — see tests/maestro/.results/junit.xml"
fi
exit "${STATUS}"
