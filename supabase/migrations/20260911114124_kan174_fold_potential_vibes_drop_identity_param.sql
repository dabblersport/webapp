-- ############################################################################
-- ## APPLIED 2026-09-11 via apply_migration. Ledger version 20260911114124.   ##
-- ## Renamed from the held file kan174_fold_potential_vibes_drop_identity     ##
-- ## _param.sql to match the returned ledger version, per the kan186_profile  ##
-- ## _fk_cascade_part_a.sql precedent. A prior attempt the same day by        ##
-- ## backend-2 was DENIED by the harness permission classifier (not a        ##
-- ## governance gate); production was re-read and confirmed unchanged after  ##
-- ## that denial. All in-migration post-conditions (5a-5i) passed on apply;  ##
-- ## re-verified independently post-apply against the live catalogue.        ##
-- ############################################################################
--
-- KAN-174 — rpc_potential_vibes: fold the 7-arg implementation into the 6-arg
-- wrapper and delete the caller-supplied identity parameter.
--
-- Ruling: DECISIONS.md T-070 (cto, 2026-09-10), Decisions 1-4.
-- Standing rule it enforces: CONVENTIONS.md §6d — a SECURITY DEFINER function must
-- never accept the caller's identity as a parameter. Third form of this defect in
-- the corpus, after T-040's definer blocklist oracle and T-064's list_active_usernames.
--
-- Authored from pg_get_functiondef() on the LIVE catalogue (oids 95102 / 95117),
-- never from a migration file (T-058) — attributes are emitted verbatim, so a stale
-- SECURITY DEFINER or search_path cannot be reproduced by accident.
--
-- ============================================================================
-- ORDER IS LOAD-BEARING
-- ============================================================================
-- CREATE OR REPLACE the 6-arg FIRST, DROP the 7-arg SECOND. Reversed, the wrapper
-- points at a signature that no longer exists. Both statements run in one
-- transaction, so no such window exists at all.
--
-- This is a FOLD, not an edit. "Remove p_me from the 7-arg" is not an available
-- operation: the result of removing it IS the 6-arg signature, which already
-- exists. The two objects have to be collapsed.
--
-- ============================================================================
-- WHAT IS DELIBERATELY *NOT* DONE — T-070 Decision 2. Read before "hardening" this.
-- ============================================================================
-- * SECURITY DEFINER IS KEPT. public.v_sport_profiles_with_user grants anon=xtm and
--   authenticated=xtm — no `r`. Measured on wtncuzcskpigqpmnxwws 2026-09-11:
--   has_table_privilege('anon', …, 'SELECT') and the authenticated equivalent are
--   both FALSE. An invoker function here returns nothing to anyone. The definer
--   boundary is what makes a controlled projection possible at all, and it is
--   earned by the fixed return signature (same pattern as T-044), not by the name.
--
-- * anon's EXECUTE GRANT IS KEPT. After the fold auth.uid() is NULL for anon,
--   `spw.user_id <> NULL` is NULL for every row, and anon gets 0 rows — the honest
--   answer for a logged-out caller, and exactly what it got before this migration.
--   Revoking would turn 0 rows into 42501 raised through v_potential_vibes_default,
--   which anon DOES hold `r` on and which is on the anon view allowlist
--   (SCHEMA.md §2f) and gated by anon-allowlist-check.yml. A live break in exchange
--   for nothing. KAN-174 AC1 asked for this revoke as CONTAINMENT; T-070 ruled after
--   the filing that the containment that matters is the 7-arg's, which already holds
--   and which this migration makes permanent by removing the object entirely.
--   CREATE OR REPLACE preserves proacl, so the grant survives without being restated.
--   Restating it would be worse: it would make the grant look like a decision taken
--   here rather than one inherited and deliberately left alone.
--
-- * §2g's allowlist block in docs/SCHEMA.md (lines 718-793) IS NOT TOUCHED, even
--   though dropping rpc_potential_vibes_debug leaves its signature listed there.
--   The gate's diff is one-directional by design (anon_function_grants_diff.sh:
--   "a signature that leaves the flagged set … is not a build failure"), so this
--   cannot redden CI. AC6 excludes that block explicitly.
--
-- NO EXPLICIT BEGIN/COMMIT. apply_migration runs the whole file as one
-- transaction; an inner BEGIN would only raise a nested-transaction WARNING and
-- an inner COMMIT would close the outer one early, which is exactly the window
-- the "order is load-bearing" note above exists to prevent.
--
-- ============================================================================
-- EVERY POST-CONDITION BELOW WAS DEMONSTRATED FAILING BEFORE IT COUNTED AS
-- PASSING, against the live pre-migration catalogue on 2026-09-11:
--   5b  "the 7-arg overload still exists"                            — raised
--   5c  "rpc_potential_vibes_debug still exists"                     — raised
--   5d  "an rpc_potential_vibes* function still takes a uuid argument" — raised
--   5e  "expected exactly 1 …, found 3"                              — raised
--   5h  "AC3 comment is missing from the 6-arg"                      — raised
--   5i  "p_limit clamp did not hold — 140 rows for p_limit=999999"   — raised
-- 5f (body free of p_me) does NOT discriminate pre-migration and is stated as
-- such: the 6-arg body never contained p_me, the 7-arg's did. It guards the fold
-- against re-importing the parameter, so its discriminating case is a botched
-- fold, not the pre-migration catalogue. Verified against the 7-arg's prosrc,
-- where the identical predicate does match.
--
-- THE TWO BEHAVIOURAL ASSERTIONS WERE DEMONSTRATED AGAINST A DELIBERATELY BROKEN
-- FOLD, in a rolled-back transaction on 2026-09-11 — same body, same clamp, with
-- the self-exclusion predicate deleted. Both caught it:
--   self-exclusion → "self-exclusion broken - 1 own rows returned for sport padel"
--                    (subject owns 1 of padel's 27 rows; the clamp of 50 cannot
--                     hide the effect, which is why the sport is chosen this way)
--   anon shape     → "no caller identity returned 50 rows, expected 0"
--                    — i.e. the broken fold reproduces the KAN-174 incident, and
--                      the assertion is what stops it committing.
-- Production was re-read after that rollback and confirmed unchanged (prosrc 183
-- bytes, no clamp, original proacl) before this migration was applied.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. THE FOLD. The 7-arg's body, with p_me replaced by auth.uid() at the one
--    site that used it, and p_limit clamped (T-070 Decision 3).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_potential_vibes(
  p_sport     text,
  p_as_role   text,
  p_lat       double precision,
  p_lng       double precision,
  p_radius_km numeric,
  p_limit     integer
)
 RETURNS TABLE(user_id uuid, role text, sport_key text, username text, display_name text, score numeric, reasons jsonb)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    spw.user_id,
    spw.profile_type         AS role,
    spw.sport_key,
    spw.profile_username     AS username,
    spw.profile_display_name AS display_name,
    1.0::numeric             AS score,   -- stub score for now
    jsonb_build_object(
      'source', 'stub',
      'reason', 'v_sport_profiles_with_user'
    )                         AS reasons
  FROM public.v_sport_profiles_with_user spw
  WHERE
    -- filter by sport if provided
    (p_sport IS NULL OR spw.sport_key = p_sport)
    -- SELF-EXCLUSION PRODUCT FILTER, NOT AN ACCESS CONTROL. See the COMMENT ON
    -- FUNCTION below. Identity is derived here and cannot be supplied by the
    -- caller; for an unauthenticated caller auth.uid() is NULL, the comparison is
    -- NULL for every row, and the function returns 0 rows.
    AND spw.user_id <> auth.uid()
    -- later: role filter if you want it
    -- AND (p_as_role IS NULL OR spw.profile_type = p_as_role)
  ORDER BY score DESC
  -- Anti-bulk clamp (T-070 Decision 3). 50 is a DESIGN CEILING, not a measurement:
  -- there is no client caller to calibrate against, and v_potential_vibes_default
  -- passes 20. It is a real control only because this function has NO OFFSET
  -- PARAMETER — p_limit is the sole lever for getting more than one page.
  -- IF PAGING IS EVER ADDED, THIS CLAMP STOPS BEING A CONTROL AND MUST BE
  -- REVISITED IN THE SAME CHANGE.
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
$function$;

