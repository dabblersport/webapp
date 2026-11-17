-- KAN-981 [W1-B3] event change and cancel notices: live test. Run as postgres on wtncuzcskpigqpmnxwws, the whole file in
-- one session. Nothing persists: every write is inside one sub-block that ends with 'kan981_rollback'; only the
-- results survive (plpgsql variables). The consumer is driven with p_now = now() + 2 min, so the 60 s debounce is
-- passed without waiting. All edits in the block share one transaction time (occurred_at = now()).
-- Fixtures, picked live and built inside the block (no live game has 2+ players, no series has players):
--   G  a non-series game with a venue and no venue space; moved 3 days ahead; players PA, PB active, PL left.
--   V2 another venue (venue move).
--   M  a future meetup with a 'going' and an 'interested' RSVP from people other than its creator.
--   O1, O2  two games put into one existing game_series, moved ahead to different days, un-cancelled;
--           PA plays in both, PB in O1 only, PC in O2 only.
-- Expected: every row of the final SELECT has pass = true.
-- Negative controls: G6 (a reverted change plus a title edit notify nobody), the left player PL and the creator in
-- G2/G7, PC in S2, and N1 (with game.time_changed switched off, the same kind of move writes nothing, so the G2 predicate
-- would be false).
--
-- Run 2026-11-17 by backend-3 (Shed), after applying 20261117102109: 19 of 19 pass. (The first run had K1 false because
-- of a test bug: its breaks_quiet regex also matched game.waitlist_position_changed, which is not a KAN-981 kind. Fixed
-- to the explicit list.) G = 1ca21e67-6d05-431a-8252-58b81bb0ad7e (2 recipients), M = 91507e60-3d08-4583-beb5-d0718287e6b6
-- (7 recipients), series 11b397b6-177f-4b3e-8b78-7c80636f83ea. Results:
--   G2: old_en 'Fri 20 Nov, 14:00–16:00' -> new_en 'Fri 20 Nov, 15:00–17:00', old_ar 'الجمعة 20 نوفمبر، 14:00–16:00'.
--   G4: field_en 'Places, Who can join, Skill level'.
--   G5: '1Rebel DIFC' -> 'REAL GYM 365'.
--   S1: 3 series notices for 3 people. S2: 0 immediate, 2 sent.
--   M1/M2: 7 = 7. Cron job runs succeeded every minute after the apply.

CREATE TEMP TABLE IF NOT EXISTS kan981_results (probe text, pass boolean, detail text);
TRUNCATE kan981_results;

-- K: catalogue ---------------------------------------------------------------------------------------------------------
INSERT INTO kan981_results
SELECT 'K1 kinds: 10 active, game.updated off, meetup series kinds off',
       count(*) FILTER (WHERE is_active AND key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed',
             'game.details_changed', 'game.occurrence_cancelled', 'game.series_changed', 'meetup.time_changed',
             'meetup.venue_changed', 'meetup.details_changed', 'meetup.cancelled')) = 10
   AND bool_and(NOT is_active) FILTER (WHERE key IN ('game.updated', 'meetup.occurrence_cancelled', 'meetup.series_changed'))
   AND bool_and(breaks_quiet) FILTER (WHERE key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed',
             'game.details_changed', 'game.occurrence_cancelled', 'game.series_changed', 'meetup.time_changed',
             'meetup.venue_changed', 'meetup.details_changed', 'meetup.cancelled')),
       string_agg(key || '=' || is_active, ', ' ORDER BY key) FILTER (WHERE key ~ '(cancelled|_changed|updated)$')
  FROM public.notification_kinds WHERE key ~ '^(game|meetup)\.';

INSERT INTO kan981_results
SELECT 'K2 cancel trigger covers both types, 13 triggers on events',
       pg_get_triggerdef(t.oid) LIKE '%WHEN ((old.is_cancelled IS DISTINCT FROM new.is_cancelled))%'
   AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal) = 13,
       pg_get_triggerdef(t.oid)
  FROM pg_trigger t WHERE t.tgrelid = 'public.events'::regclass AND t.tgname = 'trg_kan947_events_game_updated_notify';

