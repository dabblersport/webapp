-- KAN-995 [W2-B2] Lifecycle: live test. Run as postgres on wtncuzcskpigqpmnxwws, whole file in one session. Every
-- write is inside one sub-block that ends with 'kan995_rollback'; only the results survive (plpgsql variables).
-- Fixtures picked live and reshaped inside the block: five non-series games G1..G5 (G1/G2 started 1h ago, end in 1h;
-- G3 the same; G4 for the reschedule; G5 cancelled) and one meetup M with no end_at (starts in 2 days). One player P is
-- put on G2 and G3. The worker is driven with p_now = E + offset, E = G1's scheduled end.
-- Expected: every row pass = true. N* rows are negative controls.
--
-- Run 2026-11-18 by backend-3 (Shed). Before apply: event_lifecycle_state absent; KAN-994 attendance_lifecycle()
-- answered source 'fallback'. After 20261118053016: 14 of 14 pass (S1, N1, W1, N2, C1, D1, W2, W3, N3, R1, M1, K1, G1,
-- R). W1 4 requests, a second run 0; W2 one reminder (G1); W3 G1 auto_closed / time_ended, one auto_closed notice;
-- R1 G4 got 2 confirm_end rows (old and new revision), no reminder; M1 0 before start + 2h, 1 after; K1
-- attendance_lifecycle source 'event_lifecycle_state', state did_not_happen. Live cron runs succeeded; 0 real notices.

CREATE TEMP TABLE IF NOT EXISTS kan995_results (probe text, pass boolean, detail text);
TRUNCATE kan995_results;

DO $b$
DECLARE
  r text[] := '{}';
  g uuid[]; h uuid[]; m uuid; mh uuid; p uuid; p_p uuid; x uuid;
  e_end timestamptz; m_start timestamptz; j jsonb; j2 jsonb; s text; n int; n2 int; st record;
