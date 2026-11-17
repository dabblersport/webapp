-- KAN-982 [W1-B4] Membership: live probe pack for 20261117101222_kan982_membership_notices.sql and
-- 20261117102454_kan982b_removal_reason_optional.sql (reason optional until the app sends one) and
-- 20261117162054_kan982c_untitled_event_titles.sql (localized fallback title for untitled games).
-- Run as postgres on wtncuzcskpigqpmnxwws, as one script. Everything runs inside one DO block that ends in
-- RAISE EXCEPTION, so every write (probe games, meetup, roster, notifications, settings, blocks) rolls back. The
-- exception message carries the results. Two pg_temp helpers are created first (session only).
--
-- Cast: H (host) and P1..P5, six distinct users with an active player profile, not frozen, no blocks between them.
-- Games and the meetup are created inside the block, starting in 3 days (G2 started an hour ago).
--
-- Every line must read "ok". N* lines are the negative controls.
--   S1  joins notify the host (player_joined); the 2nd join fills cap 2 -> game.full once
--   S2  a join on a full game -> waitlist_joined to that player
--   S3  a reason over 500 chars -> reason_too_long, no notice. The 2-arg call the live app makes (no reason) removes:
--       one game.removed with the organiser's name and no reason line; the next waitlisted player promoted and
--       notified (breaks_quiet kinds)
--       N3a the other players get no game.removed; N3b the 2nd waitlisted player gets no promotion notice;
--       N3c a removal (kicked) sends the host no player_left
--   S4  rpc_leave_game -> host gets player_left; next waitlisted promoted + notified
--   S5  the direct self-leave path (UPDATE game_roster as authenticated) is refused 42501; a raw UPDATE to 'left'
--       (any path that reaches the table) promotes the next waitlisted player and notifies them
--       N5  a leave with an empty waitlist promotes and notifies nobody
--   S6  cancel my place (rpc_cancel_waitlist_place) -> place_released, no reputation/penalty row; a player who left
--       and joins again notifies the host a second time (re-join no longer swallowed)
--   S7  cancel my place after the game started -> 'started'
--   S8  join request declined -> one game.join_declined; approved -> one game.join_accepted
--       N8  the approved requester gets no join_declined, the declined one no join_accepted; the host gets no
--           player_joined for a join he approved
--       S8b removal with a reason -> one game.removed whose args and body hold the organiser's name and the reason
--   S9  invites: accepted (by joining) -> inviter; declined -> inviter; withdrawn -> invitee; expired -> invitee
--   S10 meetup: the 2-arg call (no reason) -> status 'removed' (not 'cancelled') and one meetup.removed with the
--       organiser and no reason line; with a reason -> organiser and reason; an attendee leaving -> host gets
--       meetup.player_left
--       N10 the other attendee gets no meetup.removed; a removal sends the host no player_left
--   S11 mute: a muted game.player_left still writes its inbox row (KAN-974c) and its push channel is off; block: a
--       removed attendee who blocked the host gets nothing
--   S12 one sender: no schema_version 1 row of any KAN-982 kind was written by any of the above
--   S13 untitled game (title NULL): game.full to the host and game.removed to an EN and an AR recipient carry
--       title_en "<Sport> game" / title_ar "مباراة <رياضة>" and render "You were removed from <Sport> game" /
--       "تمت إزالتك من مباراة <رياضة>"; N13 control: a titled game's notice keeps its own title
--
-- Run 2026-11-17 by backend-4 after apply (migration 20261117101222): all 28 lines ok. S3 body (EN recipient):
-- "Yazan Faris removed you: Late twice in a row"; S12 legacy 0, v2 30. Seen failing first: S11 asserted the pre-KAN-974c
-- rule (a muted kind writes nothing) and failed; KAN-974c keeps the inbox row and turns the push off, which the
-- current S11 asserts. After the rollback: 0 probe events, roster active=715 left=7, waitlist 0, game_invites 0.
-- Re-run 2026-11-17 after 20261117102454 (kan982b, reason optional): all 29 lines ok. S3 old 2-arg call body
-- "Yazan Faris removed you" (no reason line); S8b with reason "Yazan Faris removed you: Late twice in a row"; S10 old
-- 2-arg call "Yazan Faris removed you"; S12 legacy 0, v2 32. The earlier run (before kan982b) showed the old 2-arg
-- call refused with reason_required, which is the regression this re-run proves fixed.
-- Re-run 2026-11-17 after 20261117162054 (kan982c, PEER R1 untitled games): all 33 lines ok. S13: "Football game is
-- full", "You were removed from Football game", AR "تمت إزالتك من مباراة كرة القدم"; N13 "You were removed from KAN982
-- Probe G1"; S12 legacy 0, v2 37. Before kan982c the same untitled title rendered "You were removed from" (PEER 16446).

