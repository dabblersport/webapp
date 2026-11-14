-- KAN-947 P-a live proof: game create writes events first and names only retained games columns; the AFTER
-- behaviours (activity, cancel notification, chat system line) fire once from events; games stays in parity.
-- Runs on the hosted project as postgres. Everything is inside one DO block that ends by raising the result
-- line, so nothing it writes survives. Callers act as authenticated (request.jwt.claims + SET LOCAL ROLE).
-- RED on the pre-image: probe 1 (the games INSERT of legacy_v1/_v2 lists shared columns) and probe 14
-- (the moved triggers are still on games).
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';
  v_uid2  uuid := '5dacb715-c263-4af8-ba22-b7a68799cbc6';
  v_pid   uuid; v_pid2 uuid;
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '9208e6be-811a-4c76-9149-8dc736983dcc';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_nonch uuid; v_nonch_var uuid;
  v_start timestamptz := date_trunc('hour', now()) + interval '9 days';
  v_g1 uuid; v_g2 uuid; v_g3 uuid; v_g4 uuid; v_g5 uuid; v_req uuid := gen_random_uuid();
  v_n int; v_m int; v_q0 int; v_q1 int; v_secret boolean;
  v_txt text; v_out text := ''; v_fail int := 0; v_pass int := 0;
  e public.events; g public.games;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k947_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;

  -- 1. static: the games INSERT of both create writers names no shared column
  SELECT count(*) INTO v_n FROM pg_proc p,
         LATERAL (SELECT substring(p.prosrc from 'INSERT INTO public\.games \(([^)]*)\)') cols) s
   WHERE p.proname IN ('rpc_create_game_legacy_v1', 'rpc_create_game_legacy_v2') AND p.pronamespace = 'public'::regnamespace
     AND s.cols ~ '\m(title|creator_profile_id|creator_user_id|start_at|end_at|capacity|listing_visibility|join_policy|min_skill|max_skill|is_cancelled|cancelled_at|cancelled_reason|sport_id|geo_location_id|area_id|venue_id|joining_rule|cost_cover|request_id|created_at|updated_at)\M';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 0, 'create writers: games INSERT names only retained columns', v_n || ' writer(s) list shared columns');

  SELECT s.id, sv.id INTO v_nonch, v_nonch_var FROM public.sports s JOIN public.sport_variants sv ON sv.sport_id = s.id AND sv.is_active
   WHERE s.is_active AND s.is_challenge_sport IS DISTINCT FROM true LIMIT 1;
  SELECT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'msg_hmac_secret' AND coalesce(decrypted_secret, '') <> '') INTO v_secret;

  -- act as player 1 (authenticated)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- 2. create single game (rpc_create_game -> legacy_v2), no venue
  v_g1 := public.rpc_create_game('player', v_sport, v_var, 'KAN947 probe single', NULL, v_start, v_start + interval '1 hour',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
  -- 3. create at a venue space
  v_g2 := public.rpc_create_game('player', v_sport, v_var, 'KAN947 probe space', v_space, v_start + interval '2 hours', v_start + interval '3 hours',
            0, 'public', 'open', 2, 5, NULL, NULL, true, true, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 12.5, NULL);
  -- 4/5. request_id idempotency
  v_g3 := public.rpc_create_game('player', v_sport, v_var, 'KAN947 probe idem', NULL, v_start + interval '4 hours', v_start + interval '5 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, v_req);
  v_g4 := public.rpc_create_game('player', v_sport, v_var, 'KAN947 probe idem', NULL, v_start + interval '4 hours', v_start + interval '5 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, v_req);
  -- 6. non-challenge sport refused with the same error
  BEGIN
    PERFORM public.rpc_create_game('player', v_nonch, v_nonch_var, 'KAN947 probe nonch', NULL, v_start, v_start + interval '1 hour',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_nonch IS NULL OR v_txt = 'sport_not_challenge_eligible', 'non-challenge sport refused', coalesce(v_txt, 'no non-challenge sport'));

  SELECT e2.creator_profile_id INTO v_pid FROM public.events e2 WHERE e2.id = v_g1;

  -- 7. events parent + games row in parity, for every probe game
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.event_id AND e0.event_type = 'game'
   WHERE g0.id IN (v_g1, v_g2, v_g3)
     AND ROW(g0.creator_profile_id, g0.creator_user_id, g0.title, g0.start_at, g0.end_at, g0.capacity, g0.listing_visibility,
             g0.join_policy, g0.is_cancelled, g0.cancelled_at, g0.cancelled_reason, g0.sport_id, g0.area_id, g0.geo_location_id,
             g0.venue_id, g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.request_id, g0.created_at, g0.updated_at)
         IS NOT DISTINCT FROM
         ROW(e0.creator_profile_id, e0.creator_user_id, e0.title, e0.start_at, e0.end_at, e0.capacity, e0.listing_visibility,
             e0.join_policy, e0.is_cancelled, e0.cancelled_at, e0.cancelled_reason, e0.sport_id, e0.area_id, e0.geo_location_id,
             e0.venue_id, e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.request_id, e0.created_at, e0.updated_at);
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 3, 'create: events parent + games mirrored (3 games, 22 columns)', v_n || '/3 in parity');

  SELECT * INTO e FROM public.events WHERE id = v_g1;
  INSERT INTO k947_tap(ok, label, detail) VALUES (e.title = 'KAN947 probe single' AND e.creator_user_id = v_uid AND e.capacity = 2
         AND e.geo_location_id IS NOT NULL AND e.area_id IS NOT NULL AND e.joining_rule = 'free' AND e.cost_cover = 'free',
         'single: shared fields on events', format('title=%s cap=%s geo=%s rule=%s', e.title, e.capacity, e.geo_location_id, e.joining_rule));
  SELECT * INTO e FROM public.events WHERE id = v_g2;
  SELECT * INTO g FROM public.games WHERE id = v_g2;
  INSERT INTO k947_tap(ok, label, detail) VALUES (e.venue_id = '94de55e3-dbb9-40cb-8a07-a59364c46411' AND e.capacity = 2 AND e.min_skill = 2
         AND g.venue_space_id = v_space AND g.price_aed = 12.5 AND g.allows_waitlist AND g.allow_spectators,
         'space: venue derived, retained columns on games', format('venue=%s cap=%s price=%s', e.venue_id, e.capacity, g.price_aed));
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_g3 = v_g4 AND (SELECT count(*) FROM public.events WHERE request_id = v_req) = 1
         AND (SELECT request_id FROM public.games WHERE id = v_g3) = v_req,
         'request_id: replay returns the same game, one events row', format('%s / %s', v_g3, v_g4));

  -- 8. activity row exactly once per create, host roster present
  SELECT count(*) INTO v_n FROM public.public_activities WHERE id IN (v_g1, v_g2, v_g3) AND activity_type = 'game_create' AND NOT is_deleted;
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 3, 'activity: one game_create row per created game', v_n || '/3');
  SELECT count(*) INTO v_n FROM public.game_roster WHERE game_id IN (v_g1, v_g2, v_g3) AND role = 'host' AND status = 'active' AND user_id = v_uid;
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 3, 'host roster row per created game', v_n || '/3');

  -- 9. frozen creator blocked
  INSERT INTO public.user_freezes (user_id, is_frozen, reason, is_active, scope) VALUES (v_uid, true, 'KAN-947 probe', true, 'all')
  ON CONFLICT DO NOTHING;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rpc_create_game('player', v_sport, v_var, 'KAN947 probe frozen', NULL, v_start, v_start + interval '1 hour',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
    v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  EXECUTE 'RESET ROLE';
  DELETE FROM public.user_freezes WHERE user_id = v_uid AND reason = 'KAN-947 probe';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_txt = 'user_frozen', 'frozen creator blocked', v_txt);

  -- 10. v1 (server-only) create, as postgres with the player's claims
  v_g5 := public.rpc_create_game_legacy_v1('player', v_sport, v_var, 'KAN947 probe v1', NULL, v_start + interval '6 hours', v_start + interval '7 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL);
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.id = v_g5 AND g0.title = e0.title AND g0.creator_user_id = e0.creator_user_id AND g0.updated_at = e0.updated_at
     AND g0.capacity = e0.capacity AND e0.title = 'KAN947 probe v1';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'legacy_v1 create: events first, games mirrored', v_n::text);

  -- 11. cancel (rpc_cancel_game, still games-first until P-b): notification, chat line, activity each exactly once
  SELECT p.id INTO v_pid2 FROM public.profiles p WHERE p.user_id = v_uid2 AND p.is_active ORDER BY p.created_at LIMIT 1;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (v_g1, v_pid2, v_uid2, 'player', 'active');
  INSERT INTO public.msg_conversations (kind, game_id) VALUES ('game', v_g1) ON CONFLICT DO NOTHING;
  SELECT count(*) INTO v_q0 FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
  SELECT count(*) INTO v_m FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := public.rpc_cancel_game(v_g1, 'KAN947 probe cancel');
  EXECUTE 'RESET ROLE';
  SELECT count(*) - v_m INTO v_n FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'cancel: game.updated notification to the player exactly once', v_n::text);
  SELECT count(*) - v_q0 INTO v_n FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
  INSERT INTO k947_tap(ok, label, detail) VALUES (CASE WHEN v_secret THEN v_n = 1 ELSE v_n = 0 END,
         'cancel: chat system line queued exactly once', format('%s (secret present: %s)', v_n, v_secret));
  SELECT count(*) INTO v_n FROM public.public_activities WHERE id = v_g1 AND is_deleted;
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'cancel: activity row marked deleted', v_n::text);
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.id = v_g1 AND g0.is_cancelled AND e0.is_cancelled AND g0.cancelled_at = e0.cancelled_at AND g0.updated_at = e0.updated_at;
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'cancel: games and events agree', v_txt);

  -- 12. events-only write mirrors to games (the one-way mirror)
  UPDATE public.events SET title = 'KAN947 probe mirrored' WHERE id = v_g2;
  SELECT count(*) INTO v_n FROM public.games g0 JOIN public.events e0 ON e0.id = g0.id
   WHERE g0.id = v_g2 AND g0.title = 'KAN947 probe mirrored' AND g0.updated_at = e0.updated_at;
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'events-only edit mirrored onto games', v_n::text);

  -- 13. games-only write without the mirror flag does not take events values (games-first writers untouched)
  UPDATE public.games SET title = 'KAN947 games-first' WHERE id = v_g3;
  SELECT count(*) INTO v_n FROM public.games WHERE id = v_g3 AND title = 'KAN947 games-first';
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 1, 'games-first UPDATE keeps its own values', v_n::text);
  UPDATE public.games SET title = 'KAN947 probe idem' WHERE id = v_g3;

  -- 14. trigger placement
  SELECT count(*) INTO v_n FROM pg_trigger WHERE tgrelid = 'public.games'::regclass
     AND tgname IN ('tr_games_activity_sync', 'trg_game_updated_notify', 'msg_system_game_cancelled');
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 0, 'moved AFTER triggers are gone from games', v_n || ' left');

  -- 15. global parity across every game
  SELECT count(*) INTO v_n FROM public.games g0 LEFT JOIN public.events e0 ON e0.id = g0.event_id AND e0.event_type = 'game'
   WHERE e0.id IS NULL OR ROW(g0.creator_profile_id, g0.creator_user_id, g0.title, g0.start_at, g0.end_at, g0.capacity, g0.listing_visibility,
             g0.join_policy, g0.is_cancelled, g0.cancelled_at, g0.cancelled_reason, g0.sport_id, g0.area_id, g0.geo_location_id,
             g0.venue_id, g0.min_skill, g0.max_skill, g0.joining_rule, g0.cost_cover, g0.request_id, g0.created_at, g0.updated_at)
         IS DISTINCT FROM
         ROW(e0.creator_profile_id, e0.creator_user_id, e0.title, e0.start_at, e0.end_at, e0.capacity, e0.listing_visibility,
             e0.join_policy, e0.is_cancelled, e0.cancelled_at, e0.cancelled_reason, e0.sport_id, e0.area_id, e0.geo_location_id,
             e0.venue_id, e0.min_skill::int, e0.max_skill::int, e0.joining_rule, e0.cost_cover, e0.request_id, e0.created_at, e0.updated_at);
  INSERT INTO k947_tap(ok, label, detail) VALUES (v_n = 0, 'games <-> events parity over all games', v_n || ' mismatches');

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k947_tap;
  RAISE EXCEPTION 'K947 RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;
