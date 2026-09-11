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

-- CASE J (must FLAG): KAN-175 AC7. The FIRST identity argument is properly
-- guarded; the SECOND is caller-controlled and never checked. The earlier
-- LIMIT 1 predicate selected one identity argument and tested only that one,
-- so it returned NOTHING for this function while `anon` could read any
-- profile it named. Regression case for the EXISTS form.
CREATE FUNCTION public.rpc_second_arg_unguarded(p_user_id uuid, p_profile_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_user_id <> auth.uid() THEN RAISE EXCEPTION 'not your data'; END IF;
  RETURN 'data for ' || p_profile_id::text;
END $$;
GRANT EXECUTE ON FUNCTION public.rpc_second_arg_unguarded(uuid, uuid) TO anon;

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
# CASE J must be a REAL exposure, not merely a shape the regex matches: passing the
# caller's own id as the guarded first argument satisfies the guard, and the second
# argument then returns data for a user the caller never proved they are.
psql_t -tAc "SELECT public.rpc_second_arg_unguarded('00000000-0000-0000-0000-0000000000ff','11111111-1111-1111-1111-111111111111');" \
  | grep -q '11111111-1111-1111-1111-111111111111' \
  || { echo "FAIL: CASE J did not actually leak the second argument's data, so it is not the exposure it claims to be." >&2; exit 1; }
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
must_flag "rpc_second_arg_unguarded(p_user_id uuid, p_profile_id uuid)"
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

# ============================================================ KAN-193: membership
#
# The two assertions above discard the function's output (`>/dev/null`). They
# prove the EXIT STATUS and nothing about what was printed — which is exactly
# how a gate comes to report a number nobody can reconcile. Everything below
# CAPTURES the output and asserts on its content.

echo "--- AC1: the full flagged population is emitted, on BOTH exits ---"

# If the emission is ever removed, this must REPORT a failure rather than abort
# the run on `set -u` — a crash here would take the AC2 section with it and tell
# the reader "bash error" instead of "the gate went back to printing a count".
if [[ -z "${ANON_FUNCTION_FLAGGED_BEGIN_MARKER:-}" || -z "${ANON_FUNCTION_FLAGGED_END_MARKER:-}" ]]; then
  echo "  FAIL  the diff script defines no flagged-population markers; there is nothing" >&2
  echo "        to reconstruct a membership from. The gate reports a count only." >&2
  fail=1
  ANON_FUNCTION_FLAGGED_BEGIN_MARKER="<<marker absent>>"
  ANON_FUNCTION_FLAGGED_END_MARKER="<<marker absent>>"
fi

extract_block() {
  awk -v b="$ANON_FUNCTION_FLAGGED_BEGIN_MARKER" \
      -v e="$ANON_FUNCTION_FLAGGED_END_MARKER" \
      '$0==b{f=1;next} $0==e{f=0} f' "$1"
}

anon_function_grants_diff "$TMP/flagged.txt" "$TMP/allow_full.txt" > "$TMP/out_ok.txt" 2>&1 || true
extract_block "$TMP/out_ok.txt" > "$TMP/block_ok.txt"
if diff -q <(LC_ALL=C sort -u "$TMP/flagged.txt") "$TMP/block_ok.txt" >/dev/null; then
  echo "  PASS  green run: block reconstructs the flagged population exactly."
else
  echo "  FAIL  green run: emitted block is not the flagged population." >&2
  # `|| true`: diff exits 1 on a difference, and under `set -o pipefail` that
  # would abort the run here and swallow every remaining assertion.
  { diff <(LC_ALL=C sort -u "$TMP/flagged.txt") "$TMP/block_ok.txt" || true; } | sed 's/^/        /' >&2
  fail=1
fi

anon_function_grants_diff "$TMP/flagged.txt" "$TMP/allow_short.txt" > "$TMP/out_fail.txt" 2>&1 || true
extract_block "$TMP/out_fail.txt" > "$TMP/block_fail.txt"
if diff -q <(LC_ALL=C sort -u "$TMP/flagged.txt") "$TMP/block_fail.txt" >/dev/null; then
  echo "  PASS  RED run: block reconstructs the flagged population exactly."
else
  echo "  FAIL  RED run: emitted block is not the flagged population." >&2
  { diff <(LC_ALL=C sort -u "$TMP/flagged.txt") "$TMP/block_fail.txt" || true; } | sed 's/^/        /' >&2
  fail=1
fi

# The red run is the one that regressed before. Its old output named ONLY the
# offenders, so this asserts the block is the POPULATION and not the offender
# list: a signature that is on the allowlist (never an offender) must be present.
if grep -qx "rpc_coalesce_fallback(p_profile_id uuid)" "$TMP/block_fail.txt"; then
  echo "  PASS  RED run: block includes non-offending members, so it is not the offender list."
else
  echo "  FAIL  RED run: block looks like the offender list, not the population." >&2
  fail=1
fi
echo

echo "--- AC2: a MASKED add-and-drop is nameable from two runs' outputs ---"
#
# The case the count cannot see: one signature leaves, a different one enters,
# net count unchanged, and the allowlist covers BOTH so the gate stays GREEN
# on both runs. Verified against the pre-change script before this was written:
# the two runs' outputs were byte-identical and named nothing.

cp "$TMP/allow_full.txt" "$TMP/allow_both.txt"
echo "rpc_late_arrival(p_recipient_id uuid)" >> "$TMP/allow_both.txt"

rc1=0
anon_function_grants_diff "$TMP/flagged.txt" "$TMP/allow_both.txt" > "$TMP/run1.txt" 2>&1 || rc1=$?

# Contain one member; introduce a different one. Net zero.
psql_t -q <<'SQL'
REVOKE EXECUTE ON FUNCTION public.rpc_fetch_locker_contents(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.rpc_fetch_locker_contents(uuid) FROM anon;

CREATE FUNCTION public.rpc_late_arrival(p_recipient_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN 'data for ' || p_recipient_id::text; END $$;
GRANT EXECUTE ON FUNCTION public.rpc_late_arrival(uuid) TO anon;
SQL

psql_t -tAc "$(anon_function_predicate_sql)" | sed '/^[[:space:]]*$/d' > "$TMP/flagged_after.txt"
rc2=0
anon_function_grants_diff "$TMP/flagged_after.txt" "$TMP/allow_both.txt" > "$TMP/run2.txt" 2>&1 || rc2=$?

n1="$(grep -c . "$TMP/flagged.txt")"
n2="$(grep -c . "$TMP/flagged_after.txt")"

if [[ "$rc1" -eq 0 && "$rc2" -eq 0 ]]; then
  echo "  PASS  both runs green — this is the masked case, not a failing one."
else
  echo "  FAIL  a run was red (rc1=$rc1 rc2=$rc2); that is not the masked case." >&2
  fail=1
fi

if [[ "$n1" -eq "$n2" ]]; then
  echo "  PASS  counts identical ($n1 = $n2) — a count-only report sees NOTHING here."
else
  echo "  FAIL  counts moved ($n1 -> $n2); the change is not masked, so this proves less." >&2
  fail=1
fi

extract_block "$TMP/run1.txt" > "$TMP/block1.txt"
extract_block "$TMP/run2.txt" > "$TMP/block2.txt"
# LC_ALL=C so comm's byte comparison matches the order the blocks were emitted in.
LC_ALL=C comm -23 "$TMP/block1.txt" "$TMP/block2.txt" > "$TMP/left.txt"
LC_ALL=C comm -13 "$TMP/block1.txt" "$TMP/block2.txt" > "$TMP/entered.txt"

if diff -q "$TMP/left.txt" <(echo "rpc_fetch_locker_contents(p_owner_id uuid)") >/dev/null; then
  echo "  PASS  diff names EXACTLY what left:     rpc_fetch_locker_contents(p_owner_id uuid)"
else
  echo "  FAIL  departure not named exactly; got:" >&2
  sed 's/^/        /' "$TMP/left.txt" >&2
  fail=1
fi

if diff -q "$TMP/entered.txt" <(echo "rpc_late_arrival(p_recipient_id uuid)") >/dev/null; then
  echo "  PASS  diff names EXACTLY what entered:  rpc_late_arrival(p_recipient_id uuid)"
else
  echo "  FAIL  entrant not named exactly; got:" >&2
  sed 's/^/        /' "$TMP/entered.txt" >&2
  fail=1
fi
echo

if [[ "$fail" -eq 0 ]]; then
  echo "Self-test result: ALL cases behaved correctly."
  exit 0
else
  echo "Self-test result: FAILED — see above." >&2
  exit 1
fi
