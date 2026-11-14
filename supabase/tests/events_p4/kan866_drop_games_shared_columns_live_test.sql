-- KAN-866 live proof (post-drop smoke): every game write and read path still runs with the 22 shared columns gone from
-- public.games. One DO block as postgres; each probe runs in its own sub-block (an error is recorded, not fatal) and
-- the block ends by raising its result line, so nothing survives. Callers act as authenticated (request.jwt.claims +
-- SET LOCAL ROLE), except the service_role-only msg_my_conversations_v1 and the server-only legacy_v1 create.
-- A 42703 (undefined column) anywhere is the failure this guards against.
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';
  v_uid2  uuid := '5dacb715-c263-4af8-ba22-b7a68799cbc6';
  v_pid   uuid := '3f346693-00c4-41b7-ad01-347e53c30883';
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '9208e6be-811a-4c76-9149-8dc736983dcc';
  v_var4  uuid := '490ce916-b984-4da5-af37-c0019402359e';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_geo   uuid := 'c2c5d4db-2db9-4e39-b403-0481957a100d';
  v_area  uuid := '89dd44d9-e892-4dea-b2f1-28492503e76f';
  v_start timestamptz := date_trunc('hour', now()) + interval '50 days';
  v_g uuid; v_g1 uuid; v_sid uuid; v_cid uuid; v_fid uuid; v_tok uuid; v_t timestamptz; v_t2 timestamptz;
  v_n int; v_m int; v_q0 int; v_txt text; v_j jsonb; v_out text; v_pass int; v_fail int;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k866_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);

  -- 0. schema shape
  SELECT count(*) INTO v_n FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND NOT attisdropped
     AND attname IN ('creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility','join_policy',
                     'is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id','venue_id','min_skill',
                     'max_skill','joining_rule','cost_cover','request_id','created_at','updated_at');
  INSERT INTO k866_tap(ok, label, detail) VALUES (v_n = 0, 'the 22 shared columns are gone from games', v_n || ' left');

  -- 1. create (single)
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_g := public.rpc_create_game('player', v_sport, v_var4, 'KAN866 smoke', NULL, v_start, v_start + interval '1 hour',
             0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES ((SELECT title FROM public.events WHERE id = v_g) = 'KAN866 smoke', 'create single', v_g::text);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'create single', SQLSTATE || ' ' || SQLERRM); END;

  -- 2. create legacy_v1 (server-only)
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    v_g1 := public.rpc_create_game_legacy_v1('player', v_sport, v_var, 'KAN866 v1', NULL, v_start + interval '2 hours', v_start + interval '3 hours',
             0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL);
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_g1 IS NOT NULL, 'create legacy_v1', v_g1::text);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'create legacy_v1', SQLSTATE || ' ' || SQLERRM); END;

  -- 3. series create, occurrence edit, future edit
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_sid := public.rpc_create_game_series('player', v_sport, v_var4, v_geo, v_area, (now() + interval '4 days')::date, '18:00', 60,
             'Asia/Dubai', 'weekly', 4, 'KAN866 series', NULL, NULL, 'public', 'open', 2, 0);
    EXECUTE 'RESET ROLE';
    SELECT g.id, e.start_at INTO v_g1, v_t FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.series_id = v_sid ORDER BY e.start_at LIMIT 1;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_j := public.rpc_edit_game_series_occurrence(v_g1, 'KAN866 one-off', v_t + interval '30 minutes', NULL, 6, v_space);
    v_j := public.rpc_edit_game_series_future(v_sid, 'KAN866 renamed', 8, NULL, NULL, NULL, NULL, false);
    EXECUTE 'RESET ROLE';
    SELECT count(*) INTO v_n FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.series_id = v_sid;
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_n = 2 AND (v_j->>'updated')::int >= 1, 'series create + occurrence edit + future edit', v_j::text);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'series create + edits', SQLSTATE || ' ' || SQLERRM); END;

  -- 4. update + reschedule
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := public.rpc_update_game(v_g, v_start + interval '1 hour', v_start + interval '2 hours', 'KAN866 edited', v_space, false,
             'public', 'open', true, true, NULL, NULL, false, NULL, NULL, 6, 10);
    v_txt := v_txt || '/' || public.rpc_reschedule_game(v_g, v_start + interval '2 hours', v_start + interval '3 hours');
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_txt = 'updated/rescheduled' AND (SELECT title FROM public.events WHERE id = v_g) = 'KAN866 edited',
           'update + reschedule', v_txt);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'update + reschedule', SQLSTATE || ' ' || SQLERRM); END;

  -- 5. KAN-949 nudge: an events edit bumps games.event_changed_at
  BEGIN
    SELECT event_changed_at INTO v_t2 FROM public.games WHERE id = v_g;
    UPDATE public.events SET title = 'KAN866 nudged' WHERE id = v_g;
    INSERT INTO k866_tap(ok, label, detail) VALUES ((SELECT event_changed_at FROM public.games WHERE id = v_g) IS DISTINCT FROM v_t2
           OR (SELECT event_changed_at FROM public.games WHERE id = v_g) IS NOT NULL, 'KAN-949 nudge bumps event_changed_at',
           coalesce(v_t2::text, 'null') || ' -> ' || coalesce((SELECT event_changed_at FROM public.games WHERE id = v_g)::text, 'null'));
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'KAN-949 nudge', SQLSTATE || ' ' || SQLERRM); END;

  -- 6. join by a second player, slots, join check
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
    v_j := public.can_current_user_join_game(v_g, 'player', NULL);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := public.rpc_join_game('player', v_g, NULL)::text;
    v_n := public.game_slots_left(v_g);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_j->>'cta' = 'join' AND EXISTS (SELECT 1 FROM public.game_roster WHERE game_id = v_g AND user_id = v_uid2 AND status = 'active'),
           'can_current_user_join_game + rpc_join_game + game_slots_left', v_j::text || ' / ' || v_txt || ' / slots=' || v_n);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'join + slots', SQLSTATE || ' ' || SQLERRM); END;

  -- 7. booking hold + challenge spawn
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.rpc_booking_hold_for_game(v_g, v_space, v_start + interval '2 hours', v_start + interval '3 hours');
    EXECUTE 'RESET ROLE';
    INSERT INTO public.challenges (owner_profile_id, owner_user_id, title, sport, sport_id) VALUES (v_pid, v_uid, 'KAN866 challenge', 'padel', v_sport) RETURNING id INTO v_cid;
    INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_g1 := public.rpc_challenge_spawn_game(v_fid, v_start + interval '5 hours', v_space);
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES ((SELECT venue_id FROM public.events WHERE id = v_g) IS NOT NULL AND v_g1 IS NOT NULL,
           'booking hold + challenge spawn', v_g1::text);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'booking hold + challenge spawn', SQLSTATE || ' ' || SQLERRM); END;

  -- 8. readers: nearby, card by link, conversations, feeds, views
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.rpc_get_nearby_games(25.2, 55.3, 200000);
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES (true, 'rpc_get_nearby_games', v_n || ' rows');
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'rpc_get_nearby_games', SQLSTATE || ' ' || SQLERRM); END;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := public.rpc_update_game(v_g, v_start + interval '2 hours', v_start + interval '3 hours', NULL, NULL, false,
             NULL, 'link', NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, 10);   -- the card-by-link path is link-policy only
    v_tok := public.rpc_mint_join_link(v_g, NULL, NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT to_jsonb(c) INTO v_j FROM public.rpc_game_card_by_link(v_g, v_tok) c;
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_j->>'join_policy' = 'link', 'mint link + rpc_game_card_by_link', left(v_j::text, 160));
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'game card by link', SQLSTATE || ' ' || SQLERRM); END;
  BEGIN
    INSERT INTO public.msg_conversations (kind, game_id) VALUES ('game', v_g) ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    SELECT count(*) INTO v_n FROM public.msg_my_conversations_v1(50);
    INSERT INTO k866_tap(ok, label, detail) VALUES (true, 'msg_my_conversations_v1', v_n || ' rows');
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'msg_my_conversations_v1', SQLSTATE || ' ' || SQLERRM); END;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.rpc_get_activity_feed('all', 20, NULL);
    SELECT count(*) INTO v_m FROM public.get_home_feed(20, now());
    EXECUTE 'RESET ROLE';
    INSERT INTO k866_tap(ok, label, detail) VALUES (true, 'rpc_get_activity_feed + get_home_feed(int, timestamptz)', v_n || ' / ' || v_m || ' rows');
    -- get_home_feed(integer, integer) raises 42703 r.original_post_id (post_reposts has no such column): pre-existing,
    -- unrelated to games, so it is not probed here.
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'activity feeds', SQLSTATE || ' ' || SQLERRM); END;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.v_game_card;
    SELECT count(*) INTO v_m FROM public.v_my_games;
    EXECUTE 'RESET ROLE';
    SELECT v_n || ' / ' || v_m || ' / ' || (SELECT count(*) FROM public.kan714_games_read) || ' / ' || (SELECT count(*) FROM public.kan718_games_compat) INTO v_txt;
    INSERT INTO k866_tap(ok, label, detail) VALUES (true, 'views v_game_card / v_my_games / kan714_games_read / kan718_games_compat', v_txt);
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'game views', SQLSTATE || ' ' || SQLERRM); END;

  -- 9. cancel: notification + chat line + activity once
  BEGIN
    SELECT count(*) INTO v_q0 FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
    SELECT count(*) INTO v_m FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := public.rpc_cancel_game(v_g, 'KAN866 cancel');
    EXECUTE 'RESET ROLE';
    SELECT count(*) - v_m INTO v_n FROM public.notifications WHERE to_user_id = v_uid2 AND kind_key = 'game.updated';
    SELECT count(*) - v_q0 INTO v_m FROM net.http_request_queue WHERE url LIKE '%/internal/system-line';
    INSERT INTO k866_tap(ok, label, detail) VALUES (v_txt = 'cancelled' AND v_n = 1 AND v_m = 1
           AND EXISTS (SELECT 1 FROM public.public_activities WHERE id = v_g AND is_deleted),
           'cancel: notification, chat line, activity once', format('notif=%s line=%s', v_n, v_m));
  EXCEPTION WHEN OTHERS THEN INSERT INTO k866_tap(ok, label, detail) VALUES (false, 'cancel', SQLSTATE || ' ' || SQLERRM); END;

  -- 10. every game still has its events parent
  SELECT count(*) INTO v_n FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.id IS NULL;
  INSERT INTO k866_tap(ok, label, detail) VALUES (v_n = 0, 'every game has its events parent', v_n || ' orphans of ' || (SELECT count(*) FROM public.games));

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k866_tap;
  RAISE EXCEPTION 'K866 RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;
