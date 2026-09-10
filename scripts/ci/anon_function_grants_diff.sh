#!/usr/bin/env bash
# KAN-175 — shared logic for the anon-executable SECURITY DEFINER function gate.
#
# Companion to anon_allowlist_diff.sh (KAN-61), which covers VIEWS. That gate's
# SQL reads `WHERE c.relkind = 'v'` and has no pg_proc, proacl or EXECUTE
# coverage anywhere — functions were a different Postgres object class and sat
# entirely outside it. This file closes that class.
#
# Extracted so the live runner (check_anon_function_grants.sh) and the self-test
# (check_anon_function_grants_test.sh) execute the IDENTICAL predicate. That is
# not tidiness: if the self-test ran its own copy of the SQL it would prove
# something about the copy and nothing about the shipped gate — which is exactly
# how KAN-61's view gate came to be self-tested by a pure text diff that never
# touched a database.

# ---------------------------------------------------------------- the predicate
#
# THE FAILING PREDICATE. A function is flagged when ALL of:
#
#   1. it is SECURITY DEFINER               — it runs as its owner, not its caller;
#   2. `anon` holds EXECUTE **effectively** — has_function_privilege(), never a
#      text match on proacl. A bare `=X/postgres` ACL entry is a grant to PUBLIC
#      which `anon` inherits, so a function whose proacl never names `anon` can
#      still be called by it. Measured on wtncuzcskpigqpmnxwws 2026-09-10:
#      60 of the 292 SECURITY DEFINER + anon-executable functions are reachable
#      ONLY through that bare PUBLIC grant and are invisible to string matching;
#   3. it takes a uuid argument whose NAME denotes a person rather than a thing;
#   4. its body never COMPARES that argument to auth.uid().
#
# On (3): the vocabulary below was derived from the live catalogue, not guessed.
# Enumerating every uuid argument name on the 292 shows the split plainly —
# p_game_id, p_post_id, p_venue_id, p_squad_id are object identifiers and carry
# no impersonation risk, while p_user_id, p_profile_id, p_me, p_actor, p_peer
# denote a person and are what an attacker substitutes.
#
# On (4), and this is the part that matters most: the test is COMPARISON, not
# mention. Of the 76 functions carrying an identity argument, 47 mention
# auth.uid() somewhere in the body and only 2 actually compare the argument to
# it. The classic bypass is
#
#     v_user_id := COALESCE(p_user_id, auth.uid());
#
# which mentions auth.uid(), reads as authentication, and is not: a caller who
# supplies any uuid wins outright, and only a caller who omits it gets their own
# identity. public.rpc_get_friends(p_user_id uuid) does exactly this today and
# returns the named user's full friend list to `anon`. A "does the body mention
# auth.uid()" test clears it. That is why this predicate demands a comparison.
#
# NOT part of the predicate, deliberately:
#
#   * A `DEFAULT auth.uid()` on the parameter is DECORATION, not mitigation. A
#     default applies only when the caller OMITS the argument and protects
#     nothing against a caller who supplies one. It also lives in
#     pg_get_function_arguments(), never in prosrc, so testing prosrc ignores it
#     automatically. public.rpc_get_friend_suggestions(p_user_id uuid DEFAULT
#     auth.uid(), p_limit integer) is the live worked example — SECURITY DEFINER,
#     anon-executable, no auth check in the body at all.
#
#   * Whether the function has a shorter same-named overload. An earlier draft of
#     this gate required an overload pair, on the rpc_potential_vibes shape where
#     a 6-arg wrapper injects auth.uid() into a 7-arg implementation. That was an
#     artifact of one case, not a property of the class:
#     rpc_get_friend_suggestions has no overload at all and is the worst instance
#     found. Requiring the pair made the gate structurally blind to it.
#
#   * Whether the function appears to have callers. It is NOT decidable from the
#     catalogue here. A call site names the FUNCTION, not the signature, so a body
#     grep attributes a call to whichever overload the reader assumes, and
#     pg_depend does not record function-to-function calls at all. A sweep of
#     2,954 bodies concluded rpc_potential_vibes/7 had zero callers; its 6-arg
#     wrapper was its only caller. An uncalled-LOOKING function may be the
#     implementation half of a live pair, so caller counts are never used to
#     suppress a finding.
#
# Known and accepted limits, stated rather than hidden:
#   * A comparison built at runtime through EXECUTE/format() is not visible to a
#     source-text test and would read as unguarded (fails loud — a false positive
#     that costs an allowlist review, not a miss).
#   * A guard that compares a DERIVED variable rather than the parameter itself
#     (v_uid := p_user_id; IF v_uid = auth.uid()) reads as unguarded. Same
#     direction: noisy, not blind.
#   * An identity argument whose name is outside the vocabulary is missed. This is
#     the one direction that fails silently, which is why the vocabulary is
#     derived from the catalogue and why AC1's census runs alongside the gate.
anon_function_predicate_sql() {
  cat <<'SQL'
WITH f AS (
  SELECT p.oid,
         p.proname,
         p.prosrc,
         pg_get_function_identity_arguments(p.oid) AS idargs,
         (SELECT a.nm
            FROM unnest(coalesce(p.proargnames, ARRAY[]::text[]),
                        p.proargtypes::oid[]) AS a(nm, ty)
           WHERE ty = 'uuid'::regtype
             AND a.nm ~ '(^|_)(me|user|users|profile|actor|peer|rater|ratee|author|owner|captain|beneficiary|creator|member|viewer|recipient|sender|follower|friend)(_|$)'
           LIMIT 1) AS id_arg
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prokind = 'f'
     AND p.prosecdef
     AND has_function_privilege('anon', p.oid, 'EXECUTE')
)
SELECT proname || '(' || idargs || ')'
  FROM f
 WHERE id_arg IS NOT NULL
   AND NOT (
         prosrc ~ ('(?i)' || id_arg || '\s*(=|<>|!=|is\s+distinct\s+from|is\s+not\s+distinct\s+from)\s*auth\.uid\(\)')
      OR prosrc ~ ('(?i)auth\.uid\(\)\s*(=|<>|!=|is\s+distinct\s+from|is\s+not\s+distinct\s+from)\s*' || id_arg)
       )
 ORDER BY 1;
SQL
}

