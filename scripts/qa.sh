#!/usr/bin/env bash
#
# qa.sh — run Dabbler integration tests and return PASS/FAIL. Text only.
#
# This exists because driving the simulator by screenshot is slow, expensive and
# unreliable: every screenshot is a large image in an agent's context, and a
# native alert swallows input silently so the screenshot of a swallowed login is
# indistinguishable from a failed one. See
# .claude/agent-memory/qa/stories/login-ios.md.
#
# This script never captures an image. It boots/verifies the simulator, grants
# location up front so that dialog never fires, runs `flutter test` against
# integration_test/, and exits with the test's own status code.
#
# See --help for usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

BUNDLE_ID="app.dabbler.pro"
DEVICE="ios"
FRESH=0
TIMEOUT_SECS=1200
TARGET=""

usage() {
  cat <<'EOF'
Usage: ./scripts/qa.sh [target] [-d ios|chrome] [--fresh] [--timeout SECS]

Runs the integration tests and prints PASS or FAIL. No screenshots, ever.

  target          A file under integration_test/, or a shorthand name.
                    ./scripts/qa.sh              -> integration_test/  (all)
                    ./scripts/qa.sh login        -> integration_test/login_test.dart
                    ./scripts/qa.sh integration_test/app_test.dart
                  A shorthand that has no matching file is an error, not a
                  silent full-suite run.

  -d, --device    ios (default) or chrome.
                    ios     — real device behaviour. Required for anything
                              device-specific: notifications, permissions,
                              deep links, platform channels. Costs a build
                              (~8 min cold, under a minute warm).
                    chrome  — logic only. Skips the iOS build entirely, so it
                              is far faster, but it is not the app on a phone:
                              no native permission dialogs, no push, no
                              platform channels. Use it for business logic and
                              routing; use ios for anything a device does.
                              Requires chromedriver on PATH.

      --fresh     Uninstall the app before running.
                  OFF BY DEFAULT ON PURPOSE. The install and its logged-in
                  session persist between runs, which is what makes repeat runs
                  fast. Pass --fresh ONLY when the thing under test is auth
                  itself: with a persisted session a login test passes
                  vacuously — it never reaches the login screen, and it will
                  report PASS while proving nothing. --fresh also brings back
                  the first-run permission dialogs (see the warning below).

      --timeout   Seconds before the run is killed and reported as FAIL
                  (default 1200). A hung run and a slow run look identical
                  from outside; this makes the script say which.

  -h, --help      This text.

Credentials are read at run time from .env via --dart-define-from-file.
They are never written into this script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -d|--device) DEVICE="${2:-}"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    --timeout) TIMEOUT_SECS="${2:-}"; shift 2 ;;
    -*) echo "qa.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -n "${TARGET}" ]]; then
        echo "qa.sh: more than one target given ('${TARGET}' and '$1')" >&2
        exit 2
      fi
      TARGET="$1"; shift ;;
  esac
done

# ---------------------------------------------------------------- target ----
if [[ -z "${TARGET}" ]]; then
  TEST_TARGET="integration_test/"
elif [[ -e "${TARGET}" ]]; then
  TEST_TARGET="${TARGET}"
elif [[ -e "integration_test/${TARGET}_test.dart" ]]; then
  TEST_TARGET="integration_test/${TARGET}_test.dart"
elif [[ -e "integration_test/${TARGET}" ]]; then
  TEST_TARGET="integration_test/${TARGET}"
