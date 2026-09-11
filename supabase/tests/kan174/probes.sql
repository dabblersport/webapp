-- KAN-174 probe pack — rpc_potential_vibes: the identity parameter is gone, the
-- self-exclusion predicate still works, and anon still gets 0 rows rather than 42501.
--
-- Migration: supabase/migrations/20260911114124_kan174_fold_potential_vibes_drop_identity_param.sql
-- STATUS 2026-09-11: APPLIED (ledger version 20260911114124). Post-apply live
-- re-verification (independent of the migration's own in-transaction post-conditions):
-- exactly one rpc_potential_vibes remains, SECURITY DEFINER intact, anon EXECUTE
-- retained, AC3 comment present. Confirmed over an actual PostgREST HTTP round-trip
-- (AC4): anon POST to the 6-arg returns 200 [], the removed 7-arg signature returns
-- 404 PGRST202 (unreachable, not merely empty).
--
-- Pre-fix results below are PRESERVED AS HISTORICAL RECORD of what this pack measured
-- before the fix landed — do not re-run assuming these values still hold:
--
--   P1  seven_arg_dropped=false, debug_dropped=false, family_count=3,
--       no_uuid_arg_anywhere=false          <- the three that had to flip (now flipped)
--   P2  still_security_definer=true, anon_keeps_execute=true,
--       anon_can_read_base=false            <- already correct, unchanged post-fix
--   P3  ac3_comment_present is NULL         <- no comment existed yet (now present)
--   P4  PASS — sport padel, subject 26, stranger 27, 0 leaked
--   P5  RAISED — "clamp did not hold - 140 rows for p_limit=999999"
--   P6  PASS — 0 rows from both, no exception
--
-- P4 AND P6 PASSING PRE-FIX IS CORRECT AND IS THE POINT. The 6-arg wrapper's own
-- self-exclusion always worked, and anon always got 0 rows THROUGH IT. The incident
-- was never the 6-arg: it was the 7-arg sibling, reachable directly, whose identity
-- came from the caller. So P4/P6 are REGRESSION guards — they must keep passing
-- across the fold — while P1 and P5 are the probes that actually change state.
-- A pack where every probe flips would be a pack that had not understood the defect.
--
-- RUN AS `postgres`. has_function_privilege and has_table_privilege are role-explicit
-- so the running role does not change their answers, but the pg_proc reads need
-- catalogue visibility, and P4/P5 need to set request.jwt.claims.
--
-- NO WRITES. Every statement is a SELECT or a transaction-local set_config. The
-- function under test is read-only by construction.
--
-- ===========================================================================
-- WHY THIS PACK IS SHAPED LIKE THIS — the vacuity problem is the whole story.
-- ===========================================================================
-- The first attempt at this ticket's behaviour check reported "147 rows before,
-- 147 rows after — behaviour preserved" and PROVED NOTHING. It ran with no JWT, so
-- auth.uid() was NULL, so `spw.user_id <> auth.uid()` was NULL for every row and
-- the self-exclusion predicate was never exercised at all.
--
-- A self-exclusion probe is vacuous unless ALL of these hold, and each is asserted
-- rather than assumed:
--   (a) a caller identity is actually in scope — auth.uid() must equal the subject;
--   (b) the subject actually OWNS rows in the view — otherwise "none of mine came
--       back" is true of any function, including a broken one;
--   (c) the subject's rows would otherwise be VISIBLE — i.e. the query is not
--       already empty for an unrelated reason;
--   (d) the clamp cannot hide the effect — with LIMIT capped at 50 and 147 rows in
--       the view, an unordered top-50 might miss the subject's rows by luck. So the
--       probe narrows to a sport whose TOTAL fits under the clamp.
-- P0 establishes (a)-(d) and VOIDS THE PACK if any fails.
--
-- Measured on wtncuzcskpigqpmnxwws 2026-09-11, pre-migration:
--   v_sport_profiles_with_user            147 rows / 137 distinct users
--   busiest subject                       7 of those 147 rows
--   authenticated + real JWT, limit 999999  140 rows   <- self-exclusion working
--   authenticated + JWT for a stranger      147 rows   <- the discriminating control
--   anon, 6-arg, limit 999999                 0 rows
--   anon, v_potential_vibes_default            0 rows
--   anon -> rpc_potential_vibes_debug       42P01, NOT 42501
-- 140 vs 147 is the discrimination the original run lacked.

-- ===========================================================================
-- P0 — VOID-THE-PACK PRECONDITIONS (T-055). If any column below is not `true`,
-- STOP: every behavioural probe after it would pass without testing anything.
-- ===========================================================================
BEGIN;
SELECT set_config('request.jwt.claims',
       json_build_object(
         'sub', (SELECT s.user_id::text FROM public.v_sport_profiles_with_user s
                  GROUP BY s.user_id ORDER BY count(*) DESC, s.user_id LIMIT 1),
         'role','authenticated')::text, true);

WITH subject AS (
  SELECT s.user_id AS me FROM public.v_sport_profiles_with_user s
   GROUP BY s.user_id ORDER BY count(*) DESC, s.user_id LIMIT 1
), narrow AS (
  SELECT s.sport_key,
         count(*)                                          AS sport_total,
         count(*) FILTER (WHERE s.user_id = (SELECT me FROM subject)) AS sport_own
    FROM public.v_sport_profiles_with_user s
   GROUP BY s.sport_key
  HAVING count(*) FILTER (WHERE s.user_id = (SELECT me FROM subject)) > 0
     AND count(*) <= 50
     AND count(*) - count(*) FILTER (WHERE s.user_id = (SELECT me FROM subject)) > 0
   ORDER BY count(*) DESC LIMIT 1
)
SELECT
  current_user::text                                AS running_role,
  (SELECT me FROM subject) IS NOT NULL              AS a_subject_exists,
  auth.uid() = (SELECT me FROM subject)             AS b_jwt_actually_took,
  (SELECT sport_own   FROM narrow) > 0              AS c_subject_owns_rows,
  (SELECT sport_total FROM narrow) <= 50            AS d_fits_under_clamp,
  (SELECT sport_key   FROM narrow)                  AS probe_sport,
  (SELECT sport_total FROM narrow)                  AS sport_total,
  (SELECT sport_own   FROM narrow)                  AS sport_own;
ROLLBACK;

-- ===========================================================================
-- P1 — THE INCIDENT OBJECT IS GONE. The 7-arg overload that took a caller-supplied
-- p_me, and the debug function that took one too.
--
-- Asserted on to_regprocedure(), NEVER on pg_get_function_identity_arguments()
-- text: that function emits PARAMETER NAMES ("p_sport text, …"), so comparing it
-- to a type list matches nothing, every test reads NULL, and the check passes
-- while the object is still there. That trap was hit for real on KAN-188.
--
-- Pre-migration this reports 7-arg PRESENT, debug PRESENT, family count 3.
-- Post-migration: both absent, count 1.
-- ===========================================================================
SELECT
  to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer)')       IS NOT NULL AS six_arg_present,       -- must stay true
  to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer,uuid)')  IS NULL     AS seven_arg_dropped,     -- must become true
  to_regprocedure('public.rpc_potential_vibes_debug(uuid,text,text,double precision,double precision,numeric,integer)') IS NULL AS debug_dropped,        -- must become true
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE 'rpc_potential_vibes%')                                            AS family_count,                     -- must become 1
  NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
               WHERE n.nspname='public' AND p.proname LIKE 'rpc_potential_vibes%'
                 AND 'uuid'::regtype::oid = ANY (p.proargtypes::oid[]))                                            AS no_uuid_arg_anywhere;             -- must become true

