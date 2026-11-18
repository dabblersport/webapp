-- KAN-996 [W2-B3] results: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118112808_kan996_results.sql. Everything (including the pg_temp
-- helpers) is in one transaction that ends in RAISE EXCEPTION, so nothing persists.
-- Fixtures: three game Events G1 = 96949cc9, G2 = 1ad6aec2, G3 = 1e2d9f57, re-owned by organiser U = a3ba3271 in the
-- transaction, set competitive (casual, team_ball sport), ended (KAN-995 lifecycle) with finalized attendance (KAN-994):
-- P1..P8 attended, X no_show_confirmed (the non-attendee). Meetup M = 1b6df962 for the non-competitive case.
-- Calls run as authenticated with request.jwt.claims. The sweep takes p_now, so 24h is simulated by passing now()+25h.

CREATE OR REPLACE FUNCTION pg_temp.kan996_as(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE e text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN EXECUTE p_sql; e := 'ok'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  RETURN e;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.kan996_fixture(p_ev uuid, p_org uuid, p_players uuid[], p_x uuid) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.events SET creator_user_id = p_org, is_cancelled = false, cancelled_at = NULL,
         sport_id = '57dcaa58-e8c8-4ae7-9a35-3ddeef79d3e9',
         start_at = now() - interval '3 hours', end_at = now() - interval '2 hours' WHERE id = p_ev;
  UPDATE public.games SET game_type = 'casual' WHERE event_id = p_ev;
  DELETE FROM public.event_lifecycle WHERE event_id = p_ev;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_ended_at, closed_at, closed_reason)
  VALUES (p_ev, 'game', 'ended', now() - interval '2 hours', now() - interval '2 hours', 'played');
  DELETE FROM public.event_results WHERE event_id = p_ev;
  DELETE FROM public.event_attendance WHERE event_id = p_ev;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = p_ev;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
  SELECT p_ev, 'game', u, 'attended', now() - interval '1 hour' FROM unnest(p_players) u;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
  VALUES (p_ev, 'game', p_x, 'no_show_confirmed', now() - interval '1 hour');
  INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto)
  VALUES (p_ev, now() - interval '1 hour', p_org, false);
END $f$;

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  p uuid[] := ARRAY['036735b7-2668-4fc6-9ec3-dceb8b95ea33','039a9d4a-8c8d-48e1-8dff-327c1c615179',
                    '043b384d-f5ff-4c0a-b16c-dbf31f26e5a3','09916fe0-bb49-4c0b-8a1b-fc5cd6cad1da',
                    '0a8453c4-f3bf-4864-a36e-923ba191c48d','0d07f76f-0291-4350-8502-0fa5a471ca5c',
                    '0d545d68-e02f-4f46-bd08-60c7e28cf7be','13d00e2d-86f8-4d7b-8b7f-c1a8d32f4455']::uuid[];
  x uuid := '143507a6-5379-4c68-a25d-63a362bbd663';
  g1 uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  g2 uuid := '1ad6aec2-639a-4a0e-b95f-05399cbe85d1';
  g3 uuid := '1e2d9f57-3eaa-444d-87ee-0ff203282709';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  e text; e2 text; e3 text; j jsonb; c int; c2 int; r record; i int; t0 timestamptz := now();
