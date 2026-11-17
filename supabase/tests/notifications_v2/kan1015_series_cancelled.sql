-- KAN-1015: whole-series cancel sends game.series_cancelled. Live test, run as postgres on wtncuzcskpigqpmnxwws, whole
-- file in one session. Every write is inside a sub-block that is rolled back; only the results survive.
-- Fixture, built in each sub-block: one existing game_series with 2 occurrences O1, O2, set 4 and 11 days ahead,
-- not cancelled; PA plays in both, PB (Arabic) in O1, PC in O2. Consumer driven with p_now = now() + 2 min.
--   T1  whole-series cancel (rpc_cancel_game_series as its creator) -> one game.series_cancelled per person (PA once),
--       no series_changed / occurrence_cancelled / game.cancelled; EN and AR titles read right.
--   N1  negative control: a series edit (both occurrences moved in one statement) still sends game.series_changed,
--       and no series_cancelled.
--   T2  one occurrence cancelled alone -> game.occurrence_cancelled to that occurrence only, no series kind.
--   T3  one transaction cancels O1 and moves O2 (edit-future with an earlier end date) -> series_changed, not cancelled.
-- Expected: every row pass = true.
--
-- Run 2026-11-17 by backend-3 (Shed). Before applying 20261117163934: T1 false (0 game.series_cancelled; the real
-- rpc_cancel_game_series path was used, 2 occurrences cancelled), T1b null; N1, T2, T3 true (the baseline they keep).
-- After: all 6 rows pass, plus T4 below. T1 3 notices for 3 people via rpc_cancel_game_series; T1b en "All upcoming
-- KAN717 Rerun Series games were cancelled", ar "أُلغيت جميع مباريات KAN717 Rerun Series القادمة"; N1 series_changed=3;
-- T2 occurrence_cancelled=2 of 2; T3 series_changed=3. T4 (untitled series): "All upcoming Football games were
-- cancelled" / "أُلغيت جميع مباريات كرة القدم القادمة".

CREATE TEMP TABLE IF NOT EXISTS kan1015_results (probe text, pass boolean, detail text);
TRUNCATE kan1015_results;

DO $b$
DECLARE
  r text[] := '{}';
  sid uuid; screator uuid; o1 uuid; o2 uuid;
  pa uuid; pb uuid; pc uuid; pa_p uuid; pb_p uuid; pc_p uuid;
  want uuid[]; o1want uuid[]; n int; s text; s_ar text; j jsonb; path text;
  t0 timestamptz := now() + interval '2 minutes';
  scen text;
