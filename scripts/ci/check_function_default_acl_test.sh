#!/usr/bin/env bash
# KAN-194 AC4 — self-test for the function default-privilege gate.
#
# THIS TEST RUNS REAL SQL AGAINST A REAL, DISPOSABLE POSTGRES, same discipline
# as KAN-175's check_anon_function_grants_test.sh. A fixture-only test would
# prove nothing about PostgreSQL's actual default-privilege semantics -- and
# KAN-189 found out the hard way, live, that a plausible-looking schema-scoped
# REVOKE does NOT close the built-in global PUBLIC default. This test exists so
# that exact mistake cannot silently ship again: every case below creates a
# genuine function and reads its EFFECTIVE privilege
# (has_function_privilege), never just the pg_default_acl row shape.
#
# NEVER runs against wtncuzcskpigqpmnxwws or any other Supabase project. The
# substrate is a throwaway container destroyed on exit.
#
# Substrate selection, same pattern as KAN175_TEST_DB_URL:
#   * CI: set KAN194_TEST_DB_URL to a service-container Postgres.
#   * Local: with no KAN194_TEST_DB_URL it starts its own docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./function_default_acl_diff.sh
source "$SCRIPT_DIR/function_default_acl_diff.sh"

CONTAINER="kan194-selftest-$$"
OWN_CONTAINER=0

cleanup() {
  [[ "$OWN_CONTAINER" -eq 1 ]] && docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "${TMP:-}"
}
trap cleanup EXIT

TMP="$(mktemp -d)"

if [[ -n "${KAN194_TEST_DB_URL:-}" ]]; then
  command -v psql >/dev/null 2>&1 || { echo "FAIL: KAN194_TEST_DB_URL set but psql not on PATH." >&2; exit 1; }
  psql_t() { psql "$KAN194_TEST_DB_URL" -v ON_ERROR_STOP=1 "$@"; }
  echo "Substrate: KAN194_TEST_DB_URL (caller-provided, assumed disposable)"
else
  command -v docker >/dev/null 2>&1 || {
    echo "FAIL: no KAN194_TEST_DB_URL and docker is not available." >&2
    echo "This test requires a real disposable Postgres -- it cannot fall back to" >&2
    echo "fixtures without ceasing to test the thing it exists to test." >&2
    exit 1; }
  echo "Substrate: starting disposable docker Postgres ($CONTAINER)"
  docker run -d --rm --name "$CONTAINER" \
    -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=kan194 postgres:16 >/dev/null
  OWN_CONTAINER=1
  psql_t() { docker exec -i "$CONTAINER" psql -U postgres -d kan194 -v ON_ERROR_STOP=1 "$@"; }
  # pg_isready alone is not sufficient: the official postgres image's
  # entrypoint accepts connections briefly during initdb, then restarts —
  # pg_isready can report ready during that transient window right before the
  # socket disappears for the real startup. Wait for an actual query to
  # succeed, not just the readiness probe.
  ready=0
  for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" pg_isready -U postgres -d kan194 >/dev/null 2>&1 \
       && docker exec "$CONTAINER" psql -U postgres -d kan194 -tAc "SELECT 1" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  [[ "$ready" -eq 1 ]] || {
    echo "FAIL: disposable Postgres did not become ready." >&2; exit 1; }
fi

fail=0
probe_n=0

# Reads the predicate into $1 (a file path), one problem per line (possibly
# empty). Written to a file rather than a bash array for portability — this
# script must also run under bash 3.2 (macOS default), which lacks mapfile.
read_problems() {
  psql_t -tAc "$(function_default_acl_postgres_predicate_sql)" | sed '/^[[:space:]]*$/d' > "$1"
}

problem_flagged() { grep -qx "$1" "$2"; }

