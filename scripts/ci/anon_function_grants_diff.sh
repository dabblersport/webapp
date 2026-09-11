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
#      still be called by it. Measured on wtncuzcskpigqpmnxwws 2026-09-10: of the
#      SECURITY DEFINER + anon-executable population (292 at the time of that
#      reading, 290 later the same day as functions were contained), 60 were
#      reachable ONLY through that bare PUBLIC grant and invisible to a string
#      match. The ratio is the point, not the integer — read the printed census;
#   3. it takes a uuid argument whose NAME denotes a person rather than a thing;
#   4. its body never COMPARES **that** argument to auth.uid() — and it is flagged
#      if ANY ONE of its identity arguments is unguarded, not merely the first.
#
# On (4)'s "ANY ONE", added 2026-09-10 (KAN-175 AC7, found by backend-7 and
# reproduced by backend-5 in peer review): an earlier draft selected a single
# identity argument with `LIMIT 1` and tested only that one. A function which
# guards its FIRST identity argument and leaves a SECOND one caller-controlled
# was therefore cleared outright. That is not hypothetical — the fabricated
# case in the self-test,
#
#     rpc_second_arg_unguarded(p_user_id uuid, p_profile_id uuid)
#       IF p_user_id <> auth.uid() THEN RAISE ...          -- first arg guarded
#       RETURN 'data for ' || p_profile_id                 -- second NEVER checked
#
# is a genuine anon-reachable read of another user's data, and the LIMIT 1 form
# returned NOTHING for it. Four live functions carry two identity arguments
# (can_view_post, is_blocked, rpc_rate_user, rpc_squad_create); all four happen
# to be flagged on their first argument anyway, so there was no live miss — but
# that was luck, not coverage, and luck is what this ticket exists to remove.
# The EXISTS form below is non-regressive: measured against wtncuzcskpigqpmnxwws
# on 2026-09-10 it returns the same population of 72 as the LIMIT 1 form.
#
# On (3): the vocabulary below was derived from the live catalogue, not guessed.
# Enumerating every uuid argument name across the definer + anon-executable
# population (292 at the 2026-09-10 reading) shows the split plainly —
# p_game_id, p_post_id, p_venue_id, p_squad_id are object identifiers and carry
# no impersonation risk, while p_user_id, p_profile_id, p_me, p_actor, p_peer
# denote a person and are what an attacker substitutes.
#
# On (4), and this is the part that matters most: the test is COMPARISON, not
# mention. Measured 2026-09-10: of the functions carrying an identity argument
# (76 at the first reading that day, 74 later once two were contained), 47
# mentioned auth.uid() somewhere in the body and only 2 actually compared an
# argument to it. The 47-vs-2 gap is the finding; the totals drift and the two
# figures above were taken at slightly different moments, so treat them as
# orientation and re-derive from the catalogue if a number has to be exact.
# The classic bypass is
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
         p.proargnames,
         p.proargtypes,
         pg_get_function_identity_arguments(p.oid) AS idargs
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prokind = 'f'
     AND p.prosecdef
     AND has_function_privilege('anon', p.oid, 'EXECUTE')
)
SELECT proname || '(' || idargs || ')'
  FROM f
 WHERE EXISTS (
         SELECT 1
           FROM unnest(coalesce(f.proargnames, ARRAY[]::text[]),
                       f.proargtypes::oid[]) AS a(nm, ty)
          WHERE ty = 'uuid'::regtype
            AND a.nm ~ '(^|_)(me|user|users|profile|actor|peer|rater|ratee|author|owner|captain|beneficiary|creator|member|viewer|recipient|sender|follower|friend)(_|$)'
            AND NOT (
                  f.prosrc ~ ('(?i)' || a.nm || '\s*(=|<>|!=|is\s+distinct\s+from|is\s+not\s+distinct\s+from)\s*auth\.uid\(\)')
               OR f.prosrc ~ ('(?i)auth\.uid\(\)\s*(=|<>|!=|is\s+distinct\s+from|is\s+not\s+distinct\s+from)\s*' || a.nm)
                )
       )
 ORDER BY 1;
SQL
}

