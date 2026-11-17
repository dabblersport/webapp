-- KAN-1017: live probe pack for 20261117171717_kan1017_game_invite_notify.sql. Run as postgres on
-- wtncuzcskpigqpmnxwws; one DO block ending in RAISE EXCEPTION, so every write rolls back. It never touches the QA
-- device-test game or invite (it creates its own games and calls no global sweep).
--   I1  rpc_invite_user records the caller's profile as invited_by; the invitee gets one game.invited (v2), EN, titled
--   I2  untitled game: EN "<host> invited you to <Sport> game", AR "<host> دعاك إلى مباراة <رياضة>"
--   N1  self-invite sends nothing      N2  an invitee who blocked the host gets nothing
--   K1  accepted -> the inviter        K2  declined -> the inviter
--   K3  withdrawn -> the invitee, inviter as actor        K4  expired -> the invitee
--   N3  no legacy (schema_version 1) game.invited row
--
-- Run 2026-11-17 by backend-4 after apply (20261117171717): all 10 ok.
--   I1 "Yazan Faris invited you to KAN1017 Probe G"; I2 EN "Yazan Faris invited you to Football game";
--   I2 AR "Yazan Faris دعاك إلى مباراة كرة القدم"; K1 "Arjun Menon accepted your invite to KAN1017 Probe G";
--   K3 "Your invite to Football game was withdrawn".
CREATE OR REPLACE FUNCTION pg_temp.k1017_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
END $$;
CREATE OR REPLACE FUNCTION pg_temp.k1017_n(p_to uuid, p_kind text, p_entity uuid) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM public.notifications WHERE to_user_id = p_to AND kind_key = p_kind AND context ->> 'entity_id' = p_entity::text $$;

DO $probe$
DECLARE
  u uuid[]; pr uuid[]; h uuid; p1 uuid; p2 uuid; p3 uuid;
  g uuid; gu uuid; e uuid; inv uuid; inv2 uuid; inv3 uuid; s text; r text := ''; ok boolean; nt record; tpl record; sp record; hn text; n int;
BEGIN
  SELECT array_agg(user_id ORDER BY created_at), array_agg(id ORDER BY created_at) INTO u, pr FROM (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id, p.created_at FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = p.user_id OR b.blocked_user_id = p.user_id)
     ORDER BY p.user_id, p.created_at) s
   LIMIT 4;
  h := u[1]; p1 := u[2]; p2 := u[3]; p3 := u[4];
  UPDATE public.profiles SET language = 'en' WHERE user_id = p1;
  UPDATE public.profiles SET language = 'ar' WHERE user_id = p2;
  hn := public.kan982_display_name(h);
  SELECT area_id, geo_location_id, sport_id INTO tpl FROM public.events
   WHERE event_type = 'game' AND area_id IS NOT NULL AND geo_location_id IS NOT NULL AND sport_id IS NOT NULL LIMIT 1;
  SELECT name_en, coalesce(nullif(btrim(name_ar), ''), name_en) AS name_ar INTO sp FROM public.sports WHERE id = tpl.sport_id;

  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1017 Probe G', 5, 'invite', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', NULL, 5, 'invite', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO gu;

  PERFORM pg_temp.k1017_as(h); inv := public.rpc_invite_user(g, p1);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.invited' AND context ->> 'entity_id' = g::text;
  ok := (SELECT pp.user_id FROM public.game_invites i JOIN public.profiles pp ON pp.id = i.invited_by_profile_id WHERE i.id = inv) = h
        AND pg_temp.k1017_n(p1, 'game.invited', g) = 1 AND nt.schema_version = 2
        AND nt.title = hn || ' invited you to KAN1017 Probe G' AND nt.context ->> 'actor_user_id' = h::text;
  r := r || format(E'I1 invite records the inviter, one game.invited (EN, titled): %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);

  inv2 := public.rpc_invite_user(gu, p1);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.invited' AND context ->> 'entity_id' = gu::text;
  ok := nt.title = hn || ' invited you to ' || sp.name_en || ' game';
  r := r || format(E'I2 untitled game, EN: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);
  inv3 := public.rpc_invite_user(gu, p2);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p2 AND kind_key = 'game.invited' AND context ->> 'entity_id' = gu::text;
  ok := nt.title = hn || ' دعاك إلى مباراة ' || sp.name_ar;
  r := r || format(E'I2 untitled game, AR: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);

  PERFORM public.rpc_invite_user(g, h);
  ok := pg_temp.k1017_n(h, 'game.invited', g) = 0;
  r := r || format(E'N1 self-invite sends nothing: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  INSERT INTO public.user_blocks(blocker_user_id, blocked_user_id) VALUES (p3, h);
  PERFORM public.rpc_invite_user(g, p3);
  ok := pg_temp.k1017_n(p3, 'game.invited', g) = 0;
  r := r || format(E'N2 invitee who blocked the host gets nothing: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  PERFORM pg_temp.k1017_as(p1); PERFORM public.rpc_join_game('player', g);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = h AND kind_key = 'game.invite_accepted' AND context ->> 'entity_id' = g::text;
  ok := pg_temp.k1017_n(h, 'game.invite_accepted', g) = 1 AND nt.context ->> 'actor_user_id' = p1::text;
  r := r || format(E'K1 accepted -> the inviter: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);
  PERFORM pg_temp.k1017_as(p2); s := public.rpc_decline_game_invite(inv3);
  ok := s = 'declined' AND pg_temp.k1017_n(h, 'game.invite_declined', gu) = 1;
  r := r || format(E'K2 declined -> the inviter: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  PERFORM pg_temp.k1017_as(h); s := public.rpc_withdraw_game_invite(inv2);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.invite_withdrawn' AND context ->> 'entity_id' = gu::text;
  ok := s = 'withdrawn' AND nt.context ->> 'actor_user_id' = h::text AND nt.title = 'Your invite to ' || sp.name_en || ' game was withdrawn';
  r := r || format(E'K3 withdrawn -> invitee, inviter as actor: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);
  PERFORM pg_temp.k1017_as(h); inv := public.rpc_invite_user(g, p2);
  UPDATE public.game_invites SET status = 'expired', responded_at = now() WHERE id = inv;
  ok := pg_temp.k1017_n(p2, 'game.invite_expired', g) = 1;
  r := r || format(E'K4 expired -> invitee: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'game.invited' AND created_at = now() AND schema_version = 1;
  r := r || format(E'N3 no legacy-path game.invited row: %s (%s)\n', CASE WHEN n = 0 THEN 'ok' ELSE 'FAIL' END, n);

  RAISE EXCEPTION E'KAN1017 PROBE RESULTS (rolled back)\n%', r;
END
$probe$;
