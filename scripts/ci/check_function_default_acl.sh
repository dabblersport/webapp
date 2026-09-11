#!/usr/bin/env bash
# KAN-189/KAN-194 — CI gate for the function default-privilege configuration.
#
# KAN-67's revoke covered TABLES only. `pg_default_acl` for FUNCTIONS in
# `public` still granted `anon` EXECUTE on every future `CREATE FUNCTION` — on
# TWO independent channels, closing only one of which (KAN-189's first
# migration) was proven live to be insufficient. See
# function_default_acl_diff.sh for the full explanation and docs/SCHEMA.md
# §2g.1 for the history.
#
# This is read-only against wtncuzcskpigqpmnxwws — no CREATE FUNCTION, no
# ALTER DEFAULT PRIVILEGES here. It only queries pg_default_acl.
#
# Requires SUPABASE_DB_URL, shared with the KAN-61/KAN-175 gates in the same
# workflow — no new secret.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./function_default_acl_diff.sh
source "$SCRIPT_DIR/function_default_acl_diff.sh"

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "FAIL: SUPABASE_DB_URL is not set." >&2
  echo "" >&2
  echo "This gate needs a direct Postgres connection string (Project Settings ->" >&2
  echo "Database -> Connection string, in the wtncuzcskpigqpmnxwws project), added" >&2
  echo "as a GitHub Actions secret named SUPABASE_DB_URL. It shares that secret with" >&2
  echo "the KAN-61/KAN-175 gates, which have been running against it since 2026-08-29" >&2
  echo "and 2026-09-10 respectively. Failing loudly here is intentional: a skipped" >&2
  echo "security gate must be visible." >&2
  exit 1
fi

command -v psql >/dev/null 2>&1 || { echo "FAIL: psql not found on PATH." >&2; exit 1; }

PROBLEMS_FILE="$(mktemp)"
trap 'rm -f "$PROBLEMS_FILE"' EXIT

echo "--- postgres: function default-privilege state (failing gate) ---"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tAc "$(function_default_acl_postgres_predicate_sql)" \
  | sed '/^[[:space:]]*$/d' > "$PROBLEMS_FILE"

echo "--- supabase_admin: function default-privilege state (reported, never failing) ---"
echo "T-045's role split reserves supabase_admin for its own ruling. KAN-189 and"
echo "KAN-194 had no authority to modify it and did not. Reported here for"
echo "visibility only -- a true value below does NOT fail this build."
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tA -F' | ' -c "$(function_default_acl_supabase_admin_report_sql)" \
  | while IFS='|' read -r named_anon global_never_revoked; do
      echo "  named anon default present:            ${named_anon// /}"
      echo "  global PUBLIC default never revoked:   ${global_never_revoked// /}"
    done
echo

function_default_acl_gate "$PROBLEMS_FILE"