# ------------------------------------------------------------------ the census
#
# AC1's first two bullets. REPORTED, NEVER FAILING. Both populations are far too
# large to allowlist name-by-name — measured 2026-09-10, SECURITY DEFINER was 303
# and effectively anon-executable was 1,746 of 1,761 public functions — and a gate
# whose baseline nobody can maintain goes green by exhaustion rather than by being
# satisfied. They are printed so a human sees the shape of the estate move.
#
# THE FIGURE ABOVE WAS WRONG UNTIL 2026-09-10 (KAN-175 AC6). This comment read
# "(303 and 292 live)", which pairs the SECURITY DEFINER count with `both` and
# presents it as the anon-executable population — understating that population
# roughly SIX-FOLD. The SQL below always computed all four correctly and prints
# them under their own labels; only the prose was wrong. That is the whole trap
# AC6 exists to close, and it appeared in three separate places in this repo,
# including here, three lines above the correct query.
#
# So: PREFER THE PRINTED CENSUS TO ANY NUMBER WRITTEN IN A COMMENT. Counts drift
# as functions are contained; the query does not. Numbers quoted in this file are
# dated snapshots for orientation, never the authority.
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
#
# ---------------------------------------------------- membership, not just a count
#
# KAN-193. This function used to report its result as a bare count — "OK: all 72
# flagged function signature(s) are on the allowlist" — and record nowhere WHICH
# signatures made up that 72. The CI log had the number and never the membership.
#
# That is not a cosmetic gap. A function newly becoming anon-reachable while a
# different one is contained, in the same window, moves the count by zero. Both
# runs print the identical line, both are green, and the change is invisible.
# Reproduced for real on a disposable Postgres before this was written: one
# signature out, a different one in, allowlist covering both, and the two runs'
# outputs were BYTE-IDENTICAL. A shrinking or churning flagged set is the one
# direction a count cannot distinguish from the predicate silently breaking.
#
# So the full population is emitted between markers, LC_ALL=C sorted, one
# signature per line, ON BOTH EXITS — the failing path too. A red run needs this
# more than a green one, not less: the failure branch below names only the
# OFFENDERS, and without the population they were drawn from, whoever is paged by
# a red gate cannot tell a real regression from a shifted baseline.
#
# The sort is LC_ALL=C so the block is byte-stable across machines and database
# collations; two runs' blocks are then directly comparable with comm/diff, which
# is what makes the add-and-drop above nameable rather than merely countable.
# The count is derived FROM the emitted block rather than counted separately, so
# the number and the membership can never disagree — a count that cannot be
# reconciled against its own membership is the whole defect this closes.
#
# The markers are load-bearing. An unmarked or differently-ordered list can print
# without being diffable, which would satisfy "the script prints a list" while
# leaving the masked case exactly as invisible as it was.
#
# ON STREAMS, so nobody "tidies" this later: the block always goes to STDOUT, on
# both exits, while the failure message goes to stderr. Do not make the block's
# stream depend on the exit status — a consumer extracting it would then have to
# know how the run ended before it could find the block, which is backwards.
# The failure message therefore names stdout explicitly rather than saying the
# block is "above": the two streams are separate pipes in CI and their relative
# order is not guaranteed under buffering, so a positional claim would be a
# statement this code cannot honour. (Raised by backend-6 in KAN-193 peer review.)
ANON_FUNCTION_FLAGGED_BEGIN_MARKER="--- ANON_FUNCTION_FLAGGED_BEGIN ---"
ANON_FUNCTION_FLAGGED_END_MARKER="--- ANON_FUNCTION_FLAGGED_END ---"

anon_function_grants_diff() {
  local live_file="$1"
  local allowlist_file="$2"

  # AC1: the full flagged population, on every run. Emitted BEFORE the pass/fail
  # branch below precisely so that neither outcome can skip it.
  local sorted_flagged flagged_count
  sorted_flagged="$(LC_ALL=C sort -u "$live_file" | sed '/^[[:space:]]*$/d')"
  flagged_count="$(printf '%s\n' "$sorted_flagged" | grep -c . || true)"

  echo "$ANON_FUNCTION_FLAGGED_BEGIN_MARKER"
  if [[ -n "$sorted_flagged" ]]; then
    printf '%s\n' "$sorted_flagged"
  fi
  echo "$ANON_FUNCTION_FLAGGED_END_MARKER"

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
    echo "" >&2
    echo "The offender(s) above are a SUBSET of the flagged population, which is $flagged_count" >&2
    echo "signature(s) and is printed in full ON STDOUT, between the ANON_FUNCTION_FLAGGED" >&2
    echo "markers. Diff that block against a previous run's to tell a real regression from a" >&2
    echo "baseline that moved underneath you." >&2
    return 1
  fi

  echo "OK: all $flagged_count flagged function signature(s) are on the allowlist."
  echo "    (Full membership is between the ANON_FUNCTION_FLAGGED markers above, LC_ALL=C"
  echo "     sorted. Diff two runs' blocks to name what entered and left — the count alone"
  echo "     cannot: one signature out and a different one in moves it by zero.)"
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
