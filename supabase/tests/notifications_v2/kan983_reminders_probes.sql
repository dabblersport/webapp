-- KAN-983 [W1-B5] Reminders: live probe pack for 20261117102448_kan983_reminders.sql.
-- Run as postgres on wtncuzcskpigqpmnxwws. One DO block that ends in RAISE EXCEPTION, so every write rolls back and
-- the exception message carries the results. Nothing persists, and nothing is pushed (pg_net's queue is a table and
-- rolls back with the block).
-- The worker and planner take p_now, so the block walks a clock across the ladder without waiting.
-- Fixtures: the three latest open upcoming meetups (M1, M2, M3) and the latest open upcoming game (G), moved to fixed
-- local times; eight users with one active profile who are in none of them.
--
--   P1  Going, M1 at 18:30 local in 3 days           -> 4 jobs: 24h, 09:00, 2h, 30m (meetup.reminder)
--   P2  Interested, M1                               -> 4 jobs; 09:00 is meetup.confirm_attendance
--   P3  09:00 skipped: M2 at 10:00 local             -> 3 jobs, no 09:00
--   P4  late join at T-3h                            -> only 2h and 30m planned
--   S1  worker at T-24h                              -> 24h sent, title rendered
--   S2  worker run twice at the same clock           -> second run claims nothing; 1 notification
--   S3  replay after a crash (job reset to pending)  -> notify_v2 dedupe keeps 1 notification
--   N1  NEGATIVE CONTROL: same replay with the dedupe key changed -> a 2nd notification appears
--   S4  worker at 09:00 local                        -> Going gets meetup.reminder; Interested gets the confirm card
--   S5  Going on the card                            -> status going, the 2h and 30m rungs stay
--   S6  Not going on the card                        -> cancelled, its pending jobs are gone, nothing more is sent
--   S7  rung 2h switched off for one user            -> 2h skipped rung_disabled, 30m sent
--   S8  left between claim and send (30m)            -> skipped not_participant; the others' 30m sent
--   S9  30m sent; no activity.starting_soon kind
--   S10 expired: M2's 30m job first reached after its expiry -> skipped expired, not sent late
--   R1  reschedule while claimed (G)                 -> old job skipped revision_changed; 4 jobs re-planned at rev+1
--   R2  removal from the game (status kicked)        -> pending jobs gone
--   C1  cancel while claimed (M3)                    -> skipped event_cancelled; pending gone after sync; 0 sent
--   G1  authenticated and anon: notification_jobs and reminder_worker_run refused 42501
--
-- Dry run 2026-11-17 by backend-7 (BEGIN; the migration; this block; the block's exception rolled it all back,
-- migration NOT applied): backfill 144 jobs, cron job present; P1-P4 ok; S1 ok ("Dubai community workout starts
-- tomorrow at 6:30 PM"); S2 ok (claimed 0, 1 notification); S3 ok; N1 ok (2 notifications with the key changed);
-- S4 ok (card "Dubai community workout is today at 6:30 PM | Are you going? | ["going","not_going"]"); S5, S6, S6b,
-- S7, S8, S9 ok; S10 failed on the probe's own expectation (the 2h job was correctly sent at the 09:00 run) and was
-- corrected as below; R1 ok (re-planned 4 at rev 2, 0 sent); R2 ok; C1 ok; G1 ok x4.

DO $probe$
DECLARE
  r     text := '';
  m1 uuid; m2 uuid; m3 uuid; g uuid;
  u uuid[]; p uuid[];
  t1 timestamptz; t2 timestamptz; t3 timestamptz; tg timestamptz; nine timestamptz;
  n int; n2 int; s text; jid bigint; jid2 bigint; res text; ok boolean; v jsonb; ids bigint[]; k text; e text;
BEGIN
  SELECT id INTO m1 FROM public.events WHERE event_type = 'meetup' AND NOT is_cancelled AND join_policy = 'open'
     AND start_at > now() ORDER BY start_at DESC, id LIMIT 1;
  SELECT id INTO m2 FROM public.events WHERE event_type = 'meetup' AND NOT is_cancelled AND join_policy = 'open'
     AND start_at > now() AND id <> m1 ORDER BY start_at DESC, id LIMIT 1;
  SELECT id INTO m3 FROM public.events WHERE event_type = 'meetup' AND NOT is_cancelled AND join_policy = 'open'
     AND start_at > now() AND id NOT IN (m1, m2) ORDER BY start_at DESC, id LIMIT 1;
  SELECT id INTO g FROM public.events WHERE event_type = 'game' AND NOT is_cancelled AND join_policy = 'open'
     AND start_at > now() ORDER BY start_at DESC, id LIMIT 1;
  IF m1 IS NULL OR m2 IS NULL OR m3 IS NULL OR g IS NULL THEN
    RAISE EXCEPTION 'fixtures missing: m1 % m2 % m3 % g %', m1, m2, m3, g;
  END IF;

  SELECT array_agg(x.user_id ORDER BY x.created_at), array_agg(x.profile_id ORDER BY x.created_at) INTO u, p
    FROM (SELECT pr.user_id, pr.id AS profile_id, au.created_at
            FROM public.profiles pr JOIN auth.users au ON au.id = pr.user_id
           WHERE pr.is_active
             AND (SELECT count(*) FROM public.profiles p2 WHERE p2.user_id = pr.user_id AND p2.is_active) = 1
             AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps s0 WHERE s0.user_id = pr.user_id AND s0.meetup_id IN (m1, m2, m3))
             AND NOT EXISTS (SELECT 1 FROM public.game_roster r0 WHERE r0.user_id = pr.user_id AND r0.game_id = g)
           ORDER BY au.created_at LIMIT 8) x;
  IF cardinality(u) < 8 THEN RAISE EXCEPTION 'need 8 users, got %', cardinality(u); END IF;

  t1 := ((current_date + 3)::timestamp + time '18:30') AT TIME ZONE 'Asia/Dubai';
  t2 := ((current_date + 3)::timestamp + time '10:00') AT TIME ZONE 'Asia/Dubai';
  t3 := ((current_date + 4)::timestamp + time '18:30') AT TIME ZONE 'Asia/Dubai';
  tg := ((current_date + 5)::timestamp + time '18:30') AT TIME ZONE 'Asia/Dubai';
  nine := ((current_date + 3)::timestamp + time '09:00') AT TIME ZONE 'Asia/Dubai';

  UPDATE public.events SET start_at = t1, end_at = t1 + interval '1 hour', capacity = 50 WHERE id = m1;
  UPDATE public.events SET start_at = t2, end_at = t2 + interval '1 hour', capacity = 50 WHERE id = m2;
  UPDATE public.events SET start_at = t3, end_at = t3 + interval '1 hour', capacity = 50 WHERE id = m3;
  UPDATE public.events SET start_at = tg, end_at = tg + interval '1 hour', capacity = 20 WHERE id = g;
  PERFORM public.reminder_sync_event_changes();
  r := r || format(E'tz m1=%s m2=%s g=%s\n', public.event_timezone(m1), public.event_timezone(m2), public.event_timezone(g));

  -- P1
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[1], p[1], 'going');
  SELECT count(*), string_agg(rung || '@' || to_char(due_at AT TIME ZONE 'Asia/Dubai', 'DD HH24:MI') || '/' || kind_key, ', ' ORDER BY due_at)
    INTO n, s FROM public.notification_jobs WHERE event_id = m1 AND user_id = u[1] AND status = 'pending';
  ok := n = 4 AND s LIKE '24h@% 18:30/meetup.reminder, 09:00@% 09:00/meetup.reminder, 2h@% 16:30/meetup.reminder, 30m@% 18:00/meetup.reminder';
  r := r || format(E'P1 going ladder: %s (%s) %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n, s);

  -- P2 (and the user who will answer Going)
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[2], p[2], 'interested');
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[3], p[3], 'interested');
  SELECT count(*), string_agg(rung || '/' || kind_key, ', ' ORDER BY due_at)
    INTO n, s FROM public.notification_jobs WHERE event_id = m1 AND user_id = u[2] AND status = 'pending';
  ok := n = 4 AND s = '24h/meetup.reminder, 09:00/meetup.confirm_attendance, 2h/meetup.reminder, 30m/meetup.reminder';
  r := r || format(E'P2 interested ladder: %s (%s) %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n, s);

  -- P3
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m2, u[1], p[1], 'going');
  SELECT count(*), string_agg(rung, ',' ORDER BY due_at) INTO n, s
    FROM public.notification_jobs WHERE event_id = m2 AND user_id = u[1] AND status = 'pending';
  r := r || format(E'P3 10:00 event has no 09:00 rung: %s (%s) %s\n', CASE WHEN n = 3 AND s = '24h,2h,30m' THEN 'ok' ELSE 'FAIL' END, n, s);

  -- P4
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[4], p[4], 'going');
  PERFORM public.reminder_plan_member(m1, u[4], t1 - interval '3 hours');
  SELECT count(*), string_agg(rung, ',' ORDER BY due_at) INTO n, s
    FROM public.notification_jobs WHERE event_id = m1 AND user_id = u[4];
  r := r || format(E'P4 late join at T-3h: %s (%s) %s\n', CASE WHEN n = 2 AND s = '2h,30m' THEN 'ok' ELSE 'FAIL' END, n, s);

  -- more members of M1: rung 2h off (u7), leaves between claim and send (u8)
  INSERT INTO public.notification_settings (user_id) VALUES (u[7]) ON CONFLICT (user_id) DO NOTHING;
  UPDATE public.notification_settings SET reminder_rungs = jsonb_set(reminder_rungs, '{going,2h}', 'false') WHERE user_id = u[7];
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[7], p[7], 'going');
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m1, u[8], p[8], 'going');

  -- S1
  v := public.reminder_worker_run(500, t1 - interval '24 hours');
  SELECT j.id, j.status, nt.title INTO jid, s, k
    FROM public.notification_jobs j LEFT JOIN public.notifications nt ON nt.id = j.notification_id
   WHERE j.event_id = m1 AND j.user_id = u[1] AND j.rung = '24h';
  r := r || format(E'S1 24h sent: %s (%s) title=%s\n', CASE WHEN s = 'sent' AND k IS NOT NULL THEN 'ok' ELSE 'FAIL' END, s, k);

  -- S2
  v := public.reminder_worker_run(500, t1 - interval '24 hours');
  SELECT count(*) INTO n FROM public.notifications nt
   WHERE nt.to_user_id = u[1] AND nt.source_event_id = 'notification_jobs:' || jid;
  r := r || format(E'S2 second run: %s (claimed %s, notifications %s)\n',
                   CASE WHEN (v ->> 'claimed')::int = 0 AND n = 1 THEN 'ok' ELSE 'FAIL' END, v ->> 'claimed', n);

  -- S3
  UPDATE public.notification_jobs SET status = 'pending', notification_id = NULL, sent_at = NULL WHERE id = jid;
  v := public.reminder_worker_run(500, t1 - interval '24 hours');
  SELECT count(*) INTO n FROM public.notifications nt
   WHERE nt.to_user_id = u[1] AND nt.source_event_id = 'notification_jobs:' || jid;
  SELECT status INTO s FROM public.notification_jobs WHERE id = jid;
  r := r || format(E'S3 replay keeps one notification: %s (%s, %s)\n', CASE WHEN n = 1 AND s = 'sent' THEN 'ok' ELSE 'FAIL' END, s, n);

  -- N1 negative control
  UPDATE public.notification_jobs SET status = 'pending', notification_id = NULL, sent_at = NULL,
         dedupe_key = dedupe_key || ':negative-control' WHERE id = jid;
  v := public.reminder_worker_run(500, t1 - interval '24 hours');
  SELECT count(*) INTO n FROM public.notifications nt
   WHERE nt.to_user_id = u[1] AND nt.source_event_id = 'notification_jobs:' || jid;
  r := r || format(E'N1 NEGATIVE CONTROL changed dedupe key -> second send: %s (notifications %s)\n',
                   CASE WHEN n = 2 THEN 'ok (guard is what stops it)' ELSE 'FAIL' END, n);

  -- S4
  v := public.reminder_worker_run(500, nine);
  SELECT string_agg(j.user_id::text || '=' || j.status || '/' || nt.kind_key, ' ') INTO s
    FROM public.notification_jobs j LEFT JOIN public.notifications nt ON nt.id = j.notification_id
   WHERE j.event_id = m1 AND j.rung = '09:00' AND j.user_id IN (u[1], u[2], u[3]);
  ok := s LIKE '%' || u[1] || '=sent/meetup.reminder%' AND s LIKE '%' || u[2] || '=sent/meetup.confirm_attendance%'
    AND s LIKE '%' || u[3] || '=sent/meetup.confirm_attendance%';
  SELECT nt.title || ' | ' || coalesce(nt.body, '') || ' | ' || (nt.args -> 'actions')::text INTO k
    FROM public.notification_jobs j JOIN public.notifications nt ON nt.id = j.notification_id
   WHERE j.event_id = m1 AND j.rung = '09:00' AND j.user_id = u[2];
  r := r || format(E'S4 09:00 sent, card for Interested: %s card=%s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, k);

  -- S5 / S6: answer the card as the user
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u[3], 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  res := public.rpc_answer_meetup_attendance(m1, 'going');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u[2], 'role', 'authenticated')::text, true);
  k := public.rpc_answer_meetup_attendance(m1, 'not_going');
  EXECUTE 'RESET ROLE';
  SELECT count(*), string_agg(rung || '/' || audience, ',' ORDER BY due_at) INTO n, s
    FROM public.notification_jobs WHERE event_id = m1 AND user_id = u[3] AND status = 'pending';
  r := r || format(E'S5 Going on the card: %s (%s; pending %s %s)\n',
                   CASE WHEN res = 'going' AND n = 2 AND s = '2h/going,30m/going' THEN 'ok' ELSE 'FAIL' END, res, n, s);
  SELECT count(*) INTO n FROM public.notification_jobs WHERE event_id = m1 AND user_id = u[2] AND status = 'pending';
  r := r || format(E'S6 Not going on the card: %s (%s; pending %s)\n', CASE WHEN k = 'cancelled' AND n = 0 THEN 'ok' ELSE 'FAIL' END, k, n);

  -- S7
  v := public.reminder_worker_run(500, t1 - interval '2 hours');
  SELECT string_agg(user_id::text || '=' || status || coalesce(':' || skip_reason, ''), ' ') INTO s
    FROM public.notification_jobs WHERE event_id = m1 AND rung = '2h' AND user_id IN (u[1], u[3], u[4], u[7]);
  ok := s LIKE '%' || u[7] || '=skipped:rung_disabled%' AND s LIKE '%' || u[1] || '=sent%'
    AND s LIKE '%' || u[3] || '=sent%' AND s LIKE '%' || u[4] || '=sent%';
  r := r || format(E'S7 2h: off for one user, sent for the rest: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL ' || s END);

  -- S8 / S9
  ids := ARRAY(SELECT public.reminder_jobs_claim(500, t1 - interval '30 minutes'));
  UPDATE public.meetup_rsvps SET status = 'cancelled' WHERE meetup_id = m1 AND user_id = u[8];
  FOREACH jid2 IN ARRAY ids LOOP
    PERFORM public.reminder_job_process(jid2, t1 - interval '30 minutes');
  END LOOP;
  SELECT string_agg(user_id::text || '=' || status || coalesce(':' || skip_reason, ''), ' ') INTO s
    FROM public.notification_jobs WHERE event_id = m1 AND rung = '30m' AND user_id IN (u[1], u[7], u[8]);
  ok := s LIKE '%' || u[8] || '=skipped:not_participant%' AND s LIKE '%' || u[1] || '=sent%' AND s LIKE '%' || u[7] || '=sent%';
  r := r || format(E'S8 left between claim and send: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL ' || s END);
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = u[2] AND source_event_id LIKE 'notification_jobs:%'
     AND dedupe_key LIKE 'reminder:' || u[2] || ':' || m1 || ':%' AND (args ->> 'rung') IN ('2h', '30m');
  r := r || format(E'S6b Not going got no 2h/30m: %s (%s)\n', CASE WHEN n = 0 THEN 'ok' ELSE 'FAIL' END, n);
  r := r || format(E'S9 30m sent, no activity.starting_soon kind: %s\n',
                   CASE WHEN s LIKE '%' || u[1] || '=sent%' AND NOT EXISTS (SELECT 1 FROM public.notification_kinds WHERE key = 'activity.starting_soon')
                        THEN 'ok' ELSE 'FAIL' END);

  -- S10. M2 starts 10:00 local. Its 24h job went out in the S1 run, inside its window; its 2h job (due 08:00, expires
  -- 09:30) went out in the 09:00 run, inside its window; its 30m job (due 09:30, expires 10:00) was first reached by
  -- the 16:30 run, after expiry, so it is dropped, not sent late.
  v := public.reminder_worker_run(500, t2);
  SELECT string_agg(rung || '=' || status || coalesce(':' || skip_reason, ''), ',' ORDER BY due_at) INTO s
    FROM public.notification_jobs WHERE event_id = m2 AND user_id = u[1];
  r := r || format(E'S10 late job dropped: %s (%s)\n',
                   CASE WHEN s = '24h=sent,2h=sent,30m=skipped:expired' THEN 'ok' ELSE 'FAIL' END, s);

  -- R1
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (g, p[5], u[5], 'player', 'active');
  SELECT count(*) INTO n FROM public.notification_jobs WHERE event_id = g AND user_id = u[5] AND status = 'pending';
  ids := ARRAY(SELECT public.reminder_jobs_claim(500, tg - interval '24 hours'));
  SELECT id INTO jid FROM public.notification_jobs WHERE event_id = g AND user_id = u[5] AND rung = '24h';
  UPDATE public.events SET start_at = tg + interval '1 day', end_at = tg + interval '1 day 1 hour' WHERE id = g;
  res := public.reminder_job_process(jid, tg - interval '24 hours');
  PERFORM public.reminder_sync_event_changes(tg - interval '24 hours');
  SELECT count(*), min(schedule_revision) INTO n2, jid2 FROM public.notification_jobs
   WHERE event_id = g AND user_id = u[5] AND status = 'pending';
  SELECT count(*) INTO k FROM public.notifications WHERE to_user_id = u[5] AND kind_key = 'game.reminder';
  r := r || format(E'R1 reschedule while claimed: %s (planned %s, old job %s, re-planned %s at rev %s, game.reminder sent %s)\n',
                   CASE WHEN n = 4 AND res = 'skipped:revision_changed' AND n2 = 4
                         AND jid2 = (SELECT schedule_revision FROM public.events WHERE id = g) AND k = '0'
                        THEN 'ok' ELSE 'FAIL' END, n, res, n2, jid2, k);

  -- R2
  UPDATE public.game_roster SET status = 'kicked' WHERE game_id = g AND user_id = u[5];
  SELECT count(*) INTO n FROM public.notification_jobs WHERE event_id = g AND user_id = u[5] AND status = 'pending';
  r := r || format(E'R2 removal clears pending: %s (%s)\n', CASE WHEN n = 0 THEN 'ok' ELSE 'FAIL' END, n);

  -- C1
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m3, u[6], p[6], 'going');
  ids := ARRAY(SELECT public.reminder_jobs_claim(500, t3 - interval '24 hours'));
  SELECT id INTO jid FROM public.notification_jobs WHERE event_id = m3 AND user_id = u[6] AND rung = '24h';
  UPDATE public.events SET is_cancelled = true WHERE id = m3;
  res := public.reminder_job_process(jid, t3 - interval '24 hours');
  PERFORM public.reminder_sync_event_changes(t3 - interval '24 hours');
  v := public.reminder_worker_run(500, t3);
  SELECT count(*) INTO n FROM public.notification_jobs WHERE event_id = m3 AND user_id = u[6] AND status IN ('pending', 'claimed', 'sent');
  SELECT count(*) INTO n2 FROM public.notifications WHERE to_user_id = u[6] AND kind_key = 'meetup.reminder';
  r := r || format(E'C1 cancel before send: %s (%s, live jobs %s, sent %s)\n',
                   CASE WHEN res = 'skipped:event_cancelled' AND n = 0 AND n2 = 0 THEN 'ok' ELSE 'FAIL' END, res, n, n2);

  -- G1
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u[1], 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN PERFORM 1 FROM public.notification_jobs LIMIT 1; r := r || E'G1 authenticated select: FAIL (allowed)\n';
  EXCEPTION WHEN insufficient_privilege THEN r := r || E'G1 authenticated select: ok 42501\n'; END;
  BEGIN PERFORM public.reminder_worker_run(); r := r || E'G1 authenticated worker: FAIL (allowed)\n';
  EXCEPTION WHEN insufficient_privilege THEN r := r || E'G1 authenticated worker: ok 42501\n'; END;
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  PERFORM set_config('role', 'anon', true);
  BEGIN PERFORM 1 FROM public.notification_jobs LIMIT 1; r := r || E'G1 anon select: FAIL (allowed)\n';
  EXCEPTION WHEN insufficient_privilege THEN r := r || E'G1 anon select: ok 42501\n'; END;
  BEGIN PERFORM public.rpc_answer_meetup_attendance(m1, 'going'); r := r || E'G1 anon answer: FAIL (allowed)\n';
  EXCEPTION WHEN insufficient_privilege THEN r := r || E'G1 anon answer: ok 42501\n'; END;
  EXECUTE 'RESET ROLE';

  RAISE EXCEPTION E'KAN-983 RESULTS\n%', r;
