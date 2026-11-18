-- KAN-1008 rpc_my_ongoing_events: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118141117_kan1008_my_ongoing_events.sql and
-- 20261118142327_kan1008b_my_ongoing_events_fix.sql. One DO block ending in
-- RAISE EXCEPTION: everything rolls back.
-- Fixtures (as kan1002_lifecycle_read_test.sql): game G = 96949cc9 (private, organiser U = a3ba3271) with V = 039a9d4a an
-- active roster player; public meetup M = 1b6df962 (organiser U); X = ec959ff7 is a non-participant.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  x uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  gid uuid; mid uuid; xp uuid; up uuid; e text; j jsonb; j2 jsonb; a uuid[]; b uuid[]; i int; ok boolean;
BEGIN
  SELECT id INTO gid FROM public.games WHERE event_id = g;
  SELECT id INTO mid FROM public.meetups WHERE event_id = m;
  SELECT id INTO xp FROM public.profiles WHERE user_id = x LIMIT 1;
  SELECT creator_profile_id INTO up FROM public.events WHERE id = m;
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, listing_visibility = 'private',
         start_at = now() - interval '10 minutes', end_at = now() + interval '50 minutes' WHERE id = g;
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, listing_visibility = 'public',
         start_at = now() + interval '20 minutes', end_at = now() + interval '2 hours' WHERE id = m;
  DELETE FROM public.game_roster WHERE game_id = gid AND user_id IN (v, x);
  DELETE FROM public.game_waitlist WHERE game_id = gid AND user_id IN (v, x);
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, 'de8a830c-c561-4528-8ba0-37b89bd37814', v, 'player', 'active');
  INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (gid, xp, x, 1);
  DELETE FROM public.meetup_rsvps WHERE meetup_id = mid AND user_id IN (v, x);
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (mid, v, 'de8a830c-c561-4528-8ba0-37b89bd37814', 'going');
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (mid, x, xp, 'interested');
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (u, v, x) OR blocked_user_id IN (u, v, x);
  DELETE FROM public.event_lifecycle WHERE event_id IN (g, m);
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at)
  VALUES (g, 'game', 'started', now() - interval '9 minutes');
  -- other events of U/V that would otherwise share the window
  UPDATE public.events SET start_at = start_at + interval '30 days', end_at = end_at + interval '30 days'
   WHERE id NOT IN (g, m) AND start_at BETWEEN now() - interval '49 hours' AND now() + interval '3 hours'
     AND (creator_user_id IN (u, v, x)
          OR id IN (SELECT gg.event_id FROM public.game_roster r JOIN public.games gg ON gg.id = r.game_id WHERE r.user_id IN (u, v, x))
          OR id IN (SELECT mm.event_id FROM public.meetup_rsvps r JOIN public.meetups mm ON mm.id = r.meetup_id WHERE r.user_id IN (u, v, x)));

  ------------------------------------------------------------------------------------------- C1 who is included
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  a := ARRAY(SELECT (o ->> 'event_id')::uuid FROM jsonb_array_elements(j) o);
  n := n + 1;
  IF a = ARRAY[g, m] THEN
    tap := tap || format(E'ok %s - roster player and going RSVP: V sees the running game and the meetup, ordered by start\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - V: %s\n', n, j); END IF;

  n := n + 1;
  IF (SELECT bool_and(NOT (o ->> 'is_organiser')::boolean) FROM jsonb_array_elements(j) o)
     AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(j -> 0) k) = ARRAY['actual_started_at','auto_close_at','check_in_state',
         'event_id','is_cancelled','is_organiser','kind','previous_end_at','previous_start_at','schedule_revision','scheduled_end_at',
         'start_at','state','title']
     AND j -> 0 ->> 'kind' = 'game' AND j -> 1 ->> 'kind' = 'meetup' AND j -> 0 ->> 'state' = 'started'
     AND j -> 0 ->> 'actual_started_at' IS NOT NULL
     AND (j -> 0 ->> 'schedule_revision')::int = (SELECT schedule_revision FROM public.events WHERE id = g) THEN
    tap := tap || format(E'ok %s - running game: state started, actual_started_at set; exact 14 keys, no score/eta/location\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - shape %s\n', n, j); END IF;

  -- check_in_state = rpc_attendance_my state; control: they would differ if V were not a participant (not_eligible)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_attendance_my(g);
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j -> 0 ->> 'check_in_state' = j2 ->> 'state' AND j2 ->> 'state' <> 'not_eligible' THEN
    tap := tap || format(E'ok %s - check_in_state %s equals rpc_attendance_my state\n', n, j2 ->> 'state');
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - check-in %s vs %s\n', n, j -> 0, j2); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF ARRAY(SELECT (o ->> 'event_id')::uuid FROM jsonb_array_elements(j) o) = ARRAY[g, m]
     AND (SELECT bool_and((o ->> 'is_organiser')::boolean) FROM jsonb_array_elements(j) o) THEN
    tap := tap || format(E'ok %s - organiser U sees both, is_organiser true\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - U: %s\n', n, j); END IF;

  -- X: waitlisted on G and interested on M -> nothing; control: X going on M -> M
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  UPDATE public.meetup_rsvps SET status = 'going' WHERE meetup_id = mid AND user_id = x;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j = '[]'::jsonb AND ARRAY(SELECT (o ->> 'event_id')::uuid FROM jsonb_array_elements(j2) o) = ARRAY[m] THEN
    tap := tap || format(E'ok %s - waitlisted and interested X sees nothing; control: the same X going sees M\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - X: %s / %s\n', n, j, j2); END IF;

  -- a true non-participant (V on nothing): remove V everywhere -> empty; (control is test 1)
  DELETE FROM public.game_roster WHERE game_id = gid AND user_id = v;
  UPDATE public.meetup_rsvps SET status = 'declined' WHERE meetup_id = mid AND user_id = v;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j = '[]'::jsonb THEN
    tap := tap || format(E'ok %s - non-participant (roster removed, RSVP declined) sees nothing; control: test 1\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - non-participant: %s\n', n, j); END IF;

  ------------------------------------------------------------------------------------------- C2 hidden and blocked (X going on M)
  UPDATE public.events SET listing_visibility = 'hidden' WHERE id = m;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET listing_visibility = 'public' WHERE id = m;
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (u, x);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  DELETE FROM public.user_blocks WHERE blocker_user_id = u AND blocked_user_id = x;
  n := n + 1;
  IF j = '[]'::jsonb AND j2 = '[]'::jsonb THEN
    tap := tap || format(E'ok %s - a hidden meetup and a blocked organiser exclude M for a going X; control: test 5\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - hidden %s blocked %s\n', n, j, j2); END IF;

  ------------------------------------------------------------------------------------------- C3 window (X going on M)
  ok := true;
  FOR e, i IN SELECT * FROM (VALUES ('40 m/30 out', 30), ('40 m/60 in', 60), ('20 m/-5 out', -5), ('130 m/500 out', 500), ('110 m/500 in', 500)) q LOOP
    UPDATE public.events SET start_at = now() + (split_part(e, ' ', 1) || ' minutes')::interval,
                             end_at = now() + (split_part(e, ' ', 1) || ' minutes')::interval + interval '1 hour' WHERE id = m;
    EXECUTE 'SET LOCAL ROLE authenticated';
    j := public.rpc_my_ongoing_events(i);
    EXECUTE 'RESET ROLE';
    IF (jsonb_array_length(j) = 1) <> (e LIKE '% in') THEN ok := false; tap := tap || format(E'# window %s: %s\n', e, j); END IF;
  END LOOP;
  n := n + 1;
  IF ok THEN
    tap := tap || format(E'ok %s - window: +40m out at 30, in at 60; -5 clamps to 0; 500 clamps to 120 (+110m in, +130m out)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - window\n', n); END IF;
  UPDATE public.events SET start_at = now() + interval '20 minutes', end_at = now() + interval '2 hours' WHERE id = m;

  ------------------------------------------------------------------------------------------- C4 cancelled / closed / auto-close (U on G)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  ok := true;
  FOR e IN SELECT unnest(ARRAY['cancel 1h in', 'cancel 3h out', 'ended 1h in', 'ended 3h out', 'auto_closed 1h in',
                               'did_not_happen 3h out', 'autopast out', 'autofuture in']) LOOP
    UPDATE public.events SET is_cancelled = false, cancelled_at = NULL,
           start_at = now() - interval '10 minutes', end_at = now() + interval '50 minutes' WHERE id = g;
    DELETE FROM public.event_lifecycle WHERE event_id = g;
    IF e LIKE 'cancel%' THEN
      INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at) VALUES (g, 'game', 'started', now() - interval '9 minutes');
      UPDATE public.events SET is_cancelled = true, cancelled_at = now() - (split_part(e, ' ', 2))::interval WHERE id = g;
    ELSIF e LIKE 'auto%past%' OR e LIKE 'autofuture%' THEN
      UPDATE public.events SET start_at = now() - interval '6 hours', end_at = now() - interval '5 hours' WHERE id = g;
      INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at, end_revision, confirm_requested_at, reminder_sent_at)
      SELECT g, 'game', 'started', now() - interval '6 hours', ev.schedule_revision, now() - interval '5 hours',
             CASE WHEN e LIKE 'autopast%' THEN now() - interval '4 hours' ELSE now() - interval '30 minutes' END
        FROM public.events ev WHERE ev.id = g;
    ELSE
      INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at, actual_ended_at, closed_at, closed_reason)
      VALUES (g, 'game', split_part(e, ' ', 1), now() - interval '9 minutes', now() - interval '6 minutes',
              now() - (split_part(e, ' ', 2))::interval,
              CASE split_part(e, ' ', 1) WHEN 'ended' THEN 'played' WHEN 'auto_closed' THEN 'time_ended' ELSE 'did_not_happen' END);
    END IF;
    EXECUTE 'SET LOCAL ROLE authenticated';
    j := public.rpc_my_ongoing_events();
    EXECUTE 'RESET ROLE';
    j2 := (SELECT o FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = g);
    IF (j2 IS NOT NULL) <> (e LIKE '% in')
       OR (j2 IS NOT NULL AND e LIKE 'cancel%' AND j2 ->> 'is_cancelled' <> 'true')
       OR (j2 IS NOT NULL AND e LIKE 'ended%' AND j2 ->> 'state' <> 'confirmed')
       OR (j2 IS NOT NULL AND e LIKE 'autofuture%' AND (j2 ->> 'state' <> 'awaiting_confirmation' OR (j2 ->> 'auto_close_at')::timestamptz <= now())) THEN
      ok := false; tap := tap || format(E'# %s: %s\n', e, j2);
    END IF;
  END LOOP;
  n := n + 1;
  IF ok THEN
    tap := tap || format(E'ok %s - cancelled 1h ago in (is_cancelled), 3h ago out; closed 1h in (confirmed/auto_closed), 3h out; auto-close passed out, future in\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - retention\n', n); END IF;
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL,
         start_at = now() - interval '10 minutes', end_at = now() + interval '50 minutes' WHERE id = g;
  DELETE FROM public.event_lifecycle WHERE event_id = g;

  ------------------------------------------------------------------------------------------- C5 reschedule (U on M)
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  INSERT INTO public.event_changes (event_id, event_type, revision, field, old_value, new_value, schedule_change, change_group)
  VALUES (m, 'meetup', 9999, 'start_at', to_jsonb(timestamptz '2026-01-01 10:00+00'), to_jsonb(now() + interval '20 minutes'), true, gen_random_uuid());
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  j := (SELECT o FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = m);
  j2 := (SELECT o FROM jsonb_array_elements(j2) o WHERE (o ->> 'event_id')::uuid = m);
  n := n + 1;
  IF (j2 ->> 'previous_start_at')::timestamptz = timestamptz '2026-01-01 10:00+00' AND j2 ->> 'previous_end_at' IS NULL
     AND j ->> 'previous_start_at' IS DISTINCT FROM j2 ->> 'previous_start_at' THEN
    tap := tap || format(E'ok %s - previous_start_at from the latest schedule change; previous_end_at null when only start moved; control: differs before\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - reschedule %s / %s\n', n, j, j2); END IF;

  ------------------------------------------------------------------------------------------- C6 ordering and cap (U)
  FOR i IN 1..12 LOOP
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at, listing_visibility)
    VALUES (gen_random_uuid(), 'meetup', up, u, 'kan1008 cap ' || i, now() + (13 - i) * interval '1 minute',
            now() + interval '1 hour', 'public');
  END LOOP;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF jsonb_array_length(j) = 10 AND (j -> 0 ->> 'event_id')::uuid = g
     AND (SELECT bool_and(p.s <= q.s) FROM
           (SELECT ord, (o ->> 'start_at')::timestamptz s FROM jsonb_array_elements(j) WITH ORDINALITY t(o, ord)) p
           JOIN (SELECT ord, (o ->> 'start_at')::timestamptz s FROM jsonb_array_elements(j) WITH ORDINALITY t(o, ord)) q ON q.ord = p.ord + 1)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = m)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE o ->> 'title' = 'kan1008 cap 1') THEN
    tap := tap || format(E'ok %s - 14 candidates: capped at 10, ascending start; the latest (cap 1 at +12m, M at +20m) drop\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - cap %s\n', n, j); END IF;

  ------------------------------------------------------------------------------------------- C8 KAN-1008b additions (U)
  -- cancelled meetup with cancelled_at NULL (meetups cannot carry cancelled_at): kept to start + 2h, then dropped
  UPDATE public.events SET is_cancelled = true, start_at = now() - interval '1 hour', end_at = now() + interval '1 hour' WHERE id = m;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET start_at = now() - interval '3 hours', end_at = now() + interval '1 hour' WHERE id = m;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT cancelled_at FROM public.events WHERE id = m) IS NULL
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = m AND o ->> 'is_cancelled' = 'true')
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j2) o WHERE (o ->> 'event_id')::uuid = m) THEN
    tap := tap || format(E'ok %s - cancelled, cancelled_at NULL: kept at start -1h, dropped at start -3h (fallback start_at + 2h)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - null cancelled_at %s / %s\n', n, j, j2); END IF;
  UPDATE public.events SET is_cancelled = false, start_at = now() + interval '20 minutes', end_at = now() + interval '2 hours' WHERE id = m;

  -- no lifecycle row, past scheduled end: in at end + 5h, out at end + 7h
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  UPDATE public.events SET start_at = now() - interval '6 hours', end_at = now() - interval '5 hours' WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET start_at = now() - interval '8 hours', end_at = now() - interval '7 hours' WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = g AND o ->> 'auto_close_at' IS NULL)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j2) o WHERE (o ->> 'event_id')::uuid = g) THEN
    tap := tap || format(E'ok %s - no lifecycle row: kept at end + 5h (auto_close_at null), dropped at end + 7h\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - no-row %s / %s\n', n, j, j2); END IF;

  -- 48h lower bound: closed 1h ago (kept by retention), start 47h ago in, 49h ago out
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at, actual_ended_at, closed_at, closed_reason)
  VALUES (g, 'game', 'ended', now() - interval '47 hours', now() - interval '2 hours', now() - interval '1 hour', 'played');
  UPDATE public.events SET start_at = now() - interval '47 hours', end_at = now() - interval '46 hours' WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET start_at = now() - interval '49 hours', end_at = now() - interval '48 hours' WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = g)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(j2) o WHERE (o ->> 'event_id')::uuid = g) THEN
    tap := tap || format(E'ok %s - 48h lower bound: closed game started 47h ago in, 49h ago out\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - 48h %s / %s\n', n, j, j2); END IF;
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  UPDATE public.events SET start_at = now() - interval '10 minutes', end_at = now() + interval '50 minutes' WHERE id = g;

  -- non-game/meetup event_type: the events CHECK rejects it, so the ev filter can never meet one
  BEGIN
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at, listing_visibility)
    VALUES (gen_random_uuid(), 'tournament', up, u, 'kan1008 other type', now(), now() + interval '1 hour', 'public');
    e := 'accepted';
  EXCEPTION WHEN OTHERS THEN e := SQLSTATE;
  END;
  n := n + 1;
  IF e = '23514' THEN
    tap := tap || format(E'ok %s - event_type tournament rejected (23514): no non-game/meetup event can be a candidate\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - other type %s\n', n, e); END IF;

  -- organiser check_in_state on G is exactly not_eligible
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT o ->> 'check_in_state' FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = g) = 'not_eligible' THEN
    tap := tap || format(E'ok %s - organiser U check_in_state on G = not_eligible\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - organiser check-in %s\n', n, j); END IF;

  -- blocked roster player: V active on G, U blocks V. Games follow _can_view_game, which keeps a roster member's view
  -- through a block (unlike the meetup block in test 7): G stays, and the RPC agrees with _can_view_game as V.
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, 'de8a830c-c561-4528-8ba0-37b89bd37814', v, 'player', 'active');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (u, v);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j2 := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  ok := public._can_view_game(gid);
  DELETE FROM public.user_blocks WHERE blocker_user_id = u AND blocked_user_id = v;
  n := n + 1;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(j) o WHERE (o ->> 'event_id')::uuid = g)
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(j2) o WHERE (o ->> 'event_id')::uuid = g) = ok AND ok THEN
    tap := tap || format(E'ok %s - roster player V blocked by organiser: G kept, matching _can_view_game as V (true)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - blocked roster %s / %s\n', n, j, j2); END IF;

  -- cap tie-break: 12 events at one start_at before G -> the 10 lowest ids
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  FOR i IN 1..12 LOOP
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at, listing_visibility)
    VALUES (gen_random_uuid(), 'meetup', up, u, 'kan1008 tie ' || i, date_trunc('second', now()) - interval '20 minutes',
            now() + interval '1 hour', 'public');
  END LOOP;
  b := ARRAY(SELECT id FROM public.events WHERE title LIKE 'kan1008 tie %' ORDER BY id LIMIT 10);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_my_ongoing_events();
  EXECUTE 'RESET ROLE';
  a := ARRAY(SELECT (o ->> 'event_id')::uuid FROM jsonb_array_elements(j) o);
  n := n + 1;
  IF a = b AND array_length(a, 1) = 10 THEN
    tap := tap || format(E'ok %s - 12 events tied on start_at: the 10 lowest ids, ascending id\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - tie %s vs %s\n', n, a, b); END IF;

  ------------------------------------------------------------------------------------------- C7 grants
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM public.rpc_my_ongoing_events(); e := 'accepted';
  EXCEPTION WHEN OTHERS THEN e := SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF e = '42501' AND NOT has_function_privilege('anon', 'public.rpc_my_ongoing_events(integer)', 'EXECUTE')
     AND NOT has_function_privilege('public', 'public.rpc_my_ongoing_events(integer)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_my_ongoing_events(integer)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.kan1008_lifecycle_view(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.kan1008_check_in_state(uuid,uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.kan1008_lifecycle_view(uuid)', 'EXECUTE')
     AND (SELECT prosecdef FROM pg_proc WHERE oid = 'public.rpc_my_ongoing_events(integer)'::regprocedure) THEN
    tap := tap || format(E'ok %s - anon cannot execute (42501); PUBLIC no grant; authenticated can; helpers owner-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - anon: %s\n', n, e); END IF;

  RAISE EXCEPTION E'\n%1..%\n# % of % passed', tap, n, n - bad, n;
END
$tap$;
