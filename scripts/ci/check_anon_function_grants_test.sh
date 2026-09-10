#!/usr/bin/env bash
# KAN-175 AC3/AC4 — self-test for the anon-executable SECURITY DEFINER gate.
#
# THIS TEST RUNS REAL SQL AGAINST A REAL, DISPOSABLE POSTGRES. That is the whole
# point of it, and it is the one thing KAN-61's view self-test does not do.
#
# KAN-61's check_anon_allowlist_test.sh is a pure text diff over two fixture
# files. It proves the diff logic rejects an unlisted name and never executes a
# single line of the catalogue SQL that decides WHICH names reach the diff. Here
# the detection IS the SQL predicate — a fixture-only test would prove the
# plumbing while leaving the detector itself unexercised, reproducing the exact
# blind spot this ticket exists to close. So every case below creates a genuine
# function in a genuine database and asserts on what the shipped predicate
# actually returns.
#
# NEVER runs against wtncuzcskpigqpmnxwws or any other Supabase project. The
# substrate is a throwaway container that is destroyed on exit.
#
# Substrate selection:
#   * CI: set KAN175_TEST_DB_URL to a service-container Postgres and this script
#     uses it directly (psql must be on PATH).
#   * Local: with no KAN175_TEST_DB_URL it starts its own docker container and
#     runs psql INSIDE it, so no local postgres-client install is needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./anon_function_grants_diff.sh
source "$SCRIPT_DIR/anon_function_grants_diff.sh"

CONTAINER="kan175-selftest-$$"
OWN_CONTAINER=0

cleanup() {
  [[ "$OWN_CONTAINER" -eq 1 ]] && docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "${TMP:-}"
}
trap cleanup EXIT

TMP="$(mktemp -d)"

if [[ -n "${KAN175_TEST_DB_URL:-}" ]]; then
  command -v psql >/dev/null 2>&1 || { echo "FAIL: KAN175_TEST_DB_URL set but psql not on PATH." >&2; exit 1; }
  psql_t() { psql "$KAN175_TEST_DB_URL" -v ON_ERROR_STOP=1 "$@"; }
  echo "Substrate: KAN175_TEST_DB_URL (caller-provided, assumed disposable)"
else
  command -v docker >/dev/null 2>&1 || {
    echo "FAIL: no KAN175_TEST_DB_URL and docker is not available." >&2
    echo "This test requires a real disposable Postgres — it cannot fall back to" >&2
    echo "fixtures without ceasing to test the thing it exists to test." >&2
    exit 1; }
  echo "Substrate: starting disposable docker Postgres ($CONTAINER)"
  docker run -d --rm --name "$CONTAINER" \
    -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=kan175 postgres:16 >/dev/null
  OWN_CONTAINER=1
  psql_t() { docker exec -i "$CONTAINER" psql -U postgres -d kan175 -v ON_ERROR_STOP=1 "$@"; }
  for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" pg_isready -U postgres -d kan175 >/dev/null 2>&1; then break; fi
    sleep 1
  done
  docker exec "$CONTAINER" pg_isready -U postgres -d kan175 >/dev/null 2>&1 || {
    echo "FAIL: disposable Postgres did not become ready." >&2; exit 1; }
fi

# ---------------------------------------------------------------- the fixture
#
# A minimal stand-in for the Supabase shape the predicate assumes: an `anon`
# role and an auth.uid(). Nothing else from Supabase is needed, because the
# predicate reads only pg_proc, pg_namespace and has_function_privilege.
#
# Every function below is NEWLY WRITTEN FOR THIS TEST. None is named
# rpc_potential_vibes, and none shares a parameter name with it — AC4 requires
# the gate to catch functions nobody has written yet, so testing against the
# known instance would prove nothing about the class.
echo "Seeding fabricated cases..."
psql_t -q <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE SCHEMA auth;
-- Returns a fixed uuid rather than NULL on purpose. With a NULL auth.uid(),
-- `p_user_id <> auth.uid()` evaluates to NULL, the IF is not taken, and CASE F's
-- guard would silently never fire — leaving the false-positive control passing
-- for the wrong reason.
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
  AS $$ SELECT '00000000-0000-0000-0000-0000000000ff'::uuid $$;