else
  echo "FAIL: no such test target '${TARGET}'." >&2
  echo "      Tried: ${TARGET}, integration_test/${TARGET}_test.dart, integration_test/${TARGET}" >&2
  echo "      Present under integration_test/:" >&2
  ls -1 integration_test/*.dart 2>/dev/null | sed 's/^/        /' >&2 || echo "        (none)" >&2
  exit 2
fi

if [[ ! -f .env ]]; then
  echo "FAIL: .env not found at ${REPO_ROOT}/.env." >&2
  echo "      The app calls Environment.load() -> _validate() during bootstrap and" >&2
  echo "      throws 'Missing environment variables' without it. Copy .env.example." >&2
  exit 2
fi

echo "==> Dabbler QA runner"
echo "    Repo:   ${REPO_ROOT}"
echo "    Target: ${TEST_TARGET}"
echo "    Device: ${DEVICE}"

# ---------------------------------------------------------------- device ----
FLUTTER_CMD=(flutter test "${TEST_TARGET}" --dart-define-from-file=.env)

case "${DEVICE}" in
  ios)
    UDID="$(xcrun simctl list devices booted 2>/dev/null \
      | grep -Eo '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
      | head -n 1)"

    if [[ -z "${UDID}" ]]; then
      echo "==> No simulator booted. Booting the newest available iPhone."
      UDID="$(xcrun simctl list devices available 2>/dev/null \
        | grep -E '^\s+iPhone' \
        | grep -Eo '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
        | tail -n 1)"
      if [[ -z "${UDID}" ]]; then
        echo "FAIL: no available iPhone simulator to boot." >&2
        exit 2
      fi
      xcrun simctl boot "${UDID}" >/dev/null 2>&1 || true
      open -a Simulator >/dev/null 2>&1 || true
    fi

    # Wait for the device to actually reach Booted. `simctl boot` returns before
    # the device is usable, and installing into a booting device fails oddly.
    for _ in $(seq 1 60); do
      xcrun simctl list devices 2>/dev/null | grep -q "${UDID}) (Booted)" && break
      sleep 1
    done
    if ! xcrun simctl list devices 2>/dev/null | grep -q "${UDID}) (Booted)"; then
      echo "FAIL: simulator ${UDID} did not reach Booted within 60s." >&2
      exit 2
    fi

    DEV_NAME="$(xcrun simctl list devices 2>/dev/null | grep "${UDID}" \
      | sed -E 's/^[[:space:]]*//; s/ \(.*//' | head -n 1)"
    echo "==> Simulator: ${DEV_NAME:-unknown} (${UDID})"

    if [[ "${FRESH}" -eq 1 ]]; then
      echo "==> --fresh: uninstalling ${BUNDLE_ID} (session will not persist)"
      xcrun simctl uninstall "${UDID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
    fi

    # Pre-grant location so the location alert never appears. simctl applies
    # this to the bundle id whether or not the app is currently installed.
    echo "==> Granting location permissions to ${BUNDLE_ID}"
    for SERVICE in location location-always; do
      if xcrun simctl privacy "${UDID}" grant "${SERVICE}" "${BUNDLE_ID}" 2>/dev/null; then
        echo "    granted: ${SERVICE}"
      else
        echo "    WARNING: could not grant ${SERVICE} — the location dialog may appear."
      fi
    done

    cat <<'WARN'

    ----------------------------------------------------------------------
    WARNING — NOTIFICATIONS CANNOT BE PRE-GRANTED.

    `xcrun simctl privacy` has no notifications service; the full list is
    calendar, contacts, contacts-limited, location, location-always, photos,
    photos-add, media-library, microphone, motion, reminders, siri. There is
    no supported command for it, so this script does not pretend to have one.

    Consequence: on a FRESH INSTALL the notification permission alert still
    fires. It is a SpringBoard alert; it sits above the Flutter view and
    swallows input. A test driving the app underneath it will fail in a way
    that looks like an app defect and is not.

    On a warm run (the default — no --fresh) the grant is already recorded
    from the previous install, so the alert does not appear. That is a second
    reason not to pass --fresh casually.

    The permanent fix is a guard at
      lib/services/notifications/push_notification_service_mobile.dart:39
    so the permission request is skipped under an integration-test flag. That
    is a developer's change, not devops'. It is owed and not done.
    ----------------------------------------------------------------------

WARN

    FLUTTER_CMD+=(-d "${UDID}")
    ;;

  chrome)
    if ! command -v chromedriver >/dev/null 2>&1; then
      echo "FAIL: chromedriver is not on PATH." >&2
      echo "      Web integration tests run through 'flutter drive', which needs it." >&2
      echo "      Install: brew install --cask chromedriver   (then clear quarantine)" >&2
      echo "      Or use the iOS path: ./scripts/qa.sh ${TARGET:-} -d ios" >&2
      exit 2
    fi
    if [[ ! -f test_driver/integration_test.dart ]]; then
      echo "FAIL: test_driver/integration_test.dart is missing (required by flutter drive)." >&2
      exit 2
    fi
    if [[ "${TEST_TARGET}" == */ ]]; then
      echo "FAIL: 'flutter drive' takes one --target file, not a directory." >&2
      echo "      Name a single test, e.g. ./scripts/qa.sh app -d chrome" >&2
      exit 2
    fi
    echo "==> Starting chromedriver on :4444"
    chromedriver --port=4444 >/dev/null 2>&1 &
    CHROMEDRIVER_PID=$!
    trap 'kill "${CHROMEDRIVER_PID}" 2>/dev/null || true' EXIT
    sleep 2
    FLUTTER_CMD=(flutter drive
      --driver=test_driver/integration_test.dart
      --target="${TEST_TARGET}"
      -d web-server
      --browser-name=chrome
      --dart-define-from-file=.env)
    ;;

  *)
    echo "qa.sh: --device must be 'ios' or 'chrome' (got '${DEVICE}')" >&2
    exit 2 ;;
esac

# ------------------------------------------------------------------- run ----
echo "==> Running: ${FLUTTER_CMD[*]}"
echo "    Timeout: ${TIMEOUT_SECS}s"
echo

# Watchdog. A hung run and a slow run are indistinguishable from outside, and
# that ambiguity is exactly what makes an agent sit and wait. Kill and say so.
#
# Deliberately polled in the FOREGROUND rather than with a background subshell:
# a backgrounded watchdog inherits stdout, so its still-sleeping `sleep` keeps
# the pipe open after the test exits and `./scripts/qa.sh | tail` hangs forever
# with the verdict stuck in the pipe. That failure looks exactly like the hang
# this script exists to make visible.
"${FLUTTER_CMD[@]}" &
RUN_PID=$!

ELAPSED=0
TIMED_OUT=0
while kill -0 "${RUN_PID}" 2>/dev/null; do
  if (( ELAPSED >= TIMEOUT_SECS )); then
    TIMED_OUT=1
    echo
    echo "!!! TIMEOUT after ${TIMEOUT_SECS}s — killing the run."
    echo "    If this was a --fresh iOS run, the most likely cause is the"
    echo "    notification permission alert blocking input (see warning above)."
    kill -TERM "${RUN_PID}" 2>/dev/null || true
    sleep 5
    kill -KILL "${RUN_PID}" 2>/dev/null || true
    break
  fi
  sleep 2
  ELAPSED=$(( ELAPSED + 2 ))
done

wait "${RUN_PID}"
STATUS=$?
if [[ "${TIMED_OUT}" -eq 1 ]]; then
  STATUS=124
fi

echo
if [[ "${STATUS}" -eq 0 ]]; then
  echo "PASS  ${TEST_TARGET} on ${DEVICE}"
else
  echo "FAIL  ${TEST_TARGET} on ${DEVICE}  (exit ${STATUS})"
fi
exit "${STATUS}"