END
$probe$;

-- KAN-983b (PEER 16444): rpc_answer_meetup_attendance(id, 'going') refuses what rpc_meetup_rsvp refuses.
-- Each case is checked on an Interested member of an open public meetup, then the condition is removed and the same
-- user answers again (the control) and becomes Going. Expected after 20261117103719_kan983b: every line "ok".
--   E1 frozen                  -> not_allowed ; control (freeze lifted) -> going
--   E2 meetup not visible      -> not_visible ; control (public again)  -> going
--   E3 blocked by the host     -> not_visible ; control (block removed) -> going
--   E4 caller blocks the host  -> not_visible ; control (block removed) -> going
DO $probe_b$
DECLARE
  r text := ''; m uuid; host uuid; u uuid[]; p uuid[]; res text; i int;
BEGIN
  SELECT e.id, e.creator_user_id INTO m, host FROM public.events e
   WHERE e.event_type = 'meetup' AND NOT e.is_cancelled AND e.join_policy = 'open' AND e.listing_visibility = 'public'
     AND e.start_at > now() + interval '1 day' ORDER BY e.start_at DESC, e.id LIMIT 1;
  SELECT array_agg(x.user_id ORDER BY x.created_at), array_agg(x.profile_id ORDER BY x.created_at) INTO u, p
    FROM (SELECT pr.user_id, pr.id AS profile_id, au.created_at
            FROM public.profiles pr JOIN auth.users au ON au.id = pr.user_id
           WHERE pr.is_active AND pr.user_id <> host
             AND (SELECT count(*) FROM public.profiles p2 WHERE p2.user_id = pr.user_id AND p2.is_active) = 1
             AND NOT public.is_frozen(pr.user_id)
             AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps s0 WHERE s0.user_id = pr.user_id AND s0.meetup_id = m)
             AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE (b.blocker_user_id = pr.user_id AND b.blocked_user_id = host)
                                                                OR (b.blocker_user_id = host AND b.blocked_user_id = pr.user_id))
           ORDER BY au.created_at LIMIT 4) x;
  UPDATE public.events SET capacity = 500 WHERE id = m;
  FOR i IN 1..4 LOOP
    INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m, u[i], p[i], 'interested');
  END LOOP;

  -- conditions
  INSERT INTO public.user_freezes (user_id, is_frozen, is_active, reason, frozen_at) VALUES (u[1], true, true, 'kan983b probe', now());
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (host, u[3]);
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (u[4], host);

  FOR i IN 1..4 LOOP
    IF i = 2 THEN UPDATE public.events SET listing_visibility = 'hidden' WHERE id = m; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u[i], 'role', 'authenticated')::text, true);
    PERFORM set_config('role', 'authenticated', true);
    BEGIN
      res := public.rpc_answer_meetup_attendance(m, 'going');
    EXCEPTION WHEN OTHERS THEN
      res := 'refused:' || SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    IF i = 2 THEN UPDATE public.events SET listing_visibility = 'public' WHERE id = m; END IF;
    r := r || format(E'E%s %s: %s (%s)\n', i,
                     CASE i WHEN 1 THEN 'frozen' WHEN 2 THEN 'not visible' WHEN 3 THEN 'blocked by host' ELSE 'blocks host' END,
                     CASE WHEN res = 'refused:' || CASE i WHEN 1 THEN 'not_allowed' ELSE 'not_visible' END THEN 'ok' ELSE 'FAIL' END,
                     res);
  END LOOP;

  -- controls: remove each condition, same user answers again
  UPDATE public.user_freezes SET is_frozen = false, lifted_at = now() WHERE user_id = u[1] AND reason = 'kan983b probe';
  DELETE FROM public.user_blocks WHERE blocker_user_id = host AND blocked_user_id = u[3];
  DELETE FROM public.user_blocks WHERE blocker_user_id = u[4] AND blocked_user_id = host;
  FOR i IN 1..4 LOOP
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u[i], 'role', 'authenticated')::text, true);
    PERFORM set_config('role', 'authenticated', true);
    BEGIN
      res := public.rpc_answer_meetup_attendance(m, 'going');
    EXCEPTION WHEN OTHERS THEN
      res := 'refused:' || SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    r := r || format(E'E%s control: %s (%s)\n', i, CASE WHEN res = 'going' THEN 'ok' ELSE 'FAIL' END, res);
  END LOOP;

  RAISE EXCEPTION E'KAN-983b RESULTS\n%', r;
END
$probe_b$;
