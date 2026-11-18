-- KAN-997 [W2-B4] ratings: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118114339_kan997_ratings.sql and 20261118115355_kan997b_ratings_hardening.sql. Everything (including the pg_temp
-- helpers) is in one transaction that ends in RAISE EXCEPTION, so nothing persists.
-- Fixtures: game G1 = 96949cc9 (venue 9211fe48), game G2 = 1ad6aec2 (window edge), meetup M = 1b6df962 (venue
-- 5a5de6fd), re-owned by organiser U = a3ba3271, ended (KAN-995 lifecycle) with finalized attendance (KAN-994):
-- P1..P4 attended, P5 no_show_review (corrected to attended mid-test), X no_show_confirmed, Y not a participant.
-- On M, P5 stays no_show_review, so P2 sees 3 rateable players (P1, P3, P4).
-- Calls run as authenticated with request.jwt.claims. The sweep takes p_now.

CREATE OR REPLACE FUNCTION pg_temp.kan997_as(p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE e text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', p_role)::text, true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
  BEGIN EXECUTE p_sql; e := 'ok'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  RETURN e;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.kan997_get(p_uid uuid, p_ev uuid) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  j := public.rpc_rating_get(p_ev);
  RESET ROLE;
  RETURN j;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.kan997_fixture(p_ev uuid, p_type text, p_org uuid, p_players uuid[], p_p5 uuid,
                                                  p_x uuid, p_ended interval) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.events SET creator_user_id = p_org, is_cancelled = false, cancelled_at = NULL,
         start_at = now() - p_ended - interval '1 hour', end_at = now() - p_ended WHERE id = p_ev;
  DELETE FROM public.event_lifecycle WHERE event_id = p_ev;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_ended_at, closed_at, closed_reason)
  VALUES (p_ev, p_type, 'ended', now() - p_ended, now() - p_ended, 'played');
  DELETE FROM public.event_rating_prompts WHERE event_id = p_ev;
  DELETE FROM public.event_attendance WHERE event_id = p_ev;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = p_ev;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
  SELECT p_ev, p_type, u, 'attended', now() FROM unnest(p_players) u;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at, review_requested_at, review_deadline)
  VALUES (p_ev, p_type, p_p5, 'no_show_review', now(), now(), now() + interval '48 hours');
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
  p5 uuid := '0a8453c4-f3bf-4864-a36e-923ba191c48d';
  x uuid := '143507a6-5379-4c68-a25d-63a362bbd663';
  y uuid := '13d00e2d-86f8-4d7b-8b7f-c1a8d32f4455';
  g1 uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  g2 uuid := '1ad6aec2-639a-4a0e-b95f-05399cbe85d1';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  pl text := '{"sportsmanship": 4, "skill_fit": 5}';
  og text := '{"hosting": 5}';
  vn text := '{"cleanliness": 3}';
  e text; e2 text; e3 text; e4 text; e5 text; j jsonb; c int; c2 int; c3 int; t0 timestamptz := now(); w record;
