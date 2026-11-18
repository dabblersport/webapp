-- KAN-986 [W1-B8] housekeeping + KAN-1011 grants: live test pack.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117164404_kan986_housekeeping_grants.sql. BEGIN ... ROLLBACK:
-- the retention run below deletes the real 90-day backlog INSIDE the transaction only; nothing persists.
-- A = dabbler.pro@proton.me, B = jidep35093@iconcubic.com.
--
--  R1  a row 91 days old is deleted; NEGATIVE CONTROL: a row 89 days old stays
--  R2  an unread security notice 91 days old stays; the same notice read is deleted
--  R3  a game.join_request 91 days old stays while its request is pending; NEGATIVE CONTROL: one without a pending
--      request is deleted
--  R4  a period under 90 days is refused (22023)
--  R5  batches: p_batch 100 deletes the backlog in several batches
--  J1  cron_job_run_details_prune deletes only runs older than 7 days (NEGATIVE CONTROL: recent count unchanged)
--  G1  anon: rpc_cancel_game, rpc_leave_game, notifications SELECT, mark_notification_read -> 42501
--  G2  NEGATIVE CONTROL: authenticated reaches rpc_cancel_game (business error, not 42501), reads its inbox and the
--      Activity log view, runs mark_notification_read; anon still runs rpc_username_availability
--  G3  sequences: anon and authenticated nextval / setval -> 42501; NEGATIVE CONTROL: service_role nextval works
--  G4  MAINTAIN: authenticated LOCK ... ACCESS EXCLUSIVE on notification_kinds -> 42501
--  T1  anon rpc_track_event('flags_snapshot') works (KAN-109); NEGATIVE CONTROL: another event name is refused by the
--      function's own rule (42501 'not permitted for unauthenticated callers'), not by a missing grant
--  K1  catalogue: no client grant on any public sequence, 16 anon rpc_* left (15 read-only + rpc_track_event)
--
-- Run history: 2026-11-17 backend-2, one full run after 20261117164404: 28/28 PASS (retention run inside the rolled-back
-- transaction deleted 611 = 608 real backlog + 3 test rows, in 7 batches of 100; kept the 2 open-action rows).

BEGIN;
CREATE TEMP TABLE pr (n int GENERATED ALWAYS AS IDENTITY, name text, expected text, actual text) ON COMMIT DROP;
GRANT ALL ON pr TO anon, authenticated, service_role;
CREATE FUNCTION pg_temp.r(a text, b text, c text) RETURNS void LANGUAGE sql AS $$ INSERT INTO pg_temp.pr(name, expected, actual) VALUES (a, b, c) $$;
GRANT EXECUTE ON FUNCTION pg_temp.r(text, text, text) TO anon, authenticated, service_role;
CREATE TEMP TABLE ids ON COMMIT DROP AS
SELECT (SELECT id FROM auth.users WHERE email = 'dabbler.pro@proton.me') a,
       (SELECT id FROM auth.users WHERE email = 'jidep35093@iconcubic.com') b,
       (SELECT min(p.id::text)::uuid FROM profiles p WHERE p.user_id = (SELECT id FROM auth.users WHERE email = 'jidep35093@iconcubic.com')) b_profile,
       (SELECT e.id FROM events e JOIN games g ON g.event_id = e.id WHERE e.event_type = 'game'
         AND NOT EXISTS (SELECT 1 FROM game_join_requests j WHERE j.game_id = e.id
                          AND j.from_user_id = (SELECT id FROM auth.users WHERE email = 'jidep35093@iconcubic.com'))
         ORDER BY e.created_at DESC LIMIT 1) game;
GRANT SELECT ON ids TO anon, authenticated, service_role;
CREATE TEMP TABLE t ON COMMIT DROP AS SELECT
  gen_random_uuid() old91, gen_random_uuid() new89, gen_random_uuid() sec_unread, gen_random_uuid() sec_read,
  gen_random_uuid() jr_open, gen_random_uuid() jr_closed;
GRANT SELECT ON t TO anon, authenticated, service_role;

