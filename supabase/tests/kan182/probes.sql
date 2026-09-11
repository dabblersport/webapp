-- KAN-182 probe pack -- process_notification_event reachability gate.
-- Migration: 20260911105434_kan182_process_notification_event_contain_and_definer_trg_circle_join_notify.sql
-- STATUS: APPLIED 2026-09-11, ledger version 20260911105434. P1-P5 all PASS post-apply.
--
-- EACH PROBE WAS SEEN TO FAIL BEFORE IT WAS ALLOWED TO PASS. P1, P2 and P4 were run
-- against the live pre-fix schema and raised (P1: 1 client role held EXECUTE; P2:
-- 1 SECURITY INVOKER caller, trg_circle_join_notify; P4: n=0). P3 and P5 pass both
-- before and after -- a pure-DDL change must not move a caller population or a body --
-- so they are falsified by the P3C/P5C controls at the foot instead.
--
-- GUARD SHAPE -- every assert below compares a COUNT to an EXPECTED INTEGER
-- (`IF n <> expected THEN RAISE`). None is of the form `IF <boolean> THEN RAISE`.
-- That distinction is the whole point: a boolean guard fails OPEN when the
-- expression is NULL or when the query silently matches nothing, so it reports
-- success for a schema it never actually inspected. A count guard fails CLOSED --
-- if the population moves in ANY direction, including to zero because a name was
-- typo'd, n stops equalling expected and the probe raises.
--
-- NO WRITES. Every probe reads pg_proc / pg_trigger / pg_constraint only. The function
-- under test is never invoked in-database before the migration lands: invoking it as
-- `authenticated` WOULD CURRENTLY SUCCEED and insert a real row into `notifications`
-- (565 live rows). That is a user-data mutation and is out of bounds. See the
-- post-apply section at the foot for the execution probe that becomes safe only once
-- the revoke is in place.
--
-- RUN AS `postgres`.

-- ===========================================================================
-- P0 -- VOID-THE-PACK PRECONDITION (T-055: check the target before trusting a probe)
-- ===========================================================================
SELECT
  current_user::text                          AS running_role,  -- expect postgres
  p.oid                                       AS target_oid,    -- expect 107885
  p.prosecdef                                 AS secdef,        -- expect true
  pg_get_userbyid(p.proowner)                 AS owner,         -- expect postgres
  p.proacl::text                              AS acl,
  p.proconfig::text                           AS config,        -- expect {"search_path=public, pg_temp"}
  md5(p.prosrc)                               AS body_md5       -- expect 1b14f5666734be00236e5abd4aa13dd4, UNCHANGED
FROM pg_proc p
WHERE p.oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure;

-- This migration is pure DDL (ALTER / REVOKE / COMMENT) and restates no body, so a
-- changed md5 on either function means something other than this migration touched it.

-- ===========================================================================
-- P1 -- No client role holds EXECUTE.
-- GUARD: count vs expected integer. FAILS CLOSED.
-- PUBLIC checked EXPLICITLY -- a bare `=X/postgres` entry is a grant to PUBLIC that
-- `anon` inherits without being named, so a proacl text-match for 'anon' misses it.
-- PRE-FIX RESULT: n = 1 (authenticated). POST-FIX EXPECTED: n = 0.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 0;
BEGIN
  SELECT count(*) INTO n
  FROM (VALUES ('anon'), ('authenticated'), ('public')) AS r(role)
  WHERE has_function_privilege(
          r.role,
          'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure,
          'EXECUTE');
  IF n <> expected THEN
    RAISE EXCEPTION 'P1 FAIL: % client role(s) still hold EXECUTE, expected %', n, expected;
  END IF;
  RAISE NOTICE 'P1 PASS: no client role holds EXECUTE';
END $$;