-- ---------------------------------------------------------------------------
-- 2. DROP the 7-arg. Its identity parameter is the whole vulnerability.
--    No grants to restore: proacl was {postgres=X,service_role=X} — PUBLIC, anon
--    and authenticated all absent — and pg_depend records no dependent object.
--
--    NOT "rename to a private _-prefixed helper and revoke EXECUTE" (T-070
--    rejected it): that leaves a SECURITY DEFINER function whose safety is a
--    grant, and the grant is what failed. Remove the parameter and the class of
--    defect is gone; revoke the grant and it is merely dormant, one GRANT EXECUTE
--    in a future migration away from returning.
-- ---------------------------------------------------------------------------
DROP FUNCTION public.rpc_potential_vibes(text, text, double precision, double precision, numeric, integer, uuid);

-- ---------------------------------------------------------------------------
-- 3. DROP rpc_potential_vibes_debug — T-070 Decision 4. DROPPED, NOT REVOKED.
--
--    ITS INERTNESS IS LUCK, NOT CONTAINMENT, AND THE PROBE PROVES WHICH. As anon
--    it does NOT raise 42501. Re-measured 2026-09-11, immediately before this
--    migration: it raises
--        42P01  relation "public.v_vibes_candidates" does not exist
--    — it PASSES the permission check on a bare PUBLIC `=X` entry and dies two
--    statements later on a missing relation. to_regclass('public.v_vibes_candidates')
--    is NULL, confirmed in the same run.
--
--    It is SECURITY DEFINER, takes caller-supplied p_me, and is the RICHER body —
--    3,599 bytes against 725 — exposing skill_level, composite_score reputation,
--    mutual counts and geo-derived locality. The day anyone creates
--    v_vibes_candidates to finish that work, this incident reproduces with a worse
--    payload and no new grant required. Its search_path is 'public' alone, missing
--    pg_temp unlike every other function in the family — a second, independent
--    reason not to keep it alive. The algorithm is preserved in T-070 and in git;
--    the executable object is not worth its blast radius.
-- ---------------------------------------------------------------------------
DROP FUNCTION public.rpc_potential_vibes_debug(uuid, text, text, double precision, double precision, numeric, integer);

