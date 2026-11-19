-- KAN-968 (MVP votes) + KAN-969 (wins): live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261119180000_kan968_kan969_mvp_votes_wins.sql.
-- One transaction ending in RAISE EXCEPTION carrying the TAP output, so nothing persists.
-- Fixtures reuse the KAN-997 events: G1 game ended 2h ago, M meetup ended 2h ago, G2 game ended 49h ago
-- (window closed). P1..P4 attended, X no_show_confirmed, Y not a participant, U organiser.

CREATE OR REPLACE FUNCTION pg_temp.k968_as(p_uid uuid, p_sql text) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE e text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN EXECUTE p_sql; e := 'ok'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  RESET ROLE;
  RETURN e;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.k968_val(p_uid uuid, p_sql text) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE r text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  EXECUTE p_sql INTO r;
  RESET ROLE;
  RETURN r;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.k968_fixture(p_ev uuid, p_type text, p_org uuid, p_players uuid[], p_x uuid, p_ended interval)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.events SET creator_user_id = p_org, is_cancelled = false, cancelled_at = NULL,
         start_at = now() - p_ended - interval '1 hour', end_at = now() - p_ended WHERE id = p_ev;
  DELETE FROM public.event_lifecycle WHERE event_id = p_ev;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_ended_at, closed_at, closed_reason)
  VALUES (p_ev, p_type, 'ended', now() - p_ended, now() - p_ended, 'played');
  DELETE FROM public.event_mvp_votes WHERE event_id = p_ev;
  DELETE FROM public.event_results WHERE event_id = p_ev;
  DELETE FROM public.event_attendance WHERE event_id = p_ev;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = p_ev;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
  SELECT p_ev, p_type, u, 'attended', now() FROM unnest(p_players) u;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
  VALUES (p_ev, p_type, p_x, 'no_show_confirmed', now());
  INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto)
  VALUES (p_ev, now(), p_org, false);
END $f$;

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  p uuid[] := ARRAY['036735b7-2668-4fc6-9ec3-dceb8b95ea33','039a9d4a-8c8d-48e1-8dff-327c1c615179',
                    '043b384d-f5ff-4c0a-b16c-dbf31f26e5a3','09916fe0-bb49-4c0b-8a1b-fc5cd6cad1da']::uuid[];
  x uuid := '143507a6-5379-4c68-a25d-63a362bbd663';
  y uuid := '13d00e2d-86f8-4d7b-8b7f-c1a8d32f4455';
  g1 uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  g2 uuid := '1ad6aec2-639a-4a0e-b95f-05399cbe85d1';
  m  uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  e text; e2 text; j jsonb; c int; v text;
  t0 timestamptz := now(); t1 timestamptz := now() + interval '1 day';  -- now() = txn start: only this test's rows count
