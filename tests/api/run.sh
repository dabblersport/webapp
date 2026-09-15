#!/usr/bin/env bash
#
# run.sh — run the repository-owned API collection and return PASS/FAIL.
#
#   npm run test:api
#   bash tests/api/run.sh [collection.json]
#
# Variables come from the environment; `.env` at the repository root is read
# for SUPABASE_URL / SUPABASE_ANON_KEY when they are not already set (process
# environment wins, the same precedence rule as tests/e2e). The anon key is
# public-by-design and RLS-protected; nothing else is ever passed, and no
# service-role key may be used here.
#
# Engine: Postman CLI when it is logged in (`postman login --with-api-key`,
# key from POSTMAN_API_KEY — never from a file in this repository), otherwise
# newman via npx, which runs the same collection format with no account.
# Both write JUnit-style results under tests/api/.results/ (gitignored).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

COLLECTION="${1:-${HERE}/dabbler-api.postman_collection.json}"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]] && [[ -f .env ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^(SUPABASE_URL|SUPABASE_ANON_KEY)=' .env | xargs)
fi
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "FAIL: SUPABASE_URL / SUPABASE_ANON_KEY are not set and .env does not supply them." >&2
  exit 2
fi
[[ -f "${COLLECTION}" ]] || { echo "FAIL: no collection at ${COLLECTION}" >&2; exit 2; }

mkdir -p "${HERE}/.results"
echo "==> Dabbler API runner"
echo "    Collection: ${COLLECTION}"
echo "    Target:     ${SUPABASE_URL}"

STATUS=2
if command -v postman >/dev/null 2>&1 && [[ -n "${POSTMAN_API_KEY:-}" ]]; then
  echo "==> engine: Postman CLI"
  postman login --with-api-key "${POSTMAN_API_KEY}" >/dev/null 2>&1 || true
  postman collection run "${COLLECTION}" \
    --env-var "SUPABASE_URL=${SUPABASE_URL}" \
    --env-var "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
    --reporters cli,junit --reporter-junit-export "${HERE}/.results/junit.xml"
  STATUS=$?
else
  echo "==> engine: newman (npx) — Postman CLI needs POSTMAN_API_KEY to be logged in"
  npx --yes newman@6 run "${COLLECTION}" \
    --env-var "SUPABASE_URL=${SUPABASE_URL}" \
    --env-var "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
    --reporters cli,junit --reporter-junit-export "${HERE}/.results/junit.xml"
  STATUS=$?
fi

echo
if [[ "${STATUS}" -eq 0 ]]; then
  echo "PASS  api $(basename "${COLLECTION}")"
else
  echo "FAIL  api $(basename "${COLLECTION}")  (exit ${STATUS}) — see tests/api/.results/junit.xml"
fi
exit "${STATUS}"