BEGIN
  SELECT array_agg(id ORDER BY id), array_agg(creator_user_id ORDER BY id) INTO g, h FROM (
    SELECT e.id, e.creator_user_id FROM public.events e JOIN public.games gm ON gm.event_id = e.id
     WHERE e.event_type = 'game' AND NOT e.is_cancelled AND gm.series_id IS NULL AND e.creator_user_id IS NOT NULL
     ORDER BY e.id LIMIT 5) z;
  SELECT e.id, e.creator_user_id INTO m, mh FROM public.events e WHERE e.event_type = 'meetup' AND NOT e.is_cancelled
   ORDER BY e.id LIMIT 1;
  SELECT pr.user_id, pr.id INTO p, p_p FROM public.profiles pr
   WHERE pr.is_active AND pr.persona_type = 'player' AND pr.user_id <> ALL (h)
     AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = pr.user_id AND gr.game_id = ANY (g))
     AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE pr.user_id IN (b.blocker_user_id, b.blocked_user_id))
   ORDER BY pr.user_id LIMIT 1;
  SELECT pr.user_id INTO x FROM public.profiles pr WHERE pr.is_active AND pr.user_id <> ALL (h) AND pr.user_id <> p
   ORDER BY pr.user_id LIMIT 1;
  IF cardinality(g) < 5 OR m IS NULL OR p IS NULL OR x IS NULL THEN RAISE EXCEPTION 'kan995 test: fixture missing'; END IF;

  BEGIN
    UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
           start_at = date_trunc('minute', now()) - interval '1 hour', end_at = date_trunc('minute', now()) + interval '1 hour'
     WHERE id = ANY (g);
    UPDATE public.events SET is_cancelled = true WHERE id = g[5];
    UPDATE public.events SET start_at = date_trunc('minute', now()) + interval '2 days', end_at = NULL WHERE id = m;
    INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
    VALUES (g[2], p_p, p, 'player', 'active'), (g[3], p_p, p, 'player', 'active');
    UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id = ANY (h || mh || p);
    DELETE FROM public.event_lifecycle WHERE event_id = ANY (g || m);
    SELECT end_at INTO e_end FROM public.events WHERE id = g[1];
    SELECT start_at INTO m_start FROM public.events WHERE id = m;

    -- S1 Start by the organiser at/after the scheduled start; repeat is idempotent
    PERFORM set_config('request.jwt.claims', json_build_object('sub', h[1], 'role', 'authenticated')::text, true);
    j := public.rpc_event_start(g[1]);
    j2 := public.rpc_event_start(g[1]);
    r := r || ARRAY['S1 organiser Start records actual_started_at; a second Start is idempotent',
      (j ->> 'result' = 'started' AND j2 ->> 'result' = 'already_started'
       AND j ->> 'actual_started_at' = j2 ->> 'actual_started_at'
       AND (SELECT state FROM public.event_lifecycle WHERE event_id = g[1]) = 'started'
       AND (SELECT count(*) FROM public.event_lifecycle_transitions WHERE event_id = g[1] AND to_state = 'started'
              AND actor_user_id = h[1]) = 1)::text,
      format('%s / %s', j ->> 'result', j2 ->> 'result')];

    -- N1 Start refused: a non-organiser, a cancelled event, before the start
    PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.rpc_event_start(g[2]); s := 'allowed';
    EXCEPTION WHEN raise_exception THEN s := SQLERRM; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', h[5], 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.rpc_event_start(g[5]); s := s || '/allowed';
    EXCEPTION WHEN raise_exception THEN s := s || '/' || SQLERRM; END;
    UPDATE public.events SET start_at = now() + interval '1 day', end_at = now() + interval '1 day 1 hour' WHERE id = g[4];
    PERFORM set_config('request.jwt.claims', json_build_object('sub', h[4], 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.rpc_event_start(g[4]); s := s || '/allowed';
    EXCEPTION WHEN raise_exception THEN s := s || '/' || SQLERRM; END;
    r := r || ARRAY['N1 Start refused for a non-organiser, a cancelled event, and before the start',
      (s = 'not_organiser/cancelled/not_started_yet')::text, s];
    UPDATE public.events SET start_at = date_trunc('minute', now()) - interval '1 hour',
                             end_at = date_trunc('minute', now()) + interval '1 hour' WHERE id = g[4];

    -- W1 at the end: one confirm request to each organiser; a second run sends nothing more
    j := public.kan995_lifecycle_worker(e_end + interval '1 minute');
    j2 := public.kan995_lifecycle_worker(e_end + interval '1 minute');
    SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'activity.confirm_end'
       AND context ->> 'entity_id' IN (g[1]::text, g[2]::text, g[3]::text, g[4]::text);
    r := r || ARRAY['W1 at the scheduled end: one confirm_end per organiser (G1..G4), none twice',
      (n = 4 AND (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.confirm_end'
                    AND context ->> 'entity_id' = g[1]::text AND to_user_id = h[1]) = 1)::text,
      format('requests=%s run1=%s run2=%s', n, j, j2)];
    r := r || ARRAY['N2 cancelled G5: no lifecycle step',
      (NOT EXISTS (SELECT 1 FROM public.notifications WHERE context ->> 'entity_id' = g[5]::text AND kind_key LIKE 'activity.%')
       AND NOT EXISTS (SELECT 1 FROM public.event_lifecycle WHERE event_id = g[5]))::text, 'G5'];

    -- C1 G2: the organiser confirms "played" -> ended, participants told, audited
    PERFORM set_config('request.jwt.claims', json_build_object('sub', h[2], 'role', 'authenticated')::text, true);
    j := public.rpc_event_confirm_end(g[2], 'played');
    j2 := public.rpc_event_confirm_end(g[2], 'played');
    r := r || ARRAY['C1 confirm "played": state ended, activity.ended to the participant once, audited with the actor',
      (j ->> 'result' = 'ended' AND j2 ->> 'result' = 'already_ended'
       AND (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.ended' AND to_user_id = p
              AND context ->> 'entity_id' = g[2]::text) = 1
       AND (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.ended' AND to_user_id = h[2]
              AND context ->> 'entity_id' = g[2]::text) = 0
       AND EXISTS (SELECT 1 FROM public.event_lifecycle_transitions WHERE event_id = g[2] AND to_state = 'ended'
                    AND actor_user_id = h[2] AND reason = 'organiser_played'))::text,
      format('%s / %s', j ->> 'result', j2 ->> 'result')];

    -- E1 (PEER 16517, KAN-995b): kan995_transition on a closed row must raise and leave it untouched
    BEGIN
      PERFORM public.kan995_transition(g[2], 'auto_closed', NULL, 'time_ended', now(), 'time_ended');
      s := 'overwrote';
    EXCEPTION WHEN raise_exception THEN s := SQLERRM; END;
    r := r || ARRAY['E1 kan995_transition on a closed (ended/played) row raises lifecycle_closed, row unchanged',
      (s = 'lifecycle_closed' AND (SELECT state || '/' || closed_reason FROM public.event_lifecycle WHERE event_id = g[2]) = 'ended/played')::text,
      format('%s -> %s', s, (SELECT state || '/' || closed_reason FROM public.event_lifecycle WHERE event_id = g[2]))];

    -- D1 G3: "did not happen" -> closed in that state, audited, nobody told, a later "played" refused
    PERFORM set_config('request.jwt.claims', json_build_object('sub', h[3], 'role', 'authenticated')::text, true);
    j := public.rpc_event_confirm_end(g[3], 'did_not_happen');
    BEGIN PERFORM public.rpc_event_confirm_end(g[3], 'played'); s := 'allowed';
    EXCEPTION WHEN raise_exception THEN s := SQLERRM; END;
    r := r || ARRAY['D1 "did not happen": closed, audited with the actor, no participant notice, not reopened',
      (j ->> 'result' = 'did_not_happen' AND s = 'already_closed'
       AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'activity.ended' AND context ->> 'entity_id' = g[3]::text)
       AND EXISTS (SELECT 1 FROM public.event_lifecycle_transitions WHERE event_id = g[3] AND to_state = 'did_not_happen'
                    AND actor_user_id = h[3]))::text,
      format('%s / reopen: %s', j ->> 'result', s)];

    -- R1 G4 rescheduled after its request: the end steps restart from the new end
    UPDATE public.events SET start_at = start_at + interval '1 day', end_at = end_at + interval '1 day' WHERE id = g[4];

    -- W2 end + 2h: one reminder for G1 only (G2 confirmed, G3 did not happen, G4 now in the future)
    j := public.kan995_lifecycle_worker(e_end + interval '2 hours 1 minute');
    PERFORM public.kan995_lifecycle_worker(e_end + interval '2 hours 2 minutes');
    SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'activity.confirm_end_reminder'
       AND context ->> 'entity_id' IN (g[1]::text, g[2]::text, g[3]::text, g[4]::text);
    r := r || ARRAY['W2 end + 2h: exactly one reminder, for the unconfirmed G1 only',
      (n = 1 AND EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'activity.confirm_end_reminder'
                          AND context ->> 'entity_id' = g[1]::text AND to_user_id = h[1]))::text,
      format('reminders=%s %s', n, j)];

    -- W3 end + 4h: G1 auto-closes as "scheduled time ended"; the confirmed G2 and the closed G3 get nothing
    j := public.kan995_lifecycle_worker(e_end + interval '4 hours 1 minute');
    PERFORM public.kan995_lifecycle_worker(e_end + interval '5 hours');
    SELECT * INTO st FROM public.event_lifecycle_state(g[1]);
    r := r || ARRAY['W3 end + 4h: G1 auto_closed (time_ended), one activity.auto_closed to the organiser',
      (st.state = 'auto_closed' AND st.closed_reason = 'time_ended'
       AND (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.auto_closed'
              AND context ->> 'entity_id' = g[1]::text AND to_user_id = h[1]) = 1)::text,
      format('%s %s', st.state, j)];
    r := r || ARRAY['N3 confirming stops the jobs: G2 (played) and G3 (did not happen) got no reminder and no auto-close',
      (NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key IN ('activity.confirm_end_reminder', 'activity.auto_closed')
                    AND context ->> 'entity_id' IN (g[2]::text, g[3]::text))
       AND (SELECT state FROM public.event_lifecycle WHERE event_id = g[2]) = 'ended'
       AND (SELECT state FROM public.event_lifecycle WHERE event_id = g[3]) = 'did_not_happen')::text, ''];

    -- R1 (cont.) G4 at its new end: a fresh request under the new revision
    j := public.kan995_lifecycle_worker(e_end + interval '1 day 1 minute');
    SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'activity.confirm_end' AND context ->> 'entity_id' = g[4]::text;
    r := r || ARRAY['R1 reschedule: no reminder at the old time; a new confirm request at the new end',
      (n = 2 AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'activity.confirm_end_reminder'
                              AND context ->> 'entity_id' = g[4]::text)
       AND (SELECT end_revision FROM public.event_lifecycle WHERE event_id = g[4])
           = (SELECT schedule_revision FROM public.events WHERE id = g[4]))::text,
      format('confirm_end rows for G4=%s', n)];

    -- M1 meetup with no end_at: the end is start + 2h
    j := public.kan995_lifecycle_worker(m_start + interval '1 hour 59 minutes');
    n := (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.confirm_end' AND context ->> 'entity_id' = m::text);
    j := public.kan995_lifecycle_worker(m_start + interval '2 hours 1 minute');
    n2 := (SELECT count(*) FROM public.notifications WHERE kind_key = 'activity.confirm_end' AND context ->> 'entity_id' = m::text);
    SELECT * INTO st FROM public.event_lifecycle_state(m);
    r := r || ARRAY['M1 meetup without end_at: no request before start + 2h, one at start + 2h',
      (n = 0 AND n2 = 1 AND st.scheduled_end_at = m_start + interval '2 hours')::text,
      format('before=%s after=%s scheduled_end=%s', n, n2, st.scheduled_end_at)];

    -- K1 the KAN-994 contract: attendance_lifecycle reads event_lifecycle_state
    SELECT * INTO st FROM public.attendance_lifecycle(g[3]);
    r := r || ARRAY['K1 KAN-994 attendance_lifecycle reads the contract (did_not_happen for G3)',
      (st.source = 'event_lifecycle_state' AND st.state = 'did_not_happen')::text, format('%s %s', st.source, st.state)];

    RAISE EXCEPTION 'kan995_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan995_rollback' THEN RAISE; END IF;
  END;

  -- G1 grants: tables, sequence and server functions closed to clients; RPCs open to authenticated only
  r := r || ARRAY['G1 grants: tables/sequence/state/worker server-only; RPCs authenticated, not anon',
    (NOT has_table_privilege('authenticated', 'public.event_lifecycle', 'SELECT')
     AND NOT has_table_privilege('anon', 'public.event_lifecycle', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.event_lifecycle_transitions', 'SELECT')
     AND NOT has_sequence_privilege('authenticated', 'public.event_lifecycle_transitions_id_seq', 'USAGE')
     AND NOT has_function_privilege('authenticated', 'public.event_lifecycle_state(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.kan995_lifecycle_worker(timestamptz)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_event_start(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_event_start(uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_event_confirm_end(uuid,text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_event_confirm_end(uuid,text)', 'EXECUTE'))::text, ''];
  r := r || ARRAY['R nothing persisted',
    (NOT EXISTS (SELECT 1 FROM public.event_lifecycle WHERE event_id = ANY (g || m))
     AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE dedupe_key LIKE 'lifecycle:%'
                      AND context ->> 'entity_id' IN (SELECT unnest(g || m)::text)))::text, ''];

  FOR i IN 1 .. array_length(r, 1) / 3 LOOP
    INSERT INTO pg_temp.kan995_results VALUES (r[3 * i - 2], r[3 * i - 1]::boolean, r[3 * i]);
  END LOOP;
END $b$;

SELECT probe, pass, detail FROM pg_temp.kan995_results ORDER BY pass, probe;