# Creates a genuinely new disposable function under `postgres` and reports its
# EFFECTIVE anon/authenticated EXECUTE via has_function_privilege -- never the
# raw proacl text -- then drops it. This is the check that actually matters:
# it proves the catalogue-row predicate agrees with what PostgreSQL really
# does for a brand-new function, closing the exact gap KAN-189 found live
# (a schema-scoped-only revoke passing a naive catalogue check while a fresh
# function still inherited PUBLIC EXECUTE).
probe_effective_privilege() {
  probe_n=$((probe_n + 1))
  local fn="public._kan194_selftest_probe_${probe_n}"
  psql_t -q -c "CREATE FUNCTION ${fn}() RETURNS integer LANGUAGE sql AS \$\$ SELECT 1 \$\$;"
  local out
  out="$(psql_t -tA -F'|' -c "SELECT has_function_privilege('anon', '${fn}()'::regprocedure, 'EXECUTE'), has_function_privilege('authenticated', '${fn}()'::regprocedure, 'EXECUTE');")"
  psql_t -q -c "DROP FUNCTION ${fn}();"
  echo "$out"
}

# ---------------------------------------------------------------- fixture setup
#
# Simulate the ACTUAL pre-KAN-189 production shape: a schema-scoped default
# ALREADY exists (Supabase's own provisioning did this, historically, before
# KAN-189 ever ran) that names anon/authenticated/service_role alongside
# postgres. A truly virgin Postgres has no pg_default_acl row at all, which
# would test a different (and less realistic) starting condition.
echo "Seeding the pre-KAN-189 production shape..."
psql_t -q <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE supabase_admin NOLOGIN;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
SQL
echo "Fixture ready."
echo

# ============================================================ CASE 1: the RED case
echo "--- CASE 1 (must FAIL / flag both channels): pre-fix production shape ---"
read_problems "$TMP/problems_before.txt"
echo "  predicate:"; sed 's/^/    /' "$TMP/problems_before.txt"

if problem_flagged "named_anon_default" "$TMP/problems_before.txt"; then
  echo "  PASS  named_anon_default flagged, as expected pre-fix."
else
  echo "  FAIL  named_anon_default NOT flagged pre-fix -- predicate is blind to channel 1." >&2
  fail=1
fi
if problem_flagged "global_public_default" "$TMP/problems_before.txt"; then
  echo "  PASS  global_public_default flagged, as expected pre-fix (no global revoke has run)."
else
  echo "  FAIL  global_public_default NOT flagged pre-fix -- predicate is blind to channel 2." >&2
  fail=1
fi

# Effective-privilege proof: a genuinely new function really does inherit
# anon EXECUTE today, confirming the flag is not a false alarm.
before_eff="$(probe_effective_privilege)"
if [[ "$before_eff" == "t|t" ]]; then
  echo "  PASS  effective probe confirms: a fresh function really gets anon+authenticated EXECUTE pre-fix."
else
  echo "  FAIL  effective probe did not confirm pre-fix exposure (got: $before_eff)." >&2
  fail=1
fi

if function_default_acl_gate "$TMP/problems_before.txt" > "$TMP/gate1.txt" 2>&1; then
  echo "  FAIL  gate PASSED the pre-fix state -- this defeats the point." >&2
  fail=1
else
  echo "  PASS  gate correctly rejects the pre-fix state."
fi
echo

# ============================================================ CASE 2: apply the real fix
echo "--- Applying KAN-189's real fix (both migrations, verbatim shape) ---"
psql_t -q <<'SQL'
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES
  FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
SQL
echo "Applied."
echo

echo "--- CASE 2 (must PASS / flag nothing): post-fix state ---"
read_problems "$TMP/problems_after.txt"
echo "  predicate:"; sed 's/^/    /' "$TMP/problems_after.txt"

if [[ ! -s "$TMP/problems_after.txt" ]]; then
  echo "  PASS  no problems flagged post-fix."
else
  echo "  FAIL  problems still flagged post-fix:" >&2
  sed 's/^/        /' "$TMP/problems_after.txt" >&2
  fail=1
