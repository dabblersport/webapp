-- KAN-994 [W2-B1] attendance: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117181706_kan994_attendance.sql and
-- 20261118052547_kan994b_attendance_lifecycle_end.sql and 20261118103940_kan994c_lifecycle_contract.sql and 20261118112225_kan994d_sweep_isolation.sql. One DO block ending in RAISE EXCEPTION: everything rolls back.
-- Fixtures: game event G = 96949cc9 (organiser U = a3ba3271, reopened and re-timed in the transaction) with V = 039a9d4a
-- as an active roster player and W = bbede6b0 on the waitlist; meetup M = 1b6df962 (organiser U) with V going and W
-- interested; X = ec959ff7 is a non-participant. Calls run as authenticated with request.jwt.claims.
-- Times are moved relative to now() because the RPCs use now(); the sweep takes p_now.
-- KAN-995 shipped public.event_lifecycle_state before this test ran, so the lifecycle is read through it (the
-- fallback was removed in kan994c).

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  w uuid := 'bbede6b0-72e7-4b3a-a086-5eca9788a408';
  x uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  e text; j jsonb; c int; t text; ev uuid[]; r record; st timestamptz;
BEGIN
  -- fixtures --------------------------------------------------------------------------------------------------------
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
         start_at = now() + interval '10 minutes', end_at = now() + interval '70 minutes' WHERE id = g;
  DELETE FROM public.game_roster WHERE game_id = g AND user_id IN (v, w, x);
  DELETE FROM public.game_waitlist WHERE game_id = g AND user_id IN (v, w, x);
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (g, 'de8a830c-c561-4528-8ba0-37b89bd37814', v, 'player', 'active');
  INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position)
  VALUES (g, '1ac82836-10d0-4eea-94bb-7d8d9914e12e', w, 1);
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (u, v) OR blocked_user_id IN (u, v);
  UPDATE public.profiles SET language = 'en' WHERE user_id IN (u, v);
  DELETE FROM public.event_lifecycle WHERE event_id IN (g, m);   -- KAN-995 state reset for the fixtures

  ---------------------------------------------------------------------------------------- C1 check-in window and eligibility
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_check_in(g);
  j := public.rpc_attendance_check_in(g);   -- twice
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO c FROM public.event_attendance WHERE event_id = g AND user_id = v;
  n := n + 1;
  IF c = 1 AND (SELECT mark FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'attended' THEN
    tap := tap || format(E'ok %s - a roster player checks in 10 minutes before the start; checking in twice keeps one row\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - check-in rows %s\n', n, c); END IF;

  -- negative controls: 31 minutes before, 16 minutes after, waitlisted, non-participant
  FOR r IN SELECT * FROM (VALUES (v, now() + interval '31 minutes', 'check_in_closed', '31 min before'),
                                 (v, now() - interval '16 minutes', 'check_in_closed', '16 min after'),
                                 (w, now() + interval '10 minutes', 'not_eligible', 'waitlisted'),
                                 (x, now() + interval '10 minutes', 'not_eligible', 'non-participant')) AS q(who, at, expect, label) LOOP
    DELETE FROM public.event_attendance WHERE event_id = g AND user_id = r.who;
    UPDATE public.events SET start_at = r.at, end_at = r.at + interval '1 hour' WHERE id = g;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', r.who, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      PERFORM public.rpc_attendance_check_in(g);
      e := 'accepted';
    EXCEPTION WHEN OTHERS THEN e := SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    n := n + 1;
    IF e = r.expect AND NOT EXISTS (SELECT 1 FROM public.event_attendance WHERE event_id = g AND user_id = r.who) THEN
      tap := tap || format(E'ok %s - negative control: check-in %s is refused (%s)\n', n, r.label, e);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - check-in %s: %s\n', n, r.label, e); END IF;
  END LOOP;

  -- accepted edges: 29.5 minutes before and 14.5 minutes after the start
  FOR r IN SELECT * FROM (VALUES (now() + interval '29 minutes 30 seconds', '29.5 min before'),
                                 (now() - interval '14 minutes 30 seconds', '14.5 min after')) AS q(at, label) LOOP
    DELETE FROM public.event_attendance WHERE event_id = g AND user_id = v;
    UPDATE public.events SET start_at = r.at, end_at = r.at + interval '1 hour' WHERE id = g;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.rpc_attendance_check_in(g); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
    EXECUTE 'RESET ROLE';
    n := n + 1;
    IF e = 'accepted' AND EXISTS (SELECT 1 FROM public.event_attendance WHERE event_id = g AND user_id = v AND mark = 'attended') THEN
      tap := tap || format(E'ok %s - check-in %s is accepted (window edge)\n', n, r.label);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - check-in %s: %s\n', n, r.label, e); END IF;
  END LOOP;
  DELETE FROM public.event_attendance WHERE event_id = g AND user_id = v;

  -- meetup: a going member checks in; an interested user cannot
  UPDATE public.events SET is_cancelled = false, start_at = now() + interval '5 minutes', end_at = now() + interval '65 minutes' WHERE id = m;
  DELETE FROM public.meetup_rsvps WHERE meetup_id = m AND user_id IN (v, w);
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, status) VALUES (m, v, 'going'), (m, w, 'interested');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_check_in(m);
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_check_in(m); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j ->> 'state' = 'checked_in' AND e = 'not_eligible' THEN
    tap := tap || format(E'ok %s - meetup: a going member checks in; control: an interested user is refused (not_eligible)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - meetup check-in: %s / %s\n', n, j, e); END IF;

  --------------------------------------------------------------------------------- C2 corrections: window, reason, organiser
  -- during the window: refused
  UPDATE public.events SET start_at = now() + interval '5 minutes', end_at = now() + interval '65 minutes' WHERE id = g;
  -- the negative controls above deleted V's row: V checks in again so the correction below starts from 'attended'
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_attendance_check_in(g);
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_correct(g, v, 'no_show', 'left early'); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF e = 'window_not_closed' THEN tap := tap || format(E'ok %s - the organiser cannot correct during the check-in window\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - correction during window: %s\n', n, e); END IF;

  -- after the window: needs a reason; the second account (not the organiser) is refused
  UPDATE public.events SET start_at = now() - interval '30 minutes', end_at = now() + interval '30 minutes' WHERE id = g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_correct(g, v, 'no_show', '   '); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_correct(g, v, 'attended', 'I was there'); t := 'accepted'; EXCEPTION WHEN OTHERS THEN t := SQLERRM; END;
  BEGIN PERFORM public.rpc_attendance_finalize(g); t := t || '/accepted'; EXCEPTION WHEN OTHERS THEN t := t || '/' || SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF e = 'reason_required' AND t = 'not_organiser/not_organiser' THEN
    tap := tap || format(E'ok %s - after the window a blank reason is refused; the second account cannot correct or finalize (not_organiser)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - reason/organiser: %s %s\n', n, e, t); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_attendance_correct(g, v, 'no_show', 'Left after five minutes');
  SELECT count(*) INTO c FROM public.rpc_attendance_list(g) l WHERE l.user_id = v AND l.mark = 'no_show';
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF c = 1 AND EXISTS (SELECT 1 FROM public.event_attendance_corrections k
                        WHERE k.event_id = g AND k.user_id = v AND k.actor_user_id = u AND k.from_mark = 'attended'
                          AND k.to_mark = 'no_show' AND k.reason = 'Left after five minutes') THEN
    tap := tap || format(E'ok %s - the organiser corrects with a reason; the correction is audited and shows in the list\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - correction audit\n', n); END IF;

  ---------------------------------------------------------------------------- C3 finalize -> no-show pending, review flow
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_finalize(g);
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'no_show_pending'
     AND EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND kind_key = 'activity.no_show_pending'
                  AND dedupe_key = 'activity.no_show_pending:' || g || ':' || v
                  AND body = 'This confirms in 48h unless you ask for a review.')
     AND (public.rpc_showup_rate(v) ->> 'no_shows')::int = 0 THEN
    tap := tap || format(E'ok %s - finalize: the player is no_show_pending, told "confirms in 48h unless you ask for a review", not counted yet\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - finalize: %s\n', n, j); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_request_review(g, 'I was there, ask Sara');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'no_show_review'
     AND EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = u AND kind_key = 'activity.review_requested'
                  AND dedupe_key = 'activity.review_requested:' || g || ':' || u) THEN
    tap := tap || format(E'ok %s - the player asks for a review; the organiser gets "asked to review their attendance"\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - review request: %s\n', n, j); END IF;

  -- controls: the second account (V, not the organiser) cannot decide the review or read the list; a player who is not
  -- no_show_pending (X) cannot ask for a review
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_decide_review(g, v, 'accept'); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  BEGIN PERFORM * FROM public.rpc_attendance_list(g); e := e || '/accepted'; EXCEPTION WHEN OTHERS THEN e := e || '/' || SQLERRM; END;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_request_review(g, 'me too'); t := 'accepted'; EXCEPTION WHEN OTHERS THEN t := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF e = 'not_organiser/not_organiser' AND t = 'no_pending_no_show'
     AND (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'no_show_review' THEN
    tap := tap || format(E'ok %s - the second account cannot decide a review or read the list (not_organiser); a player not pending cannot ask for review (no_pending_no_show)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - review controls: %s / %s\n', n, e, t); END IF;

  -- organiser keeps -> confirmed and counted
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_decide_review(g, v, 'keep');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'no_show_confirmed'
     AND EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND kind_key = 'activity.review_kept')
     AND (public.rpc_showup_rate(v) ->> 'no_shows')::int = 1 THEN
    tap := tap || format(E'ok %s - organiser keeps: no_show_confirmed, the player is told, and it now counts\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - keep: %s\n', n, j); END IF;

  -- accept path, on a second row (meetup), and the sweep expiries
  UPDATE public.events SET start_at = now() - interval '30 minutes', end_at = now() + interval '30 minutes' WHERE id = m;
  DELETE FROM public.event_attendance WHERE event_id = m;
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_finalize(m);     -- V never checked in -> no_show_pending
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  UPDATE public.event_attendance SET no_show_deadline = now() - interval '1 minute' WHERE event_id = m AND user_id = v;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_attendance_request_review(m, NULL); e := 'accepted'; EXCEPTION WHEN OTHERS THEN e := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF e = 'review_window_closed' AND (SELECT outcome FROM public.event_attendance WHERE event_id = m AND user_id = v) = 'no_show_pending' THEN
    tap := tap || format(E'ok %s - a review request after the 48h deadline is refused (review_window_closed)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - late review request: %s\n', n, e); END IF;
  UPDATE public.event_attendance SET no_show_deadline = now() + interval '48 hours' WHERE event_id = m AND user_id = v;
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_attendance_request_review(m, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_attendance_decide_review(m, v, 'accept');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT outcome FROM public.event_attendance WHERE event_id = m AND user_id = v) = 'attended'
     AND EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND kind_key = 'activity.review_accepted') THEN
    tap := tap || format(E'ok %s - meetup: not checked in -> no-show pending at finalize; review accepted -> attended, player told\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - accept: %s\n', n, j); END IF;

  -- sweep: pending past 48h -> confirmed; review unanswered past 48h -> attended (player's favour)
  UPDATE public.event_attendance SET outcome = 'no_show_pending', no_show_deadline = now() + interval '48 hours',
         review_decision = NULL, review_deadline = NULL WHERE event_id = m AND user_id = v;
  j := public.attendance_sweep(now() + interval '47 hours');
  t := (SELECT outcome FROM public.event_attendance WHERE event_id = m AND user_id = v);
  j := public.attendance_sweep(now() + interval '49 hours');
  n := n + 1;
  IF t = 'no_show_pending' AND (SELECT outcome FROM public.event_attendance WHERE event_id = m AND user_id = v) = 'no_show_confirmed' THEN
    tap := tap || format(E'ok %s - no review request: still pending at 47h (control), no_show_confirmed after 48h\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - 48h expiry: %s then %s\n', n, t,
    (SELECT outcome FROM public.event_attendance WHERE event_id = m AND user_id = v)); END IF;
  UPDATE public.event_attendance SET outcome = 'no_show_review', review_deadline = now() + interval '48 hours',
         review_decision = NULL WHERE event_id = m AND user_id = v;
  j := public.attendance_sweep(now() + interval '49 hours');
  n := n + 1;
  IF (SELECT outcome || '/' || review_decision FROM public.event_attendance WHERE event_id = m AND user_id = v) = 'attended/expired_accepted' THEN
    tap := tap || format(E'ok %s - an unanswered review request after 48h is accepted in the player''s favour\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - review expiry\n', n); END IF;

  ------------------------------------------------------------------- C4 auto-finalize 24h after the effective end
  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = g;
  st := now() + interval '10 minutes';
  UPDATE public.events SET start_at = st, end_at = st + interval '1 hour' WHERE id = g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_attendance_check_in(g);
  EXECUTE 'RESET ROLE';
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (g, '90746b60-9145-4f99-acec-9862ccb697fa', x, 'player', 'active');   -- X joins and never checks in
  -- KAN-995 never saw it: past and still 'scheduled' -> not finalized (waiting for the lifecycle worker)
  j := public.attendance_sweep(st + interval '1 hour' + interval '30 hours');
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations WHERE event_id = g)
     AND (j ->> 'waiting_for_lifecycle')::int >= 1 THEN
    tap := tap || format(E'ok %s - a past event still ''scheduled'' in event_lifecycle_state is not auto-finalized (worker never saw it)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - scheduled-past: %s\n', n, j); END IF;
  -- fixture: KAN-995 auto-closed it at the scheduled end (test data; product code reads only event_lifecycle_state)
  INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
  VALUES (g, 'game', 'auto_closed', st + interval '3 hours', 'time_ended');
  j := public.attendance_sweep(st + interval '1 hour' + interval '23 hours');
  c := (SELECT count(*) FROM public.event_attendance_finalizations WHERE event_id = g);
  j := public.attendance_sweep(st + interval '1 hour' + interval '24 hours' + interval '1 minute');
  n := n + 1;
  IF c = 0 AND (SELECT reason FROM public.event_attendance_finalizations WHERE event_id = g) = 'auto'
     AND (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) = 'attended'
     AND (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = x) = 'unknown'
     AND NOT EXISTS (SELECT 1 FROM public.event_attendance WHERE event_id = g AND outcome LIKE 'no_show%')
     AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = x AND kind_key = 'activity.no_show_pending') THEN
    tap := tap || format(E'ok %s - never finalized: nothing at end+23h (control); at end+24h auto-finalized, check-in attended, absentee unknown, nobody no-show\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - auto-finalize: %s\n', n, j); END IF;

  -- did_not_happen (KAN-995 lifecycle) and cancelled: no outcomes, no no-shows
  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = g;
  -- fixture: KAN-995 records the event as did_not_happen (written here directly as test data; the product code reads
  -- it only through public.event_lifecycle_state)
  INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
  VALUES (g, 'game', 'did_not_happen', now(), 'did_not_happen')
  ON CONFLICT (event_id) DO UPDATE SET state = 'did_not_happen', closed_at = now(), closed_reason = 'did_not_happen',
         actual_ended_at = NULL;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_attendance_check_in(g);
  EXECUTE 'RESET ROLE';
  j := public.attendance_sweep(st + interval '1 hour' + interval '24 hours' + interval '1 minute');
  n := n + 1;
  IF (SELECT reason FROM public.event_attendance_finalizations WHERE event_id = g) = 'did_not_happen'
     AND NOT EXISTS (SELECT 1 FROM public.event_attendance WHERE event_id = g AND outcome IS NOT NULL)
     AND (SELECT source FROM public.attendance_lifecycle(g)) = 'event_lifecycle_state' THEN
    tap := tap || format(E'ok %s - did_not_happen (via event_lifecycle_state): closed with no outcomes and no no-shows\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - did_not_happen: %s\n', n, j); END IF;
  -- a no-show pending from before the event was marked did_not_happen is voided at 48h, not confirmed
  UPDATE public.event_attendance SET outcome = 'no_show_pending', no_show_deadline = now() - interval '1 minute'
   WHERE event_id = g AND user_id = v;
  j := public.attendance_sweep(now());
  n := n + 1;
  IF (SELECT outcome FROM public.event_attendance WHERE event_id = g AND user_id = v) IS NULL
     AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND kind_key = 'activity.no_show_confirmed'
                      AND dedupe_key = 'activity.no_show_confirmed:' || g || ':' || v) THEN
    tap := tap || format(E'ok %s - did_not_happen: a pending no-show is voided at 48h, not confirmed, no notice\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - void: %s\n', n, j); END IF;
  DELETE FROM public.event_lifecycle WHERE event_id = g;

  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = g;
  UPDATE public.events SET is_cancelled = true WHERE id = g;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
  VALUES (g, 'game', 'auto_closed', st + interval '3 hours', 'time_ended');
  j := public.attendance_sweep(st + interval '1 hour' + interval '24 hours' + interval '1 minute');
  -- re-check after the lock: called directly (bypassing the sweep's pre-filter) it still records nothing
  c := public.attendance_finalize_event(g, NULL, true, st + interval '5 days');
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  n := n + 1;
  IF c = -1 AND NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations WHERE event_id = g)
     AND NOT EXISTS (SELECT 1 FROM public.event_attendance WHERE event_id = g)
     AND (SELECT source FROM public.attendance_lifecycle(g)) = 'event_lifecycle_state' THEN
    tap := tap || format(E'ok %s - a cancelled event records nothing (lifecycle read through event_lifecycle_state)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - cancelled: %s\n', n, j); END IF;

  ------------------------------------------------------------------------------- C5 show-up rate against a hand count
  DELETE FROM public.event_attendance WHERE user_id = v;
  SELECT array_agg(id) INTO ev FROM (SELECT e.id FROM public.events e
     WHERE NOT COALESCE(e.is_cancelled, false) AND e.event_type IN ('game','meetup') AND e.id NOT IN (g, m)
     ORDER BY e.created_at LIMIT 5) s;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome)
  SELECT ev[i], (SELECT event_type FROM public.events WHERE id = ev[i]), v, o
    FROM (VALUES (1, 'attended'), (2, 'no_show_confirmed')) AS q(i, o);
  j := public.rpc_showup_rate(v);
  n := n + 1;
  IF ((j ->> 'confirmed')::int = 2) AND (j ->> 'rate' IS NULL) AND ((j ->> 'enough')::boolean = false) THEN
    tap := tap || format(E'ok %s - below 3 confirmed events: "not enough games yet" (rate null): %s\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - below 3: %s\n', n, j); END IF;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome)
  SELECT ev[i], (SELECT event_type FROM public.events WHERE id = ev[i]), v, o
    FROM (VALUES (3, 'attended'), (4, 'unknown'), (5, 'no_show_pending')) AS q(i, o);
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome) VALUES (g, 'game', v, 'attended');  -- g is cancelled now
  j := public.rpc_showup_rate(v);
  n := n + 1;
  -- hand count: attended 2 (events 1, 3), confirmed no-show 1 (event 2); excluded: unknown, pending, cancelled g
  IF (j ->> 'confirmed')::int = 3 AND (j ->> 'attended')::int = 2 AND (j ->> 'rate')::int = 67 AND (j ->> 'enough')::boolean THEN
    tap := tap || format(E'ok %s - show-up rate = hand count 2/3 = 67%%; unknown, pending and the cancelled event excluded\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - rate: %s\n', n, j); END IF;

  -- did_not_happen is excluded: an attended row on M counts (control), then M marked did_not_happen drops it again
  INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome) VALUES (m, 'meetup', v, 'attended');
  c := (public.rpc_showup_rate(v) ->> 'confirmed')::int;
  INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
  VALUES (m, 'meetup', 'did_not_happen', now(), 'did_not_happen')
  ON CONFLICT (event_id) DO UPDATE SET state = 'did_not_happen', closed_at = now(), closed_reason = 'did_not_happen',
         actual_ended_at = NULL;
  j := public.rpc_showup_rate(v);
  DELETE FROM public.event_lifecycle WHERE event_id = m;
  n := n + 1;
  IF c = 4 AND (j ->> 'confirmed')::int = 3 AND (j ->> 'attended')::int = 2 AND (j ->> 'rate')::int = 67 THEN
    tap := tap || format(E'ok %s - show-up rate excludes a did_not_happen event (4 confirmed before as control, 3 after)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - did_not_happen rate: %s then %s\n', n, c, j); END IF;

  ------------------------------------------------------------------------------------------- C5b sweep isolation
  -- fixture (rolled back): G and M both past, auto_closed, not finalized; a trigger makes G's finalization raise
  DELETE FROM public.event_attendance WHERE event_id IN (g, m);
  DELETE FROM public.event_attendance_finalizations WHERE event_id IN (g, m);
  UPDATE public.events SET is_cancelled = false, start_at = now() - interval '3 hours', end_at = now() - interval '2 hours'
   WHERE id IN (g, m);
  INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
  VALUES (g, 'game', 'auto_closed', now() - interval '2 hours', 'time_ended'),
         (m, 'meetup', 'auto_closed', now() - interval '2 hours', 'time_ended')
  ON CONFLICT (event_id) DO UPDATE SET state = 'auto_closed', closed_at = EXCLUDED.closed_at, closed_reason = 'time_ended',
         actual_ended_at = NULL;
  EXECUTE format($f$CREATE FUNCTION pg_temp.kan994d_boom() RETURNS trigger LANGUAGE plpgsql AS $b$
    BEGIN IF NEW.event_id = %L THEN RAISE EXCEPTION 'kan994d_boom'; END IF; RETURN NEW; END $b$$f$, g);
  CREATE TRIGGER kan994d_boom BEFORE INSERT ON public.event_attendance_finalizations
    FOR EACH ROW EXECUTE FUNCTION pg_temp.kan994d_boom();
  j := public.attendance_sweep(now() + interval '30 hours');
  DROP TRIGGER kan994d_boom ON public.event_attendance_finalizations;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations WHERE event_id = g)
     AND EXISTS (SELECT 1 FROM public.event_attendance_finalizations WHERE event_id = m)
     AND (j ->> 'failed')::int >= 1 THEN
    tap := tap || format(E'ok %s - sweep isolation: G raises inside the sweep, M is still finalized, failed >= 1: %s\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - sweep isolation: %s\n', n, j); END IF;
  DELETE FROM public.event_lifecycle WHERE event_id IN (g, m);

  ------------------------------------------------------------------------------------------- C6 grants and privacy
  n := n + 1;
  IF NOT has_table_privilege('authenticated', 'public.event_attendance', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.event_attendance_corrections', 'SELECT')
     AND NOT has_function_privilege('authenticated', 'public.attendance_sweep(timestamptz)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.attendance_lifecycle(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_attendance_check_in(uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_attendance_check_in(uuid)', 'EXECUTE')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name LIKE 'event_attendance%'
                      AND (column_name ~* '(lat|lng|lon|location|geo|ip)' OR data_type IN ('point', 'inet')))
     AND NOT (SELECT is_active FROM public.notification_kinds WHERE key = 'activity.checkin_open') THEN
    tap := tap || format(E'ok %s - tables server-only, sweep/reader service-only, RPCs authenticated only, no location column, checkin_open inactive\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - grants/privacy\n', n); END IF;

  RAISE EXCEPTION E'KAN-994 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;