-- ===========================================================================
-- P2 — THE DEFINER BOUNDARY AND THE GRANT ARE BOTH DELIBERATELY UNCHANGED.
--
-- READ T-070 DECISION 2 BEFORE "FIXING" ANYTHING THIS PROBE REPORTS.
-- SECURITY DEFINER is load-bearing: the underlying view is unreadable to BOTH
-- client roles, so an invoker function returns nothing to anyone and the feature
-- silently dies. anon's EXECUTE is load-bearing too: revoking it turns 0 rows into
-- 42501 raised through v_potential_vibes_default, which anon CAN select and which
-- is on the §2f allowlist. Both change together or neither does.
--
-- has_*_privilege throughout, never a proacl text match — a bare `=X/postgres`
-- entry is a grant to PUBLIC that anon inherits without ever being named.
-- ===========================================================================
SELECT
  p.prosecdef                                                                AS still_security_definer,  -- expect true
  p.proconfig @> ARRAY['search_path=public, pg_temp']                        AS search_path_intact,      -- expect true
  has_function_privilege('anon',          p.oid, 'EXECUTE')                  AS anon_keeps_execute,      -- expect true, ON PURPOSE
  has_function_privilege('authenticated', p.oid, 'EXECUTE')                  AS auth_keeps_execute,      -- expect true
  has_table_privilege('anon',          'public.v_sport_profiles_with_user', 'SELECT') AS anon_can_read_base,  -- expect FALSE
  has_table_privilege('authenticated', 'public.v_sport_profiles_with_user', 'SELECT') AS auth_can_read_base,  -- expect FALSE
  p.prosrc ~ 'p_me'                                                          AS body_still_has_p_me,     -- expect false
  p.prosrc ~ 'auth\.uid\(\)'                                                 AS body_derives_identity    -- expect true