INSERT INTO notifications (id, to_user_id, kind_key, title, context, priority, is_read, created_at)
SELECT old91, (SELECT a FROM ids), 'social.post_liked', 'kan986 91d', '{}'::jsonb, 'normal'::notify_priority, false, now() - interval '91 days' FROM t
UNION ALL SELECT new89, (SELECT a FROM ids), 'social.post_liked', 'kan986 89d', '{}', 'normal', false, now() - interval '89 days' FROM t
UNION ALL SELECT sec_unread, (SELECT a FROM ids), 'security.new_signin', 'kan986 sec unread', '{}', 'high', false, now() - interval '91 days' FROM t
UNION ALL SELECT sec_read, (SELECT a FROM ids), 'security.new_signin', 'kan986 sec read', '{}', 'high', true, now() - interval '91 days' FROM t
UNION ALL SELECT jr_open, (SELECT a FROM ids), 'game.join_request', 'kan986 jr open',
  jsonb_build_object('entity_id', (SELECT game FROM ids), 'actor_user_id', (SELECT b FROM ids)), 'normal', false, now() - interval '91 days' FROM t
UNION ALL SELECT jr_closed, (SELECT a FROM ids), 'game.join_request', 'kan986 jr closed',
  jsonb_build_object('entity_id', gen_random_uuid(), 'actor_user_id', (SELECT b FROM ids)), 'normal', false, now() - interval '91 days' FROM t;
INSERT INTO game_join_requests (game_id, from_profile_id, from_user_id, status)
SELECT game, b_profile, b, 'pending' FROM ids;

SELECT pg_temp.r('R4 under 90 days refused', '22023', (SELECT CASE WHEN true THEN NULL END));
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM public.notifications_retention_run(89); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  UPDATE pg_temp.pr SET actual = v WHERE name = 'R4 under 90 days refused';
END $x$;

CREATE TEMP TABLE run ON COMMIT DROP AS SELECT public.notifications_retention_run(90, 100) j;
SELECT pg_temp.r('R5 batches of 100: deleted >= 610 in >= 7 batches', 'true',
  ((SELECT (j ->> 'deleted')::int >= 610 AND (j ->> 'batches')::int >= 7 FROM run))::text);
SELECT pg_temp.r('R1 91-day row deleted; NC 89-day row kept', 'false|true',
  (SELECT EXISTS (SELECT 1 FROM notifications WHERE id = t.old91)::text || '|' || EXISTS (SELECT 1 FROM notifications WHERE id = t.new89)::text FROM t));
SELECT pg_temp.r('R2 unread security kept; read security deleted', 'true|false',
  (SELECT EXISTS (SELECT 1 FROM notifications WHERE id = t.sec_unread)::text || '|' || EXISTS (SELECT 1 FROM notifications WHERE id = t.sec_read)::text FROM t));
SELECT pg_temp.r('R3 pending join request kept; NC closed one deleted', 'true|false',
  (SELECT EXISTS (SELECT 1 FROM notifications WHERE id = t.jr_open)::text || '|' || EXISTS (SELECT 1 FROM notifications WHERE id = t.jr_closed)::text FROM t));
SELECT pg_temp.r('R5 nothing older than 90 days left except the kept open-action rows', '2',
  (SELECT count(*)::text FROM notifications WHERE created_at < now() - interval '90 days'));
SELECT pg_temp.r('R5 run result (info)', 'info', (SELECT j::text FROM run));

CREATE TEMP TABLE jrd ON COMMIT DROP AS SELECT
  (SELECT count(*) FROM cron.job_run_details WHERE coalesce(end_time, start_time) >= now() - interval '7 days') recent,
  (SELECT count(*) FROM cron.job_run_details WHERE coalesce(end_time, start_time) <  now() - interval '7 days') old;
SELECT pg_temp.r('J1 prune 1000 old runs', '1000', public.cron_job_run_details_prune('7 days', 1000, 1)::text);
SELECT pg_temp.r('J1 NC recent runs untouched, old ones down by 1000', 'true',
  ((SELECT count(*) FROM cron.job_run_details WHERE coalesce(end_time, start_time) >= now() - interval '7 days') >= (SELECT recent FROM jrd)
   AND (SELECT count(*) FROM cron.job_run_details WHERE coalesce(end_time, start_time) < now() - interval '7 days') = (SELECT old FROM jrd) - 1000)::text);
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM public.cron_job_run_details_prune('1 hour'); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('J1 keep under 1 day refused', '22023', v);
END $x$;

