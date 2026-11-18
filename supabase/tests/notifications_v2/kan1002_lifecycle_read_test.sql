-- KAN-1002 lifecycle read + rpc_attendance_my title/venue: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118124211_kan1002b_lifecycle_read_fix.sql. One DO block ending in
-- RAISE EXCEPTION: everything rolls back.
-- Fixtures (as kan994_attendance_test.sql): game G = 96949cc9 (private, organiser U = a3ba3271) with V = 039a9d4a an
-- active roster player; public meetup M = 1b6df962 (organiser U); X = ec959ff7 is a non-participant.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  x uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  e text; j jsonb; ju jsonb; r record; k text; missing text; seen text[] := '{}'; ts timestamptz;
  old_keys text[] := ARRAY['event_id','state','opens_at','closes_at','checked_in_at','outcome','correction_reason',
                           'no_show_deadline','review_deadline','review_decision'];
BEGIN
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL, listing_visibility = 'private',
         start_at = now() - interval '10 minutes', end_at = now() + interval '50 minutes' WHERE id = g;
  UPDATE public.events SET is_cancelled = false, listing_visibility = 'public' WHERE id = m;
  DELETE FROM public.game_roster WHERE game_id = g AND user_id IN (v, x);
  DELETE FROM public.game_waitlist WHERE game_id = g AND user_id IN (v, x);
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (g, 'de8a830c-c561-4528-8ba0-37b89bd37814', v, 'player', 'active');
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (u, v, x) OR blocked_user_id IN (u, v, x);
  DELETE FROM public.event_lifecycle WHERE event_id IN (g, m);

  ------------------------------------------------------------------------------- C1 each state, organiser and participant
  FOR r IN SELECT * FROM (VALUES
      ('none',           now() + interval '50 minutes', 'scheduled'),
      ('none',           now() - interval '5 minutes',  'awaiting_confirmation'),
      ('scheduled',      now() + interval '50 minutes', 'scheduled'),
      ('scheduled',      now() - interval '5 minutes',  'awaiting_confirmation'),
      ('started',        now() + interval '50 minutes', 'started'),
      ('started',        now() - interval '5 minutes',  'awaiting_confirmation'),
      ('ended',          now() - interval '5 minutes',  'confirmed'),
      ('auto_closed',    now() - interval '5 minutes',  'auto_closed'),
      ('did_not_happen', now() - interval '5 minutes',  'did_not_happen')) AS q(raw, end_at, expect) LOOP
    DELETE FROM public.event_lifecycle WHERE event_id = g;
    UPDATE public.events SET end_at = r.end_at WHERE id = g;
    IF r.raw <> 'none' THEN
      INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at, actual_ended_at, closed_at, closed_reason)
      VALUES (g, 'game', r.raw, CASE WHEN r.raw <> 'scheduled' THEN now() - interval '9 minutes' END,
              CASE WHEN r.raw = 'ended' THEN now() - interval '6 minutes' END,
              CASE WHEN r.raw IN ('ended','auto_closed','did_not_happen') THEN now() - interval '1 minute' END,
              CASE r.raw WHEN 'ended' THEN 'played' WHEN 'auto_closed' THEN 'time_ended' WHEN 'did_not_happen' THEN 'did_not_happen' END);
    END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    ju := public.rpc_event_lifecycle_read(g);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
    j := public.rpc_event_lifecycle_read(g);
    EXECUTE 'RESET ROLE';
    n := n + 1;
    IF ju ->> 'state' = r.expect AND j ->> 'state' = r.expect AND (ju ->> 'is_organiser')::boolean
       AND NOT (j ->> 'is_organiser')::boolean AND j ->> 'raw_state' = replace(r.raw, 'none', 'scheduled')
       AND (r.raw IN ('none','scheduled') OR (j ? 'actual_started_at' AND j ->> 'actual_started_at' IS NOT NULL))
       AND ((r.raw IN ('ended','auto_closed','did_not_happen')) = (j ->> 'closed_at' IS NOT NULL AND j ->> 'closed_reason' IS NOT NULL))
       AND j ->> 'start_at' IS NOT NULL AND j ->> 'end_at' IS NOT NULL
       AND j ->> 'is_cancelled' = 'false' AND j ? 'auto_close_at' AND j ->> 'auto_close_at' IS NULL
       AND NOT (j ?| ARRAY['confirmed_by','actor_user_id','closed_by']) THEN
      tap := tap || format(E'ok %s - raw %s reads as %s for organiser (is_organiser true) and participant (false)\n', n, r.raw, r.expect);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s: organiser %s participant %s\n', n, r.expect, ju, j); END IF;
    seen := seen || (j ->> 'state') || (ju ->> 'state');
  END LOOP;

  -- control on the mapping across every loop row (organiser and participant): the raw 'ended' never leaks, and the
  -- same raw value reads differently on either side of the scheduled end
  n := n + 1;
  IF NOT ('ended' = ANY (seen)) AND 'confirmed' = ANY (seen) AND 'started' = ANY (seen)
     AND 'awaiting_confirmation' = ANY (seen) AND 'scheduled' = ANY (seen) AND cardinality(seen) = 18 THEN
    tap := tap || format(E'ok %s - control: no read returns raw ended; scheduled/started read differently before and after the end\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - mapping leak %s\n', n, seen); END IF;

  -- auto_close_at: exact once the reminder is sent for the current revision = greatest(end + 4h, reminder + 2h)
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  UPDATE public.events SET end_at = now() - interval '5 minutes' WHERE id = g;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at, end_revision, confirm_requested_at, reminder_sent_at)
  SELECT g, 'game', 'started', now() - interval '9 minutes', e2.schedule_revision, now() - interval '3 hours', now() - interval '1 hour'
    FROM public.events e2 WHERE e2.id = g;
  ts := greatest((SELECT public.kan995_scheduled_end(start_at, end_at) FROM public.events WHERE id = g) + interval '4 hours',
                 now() + interval '1 hour');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_event_lifecycle_read(g);
  EXECUTE 'RESET ROLE';
  UPDATE public.event_lifecycle SET end_revision = end_revision - 1 WHERE event_id = g;   -- reschedule: stale reminder
  EXECUTE 'SET LOCAL ROLE authenticated';
  ju := public.rpc_event_lifecycle_read(g);
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (j ->> 'auto_close_at')::timestamptz = ts AND j ->> 'state' = 'awaiting_confirmation'
     AND ju ? 'auto_close_at' AND ju ->> 'auto_close_at' IS NULL THEN
    tap := tap || format(E'ok %s - auto_close_at = greatest(end + 4h, reminder + 2h); control: null when the reminder belongs to an older revision\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - auto_close_at %s / %s expect %s\n', n, j, ju, ts); END IF;

  -- is_cancelled true for a cancelled event (and auto_close_at null: the worker skips it); false checked in C1
  UPDATE public.event_lifecycle SET end_revision = end_revision + 1 WHERE event_id = g;
  UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_event_lifecycle_read(g);
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL WHERE id = g;
  n := n + 1;
  IF j ->> 'is_cancelled' = 'true' AND j ->> 'auto_close_at' IS NULL THEN
    tap := tap || format(E'ok %s - is_cancelled true for a cancelled event (false on every C1 row); no auto_close_at\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - cancelled: %s\n', n, j); END IF;
  DELETE FROM public.event_lifecycle WHERE event_id = g;

  ------------------------------------------------------------------------------------------ C2 anon and invisible callers
  n := n + 1;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM public.rpc_event_lifecycle_read(g); e := 'accepted';
  EXCEPTION WHEN OTHERS THEN e := SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  IF e = '42501' AND NOT has_function_privilege('anon', 'public.rpc_event_lifecycle_read(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('public', 'public.rpc_event_lifecycle_read(uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_event_lifecycle_read(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.kan1002_event_visible(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.kan1002_venue_name(uuid)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - anon cannot execute (42501); PUBLIC has no grant; authenticated can; helpers owner-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - anon: %s\n', n, e); END IF;

  -- X cannot see the private game; control: the same X reads the public meetup; then a block hides it
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_event_lifecycle_read(g); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  BEGIN j := public.rpc_event_lifecycle_read(m); k := 'accepted'; EXCEPTION WHEN OTHERS THEN k := SQLERRM; END;
  BEGIN PERFORM public.rpc_event_lifecycle_read(gen_random_uuid()); missing := 'accepted'; EXCEPTION WHEN OTHERS THEN missing := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  -- M has no lifecycle row and its scheduled end (start + 2h, no end_at) is past: KAN-1002b reads it as
  -- awaiting_confirmation (failed as 'scheduled' before the fix test was updated)
  IF e = 'event_not_found' AND k = 'accepted'
     AND j ->> 'state' = (SELECT CASE WHEN now() > public.kan995_scheduled_end(start_at, end_at) THEN 'awaiting_confirmation'
                                      ELSE 'scheduled' END FROM public.events WHERE id = m) AND NOT (j ->> 'is_organiser')::boolean
     AND missing = 'event_not_found' THEN
    tap := tap || format(E'ok %s - a non-participant gets event_not_found on a private game (same as a missing id); control: reads a public meetup\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - invisible: %s / %s / %s\n', n, e, k, missing); END IF;

  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (u, x);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_event_lifecycle_read(m); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  DELETE FROM public.user_blocks WHERE blocker_user_id = u AND blocked_user_id = x;
  n := n + 1;
  IF e = 'event_not_found' THEN
    tap := tap || format(E'ok %s - a user the organiser blocked gets event_not_found on the public meetup\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - blocked: %s\n', n, e); END IF;

  -- private meetup: events_meetup_visibility_check allows no 'private' meetup; the private scopes are circle / invite
  -- / link / hidden. 'circle' = kan713_meetup_visible -> can_view_with_scope -> are_synced (mutual follow) with the
  -- organiser. V is not in U's circle: hidden. X is (live: are_synced(X, U) = true): visible.
  UPDATE public.events SET listing_visibility = 'circle' WHERE id = m;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_event_lifecycle_read(m); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  BEGIN j := public.rpc_event_lifecycle_read(m); k := 'accepted'; EXCEPTION WHEN OTHERS THEN k := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  UPDATE public.events SET listing_visibility = 'public' WHERE id = m;
  n := n + 1;
  IF e = 'event_not_found' AND k = 'accepted' AND NOT (j ->> 'is_organiser')::boolean
     AND NOT public.are_synced(v, u) AND public.are_synced(x, u) THEN
    tap := tap || format(E'ok %s - circle meetup: event_not_found for a non-member; readable by a circle member\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - circle meetup: %s / %s\n', n, e, k); END IF;

  ------------------------------------------------------------------------------------ C3 rpc_attendance_my title and venue
  UPDATE public.events SET start_at = now() + interval '10 minutes', end_at = now() + interval '70 minutes' WHERE id = g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_my(g);
  EXECUTE 'RESET ROLE';
  missing := (SELECT string_agg(o, ',') FROM unnest(old_keys) o WHERE NOT j ? o);
  n := n + 1;
  IF missing IS NULL AND j ->> 'state' = 'open'
     AND j ->> 'title' = (SELECT title FROM public.events WHERE id = g)
     AND j ->> 'venue_name' = (SELECT coalesce(nullif(vv.name_en, ''), vv.name_ar) FROM public.events e2 JOIN public.venues vv ON vv.id = e2.venue_id WHERE e2.id = g) THEN
    tap := tap || format(E'ok %s - attendance_my: participant gets title and venue name; every old key present; state still open\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - attendance_my: missing %s, %s\n', n, missing, j); END IF;

  -- control: X (not eligible, cannot see the private game) gets the old keys but no title/venue
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_my(g);
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j ->> 'state' = 'not_eligible' AND j ? 'title' AND j ->> 'title' IS NULL AND j ->> 'venue_name' IS NULL
     AND (SELECT count(*) FROM unnest(old_keys) o WHERE j ? o) = array_length(old_keys, 1) THEN
    tap := tap || format(E'ok %s - negative control: a user who cannot see the game gets title/venue null (not_eligible)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - leak to X: %s\n', n, j); END IF;

  -- kan1002_venue_name via the game's venue_space (events.venue_id null), then the name_ar fallback
  UPDATE public.events SET venue_id = NULL WHERE id = g;
  UPDATE public.games SET venue_space_id = 'e561f01a-1cb7-447e-9355-5aa97e1fcef2' WHERE event_id = g;
  j := jsonb_build_object('a', public.kan1002_venue_name(g));
  k := (SELECT vv.name_en FROM public.venue_spaces s2 JOIN public.venues vv ON vv.id = s2.venue_id
         WHERE s2.id = 'e561f01a-1cb7-447e-9355-5aa97e1fcef2');
  UPDATE public.venues SET name_en = '', name_ar = 'ملعب الاختبار'
   WHERE id = (SELECT venue_id FROM public.venue_spaces WHERE id = 'e561f01a-1cb7-447e-9355-5aa97e1fcef2');
  ju := jsonb_build_object('a', public.kan1002_venue_name(g));
  n := n + 1;
  IF j ->> 'a' = k AND k <> '' AND ju ->> 'a' = 'ملعب الاختبار' THEN
    tap := tap || format(E'ok %s - venue_name from the game venue_space when the event has no venue; name_ar when name_en is empty\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - venue_space path: %s / %s\n', n, j, ju); END IF;

  -- X has an attendance row on the private game it cannot see: v_show is true through r.id, so title and venue are
  -- returned; state follows the window (start in 10 min -> 'open'), not 'not_eligible'
  INSERT INTO public.event_attendance (event_id, event_type, user_id) VALUES (g, 'game', x);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_my(g);
  BEGIN PERFORM public.rpc_event_lifecycle_read(g); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  DELETE FROM public.event_attendance WHERE event_id = g AND user_id = x;
  n := n + 1;
  IF j ->> 'state' = 'open' AND j ->> 'title' = (SELECT title FROM public.events WHERE id = g)
     AND j ->> 'venue_name' = 'ملعب الاختبار' AND e = 'event_not_found' THEN
    tap := tap || format(E'ok %s - attendance row, event not visible: attendance_my still gives title/venue (state open); lifecycle_read gives event_not_found\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - attendance-row branch: %s / %s\n', n, j, e); END IF;

  -- venue null when the event has none; meetup falls back to location_name
  UPDATE public.events SET venue_id = NULL WHERE id IN (g, m);
  UPDATE public.games SET venue_space_id = NULL WHERE event_id = g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_my(g);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  ju := public.rpc_attendance_my(m);
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j ? 'venue_name' AND j ->> 'venue_name' IS NULL AND j ->> 'title' IS NOT NULL
     AND ju ->> 'venue_name' = (SELECT location_name FROM public.meetups WHERE event_id = m) THEN
    tap := tap || format(E'ok %s - venue_name is null when the game has no venue; a meetup without venue uses its location name\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - venue null: %s / %s\n', n, j, ju); END IF;

  RAISE EXCEPTION E'KAN-1002 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;