BEGIN
  SELECT gm.series_id INTO sid FROM public.games gm WHERE gm.series_id IS NOT NULL
   GROUP BY gm.series_id HAVING count(*) >= 2 ORDER BY gm.series_id LIMIT 1;
  SELECT gs.creator_user_id INTO screator FROM public.game_series gs WHERE gs.id = sid;
  SELECT (array_agg(gm.event_id ORDER BY gm.event_id))[1], (array_agg(gm.event_id ORDER BY gm.event_id))[2]
    INTO o1, o2 FROM public.games gm WHERE gm.series_id = sid;
  WITH c AS (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id FROM public.profiles p
     WHERE p.user_id IS NOT NULL AND p.is_active AND p.persona_type = 'player' AND p.user_id <> screator
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = p.user_id AND gr.game_id IN (o1, o2))
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
     ORDER BY p.user_id, p.created_at LIMIT 3)
  SELECT (array_agg(user_id ORDER BY user_id))[1], (array_agg(id ORDER BY user_id))[1],
         (array_agg(user_id ORDER BY user_id))[2], (array_agg(id ORDER BY user_id))[2],
         (array_agg(user_id ORDER BY user_id))[3], (array_agg(id ORDER BY user_id))[3]
    INTO pa, pa_p, pb, pb_p, pc, pc_p FROM c;
  IF o2 IS NULL OR pc IS NULL THEN RAISE EXCEPTION 'kan1015 test: fixture missing'; END IF;

  FOREACH scen IN ARRAY ARRAY['T1', 'N1', 'T2', 'T3'] LOOP
    BEGIN
      -- fixture
      UPDATE public.game_series SET status = 'active' WHERE id = sid;
      UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
             start_at = date_trunc('hour', now()) + interval '4 days', end_at = date_trunc('hour', now()) + interval '4 days 1 hour'
       WHERE id = o1;
      UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
             start_at = date_trunc('hour', now()) + interval '11 days', end_at = date_trunc('hour', now()) + interval '11 days 1 hour'
       WHERE id = o2;
      INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES
        (o1, pa_p, pa, 'player', 'active'), (o1, pb_p, pb, 'player', 'active'),
        (o2, pa_p, pa, 'player', 'active'), (o2, pc_p, pc, 'player', 'active');
      UPDATE public.profiles SET language = 'ar' WHERE user_id = pb;
      UPDATE public.profiles SET language = 'en' WHERE user_id IN (pa, pc);
      UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id IN (pa, pb, pc);
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || '{"w1_b3": "setup"}'::jsonb WHERE NOT (x.consumed_by ? 'w1_b3');
      SELECT array_agg(DISTINCT u ORDER BY u) INTO want FROM unnest(ARRAY[o1, o2]) e(id), LATERAL public.kan981_recipients(e.id) u;
      SELECT array_agg(u ORDER BY u) INTO o1want FROM public.kan981_recipients(o1) u;
      PERFORM set_config('request.jwt.claims', json_build_object('sub', screator, 'role', 'authenticated')::text, true);

      IF scen = 'T1' THEN
        BEGIN
          j := public.rpc_cancel_game_series(sid, 'kan1015 test');
          path := 'rpc_cancel_game_series ' || j::text;
        EXCEPTION WHEN raise_exception THEN
          UPDATE public.events SET is_cancelled = true, cancelled_at = now(), cancelled_reason = 'kan1015 test' WHERE id IN (o1, o2);
          path := 'direct one-statement cancel (rpc refused: ' || SQLERRM || ')';
        END;
        PERFORM public.kan981_consume_event_changes(t0);
        SELECT count(*) INTO n FROM public.notifications
         WHERE kind_key = 'game.series_cancelled' AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%';
        SELECT title INTO s FROM public.notifications WHERE kind_key = 'game.series_cancelled' AND to_user_id = pa
         AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%';
        SELECT title INTO s_ar FROM public.notifications WHERE kind_key = 'game.series_cancelled' AND to_user_id = pb
         AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%';
        r := r || ARRAY['T1 whole-series cancel -> one game.series_cancelled per active participant',
          (n = cardinality(want)
           AND (SELECT count(*) FROM public.notifications WHERE kind_key = 'game.series_cancelled' AND to_user_id = pa
                  AND dedupe_key LIKE 'w1_b3:series_cancel:%') = 1
           AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE dedupe_key LIKE 'w1_b3:%'
                            AND kind_key IN ('game.series_changed', 'game.occurrence_cancelled', 'game.cancelled')
                            AND context ->> 'entity_id' IN (o1::text, o2::text)))::text,
          format('sent=%s people=%s via %s', n, cardinality(want), path)];
        r := r || ARRAY['T1b titles read right in EN and AR (no "game games")',
          (s LIKE 'All upcoming % games were cancelled' AND s NOT LIKE '% game games%'
           AND s_ar LIKE 'أُلغيت جميع مباريات % القادمة' AND s_ar NOT LIKE '%مباريات مباراة%')::text,
          format('en="%s" ar="%s"', s, s_ar)];

      ELSIF scen = 'N1' THEN
        UPDATE public.events SET start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour' WHERE id IN (o1, o2);
        PERFORM public.kan981_consume_event_changes(t0);
        SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'game.series_changed' AND dedupe_key LIKE 'w1_b3:series:' || sid || ':%';
        r := r || ARRAY['N1 control: series edit still sends game.series_changed, never series_cancelled',
          (n = cardinality(want) AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'game.series_cancelled'
                                                   AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%'))::text,
          format('series_changed=%s people=%s', n, cardinality(want))];

      ELSIF scen = 'T2' THEN
        UPDATE public.events SET is_cancelled = true WHERE id = o1;
        PERFORM public.kan981_consume_event_changes(t0);
        SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'game.occurrence_cancelled' AND context ->> 'entity_id' = o1::text;
        r := r || ARRAY['T2 single occurrence cancel -> occurrence_cancelled to that occurrence only',
          (n = cardinality(o1want) AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE dedupe_key LIKE 'w1_b3:series%' || sid || ':%'))::text,
          format('occurrence_cancelled=%s want=%s', n, cardinality(o1want))];

      ELSE  -- T3
        UPDATE public.events SET is_cancelled = CASE WHEN id = o1 THEN true ELSE is_cancelled END,
                                 start_at = CASE WHEN id = o2 THEN start_at + interval '1 hour' ELSE start_at END,
                                 end_at   = CASE WHEN id = o2 THEN end_at + interval '1 hour' ELSE end_at END
         WHERE id IN (o1, o2);
        PERFORM public.kan981_consume_event_changes(t0);
        SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'game.series_changed' AND dedupe_key LIKE 'w1_b3:series:' || sid || ':%';
        r := r || ARRAY['T3 mixed cancel + move in one transaction -> series_changed, not series_cancelled',
          (n = cardinality(want) AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'game.series_cancelled'
                                                   AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%'))::text,
          format('series_changed=%s', n)];
      END IF;

      RAISE EXCEPTION 'kan1015_rollback';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'kan1015_rollback' THEN RAISE; END IF;
    END;
  END LOOP;

  r := r || ARRAY['R nothing persisted',
    (NOT EXISTS (SELECT 1 FROM public.notifications WHERE dedupe_key LIKE 'w1_b3:series%' || sid || ':%'
                  AND context ->> 'entity_id' IN (o1::text, o2::text)))::text, format('series=%s O1=%s O2=%s', sid, o1, o2)];
  FOR i IN 1 .. array_length(r, 1) / 3 LOOP
    INSERT INTO pg_temp.kan1015_results VALUES (r[3 * i - 2], r[3 * i - 1]::boolean, r[3 * i]);
  END LOOP;
END $b$;

SELECT probe, pass, detail FROM pg_temp.kan1015_results ORDER BY pass, probe;


-- T4: untitled series -> the sport name, without "game games" (run separately; result written after the rollback)
CREATE TEMP TABLE IF NOT EXISTS kan1015_t4 (probe text, pass boolean, detail text); TRUNCATE kan1015_t4;
DO $b$
DECLARE sid uuid; screator uuid; o1 uuid; o2 uuid; pa uuid; pb uuid; pa_p uuid; pb_p uuid; s text; s_ar text; sp_en text; sp_ar text;
BEGIN
  SELECT gm.series_id INTO sid FROM public.games gm WHERE gm.series_id IS NOT NULL GROUP BY gm.series_id HAVING count(*) >= 2 ORDER BY gm.series_id LIMIT 1;
  SELECT gs.creator_user_id INTO screator FROM public.game_series gs WHERE gs.id = sid;
  SELECT (array_agg(gm.event_id ORDER BY gm.event_id))[1], (array_agg(gm.event_id ORDER BY gm.event_id))[2] INTO o1, o2 FROM public.games gm WHERE gm.series_id = sid;
  SELECT (array_agg(user_id ORDER BY user_id))[1], (array_agg(id ORDER BY user_id))[1], (array_agg(user_id ORDER BY user_id))[2], (array_agg(id ORDER BY user_id))[2]
    INTO pa, pa_p, pb, pb_p FROM (SELECT DISTINCT ON (p.user_id) p.user_id, p.id FROM public.profiles p
     WHERE p.is_active AND p.persona_type = 'player' AND p.user_id <> screator
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = p.user_id AND gr.game_id IN (o1, o2))
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
     ORDER BY p.user_id LIMIT 2) c;
  SELECT sp.name_en, coalesce(nullif(btrim(sp.name_ar), ''), sp.name_en) INTO sp_en, sp_ar FROM public.events e JOIN public.sports sp ON sp.id = e.sport_id WHERE e.id = o1;
  BEGIN
    UPDATE public.game_series SET status = 'active', title = NULL WHERE id = sid;
    UPDATE public.events SET title = NULL, is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
           start_at = date_trunc('hour', now()) + CASE WHEN id = o1 THEN interval '4 days' ELSE interval '11 days' END,
           end_at   = date_trunc('hour', now()) + CASE WHEN id = o1 THEN interval '4 days 1 hour' ELSE interval '11 days 1 hour' END
     WHERE id IN (o1, o2);
    INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (o1, pa_p, pa, 'player', 'active'), (o2, pb_p, pb, 'player', 'active');
    UPDATE public.profiles SET language = 'en' WHERE user_id = pa;
    UPDATE public.profiles SET language = 'ar' WHERE user_id = pb;
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || '{"w1_b3": "setup"}'::jsonb WHERE NOT (x.consumed_by ? 'w1_b3');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', screator, 'role', 'authenticated')::text, true);
    PERFORM public.rpc_cancel_game_series(sid, 'kan1015 t4');
    PERFORM public.kan981_consume_event_changes(now() + interval '2 minutes');
    SELECT title INTO s FROM public.notifications WHERE kind_key = 'game.series_cancelled' AND to_user_id = pa AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%';
    SELECT title INTO s_ar FROM public.notifications WHERE kind_key = 'game.series_cancelled' AND to_user_id = pb AND dedupe_key LIKE 'w1_b3:series_cancel:' || sid || ':%';
    RAISE EXCEPTION 'kan1015_rollback';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'kan1015_rollback' THEN RAISE; END IF;
  END;
  INSERT INTO pg_temp.kan1015_t4 VALUES ('T4 untitled series: sport name, no "game games"',
    coalesce(s = 'All upcoming ' || sp_en || ' games were cancelled' AND s_ar = 'أُلغيت جميع مباريات ' || sp_ar || ' القادمة', false),
    format('en="%s" ar="%s"', s, s_ar));