-- CASE A (must FLAG): the plain offence. Different name and different parameter
-- name from any function in the live database.
CREATE FUNCTION public.rpc_fetch_locker_contents(p_owner_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN 'secrets belonging to ' || p_owner_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_fetch_locker_contents(uuid) TO anon;

-- CASE B (must FLAG): AC4's second fabricated case. Different name AND a
-- different identity vocabulary word again (p_member_ref, not p_owner_id).
CREATE FUNCTION public.rpc_export_member_dossier(p_member_ref uuid, p_format text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN 'dossier:' || p_member_ref::text || ':' || p_format; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_export_member_dossier(uuid, text) TO anon;

-- CASE C (must FLAG): reachable ONLY through a bare PUBLIC grant. Its proacl
-- never contains the string "anon", so a text match on proacl misses it while
-- has_function_privilege resolves it correctly.
CREATE FUNCTION public.rpc_public_grant_only(p_viewer_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN p_viewer_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_public_grant_only(uuid) TO PUBLIC;

-- CASE D (must FLAG): DEFAULT auth.uid() is decoration. The default applies only
-- when the caller omits the argument and stops nobody who supplies one.
CREATE FUNCTION public.rpc_decorated_default(p_user_id uuid DEFAULT auth.uid())
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN 'data for ' || p_user_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_decorated_default(uuid) TO anon;

-- CASE E (must FLAG): mentions auth.uid() but never COMPARES it — the COALESCE
-- fallback. Reads as authentication; is not.
CREATE FUNCTION public.rpc_coalesce_fallback(p_profile_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v uuid;
BEGIN v := COALESCE(p_profile_id, auth.uid()); RETURN v::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_coalesce_fallback(uuid) TO anon;

-- CASE F (must NOT flag): properly guarded. Compares the argument to auth.uid().
CREATE FUNCTION public.rpc_properly_guarded(p_user_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_user_id <> auth.uid() THEN RAISE EXCEPTION 'not your data'; END IF;
  RETURN 'ok';
END $$;
GRANT EXECUTE ON FUNCTION public.rpc_properly_guarded(uuid) TO anon;

-- CASE G (must NOT flag): object identifier, not an identity. p_game_id names a
-- thing. Flagging these would make the gate unusable — 18 live functions take
-- p_game_id.
CREATE FUNCTION public.rpc_object_id_only(p_game_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN p_game_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_object_id_only(uuid) TO anon;

-- CASE H (must NOT flag): identity argument, but SECURITY INVOKER. It runs as
-- the caller, so RLS still applies and there is no privilege to borrow.
CREATE FUNCTION public.rpc_invoker_identity(p_user_id uuid)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN RETURN p_user_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_invoker_identity(uuid) TO anon;

-- CASE I (must NOT flag): definer with an identity argument, but anon cannot
-- execute it. Revoking PUBLIC is required as well as not granting anon —
-- functions are created with EXECUTE to PUBLIC by default.
CREATE FUNCTION public.rpc_definer_not_anon(p_user_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN p_user_id::text; END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_definer_not_anon(uuid) FROM PUBLIC;
SQL

# Sanity: the fabricated functions must actually be callable, or a "not flagged"
# result could mean the object never existed rather than that it passed.
psql_t -tAc "SELECT public.rpc_fetch_locker_contents('00000000-0000-0000-0000-000000000001');" >/dev/null
psql_t -tAc "SELECT public.rpc_properly_guarded('00000000-0000-0000-0000-000000000001');" >/dev/null 2>&1 \
  && { echo "FAIL: the guarded fixture should have raised, so it is not exercising its guard." >&2; exit 1; } \
  || true
echo "Fixtures seeded and confirmed executable."
echo

psql_t -tAc "$(anon_function_predicate_sql)" | sed '/^[[:space:]]*$/d' > "$TMP/flagged.txt"

echo "--- Predicate output ---"
sed 's/^/  /' "$TMP/flagged.txt"
echo

fail=0
must_flag()    { grep -qx "$1" "$TMP/flagged.txt" && echo "  PASS  flagged: $1" || { echo "  FAIL  NOT flagged (should be): $1" >&2; fail=1; }; }
must_not_flag(){ grep -qx "$1" "$TMP/flagged.txt" && { echo "  FAIL  flagged (should not be): $1" >&2; fail=1; } || echo "  PASS  not flagged: $1"; }

echo "--- Cases that MUST be caught ---"
must_flag "rpc_fetch_locker_contents(p_owner_id uuid)"
must_flag "rpc_export_member_dossier(p_member_ref uuid, p_format text)"
must_flag "rpc_public_grant_only(p_viewer_id uuid)"
must_flag "rpc_decorated_default(p_user_id uuid)"
must_flag "rpc_coalesce_fallback(p_profile_id uuid)"
echo
echo "--- Cases that MUST NOT be caught (false-positive control) ---"
must_not_flag "rpc_properly_guarded(p_user_id uuid)"
must_not_flag "rpc_object_id_only(p_game_id uuid)"
must_not_flag "rpc_invoker_identity(p_user_id uuid)"
must_not_flag "rpc_definer_not_anon(p_user_id uuid)"
echo

# ------------------------------------------------------- the diff, both directions
echo "--- Diff: a complete allowlist must PASS ---"
cp "$TMP/flagged.txt" "$TMP/allow_full.txt"
if anon_function_grants_diff "$TMP/flagged.txt" "$TMP/allow_full.txt" >/dev/null; then
  echo "  PASS: gate allowed a fully-listed set."
else
  echo "  FAIL: gate rejected a set identical to its allowlist." >&2; fail=1
fi
echo

echo "--- Diff: an allowlist missing one entry must FAIL ---"
grep -vx "rpc_export_member_dossier(p_member_ref uuid, p_format text)" "$TMP/flagged.txt" > "$TMP/allow_short.txt"
if anon_function_grants_diff "$TMP/flagged.txt" "$TMP/allow_short.txt" >/dev/null 2>&1; then
  echo "  FAIL: gate passed a live set containing an unlisted function. This defeats the point." >&2
  fail=1
else
  echo "  PASS: gate correctly rejected the unlisted function."
fi
echo

if [[ "$fail" -eq 0 ]]; then
  echo "Self-test result: ALL cases behaved correctly."
  exit 0
else
  echo "Self-test result: FAILED — see above." >&2
  exit 1
fi