BEGIN
  DELETE FROM public.user_blocks WHERE blocker_user_id = ANY (p || u) OR blocked_user_id = ANY (p || u);
  PERFORM pg_temp.k968_fixture(g1, 'game', u, p, x, interval '2 hours');
  PERFORM pg_temp.k968_fixture(m, 'meetup', u, p, x, interval '2 hours');
  PERFORM pg_temp.k968_fixture(g2, 'game', u, p, x, interval '49 hours');

  -- 0 control: a probe that must fail does fail (the harness can say not ok).
  n := n + 1;
  e := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[1]));
  IF e = 'ok' THEN tap := tap || format(E'not ok %s - control: self-vote unexpectedly ok\n', n); bad := bad + 1;
  ELSE tap := tap || format(E'ok %s - control: probe harness reports failures (%s)\n', n, e); END IF;

  -- 1 cast a vote
  n := n + 1;
  e := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[2]));
  IF e = 'ok' AND (SELECT player_user_id FROM public.event_mvp_votes WHERE event_id = g1 AND voter_user_id = p[1]) = p[2]
  THEN tap := tap || format(E'ok %s - attendee votes another attendee\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - vote: %s\n', n, e); END IF;

  -- 2 double vote replaces
  n := n + 1;
  e := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[3]));
  SELECT count(*) INTO c FROM public.event_mvp_votes WHERE event_id = g1 AND voter_user_id = p[1];
  IF e = 'ok' AND c = 1 AND (SELECT player_user_id FROM public.event_mvp_votes WHERE event_id = g1 AND voter_user_id = p[1]) = p[3]
  THEN tap := tap || format(E'ok %s - second vote replaces the first (1 row, now P3)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - replace: %s rows=%s\n', n, e, c); END IF;

  -- 3 self-vote refused
  n := n + 1;
  e := pg_temp.k968_as(p[2], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[2]));
  IF e = 'self_vote' THEN tap := tap || format(E'ok %s - self-vote refused (self_vote)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - self: %s\n', n, e); END IF;

  -- 4 non-participant cannot vote; no-show cannot vote
  n := n + 1;
  e := pg_temp.k968_as(y, format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[1]));
  e2 := pg_temp.k968_as(x, format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[1]));
  IF e = 'not_eligible' AND e2 = 'not_eligible' THEN tap := tap || format(E'ok %s - non-participant and no-show cannot vote\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - ineligible voter: %s / %s\n', n, e, e2); END IF;

  -- 5 cannot vote for a non-participant / no-show / organiser
  n := n + 1;
  e := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, y));
  e2 := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, x));
  v := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, u));
  IF e = 'player_not_eligible' AND e2 = 'player_not_eligible' AND v = 'player_not_eligible'
  THEN tap := tap || format(E'ok %s - votes for non-participant, no-show, organiser refused\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - ineligible target: %s / %s / %s\n', n, e, e2, v); END IF;

  -- 6 outside window
  n := n + 1;
  e := pg_temp.k968_as(p[1], format('SELECT public.rpc_mvp_vote(%L, %L)', g2, p[2]));
  IF e = 'window_closed' THEN tap := tap || format(E'ok %s - vote after 48h refused (window_closed)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - window: %s\n', n, e); END IF;

  -- 7 rpc_mvp_get: my vote + candidates exclude me
  n := n + 1;
  j := pg_temp.k968_val(p[1], format('SELECT public.rpc_mvp_get(%L)::text', g1))::jsonb;
  IF (j->>'my_vote')::uuid = p[3] AND jsonb_array_length(j->'candidates') = 3
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j->'candidates') cc WHERE (cc->>'user_id')::uuid = p[1])
  THEN tap := tap || format(E'ok %s - rpc_mvp_get returns my vote and 3 candidates without me\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - get: %s\n', n, j); END IF;

  -- 8 RLS: others' raw votes invisible, own visible; direct write refused
  n := n + 1;
  PERFORM pg_temp.k968_as(p[2], format('SELECT public.rpc_mvp_vote(%L, %L)', g1, p[3]));
  e := pg_temp.k968_val(p[3], format('SELECT count(*)::text FROM public.event_mvp_votes WHERE event_id = %L', g1));
  e2 := pg_temp.k968_val(p[1], format('SELECT count(*)::text FROM public.event_mvp_votes WHERE event_id = %L', g1));
  v := pg_temp.k968_as(p[4], format('INSERT INTO public.event_mvp_votes (event_id, voter_user_id, player_user_id) VALUES (%L, %L, %L)', g1, p[4], p[1]));
  IF e = '0' AND e2 = '1' AND v LIKE 'permission denied%' THEN tap := tap || format(E'ok %s - RLS: votee sees 0 rows, voter sees own 1, direct insert denied\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - rls: %s / %s / %s\n', n, e, e2, v); END IF;

  -- 9 aggregate
  n := n + 1;
  IF public.mvp_votes_count(p[3], t0, t1) = 2 AND public.mvp_votes_count(p[2], t0, t1) = 0
     AND pg_temp.k968_as(p[1], format('SELECT public.mvp_votes_count(%L)', p[3])) LIKE 'permission denied%'
  THEN tap := tap || format(E'ok %s - mvp_votes_count: P3=2, P2=0 (replaced vote not counted); not callable by authenticated\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - count\n', n); END IF;

  ------------------------------------------------------------------ wins
  INSERT INTO public.event_results (event_id, status, score_a, score_b, winning_side, confirm_method, confirmed_at, first_submission_at, deadline_at)
  VALUES (g1, 'confirmed', 3, 1, 'a', 'approved', now(), now(), now() + interval '1 day'),
         (m,  'confirmed', 2, 2, NULL, 'organiser_final', now(), now(), now() + interval '1 day'),
         (g2, 'open', NULL, NULL, NULL, NULL, NULL, now(), now() + interval '1 day');
  INSERT INTO public.event_result_submissions (event_id, user_id, score_a, score_b, side) VALUES
    (g1, p[1], 3, 1, 'a'), (g1, p[2], 3, 1, 'b'),
    (m,  p[1], 2, 2, 'a'), (m,  p[2], 2, 2, 'b'),
    (g2, p[1], 5, 0, 'a');

  -- 10 winner 1, loser 0, draw 0, open result 0
  n := n + 1;
  IF public.result_wins(p[1], t0, t1) = 1 AND public.result_wins(p[2], t0, t1) = 0 AND public.result_wins(p[3], t0, t1) = 0
  THEN tap := tap || format(E'ok %s - wins: winner=1 (draw and open result add 0), loser=0, non-submitter=0\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - wins %s/%s\n', n, public.result_wins(p[1], t0, t1), public.result_wins(p[2], t0, t1)); END IF;

  -- 11 open result becoming final counts; window boundary respected
  n := n + 1;
  UPDATE public.event_results SET status = 'confirmed', score_a = 5, score_b = 0, winning_side = 'a', confirm_method = 'auto', confirmed_at = now() WHERE event_id = g2;
  IF public.result_wins(p[1], t0, t1) = 2 AND public.result_wins(p[1], t1, t1 + interval '1 day') = 0
  THEN tap := tap || format(E'ok %s - auto-confirmed result counts; outside period = 0\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - auto\n', n); END IF;

  -- 12 active_stream carries mvp_votes + wins and still runs
  n := n + 1;
  e := pg_temp.k968_as(p[1], 'SELECT count(*) FROM public.active_stream(ARRAY[''player_week'',''player_month''])');
  IF e = 'ok' AND position('''mvp_votes''' in pg_get_functiondef('public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)'::regprocedure)) > 0
     AND position('''hosted''' in pg_get_functiondef('public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)'::regprocedure)) > 0
  THEN tap := tap || format(E'ok %s - active_stream runs; stats keep hosted and add mvp_votes, wins\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - stream: %s\n', n, e); END IF;

  RAISE EXCEPTION E'TAP\n1..%\n%# failed: %', n, tap, bad;
END $tap$;
