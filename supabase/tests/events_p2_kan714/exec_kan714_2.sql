-- KAN-714 part 2 EXECUTION + RESULT-PARITY + WRITE-PARITY PROBE. LOCAL THROWAWAY POSTGRES ONLY.
-- One transaction, ROLLBACK at the end; every case additionally runs in its own subtransaction that is rolled
-- back, so cases cannot leak state into each other and the database is unchanged afterwards.
--
-- Prints one line per case:  row|object|case|actor|STATUS|out=<md5 of normalised output>|state=<md5 of normalised
-- after-state of every table a write path touches>
--   STATUS = OK, or ERR <sqlstate> <first 90 chars of the message, normalised>.
-- Normalisation: random (v4) uuids -> <u>; timestamps on the current date -> <now>. Fixture ids are not v4.
-- Run on k713b (no KAN-714), k714b (part 1) and k714c (parts 1+2): `diff` must be empty — the repoint changes
-- the source of every shared value, never the value (the KAN-712 compat mirror keeps the legacy copy exact).
-- Run on the corrupted copies (corrupt_legacy_kan714.sql) for PROVENANCE: a case whose output follows the
-- corrupted legacy value pre-KAN-714 and the events value post-KAN-714 proves the read moved.
-- A case that never reaches the object's read (an error raised before it) is reported by the contract as
-- NOT-EXECUTED for that object, never as a pass.
\set ON_ERROR_STOP 1

BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE xout (rown int, obj text, cs text, actor text, status text, outh text, stateh text);
GRANT ALL ON xout TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.norm(t text) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT regexp_replace(
           regexp_replace(coalesce(t, '<null>'),
             '[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}', '<u>', 'g'),
           to_char(current_date, 'YYYY-MM-DD') || '[ T][0-9:.]+([+-][0-9:]+)?', '<now>', 'g')
$$;

-- After-state of every table a repointed write path can touch (only the tables that exist in this harness).
CREATE FUNCTION pg_temp.state() RETURNS text LANGUAGE plpgsql AS $$
DECLARE t text; v text; acc text := '';
BEGIN
  FOREACH t IN ARRAY ARRAY['games','meetups','events','game_roster','game_join_requests','game_waitlist','game_invites',
    'meetup_rsvps','meetup_attendees','meetup_invites','notifications','activity_events','public_activities',
    'game_link_tokens','meetup_link_tokens','venue_bookings','game_rating_events','user_reputation_events',
    'venue_rating_events','game_settlements','wallet_ledger','charges','event_outbox','feed_items','game_series',
    'msg_conversations','msg_conversation_members','posts','game_rating_aggregate']
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('SELECT md5(coalesce(string_agg(pg_temp.norm(x::text), E''\n'' ORDER BY pg_temp.norm(x::text)), '''')) FROM public.%I x', t) INTO v;
      acc := acc || t || ':' || v || ';';
    END IF;
  END LOOP;
  RETURN md5(acc);
END $$;

-- Run p_sql (a query returning rows) as p_role with auth.uid() = p_uid (p_role NULL = the owner session,
-- i.e. cron / service / trigger context), record output + after-state, then roll the subtransaction back.
CREATE FUNCTION pg_temp.x(p_row int, p_obj text, p_cs text, p_actor text, p_role text, p_uid uuid, p_sql text, p_state boolean DEFAULT true, p_pre text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v text; st text := '-'; s text; m text; ok boolean := false;
BEGIN
  BEGIN
    IF p_pre IS NOT NULL THEN EXECUTE p_pre; END IF;  -- case-local setup, rolled back with the case
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    IF p_sql ~* '^\s*(insert|update|delete)\s' THEN
      -- DML that fires the trigger under test: output is the row count; the effect is in the after-state.
      EXECUTE p_sql;
      GET DIAGNOSTICS v = ROW_COUNT;
    ELSE
      EXECUTE format('SELECT coalesce(string_agg(pg_temp.norm(t::text), E''\n'' ORDER BY pg_temp.norm(t::text)), '''') FROM (%s) t', p_sql) INTO v;
    END IF;
    RESET ROLE;
    ok := true;
    IF p_state THEN st := pg_temp.state(); END IF;
    RAISE EXCEPTION USING ERRCODE = 'KX714', MESSAGE = 'rollback case';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO xout VALUES (p_row, p_obj, p_cs, p_actor,
    CASE WHEN ok THEN 'OK' ELSE 'ERR ' || s || ' ' || left(pg_temp.norm(m), 90) END,
    CASE WHEN ok THEN md5(v) ELSE '-' END, st);
