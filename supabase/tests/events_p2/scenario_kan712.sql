-- KAN-712 OLD-vs-NEW SCENARIO. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
--
-- Run the SAME file against two local databases built by the same chain:
--   OLD = harness + seed + KAN-712 harness + KAN-710 + KAN-711 + backfill   (phase 1: legacy authoritative)
--   NEW = OLD + 20261103100000 + 20261103110000                              (phase 2: events authoritative)
-- and diff the outputs. Every RPC is called as the API role that calls it live (authenticated, or
-- service_role for the generator) with request.jwt.claim.sub set, exactly as PostgREST would.
-- The output is a normalized projection: no generated ids, no timestamps that come from now()
-- (only fixed scenario timestamps), so OLD and NEW must print byte-identical text. Error outcomes
-- print SQLSTATE only (message text is printed for the two documented pre-existing defects).
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
CREATE TEMP TABLE lbl (label text PRIMARY KEY, id uuid);
CREATE TEMP TABLE out (step int, what text, result text);

-- helper: run a SQL expression as <role> with auth.uid() = <uid>, return its text result or ERR <sqlstate>
CREATE FUNCTION pg_temp.run(p_step int, p_what text, p_role text, p_uid uuid, p_sql text, p_label text DEFAULT NULL, p_msg boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v text; v_state text; v_msg text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    RESET ROLE;   -- the SET LOCAL above was undone with the subtransaction; this is belt and braces
    PERFORM set_config('request.jwt.claim.sub', '', true);
    INSERT INTO out VALUES (p_step, p_what, 'ERR ' || v_state || CASE WHEN p_msg THEN ' ' || v_msg ELSE '' END);
    RETURN;
  END;
  IF p_label IS NOT NULL THEN INSERT INTO lbl VALUES (p_label, v::uuid); v := 'id:' || p_label; END IF;
  INSERT INTO out VALUES (p_step, p_what, coalesce(v, '<null>'));
END $$;
CREATE FUNCTION pg_temp.id(p text) RETURNS text LANGUAGE sql AS $$ SELECT quote_literal(id) FROM lbl WHERE label = p $$;

\set A1 '''00000000-0000-0000-0000-0000000000a1'''
\set A2 '''00000000-0000-0000-0000-0000000000a2'''
\set A3 '''00000000-0000-0000-0000-0000000000a3'''
\set A4 '''00000000-0000-0000-0000-0000000000a4'''
\set SPORT '''00000000-0000-0000-0000-0000000000e1'''
\set GEO '''00000000-0000-0000-0000-0000000000d1'''
\set AREA '''00000000-0000-0000-0000-0000000000c1'''

-- 1. Game create with request_id, replay, update, reschedule, booking hold, cancel ---------------------------
SELECT pg_temp.run(1, 'game create', 'authenticated', :A1, format($q$SELECT public.rpc_create_game(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Game one', p_start_at => '2027-03-01 18:00+00', p_end_at => '2027-03-01 19:00+00',
  p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
  p_request_id => 'aaaaaaaa-0000-0000-0000-000000000001')::text$q$, :SPORT, :GEO, :AREA), 'G1');
SELECT pg_temp.run(2, 'game create replay returns same id', 'authenticated', :A1, format($q$SELECT (public.rpc_create_game(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Game one', p_start_at => '2027-03-01 18:00+00', p_end_at => '2027-03-01 19:00+00',
  p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
  p_request_id => 'aaaaaaaa-0000-0000-0000-000000000001') = %s)::text$q$, :SPORT, :GEO, :AREA, pg_temp.id('G1')));
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
  SELECT id, '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active' FROM lbl WHERE label = 'G1';
SELECT pg_temp.run(3, 'rpc_update_game', 'authenticated', :A1, format($q$SELECT public.rpc_update_game(%s, '2027-03-02 18:00+00', '2027-03-02 20:00+00',
  p_title => 'Game one edited', p_max_players => 12, p_min_players => 4, p_price_aed => 25, p_listing_visibility => 'followers')$q$, pg_temp.id('G1')));
SELECT pg_temp.run(4, 'rpc_update_game by non-host', 'authenticated', :A2, format($q$SELECT public.rpc_update_game(%s, '2027-03-02 18:00+00', '2027-03-02 20:00+00',
  p_title => 'stolen', p_price_aed => 0)$q$, pg_temp.id('G1')));
SELECT pg_temp.run(5, 'rpc_reschedule_game', 'authenticated', :A1, format($q$SELECT public.rpc_reschedule_game(%s, '2027-03-03 17:00+00', '2027-03-03 18:30+00')$q$, pg_temp.id('G1')));
SELECT pg_temp.run(6, 'rpc_booking_hold_for_game', 'authenticated', :A1, format($q$SELECT (public.rpc_booking_hold_for_game(%s, '00000000-0000-0000-0000-00000000ee11',
  '2027-03-03 17:00+00', '2027-03-03 18:30+00') IS NOT NULL)::text$q$, pg_temp.id('G1')));
SELECT pg_temp.run(7, 'rpc_cancel_game', 'authenticated', :A1, format($q$SELECT public.rpc_cancel_game(%s, 'rain')$q$, pg_temp.id('G1')));
SELECT pg_temp.run(8, 'rpc_cancel_game again (no new side effects)', 'authenticated', :A1, format($q$SELECT public.rpc_cancel_game(%s, 'rain again')$q$, pg_temp.id('G1')));

-- 2. Meetup create with request_id, replay, update, cancel ---------------------------------------------------
SELECT pg_temp.run(10, 'meetup create', 'authenticated', :A1, format($q$SELECT public.rpc_create_meetup(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Meetup one', p_geo_location_id => %L, p_area_id => %L,
  p_start_at => '2027-04-01 09:00+00', p_end_at => '2027-04-01 11:00+00', p_capacity => 12,
  p_request_id => 'aaaaaaaa-0000-0000-0000-000000000002')::text$q$, :SPORT, :GEO, :AREA), 'M1');
SELECT pg_temp.run(11, 'meetup create replay returns same id', 'authenticated', :A1, format($q$SELECT (public.rpc_create_meetup(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Meetup one', p_geo_location_id => %L, p_area_id => %L,
  p_start_at => '2027-04-01 09:00+00', p_end_at => '2027-04-01 11:00+00', p_capacity => 12,
  p_request_id => 'aaaaaaaa-0000-0000-0000-000000000002') = %s)::text$q$, :SPORT, :GEO, :AREA, pg_temp.id('M1')));
INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  SELECT id, '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'going' FROM lbl WHERE label = 'M1';
SELECT pg_temp.run(12, 'rpc_meetup_update', 'authenticated', :A1, format($q$SELECT (public.rpc_meetup_update(%s, p_title => 'Meetup one edited',
  p_start_at => '2027-04-02 09:00+00', p_end_at => '2027-04-02 12:00+00', p_capacity => 20) - 'id')::text$q$, pg_temp.id('M1')));
SELECT pg_temp.run(13, 'rpc_meetup_update by non-host', 'authenticated', :A2, format($q$SELECT public.rpc_meetup_update(%s, p_title => 'stolen')::text$q$, pg_temp.id('M1')));
SELECT pg_temp.run(14, 'rpc_meetup_cancel', 'authenticated', :A1, format($q$SELECT public.rpc_meetup_cancel(%s)$q$, pg_temp.id('M1')));
SELECT pg_temp.run(15, 'rpc_meetup_cancel again', 'authenticated', :A1, format($q$SELECT public.rpc_meetup_cancel(%s)$q$, pg_temp.id('M1')));

-- 3. Failed creates leave no rows ------------------------------------------------------------------------------
CREATE TEMP TABLE cnt AS SELECT (SELECT count(*) FROM public.games) g, (SELECT count(*) FROM public.meetups) m,
  (SELECT count(*) FROM public.events) e, (SELECT count(*) FROM public.event_outbox) o, (SELECT count(*) FROM public.public_activities) a;
SELECT pg_temp.run(20, 'game create: bad geo FK', 'authenticated', :A1, format($q$SELECT public.rpc_create_game(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Bad', p_start_at => '2027-05-01 18:00+00', p_end_at => '2027-05-01 19:00+00',
  p_geo_location_id => '00000000-0000-0000-0000-00000000dead', p_area_id => %L, p_price_aed => 0,
  p_request_id => 'aaaaaaaa-0000-0000-0000-000000000003')::text$q$, :SPORT, :AREA));
SELECT pg_temp.run(21, 'game create: invalid time range', 'authenticated', :A1, format($q$SELECT public.rpc_create_game(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Bad', p_start_at => '2027-05-01 18:00+00', p_end_at => '2027-05-01 17:00+00',
  p_geo_location_id => %L, p_area_id => %L, p_price_aed => 0)::text$q$, :SPORT, :GEO, :AREA));
SELECT pg_temp.run(22, 'meetup create: title too short (legacy CHECK)', 'authenticated', :A1, format($q$SELECT public.rpc_create_meetup(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'x', p_geo_location_id => %L, p_area_id => %L,
  p_start_at => '2027-05-01 09:00+00', p_request_id => 'aaaaaaaa-0000-0000-0000-000000000004')::text$q$, :SPORT, :GEO, :AREA));
INSERT INTO out SELECT 23, 'failed creates: row deltas games/meetups/events/outbox/activities',
  concat_ws('/', (SELECT count(*) FROM public.games) - g, (SELECT count(*) FROM public.meetups) - m, (SELECT count(*) FROM public.events) - e,
            (SELECT count(*) FROM public.event_outbox) - o, (SELECT count(*) FROM public.public_activities) - a) FROM cnt;

-- 4. Series: create (generator via rpc), edit one occurrence, edit future, cancel series; cron generator ------
SELECT pg_temp.run(30, 'rpc_create_game_series', 'authenticated', :A1, format($q$SELECT public.rpc_create_game_series('player', %L, NULL, %L, %L,
  '2027-01-04', '18:00', 60, 'UTC', 'weekly', 10, 'Series one', NULL, NULL, 'public', 'open', 3, 0)::text$q$, :SPORT, :GEO, :AREA), 'S1');
INSERT INTO lbl SELECT 'S1occ1', id FROM public.games WHERE series_id = (SELECT id FROM lbl WHERE label = 'S1') ORDER BY start_at LIMIT 1;
SELECT pg_temp.run(31, 'rpc_edit_game_series_occurrence', 'authenticated', :A1, format($q$SELECT (public.rpc_edit_game_series_occurrence(%s,
  p_title => 'Series one, first edited', p_start_at => '2027-01-04 19:00+00', p_capacity => 8) IS NOT NULL)::text$q$, pg_temp.id('S1occ1')));
SELECT pg_temp.run(32, 'rpc_edit_game_series_future', 'authenticated', :A1, format($q$SELECT (public.rpc_edit_game_series_future(%s,
  p_title => 'Series one v2', p_capacity => 14, p_start_time_local => '20:00', p_ends_on => '2027-01-11') - 'series_id')::text$q$, pg_temp.id('S1')));
SELECT pg_temp.run(33, 'rpc_cancel_game_series', 'authenticated', :A1, format($q$SELECT (public.rpc_cancel_game_series(%s, 'season over') - 'series_id')::text$q$, pg_temp.id('S1')));
SELECT pg_temp.run(34, 'rpc_create_game_series (second)', 'authenticated', :A2, format($q$SELECT public.rpc_create_game_series('player', %L, NULL, %L, %L,
  '2027-02-01', '07:30', 90, 'Asia/Dubai', 'biweekly', 6, 'Series two', NULL, NULL, 'public', 'open', 2, 0)::text$q$, :SPORT, :GEO, :AREA), 'S2');
UPDATE public.game_series SET occurrences_ahead = 3 WHERE id = (SELECT id FROM lbl WHERE label = 'S2');
SELECT pg_temp.run(35, 'fn_generate_game_series_occurrences(NULL) as service_role (cron)', 'service_role', NULL,
  $q$SELECT public.fn_generate_game_series_occurrences(NULL)::text$q$);
SELECT pg_temp.run(36, 'fn_generate_game_series_occurrences as authenticated (not granted)', 'authenticated', :A2,
  $q$SELECT public.fn_generate_game_series_occurrences(NULL)::text$q$);

-- 5. Challenge spawn (pre-existing defect: can never insert), admin cleanup ---------------------------------
SELECT pg_temp.run(40, 'rpc_challenge_spawn_game (defect, fails in both)', 'authenticated', :A1,
  $q$SELECT public.rpc_challenge_spawn_game('00000000-0000-0000-0000-00000000cf01', '2027-06-01 10:00+00')::text$q$);
SELECT pg_temp.run(41, 'cleanup target creates a game', 'authenticated', :A4, format($q$SELECT public.rpc_create_game(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Cleanup game', p_start_at => '2027-07-01 18:00+00', p_end_at => '2027-07-01 19:00+00',
  p_geo_location_id => %L, p_area_id => %L, p_price_aed => 0)::text$q$, :SPORT, :GEO, :AREA), 'G4');
SELECT pg_temp.run(42, 'admin_cleanup_user_data by non-admin', 'authenticated', :A1, $q$SELECT count(*)::text FROM public.admin_cleanup_user_data('00000000-0000-0000-0000-0000000000a4', false)$q$);
SELECT pg_temp.run(43, 'admin_cleanup_user_data (games-only user)', 'authenticated', :A3,
  $q$SELECT string_agg(affected_table || '.' || affected_column || '=' || rows_affected, ',' ORDER BY affected_table, affected_column)
       FROM public.admin_cleanup_user_data('00000000-0000-0000-0000-0000000000a4', false)$q$);
INSERT INTO out SELECT 44, 'cleanup leaves no G4 row in games/events', (SELECT count(*) FROM public.games WHERE id = l.id) || '/' ||
  (SELECT count(*) FROM public.events WHERE id = l.id) FROM lbl l WHERE l.label = 'G4';
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-0000000000a5');
INSERT INTO public.profiles(id, user_id) VALUES ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-0000000000a5');
SELECT pg_temp.run(45, 'meetup-owning user creates a meetup', 'authenticated', '00000000-0000-0000-0000-0000000000a5', format($q$SELECT public.rpc_create_meetup(p_actor_type => 'player',
  p_sport_id => %L, p_sport_variant_id => NULL, p_title => 'Cleanup meetup', p_geo_location_id => %L, p_area_id => %L,
  p_start_at => '2027-07-02 09:00+00')::text$q$, :SPORT, :GEO, :AREA), 'M5');
SELECT pg_temp.run(46, 'admin_cleanup_user_data (meetup owner: pre-existing RESTRICT failure)', 'authenticated', :A3,
  $q$SELECT count(*)::text FROM public.admin_cleanup_user_data('00000000-0000-0000-0000-0000000000a5', false)$q$, NULL, true);

-- Projection ---------------------------------------------------------------------------------------------------
SELECT '#STEP|' || step || '|' || what || '|' || result FROM out ORDER BY step;
SELECT '#GAME|' || concat_ws('|', g.title, g.start_at, g.end_at, g.capacity, g.listing_visibility, g.join_policy, g.is_cancelled,
       g.cancelled_reason, g.cancelled_at IS NOT NULL, g.venue_space_id, g.price_aed, g.joining_rule, g.cost_cover,
       g.series_id IS NOT NULL, g.creator_user_id, g.creator_profile_id, g.request_id, g.rules, g.event_id = g.id)
  FROM public.games g ORDER BY 1;
SELECT '#MEETUP|' || concat_ws('|', m.title, m.start_at, m.end_at, m.capacity, m.listing_visibility, m.rsvp_policy, m.is_cancelled,
       m.joining_rule, m.cost_cover, m.creator_user_id, m.creator_profile_id, m.host_actor_id, m.request_id, m.event_id = m.id)
  FROM public.meetups m ORDER BY 1;
SELECT '#EVENT|' || concat_ws('|', e.event_type, e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.join_policy,
       e.is_cancelled, e.cancelled_reason, e.cancelled_at IS NOT NULL, e.joining_rule, e.cost_cover, e.creator_user_id, e.request_id)
  FROM public.events e ORDER BY 1;
SELECT '#SERIES|' || concat_ws('|', s.title, s.status, s.capacity, s.start_time_local, s.ends_on, s.occurrences_ahead) FROM public.game_series s ORDER BY 1;
SELECT '#SINK|public_activities|' || activity_type || '|deleted=' || is_deleted || '|' || count(*) FROM public.public_activities GROUP BY activity_type, is_deleted ORDER BY 1;
SELECT '#SINK|event_outbox|' || event_key || '|' || count(*) FROM public.event_outbox GROUP BY event_key ORDER BY 1;
SELECT '#SINK|notifications|' || kind || '|' || count(*) FROM public.notifications GROUP BY kind ORDER BY 1;
SELECT '#SINK|msg_system_lines|' || kind || '|' || count(*) FROM public.msg_system_lines GROUP BY kind ORDER BY 1;
SELECT '#SINK|venue_bookings|' || count(*) FROM public.venue_bookings;
SELECT '#SINK|game_roster|' || count(*) || '|meetup_rsvps|' || (SELECT count(*) FROM public.meetup_rsvps) FROM public.game_roster;
SELECT '#PARITY|kan711_events_parity rows=' || count(*) FROM public.kan711_events_parity;
SELECT '#PARITY|updated_at equal games=' || (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.id WHERE e.updated_at IS DISTINCT FROM g.updated_at)
    || ' meetups=' || (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.id WHERE e.updated_at IS DISTINCT FROM m.updated_at)
    || ' orphans=' || (SELECT count(*) FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
                                                             AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id));
ROLLBACK;
