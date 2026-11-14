-- KAN-947 P-c live proof: series create (generator), occurrence edit, future edit and series cancel write events
-- first; games stays in parity; one activity row per occurrence; occurrence_time_taken still reported.
-- One DO block as postgres that ends by raising its result line (nothing survives). Callers act as authenticated.
-- RED on the pre-image: probe 1 (the series writers still call kan718_game_event_sync / kan718_game_derive).
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '490ce916-b984-4da5-af37-c0019402359e';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_geo   uuid := 'c2c5d4db-2db9-4e39-b403-0481957a100d';
  v_area  uuid;
  v_sid uuid; v_g1 uuid; v_g2 uuid; v_n int; v_txt text; v_j jsonb; v_out text; v_pass int; v_fail int;
  e public.events; g public.games; v_t1 timestamptz; v_t2 timestamptz;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k947c_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;
  SELECT count(*) INTO v_n FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('fn_generate_game_series_occurrences_kan712_inner', 'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner')
     AND p.prosrc ~ 'kan718_game_event_sync|kan718_game_derive';
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 0, 'series writers no longer write games-first', v_n || ' still games-first');
  SELECT area_id INTO v_area FROM public.geo_locations WHERE id = v_geo;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_sid := public.rpc_create_game_series('player', v_sport, v_var, v_geo, v_area, (now() + interval '3 days')::date, '18:00', 60,
           'Asia/Dubai', 'weekly', 4, 'KAN947c series', NULL, NULL, 'public', 'open', 3, 0);
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.series_id = v_sid AND e0.title = 'KAN947c series' AND g0.title = e0.title AND g0.start_at = e0.start_at AND g0.updated_at = e0.updated_at;
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 3, 'generator: 3 occurrences, events first, games mirrored', v_n || '/3');
  SELECT count(*) INTO v_n FROM public.public_activities a JOIN public.games g0 ON g0.id = a.id WHERE g0.series_id = v_sid AND a.activity_type = 'game_create';
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 3, 'generator: one activity row per occurrence', v_n || '/3');
  SELECT g0.id INTO v_g1 FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.series_id = v_sid ORDER BY e0.start_at LIMIT 1;
  SELECT g0.id INTO v_g2 FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.series_id = v_sid ORDER BY e0.start_at OFFSET 1 LIMIT 1;

  -- occurrence edit: title, capacity, space, later start
  SELECT start_at INTO v_t1 FROM public.events WHERE id = v_g1;
  SELECT start_at INTO v_t2 FROM public.events WHERE id = v_g2;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_j := public.rpc_edit_game_series_occurrence(v_g1, 'KAN947c one-off', v_t1 + interval '30 minutes', NULL, 6, v_space);
  EXECUTE 'RESET ROLE';
  SELECT * INTO e FROM public.events WHERE id = v_g1;
  SELECT * INTO g FROM public.games WHERE id = v_g1;
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_j->>'game_id' = v_g1::text AND e.title = 'KAN947c one-off' AND e.capacity = 6
         AND e.venue_id = '94de55e3-dbb9-40cb-8a07-a59364c46411' AND g.venue_space_id = v_space AND g.series_id = v_sid
         AND g.title = e.title AND g.start_at = e.start_at AND g.capacity = 6 AND g.venue_id = e.venue_id AND g.updated_at = e.updated_at,
         'occurrence edit: events first, games mirrored', format('%s cap=%s venue=%s', e.title, e.capacity, e.venue_id));

  -- occurrence edit onto another occurrence's start: occurrence_time_taken
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_j := public.rpc_edit_game_series_occurrence(v_g1, NULL, v_t2, NULL, NULL, NULL);
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_txt = 'occurrence_time_taken', 'occurrence edit onto a taken start refused', v_txt);

  -- future edit: title + capacity + space for every future row without players
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_j := public.rpc_edit_game_series_future(v_sid, 'KAN947c renamed', 8, NULL, NULL, v_space, NULL, false);
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.series_id = v_sid AND e0.title = 'KAN947c renamed' AND e0.capacity = 8 AND g0.venue_space_id = v_space
     AND e0.venue_id = '94de55e3-dbb9-40cb-8a07-a59364c46411' AND g0.title = e0.title AND g0.capacity = 8 AND g0.updated_at = e0.updated_at;
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 3 AND (v_j->>'updated')::int = 3, 'future edit: 3 rows, events first, games mirrored', v_j::text);

  -- series cancel (rpc_cancel_game per row): every occurrence cancelled in both tables, activity deleted
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_j := to_jsonb(public.rpc_cancel_game_series(v_sid, 'KAN947c end'));
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.series_id = v_sid AND e0.is_cancelled AND g0.is_cancelled AND g0.cancelled_at = e0.cancelled_at
     AND EXISTS (SELECT 1 FROM public.public_activities a WHERE a.id = g0.id AND a.is_deleted);
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 3, 'series cancel: 3 rows cancelled, games mirrored, activity deleted', v_j::text);

  SELECT count(*) INTO v_n FROM public.games g0 LEFT JOIN public.events e0 ON e0.id = g0.event_id AND e0.event_type = 'game'
   WHERE e0.id IS NULL OR ROW(g0.creator_profile_id, g0.creator_user_id, g0.title, g0.start_at, g0.end_at, g0.capacity, g0.listing_visibility,
             g0.join_policy, g0.is_cancelled, g0.cancelled_at, g0.cancelled_reason, g0.sport_id, g0.area_id, g0.geo_location_id,
             g0.venue_id, g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.request_id, g0.created_at, g0.updated_at)
         IS DISTINCT FROM
         ROW(e0.creator_profile_id, e0.creator_user_id, e0.title, e0.start_at, e0.end_at, e0.capacity, e0.listing_visibility,
             e0.join_policy, e0.is_cancelled, e0.cancelled_at, e0.cancelled_reason, e0.sport_id, e0.area_id, e0.geo_location_id,
             e0.venue_id, e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.request_id, e0.created_at, e0.updated_at);
  INSERT INTO k947c_tap(ok, label, detail) VALUES (v_n = 0, 'games <-> events parity over all games', v_n || ' mismatches');

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k947c_tap;
  RAISE EXCEPTION 'K947c RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;
