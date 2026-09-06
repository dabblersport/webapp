#!/usr/bin/env bash
#
# Run Dabbler integration tests on a booted iOS Simulator.
#
# Behaviour:
#   - Auto-detects the currently booted iOS simulator and runs the integration
#     tests against it.
#   - If no simulator is booted, prints a message and falls back to the default
#     device selection (`flutter test integration_test/`).
#
# Usage:
#   ./scripts/run_integration_tests.sh
#   ./scripts/run_integration_tests.sh integration_test/app_test.dart   # single file

set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Test target: a specific file/dir if passed, otherwise the whole suite.
TEST_TARGET="${1:-integration_test/}"

echo "==> Dabbler integration test runner"
echo "    Repo:   ${REPO_ROOT}"
echo "    Target: ${TEST_TARGET}"

# Detect the first booted iOS simulator's UDID.
# Example line: "    iPhone 17 Pro (ABCD1234-...-EF) (Booted)"
BOOTED_UDID="$(xcrun simctl list devices booted 2>/dev/null \
  | grep -Eo '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
  | head -n 1 || true)"

if [[ -n "${BOOTED_UDID}" ]]; then
  BOOTED_NAME="$(xcrun simctl list devices booted 2>/dev/null \
    | grep "${BOOTED_UDID}" | sed -E 's/^[[:space:]]*//; s/ \(.*//' | head -n 1 || true)"
  echo "==> Booted simulator detected: ${BOOTED_NAME:-unknown} (${BOOTED_UDID})"
  echo "==> Running: flutter test ${TEST_TARGET} -d ${BOOTED_UDID} --dart-define-from-file=.env"
  exec flutter test "${TEST_TARGET}" -d "${BOOTED_UDID}" --dart-define-from-file=.env
else
  echo "==> No booted iOS simulator found."
  echo "    Tip: boot one with 'open -a Simulator' (or 'xcrun simctl boot <udid>')."
  echo "==> Falling back to: flutter test ${TEST_TARGET} --dart-define-from-file=.env"
  exec flutter test "${TEST_TARGET}" --dart-define-from-file=.env
fi
