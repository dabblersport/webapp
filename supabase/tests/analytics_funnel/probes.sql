-- KAN-700 probes for public.rpc_admin_launch_funnel(date, date).
-- Run by Ops after the migration is applied, as postgres, in one session. Every write is rolled back.
-- Each probe raises on failure; a clean run reaches the final ROLLBACK.
BEGIN;

-- Seed: one real auth user is made admin (rolled back); a random uuid is the non-admin.
-- The ids travel as transaction-local settings (readable under every role), so nothing is granted to anyone.
SELECT set_config('k700.admin_id', (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)::text, true),
       set_config('k700.plain_id', gen_random_uuid()::text, true);

INSERT INTO public.role_grants (user_id, role) SELECT current_setting('k700.admin_id')::uuid, 'admin'
  ON CONFLICT DO NOTHING;

-- 2099 dates cannot collide with real rows. Day 1: all four launch events + other_event; day 3 empty; day 2 none.
INSERT INTO public.analytics_events (user_id, event_name, properties, created_at)
SELECT current_setting('k700.admin_id')::uuid, 'signup',       '{"secret":"x"}', '2099-01-01 10:00+00' UNION ALL
SELECT current_setting('k700.admin_id')::uuid, 'signup',       '{}',             '2099-01-01 23:59:59+00' UNION ALL
SELECT current_setting('k700.plain_id')::uuid, 'game_created', '{}',             '2099-01-01 11:00+00' UNION ALL
SELECT current_setting('k700.plain_id')::uuid, 'game_joined',  '{}',             '2099-01-01 12:00+00' UNION ALL
SELECT current_setting('k700.admin_id')::uuid, 'check_in',     '{}',             '2099-01-03 00:00:00+00' UNION ALL
SELECT current_setting('k700.admin_id')::uuid, 'other_event',  '{}',             '2099-01-01 13:00+00';

-- P1: admin gets rows, counts right, other_event excluded, empty day has no row.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', current_setting('k700.admin_id')::uuid, 'role', 'authenticated')::text, true);
DO $$
DECLARE n int; s bigint; d2 int; oth int;
BEGIN
  SELECT count(*), sum(events) INTO n, s FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-03');
  IF n <> 4 OR s <> 5 THEN RAISE EXCEPTION 'P1 FAIL: rows=% events=% (want 4 rows, 5 events)', n, s; END IF;
  SELECT count(*) INTO d2 FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-03') WHERE day = '2099-01-02';
  IF d2 <> 0 THEN RAISE EXCEPTION 'P1 FAIL: day with no events returned a row'; END IF;
  SELECT count(*) INTO oth FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-03') WHERE event_name = 'other_event';
  IF oth <> 0 THEN RAISE EXCEPTION 'P1 FAIL: other_event was counted'; END IF;
  SELECT events INTO s FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-01') WHERE event_name = 'signup';
  IF s <> 2 THEN RAISE EXCEPTION 'P1 FAIL: signup events=% (want 2; 23:59:59 UTC belongs to day 1)', s; END IF;
  RAISE NOTICE 'P1 ok';
END $$;

-- P2: output columns are exactly day, event_name, events, distinct_users (no properties, no user id).
DO $$
DECLARE cols text;
BEGIN
  SELECT string_agg(nm, ',' ORDER BY ord) INTO cols
    FROM pg_proc p, LATERAL unnest(p.proargnames, p.proargmodes) WITH ORDINALITY AS u(nm, md, ord)
   WHERE p.oid = 'public.rpc_admin_launch_funnel(date,date)'::regprocedure AND u.md = 't';
  IF cols <> 'day,event_name,events,distinct_users' THEN RAISE EXCEPTION 'P2 FAIL: columns=%', cols; END IF;
  RAISE NOTICE 'P2 ok';
END $$;

-- P3: span over 92 days raises; exactly 92 is allowed; reversed range raises.
DO $$
BEGIN
  PERFORM count(*) FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-04-02');   -- 92 days
  BEGIN
    PERFORM count(*) FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-04-03'); -- 93 days
    RAISE EXCEPTION 'P3 FAIL: 93-day span did not raise';
  EXCEPTION WHEN sqlstate '22023' THEN NULL;
  END;
  BEGIN
    PERFORM count(*) FROM public.rpc_admin_launch_funnel('2099-01-03', '2099-01-01');
    RAISE EXCEPTION 'P3 FAIL: reversed range did not raise';
  EXCEPTION WHEN sqlstate '22023' THEN NULL;
  END;
  RAISE NOTICE 'P3 ok';
END $$;

-- P4: authenticated non-admin raises 42501.
SELECT set_config('request.jwt.claims',
  json_build_object('sub', current_setting('k700.plain_id')::uuid, 'role', 'authenticated')::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-03');
    RAISE EXCEPTION 'P4 FAIL: non-admin was served';
  EXCEPTION WHEN sqlstate '42501' THEN NULL;
  END;
  RAISE NOTICE 'P4 ok';
END $$;

-- P5: anon cannot execute.
RESET ROLE;
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.rpc_admin_launch_funnel(date,date)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 FAIL: anon has EXECUTE';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.rpc_admin_launch_funnel(date,date)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.rpc_admin_launch_funnel(date,date)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 FAIL: authenticated/service_role lack EXECUTE';
  END IF;
  RAISE NOTICE 'P5 ok';
END $$;
SET LOCAL ROLE anon;
DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM public.rpc_admin_launch_funnel('2099-01-01', '2099-01-03');
    RAISE EXCEPTION 'P5 FAIL: anon call succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;   -- 42501
  END;
  RAISE NOTICE 'P5b ok';
END $$;
RESET ROLE;

ROLLBACK;