CREATE OR REPLACE FUNCTION pg_temp.k982_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
END $$;

CREATE OR REPLACE FUNCTION pg_temp.k982_n(p_to uuid, p_kind text, p_entity uuid) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM public.notifications
   WHERE to_user_id = p_to AND kind_key = p_kind AND context ->> 'entity_id' = p_entity::text
$$;

DO $probe$
DECLARE
  u uuid[]; pr uuid[];
  h uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid; p5 uuid;
  g1 uuid; g2 uuid; g3 uuid; g4 uuid; m1 uuid; e uuid;
  r text := ''; ok boolean; s text; n int; n2 int; rq uuid; inv uuid; nt record; tpl record; g5 uuid; sp record;
BEGIN
  SELECT array_agg(user_id ORDER BY created_at), array_agg(id ORDER BY created_at) INTO u, pr FROM (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id, p.created_at FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = p.user_id OR b.blocked_user_id = p.user_id)
     ORDER BY p.user_id, p.created_at) s
   LIMIT 6;
  IF array_length(u, 1) < 6 THEN RAISE EXCEPTION 'need 6 users, found %', array_length(u, 1); END IF;
  h := u[1]; p1 := u[2]; p2 := u[3]; p3 := u[4]; p4 := u[5]; p5 := u[6];
  -- area, place and sport copied from an existing game (games require all three)
  SELECT area_id, geo_location_id, sport_id INTO tpl FROM public.events
   WHERE event_type = 'game' AND area_id IS NOT NULL AND geo_location_id IS NOT NULL AND sport_id IS NOT NULL LIMIT 1;

  -- probe games and meetup
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN982 Probe G1', 2, 'open', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g1;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() - interval '1 hour', now() + interval '1 hour', 'KAN982 Probe G2', 5, 'open', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g2;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN982 Probe G3', 5, 'request', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g3;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN982 Probe G4', 5, 'invite', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g4;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy)
  VALUES (e, 'meetup', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN982 Probe M1', 10, 'open');
  INSERT INTO public.meetups(id, event_id, host_actor_id) VALUES (e, e, pr[1]) RETURNING id INTO m1;

  -- S1 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p1); PERFORM public.rpc_join_game('player', g1);
  PERFORM pg_temp.k982_as(p2); PERFORM public.rpc_join_game('player', g1);
  ok := pg_temp.k982_n(h, 'game.player_joined', g1) = 2 AND pg_temp.k982_n(h, 'game.full', g1) = 1;
  r := r || format(E'S1 joins notify host, full once: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- S2 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p3); SELECT result INTO s FROM public.rpc_join_game('player', g1);
  PERFORM pg_temp.k982_as(p4); PERFORM public.rpc_join_game('player', g1);
  ok := s = 'waitlisted' AND pg_temp.k982_n(p3, 'game.waitlist_joined', g1) = 1
        AND pg_temp.k982_n(p4, 'game.waitlist_joined', g1) = 1;
  r := r || format(E'S2 waitlist_joined: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s);

  -- S3 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(h);
  ok := false;
  BEGIN PERFORM public.rpc_remove_player(g1, (SELECT profile_id FROM public.game_roster WHERE game_id = g1 AND user_id = p1), repeat('x', 501));
  EXCEPTION WHEN raise_exception THEN ok := SQLERRM = 'reason_too_long'; END;
  ok := ok AND pg_temp.k982_n(p1, 'game.removed', g1) = 0
        AND (SELECT status FROM public.game_roster WHERE game_id = g1 AND user_id = p1) = 'active';
  r := r || format(E'S3 reason over 500 chars refused, no notice: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- the exact call shape of the live app: named p_game_id, p_profile_id, no reason
  s := public.rpc_remove_player(p_game_id => g1,
                                p_profile_id => (SELECT profile_id FROM public.game_roster WHERE game_id = g1 AND user_id = p1));
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.removed'
     AND context ->> 'entity_id' = g1::text;
  ok := s = 'removed_promoted_waitlist' AND pg_temp.k982_n(p1, 'game.removed', g1) = 1
        AND NOT (nt.args ? 'reason') AND NOT (nt.args ? 'reason_line')
        AND nt.args ->> 'organiser' = public.kan982_display_name(h)
        AND nt.body IN (public.kan982_display_name(h) || ' removed you', 'أزالك ' || public.kan982_display_name(h))
        AND nt.schema_version = 2
        AND (SELECT breaks_quiet FROM public.notification_kinds WHERE key = 'game.removed');
  r := r || format(E'S3 old 2-arg call, no reason -> removed, one notice with organiser, no reason line: %s (%s | %s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s, nt.body);
  ok := (SELECT status FROM public.game_roster WHERE game_id = g1 AND user_id = p3) = 'active'
        AND pg_temp.k982_n(p3, 'game.waitlist_promoted', g1) = 1
        AND (SELECT breaks_quiet FROM public.notification_kinds WHERE key = 'game.waitlist_promoted');
  r := r || format(E'S3 first waitlisted promoted and notified: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  ok := pg_temp.k982_n(p2, 'game.removed', g1) = 0 AND pg_temp.k982_n(p3, 'game.removed', g1) = 0
        AND pg_temp.k982_n(p4, 'game.removed', g1) = 0 AND pg_temp.k982_n(h, 'game.removed', g1) = 0;
  r := r || format(E'N3a other players get no game.removed: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  ok := pg_temp.k982_n(p4, 'game.waitlist_promoted', g1) = 0
        AND EXISTS (SELECT 1 FROM public.game_waitlist WHERE game_id = g1 AND user_id = p4);
  r := r || format(E'N3b 2nd waitlisted not promoted, not notified: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  ok := pg_temp.k982_n(h, 'game.player_left', g1) = 0;
  r := r || format(E'N3c removal sends the host no player_left: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- S4 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p2); s := public.rpc_leave_game('player', g1);
  ok := s = 'left_promoted_waitlist' AND pg_temp.k982_n(h, 'game.player_left', g1) = 1
        AND (SELECT status FROM public.game_roster WHERE game_id = g1 AND user_id = p4) = 'active'
        AND pg_temp.k982_n(p4, 'game.waitlist_promoted', g1) = 1;
  r := r || format(E'S4 rpc_leave_game: host told, next promoted + notified: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s);

  -- S5 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p5); PERFORM public.rpc_join_game('player', g1);   -- full: P5 waits
  PERFORM pg_temp.k982_as(p3);
  PERFORM set_config('role', 'authenticated', true);
  ok := false;
  BEGIN
    UPDATE public.game_roster SET status = 'left', left_at = now() WHERE game_id = g1 AND user_id = p3;
  EXCEPTION WHEN insufficient_privilege THEN ok := true;
  END;
  EXECUTE 'RESET ROLE';
  ok := ok AND (SELECT status FROM public.game_roster WHERE game_id = g1 AND user_id = p3) = 'active';
  r := r || format(E'S5 direct self-leave as authenticated refused 42501: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  UPDATE public.game_roster SET status = 'left', left_at = now() WHERE game_id = g1 AND user_id = p3;   -- raw path
  ok := (SELECT status FROM public.game_roster WHERE game_id = g1 AND user_id = p5) = 'active'
        AND pg_temp.k982_n(p5, 'game.waitlist_promoted', g1) = 1;
  r := r || format(E'S5 raw UPDATE to left promotes + notifies: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  SELECT count(*) INTO n FROM public.notifications WHERE kind_key = 'game.waitlist_promoted' AND context ->> 'entity_id' = g1::text;
  PERFORM pg_temp.k982_as(p4); s := public.rpc_cancel_waitlist_place(g1);        -- waitlist is empty now
  SELECT count(*) INTO n2 FROM public.notifications WHERE kind_key = 'game.waitlist_promoted' AND context ->> 'entity_id' = g1::text;
  ok := s = 'place_released' AND n2 = n AND NOT EXISTS (SELECT 1 FROM public.game_waitlist WHERE game_id = g1);
  r := r || format(E'N5 empty waitlist: nobody promoted or notified: %s (%s, %s->%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s, n, n2);

  -- S6 ------------------------------------------------------------------------------------------------------------
  ok := NOT EXISTS (SELECT 1 FROM public.user_reputation_events x WHERE x.created_at = now());
  r := r || format(E'S6 cancel my place records no penalty row: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  PERFORM pg_temp.k982_as(p2); SELECT result INTO s FROM public.rpc_join_game('player', g1);   -- P2 left in S4
  ok := s = 'joined' AND (SELECT count(*) FROM public.notifications WHERE to_user_id = h AND kind_key = 'game.player_joined'
                            AND context ->> 'entity_id' = g1::text AND context ->> 'actor_user_id' = p2::text) = 2;
  r := r || format(E'S6 re-join notifies the host again: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s);

  -- S7 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p1);
  ok := false;
  BEGIN PERFORM public.rpc_cancel_waitlist_place(g2);
  EXCEPTION WHEN raise_exception THEN ok := SQLERRM = 'started'; END;
  r := r || format(E'S7 cancel my place after start refused: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- S8 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p1); PERFORM public.rpc_join_game('player', g3);
  PERFORM pg_temp.k982_as(p2); PERFORM public.rpc_join_game('player', g3);
  PERFORM pg_temp.k982_as(h);
  SELECT id INTO rq FROM public.game_join_requests WHERE game_id = g3 AND from_user_id = p1;
  s := public.rpc_decide_join_request(rq, false);
  ok := s = 'denied' AND pg_temp.k982_n(p1, 'game.join_declined', g3) = 1 AND pg_temp.k982_n(p1, 'game.join_accepted', g3) = 0;
  r := r || format(E'S8 declined -> one join_declined, no join_accepted: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  SELECT id INTO rq FROM public.game_join_requests WHERE game_id = g3 AND from_user_id = p2;
  s := public.rpc_decide_join_request(rq, true);
  ok := s = 'approved_joined' AND pg_temp.k982_n(p2, 'game.join_accepted', g3) = 1
        AND pg_temp.k982_n(p2, 'game.join_declined', g3) = 0 AND pg_temp.k982_n(h, 'game.player_joined', g3) = 0;
  r := r || format(E'N8 approved -> join_accepted only; host not told of his own approval: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  s := public.rpc_remove_player(g3, (SELECT profile_id FROM public.game_roster WHERE game_id = g3 AND user_id = p2),
                                'Late twice in a row');
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p2 AND kind_key = 'game.removed'
     AND context ->> 'entity_id' = g3::text;
  ok := s = 'removed' AND pg_temp.k982_n(p2, 'game.removed', g3) = 1
        AND nt.args ->> 'reason' = 'Late twice in a row' AND nt.args ->> 'organiser' = public.kan982_display_name(h)
        AND nt.body LIKE '%' || public.kan982_display_name(h) || '%' AND nt.body LIKE '%: Late twice in a row';
  r := r || format(E'S8b removal with a reason -> organiser + reason in args and body: %s (%s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.body);

  -- S9 ------------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(h);
  PERFORM public.rpc_invite_user(g4, p1);
  PERFORM pg_temp.k982_as(p1); PERFORM public.rpc_join_game('player', g4);
  ok := (SELECT status FROM public.game_invites WHERE game_id = g4 AND to_user_id = p1) = 'accepted'
        AND pg_temp.k982_n(h, 'game.invite_accepted', g4) = 1;
  r := r || format(E'S9 invite accepted -> inviter told once: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  PERFORM pg_temp.k982_as(h); inv := public.rpc_invite_user(g4, p2);
  PERFORM pg_temp.k982_as(p2); s := public.rpc_decline_game_invite(inv);
  ok := s = 'declined' AND pg_temp.k982_n(h, 'game.invite_declined', g4) = 1 AND pg_temp.k982_n(p2, 'game.invite_declined', g4) = 0;
  r := r || format(E'S9 invite declined -> inviter told once: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  PERFORM pg_temp.k982_as(h); inv := public.rpc_invite_user(g4, p3); s := public.rpc_withdraw_game_invite(inv);
  ok := s = 'withdrawn' AND pg_temp.k982_n(p3, 'game.invite_withdrawn', g4) = 1 AND pg_temp.k982_n(h, 'game.invite_withdrawn', g4) = 0;
  r := r || format(E'S9 invite withdrawn -> invitee told once: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  INSERT INTO public.game_invites(game_id, to_user_id, invited_by_profile_id, status) VALUES (g2, p4, pr[1], 'pending');
  n := public.expire_game_invites();
  ok := n = 1 AND pg_temp.k982_n(p4, 'game.invite_expired', g2) = 1 AND pg_temp.k982_n(h, 'game.invite_expired', g2) = 0
        AND public.expire_game_invites() = 0 AND pg_temp.k982_n(p4, 'game.invite_expired', g2) = 1;
  r := r || format(E'S9 invite expired -> invitee told once (second sweep idle): %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- S10 -----------------------------------------------------------------------------------------------------------
  PERFORM pg_temp.k982_as(p1); PERFORM public.rpc_meetup_rsvp(m1, 'going');
  PERFORM pg_temp.k982_as(p2); PERFORM public.rpc_meetup_rsvp(m1, 'going');
  PERFORM pg_temp.k982_as(p3); PERFORM public.rpc_meetup_rsvp(m1, 'going');
  PERFORM pg_temp.k982_as(p4); PERFORM public.rpc_meetup_rsvp(m1, 'going');
  PERFORM pg_temp.k982_as(h);
  -- the exact call shape of the live app: named p_meetup_id, p_user_id, no reason
  s := public.rpc_meetup_remove_attendee(p_meetup_id => m1, p_user_id => p1);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'meetup.removed' AND context ->> 'entity_id' = m1::text;
  ok := s = 'removed' AND (SELECT status FROM public.meetup_rsvps WHERE meetup_id = m1 AND user_id = p1) = 'removed'
        AND pg_temp.k982_n(p1, 'meetup.removed', m1) = 1
        AND NOT (nt.args ? 'reason') AND nt.args ->> 'organiser' = public.kan982_display_name(h)
        AND nt.body IN (public.kan982_display_name(h) || ' removed you', 'أزالك ' || public.kan982_display_name(h));
  r := r || format(E'S10 meetup old 2-arg call -> status removed, one notice with organiser, no reason line: %s (%s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.body);
  s := public.rpc_meetup_remove_attendee(m1, p4, 'Not a member of the club');
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p4 AND kind_key = 'meetup.removed' AND context ->> 'entity_id' = m1::text;
  ok := s = 'removed' AND pg_temp.k982_n(p4, 'meetup.removed', m1) = 1
        AND nt.args ->> 'reason' = 'Not a member of the club' AND nt.args ->> 'organiser' = public.kan982_display_name(h)
        AND nt.body LIKE '%: Not a member of the club';
  r := r || format(E'S10 meetup removal with a reason -> organiser + reason: %s (%s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.body);
  ok := pg_temp.k982_n(p2, 'meetup.removed', m1) = 0 AND pg_temp.k982_n(p3, 'meetup.removed', m1) = 0
        AND pg_temp.k982_n(h, 'meetup.player_left', m1) = 0;
  r := r || format(E'N10 others get no meetup.removed; removal is not a leave: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);
  PERFORM pg_temp.k982_as(p2); PERFORM public.rpc_meetup_rsvp(m1, 'cancel');
  ok := (SELECT status FROM public.meetup_rsvps WHERE meetup_id = m1 AND user_id = p2) = 'cancelled'
        AND pg_temp.k982_n(h, 'meetup.player_left', m1) = 1;
  r := r || format(E'S10 attendee leaves -> host gets meetup.player_left: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- S11 -----------------------------------------------------------------------------------------------------------
  INSERT INTO public.notification_settings(user_id, muted_kinds) VALUES (h, ARRAY['game.player_left'])
    ON CONFLICT (user_id) DO UPDATE SET muted_kinds = ARRAY['game.player_left'];
  n := pg_temp.k982_n(h, 'game.player_left', g1);                          -- 3 so far: S4, S5 raw leave, S6 cancel
  PERFORM pg_temp.k982_as(p5); s := public.rpc_leave_game('player', g1);
  -- KAN-974c (PUSH-12): a muted kind still writes the inbox row; delivery skips the push.
  ok := s LIKE 'left%' AND n = 3 AND pg_temp.k982_n(h, 'game.player_left', g1) = n + 1
        AND NOT public.notification_channel_enabled(h, 'game.player_left', 'push')
        AND public.notification_channel_enabled(h, 'game.removed', 'push');
  r := r || format(E'S11 muted kind: inbox row kept, push channel off for that kind only: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);
  INSERT INTO public.user_blocks(blocker_user_id, blocked_user_id) VALUES (p3, h);
  PERFORM pg_temp.k982_as(h); s := public.rpc_meetup_remove_attendee(m1, p3, 'Blocked case');
  ok := s = 'removed' AND pg_temp.k982_n(p3, 'meetup.removed', m1) = 0;
  r := r || format(E'S11 blocked: removal applied, no notice: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- S13 -----------------------------------------------------------------------------------------------------------
  SELECT name_en, coalesce(nullif(btrim(name_ar), ''), name_en) AS name_ar INTO sp FROM public.sports WHERE id = tpl.sport_id;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy, area_id, geo_location_id, sport_id)
  VALUES (e, 'game', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', NULL, 2, 'open', tpl.area_id, tpl.geo_location_id, tpl.sport_id);
  INSERT INTO public.games(id, event_id) VALUES (e, e) RETURNING id INTO g5;
  UPDATE public.profiles SET language = 'en' WHERE user_id = p1;
  UPDATE public.profiles SET language = 'ar' WHERE user_id = p2;
  PERFORM pg_temp.k982_as(p1); PERFORM public.rpc_join_game('player', g5);
  PERFORM pg_temp.k982_as(p2); PERFORM public.rpc_join_game('player', g5);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = h AND kind_key = 'game.full' AND context ->> 'entity_id' = g5::text;
  ok := pg_temp.k982_n(h, 'game.full', g5) = 1
        AND nt.args ->> 'title_en' = sp.name_en || ' game' AND nt.args ->> 'title_ar' = 'مباراة ' || sp.name_ar
        AND nt.title IN (sp.name_en || ' game is full', 'اكتمل العدد في مباراة ' || sp.name_ar);
  r := r || format(E'S13 untitled game.full has a fallback title: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);
  PERFORM pg_temp.k982_as(h);
  PERFORM public.rpc_remove_player(p_game_id => g5, p_profile_id => (SELECT profile_id FROM public.game_roster WHERE game_id = g5 AND user_id = p1));
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.removed' AND context ->> 'entity_id' = g5::text;
  ok := nt.title = 'You were removed from ' || sp.name_en || ' game';
  r := r || format(E'S13 untitled game.removed EN: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);
  PERFORM public.rpc_remove_player(g5, (SELECT profile_id FROM public.game_roster WHERE game_id = g5 AND user_id = p2), 'سبب');
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p2 AND kind_key = 'game.removed' AND context ->> 'entity_id' = g5::text;
  ok := nt.title = 'تمت إزالتك من مباراة ' || sp.name_ar AND nt.body LIKE '%: سبب';
  r := r || format(E'S13 untitled game.removed AR: %s (%s | %s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title, nt.body);
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = p1 AND kind_key = 'game.removed' AND context ->> 'entity_id' = g1::text;
  ok := nt.args ->> 'title_en' = 'KAN982 Probe G1' AND nt.args ->> 'title_ar' = 'KAN982 Probe G1'
        AND nt.title IN ('You were removed from KAN982 Probe G1', 'تمت إزالتك من KAN982 Probe G1');
  r := r || format(E'N13 titled game keeps its own title: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.title);

  -- S12 -----------------------------------------------------------------------------------------------------------
  SELECT count(*) INTO n FROM public.notifications
   WHERE created_at = now() AND schema_version = 1
     AND kind_key IN ('game.removed', 'game.waitlist_promoted', 'game.join_accepted', 'game.player_joined',
                      'game.join_declined', 'game.invite_accepted', 'game.invite_declined', 'game.invite_withdrawn',
                      'game.invite_expired', 'game.player_left', 'game.full', 'game.waitlist_joined',
                      'meetup.removed', 'meetup.player_left');
  SELECT count(*) INTO n2 FROM public.notifications WHERE created_at = now() AND schema_version = 2;
  r := r || format(E'S12 no legacy-path row for a KAN-982 kind: %s (legacy %s, v2 %s)\n', CASE WHEN n = 0 THEN 'ok' ELSE 'FAIL' END, n, n2);

  RAISE EXCEPTION E'KAN982 PROBE RESULTS (rolled back)\n%', r;
END
$probe$;