-- ===========================================================================
-- P2 -- Every in-database caller survives the revoke.
-- A caller keeps working only if it is SECURITY DEFINER owned by a role that still
-- holds EXECUTE; a SECURITY INVOKER caller executes as the END USER and would raise
-- 42501. This is the probe that catches the real regression risk in this ticket.
-- GUARD: count vs expected integer. FAILS CLOSED.
-- PRE-FIX RESULT: n = 1 (trg_circle_join_notify, attached to circle_members --
-- joining a circle would fail outright). POST-FIX EXPECTED: n = 0.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 0; offenders text;
BEGIN
  SELECT count(*), coalesce(string_agg(p.proname, ', '), '(none)') INTO n, offenders
  FROM pg_proc p
  WHERE p.prosrc ILIKE '%process_notification_event%'
    AND p.oid <> 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure
    AND NOT p.prosecdef;
  IF n <> expected THEN
    RAISE EXCEPTION 'P2 FAIL: % SECURITY INVOKER caller(s) would break: %', n, offenders;
  END IF;
  RAISE NOTICE 'P2 PASS: all callers are SECURITY DEFINER';
END $$;

-- ===========================================================================
-- P3 -- The caller population itself has not moved.
-- Without this, P2 passes trivially if the ILIKE stops matching (a rename, a schema
-- change, a typo) -- zero callers inspected, zero offenders found, green. This is the
-- "passes for the wrong reason" guard.
-- GUARD: count vs expected integer. FAILS CLOSED.
-- MEASURED 2026-09-11: 19 DISTINCT CALLER FUNCTIONS, all in schema `public`.
--
-- THIS NUMBER COUNTS FUNCTIONS, NOT CALL SITES, and the two differ. The same
-- measurement returns 22 textual occurrences of the name across those 19 bodies --
-- several call it more than once. A "21 callers" figure quoted upstream is a call-site
-- count, not a function count; it is not what this probe asserts and 19 is not a
-- contradiction of it. Stated so the next reader does not "correct" 19 to 21 and
-- turn a passing probe into a failing one.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 19;
BEGIN
  SELECT count(*) INTO n
  FROM pg_proc p
  WHERE p.prosrc ILIKE '%process_notification_event%'
    AND p.oid <> 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure;
  IF n <> expected THEN
    RAISE EXCEPTION 'P3 FAIL: caller population is %, expected % -- P2 may be vacuous', n, expected;
  END IF;
  RAISE NOTICE 'P3 PASS: caller population still %', expected;
END $$;

-- ===========================================================================
-- P4 -- trg_circle_join_notify is DEFINER and its search_path is still pinned.
-- Making a function SECURITY DEFINER without a pinned search_path is its own
-- vulnerability, so the two are asserted together and never separately.
-- GUARD: count vs expected integer. FAILS CLOSED.
-- PRE-FIX RESULT: n = 0. POST-FIX EXPECTED: n = 1.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 1;
BEGIN
  SELECT count(*) INTO n
  FROM pg_proc p
  WHERE p.oid = 'public.trg_circle_join_notify()'::regprocedure
    AND p.prosecdef
    AND p.proconfig @> ARRAY['search_path=public, pg_temp'];
  IF n <> expected THEN
    RAISE EXCEPTION 'P4 FAIL: trg_circle_join_notify is not DEFINER-with-pinned-search_path (n=%)', n;
  END IF;
  RAISE NOTICE 'P4 PASS: trg_circle_join_notify is DEFINER with pinned search_path';
END $$;

-- ===========================================================================
-- P5 -- Neither body was restated. Pure-DDL migration; md5s must be unchanged.
-- GUARD: count vs expected integer. FAILS CLOSED.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 2;
BEGIN
  SELECT count(*) INTO n FROM pg_proc p
  WHERE (p.oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure
         AND md5(p.prosrc) = '1b14f5666734be00236e5abd4aa13dd4')
     OR (p.oid = 'public.trg_circle_join_notify()'::regprocedure
         AND md5(p.prosrc) = 'a2afe6754a5b774354fdb2e78e540747');  -- measured live 2026-09-11
  IF n <> expected THEN
    RAISE EXCEPTION 'P5 FAIL: % of % bodies match their expected md5', n, expected;
  END IF;
  RAISE NOTICE 'P5 PASS: both bodies unchanged';
END $$;