-- G1 anon
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SET LOCAL ROLE anon;
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM public.rpc_cancel_game(gen_random_uuid(), 'x'); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G1 anon rpc_cancel_game', '42501', v);
  BEGIN PERFORM public.rpc_leave_game('x', gen_random_uuid()); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G1 anon rpc_leave_game', '42501', v);
  BEGIN PERFORM count(*) FROM public.notifications; v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G1 anon reads notifications', '42501', v);
  BEGIN PERFORM public.mark_notification_read(gen_random_uuid()); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G1 anon mark_notification_read', '42501', v);
  BEGIN PERFORM nextval('public.wallet_ledger_id_seq'); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G3 anon nextval wallet_ledger_id_seq', '42501', v);
  BEGIN PERFORM setval('public.username_attempts_id_seq', 1); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G3 anon setval username_attempts_id_seq', '42501', v);
  BEGIN PERFORM public.rpc_username_availability('kan986probe'); v := 'reached'; EXCEPTION WHEN insufficient_privilege THEN v := SQLSTATE; WHEN OTHERS THEN v := 'reached'; END;
  PERFORM pg_temp.r('G2 NC anon still runs rpc_username_availability', 'reached', v);
  BEGIN PERFORM public.rpc_track_event('flags_snapshot', '{"kan986":"probe"}'::jsonb); v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE || ':' || SQLERRM; END;
  PERFORM pg_temp.r('T1 anon rpc_track_event flags_snapshot accepted', 'ok', v);
  BEGIN PERFORM public.rpc_track_event('kan986_other_event', '{}'::jsonb); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE || ':' || (SQLERRM LIKE '%not permitted for unauthenticated%')::text; END;
  PERFORM pg_temp.r('T1 NC anon other event refused by the function rule (not by the grant)', '42501:true', v);
END $x$;
RESET ROLE;

-- G2 authenticated (A)
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT a FROM ids), 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM public.rpc_cancel_game(gen_random_uuid(), 'x'); v := 'accepted'; EXCEPTION WHEN insufficient_privilege THEN v := SQLSTATE; WHEN OTHERS THEN v := 'reached:' || SQLSTATE; END;
  PERFORM pg_temp.r('G2 NC authenticated reaches rpc_cancel_game (not 42501)', 'true', (v <> '42501')::text);
  BEGIN PERFORM count(*) FROM public.notifications WHERE to_user_id = (SELECT a FROM pg_temp.ids); v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G2 A reads its inbox', 'ok', v);
  BEGIN PERFORM 1 FROM public.v_activity_inbox LIMIT 1; v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G2 A reads the Activity log view', 'ok', v);
  BEGIN PERFORM public.mark_notification_read((SELECT new89 FROM pg_temp.t)); v := 'ok'; EXCEPTION WHEN insufficient_privilege THEN v := SQLSTATE; WHEN OTHERS THEN v := 'reached:' || SQLSTATE; END;
  PERFORM pg_temp.r('G2 A runs mark_notification_read', 'true', (v <> '42501')::text);
  BEGIN PERFORM nextval('public.content_draft_events_id_seq'); v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G3 authenticated nextval content_draft_events_id_seq', '42501', v);
  BEGIN LOCK TABLE public.notification_kinds IN ACCESS EXCLUSIVE MODE; v := 'accepted'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G4 authenticated LOCK ACCESS EXCLUSIVE notification_kinds (MAINTAIN gone)', '42501', v);
END $x$;
RESET ROLE;
SELECT set_config('request.jwt.claims', json_build_object('sub', (SELECT b FROM ids), 'role', 'authenticated')::text, true);
SET LOCAL ROLE authenticated;
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM count(*) FROM public.notifications WHERE to_user_id = (SELECT b FROM pg_temp.ids); v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G2 B reads its inbox', 'ok', v);
  BEGIN PERFORM 1 FROM public.v_activity_inbox LIMIT 1; v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G2 B reads the Activity log view', 'ok', v);
END $x$;
RESET ROLE;

SET LOCAL ROLE service_role;
DO $x$ DECLARE v text; BEGIN
  BEGIN PERFORM nextval('public.wallet_ledger_id_seq'); v := 'ok'; EXCEPTION WHEN OTHERS THEN v := SQLSTATE; END;
  PERFORM pg_temp.r('G3 NC service_role nextval works', 'ok', v);
END $x$;
RESET ROLE;

SELECT pg_temp.r('K1 client grants on public sequences', '0',
  (SELECT count(*)::text FROM pg_class c, aclexplode(c.relacl) a WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S'
     AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole)));
SELECT pg_temp.r('K1 anon-executable volatile rpc_* left (15 read-only + rpc_track_event)', '16',
  (SELECT count(*)::text FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f' AND p.provolatile = 'v'
     AND p.proname LIKE 'rpc\_%' AND has_function_privilege('anon', p.oid, 'EXECUTE')));

SELECT n, CASE WHEN expected = 'info' OR expected IS NOT DISTINCT FROM actual THEN 'PASS' ELSE 'FAIL' END verdict, name, expected, actual
  FROM pr ORDER BY n;
ROLLBACK;