BEGIN
  DELETE FROM public.user_blocks WHERE blocker_user_id = ANY (p || u || p5) OR blocked_user_id = ANY (p || u || p5);
  UPDATE public.profiles SET language = 'en' WHERE user_id = ANY (p || u || p5);
  PERFORM pg_temp.kan997_fixture(g1, 'game', u, p, p5, x, interval '2 hours');
  PERFORM pg_temp.kan997_fixture(m, 'meetup', u, p, p5, x, interval '2 hours');
  PERFORM pg_temp.kan997_fixture(g2, 'game', u, p, p5, x, interval '47 hours 59 minutes');

  ------------------------------------------------------------- C1 game: rate a player, the organiser and the venue
  e  := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], pl));
  e2 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_organiser(%L, %L)', g1, og));
  e3 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_venue(%L, %L)', g1, vn));
  n := n + 1;
  IF e = 'ok' AND e2 = 'ok' AND e3 = 'ok'
     AND EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p[1] AND ratee_user_id = p[2] AND game_id IS NOT NULL)
     AND EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p[1] AND ratee_user_id = u)
     AND EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id = g1 AND rater_user_id = p[1] AND venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e') THEN
    tap := tap || format(E'ok %s - game: an attendee rates a player, the organiser and the venue\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - game rate: %s / %s / %s\n', n, e, e2, e3); END IF;

  ------------------------------------------------------------- C2 meetup: same three
  e  := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', m, p[2], pl));
  e2 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_organiser(%L, %L)', m, og));
  e3 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_venue(%L, %L)', m, vn));
  n := n + 1;
  IF e = 'ok' AND e2 = 'ok' AND e3 = 'ok'
     AND (SELECT count(*) FROM public.user_reputation_events WHERE event_id = m AND rater_user_id = p[1] AND game_id IS NULL) = 2
     AND EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id = m AND rater_user_id = p[1] AND venue_id = '5a5de6fd-0c01-4731-969c-51ccaf4fbd4f') THEN
    tap := tap || format(E'ok %s - meetup included: player, organiser and venue rated (game_id NULL)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - meetup rate: %s / %s / %s\n', n, e, e2, e3); END IF;

  ------------------------------------------------------------- C3 negative: non-attendee, no-show, review-pending, organiser
  e  := pg_temp.kan997_as(y, format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], pl));
  e2 := pg_temp.kan997_as(x, format('SELECT public.rpc_rate_venue(%L, %L)', g1, vn));
  e3 := pg_temp.kan997_as(p5, format('SELECT public.rpc_rate_organiser(%L, %L)', g1, og));
  e4 := pg_temp.kan997_as(u, format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], pl));
  e5 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, x, pl));
  n := n + 1;
  IF e = 'not_eligible' AND e2 = 'not_eligible' AND e3 = 'not_eligible' AND e4 = 'not_eligible' AND e5 = 'ratee_not_attended'
     AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g1 AND (rater_user_id IN (x, y, p5, u) OR ratee_user_id = x))
     AND NOT EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id = g1 AND rater_user_id IN (x, y, p5, u)) THEN
    tap := tap || format(E'ok %s - negative control: non-attendee, no-show, review-pending and organiser refused (%s); a no-show cannot be rated (%s)\n', n, e, e5);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - refusals: %s / %s / %s / %s / %s\n', n, e, e2, e3, e4, e5); END IF;

  ------------------------------------------------------------- C4 self
  e := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[1], pl));
  n := n + 1;
  IF e = 'cannot_rate_self' AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE rater_user_id = p[1] AND ratee_user_id = p[1]) THEN
    tap := tap || format(E'ok %s - cannot rate yourself (%s)\n', n, e);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - self: %s\n', n, e); END IF;

  ------------------------------------------------------------- C5 correction to attended
  UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'accepted', review_decided_at = now()
   WHERE event_id = g1 AND user_id = p5;
  e := pg_temp.kan997_as(p5, format('SELECT public.rpc_rate_organiser(%L, %L)', g1, og));
  n := n + 1;
  IF e = 'ok' AND EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p5 AND ratee_user_id = u) THEN
    tap := tap || format(E'ok %s - refused while review-pending, accepted after the organiser corrects to attended\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - correction: %s\n', n, e); END IF;

  ------------------------------------------------------------- C6 repeat updates, one row
  e := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], '{"sportsmanship": 2}'));
  e2 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_venue(%L, %L)', g1, '{"staff": 5}'));
  n := n + 1;
  IF e = 'ok' AND e2 = 'ok'
     AND (SELECT count(*) FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p[1] AND ratee_user_id = p[2]) = 1
     AND (SELECT scores FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p[1] AND ratee_user_id = p[2]) = '{"sportsmanship": 2}'::jsonb
     AND (SELECT count(*) FROM public.venue_rating_events WHERE event_id = g1 AND rater_user_id = p[1]) = 1 THEN
    tap := tap || format(E'ok %s - a repeat rating updates the one row per rater, target and event\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - repeat: %s / %s\n', n, e, e2); END IF;

  -- negative control on scores
  e := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[3], '{"hosting": 4}'));
  e2 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[3], '{"sportsmanship": 6}'));
  e3 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[3], '{}'));
  n := n + 1;
  IF e = 'unknown_dimension' AND e2 = 'score_out_of_range' AND e3 = 'invalid_scores'
     AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g1 AND ratee_user_id = p[3]) THEN
    tap := tap || format(E'ok %s - wrong dimension, out-of-range and empty scores refused\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - scores: %s / %s / %s\n', n, e, e2, e3); END IF;

  ------------------------------------------------------------- C7 48h window edge
  e := pg_temp.kan997_as(p[3], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, og));
  UPDATE public.event_lifecycle SET actual_ended_at = now() - interval '48 hours 1 minute' WHERE event_id = g2;
  e2 := pg_temp.kan997_as(p[4], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, og));
  e3 := pg_temp.kan997_as(p[3], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, '{"hosting": 1}'));
  j := pg_temp.kan997_get(p[3], g2);
  n := n + 1;
  IF e = 'ok' AND e2 = 'window_closed' AND e3 = 'window_closed' AND j->>'state' = 'closed' AND (j->>'read_only')::boolean
     AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g2 AND rater_user_id = p[4])
     AND (SELECT scores FROM public.user_reputation_events WHERE event_id = g2 AND rater_user_id = p[3]) = og::jsonb THEN
    tap := tap || format(E'ok %s - 47h59m after the end: accepted; 48h+1m: refused (%s), no update, state closed read-only\n', n, e2);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - window: %s / %s / %s %s\n', n, e, e2, e3, j); END IF;

  -- window opens only at finalize (negative control)
  DELETE FROM public.event_attendance_finalizations WHERE event_id = g2;
  UPDATE public.event_lifecycle SET actual_ended_at = now() - interval '1 hour' WHERE event_id = g2;
  e := pg_temp.kan997_as(p[4], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, og));
  j := pg_temp.kan997_get(p[4], g2);
  n := n + 1;
  IF e = 'window_not_open' AND j->>'state' = 'not_open' THEN
    tap := tap || format(E'ok %s - before attendance is finalized nobody can rate (%s, state %s)\n', n, e, j->>'state');
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - pre-finalize: %s %s\n', n, e, j); END IF;

  ------------------------------------------------------------- C8 optional steps, resume, states
  j := pg_temp.kan997_get(p[2], m);
  e := j->>'state';
  e2 := pg_temp.kan997_as(p[2], format('SELECT public.rpc_rate_venue(%L, %L)', m, vn));
  j := pg_temp.kan997_get(p[2], m);
  e3 := j->>'state';
  c := (SELECT count(*) FROM jsonb_array_elements(j->'players') q WHERE q ? 'mine');
  e4 := pg_temp.kan997_as(p[2], format('SELECT public.rpc_rating_submit(%L)', m));
  e5 := pg_temp.kan997_get(p[2], m)->>'state';
  n := n + 1;
  IF e = 'not_started' AND e2 = 'ok' AND e3 = 'partly_saved' AND c = 0 AND j->'venue' ? 'mine' AND NOT (j->'organiser' ? 'mine')
     AND e4 = 'ok' AND e5 = 'submitted' AND jsonb_array_length(j->'players') = 3 THEN
    tap := tap || format(E'ok %s - steps optional: venue only -> partly_saved (players/organiser skipped, resumable) -> submitted\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - states: %s %s %s %s %s %s\n', n, e, e2, e3, e4, e5, j); END IF;

  j := pg_temp.kan997_get(y, m);
  n := n + 1;
  IF j->>'state' = 'not_eligible' AND NOT j ? 'players' THEN
    tap := tap || format(E'ok %s - a non-attendee sees state not_eligible and nothing else\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - not eligible get: %s\n', n, j); END IF;

  ------------------------------------------------------------- C9 prompt once; none after rated/dismissed; reminder
  SELECT * INTO w FROM public.ratings_window(g1);
  e := pg_temp.kan997_as(p[3], format('SELECT public.rpc_rating_dismiss(%L)', g1));
  j := public.ratings_sweep(now());
  PERFORM public.ratings_sweep(now() + interval '1 minute');
  SELECT count(*) INTO c FROM public.notifications WHERE kind_key = 'activity.post_activity' AND source_event_id = 'rating:' || g1 AND created_at >= t0;
  SELECT count(*) INTO c2 FROM public.notifications WHERE kind_key = 'activity.post_activity' AND source_event_id = 'rating:' || g1
     AND created_at >= t0 AND to_user_id IN (x, y, u, p[3]);
  SELECT count(DISTINCT to_user_id) INTO c3 FROM public.notifications WHERE kind_key = 'activity.post_activity' AND source_event_id = 'rating:' || g1 AND created_at >= t0;
  n := n + 1;
  IF e = 'ok' AND c = 4 AND c3 = 4 AND c2 = 0 THEN
    tap := tap || format(E'ok %s - one prompt per eligible user (4: P1, P2, P4, P5); none to the dismisser, the no-show, the non-attendee or the organiser; a second sweep sends nothing\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - prompts: %s total %s distinct %s wrong %s %s\n', n, e, c, c3, c2, j); END IF;

  PERFORM public.ratings_sweep(w.closes_at - interval '5 hours');
  PERFORM public.ratings_sweep(w.closes_at - interval '4 hours');
  SELECT count(*) INTO c FROM public.notifications WHERE kind_key = 'activity.rating_reminder' AND source_event_id = 'rating:' || g1 AND created_at >= t0;
  SELECT count(*) INTO c2 FROM public.notifications WHERE kind_key = 'activity.rating_reminder' AND source_event_id = 'rating:' || g1
     AND created_at >= t0 AND to_user_id = p[2];
  n := n + 1;
  IF c = 2 AND c2 = 1 AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'activity.rating_reminder'
       AND source_event_id = 'rating:' || g1 AND created_at >= t0 AND to_user_id IN (p[1], p[3], p5)) THEN
    tap := tap || format(E'ok %s - window closing: one reminder each to P2 and P4 (rated nothing); none to P1/P5 (rated) or P3 (dismissed); a second sweep sends none\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - reminders: %s to P2 %s\n', n, c, c2); END IF;

  ------------------------------------------------------------- C10 privacy and grants
  e  := pg_temp.kan997_as(p[2], 'SELECT count(*) FROM public.user_reputation_events');
  e2 := pg_temp.kan997_as(p[2], 'SELECT count(*) FROM public.venue_rating_events');
  e3 := pg_temp.kan997_as(p[2], 'SELECT count(*) FROM public.event_rating_prompts');
  e4 := pg_temp.kan997_as(p[2], format('SELECT public.ratings_eligible(%L)', g1));
  e5 := pg_temp.kan997_as(NULL, format('SELECT public.rpc_rate_venue(%L, %L)', g1, vn), 'anon');
  j := pg_temp.kan997_get(p[2], g1);
  n := n + 1;
  IF e LIKE 'permission denied%' AND e2 LIKE 'permission denied%' AND e3 LIKE 'permission denied%'
     AND e4 LIKE 'permission denied%' AND e5 LIKE 'permission denied%'
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j->'players') q WHERE q ? 'mine')
     AND NOT (j->'organiser' ? 'mine') THEN
    tap := tap || format(E'ok %s - privacy: rating tables and helpers denied to authenticated, RPCs denied to anon; P2 does not see P1''s rating of P2 or of the organiser\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - privacy: %s / %s / %s / %s / %s %s\n', n, e, e2, e3, e4, e5, j); END IF;

  SELECT count(*) INTO c FROM pg_proc pr WHERE pr.pronamespace = 'public'::regnamespace
     AND pr.proname IN ('rpc_rate_user', 'rpc_get_unrated_coplayers')
      OR (pr.proname = 'rpc_rate_venue' AND pr.pronargs = 5);
  n := n + 1;
  IF c = 0 AND to_regclass('public.v_rateable_after_game') IS NULL
     AND (SELECT count(*) FROM pg_proc pr WHERE pr.pronamespace = 'public'::regnamespace
           AND (pr.prosrc ILIKE '%activity.post_activity%' OR pr.prosrc ILIKE '%activity.rating_reminder%')) = 1 THEN
    tap := tap || format(E'ok %s - old 7-day game-only RPCs and view gone; ratings_sweep is the only sender of both kinds\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - old surface: %s\n', n, c); END IF;

  ------------------------------------------------------------- KAN-997b C11 stored keys are exactly what was submitted
  e  := pg_temp.kan997_as(p[2], format('SELECT public.rpc_rate_venue(%L, %L)', g1, '{"amenities": 5, "cleanliness": 3}'));
  e2 := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], '{"reliability": 5}'));
  n := n + 1;
  IF e = 'ok' AND e2 = 'ok'
     AND (SELECT scores FROM public.venue_rating_events WHERE event_id = g1 AND rater_user_id = p[2]) = '{"amenities": 5, "cleanliness": 3}'::jsonb
     AND (SELECT scores FROM public.venue_rating_events WHERE event_id = g1 AND rater_user_id = p[1]) = '{"staff": 5}'::jsonb
     AND (SELECT scores FROM public.user_reputation_events WHERE event_id = g1 AND rater_user_id = p[1] AND ratee_user_id = p[2]) = '{"reliability": 5}'::jsonb
     AND NOT EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id IN (g1, m)
                      AND (scores ?| ARRAY['facility', 'value'] OR scores ? 'surface_quality')) THEN
    tap := tap || format(E'ok %s - stored scores = submitted: venue {amenities, cleanliness} and {staff} kept as given (no old keys, skipped dimensions absent); player {reliability} only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - stored keys: %s / %s %s\n', n, e, e2,
    (SELECT jsonb_agg(scores) FROM public.venue_rating_events WHERE event_id = g1)); END IF;

  ------------------------------------------------------------- C12 aggregates: 1 and 2 raters hidden, 3 shown
  UPDATE public.badge_rules SET params = params || '{"min_count": 1}'::jsonb WHERE badge_key = 'reliable_teammate';
  e := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_venue(%L, %L)', g1, '{"staff": 5, "cleanliness": 2}'));
  -- venue 9211fe48: raters P1, P2 = 2. player P2: raters P1 = 1 (g1 and m).
  c := (SELECT count(*) FROM public.venue_rating_aggregate WHERE venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e')
     + (SELECT count(*) FROM public.v_venue_dimension_by_district WHERE venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e')
     + (SELECT count(*) FROM public.user_reputation_aggregate WHERE user_id = p[2])
     + (SELECT count(*) FROM public.v_reputation_leaderboard WHERE user_id = p[2])
     + (SELECT count(*) FROM public.v_reliable_teammate_candidates WHERE user_id = p[2]);
  e2 := pg_temp.kan997_as(p[3], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], '{"reliability": 5}'));
  c2 := (SELECT count(*) FROM public.user_reputation_aggregate WHERE user_id = p[2])
      + (SELECT count(*) FROM public.v_reputation_leaderboard WHERE user_id = p[2])
      + (SELECT count(*) FROM public.v_reliable_teammate_candidates WHERE user_id = p[2]);
  e3 := pg_temp.kan997_as(p[4], format('SELECT public.rpc_rate_venue(%L, %L)', g1, '{"cleanliness": 4, "staff": 4}'));
  e4 := pg_temp.kan997_as(p[4], format('SELECT public.rpc_rate_player(%L, %L, %L)', g1, p[2], '{"reliability": 5}'));
  n := n + 1;
  IF e = 'ok' AND e2 = 'ok' AND e3 = 'ok' AND e4 = 'ok' AND c = 0 AND c2 = 0
     AND (SELECT composite_score FROM public.venue_rating_aggregate WHERE venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e') IS NOT NULL
     AND (SELECT dim_counts ? 'amenities' FROM public.venue_rating_aggregate WHERE venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e')
     AND (SELECT array_agg(dimension_key ORDER BY dimension_key) FROM public.v_venue_dimension_by_district
           WHERE venue_id = '9211fe48-11dc-4ca3-a227-a9398709e40e') = ARRAY['cleanliness']
     AND (SELECT composite_score FROM public.user_reputation_aggregate WHERE user_id = p[2]) IS NOT NULL
     AND (SELECT reliability_avg FROM public.v_reputation_leaderboard WHERE user_id = p[2]) = 5
     AND (SELECT min_count FROM public.v_reliable_teammate_candidates WHERE user_id = p[2]) = 3 THEN
    tap := tap || format(E'ok %s - aggregates hidden at 1 and 2 raters (venue, player, leaderboard, district, teammate: %s rows); shown at 3; district shows only cleanliness (3 raters), not staff/amenities (2/1); teammate floor 3 although badge_rules min_count = 1\n', n, c + c2);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - floor: %s %s %s %s hidden %s/%s\n', n, e, e2, e3, e4, c, c2); END IF;

  ------------------------------------------------------------- C13 revoked functions
  e  := pg_temp.kan997_as(NULL, format('SELECT public.reputation_recompute(%L)', p[2]), 'anon');
  e2 := pg_temp.kan997_as(NULL, format('SELECT public.venue_rating_recompute(%L)', '9211fe48-11dc-4ca3-a227-a9398709e40e'), 'anon');
  e3 := pg_temp.kan997_as(NULL, 'SELECT public.reputation_rebuild_all()', 'anon');
  e4 := pg_temp.kan997_as(NULL, format('SELECT public.can_rate_user(%L)', p[2]), 'anon');
  e5 := pg_temp.kan997_as(p[2], format('SELECT public.reputation_recompute(%L)', p[2]));
  SELECT count(*) INTO c FROM pg_proc pr WHERE pr.pronamespace = 'public'::regnamespace
     AND pr.proname IN ('reputation_recompute', 'venue_rating_recompute', 'game_rating_recompute', 'reputation_rebuild_all',
                        'venue_rating_rebuild_all', 'game_rating_rebuild_all', 'can_rate_user', 'can_rate_venue')
     AND (has_function_privilege('anon', pr.oid, 'EXECUTE') OR has_function_privilege('authenticated', pr.oid, 'EXECUTE')
          OR NOT has_function_privilege('service_role', pr.oid, 'EXECUTE'));
  n := n + 1;
  IF e LIKE 'permission denied%' AND e2 LIKE 'permission denied%' AND e3 LIKE 'permission denied%' AND e4 LIKE 'permission denied%'
     AND e5 LIKE 'permission denied%' AND c = 0 THEN
    tap := tap || format(E'ok %s - anon and authenticated cannot execute recompute/rebuild/can_rate_* (8 functions; service_role can)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - revoked: %s / %s / %s / %s / %s / %s\n', n, e, e2, e3, e4, e5, c); END IF;

  ------------------------------------------------------------- C14 did_not_happen cannot be rated
  PERFORM pg_temp.kan997_fixture(g2, 'game', u, p, p5, x, interval '2 hours');
  e := pg_temp.kan997_as(p[1], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, og));
  UPDATE public.event_lifecycle SET state = 'did_not_happen', closed_reason = 'did_not_happen', closed_at = now()
   WHERE event_id = g2;
  e2 := pg_temp.kan997_as(p[2], format('SELECT public.rpc_rate_organiser(%L, %L)', g2, og));
  e3 := pg_temp.kan997_as(p[2], format('SELECT public.rpc_rate_venue(%L, %L)', g2, vn));
  j := pg_temp.kan997_get(p[2], g2);
  n := n + 1;
  IF e = 'ok' AND e2 = 'not_ratable' AND e3 = 'not_ratable' AND j->>'state' = 'not_open'
     AND NOT (SELECT ratable FROM public.ratings_window(g2))
     AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = g2 AND rater_user_id = p[2]) THEN
    tap := tap || format(E'ok %s - did_not_happen (event_lifecycle): rating refused (%s), state not_open; control before it: accepted\n', n, e2);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - did_not_happen: %s / %s / %s %s\n', n, e, e2, e3, j); END IF;

  RAISE EXCEPTION E'\n1..%\n%# % of % passed (rolled back)', n, tap, n - bad, n;
END
$tap$;
