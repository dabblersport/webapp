#!/usr/bin/env bash
# KAN-175 — CI gate for anon-executable SECURITY DEFINER functions.
#
# The KAN-61 gate (check_anon_allowlist.sh) covers VIEWS only. Its SQL reads
# `WHERE c.relkind = 'v'`; there is no pg_proc, no proacl and no EXECUTE
# anywhere in it. A SECURITY DEFINER FUNCTION that anon can call is a different
# Postgres object class, so that gate ran green throughout the live window of the
# exposure it was supposed to catch. This script covers the function class.
#
# Reports the AC1 census (never fails on it) and fails on the narrow predicate
# defined in anon_function_grants_diff.sh, diffed against docs/SCHEMA.md §2g.
#
# Requires SUPABASE_DB_URL: a direct Postgres connection string with enough
# privilege to read pg_catalog. Never needs service_role or superuser.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_MD="$REPO_ROOT/docs/SCHEMA.md"

# shellcheck source=./anon_function_grants_diff.sh
source "$SCRIPT_DIR/anon_function_grants_diff.sh"

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "FAIL: SUPABASE_DB_URL is not set." >&2
  echo "" >&2
  echo "This gate needs a direct Postgres connection string (Project Settings ->" >&2
  echo "Database -> Connection string, in the wtncuzcskpigqpmnxwws project), added" >&2
  echo "as a GitHub Actions secret named SUPABASE_DB_URL. It shares that secret with" >&2
  echo "the KAN-61 view gate, which has been running against it since 2026-08-29." >&2
  echo "Failing loudly here is intentional: a skipped security gate must be visible." >&2
  exit 1
fi

command -v psql >/dev/null 2>&1 || { echo "FAIL: psql not found on PATH." >&2; exit 1; }

LIVE_FILE="$(mktemp)"
ALLOWLIST_FILE="$(mktemp)"
trap 'rm -f "$LIVE_FILE" "$ALLOWLIST_FILE"' EXIT

# ------------------------------------------------------------ census (non-failing)
echo "--- Census: public functions, reported not enforced (AC1 bullets 1 and 2) ---"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tA -F' | ' -c "$(anon_function_census_sql)" \
  | while IFS='|' read -r secdef anon_x both public_only; do
      echo "  SECURITY DEFINER:                       ${secdef// /}"
      echo "  anon-executable (effective privilege):  ${anon_x// /}"
      echo "  both:                                   ${both// /}"
      echo "  ...of which reachable ONLY via the bare PUBLIC grant: ${public_only// /}"
    done
echo "  (These are too broad to allowlist one-by-one and never fail the build."
echo "   The last line is the population a proacl text-match would silently miss.)"
echo

# ------------------------------------------------------------ gate (failing)
echo "--- Gate: unguarded caller-supplied identity on definer+anon functions ---"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tAc "$(anon_function_predicate_sql)" \
  | sed '/^[[:space:]]*$/d' > "$LIVE_FILE"

awk '/<!-- ANON_FUNCTION_ALLOWLIST_START -->/{flag=1; next} /<!-- ANON_FUNCTION_ALLOWLIST_END -->/{flag=0} flag' \
  "$SCHEMA_MD" | sed '/^[[:space:]]*$/d' > "$ALLOWLIST_FILE"

if [[ ! -s "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: could not find a non-empty allowlist between the" >&2
  echo "ANON_FUNCTION_ALLOWLIST_START/END markers in docs/SCHEMA.md §2g." >&2
  echo "The markers may have been moved or removed. Note these are a SEPARATE block" >&2
  echo "from §2f's ANON_ALLOWLIST_START/END, which holds view names for KAN-61 and" >&2
  echo "must not be widened to hold function signatures." >&2
  exit 1
fi

anon_function_grants_diff "$LIVE_FILE" "$ALLOWLIST_FILE"