INSERT INTO kan981_results
SELECT 'K3 old senders gone (no game.updated / process_notification_event in either body)',
       position('game.updated' IN a) = 0 AND position('process_notification_event' IN a) = 0
   AND position('process_notification_event' IN b) = 0, 'checked bodies'
  FROM (SELECT pg_get_functiondef('public.trg_game_updated_notify()'::regprocedure) a,
               pg_get_functiondef('public.rpc_meetup_cancel_kan712_inner(uuid)'::regprocedure) b) z;

INSERT INTO kan981_results
SELECT 'K4 cron every minute, active; consumer not executable by clients',
       j.active AND j.schedule = '* * * * *'
   AND NOT has_function_privilege('authenticated', 'public.kan981_consume_event_changes(timestamptz,interval,interval)', 'EXECUTE')
   AND NOT has_function_privilege('anon', 'public.kan981_consume_event_changes(timestamptz,interval,interval)', 'EXECUTE'),
       j.command
  FROM cron.job j WHERE j.jobname = 'kan981_event_changes_every_minute';

-- counts notices written by KAN-981 for one kind and event (optionally one user)
CREATE OR REPLACE FUNCTION pg_temp.k981_n(p_kind text, p_event uuid, p_user uuid DEFAULT NULL) RETURNS int
LANGUAGE sql STABLE AS $$
  SELECT count(*)::int FROM public.notifications n
   WHERE n.kind_key = p_kind AND n.context ->> 'entity_id' = p_event::text AND n.dedupe_key LIKE 'w1_b3:%'
     AND (p_user IS NULL OR n.to_user_id = p_user) $$;

-- B: behaviour (rolled back) -------------------------------------------------------------------------------------------
DO $b$
DECLARE
  r      text[] := '{}';
  g      public.events;  m public.events;  o1 uuid; o2 uuid; sid uuid; v2 uuid;
  pa     uuid; pb uuid; pc uuid; pl uuid;           -- user ids
  pa_p   uuid; pb_p uuid; pc_p uuid; pl_p uuid;     -- profile ids
  want   uuid[]; got uuid[]; mwant uuid[]; swant uuid[]; o1want uuid[];
  n int; n2 int; cap int; ok boolean; s text; j jsonb; ids bigint[];
  t0     timestamptz := now() + interval '2 minutes';