END $$;

-- Fixture constants
CREATE TEMP TABLE k (n text PRIMARY KEY, v uuid);
INSERT INTO k VALUES
  ('a1','00000000-0000-0000-0000-0000000000a1'),('a2','00000000-0000-0000-0000-0000000000a2'),
  ('a3','00000000-0000-0000-0000-0000000000a3'),('a4','00000000-0000-0000-0000-0000000000a4'),
  ('a5','00000000-0000-0000-0000-0000000000a5'),('a7','00000000-0000-0000-0000-0000000000a7'),
  ('b4','00000000-0000-0000-0000-0000000000b4');

-- Seed (identical on every database): one game conversation for the msg_* readers.
INSERT INTO public.msg_conversations (id, kind, game_id, created_at, last_activity_at)
  VALUES ('c7140000-0000-0000-0000-000000000001', 'game', '71300000-0000-0000-0000-000000000001', '2030-01-01', '2030-01-01');
INSERT INTO public.msg_conversation_members (conversation_id, user_id, updated_at)
  VALUES ('c7140000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a4', '2030-01-01'),
         ('c7140000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '2030-01-01');

-- Attach the production triggers of the trigger functions under test (repo: baseline_schema.sql:29653,
-- 29669, 29823, 29835, 29899, 29903, 29911, 30059, 30139, 30345; 20260915150000_meetups_notifications.sql:195).
CREATE OR REPLACE TRIGGER tr_game_roster_activity_sync AFTER INSERT OR UPDATE ON public.game_roster FOR EACH ROW EXECUTE FUNCTION public.fn_game_roster_activity_sync();
CREATE OR REPLACE TRIGGER tr_meetup_rsvps_activity_sync AFTER INSERT OR UPDATE ON public.meetup_rsvps FOR EACH ROW EXECUTE FUNCTION public.fn_meetup_rsvps_activity_sync();
CREATE OR REPLACE TRIGGER trg_game_join_request_notify AFTER INSERT ON public.game_join_requests FOR EACH ROW EXECUTE FUNCTION public.trg_game_join_request_notify();
CREATE OR REPLACE TRIGGER trg_game_waitlist_promoted_notify AFTER DELETE ON public.game_waitlist FOR EACH ROW EXECUTE FUNCTION public.trg_game_waitlist_promoted_notify();
CREATE OR REPLACE TRIGGER trg_meetup_rsvps_notify AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps FOR EACH ROW EXECUTE FUNCTION public.trg_meetup_rsvps_notify();
CREATE OR REPLACE TRIGGER trg_invite_block_frozen BEFORE INSERT ON public.game_invites FOR EACH ROW EXECUTE FUNCTION public.trgfn_invite_block_frozen();
CREATE OR REPLACE TRIGGER trg_invite_block_frozen_guard BEFORE INSERT ON public.game_invites FOR EACH ROW EXECUTE FUNCTION public.trgfn_invite_block_frozen_guard();
CREATE OR REPLACE TRIGGER trg_joinreq_block_frozen_guard BEFORE INSERT ON public.game_join_requests FOR EACH ROW EXECUTE FUNCTION public.trgfn_joinreq_block_frozen_guard();
CREATE OR REPLACE TRIGGER trg_posts_set_geo BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.trgfn_posts_set_geo();
CREATE OR REPLACE TRIGGER trg_roster_block_frozen_guard BEFORE INSERT ON public.game_roster FOR EACH ROW EXECUTE FUNCTION public.trgfn_roster_block_frozen_guard();
CREATE OR REPLACE TRIGGER trg_zz_waitlist_block_frozen BEFORE INSERT ON public.game_waitlist FOR EACH ROW EXECUTE FUNCTION public.trgfn_waitlist_block_frozen_guard();

-- A frozen user (a5) so the frozen guards take their reading branch.
INSERT INTO public.user_freezes (user_id, reason, frozen_at) VALUES ('00000000-0000-0000-0000-0000000000a5', 'kan714 probe', '2030-01-01');

SELECT pg_temp.x(0, 'baseline', 'state', '-', NULL, NULL, 'SELECT 1');

-- ===================================== REPOINTED (part 2) =====================================
-- readers
SELECT pg_temp.x(8, 'active_stream', 'default', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT * FROM public.active_stream()', false);
SELECT pg_temp.x(8, 'active_stream', 'games-meetups', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT * FROM public.active_stream(ARRAY[''game_created'',''meetup_created'',''game_completed'',''meetup_completed''], NULL, 200)', false);
SELECT pg_temp.x(10, 'admin_overview_row', 'admin', 'a3', 'authenticated', (SELECT v FROM k WHERE n='a3'), 'SELECT * FROM public.admin_overview_row()', false);
SELECT pg_temp.x(10, 'admin_overview_row', 'owner', 'owner', NULL, NULL, 'SELECT * FROM public.admin_overview_row()', false);
SELECT pg_temp.x(22, 'get_games_needing_players', 'owner', 'owner', NULL, NULL, 'SELECT (e - ''existing_profiles'') || jsonb_build_object(''existing_profiles_sorted'', (SELECT jsonb_agg(v ORDER BY v) FROM jsonb_array_elements(coalesce(nullif(e->''existing_profiles'', ''null''::jsonb), ''[]''::jsonb)) v)) FROM jsonb_array_elements(public.get_games_needing_players()::jsonb) e', false);
SELECT pg_temp.x(25, 'get_open_games_for_seeding', 'owner', 'owner', NULL, NULL, 'SELECT * FROM public.get_open_games_for_seeding()', false);
SELECT pg_temp.x(38, 'msg_authorize', 'member', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT * FROM public.msg_authorize(''c7140000-0000-0000-0000-000000000001'')', true);
SELECT pg_temp.x(38, 'msg_authorize', 'nonmember', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.msg_authorize(''c7140000-0000-0000-0000-000000000001'')', true);
SELECT pg_temp.x(39, 'msg_evaluate', 'host', 'owner', NULL, NULL, 'SELECT * FROM public.msg_evaluate(''c7140000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000a1'')', false);
SELECT pg_temp.x(39, 'msg_evaluate', 'member', 'owner', NULL, NULL, 'SELECT * FROM public.msg_evaluate(''c7140000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000a4'')', false);
SELECT pg_temp.x(39, 'msg_evaluate', 'stranger', 'owner', NULL, NULL, 'SELECT * FROM public.msg_evaluate(''c7140000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000a2'')', false);
SELECT pg_temp.x(41, 'msg_my_conversations', 'member', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT * FROM public.msg_my_conversations()', false);
SELECT pg_temp.x(42, 'nearby_games', 'dubai', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.nearby_games(25.2, 55.27, 100000000, NULL, 500)', false);
SELECT pg_temp.x(43, 'rpc_autocomplete_entities', 'games', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_autocomplete_entities(''G'', ARRAY[''games''], NULL, 100)', false);
SELECT pg_temp.x(57, 'rpc_get_activity_feed', 'all', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT * FROM public.rpc_get_activity_feed(''all'', 500)', false);
SELECT pg_temp.x(58, 'rpc_get_nearby_games/5', 'dubai', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 100000000, NULL::uuid, ''distance''::text)', false);
SELECT pg_temp.x(59, 'rpc_get_nearby_games/6', 'dubai', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 100000000, NULL::uuid, ''soonest''::text, 1000::numeric)', false);
SELECT pg_temp.x(81, 'rpc_search_entities', 'games', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_search_entities(''G'', ARRAY[''games''], NULL, 100)', false);
SELECT pg_temp.x(83, 'rpc_unified_search_sectioned', 'q', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_unified_search_sectioned(''G'')', false);
SELECT pg_temp.x(83, 'rpc_unified_search_sectioned', 'q-meetup', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT * FROM public.rpc_unified_search_sectioned(''M-'')', false);

-- write / gate paths (output + full after-state)
SELECT pg_temp.x(9, 'admin_cleanup_user_data', 'dry-run', 'a3', 'authenticated', (SELECT v FROM k WHERE n='a3'), 'SELECT * FROM public.admin_cleanup_user_data(''00000000-0000-0000-0000-0000000000a1'', true)');
SELECT pg_temp.x(9, 'admin_cleanup_user_data', 'apply', 'a3', 'authenticated', (SELECT v FROM k WHERE n='a3'), 'SELECT * FROM public.admin_cleanup_user_data(''00000000-0000-0000-0000-0000000000a1'', false)');
SELECT pg_temp.x(9, 'admin_cleanup_user_data', 'apply-no-conv', 'a3', 'authenticated', (SELECT v FROM k WHERE n='a3'), 'SELECT * FROM public.admin_cleanup_user_data(''00000000-0000-0000-0000-0000000000a1'', false)', true, 'DELETE FROM public.msg_conversation_members; DELETE FROM public.msg_conversations');
SELECT pg_temp.x(17, 'fn_generate_game_series_occurrences', 'series-f1', 'owner', NULL, NULL, 'SELECT public.fn_generate_game_series_occurrences(''00000000-0000-0000-0000-0000000000f1'')');
SELECT pg_temp.x(45, 'rpc_booking_hold_for_game', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_booking_hold_for_game(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-06-01 18:00+00'', ''2030-06-01 19:00+00'')');
SELECT pg_temp.x(45, 'rpc_booking_hold_for_game', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_booking_hold_for_game(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-06-01 18:00+00'', ''2030-06-01 19:00+00'')');
SELECT pg_temp.x(46, 'rpc_booking_hold_for_meetup', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_booking_hold_for_meetup(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-07-01 18:00+00'', ''2030-07-01 19:00+00'')');
SELECT pg_temp.x(46, 'rpc_booking_hold_for_meetup', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_booking_hold_for_meetup(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-07-01 18:00+00'', ''2030-07-01 19:00+00'')');
SELECT pg_temp.x(44, 'rpc_booking_cancel', 'game-host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_booking_cancel(public.rpc_booking_hold_for_game(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-06-01 18:00+00'', ''2030-06-01 19:00+00''))');
SELECT pg_temp.x(44, 'rpc_booking_cancel', 'meetup-host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_booking_cancel(public.rpc_booking_hold_for_meetup(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-00000000ee11'', ''2030-07-01 18:00+00'', ''2030-07-01 19:00+00''))');
SELECT pg_temp.x(49, 'rpc_create_game', 'player', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_create_game(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''G-new'', NULL, ''2031-01-01 18:00+00'', ''2031-01-01 19:00+00'', p_area_id => ''00000000-0000-0000-0000-0000000000c1'', p_geo_location_id => ''00000000-0000-0000-0000-0000000000d1'')');
SELECT pg_temp.x(49, 'rpc_create_game', 'idempotent-replay', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_create_game(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''G-new'', NULL, ''2031-01-01 18:00+00'', ''2031-01-01 19:00+00'', p_area_id => ''00000000-0000-0000-0000-0000000000c1'', p_geo_location_id => ''00000000-0000-0000-0000-0000000000d1'', p_request_id => ''71400000-0000-0000-0000-0000000000aa'') UNION ALL SELECT public.rpc_create_game(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''G-new'', NULL, ''2031-01-01 18:00+00'', ''2031-01-01 19:00+00'', p_area_id => ''00000000-0000-0000-0000-0000000000c1'', p_lat => 25.2, p_lng => 55.27, p_request_id => ''71400000-0000-0000-0000-0000000000aa'')');
SELECT pg_temp.x(52, 'rpc_create_meetup', 'player', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_create_meetup(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''M-new'', p_start_at => ''2031-01-01 18:00+00'')');
SELECT pg_temp.x(52, 'rpc_create_meetup', 'idempotent-replay', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_create_meetup(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''M-new'', p_start_at => ''2031-01-01 18:00+00'', p_request_id => ''71400000-0000-0000-0000-0000000000ab'') UNION ALL SELECT public.rpc_create_meetup(''player'', (SELECT id FROM public.sports LIMIT 1), NULL, ''M-new'', p_start_at => ''2031-01-01 18:00+00'', p_request_id => ''71400000-0000-0000-0000-0000000000ab'')');
SELECT pg_temp.x(53, 'rpc_decide_join_request', 'host-approve', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_decide_join_request((SELECT id FROM public.game_join_requests LIMIT 1), true)');
SELECT pg_temp.x(53, 'rpc_decide_join_request', 'host-reject', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_decide_join_request((SELECT id FROM public.game_join_requests LIMIT 1), false)');
SELECT pg_temp.x(53, 'rpc_decide_join_request', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_decide_join_request((SELECT id FROM public.game_join_requests LIMIT 1), true)');
SELECT pg_temp.x(60, 'rpc_invite_user', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_invite_user(''71300000-0000-0000-0000-000000000003'', ''00000000-0000-0000-0000-0000000000a2'')');
SELECT pg_temp.x(60, 'rpc_invite_user', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_invite_user(''71300000-0000-0000-0000-000000000003'', ''00000000-0000-0000-0000-0000000000a5'')');
SELECT pg_temp.x(61, 'rpc_join_game', 'public-open', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_join_game(''player'', ''71300000-0000-0000-0000-000000000001'')');
SELECT pg_temp.x(61, 'rpc_join_game', 'followers-request', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_join_game(''player'', ''71300000-0000-0000-0000-000000000002'')');
SELECT pg_temp.x(61, 'rpc_join_game', 'private-invitee', 'a7', 'authenticated', (SELECT v FROM k WHERE n='a7'), 'SELECT public.rpc_join_game(''player'', ''71300000-0000-0000-0000-000000000003'')');
SELECT pg_temp.x(61, 'rpc_join_game', 'link-token', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_join_game(''player'', ''71300000-0000-0000-0000-000000000004'', (SELECT token FROM public.game_link_tokens LIMIT 1))');
SELECT pg_temp.x(65, 'rpc_meetup_decide_request', 'host-approve', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_decide_request(''71300000-0000-0000-0000-000000000102'', ''00000000-0000-0000-0000-0000000000a5'', ''approve'')');
SELECT pg_temp.x(65, 'rpc_meetup_decide_request', 'host-decline', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_decide_request(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-0000000000a2'', ''decline'')');
SELECT pg_temp.x(65, 'rpc_meetup_decide_request', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_meetup_decide_request(''71300000-0000-0000-0000-000000000102'', ''00000000-0000-0000-0000-0000000000a5'', ''approve'')');
SELECT pg_temp.x(69, 'rpc_meetup_remove_attendee', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_remove_attendee(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-0000000000a4'')');
SELECT pg_temp.x(69, 'rpc_meetup_remove_attendee', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_meetup_remove_attendee(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-0000000000a4'')');
SELECT pg_temp.x(70, 'rpc_meetup_rsvp', 'public-going', 'a7', 'authenticated', (SELECT v FROM k WHERE n='a7'), 'SELECT public.rpc_meetup_rsvp(''71300000-0000-0000-0000-000000000101'', ''going'')');
SELECT pg_temp.x(70, 'rpc_meetup_rsvp', 'circle-going', 'a7', 'authenticated', (SELECT v FROM k WHERE n='a7'), 'SELECT public.rpc_meetup_rsvp(''71300000-0000-0000-0000-000000000102'', ''going'')');
SELECT pg_temp.x(70, 'rpc_meetup_rsvp', 'invite-going', 'a7', 'authenticated', (SELECT v FROM k WHERE n='a7'), 'SELECT public.rpc_meetup_rsvp(''71300000-0000-0000-0000-000000000103'', ''going'')');
SELECT pg_temp.x(74, 'rpc_mint_join_link', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_mint_join_link(''71300000-0000-0000-0000-000000000004'')');
SELECT pg_temp.x(74, 'rpc_mint_join_link', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_mint_join_link(''71300000-0000-0000-0000-000000000004'')');
SELECT pg_temp.x(75, 'rpc_rate_game', 'player', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT public.rpc_rate_game(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000b4'', ''{"fun":5}'')');
SELECT pg_temp.x(76, 'rpc_rate_user', 'player', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT public.rpc_rate_user(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000b4'', ''00000000-0000-0000-0000-0000000000a1'', ''{"fair":5}'')');
SELECT pg_temp.x(77, 'rpc_rate_venue', 'player', 'a4', 'authenticated', (SELECT v FROM k WHERE n='a4'), 'SELECT public.rpc_rate_venue(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-00000000ee01'', ''00000000-0000-0000-0000-0000000000b4'', ''{"clean":5}'')');
SELECT pg_temp.x(78, 'rpc_recreate_from_game', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_recreate_from_game(''71300000-0000-0000-0000-000000000001'')');
SELECT pg_temp.x(78, 'rpc_recreate_from_game', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_recreate_from_game(''71300000-0000-0000-0000-000000000001'')');
SELECT pg_temp.x(79, 'rpc_remove_player', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_remove_player(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000b4'')');
SELECT pg_temp.x(79, 'rpc_remove_player', 'non-host', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.rpc_remove_player(''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000b4'')');
SELECT pg_temp.x(86, 'settle_game', 'preview', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.settle_game(''71300000-0000-0000-0000-000000000001'', false)');
SELECT pg_temp.x(86, 'settle_game', 'finalize', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.settle_game(''71300000-0000-0000-0000-000000000001'', true)');

-- trigger functions (fired by the DML their production trigger is attached to)
SELECT pg_temp.x(16, 'fn_game_roster_activity_sync', 'roster-insert', 'owner', NULL, NULL, 'INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000a2'', ''00000000-0000-0000-0000-0000000000b2'', ''player'', ''active'')');
SELECT pg_temp.x(16, 'fn_game_roster_activity_sync', 'roster-update', 'owner', NULL, NULL, 'UPDATE public.game_roster SET status = ''left'' WHERE game_id = ''71300000-0000-0000-0000-000000000002''');
SELECT pg_temp.x(18, 'fn_meetup_rsvps_activity_sync+89', 'rsvp-insert', 'owner', NULL, NULL, 'INSERT INTO public.meetup_rsvps (meetup_id, user_id, status, profile_id) VALUES (''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-0000000000a7'', ''going'', ''00000000-0000-0000-0000-0000000000b7'')');
SELECT pg_temp.x(89, 'trg_meetup_rsvps_notify+18', 'rsvp-update-going', 'owner', NULL, NULL, 'UPDATE public.meetup_rsvps SET status = ''going'' WHERE meetup_id = ''71300000-0000-0000-0000-000000000101'' AND user_id = ''00000000-0000-0000-0000-0000000000a2''');
SELECT pg_temp.x(87, 'trg_game_join_request_notify+92', 'joinreq-insert', 'owner', NULL, NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (''71300000-0000-0000-0000-000000000002'', ''00000000-0000-0000-0000-0000000000b4'', ''00000000-0000-0000-0000-0000000000a4'', ''pending'')');
SELECT pg_temp.x(88, 'trg_game_waitlist_promoted_notify', 'waitlist-delete', 'owner', NULL, NULL, 'DELETE FROM public.game_waitlist WHERE game_id = ''71300000-0000-0000-0000-000000000003''');

-- ===================================== EXCEPTION-E4 (stay on the compat mirror) =====================================
SELECT pg_temp.x(5, '_recent_activity_score', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public._recent_activity_score(''00000000-0000-0000-0000-0000000000b4'', 3650)', false);
SELECT pg_temp.x(5, '_recent_activity_score', 'owner', 'owner', NULL, NULL, 'SELECT public._recent_activity_score(''00000000-0000-0000-0000-0000000000b4'', 3650)', false);
SELECT pg_temp.x(6, '_slot_conflicts_game', 'direct', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public._slot_conflicts_game(''00000000-0000-0000-0000-00000000ee11'', ''2030-06-01 17:30+00'', ''2030-06-01 18:30+00'')', false);
SELECT pg_temp.x(6, '_slot_conflicts_game', 'owner', 'owner', NULL, NULL, 'SELECT public._slot_conflicts_game(''00000000-0000-0000-0000-00000000ee11'', ''2030-06-01 17:30+00'', ''2030-06-01 18:30+00'')', false);
SELECT pg_temp.x(7, '_user_hosted_game', 'direct', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public._user_hosted_game(''00000000-0000-0000-0000-0000000000a1'', ''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(7, '_user_hosted_game', 'owner', 'owner', NULL, NULL, 'SELECT public._user_hosted_game(''00000000-0000-0000-0000-0000000000a1'', ''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(19, 'game_is_joinable', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.game_is_joinable(''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(19, 'game_is_joinable', 'owner', 'owner', NULL, NULL, 'SELECT public.game_is_joinable(''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(21, 'game_slots_left', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.game_slots_left(''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(21, 'game_slots_left', 'owner', 'owner', NULL, NULL, 'SELECT public.game_slots_left(''71300000-0000-0000-0000-000000000001'')', false);
SELECT pg_temp.x(23, 'get_nearby_games/float', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.get_nearby_games(25.2, 55.27, 100000000::float8)', false);
SELECT pg_temp.x(23, 'get_nearby_games/float', 'owner', 'owner', NULL, NULL, 'SELECT * FROM public.get_nearby_games(25.2, 55.27, 100000000::float8)', false);
SELECT pg_temp.x(24, 'get_nearby_games/int', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.get_nearby_games(25.2, 55.27, 100000000)', false);
SELECT pg_temp.x(24, 'get_nearby_games/int', 'owner', 'owner', NULL, NULL, 'SELECT * FROM public.get_nearby_games(25.2, 55.27, 100000000)', false);
SELECT pg_temp.x(37, 'meetup_slots_left', 'direct', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public.meetup_slots_left(''71300000-0000-0000-0000-000000000102'')', false);
SELECT pg_temp.x(37, 'meetup_slots_left', 'owner', 'owner', NULL, NULL, 'SELECT public.meetup_slots_left(''71300000-0000-0000-0000-000000000102'')', false);
SELECT pg_temp.x(90, 'trgfn_invite_block_frozen+91', 'invite-frozen', 'owner', NULL, NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, status) VALUES (''71300000-0000-0000-0000-000000000003'', ''00000000-0000-0000-0000-0000000000a5'', ''pending'')');
SELECT pg_temp.x(91, 'trgfn_invite_block_frozen_guard+90', 'invite-ok', 'owner', NULL, NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, status) VALUES (''71300000-0000-0000-0000-000000000003'', ''00000000-0000-0000-0000-0000000000a2'', ''pending'')');
SELECT pg_temp.x(92, 'trgfn_joinreq_block_frozen_guard+87', 'joinreq-frozen', 'owner', NULL, NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (''71300000-0000-0000-0000-000000000002'', ''00000000-0000-0000-0000-0000000000b5'', ''00000000-0000-0000-0000-0000000000a5'', ''pending'')');
SELECT pg_temp.x(93, 'trgfn_posts_set_geo', 'post-insert', 'owner', NULL, NULL, 'INSERT INTO public.posts (author_profile_id, author_user_id, visibility) VALUES (''00000000-0000-0000-0000-0000000000b1'', ''00000000-0000-0000-0000-0000000000a1'', ''public'')');
SELECT pg_temp.x(94, 'trgfn_roster_block_frozen_guard+16', 'roster-frozen', 'owner', NULL, NULL, 'INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000a5'', ''00000000-0000-0000-0000-0000000000b5'', ''player'', ''active'')');
SELECT pg_temp.x(95, 'trgfn_waitlist_block_frozen_guard', 'waitlist-frozen', 'owner', NULL, NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (''71300000-0000-0000-0000-000000000001'', ''00000000-0000-0000-0000-0000000000b5'', ''00000000-0000-0000-0000-0000000000a5'', 9)');

-- ===================================== EXCEPTION-E1 / E3 (pre-existing) =====================================
SELECT pg_temp.x(1, '_can_view_game', 'G-pri-stranger', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT public._can_view_game(''71300000-0000-0000-0000-000000000003'')', false);
SELECT pg_temp.x(26, 'getnearbygames', 'dubai', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.getnearbygames(25.2, 55.27, 100000)', false);
SELECT pg_temp.x(27, 'getnearbymeetups', 'dubai', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.getnearbymeetups(25.2, 55.27, 100000)', false);
SELECT pg_temp.x(66, 'rpc_meetup_invite_user', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_invite_user(''71300000-0000-0000-0000-000000000103'', ''00000000-0000-0000-0000-0000000000a2'', NULL)');
SELECT pg_temp.x(67, 'rpc_meetup_mint_link', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_mint_link(''71300000-0000-0000-0000-000000000104'', NULL, NULL)');
SELECT pg_temp.x(68, 'rpc_meetup_my', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT * FROM public.rpc_meetup_my()', false);
SELECT pg_temp.x(71, 'rpc_meetup_set_attendee', 'host', 'a1', 'authenticated', (SELECT v FROM k WHERE n='a1'), 'SELECT public.rpc_meetup_set_attendee(''71300000-0000-0000-0000-000000000101'', ''00000000-0000-0000-0000-0000000000a4'', ''going'')');
SELECT pg_temp.x(73, 'rpc_meetup_visible', 'any', 'a2', 'authenticated', (SELECT v FROM k WHERE n='a2'), 'SELECT * FROM public.rpc_meetup_visible()', false);

SELECT rown || '|' || obj || '|' || cs || '|' || actor || '|' || status || '|out=' || outh || '|state=' || stateh
  FROM xout ORDER BY rown, obj, cs, actor;
SELECT '#CASES ' || count(*) || ' OK ' || count(*) FILTER (WHERE status = 'OK') || ' ERR ' || count(*) FILTER (WHERE status <> 'OK') FROM xout;
ROLLBACK;