-- ===========================================================================
-- NEGATIVE CONTROLS -- P3C and P5C. EACH MUST RAISE. A GREEN RUN HERE IS A FAILURE.
--
-- P1, P2 and P4 are self-demonstrating: they FAIL against the live pre-fix schema and
-- pass only once the migration lands, so each has been SEEN to fail. P3 and P5 pass
-- BEFORE the migration too -- a pure-DDL change must not move a caller population or a
-- body -- so neither has ever been observed failing, and an unfalsified probe is not
-- evidence. These two aim the IDENTICAL predicate at a deliberately wrong target. If a
-- control passes, its partner's predicate is vacuous and its green result means nothing.
-- ===========================================================================
DO $$
DECLARE n int; expected CONSTANT int := 19;
BEGIN
  -- Identical to P3 except the searched name is misspelt -- exactly the typo P3 exists
  -- to catch. Must report 0, not 19.
  SELECT count(*) INTO n
  FROM pg_proc p
  WHERE p.prosrc ILIKE '%process_notification_evnet%';
  IF n <> expected THEN
    RAISE EXCEPTION 'P3C CORRECT (control failed as required): population is %, not % -- P3''s predicate discriminates', n, expected;
  END IF;
  RAISE NOTICE 'P3C BROKEN: control PASSED -- P3 is vacuous and its green result is worthless';
END $$;

DO $$
DECLARE n int; expected CONSTANT int := 2;
BEGIN
  -- Identical to P5 with one md5 digit flipped. Must match 1 body, not 2.
  SELECT count(*) INTO n FROM pg_proc p
  WHERE (p.oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure
         AND md5(p.prosrc) = '1b14f5666734be00236e5abd4aa13dd4')
     OR (p.oid = 'public.trg_circle_join_notify()'::regprocedure
         AND md5(p.prosrc) = 'a2afe6754a5b774354fdb2e78e540748');  -- final digit 7 -> 8
  IF n <> expected THEN
    RAISE EXCEPTION 'P5C CORRECT (control failed as required): % of % bodies matched -- P5''s md5 comparison is live', n, expected;
  END IF;
  RAISE NOTICE 'P5C BROKEN: control PASSED -- P5 is not actually comparing md5s';
END $$;

-- ===========================================================================
-- POST-APPLY ONLY -- EXECUTION PROBE. Do NOT run before the revoke lands.
-- Before the revoke this call SUCCEEDS and writes a real notifications row.
-- After it, the call is denied and cannot write. Safe by construction even if the
-- revoke silently failed: notifications.to_user_id carries
--   FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE
-- so the fabricated uuid below raises 23503 before any row can persist. Verified
-- against pg_constraint, not assumed.
--
--   SET ROLE authenticated;
--   SELECT public.process_notification_event(
--     '00000000-0000-4000-8000-0000deadbeef'::uuid,
--     'social.followed', 'profile',
--     '00000000-0000-4000-8000-0000deadbeef'::uuid,
--     '00000000-0000-4000-8000-0000deadbeef'::uuid,
--     'KAN-182 probe', 'KAN-182 probe');
--   -- EXPECT: 42501 permission denied for function process_notification_event
--   RESET ROLE;
--
-- EXTERNAL REACHABILITY (AC4) is not provable from in-database SQL and is not faked
-- here. Run the HTTP round-trip with a positive control, as KAN-181 did:
--   POST /rest/v1/rpc/jwt_role       -> expect 200 "anon"      (control: harness works)
--   POST /rest/v1/rpc/process_notification_event -> expect denial
-- A denial without a passing control proves nothing -- it is indistinguishable from a
-- dead endpoint or a malformed request.
--
-- RESULT 2026-09-11, post-apply: control 200 "anon"; target HTTP 401, code 42501,
-- 'permission denied for function process_notification_event'. Control re-run after
-- the target, still 200 -- so the 401 is a denial, not a broken harness.
--
-- TRAP, HIT FOR REAL ON THE FIRST ATTEMPT -- READ BEFORE RE-RUNNING.
-- The actor parameter is `p_actor_user_id`, NOT `p_actor_id`. Sending `p_actor_id`
-- returns HTTP 404 / PGRST202 "no matches were found in the schema cache" -- PostgREST
-- never resolves the function, so the permission check is NEVER REACHED. That 404 looks
-- like a pass and is worth nothing: it is the same response an already-deleted function
-- gives. Only the 401/42501 above proves the revoke is doing the work. This is the
-- caller-side twin of T-055: confirm the path can execute at all before reading a
-- refusal as evidence.
-- ===========================================================================
