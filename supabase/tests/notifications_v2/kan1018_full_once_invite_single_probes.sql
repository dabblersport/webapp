-- KAN-1018: live probe pack for 20261117174309_kan1018_full_once_invite_single.sql. Run as postgres on
-- wtncuzcskpigqpmnxwws; one DO block ending in RAISE EXCEPTION, so every write rolls back. Own probe games only.
--   F1  two joins fill cap 2 -> game.full once (episode 1)
--   F2  the QA case: a player leaves, the waitlisted player is promoted and refills -> still one game.full
--   F3  negative control: a leave with an empty waitlist opens the game; the next join fills it -> a second game.full
--       (episode 2), so a real refill is still told
--   I1  a join that accepts an invite -> host gets game.invite_accepted only, no game.player_joined
--   I2  negative control: a plain join on an open game -> host gets game.player_joined
--
-- Run 2026-11-17 by backend-4 after apply (20261117174309): F1, F2, F3, I1, I2 all ok (F2 n=1, F3 n=2, I1 accepted=1
-- joined=0). Seen failing before the fix: QA game 43c95ad9… had two game.full rows (keys ...:<row>:first per filling
-- row), the second from a waitlist refill. After the rollback: 0 probe events, 0 game_fill_episodes rows.
CREATE OR REPLACE FUNCTION pg_temp.k1018_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
END $$;
CREATE OR REPLACE FUNCTION pg_temp.k1018_n(p_to uuid, p_kind text, p_entity uuid) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM public.notifications WHERE to_user_id = p_to AND kind_key = p_kind AND context ->> 'entity_id' = p_entity::text $$;

DO $probe$
DECLARE
  u uuid[]; pr uuid[]; h uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; p5 uuid;
  g uuid; gi uuid; go uuid; e uuid; s text; r text := ''; ok boolean; tpl record; ep record;
BEGIN
  SELECT array_agg(user_id ORDER BY created_at), array_agg(id ORDER BY created_at) INTO u, pr FROM (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id, p.created_at FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = p.user_id OR b.blocked_user_id = p.user_id)
     ORDER BY p.user_id, p.created_at) s
   LIMIT 6;
  h := u[1]; p1 := u[2]; p2 := u[3]; p3 := u[4]; p4 := u[5]; p5 := u[6];
  SELECT area_id, geo_location_id, sport_id INTO tpl FROM public.events
   WHERE event_type = 'game' AND area_id IS NOT NULL AND geo_location_id IS NOT NULL AND sport_id IS NOT NULL LIMIT 1;

  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1018 Probe Full', 2, 'open', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1018 Probe Invite', 5, 'invite', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO gi;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1018 Probe Open', 5, 'open', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO go;

  -- F1
  PERFORM pg_temp.k1018_as(p1); PERFORM public.rpc_join_game('player', g);
  PERFORM pg_temp.k1018_as(p2); PERFORM public.rpc_join_game('player', g);
  SELECT * INTO ep FROM public.game_fill_episodes WHERE game_id = g;
  ok := pg_temp.k1018_n(h, 'game.full', g) = 1 AND ep.episode = 1 AND ep.full_since IS NOT NULL;
  r := r || format(E'F1 fill -> game.full once, episode 1: %s (n=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, pg_temp.k1018_n(h, 'game.full', g));

  -- F2
  PERFORM pg_temp.k1018_as(p3); SELECT result INTO s FROM public.rpc_join_game('player', g);
  PERFORM pg_temp.k1018_as(p1); PERFORM public.rpc_leave_game('player', g);
  SELECT * INTO ep FROM public.game_fill_episodes WHERE game_id = g;
  ok := s = 'waitlisted' AND (SELECT status FROM public.game_roster WHERE game_id = g AND user_id = p3) = 'active'
        AND pg_temp.k1018_n(h, 'game.full', g) = 1 AND ep.episode = 1 AND ep.full_since IS NOT NULL;
  r := r || format(E'F2 leave refilled from the waitlist -> still one game.full: %s (n=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, pg_temp.k1018_n(h, 'game.full', g));

  -- F3
  PERFORM pg_temp.k1018_as(p2); PERFORM public.rpc_leave_game('player', g);
  SELECT * INTO ep FROM public.game_fill_episodes WHERE game_id = g;
  ok := ep.full_since IS NULL;
  PERFORM pg_temp.k1018_as(p4); PERFORM public.rpc_join_game('player', g);
  SELECT * INTO ep FROM public.game_fill_episodes WHERE game_id = g;
  ok := ok AND pg_temp.k1018_n(h, 'game.full', g) = 2 AND ep.episode = 2 AND ep.full_since IS NOT NULL;
  r := r || format(E'F3 opened then filled again -> second game.full (episode 2): %s (n=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, pg_temp.k1018_n(h, 'game.full', g));

  -- I1
  PERFORM pg_temp.k1018_as(h); PERFORM public.rpc_invite_user(gi, p5);
  PERFORM pg_temp.k1018_as(p5); PERFORM public.rpc_join_game('player', gi);
  ok := pg_temp.k1018_n(h, 'game.invite_accepted', gi) = 1 AND pg_temp.k1018_n(h, 'game.player_joined', gi) = 0;
  r := r || format(E'I1 invite accept -> invite_accepted only: %s (accepted=%s joined=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END,
                   pg_temp.k1018_n(h, 'game.invite_accepted', gi), pg_temp.k1018_n(h, 'game.player_joined', gi));

  -- I2
  PERFORM pg_temp.k1018_as(p5); PERFORM public.rpc_join_game('player', go);
  ok := pg_temp.k1018_n(h, 'game.player_joined', go) = 1 AND pg_temp.k1018_n(h, 'game.invite_accepted', go) = 0;
  r := r || format(E'I2 plain join -> player_joined: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  RAISE EXCEPTION E'KAN1018 PROBE RESULTS (rolled back)\n%', r;
END
$probe$;