FROM pg_proc p
WHERE p.oid = to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer)')::oid;

-- ===========================================================================
-- P3 — AC3. The comment naming the predicate's role is attached to the object
-- itself, so it travels with pg_get_functiondef and cannot drift the way a row
-- in docs/SCHEMA.md can (which is precisely what AC6 exists to repair).
-- ===========================================================================
-- coalesce() is load-bearing: with no comment attached obj_description returns NULL,
-- and `NULL ~ 'x'` is NULL, not false — so an uncoalesced test reads as "unknown"
-- and an IF over it takes neither branch. Same shape as the KAN-188 blind assertion.
SELECT
  coalesce(obj_description(to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer)')::oid, 'pg_proc'), '')
    ~ 'SELF-EXCLUSION PRODUCT FILTER'                                        AS ac3_comment_present,     -- expect true
  coalesce(obj_description(to_regprocedure('public.rpc_potential_vibes(text,text,double precision,double precision,numeric,integer)')::oid, 'pg_proc'), '')
    ~ 'MUST NOT be described as'                                             AS ac3_names_limit_caveat;  -- expect true

-- ===========================================================================
-- P4 — SELF-EXCLUSION, NON-VACUOUSLY, AND THE CONTROL THAT PROVES IT DISCRIMINATES.
--
-- Two rows come back. `subject` is a user who owns rows in the probe sport;
-- `stranger` is a uuid that owns none. If BOTH return the same row count, the
-- predicate is not running and this probe is worthless — that is exactly the
-- failure mode of the original 147-before/147-after reading.
--
--   subject  : rows_returned must equal sport_total - sport_own, own_rows_leaked = 0
--   stranger : rows_returned must equal sport_total,             own_rows_leaked = 0
--
-- Demonstrated failing against a deliberately broken fold (self-exclusion predicate
-- deleted) in a rolled-back transaction on 2026-09-11: it reported 1 leaked own row
-- for sport padel, and the two identities returned identical counts.
-- ===========================================================================
DO $$
DECLARE
  v_me uuid; v_sport text; v_tot int; v_own int;
  v_sub_rows int; v_sub_leak int; v_str_rows int;
BEGIN
  SELECT s.user_id INTO v_me FROM public.v_sport_profiles_with_user s
   GROUP BY s.user_id ORDER BY count(*) DESC, s.user_id LIMIT 1;
  SELECT s.sport_key, count(*), count(*) FILTER (WHERE s.user_id = v_me)
    INTO v_sport, v_tot, v_own
    FROM public.v_sport_profiles_with_user s GROUP BY s.sport_key
   HAVING count(*) FILTER (WHERE s.user_id = v_me) > 0 AND count(*) <= 50
      AND count(*) - count(*) FILTER (WHERE s.user_id = v_me) > 0
   ORDER BY count(*) DESC LIMIT 1;
  IF v_me IS NULL OR v_sport IS NULL THEN
    RAISE EXCEPTION 'P4 VOID: no non-vacuous subject/sport pair exists';
  END IF;

  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', v_me::text, 'role','authenticated')::text, true);
  IF auth.uid() IS DISTINCT FROM v_me THEN
    RAISE EXCEPTION 'P4 VOID: JWT did not take — auth.uid() is %', coalesce(auth.uid()::text,'NULL');
  END IF;
  SELECT count(*), count(*) FILTER (WHERE r.user_id = v_me) INTO v_sub_rows, v_sub_leak
    FROM public.rpc_potential_vibes(v_sport,NULL,NULL,NULL,NULL,50) r;

  PERFORM set_config('request.jwt.claims',
          json_build_object('sub','00000000-0000-0000-0000-0000000000ff','role','authenticated')::text, true);
  SELECT count(*) INTO v_str_rows
    FROM public.rpc_potential_vibes(v_sport,NULL,NULL,NULL,NULL,50);
  PERFORM set_config('request.jwt.claims','',true);

  IF v_sub_rows = v_str_rows THEN
    RAISE EXCEPTION 'P4 VACUOUS: subject and stranger both got % rows for sport % — the predicate is not running', v_sub_rows, v_sport;
  END IF;
  IF v_sub_leak <> 0 THEN
    RAISE EXCEPTION 'P4 FAIL: self-exclusion broken — % own rows returned for sport %', v_sub_leak, v_sport;
  END IF;
  IF v_sub_rows <> v_tot - v_own OR v_str_rows <> v_tot THEN
    RAISE EXCEPTION 'P4 FAIL: sport % — subject got % (expected %), stranger got % (expected %)',
      v_sport, v_sub_rows, v_tot - v_own, v_str_rows, v_tot;
  END IF;
  RAISE NOTICE 'P4 PASS: sport %, subject % rows, stranger % rows, 0 leaked', v_sport, v_sub_rows, v_str_rows;
END $$;

-- ===========================================================================
-- P5 — THE p_limit CLAMP (T-070 Decision 3), and the default the view depends on.
--
-- p_limit IS NOT AN ACCESS CONTROL and must never be described as one. It is an
-- anti-bulk control, and it is one ONLY because this function has no offset
-- parameter. ADD PAGING AND THIS PROBE STOPS MEANING WHAT IT SAYS.
--
-- Pre-migration this returns 140 for bulk (the hole). Post-migration: <= 50.
-- ===========================================================================
DO $$
DECLARE v_me uuid; v_bulk int; v_default int; v_one int;
BEGIN
  SELECT s.user_id INTO v_me FROM public.v_sport_profiles_with_user s
   GROUP BY s.user_id ORDER BY count(*) DESC, s.user_id LIMIT 1;
  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', v_me::text, 'role','authenticated')::text, true);
  SELECT count(*) INTO v_bulk    FROM public.rpc_potential_vibes(NULL,NULL,NULL,NULL,NULL,999999);
  SELECT count(*) INTO v_default FROM public.rpc_potential_vibes(NULL,NULL,NULL,NULL,NULL,NULL);
  SELECT count(*) INTO v_one     FROM public.rpc_potential_vibes(NULL,NULL,NULL,NULL,NULL,0);
  PERFORM set_config('request.jwt.claims','',true);
  IF v_bulk > 50 THEN
    RAISE EXCEPTION 'P5 FAIL: clamp did not hold — % rows for p_limit=999999', v_bulk;
  END IF;
  IF v_default <> 20 THEN
    RAISE EXCEPTION 'P5 FAIL: p_limit=NULL yielded % rows, expected 20 (v_potential_vibes_default depends on this)', v_default;
  END IF;
  IF v_one <> 1 THEN
    RAISE EXCEPTION 'P5 FAIL: p_limit=0 yielded % rows, expected 1 (GREATEST floor)', v_one;
  END IF;
  RAISE NOTICE 'P5 PASS: bulk %, default %, floor %', v_bulk, v_default, v_one;
END $$;

-- ===========================================================================
-- P6 — THE UNAUTHENTICATED SHAPE. 0 rows, and CRUCIALLY NOT AN EXCEPTION.
--
-- This is the probe that would catch someone "hardening" the function by revoking
-- anon's EXECUTE. The correct anon result is an empty set; 42501 would be a live
-- break in v_potential_vibes_default, which anon can select and which the
-- anon-allowlist gate watches.
--
-- Demonstrated failing against a broken fold on 2026-09-11: with the self-exclusion
-- predicate deleted, this returned 50 rows to a caller with no identity — i.e. the
-- KAN-174 incident, reproduced. This probe is what stops that shipping.
-- ===========================================================================
DO $$
DECLARE v_fn int; v_view int; st text;
BEGIN
  PERFORM set_config('request.jwt.claims','',true);
  IF auth.uid() IS NOT NULL THEN
    RAISE EXCEPTION 'P6 VOID: could not clear the JWT context';
  END IF;
  BEGIN
    SELECT count(*) INTO v_fn   FROM public.rpc_potential_vibes(NULL,NULL,NULL,NULL,NULL,999999);
    SELECT count(*) INTO v_view FROM public.v_potential_vibes_default;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE;
    RAISE EXCEPTION 'P6 FAIL: unauthenticated call RAISED % — expected an empty set, not an error. If this is 42501, someone revoked anon EXECUTE; read T-070 Decision 2 before doing that.', st;
  END;
  IF v_fn <> 0 OR v_view <> 0 THEN
    RAISE EXCEPTION 'P6 FAIL: unauthenticated caller got % rows from the function and % from the view, expected 0 and 0', v_fn, v_view;
  END IF;
  RAISE NOTICE 'P6 PASS: 0 rows from both, no exception';
END $$;
