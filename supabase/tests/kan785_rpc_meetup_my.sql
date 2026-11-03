-- KAN-785 probe. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
-- Run with -v mode=before | after | rollback (driver: clean785.sh).
--   before   : rpc_meetup_my() exists, is the pinned broken pre-image, a call raises 42703; snapshots every OTHER
--              public function/view definition into kan785_fx.snap.
--   after    : rpc_meetup_my is gone, nothing depends on it, every other public function/view is byte-identical to
--              the snapshot, every meetup view still plans and runs, the other meetup RPCs are present.
--   rollback : the verbatim pre-image (migration header) restores the pinned definition, ACL and 42703 behaviour.
-- Each check prints "KAN-785 <id> PASS" or raises "KAN-785 <id> FAIL: ...".
\set ON_ERROR_STOP 1

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-785 probe: this looks like a Supabase database; local throwaway cluster only';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.call_state() RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM count(*) FROM public.rpc_meetup_my();
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERR ' || SQLSTATE;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.others() RETURNS TABLE(ident text, md text) LANGUAGE sql AS $f$
  SELECT 'f:' || p.oid::regprocedure::text, md5(CASE WHEN p.prokind IN ('a','w') THEN p.proname
                                                    ELSE pg_get_functiondef(p.oid) END || coalesce(p.proacl::text, ''))
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname <> 'rpc_meetup_my'
  UNION ALL
  SELECT 'v:' || c.relname, md5(pg_get_viewdef(c.oid) || coalesce(c.relacl::text, ''))
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('v', 'm')
$f$;

\if :{?mode}
\else
\echo 'KAN-785 probe: pass -v mode=before|after|rollback'
\quit
\endif

SELECT :'mode' = 'before' AS is_before, :'mode' = 'after' AS is_after, :'mode' = 'rollback' AS is_rollback \gset

\if :is_before
DO $$
DECLARE v text;
BEGIN
  IF to_regprocedure('public.rpc_meetup_my()') IS NULL THEN RAISE EXCEPTION 'KAN-785 B1 FAIL: function absent'; END IF;
  RAISE NOTICE 'KAN-785 B1 PASS: rpc_meetup_my() present';
  v := md5(pg_get_functiondef('public.rpc_meetup_my()'::regprocedure));
  IF v <> '9459dd31f4dfc534d26b3e37e49326b9' THEN RAISE EXCEPTION 'KAN-785 B2 FAIL: md5 %', v; END IF;
  RAISE NOTICE 'KAN-785 B2 PASS: definition = pinned broken pre-image 9459dd31…';
  v := pg_temp.call_state();
  IF v <> 'ERR 42703' THEN RAISE EXCEPTION 'KAN-785 B3 FAIL: call returned %', v; END IF;
  RAISE NOTICE 'KAN-785 B3 PASS (negative): calling rpc_meetup_my() raises ERR 42703';
END $$;
DROP SCHEMA IF EXISTS kan785_fx CASCADE;
CREATE SCHEMA kan785_fx;
CREATE TABLE kan785_fx.snap AS SELECT * FROM pg_temp.others();
SELECT format('KAN-785 B4 PASS: snapshot of %s other public functions/views', count(*)) AS r FROM kan785_fx.snap \gset
\echo NOTICE: :r
\endif