BEGIN
  DELETE FROM public.user_blocks WHERE blocker_user_id = ANY (p || u) OR blocked_user_id = ANY (p || u);
  UPDATE public.profiles SET language = 'en' WHERE user_id = ANY (p || u);
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  PERFORM pg_temp.kan996_fixture(g2, u, p, x);
  PERFORM pg_temp.kan996_fixture(g3, u, p, x);

  ------------------------------------------------------------------- C1 majority: 6 say 4-3, 2 say 3-3 -> provisional 4-3
  FOR i IN 1..7 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, %s, 3, %L)', g1,
                                        CASE WHEN i <= 6 THEN 4 ELSE 3 END, CASE WHEN i <= 4 THEN 'a' ELSE 'b' END));
  END LOOP;
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.result_ready'
     AND source_event_id = 'result:' || g1 AND created_at >= t0;
  e := pg_temp.kan996_as(p[8], format('SELECT public.rpc_result_submit(%L, 3, 3, %L)', g1, 'b'));
  SELECT * INTO r FROM public.results_tally(g1);
  SELECT args->>'summary' INTO e2 FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.result_ready'
     AND source_event_id = 'result:' || g1 AND created_at >= t0;
  n := n + 1;
  IF e = 'ok' AND r.score_a = 4 AND r.score_b = 3 AND r.votes = 6 AND r.submissions = 8 AND r.eligible = 8 AND c = 0
     AND e2 = '6 of 8 said 4 – 3' THEN
    tap := tap || format(E'ok %s - 6 of 8 say 4-3, 2 say 3-3: provisional 4-3; organiser told "%s" only once all 8 had submitted\n', n, e2);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - majority: %s %s/%s votes %s subs %s pre %s notice %s\n', n, e, r.score_a, r.score_b, r.votes, r.submissions, c, e2); END IF;

  -- negative controls: the non-attendee and the organiser cannot submit; nothing is counted
  e := pg_temp.kan996_as(x, format('SELECT public.rpc_result_submit(%L, 0, 9, %L)', g1, 'a'));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_submit(%L, 0, 9, %L)', g1, 'a'));
  SELECT * INTO r FROM public.results_tally(g1);
  n := n + 1;
  IF e = 'not_eligible' AND e2 = 'not_eligible' AND r.submissions = 8 AND r.votes = 6
     AND NOT EXISTS (SELECT 1 FROM public.event_result_submissions WHERE event_id = g1 AND user_id IN (x, u)) THEN
    tap := tap || format(E'ok %s - negative control: non-attendee (%s) and organiser (%s) refused, not counted\n', n, e, e2);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - non-attendee %s organiser %s subs %s\n', n, e, e2, r.submissions); END IF;

  ------------------------------------------------------------------------------------------------------- C2 approve
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_approve(%L)', g1));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g1));
  SELECT count(*) INTO c FROM public.notifications WHERE kind_key = 'activity.result_confirmed'
     AND source_event_id = 'result:' || g1 AND to_user_id = ANY (p) AND created_at >= t0;
  n := n + 1;
  IF e = 'not_organiser' AND e2 = 'ok' AND c = 8 AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1
       AND status = 'confirmed' AND score_a = 4 AND score_b = 3 AND winning_side = 'a' AND confirm_method = 'approved'
       AND confirmed_by = u AND revision = 2)
     AND (SELECT count(*) FROM public.event_result_revisions WHERE event_id = g1) = 1 THEN
    tap := tap || format(E'ok %s - a player cannot approve (%s); organiser approves: 4-3 confirmed, revision 2, 8 players told\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - approve: %s / %s told %s\n', n, e, e2, c); END IF;

  -- no overwrite after confirmation
  e := pg_temp.kan996_as(p[7], format('SELECT public.rpc_result_submit(%L, 3, 3, %L)', g1, 'b'));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_set_final(%L, 0, 0)', g1));
  e3 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g1));
  n := n + 1;
  IF e = 'result_final' AND e2 = 'result_final' AND e3 = 'result_final'
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1 AND score_a = 4 AND score_b = 3 AND revision = 2) THEN
    tap := tap || format(E'ok %s - after confirmation a player cannot resubmit and the organiser cannot re-enter or re-approve (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - overwrite: %s %s %s\n', n, e, e2, e3); END IF;

  ------------------------------------------------------------------------------------------- C3 reject + enter final
  FOR i IN 1..8 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, %s, %s, %L)', g2,
           CASE WHEN i <= 5 THEN 1 ELSE 0 END, CASE WHEN i <= 5 THEN 0 ELSE 1 END, CASE WHEN i <= 4 THEN 'a' ELSE 'b' END));
  END LOOP;
  e := pg_temp.kan996_as(u, format('SELECT public.rpc_result_set_final(%L, 0, 2)', g2));
  SELECT count(*) INTO c FROM public.notifications WHERE kind_key = 'activity.result_corrected'
     AND source_event_id = 'result:' || g2 AND to_user_id = ANY (p) AND created_at >= t0;
  n := n + 1;
  IF e = 'ok' AND c = 8 AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g2 AND status = 'confirmed'
       AND score_a = 0 AND score_b = 2 AND winning_side = 'b' AND confirm_method = 'organiser_final') THEN
    tap := tap || format(E'ok %s - provisional 1-0 rejected: the organiser''s final 0-2 is official, players told (corrected)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - reject: %s told %s\n', n, e, c); END IF;

  ------------------------------------------------------------------------------------- C4 24h auto-confirm (sweep)
  FOR i IN 1..4 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, %s, %s, %L)', g3,
           CASE WHEN i <= 3 THEN 5 ELSE 1 END, CASE WHEN i <= 3 THEN 1 ELSE 5 END, CASE WHEN i <= 3 THEN 'a' ELSE 'b' END));
  END LOOP;
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.result_ready'
     AND source_event_id = 'result:' || g3 AND created_at >= t0;
  j := public.results_sweep(now() + interval '3 hours');
  SELECT count(*) INTO c2 FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.result_ready'
     AND source_event_id = 'result:' || g3 AND created_at >= t0;
  n := n + 1;
  IF c = 0 AND c2 = 1 AND (SELECT status FROM public.event_results WHERE event_id = g3) = 'open' THEN
    tap := tap || format(E'ok %s - 4 of 8 submitted: no notice until the sweep 2h+ later, then one; still open before 24h\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - 2h notice %s -> %s %s\n', n, c, c2, j); END IF;

  j := public.results_sweep(now() + interval '25 hours');
  n := n + 1;
  IF (j->>'auto_confirmed')::int >= 1 AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g3
       AND status = 'confirmed' AND score_a = 5 AND score_b = 1 AND confirm_method = 'auto' AND confirmed_by IS NULL) THEN
    tap := tap || format(E'ok %s - no organiser action within 24h: provisional 5-1 confirmed automatically by results_sweep\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - auto-confirm %s\n', n, j); END IF;

  ------------------------------------------------------------------------------------------- C5 wins = hand count
  -- G1 4-3 side a wins (P1-P4 a); G2 0-2 side b wins (P5-P8 b); G3 5-1 side a wins (P1-P3 a, P4 b, P5-P8 none).
  -- Hand count: P1 2, P2 2, P3 2, P4 1, P5 1, P6 1, P7 1, P8 1, X 0.
  SELECT string_agg(public.result_wins(w)::text, ',' ORDER BY o) INTO e
    FROM unnest(p || x) WITH ORDINALITY q(w, o);
  n := n + 1;
  IF e = '2,2,2,1,1,1,1,1,0' THEN
    tap := tap || format(E'ok %s - wins from confirmed results match the hand count (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - wins %s\n', n, e); END IF;
  -- negative control: an open (unconfirmed) result is not counted
  UPDATE public.event_results SET status = 'open', score_a = NULL, score_b = NULL, winning_side = NULL,
         confirm_method = NULL, confirmed_at = NULL, confirmed_by = NULL WHERE event_id = g3;
  n := n + 1;
  IF public.result_wins(p[1]) = 1 THEN
    tap := tap || format(E'ok %s - negative control: an unconfirmed result adds no win (P1 drops to 1)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - unconfirmed counted\n', n); END IF;

  --------------------------------------------------------------- C6 organiser cannot enter before submissions exist
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  e := pg_temp.kan996_as(u, format('SELECT public.rpc_result_set_final(%L, 2, 0)', g1));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g1));
  n := n + 1;
  IF e = 'no_submissions' AND e2 = 'no_submissions' AND NOT EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1) THEN
    tap := tap || format(E'ok %s - the organiser cannot enter or approve a result before any submission (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - pre-submission organiser: %s %s\n', n, e, e2); END IF;

  ------------------------------------------------------------------------- C7 tie -> no provisional, organiser final
  FOR i IN 1..8 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, %s, %s, %L)', g1,
           CASE WHEN i <= 4 THEN 2 ELSE 1 END, CASE WHEN i <= 4 THEN 1 ELSE 2 END, CASE WHEN i <= 4 THEN 'a' ELSE 'b' END));
  END LOOP;
  SELECT * INTO r FROM public.results_tally(g1);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.result_enter_final'
     AND source_event_id = 'result:' || g1 AND created_at >= t0;
  e := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g1));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_set_final(%L, 2, 1)', g1));
  n := n + 1;
  IF r.score_a IS NULL AND r.is_tie AND c = 1 AND e = 'no_majority' AND e2 = 'ok'
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1 AND status = 'confirmed' AND score_a = 2
                 AND confirm_method = 'organiser_final') THEN
    tap := tap || format(E'ok %s - 4-4 tie: no provisional, approve refused (%s), organiser told to enter final; final 2-1 official\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - tie: %s %s notice %s %s\n', n, r.score_a, r.is_tie, c, e); END IF;

  -- tie with no organiser action within 24h -> closed with no result
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 2, 1, %L)', g1, 'a'));
  e := pg_temp.kan996_as(p[5], format('SELECT public.rpc_result_submit(%L, 1, 2, %L)', g1, 'b'));
  j := public.results_sweep(now() + interval '25 hours');
  SELECT count(*) INTO c FROM public.notifications WHERE kind_key = 'activity.result_closed'
     AND source_event_id = 'result:' || g1 AND created_at >= t0;
  e := pg_temp.kan996_as(p[2], format('SELECT public.rpc_result_submit(%L, 2, 1, %L)', g1, 'a'));
  n := n + 1;
  IF (j->>'closed_no_result')::int >= 1 AND c = 9 AND e = 'result_final'
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1 AND status = 'closed_no_result'
                 AND score_a IS NULL AND closed_at IS NOT NULL) THEN
    tap := tap || format(E'ok %s - tie and no final within 24h: closed with no result, 8 players + organiser told, later submit refused\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - tie close: %s told %s late %s\n', n, j, c, e); END IF;

  ------------------------------------------------------------------- C8 non-competitive and not-ended have no score step
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  UPDATE public.games SET game_type = 'training' WHERE event_id = g1;
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g1, 'a'));
  e2 := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', m, 'a'));
  UPDATE public.games SET game_type = 'casual' WHERE event_id = g1;
  UPDATE public.event_lifecycle SET state = 'started', closed_at = NULL, closed_reason = NULL WHERE event_id = g1;
  e3 := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g1, 'a'));
  n := n + 1;
  IF e = 'no_score_step' AND e2 = 'no_score_step' AND e3 = 'not_ended'
     AND NOT EXISTS (SELECT 1 FROM public.event_results WHERE event_id IN (g1, m)) THEN
    tap := tap || format(E'ok %s - training game and meetup have no score step (%s); a game not yet ended refuses (%s)\n', n, e, e3);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - non-competitive: %s %s %s\n', n, e, e2, e3); END IF;

  ------------------------------------------------------------------------------------------------ C9 grants
  n := n + 1;
  IF NOT has_table_privilege('authenticated', 'public.event_results', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.event_result_submissions', 'INSERT')
     AND NOT has_table_privilege('anon', 'public.event_result_revisions', 'SELECT')
     AND NOT has_function_privilege('authenticated', 'public.results_sweep(timestamptz)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.results_settle(uuid, integer, integer, text, uuid, timestamptz)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_result_submit(uuid, integer, integer, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_player_wins(uuid, timestamptz, timestamptz)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_result_submit(uuid, integer, integer, text)', 'EXECUTE')
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan996_results_sweep') THEN
    tap := tap || format(E'ok %s - tables server-only, sweep/settle service-only, RPCs authenticated only, sweep scheduled\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - grants\n', n); END IF;

  -- ========================================================================= KAN-996b hardening
  -- C10 a changed submission re-tallies and flips the majority
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  FOR i IN 1..5 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, %s, 0, %L)', g1, CASE WHEN i <= 3 THEN 2 ELSE 1 END, 'a'));
  END LOOP;
  SELECT * INTO r FROM public.results_tally(g1);
  c := r.score_a;
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g1, 'a'));
  e2 := pg_temp.kan996_as(p[2], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g1, 'a'));
  SELECT * INTO r FROM public.results_tally(g1);
  n := n + 1;
  IF c = 2 AND e = 'ok' AND e2 = 'ok' AND r.score_a = 1 AND r.votes = 4 AND r.submissions = 5 THEN
    tap := tap || format(E'ok %s - 3x 2-0 vs 2x 1-0 is 2-0; two players change to 1-0: re-tallied, majority flips to 1-0 (4 votes)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - flip: before %s after %s/%s votes %s subs %s\n', n, c, r.score_a, r.score_b, r.votes, r.submissions); END IF;

  -- C11 a submitter who becomes ineligible no longer counts
  UPDATE public.event_attendance SET outcome = 'no_show_confirmed' WHERE event_id = g1 AND user_id IN (p[4], p[5]);
  SELECT * INTO r FROM public.results_tally(g1);
  n := n + 1;
  IF r.submissions = 3 AND r.eligible = 6 AND r.score_a = 1 AND r.votes = 2 THEN
    tap := tap || format(E'ok %s - P4, P5 lose attended: their submissions drop out (3 of 6 counted, 1-0 has 2 votes)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - ineligible: subs %s elig %s %s votes %s\n', n, r.submissions, r.eligible, r.score_a, r.votes); END IF;

  -- C12 fitness and mind_body sports have no score step
  PERFORM pg_temp.kan996_fixture(g2, u, p, x);
  UPDATE public.events SET sport_id = '5b846b85-79a0-4a3f-b484-6661e6c5b52d' WHERE id = g2;
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g2, 'a'));
  UPDATE public.sports SET category = 'mind_body' WHERE id = '5b846b85-79a0-4a3f-b484-6661e6c5b52d';
  e2 := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g2, 'a'));
  UPDATE public.sports SET category = 'fitness' WHERE id = '5b846b85-79a0-4a3f-b484-6661e6c5b52d';
  n := n + 1;
  IF e = 'no_score_step' AND e2 = 'no_score_step' AND NOT EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g2) THEN
    tap := tap || format(E'ok %s - a fitness game and a mind_body game have no score step (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - fitness %s mind_body %s\n', n, e, e2); END IF;

  -- C13 after deadline_at, before the sweep: submit, approve and set_final refused
  PERFORM pg_temp.kan996_fixture(g2, u, p, x);
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g2, 'a'));
  UPDATE public.event_results SET deadline_at = now() - interval '1 minute' WHERE event_id = g2;
  e := pg_temp.kan996_as(p[2], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g2, 'a'));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g2));
  e3 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_set_final(%L, 3, 0)', g2));
  n := n + 1;
  IF e = 'result_final' AND e2 = 'result_final' AND e3 = 'result_final'
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g2 AND status = 'open' AND revision = 1) THEN
    tap := tap || format(E'ok %s - past deadline_at, sweep not yet run: submit, approve and set_final all refused (%s), still open\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - after deadline: %s %s %s\n', n, e, e2, e3); END IF;

  -- C14 cancelled event: submit refused, approve refused, sweep closes with no result and no win
  PERFORM pg_temp.kan996_fixture(g3, u, p, x);
  FOR i IN 1..3 LOOP
    e := pg_temp.kan996_as(p[i], format('SELECT public.rpc_result_submit(%L, 3, 0, %L)', g3, 'a'));
  END LOOP;
  c := public.result_wins(p[1]);
  UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = g3;
  e := pg_temp.kan996_as(p[4], format('SELECT public.rpc_result_submit(%L, 3, 0, %L)', g3, 'a'));
  e2 := pg_temp.kan996_as(u, format('SELECT public.rpc_result_approve(%L)', g3));
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);  -- clear G1/G2's open results so the sweep's wins come from G3 alone
  PERFORM pg_temp.kan996_fixture(g2, u, p, x);
  j := public.results_sweep(now() + interval '25 hours');
  n := n + 1;
  IF e = 'event_cancelled' AND e2 = 'event_cancelled' AND public.result_wins(p[1]) = c
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g3 AND status = 'closed_no_result' AND winning_side IS NULL) THEN
    tap := tap || format(E'ok %s - cancelled event: submit and approve refused (%s); sweep closes it with no result, no win\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - cancelled: %s %s %s wins %s->%s\n', n, e, e2, j, c, public.result_wins(p[1])); END IF;

  -- C15 did_not_happen refuses submit
  PERFORM pg_temp.kan996_fixture(g3, u, p, x);
  UPDATE public.event_lifecycle SET state = 'did_not_happen' WHERE event_id = g3;
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g3, 'a'));
  n := n + 1;
  IF e = 'not_ended' AND NOT EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g3) THEN
    tap := tap || format(E'ok %s - a did_not_happen event refuses submit (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - did_not_happen: %s\n', n, e); END IF;

  -- C16 sweep isolation: one event raising does not stop another settling
  PERFORM pg_temp.kan996_fixture(g1, u, p, x);
  PERFORM pg_temp.kan996_fixture(g2, u, p, x);
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g1, 'a'));
  e := pg_temp.kan996_as(p[1], format('SELECT public.rpc_result_submit(%L, 1, 0, %L)', g2, 'a'));
  EXECUTE format($q$CREATE FUNCTION public.kan996b_boom() RETURNS trigger LANGUAGE plpgsql AS $b$
    BEGIN IF NEW.event_id = %L AND NEW.status <> 'open' THEN RAISE EXCEPTION 'kan996b boom'; END IF; RETURN NEW; END $b$$q$, g1);
  CREATE TRIGGER kan996b_boom BEFORE UPDATE ON public.event_results FOR EACH ROW EXECUTE FUNCTION public.kan996b_boom();
  j := public.results_sweep(now() + interval '25 hours');
  DROP TRIGGER kan996b_boom ON public.event_results;
  DROP FUNCTION public.kan996b_boom();
  n := n + 1;
  IF (j->>'failed')::int >= 1
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g2 AND status = 'confirmed' AND confirm_method = 'auto')
     AND EXISTS (SELECT 1 FROM public.event_results WHERE event_id = g1 AND status = 'open' AND revision = 1)
     AND NOT EXISTS (SELECT 1 FROM public.event_result_revisions WHERE event_id = g1) THEN
    tap := tap || format(E'ok %s - sweep isolation: G1 raises and stays open (rolled back alone), G2 still auto-confirms; %s\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - isolation %s\n', n, j); END IF;

  RAISE EXCEPTION E'KAN-996 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;