END $b$;
SELECT * FROM pg_temp.kan1015_t4;

-- KAN-1015b (PEER 16466): a series batch is a whole-series cancel only when the series is over (status 'ended', or no
-- future non-cancelled occurrence remains). Three occurrences: O1 (day 4, PA), O2 (day 11, empty), O3 (day 18, PC;
-- a borrowed game moved into the series, its creator set to the series creator). Each scenario rolled back.
--   T5   one statement cancels O2 and O3 while O1 goes on (what a shortened edit-future does) -> series_changed to
--        O3's players, NO series_cancelled. (Players on O3 make the classification visible; the real RPC never
--        cancels a date with players, see T6.)
--   T5c  control: one statement cancels O1, O2 and O3 (series still 'active', nothing future left) -> series_cancelled.
--   T6   the real rpc_edit_game_series_future with an earlier ends_on: the empty later dates are cancelled, O1 is kept,
--        and no series_cancelled is written.
-- Run 2026-11-17 (backend-3). Before 20261117165950: T5 FALSE (series_changed=0, series_cancelled=1: PC was told the
-- whole series was cancelled while O1 goes on), T5c true, T6 true (2 empty dates cancelled, nothing sent). After: T5
-- true (series_changed=1, series_cancelled=0), T5c true (series_cancelled=2), T6 true; T1/T1b/N1/T2/T3 above re-run
-- and still pass (T1 3 for 3 via rpc_cancel_game_series, status 'ended').
CREATE TEMP TABLE IF NOT EXISTS kan1015b_results (probe text, pass boolean, detail text); TRUNCATE kan1015b_results;
DO $b$
DECLARE
  r text[] := '{}';
  sid uuid; screator uuid; o1 uuid; o2 uuid; o3 uuid; pa uuid; pc uuid; pa_p uuid; pc_p uuid;
  n_ch int; n_ca int; j jsonb; scen text; t0 timestamptz := now() + interval '2 minutes';
