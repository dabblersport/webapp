#!/usr/bin/env bash
#
# run.sh — run a k6 script on purpose and return PASS/FAIL. INTENTIONAL ONLY:
# nothing in routine validation calls this; a human or an explicit
# performance_scope flag does.
#
#   npm run test:perf                      tests/perf/k6/smoke.js
#   bash tests/perf/run.sh k6/<script>.js  a named script
#
# Env: SUPABASE_URL / SUPABASE_ANON_KEY from the environment, else from .env.
# Anon key only. Results (JSON summary) under tests/perf/.results/ (gitignored).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

SCRIPT="${1:-k6/smoke.js}"
[[ "${SCRIPT}" != /* ]] && SCRIPT="${HERE}/${SCRIPT#tests/perf/}"

if ! command -v k6 >/dev/null 2>&1; then
  echo "FAIL: k6 is not on PATH (brew install k6)" >&2
  exit 2
fi
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]] && [[ -f .env ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^(SUPABASE_URL|SUPABASE_ANON_KEY)=' .env | xargs)
fi
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "FAIL: SUPABASE_URL / SUPABASE_ANON_KEY are not set and .env does not supply them." >&2
  exit 2
fi
[[ -f "${SCRIPT}" ]] || { echo "FAIL: no k6 script at ${SCRIPT}" >&2; exit 2; }

mkdir -p "${HERE}/.results"
echo "==> Dabbler perf runner (k6) — intentional run"
echo "    Script: ${SCRIPT}"
k6 run --summary-export "${HERE}/.results/summary.json" "${SCRIPT}"
STATUS=$?
echo
if [[ "${STATUS}" -eq 0 ]]; then
  echo "PASS  k6 $(basename "${SCRIPT}")"
else
  echo "FAIL  k6 $(basename "${SCRIPT}")  (exit ${STATUS}) — thresholds in the script; summary at tests/perf/.results/summary.json"
fi
exit "${STATUS}"
