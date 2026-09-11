#!/usr/bin/env bash
# KAN-61 — CI gate for docs/DECISIONS.md T-002.
#
# Queries pg_class for every view in `public` that `anon` can SELECT and that
# lacks `security_invoker`, then fails the build if any such view is not on
# the reviewed allowlist in docs/SCHEMA.md §2f.
#
# Requires SUPABASE_DB_URL: a direct Postgres connection string (not the
# PostgREST/anon-key path) with enough privilege to read pg_catalog — any
# authenticated role works, this never needs service_role or superuser.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_MD="$REPO_ROOT/docs/SCHEMA.md"

# shellcheck source=./anon_allowlist_diff.sh
source "$SCRIPT_DIR/anon_allowlist_diff.sh"

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "FAIL: SUPABASE_DB_URL is not set." >&2
  echo "" >&2
  echo "This gate needs a direct Postgres connection string (Project Settings ->" >&2
  echo "Database -> Connection string, in the wtncuzcskpigqpmnxwws project), added" >&2
  echo "as a GitHub Actions secret named SUPABASE_DB_URL. It is not yet provisioned" >&2
  echo "as of KAN-61 landing -- ask cto/PO to add it. This is a real gap, not a" >&2
  echo "misconfiguration in this script: failing loudly here is intentional so the" >&2
  echo "missing gate is visible instead of silently skipped." >&2
  exit 1
fi

command -v psql >/dev/null 2>&1 || { echo "FAIL: psql not found on PATH." >&2; exit 1; }

LIVE_VIEWS_FILE="$(mktemp)"
ALLOWLIST_FILE="$(mktemp)"
trap 'rm -f "$LIVE_VIEWS_FILE" "$ALLOWLIST_FILE"' EXIT

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tAc "
  SELECT c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind = 'v'
    AND n.nspname = 'public'
    AND has_table_privilege('anon', c.oid, 'SELECT')
    AND NOT COALESCE(
      (SELECT option_value::boolean
       FROM pg_options_to_table(c.reloptions)
       WHERE option_name = 'security_invoker'),
      false
    )
  ORDER BY 1;
" | sed '/^\s*$/d' > "$LIVE_VIEWS_FILE"

awk '/<!-- ANON_ALLOWLIST_START -->/{flag=1; next} /<!-- ANON_ALLOWLIST_END -->/{flag=0} flag' \
  "$SCHEMA_MD" | sed '/^\s*$/d' > "$ALLOWLIST_FILE"

if [[ ! -s "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: could not find a non-empty allowlist between the ANON_ALLOWLIST_START/END" >&2
  echo "markers in docs/SCHEMA.md §2f. The markers may have been moved or removed." >&2
  exit 1
fi

anon_allowlist_diff "$LIVE_VIEWS_FILE" "$ALLOWLIST_FILE"