BEGIN
  SELECT gm.series_id INTO sid FROM public.games gm WHERE gm.series_id IS NOT NULL GROUP BY gm.series_id HAVING count(*) >= 2 ORDER BY gm.series_id LIMIT 1;
  SELECT gs.creator_user_id INTO screator FROM public.game_series gs WHERE gs.id = sid;
  SELECT (array_agg(gm.event_id ORDER BY gm.event_id))[1], (array_agg(gm.event_id ORDER BY gm.event_id))[2] INTO o1, o2 FROM public.games gm WHERE gm.series_id = sid;
  SELECT e.id INTO o3 FROM public.events e JOIN public.games gm ON gm.event_id = e.id
   WHERE e.event_type = 'game' AND gm.series_id IS NULL AND gm.venue_space_id IS NULL
     AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = e.id AND gr.user_id <> e.creator_user_id)
   ORDER BY e.id LIMIT 1;
  SELECT (array_agg(user_id ORDER BY user_id))[1], (array_agg(id ORDER BY user_id))[1], (array_agg(user_id ORDER BY user_id))[2], (array_agg(id ORDER BY user_id))[2]
    INTO pa, pa_p, pc, pc_p FROM (SELECT DISTINCT ON (p.user_id) p.user_id, p.id FROM public.profiles p
     WHERE p.is_active AND p.persona_type = 'player' AND p.user_id <> screator
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = p.user_id AND gr.game_id IN (o1, o2, o3))
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
     ORDER BY p.user_id LIMIT 2) c;
  IF o3 IS NULL OR pc IS NULL THEN RAISE EXCEPTION 'kan1015b test: fixture missing'; END IF;

  FOREACH scen IN ARRAY ARRAY['T5', 'T5c', 'T6'] LOOP
    BEGIN
      UPDATE public.game_series SET status = 'active', ends_on = NULL WHERE id = sid;
      UPDATE public.events SET creator_user_id = screator WHERE id = o3;
      UPDATE public.games SET series_id = sid WHERE event_id = o3;
      DELETE FROM public.game_roster WHERE game_id = o3;   -- the borrowed game's own host row would count as a player
      UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
             start_at = date_trunc('day', now()) + CASE id WHEN o1 THEN interval '4 days 18 hours' WHEN o2 THEN interval '11 days 18 hours' ELSE interval '18 days 18 hours' END,
             end_at   = date_trunc('day', now()) + CASE id WHEN o1 THEN interval '4 days 19 hours' WHEN o2 THEN interval '11 days 19 hours' ELSE interval '18 days 19 hours' END
       WHERE id IN (o1, o2, o3);
      INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (o1, pa_p, pa, 'player', 'active');
      IF scen <> 'T6' THEN
        INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (o3, pc_p, pc, 'player', 'active');
      END IF;
      UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id IN (pa, pc);
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || '{"w1_b3": "setup"}'::jsonb WHERE NOT (x.consumed_by ? 'w1_b3');
      PERFORM set_config('request.jwt.claims', json_build_object('sub', screator, 'role', 'authenticated')::text, true);

      IF scen = 'T5' THEN
        UPDATE public.events SET is_cancelled = true WHERE id IN (o2, o3);
      ELSIF scen = 'T5c' THEN
        UPDATE public.events SET is_cancelled = true WHERE id IN (o1, o2, o3);
      ELSE
        j := public.rpc_edit_game_series_future(sid, p_ends_on => (date_trunc('day', now()) + interval '6 days')::date);
      END IF;
      PERFORM public.kan981_consume_event_changes(t0);
      SELECT count(*) FILTER (WHERE kind_key = 'game.series_changed'), count(*) FILTER (WHERE kind_key = 'game.series_cancelled')
        INTO n_ch, n_ca FROM public.notifications WHERE dedupe_key LIKE 'w1_b3:series%' || sid || ':%';

      IF scen = 'T5' THEN
        r := r || ARRAY['T5 shortened series (later dates cancelled, O1 goes on) -> series_changed, not series_cancelled',
          (n_ca = 0 AND n_ch >= 1 AND EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'game.series_changed'
                                                AND to_user_id = pc AND dedupe_key LIKE 'w1_b3:series:' || sid || ':%'))::text,
          format('series_changed=%s series_cancelled=%s', n_ch, n_ca)];
      ELSIF scen = 'T5c' THEN
        r := r || ARRAY['T5c control: every future date cancelled -> series_cancelled',
          (n_ca = (SELECT count(DISTINCT u) FROM unnest(ARRAY[o1, o2, o3]) e(id), LATERAL public.kan981_recipients(e.id) u)
           AND n_ca >= 2 AND n_ch = 0)::text, format('series_cancelled=%s series_changed=%s', n_ca, n_ch)];
      ELSE
        r := r || ARRAY['T6 real rpc_edit_game_series_future with an earlier end -> no series_cancelled, O1 kept',
          (n_ca = 0 AND NOT (SELECT is_cancelled FROM public.events WHERE id = o1)
           AND (SELECT is_cancelled FROM public.events WHERE id = o3))::text,
          format('%s series_cancelled=%s series_changed=%s', j, n_ca, n_ch)];
      END IF;
      RAISE EXCEPTION 'kan1015_rollback';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'kan1015_rollback' THEN RAISE; END IF;
    END;
  END LOOP;
  FOR i IN 1 .. array_length(r, 1) / 3 LOOP INSERT INTO pg_temp.kan1015b_results VALUES (r[3*i-2], r[3*i-1]::boolean, r[3*i]); END LOOP;
END $b$;
SELECT * FROM pg_temp.kan1015b_results ORDER BY probe;