\if :is_after
DO $$
DECLARE v text; n int; r record;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname IN ('rpc_meetup_my', 'rpc_meetup_my_kan712_inner')) THEN
    RAISE EXCEPTION 'KAN-785 A1 FAIL: rpc_meetup_my still present';
  END IF;
  RAISE NOTICE 'KAN-785 A1 PASS: rpc_meetup_my (and any _kan712_inner) absent';

  v := pg_temp.call_state();
  IF v <> 'ERR 42883' THEN RAISE EXCEPTION 'KAN-785 A2 FAIL: call returned %', v; END IF;
  RAISE NOTICE 'KAN-785 A2 PASS: a call now raises ERR 42883 (undefined function), not 42703';

  SELECT count(*) INTO n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f', 'p') AND p.prosrc ILIKE '%rpc_meetup_my%';
  IF n > 0 THEN RAISE EXCEPTION 'KAN-785 A3 FAIL: % function bodies mention rpc_meetup_my', n; END IF;
  SELECT count(*) INTO n FROM pg_class c
   WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('v', 'm') AND pg_get_viewdef(c.oid) ILIKE '%rpc_meetup_my%';
  IF n > 0 THEN RAISE EXCEPTION 'KAN-785 A3 FAIL: % views mention rpc_meetup_my', n; END IF;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    EXECUTE $q$SELECT count(*) FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_meetup_my'$q$ INTO n;
    IF n > 0 THEN RAISE EXCEPTION 'KAN-785 A3 FAIL: kan712_wrapped_rpcs row remains'; END IF;
  END IF;
  RAISE NOTICE 'KAN-785 A3 PASS: no function body, view or kan712_wrapped_rpcs row references rpc_meetup_my';

  SELECT count(*) INTO n FROM (
    (SELECT ident, md FROM kan785_fx.snap EXCEPT SELECT ident, md FROM pg_temp.others())
    UNION ALL
    (SELECT ident, md FROM pg_temp.others() EXCEPT SELECT ident, md FROM kan785_fx.snap)) d;
  IF n > 0 THEN RAISE EXCEPTION 'KAN-785 A4 FAIL: % other public functions/views changed', n; END IF;
  RAISE NOTICE 'KAN-785 A4 PASS: all % other public functions/views byte-identical (definition + ACL)',
    (SELECT count(*) FROM kan785_fx.snap);

  n := 0;
  FOR r IN SELECT c.oid::regclass AS v FROM pg_class c
            WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'v' AND c.relname ILIKE '%meetup%' LOOP
    EXECUTE format('SELECT count(*) FROM (SELECT * FROM %s LIMIT 1) s', r.v);
    n := n + 1;
  END LOOP;
  IF n = 0 THEN RAISE EXCEPTION 'KAN-785 A5 FAIL: no meetup view found to exercise'; END IF;
  RAISE NOTICE 'KAN-785 A5 PASS: % meetup views execute', n;

  SELECT count(*) INTO n FROM unnest(ARRAY[
      'public.rpc_meetup_card(uuid,text)', 'public.rpc_meetup_attendees(uuid,text,integer,integer)',
      'public.rpc_meetup_cancel(uuid)',
      'public.rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)']) s
   WHERE to_regprocedure(s) IS NULL;
  IF n > 0 THEN RAISE EXCEPTION 'KAN-785 A6 FAIL: % other meetup RPCs missing', n; END IF;
  RAISE NOTICE 'KAN-785 A6 PASS: rpc_meetup_card / attendees / cancel / update present';
END $$;
\endif

\if :is_rollback
DO $$
DECLARE v text;
BEGIN
  IF to_regprocedure('public.rpc_meetup_my()') IS NULL THEN RAISE EXCEPTION 'KAN-785 R1 FAIL: not restored'; END IF;
  v := md5(pg_get_functiondef('public.rpc_meetup_my()'::regprocedure));
  IF v <> '9459dd31f4dfc534d26b3e37e49326b9' THEN RAISE EXCEPTION 'KAN-785 R1 FAIL: md5 %', v; END IF;
  RAISE NOTICE 'KAN-785 R1 PASS: pre-image restored, md5 = 9459dd31…';
  SELECT p.proacl::text INTO v FROM pg_proc p WHERE p.oid = 'public.rpc_meetup_my()'::regprocedure;
  IF v <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-785 R2 FAIL: acl %', v;
  END IF;
  RAISE NOTICE 'KAN-785 R2 PASS: ACL restored %', v;
  v := pg_temp.call_state();
  IF v <> 'ERR 42703' THEN RAISE EXCEPTION 'KAN-785 R3 FAIL: call returned %', v; END IF;
  RAISE NOTICE 'KAN-785 R3 PASS: restored function behaves as before (ERR 42703)';
END $$;
\endif