-- ---------------------------------------------------------------------------
-- 4. AC3 — name the predicate's role, and name where the access control actually
--    lives. Carried on the object itself so it travels with pg_get_functiondef
--    and cannot drift from the body the way a doc row can.
-- ---------------------------------------------------------------------------
COMMENT ON FUNCTION public.rpc_potential_vibes(text, text, double precision, double precision, numeric, integer) IS
$c$KAN-174 / T-070. `spw.user_id <> auth.uid()` is a SELF-EXCLUSION PRODUCT FILTER
("don't recommend yourself"), NOT an access-control gate. Do not read it as one.

The access control is three things, none of them that predicate:
 1. SECURITY DEFINER over public.v_sport_profiles_with_user, which grants anon=xtm
    and authenticated=xtm and NO `r` — neither client role can read it directly
    (42501). The definer boundary is earned by this function's fixed return
    signature, which projects exactly user_id, profile_type, sport_key,
    profile_username, profile_display_name and a stub score.
 2. Identity is DERIVED, never supplied. There is no p_me parameter and there must
    never be one (CONVENTIONS.md §6d). The 7-arg overload that took p_me was the
    KAN-174 incident: it returned 147 rows / 137 distinct users to anon, and read
    as safe only because `spw.user_id <> NULL` is NULL for every row.
 3. For an unauthenticated caller auth.uid() is NULL, so this returns 0 rows rather
    than raising. anon's EXECUTE grant is retained deliberately (T-070 Decision 2)
    so v_potential_vibes_default keeps returning 0 rows instead of 42501.

