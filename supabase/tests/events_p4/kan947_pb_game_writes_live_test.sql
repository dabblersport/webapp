-- KAN-947 P-b live proof: update / reschedule / cancel write events first; games stays in parity; the cancel
-- side effects fire exactly once; a repeat cancel and a non-host edit behave as before.
-- One DO block as postgres that ends by raising its result line (nothing survives). Callers act as authenticated.
-- RED on the pre-image: probe 1 (the inners still call kan718_game_event_sync / kan718_game_derive).
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';
  v_uid2  uuid := '5dacb715-c263-4af8-ba22-b7a68799cbc6';
  v_pid2  uuid;
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '490ce916-b984-4da5-af37-c0019402359e';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_start timestamptz := date_trunc('hour', now()) + interval '11 days';
  v_g uuid; v_n int; v_m int; v_q0 int; v_txt text; v_out text; v_pass int; v_fail int;
  v_ca timestamptz; e public.events; g public.games;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k947b_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;
  SELECT count(*) INTO v_n FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('rpc_cancel_game_kan712_inner', 'rpc_reschedule_game_kan712_inner', 'rpc_update_game_kan712_inner', 'rpc_update_game_legacy_v1_kan712_inner')
     AND p.prosrc ~ 'kan718_game_event_sync|kan718_game_derive|UPDATE public\.games\s+SET (is_cancelled|start_at)';
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 0, 'P-b writers no longer write games-first', v_n || ' still games-first');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_g := public.rpc_create_game('player', v_sport, v_var, 'KAN947b probe', NULL, v_start, v_start + interval '1 hour',
           0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
  -- update (current client signature, 17 args): title, space, visibility, skill, max players, price
  v_txt := public.rpc_update_game(v_g, v_start + interval '1 hour', v_start + interval '2 hours', 'KAN947b edited', v_space, false,
           'followers', 'request', true, true, 3, 7, false, '{"note":"x"}'::jsonb, 4, 6, 15);
  EXECUTE 'RESET ROLE';
  SELECT * INTO e FROM public.events WHERE id = v_g;
  SELECT * INTO g FROM public.games WHERE id = v_g;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_txt = 'updated' AND e.title = 'KAN947b edited' AND e.start_at = v_start + interval '1 hour'
         AND e.listing_visibility = 'followers' AND e.join_policy = 'request' AND e.min_skill = 3 AND e.max_skill = 7 AND e.capacity = 6
         AND e.venue_id = '94de55e3-dbb9-40cb-8a07-a59364c46411' AND g.venue_space_id = v_space AND g.price_aed = 15
         AND g.rules->>'max_players' = '6' AND g.rules->>'note' = 'x' AND g.allow_spectators,
         'update: shared fields on events, game-only on games', format('%s title=%s cap=%s venue=%s vis=%s price=%s', v_txt, e.title, e.capacity, e.venue_id, e.listing_visibility, g.price_aed));
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.id = v_g
     AND (g0.title, g0.start_at, g0.end_at, g0.capacity, g0.venue_id, g0.geo_location_id, g0.area_id, g0.listing_visibility, g0.join_policy,
          g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.updated_at)
       = (e0.title, e0.start_at, e0.end_at, e0.capacity, e0.venue_id, e0.geo_location_id, e0.area_id, e0.listing_visibility, e0.join_policy,
          e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.updated_at);
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1, 'update: games mirrored from events', v_n::text);

  -- clear venue (keeps geo from the old venue, joining free) and clear skill
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := public.rpc_update_game(v_g, v_start + interval '1 hour', v_start + interval '2 hours', NULL, NULL, true,
           NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, NULL, NULL, 15);
  EXECUTE 'RESET ROLE';
  SELECT * INTO e FROM public.events WHERE id = v_g;
  SELECT * INTO g FROM public.games WHERE id = v_g;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (g.venue_space_id IS NULL AND e.min_skill IS NULL AND e.title = 'KAN947b edited'
         AND e.joining_rule = 'free' AND g.title = e.title AND g.min_skill IS NULL AND g.updated_at = e.updated_at,
         'update: clear venue + clear skill', format('space=%s skill=%s rule=%s', g.venue_space_id, e.min_skill, e.joining_rule));

  -- non-host refused
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_txt := public.rpc_update_game(v_g, v_start, v_start + interval '1 hour', 'hijack', NULL, false,
             NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, 0);
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  BEGIN
    PERFORM public.rpc_reschedule_game(v_g, v_start, v_start + interval '1 hour');
    v_txt := v_txt || ' / no error';
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || ' / ' || SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_txt = 'not_host_or_not_found / not_host_or_not_found', 'non-host update and reschedule refused', v_txt);

  -- reschedule by the host
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := public.rpc_reschedule_game(v_g, v_start + interval '3 hours', v_start + interval '5 hours');
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.id = v_g
     AND e0.start_at = v_start + interval '3 hours' AND g0.start_at = e0.start_at AND g0.end_at = e0.end_at AND g0.updated_at = e0.updated_at;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1 AND v_txt = 'rescheduled', 'reschedule: events then games mirror', v_txt);

  -- legacy_v1 update (server-only), as postgres with the host's claims
  v_txt := public.rpc_update_game_legacy_v1(v_g, v_start + interval '3 hours', v_start + interval '5 hours', 'KAN947b v1', NULL, false,
           NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, 8);
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.id = v_g
     AND e0.title = 'KAN947b v1' AND e0.capacity = 8 AND g0.title = e0.title AND g0.capacity = 8 AND g0.updated_at = e0.updated_at;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1, 'legacy_v1 update: events then games mirror', v_txt);

  -- cancel: notification, chat line, activity exactly once; repeat cancel keeps the first values
  SELECT p.id INTO v_pid2 FROM public.profiles p WHERE p.user_id = v_uid2 AND p.is_active ORDER BY p.created_at LIMIT 1;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (v_g, v_pid2, v_uid2, 'player', 'active');
  INSERT INTO public.msg_conversations (kind, game_id) VALUES ('game', v_g) ON CONFLICT DO NOTHING;
  SELECT count(*) INTO v_q0 FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
  SELECT count(*) INTO v_m FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := public.rpc_cancel_game(v_g, 'KAN947b cancel');
  EXECUTE 'RESET ROLE';
  SELECT cancelled_at INTO v_ca FROM public.events WHERE id = v_g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := v_txt || '/' || public.rpc_cancel_game(v_g, 'second reason');
  EXECUTE 'RESET ROLE';
  SELECT count(*) - v_m INTO v_n FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1, 'cancel x2: game.updated notification exactly once', v_n::text);
  SELECT count(*) - v_q0 INTO v_n FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1, 'cancel x2: chat system line exactly once', v_n::text);
  SELECT count(*) INTO v_n FROM public.public_activities WHERE id = v_g AND is_deleted;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1, 'cancel: activity row marked deleted (one row)', v_n::text);
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id WHERE g0.id = v_g
     AND e0.is_cancelled AND g0.is_cancelled AND e0.cancelled_reason = 'KAN947b cancel' AND g0.cancelled_reason = e0.cancelled_reason
     AND e0.cancelled_at = v_ca AND g0.cancelled_at = v_ca AND g0.updated_at = e0.updated_at;
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 1 AND v_txt = 'cancelled/cancelled', 'cancel: first cancel kept, games mirrored', v_txt);

  -- edit after cancel refused (as before)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_txt := public.rpc_update_game(v_g, v_start, v_start + interval '1 hour', 'after cancel', NULL, false,
             NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, 0);
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_txt = 'not_host_or_not_found', 'update after cancel refused', v_txt);

  SELECT count(*) INTO v_n FROM public.games g0 LEFT JOIN public.events e0 ON e0.id = g0.event_id AND e0.event_type = 'game'
   WHERE e0.id IS NULL OR ROW(g0.creator_profile_id, g0.creator_user_id, g0.title, g0.start_at, g0.end_at, g0.capacity, g0.listing_visibility,
             g0.join_policy, g0.is_cancelled, g0.cancelled_at, g0.cancelled_reason, g0.sport_id, g0.area_id, g0.geo_location_id,
             g0.venue_id, g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.request_id, g0.created_at, g0.updated_at)
         IS DISTINCT FROM
         ROW(e0.creator_profile_id, e0.creator_user_id, e0.title, e0.start_at, e0.end_at, e0.capacity, e0.listing_visibility,
             e0.join_policy, e0.is_cancelled, e0.cancelled_at, e0.cancelled_reason, e0.sport_id, e0.area_id, e0.geo_location_id,
             e0.venue_id, e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.request_id, e0.created_at, e0.updated_at);
  INSERT INTO k947b_tap(ok, label, detail) VALUES (v_n = 0, 'games <-> events parity over all games', v_n || ' mismatches');

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k947b_tap;
  RAISE EXCEPTION 'K947b RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;