fi

after_eff="$(probe_effective_privilege)"
if [[ "$after_eff" == "f|t" ]]; then
  echo "  PASS  effective probe confirms: a fresh function now gets authenticated EXECUTE but NOT anon."
else
  echo "  FAIL  effective probe did not confirm the post-fix shape (got anon|authenticated: $after_eff)." >&2
  fail=1
fi

if function_default_acl_gate "$TMP/problems_after.txt" > "$TMP/gate2.txt" 2>&1; then
  echo "  PASS  gate correctly accepts the post-fix state."
else
  echo "  FAIL  gate rejected the post-fix state:" >&2
  sed 's/^/        /' "$TMP/gate2.txt" >&2
  fail=1
fi
echo

# ============================================================ CASE 3: regression, channel 2 only
#
# The exact scenario KAN-189 found live: channel 1 stays fixed, channel 2
# silently reopens (e.g. a future migration re-grants the global PUBLIC
# default without anyone touching the named per-schema row). A predicate that
# only checked pg_default_acl for a bare PUBLIC entry in the SCHEMA-scoped row
# would miss this entirely -- this case exists to prove ours does not.
echo "--- CASE 3 (must FAIL / flag global_public_default only): channel 2 regresses alone ---"
psql_t -q <<'SQL'
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
SQL
read_problems "$TMP/problems_regressed.txt"
echo "  predicate:"; sed 's/^/    /' "$TMP/problems_regressed.txt"

if problem_flagged "global_public_default" "$TMP/problems_regressed.txt" \
   && ! problem_flagged "named_anon_default" "$TMP/problems_regressed.txt"; then
  echo "  PASS  exactly global_public_default flagged -- channel 1 correctly still reads as fixed."
else
  echo "  FAIL  wrong problem set on a channel-2-only regression." >&2
  fail=1
fi

regressed_eff="$(probe_effective_privilege)"
if [[ "$regressed_eff" == "t|t" ]]; then
  echo "  PASS  effective probe confirms: anon EXECUTE is back on a fresh function via PUBLIC alone."
else
  echo "  FAIL  effective probe did not confirm the channel-2-only regression (got: $regressed_eff)." >&2
  fail=1
fi

# Revert channel 3's regression before the next case.
psql_t -q <<'SQL'
ALTER DEFAULT PRIVILEGES
  FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
SQL
echo

# ============================================================ CASE 4: regression, channel 1 only
echo "--- CASE 4 (must FAIL / flag named_anon_default only): channel 1 regresses alone ---"
psql_t -q <<'SQL'
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon;
SQL
read_problems "$TMP/problems_regressed2.txt"
echo "  predicate:"; sed 's/^/    /' "$TMP/problems_regressed2.txt"

if problem_flagged "named_anon_default" "$TMP/problems_regressed2.txt" \
   && ! problem_flagged "global_public_default" "$TMP/problems_regressed2.txt"; then
  echo "  PASS  exactly named_anon_default flagged -- channel 2 correctly still reads as fixed."
else
  echo "  FAIL  wrong problem set on a channel-1-only regression." >&2
  fail=1
fi
echo

# ============================================================ supabase_admin report never fails
echo "--- supabase_admin: reported, never fails (T-045 role split) ---"
admin_report="$(psql_t -tA -F'|' -c "$(function_default_acl_supabase_admin_report_sql)")"
echo "  supabase_admin report: $admin_report"
# No supabase_admin default was ever created in this fixture, so both columns
# should read false (no named default) / true (global never revoked) -- this
# just proves the report query runs and returns a shape, not a verdict.
echo "  PASS  supabase_admin report query executed (informational only, never gates)."
echo

if [[ "$fail" -eq 0 ]]; then
  echo "Self-test result: ALL cases behaved correctly."
  exit 0
else
  echo "Self-test result: FAILED -- see above." >&2
  exit 1
fi