BEGIN
  SELECT e.* INTO g FROM public.events e JOIN public.games gm ON gm.event_id = e.id
   WHERE e.event_type = 'game' AND NOT e.is_cancelled AND e.venue_id IS NOT NULL
     AND gm.series_id IS NULL AND gm.venue_space_id IS NULL ORDER BY e.id LIMIT 1;
  SELECT v.id INTO v2 FROM public.venues v WHERE v.id <> g.venue_id AND v.is_active AND v.name_en IS NOT NULL
   ORDER BY v.id LIMIT 1;
  SELECT e.* INTO m FROM public.events e WHERE e.event_type = 'meetup' AND NOT e.is_cancelled
     AND e.start_at > now() + interval '1 day'
     AND EXISTS (SELECT 1 FROM public.meetup_rsvps s WHERE s.meetup_id = e.id AND s.status = 'going' AND s.user_id <> e.creator_user_id)
     AND EXISTS (SELECT 1 FROM public.meetup_rsvps s WHERE s.meetup_id = e.id AND s.status = 'interested' AND s.user_id <> e.creator_user_id)
   ORDER BY e.id LIMIT 1;
  SELECT gm.series_id INTO sid FROM public.games gm WHERE gm.series_id IS NOT NULL
   GROUP BY gm.series_id HAVING count(*) >= 2 ORDER BY gm.series_id LIMIT 1;
  SELECT (array_agg(gm.event_id ORDER BY gm.event_id))[1], (array_agg(gm.event_id ORDER BY gm.event_id))[2]
    INTO o1, o2 FROM public.games gm WHERE gm.series_id = sid;

  -- four people who are not the creators of G, O1, O2 and not already on G
  WITH c AS (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id
      FROM public.profiles p
     WHERE p.user_id IS NOT NULL AND p.is_active
       AND p.user_id NOT IN (SELECT e.creator_user_id FROM public.events e WHERE e.id IN (g.id, o1, o2))
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = p.user_id AND gr.game_id IN (g.id, o1, o2))
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = p.user_id OR b.blocked_user_id = p.user_id)
     ORDER BY p.user_id, p.created_at)
  SELECT (array_agg(user_id ORDER BY user_id))[1], (array_agg(id ORDER BY user_id))[1],
         (array_agg(user_id ORDER BY user_id))[2], (array_agg(id ORDER BY user_id))[2],
         (array_agg(user_id ORDER BY user_id))[3], (array_agg(id ORDER BY user_id))[3],
         (array_agg(user_id ORDER BY user_id))[4], (array_agg(id ORDER BY user_id))[4]
    INTO pa, pa_p, pb, pb_p, pc, pc_p, pl, pl_p FROM (SELECT * FROM c LIMIT 4) c;

  IF g.id IS NULL OR v2 IS NULL OR m.id IS NULL OR o2 IS NULL OR pl IS NULL THEN
    RAISE EXCEPTION 'kan981 test: fixture missing g=% v2=% m=% o2=% pl=%', g.id, v2, m.id, o2, pl;
  END IF;

  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', g.creator_user_id, 'role', 'authenticated')::text, true);

    -- setup: G 3 days ahead; O1, O2 ahead on different days and not cancelled; rosters; setup rows marked consumed
    UPDATE public.events SET start_at = date_trunc('hour', now()) + interval '3 days',
                             end_at   = date_trunc('hour', now()) + interval '3 days 2 hours' WHERE id = g.id;
    UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
                             start_at = date_trunc('hour', now()) + interval '4 days',
                             end_at   = date_trunc('hour', now()) + interval '4 days 1 hour' WHERE id = o1;
    UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
                             start_at = date_trunc('hour', now()) + interval '11 days',
                             end_at   = date_trunc('hour', now()) + interval '11 days 1 hour' WHERE id = o2;
    INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES
      (g.id, pa_p, pa, 'player', 'active'), (g.id, pb_p, pb, 'player', 'active'),
      (o1, pa_p, pa, 'player', 'active'), (o1, pb_p, pb, 'player', 'active'),
      (o2, pa_p, pa, 'player', 'active'), (o2, pc_p, pc, 'player', 'active');
    INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status, left_at) VALUES
      (g.id, pl_p, pl, 'player', 'left', now());
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || '{"w1_b3": "setup"}'::jsonb
     WHERE NOT (x.consumed_by ? 'w1_b3');
    SELECT array_agg(u ORDER BY u) INTO want FROM public.kan981_recipients(g.id) u;
    SELECT g2.* INTO g FROM public.events g2 WHERE g2.id = g.id;
    r := r || ARRAY['F0 fixtures', (pa = ANY (want) AND pb = ANY (want) AND NOT pl = ANY (want)
                                    AND NOT g.creator_user_id = ANY (want))::text,
                    format('G=%s recipients=%s M=%s series=%s O1=%s O2=%s', g.id, cardinality(want), m.id, sid, o1, o2)];

    -- G1 debounce: right after the edit (p_now = now()) nothing is sent and the rows stay pending
    UPDATE public.events SET start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour' WHERE id = g.id;
    j := public.kan981_consume_event_changes(now());
    SELECT count(*) INTO n FROM public.event_changes x WHERE x.event_id = g.id AND NOT (x.consumed_by ? 'w1_b3');
    r := r || ARRAY['G1 debounce: nothing sent inside the 60 s settle window',
                    (pg_temp.k981_n('game.time_changed', g.id) = 0 AND n = 2)::text, format('%s pending=%s', j, n)];

    -- G2 time change: one game.time_changed per active participant, old -> new, EN and AR; nobody else
    SELECT array_agg(x.id) INTO ids FROM public.event_changes x WHERE x.event_id = g.id AND NOT (x.consumed_by ? 'w1_b3');
    j := public.kan981_consume_event_changes(t0);
    SELECT array_agg(n0.to_user_id ORDER BY n0.to_user_id) INTO got FROM public.notifications n0
     WHERE n0.kind_key = 'game.time_changed' AND n0.context ->> 'entity_id' = g.id::text;
    SELECT n0.args INTO j FROM public.notifications n0
     WHERE n0.kind_key = 'game.time_changed' AND n0.context ->> 'entity_id' = g.id::text AND n0.to_user_id = pa;
    r := r || ARRAY['G2 time change: exactly one per active participant, left/creator excluded',
                    (got = want AND pg_temp.k981_n('game.time_changed', g.id, pl) = 0
                     AND pg_temp.k981_n('game.time_changed', g.id, g.creator_user_id) = 0)::text,
                    format('sent=%s want=%s', cardinality(got), cardinality(want))];
    r := r || ARRAY['G2b args: old and new times in EN and AR (event timezone)',
                    (j ->> 'old_en' <> j ->> 'new_en' AND j ->> 'old_en' ~ '^\w{3} \d+ \w{3}, \d\d:\d\d–\d\d:\d\d$'
                     AND j ->> 'old_ar' ~ '(الأحد|الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة|السبت)')::text,
                    format('old_en=%s new_en=%s old_ar=%s', j ->> 'old_en', j ->> 'new_en', j ->> 'old_ar')];

    -- G3 dedupe: the same batch replayed (rows un-consumed) writes nothing new; a second run writes nothing either
    n := pg_temp.k981_n('game.time_changed', g.id);
    UPDATE public.event_changes x SET consumed_by = x.consumed_by - 'w1_b3' WHERE x.id = ANY (ids);
    PERFORM public.kan981_consume_event_changes(t0);
    PERFORM public.kan981_consume_event_changes(t0);
    r := r || ARRAY['G3 dedupe: replayed batch and second run add nothing',
                    (pg_temp.k981_n('game.time_changed', g.id) = n)::text,
                    format('before=%s after=%s', n, pg_temp.k981_n('game.time_changed', g.id))];

    -- G4 one save with two fields + a second edit in the burst -> one details notice listing all three
    UPDATE public.events SET capacity = CASE WHEN capacity >= 64 THEN capacity - 1 ELSE capacity + 1 END,
                             join_policy = CASE WHEN join_policy = 'request' THEN 'open' ELSE 'request' END WHERE id = g.id;
    UPDATE public.events SET min_skill = CASE WHEN min_skill IS NULL THEN 3 ELSE NULL END WHERE id = g.id;
    PERFORM public.kan981_consume_event_changes(t0);
    SELECT n0.args ->> 'field_en' INTO s FROM public.notifications n0
     WHERE n0.kind_key = 'game.details_changed' AND n0.context ->> 'entity_id' = g.id::text AND n0.to_user_id = pa;
    r := r || ARRAY['G4 burst of edits -> one details notice per person listing every field',
                    (pg_temp.k981_n('game.details_changed', g.id) = cardinality(want)
                     AND pg_temp.k981_n('game.details_changed', g.id, pa) = 1
                     AND s LIKE '%Places%' AND s LIKE '%Who can join%' AND s LIKE '%Skill level%')::text,
                    format('field_en=%s', s)];

    -- G5 venue move -> game.venue_changed, old venue name -> new venue name
    UPDATE public.events SET venue_id = v2 WHERE id = g.id;
    PERFORM public.kan981_consume_event_changes(t0);
    SELECT n0.args INTO j FROM public.notifications n0
     WHERE n0.kind_key = 'game.venue_changed' AND n0.context ->> 'entity_id' = g.id::text AND n0.to_user_id = pa;
    r := r || ARRAY['G5 venue move: one venue notice per person, old -> new name',
                    (pg_temp.k981_n('game.venue_changed', g.id) = cardinality(want)
                     AND j ->> 'new_en' = (SELECT v.name_en FROM public.venues v WHERE v.id = v2)
                     AND j ->> 'old_en' IS DISTINCT FROM j ->> 'new_en')::text,
                    format('old=%s new=%s', j ->> 'old_en', j ->> 'new_en')];

    -- G6 negative: a change that ends where it started, and a title change, notify nobody
    n := (SELECT count(*) FROM public.notifications n0 WHERE n0.context ->> 'entity_id' = g.id::text AND n0.dedupe_key LIKE 'w1_b3:%');
    SELECT e.capacity INTO cap FROM public.events e WHERE e.id = g.id;
    UPDATE public.events SET capacity = CASE WHEN cap > 2 THEN cap - 1 ELSE cap + 1 END WHERE id = g.id;
    UPDATE public.events SET capacity = cap WHERE id = g.id;
    UPDATE public.events SET title = coalesce(title, '') || ' k981' WHERE id = g.id;
    j := public.kan981_consume_event_changes(t0);
    n2 := (SELECT count(*) FROM public.notifications n0 WHERE n0.context ->> 'entity_id' = g.id::text AND n0.dedupe_key LIKE 'w1_b3:%');
    r := r || ARRAY['G6 negative: reverted capacity + title edit -> no notice, rows consumed',
                    (n2 = n AND NOT EXISTS (SELECT 1 FROM public.event_changes x WHERE x.event_id = g.id AND NOT (x.consumed_by ? 'w1_b3')))::text,
                    format('%s notices %s -> %s', j, n, n2)];

    -- G7 cancel: immediate game.cancelled, one per active participant; no game.updated; consumer adds nothing
    n := (SELECT count(*) FROM public.notifications n0 WHERE n0.kind_key = 'game.updated' AND n0.context ->> 'entity_id' = g.id::text);
    UPDATE public.events SET is_cancelled = true, cancelled_at = now(), cancelled_reason = 'kan981 test' WHERE id = g.id;
    SELECT array_agg(n0.to_user_id ORDER BY n0.to_user_id) INTO got FROM public.notifications n0
     WHERE n0.kind_key = 'game.cancelled' AND n0.context ->> 'entity_id' = g.id::text;
    PERFORM public.kan981_consume_event_changes(t0);
    r := r || ARRAY['G7 game cancel: game.cancelled exactly once per active participant at once, no game.updated',
                    (got = want AND pg_temp.k981_n('game.cancelled', g.id) = cardinality(want)
                     AND (SELECT count(*) FROM public.notifications n0 WHERE n0.kind_key = 'game.updated'
                           AND n0.context ->> 'entity_id' = g.id::text) = n
                     AND pg_temp.k981_n('game.cancelled', g.id, pl) = 0
                     AND NOT EXISTS (SELECT 1 FROM public.event_changes x WHERE x.event_id = g.id AND NOT (x.consumed_by ? 'w1_b3')))::text,
                    format('cancelled=%s want=%s', cardinality(got), cardinality(want))];

    -- M1 meetup time change -> going + interested, not the creator
    SELECT array_agg(u ORDER BY u) INTO mwant FROM public.kan981_recipients(m.id) u;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', m.creator_user_id, 'role', 'authenticated')::text, true);
    UPDATE public.events SET start_at = start_at + interval '30 minutes',
                             end_at = CASE WHEN end_at IS NULL THEN NULL ELSE end_at + interval '30 minutes' END WHERE id = m.id;
    PERFORM public.kan981_consume_event_changes(t0);
    SELECT array_agg(n0.to_user_id ORDER BY n0.to_user_id) INTO got FROM public.notifications n0
     WHERE n0.kind_key = 'meetup.time_changed' AND n0.context ->> 'entity_id' = m.id::text;
    r := r || ARRAY['M1 meetup time change: going and interested, once each, not the creator',
                    (got = mwant AND NOT m.creator_user_id = ANY (got)
                     AND (SELECT bool_and(s0.status IN ('going', 'interested')) FROM public.meetup_rsvps s0
                           WHERE s0.meetup_id = m.id AND s0.user_id = ANY (got)))::text,
                    format('sent=%s want=%s', cardinality(got), cardinality(mwant))];

    -- M2 meetup cancel through the RPC: meetup.cancelled exactly once per participant (old loop gone)
    PERFORM public.rpc_meetup_cancel(m.id);
    SELECT array_agg(n0.to_user_id ORDER BY n0.to_user_id) INTO got FROM public.notifications n0
     WHERE n0.kind_key = 'meetup.cancelled' AND n0.context ->> 'entity_id' = m.id::text;
    r := r || ARRAY['M2 rpc_meetup_cancel: meetup.cancelled exactly once per participant',
                    (got = mwant AND pg_temp.k981_n('meetup.cancelled', m.id) = cardinality(mwant))::text,
                    format('rows=%s want=%s', cardinality(got), cardinality(mwant))];

    -- S1 series change: one statement moves O1 and O2 -> one game.series_changed per person (PA once), no time notice
    PERFORM set_config('request.jwt.claims', json_build_object('sub', g.creator_user_id, 'role', 'authenticated')::text, true);
    SELECT array_agg(DISTINCT u ORDER BY u) INTO swant FROM unnest(ARRAY[o1, o2]) e(id), LATERAL public.kan981_recipients(e.id) u;
    SELECT array_agg(u ORDER BY u) INTO o1want FROM public.kan981_recipients(o1) u;
    UPDATE public.events SET start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour' WHERE id IN (o1, o2);
    j := public.kan981_consume_event_changes(t0);
    SELECT count(*) INTO n FROM public.notifications n0 WHERE n0.kind_key = 'game.series_changed' AND n0.dedupe_key LIKE 'w1_b3:series:' || sid || ':%';
    r := r || ARRAY['S1 series change: one series notice per person across the occurrences',
                    (n = cardinality(swant) AND pa = ANY (swant) AND (SELECT count(*) FROM public.notifications n0 WHERE n0.kind_key = 'game.series_changed'
                                  AND n0.to_user_id = pa AND n0.dedupe_key LIKE 'w1_b3:series:%') = 1
                     AND pg_temp.k981_n('game.time_changed', o1) = 0 AND pg_temp.k981_n('game.time_changed', o2) = 0)::text,
                    format('%s series notices=%s distinct people=%s', j, n, cardinality(swant))];

    -- S2 one occurrence cancelled -> nothing at once (series), then occurrence_cancelled to O1's players only
    UPDATE public.events SET is_cancelled = true WHERE id = o1;
    n := pg_temp.k981_n('game.occurrence_cancelled', o1) + pg_temp.k981_n('game.cancelled', o1);
    PERFORM public.kan981_consume_event_changes(t0);
    SELECT array_agg(n0.to_user_id ORDER BY n0.to_user_id) INTO got FROM public.notifications n0
     WHERE n0.kind_key = 'game.occurrence_cancelled' AND n0.context ->> 'entity_id' = o1::text;
    r := r || ARRAY['S2 occurrence cancel: only that occurrence''s players, once each',
                    (n = 0 AND got = o1want AND pa = ANY (got) AND pb = ANY (got)
                     AND pg_temp.k981_n('game.occurrence_cancelled', o1, pc) = 0
                     AND pg_temp.k981_n('game.cancelled', o1) = 0)::text,
                    format('immediate=%s sent=%s', n, cardinality(got))];

    -- N1 negative control: with game.time_changed switched off the G2 predicate goes false (nothing is written)
    UPDATE public.notification_kinds SET is_active = false WHERE key = 'game.time_changed';
    UPDATE public.events SET start_at = start_at + interval '2 hours', end_at = end_at + interval '2 hours' WHERE id = o2;
    PERFORM public.kan981_consume_event_changes(t0);
    r := r || ARRAY['N1 control: kind off -> no time notice for O2 (G2 predicate would be false)',
                    (pg_temp.k981_n('game.time_changed', o2) = 0)::text,
                    format('O2 time notices=%s', pg_temp.k981_n('game.time_changed', o2))];

    RAISE EXCEPTION 'kan981_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan981_rollback' THEN RAISE; END IF;
  END;

  r := r || ARRAY['R nothing persisted',
                  (NOT EXISTS (SELECT 1 FROM public.notifications n0 WHERE n0.dedupe_key LIKE 'w1_b3:%'
                                 AND n0.context ->> 'entity_id' IN (g.id::text, m.id::text, o1::text, o2::text))
                   AND (SELECT is_active FROM public.notification_kinds WHERE key = 'game.time_changed')
                   AND NOT (SELECT is_cancelled FROM public.events WHERE id = m.id))::text, 'ok'];

  FOR i IN 1 .. array_length(r, 1) / 3 LOOP
    INSERT INTO pg_temp.kan981_results VALUES (r[3 * i - 2], r[3 * i - 1]::boolean, r[3 * i]);
  END LOOP;
END $b$;

SELECT probe, pass, detail FROM pg_temp.kan981_results ORDER BY pass, probe;