# ------------------------------------------------------------------ the census
#
# AC1's first two bullets. REPORTED, NEVER FAILING. Both populations are far too
# large to allowlist name-by-name (303 and 292 live), and a gate whose baseline
# nobody can maintain goes green by exhaustion rather than by being satisfied.
# They are printed so a human sees the shape of the estate move over time.
anon_function_census_sql() {
  cat <<'SQL'
SELECT
  count(*) FILTER (WHERE p.prosecdef) AS security_definer,
  count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')) AS anon_executable,
  count(*) FILTER (WHERE p.prosecdef
                     AND has_function_privilege('anon', p.oid, 'EXECUTE')) AS both,
  count(*) FILTER (WHERE p.prosecdef
                     AND has_function_privilege('anon', p.oid, 'EXECUTE')
                     AND (p.proacl IS NULL
                          OR array_to_string(p.proacl, ',') NOT LIKE '%anon=%')) AS both_via_public_grant_only
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prokind = 'f';
SQL
}

# -------------------------------------------------------------------- the diff
#
# Usage: anon_function_grants_diff <live_signatures_file> <allowlist_file>
#
# Exits 0 if every flagged signature is on the allowlist. Exits 1 and names the
# offenders otherwise. Deliberately one-directional, matching KAN-61: a signature
# that leaves the flagged set (someone fixed it) is not a build failure, it is
# just a stale allowlist entry to tidy.
anon_function_grants_diff() {
  local live_file="$1"
  local allowlist_file="$2"

  local extra
  extra="$(comm -23 <(sort -u "$live_file") <(sort -u "$allowlist_file"))"

  if [[ -n "$extra" ]]; then
    echo "FAIL: anon-executable SECURITY DEFINER function(s) with an unguarded caller-supplied" >&2
    echo "identity argument are not on the docs/SCHEMA.md §2g allowlist:" >&2
    echo "$extra" | sed 's/^/  - /' >&2
    echo "" >&2
    echo "Each of these lets an unauthenticated caller name WHICH USER to act as, while the" >&2
    echo "function runs with its owner's privileges. Either fix it (compare the argument to" >&2
    echo "auth.uid(), drop the argument, or REVOKE EXECUTE FROM PUBLIC and anon), or — if it" >&2
    echo "is genuinely intended — add it to §2g with a written justification, which is the" >&2
    echo "reviewable diff this gate exists to force." >&2
    return 1
  fi

  echo "OK: all $(grep -c . "$live_file" | tr -d ' ') flagged function signature(s) are on the allowlist."
  return 0
}

# Allow sourcing (functions only) or direct execution (diff with argv).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 2 ]]; then
    echo "usage: $0 <live_signatures_file> <allowlist_file>" >&2
    exit 2
  fi
  anon_function_grants_diff "$1" "$2"
fi
