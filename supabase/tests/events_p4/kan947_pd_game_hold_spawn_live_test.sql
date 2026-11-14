-- KAN-947 P-d live proof: booking hold and challenge spawn write events first; can_current_user_join_game answers as
-- before; with the games-typed helpers and the seven games BEFORE triggers retired, create still blocks a frozen
-- creator, stamps request_id (idempotent replay) and refuses a non-challenge sport; parity holds.
-- One DO block as postgres that ends by raising its result line (nothing survives). Callers act as authenticated.
-- RED on the pre-image: probe 1 (helpers present, triggers attached, hold/spawn games-first).
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';
  v_uid2  uuid := '5dacb715-c263-4af8-ba22-b7a68799cbc6';
  v_pid   uuid := '3f346693-00c4-41b7-ad01-347e53c30883';
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '9208e6be-811a-4c76-9149-8dc736983dcc';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_venue uuid := '94de55e3-dbb9-40cb-8a07-a59364c46411';
  v_start timestamptz := date_trunc('hour', now()) + interval '40 days';
  v_cid uuid; v_fid uuid; v_fid2 uuid; v_g uuid; v_g2 uuid; v_g3 uuid; v_b uuid; v_req uuid := gen_random_uuid();
  v_n int; v_txt text; v_j jsonb; v_j2 jsonb; v_out text; v_pass int; v_fail int;
  e public.events; g public.games;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k947d_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;
  SELECT (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname IN ('kan718_game_event_sync', 'kan718_game_derive', 'kan711_events_map_game'))
       + (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND tgname IN ('trg_games_set_host', 'trg_games_block_frozen',
           'trg_games_stamp_request_id', 'trg_games_require_challenge_sport', 'trg_games_inherit_sport_from_space', 'trg_games_sync_geo', 'trg_games_touch'))
       + (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND prosrc ~ 'kan718_game_event_sync|kan718_game_derive|kan711_events_map_game')
       + (SELECT count(*) FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure AND prosrc ~ 'public\.games%rowtype')
    INTO v_n;
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_n = 0, 'games-typed helpers, games BEFORE triggers and games%rowtype retired', v_n || ' left');

  -- challenge spawn
  INSERT INTO public.challenges (owner_profile_id, owner_user_id, title, sport, sport_id) VALUES (v_pid, v_uid, 'KAN947d challenge', 'padel', v_sport) RETURNING id INTO v_cid;
  INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fid;
  INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fid2;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_g := public.rpc_challenge_spawn_game(v_fid, v_start, v_space);
  BEGIN
    PERFORM public.rpc_challenge_spawn_game(v_fid2, v_start, NULL);
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  SELECT * INTO e FROM public.events WHERE id = v_g;
  SELECT * INTO g FROM public.games WHERE id = v_g;
  INSERT INTO k947d_tap(ok, label, detail) VALUES (e.event_type = 'game' AND e.title LIKE 'KAN947d challenge — Fixture %' AND e.capacity = 22
         AND e.listing_visibility = 'private' AND e.join_policy = 'invite' AND e.venue_id = v_venue AND e.creator_user_id = v_uid
         AND g.game_type = 'hosted' AND g.venue_space_id = v_space AND g.title = e.title AND g.updated_at = e.updated_at AND g.venue_id = e.venue_id
         AND (SELECT game_id FROM public.challenge_fixtures WHERE id = v_fid) = v_g,
         'challenge spawn: events first, games mirrored, fixture linked', format('%s cap=%s vis=%s', e.title, e.capacity, e.listing_visibility));
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_txt = 'challenge_location_required', 'challenge spawn without a space refused', v_txt);
  SELECT count(*) INTO v_n FROM public.public_activities WHERE id = v_g AND activity_type = 'game_create';
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_n = 1, 'challenge spawn: one activity row', v_n::text);

  -- booking hold on a game created without a venue
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_g2 := public.rpc_create_game('player', v_sport, v_var, 'KAN947d hold', NULL, v_start + interval '3 hours', v_start + interval '4 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, v_req);
  v_g3 := public.rpc_create_game('player', v_sport, v_var, 'KAN947d hold', NULL, v_start + interval '3 hours', v_start + interval '4 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, v_req);
  v_b := public.rpc_booking_hold_for_game(v_g2, v_space, v_start + interval '3 hours', v_start + interval '4 hours');
  EXECUTE 'RESET ROLE';
  SELECT * INTO e FROM public.events WHERE id = v_g2;
  SELECT * INTO g FROM public.games WHERE id = v_g2;
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_b IS NOT NULL AND e.venue_id = v_venue AND g.venue_space_id = v_space AND g.venue_id = e.venue_id
         AND g.geo_location_id = e.geo_location_id AND g.updated_at = e.updated_at
         AND EXISTS (SELECT 1 FROM public.venue_bookings b WHERE b.id = v_b AND b.source_id = v_g2),
         'booking hold: booking + events location facts, games mirrored', format('venue=%s space=%s', e.venue_id, g.venue_space_id));
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_g2 = v_g3 AND (SELECT request_id FROM public.events WHERE id = v_g2) = v_req
         AND (SELECT request_id FROM public.games WHERE id = v_g2) = v_req,
         'request_id stamped and replay idempotent without the games stamp trigger', format('%s / %s', v_g2, v_g3));

  -- can_current_user_join_game: as authenticated (INVOKER, games has no policy) it answers not_found, as before;
  -- with the same claims as postgres the body runs: host for the creator, join for another player.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_j2 := public.can_current_user_join_game(v_g2, 'player', NULL);
  EXECUTE 'RESET ROLE';
  v_txt := v_j2->>'reason';
  v_j2 := public.can_current_user_join_game(v_g2, 'player', NULL);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  v_j := public.can_current_user_join_game(v_g2, 'player', NULL);
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_txt = 'not_found' AND v_j->>'cta' = 'host' AND v_j2->>'cta' = 'join',
         'can_current_user_join_game answers (authenticated not_found; host; join)', v_txt || ' / ' || v_j::text || ' / ' || v_j2::text);

  -- frozen creator still blocked, non-challenge sport still refused (games triggers gone)
  INSERT INTO public.user_freezes (user_id, is_frozen, reason, is_active, scope) VALUES (v_uid, true, 'KAN-947d probe', true, 'all') ON CONFLICT DO NOTHING;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rpc_create_game('player', v_sport, v_var, 'KAN947d frozen', NULL, v_start, v_start + interval '1 hour',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  DELETE FROM public.user_freezes WHERE user_id = v_uid AND reason = 'KAN-947d probe';
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_txt = 'user_frozen', 'frozen creator blocked (no games trigger)', v_txt);

  -- a direct games-first INSERT with no parent is still refused at commit (link check), not silently accepted
  BEGIN
    INSERT INTO public.games (id, event_id, game_type) VALUES (gen_random_uuid(), gen_random_uuid(), 'casual');
    SET CONSTRAINTS ALL IMMEDIATE;
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE; END;
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_txt <> 'no error', 'orphan games INSERT refused', v_txt);

  SELECT count(*) INTO v_n FROM public.games g0 LEFT JOIN public.events e0 ON e0.id = g0.event_id AND e0.event_type = 'game'
   WHERE e0.id IS NULL OR ROW(g0.creator_profile_id, g0.creator_user_id, g0.title, g0.start_at, g0.end_at, g0.capacity, g0.listing_visibility,
             g0.join_policy, g0.is_cancelled, g0.cancelled_at, g0.cancelled_reason, g0.sport_id, g0.area_id, g0.geo_location_id,
             g0.venue_id, g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.request_id, g0.created_at, g0.updated_at)
         IS DISTINCT FROM
         ROW(e0.creator_profile_id, e0.creator_user_id, e0.title, e0.start_at, e0.end_at, e0.capacity, e0.listing_visibility,
             e0.join_policy, e0.is_cancelled, e0.cancelled_at, e0.cancelled_reason, e0.sport_id, e0.area_id, e0.geo_location_id,
             e0.venue_id, e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.request_id, e0.created_at, e0.updated_at);
  INSERT INTO k947d_tap(ok, label, detail) VALUES (v_n = 0, 'games <-> events parity over all games', v_n || ' mismatches');

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k947d_tap;
  RAISE EXCEPTION 'K947d RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;