p_limit is clamped to [1,50] as an ANTI-BULK control, and MUST NOT be described as
an access control. It is a real control only because there is no offset parameter.
Add paging and the clamp stops being one — revisit it in that same change.$c$;

-- ---------------------------------------------------------------------------
-- 5. POST-CONDITIONS. Every one is asserted on to_regprocedure()/oid, NEVER on
--    pg_get_function_identity_arguments() text: that function emits PARAMETER
--    NAMES, so a comparison against a type list never matches, every IF tests
--    NULL, and the whole block passes while nothing is true. That trap was hit
--    for real on KAN-188 and is recorded here so it is not reintroduced.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_six      oid;
  v_me       uuid;
  v_sport    text;
  v_sport_total int;
  v_sport_own   int;
  v_got      int;
  v_leaked   int;
  v_bulk     int;
  v_default  int;
BEGIN
  -- 5a. The 6-arg survived the fold and is the only rpc_potential_vibes left.
  v_six := to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer)');
  IF v_six IS NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: the 6-arg rpc_potential_vibes does not exist';
  END IF;

  -- 5b. The identity-parameter overload is GONE.
  IF to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer,uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: the 7-arg overload still exists';
  END IF;

  -- 5c. The debug function is GONE.
  IF to_regprocedure('public.rpc_potential_vibes_debug(uuid,text,text,double precision,double precision,numeric,integer)') IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: rpc_potential_vibes_debug still exists';
  END IF;

  -- 5d. No rpc_potential_vibes* function anywhere in public takes a uuid argument.
  --     Stated as a population check rather than by name, so a third overload
  --     appearing later cannot slip past a by-name enumeration.
  IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname LIKE 'rpc_potential_vibes%'
           AND 'uuid'::regtype::oid = ANY (p.proargtypes::oid[])
      ) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: an rpc_potential_vibes* function still takes a uuid argument';
  END IF;

  -- 5e. Exactly one function remains in the family.
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname LIKE 'rpc_potential_vibes%') <> 1 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: expected exactly 1 rpc_potential_vibes* function, found %',
      (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname LIKE 'rpc_potential_vibes%');
  END IF;

  -- 5f. SECURITY DEFINER and search_path survived CREATE OR REPLACE, and the body
  --     no longer mentions p_me.
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_six) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 6-arg lost SECURITY DEFINER';
  END IF;
  IF NOT (SELECT proconfig @> ARRAY['search_path=public, pg_temp'] FROM pg_proc WHERE oid = v_six) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 6-arg search_path is %',
      (SELECT proconfig::text FROM pg_proc WHERE oid = v_six);
  END IF;
  IF (SELECT prosrc FROM pg_proc WHERE oid = v_six) ~ 'p_me' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 6-arg body still references p_me';
  END IF;

  -- 5g. anon and authenticated KEEP EXECUTE (T-070 Decision 2). Asserted by
  --     has_function_privilege, never by a proacl text match: a bare `=X/postgres`
  --     entry is a grant to PUBLIC that anon inherits without being named.
  IF NOT has_function_privilege('anon', v_six, 'EXECUTE') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: anon lost EXECUTE on the 6-arg — v_potential_vibes_default would now raise 42501';
  END IF;
  IF NOT has_function_privilege('authenticated', v_six, 'EXECUTE') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated lost EXECUTE on the 6-arg';
  END IF;

  -- 5h. The comment AC3 requires is actually attached.
  IF coalesce(obj_description(v_six, 'pg_proc'), '') !~ 'SELF-EXCLUSION PRODUCT FILTER' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: AC3 comment is missing from the 6-arg';
  END IF;

  -- ---------------------------------------------------------------------------
  -- 5i. BEHAVIOURAL. Read-only; no row is written. Identity is injected the way
  --     T-070's own probes did it — set_config on request.jwt.claims — because
  --     adding a parameter to act as another user is the defect this ticket exists
  --     to remove.
  --
  --     VACUITY GUARDS FIRST. A self-exclusion probe run with no JWT, or against a
  --     subject who owns no rows, PASSES WITHOUT TESTING ANYTHING — that is exactly
  --     how this check was run vacuously once already on this ticket. Each guard
  --     below aborts the migration rather than letting the assertion go green empty.
  -- ---------------------------------------------------------------------------
  SELECT s.user_id INTO v_me
    FROM public.v_sport_profiles_with_user s
   GROUP BY s.user_id ORDER BY count(*) DESC, s.user_id LIMIT 1;
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'POST-CONDITION VOID: v_sport_profiles_with_user is empty; the behavioural probes below would pass vacuously';
  END IF;

  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me::text, 'role', 'authenticated')::text,
                     true);   -- transaction-local; reverts at COMMIT

  IF auth.uid() IS DISTINCT FROM v_me THEN
    RAISE EXCEPTION 'POST-CONDITION VOID: JWT context did not take — auth.uid() is %, expected %. Every probe below would be vacuous.',
      coalesce(auth.uid()::text, 'NULL'), v_me;
  END IF;

  -- Choose a sport narrow enough that the [1,50] clamp cannot hide the effect.
  SELECT s.sport_key,
         count(*),
         count(*) FILTER (WHERE s.user_id = v_me)
    INTO v_sport, v_sport_total, v_sport_own
    FROM public.v_sport_profiles_with_user s
   GROUP BY s.sport_key
  HAVING count(*) FILTER (WHERE s.user_id = v_me) > 0
     AND count(*) <= 50
     AND count(*) - count(*) FILTER (WHERE s.user_id = v_me) > 0
   ORDER BY count(*) DESC
   LIMIT 1;

  IF v_sport IS NULL THEN
    RAISE EXCEPTION 'POST-CONDITION VOID: no sport exists where the probe subject owns rows AND the total fits under the clamp AND a non-self remainder exists. The self-exclusion assertion cannot be made non-vacuously.';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE r.user_id = v_me)
    INTO v_got, v_leaked
    FROM public.rpc_potential_vibes(v_sport, NULL, NULL, NULL, NULL, 50) r;

  IF v_leaked <> 0 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: self-exclusion broken — % of the caller''s own rows returned for sport %', v_leaked, v_sport;
  END IF;
  IF v_got <> v_sport_total - v_sport_own THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: behaviour not preserved for sport % — got % rows, expected % (% in view minus % own)',
      v_sport, v_got, v_sport_total - v_sport_own, v_sport_total, v_sport_own;
  END IF;

  -- The clamp. Pre-migration this same call returned 140 rows.
  SELECT count(*) INTO v_bulk
    FROM public.rpc_potential_vibes(NULL, NULL, NULL, NULL, NULL, 999999);
  IF v_bulk > 50 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: p_limit clamp did not hold — % rows for p_limit=999999', v_bulk;
  END IF;

  -- The default the view relies on is unchanged.
  SELECT count(*) INTO v_default
    FROM public.rpc_potential_vibes(NULL, NULL, NULL, NULL, NULL, NULL);
  IF v_default <> 20 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: default p_limit no longer yields 20 rows — got %', v_default;
  END IF;

  -- Unauthenticated shape: 0 rows, and crucially NOT an exception.
  PERFORM set_config('request.jwt.claims', '', true);
  IF auth.uid() IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION VOID: could not clear the JWT context; the anon-shape probe would be vacuous';
  END IF;
  SELECT count(*) INTO v_got
    FROM public.rpc_potential_vibes(NULL, NULL, NULL, NULL, NULL, 999999);
  IF v_got <> 0 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: with no caller identity the function returned % rows, expected 0', v_got;
  END IF;

  -- And the allowlisted view still resolves rather than raising.
  SELECT count(*) INTO v_got FROM public.v_potential_vibes_default;
  IF v_got <> 0 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: v_potential_vibes_default returned % rows with no caller identity, expected 0', v_got;
  END IF;
END $$;
