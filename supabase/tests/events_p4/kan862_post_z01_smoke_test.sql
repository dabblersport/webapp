-- KAN-862 post-Z01 smoke (Z01 = supabase/migrations/20261113202013_kan862_z01_remove_replaced_columns.sql, manifest
-- 254f6202893607899592380ee724a79b). Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely
-- inside BEGIN ... ROLLBACK: every row a call writes is undone by the final ROLLBACK.
--
-- Each client-facing write and read path that touched a removed games/meetups column is called as role authenticated
-- (user a3ba3271-3556-4b4e-b15d-bc0851f8a64b, the KAN-717 fixture account). A call PASSES when it completes or returns
-- a business refusal; it FAILS on a schema-class error (42703 undefined column, 42P01 undefined table, 42883, 42702).
-- Two pre-existing schema errors are KNOWN and expected to persist (they predate Z01 and are not caused by it):
--   getnearbymeetups      42P01 relation "public.geolocations" does not exist
--   rpc_meetup_visible    42703 column m.starts_at does not exist
-- A KNOWN call passes only if it raises exactly its known SQLSTATE (so a different new error is still caught).
-- M3 (Z04 write contract): an events UPDATE on a game and a meetup completes; kan712_update_event_shared as service_role
-- is recorded (its kan712_not_cut_over refusal is pre-existing, KAN-862 comment 16229).
-- Last: the created meetup pairs 1:1 with its events parent and carries the updated title and the cancel, and its
-- 'meetup_create' activity exists (deleted after the cancel) with the host's 'meetup_join' child (the first run of this
-- file caught call 1 failing with 23503 on that parent; fixed by 20261113202544_kan862_post_z01_meetups_activity_sync).
-- rpc_search_entities raises 42P01 on public.v_person_card, which Z01 does not touch (Z01 drops no relation); it is
-- recorded as KNOWN pre-existing so a different error there is still caught.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862s_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862s_ctx (k text PRIMARY KEY, v text) ON COMMIT DROP;

-- Runs p_sql (one value) as p_role with the fixture JWT; returns 'OK <value>' or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.k862s_as(p_role text, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; st text; msg text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', 'role', p_role)::text, true);
  PERFORM set_config('request.jwt.claim.sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', true);
  BEGIN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO r;
    RESET ROLE;
    r := 'OK ' || coalesce(left(r, 160), '<null>');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
    r := 'ERR ' || st || ' ' || msg;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN r;
END $f$;

-- Records one call. p_known = the one SQLSTATE this call is known to raise (NULL = must not raise a schema-class error).
CREATE FUNCTION pg_temp.k862s_rec(p_n int, p_label text, p_res text, p_known text DEFAULT NULL) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO k862s_tap VALUES (p_n,
    CASE WHEN p_known IS NOT NULL THEN p_res LIKE 'ERR ' || p_known || ' %'
         ELSE p_res !~ '^ERR (42703|42P01|42883|42702) ' END,
    p_label, p_res);
$f$;

-- 1 create meetup (events first; meetups gets only the 9 retained columns)
SELECT pg_temp.k862s_rec(1, 'rpc_create_meetup', pg_temp.k862s_as('authenticated', $q$
  SELECT public.rpc_create_meetup(
    p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
    p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
    p_title => 'KAN862 post-Z01 smoke meetup', p_description => 'smoke',
    p_venue_id => '0d5145ca-5d5e-489e-8f01-a84fd8bf39c1'::uuid, p_location_name => 'The Warehouse Gym DIFC',
    p_geo_location_id => '67e53ee4-d5bf-4ced-82f2-c8de28a12b91'::uuid, p_area_id => '7aeab558-fcc2-4559-b4a2-56832e57e33d'::uuid,
    p_start_at => timestamptz '2026-11-27 06:00 Asia/Dubai', p_end_at => timestamptz '2026-11-27 07:00 Asia/Dubai',
    p_capacity => 8, p_listing_visibility => 'public', p_rsvp_policy => 'open',
    p_request_id => 'a8620000-0000-4000-8000-000000000001'::uuid)::text$q$));
INSERT INTO k862s_ctx SELECT 'mid', substr(detail, 4) FROM k862s_tap WHERE n = 1 AND detail LIKE 'OK %';

-- 2 meetup card
SELECT pg_temp.k862s_rec(2, 'rpc_meetup_card', pg_temp.k862s_as('authenticated',
  format('SELECT public.rpc_meetup_card(%L::uuid)::text', (SELECT v FROM k862s_ctx WHERE k = 'mid'))));
-- 3 meetup update (host)
SELECT pg_temp.k862s_rec(3, 'rpc_meetup_update', pg_temp.k862s_as('authenticated',
  format('SELECT public.rpc_meetup_update(%L::uuid, p_title => %L, p_capacity => 10)::text', (SELECT v FROM k862s_ctx WHERE k = 'mid'), 'KAN862 post-Z01 smoke updated')));
-- 4 meetup RSVP (an existing public meetup the fixture user is not going to)
SELECT pg_temp.k862s_rec(4, 'rpc_meetup_rsvp going', pg_temp.k862s_as('authenticated',
  $q$SELECT public.rpc_meetup_rsvp('6a48cba4-2b1a-4759-93ea-29ca9fa4feff'::uuid, 'going')$q$));
-- 5 meetup cancel (host)
SELECT pg_temp.k862s_rec(5, 'rpc_meetup_cancel', pg_temp.k862s_as('authenticated',
  format('SELECT public.rpc_meetup_cancel(%L::uuid)', (SELECT v FROM k862s_ctx WHERE k = 'mid'))));
-- 6/7 known pre-existing errors
SELECT pg_temp.k862s_rec(6, 'getnearbymeetups (known 42P01)', pg_temp.k862s_as('authenticated',
  $q$SELECT count(*)::text FROM public.getnearbymeetups(25.2, 55.27, 10000)$q$), '42P01');
SELECT pg_temp.k862s_rec(7, 'rpc_meetup_visible (known 42703)', pg_temp.k862s_as('authenticated',
  $q$SELECT count(*)::text FROM public.rpc_meetup_visible()$q$), '42703');
-- 8 create game
SELECT pg_temp.k862s_rec(8, 'rpc_create_game', pg_temp.k862s_as('authenticated', $q$
  SELECT public.rpc_create_game(
    p_actor_type => 'player', p_sport_id => '2502490a-0339-436c-8b5e-5ac1514606c9'::uuid,
    p_sport_variant_id => '490ce916-b984-4da5-af37-c0019402359e'::uuid, p_title => 'KAN862 post-Z01 smoke game',
    p_venue_space_id => 'e561f01a-1cb7-447e-9355-5aa97e1fcef2'::uuid,
    p_start_at => timestamptz '2026-11-29 18:00 Asia/Dubai', p_end_at => timestamptz '2026-11-29 19:30 Asia/Dubai',
    p_listing_visibility => 'public', p_join_policy => 'open',
    p_geo_location_id => 'fb768cbb-ac02-4867-9ee6-9aa0a09e4e7b'::uuid, p_area_id => 'a0000000-0000-0000-0000-000000000023'::uuid,
    p_price_aed => 25, p_request_id => 'a8620000-0000-4000-8000-000000000002'::uuid)::text$q$));
-- 9 join game (public, open, free, future, not hosted by the fixture user)
SELECT pg_temp.k862s_rec(9, 'rpc_join_game', pg_temp.k862s_as('authenticated',
  $q$SELECT row(j.*)::text FROM public.rpc_join_game('player', 'b8a42a77-f572-4b9d-996b-e84e69cd7ae0'::uuid) j$q$));
-- 10 create game series
SELECT pg_temp.k862s_rec(10, 'rpc_create_game_series', pg_temp.k862s_as('authenticated', $q$
  SELECT public.rpc_create_game_series(
    'player', '2502490a-0339-436c-8b5e-5ac1514606c9'::uuid, '490ce916-b984-4da5-af37-c0019402359e'::uuid,
    'fb768cbb-ac02-4867-9ee6-9aa0a09e4e7b'::uuid, 'a0000000-0000-0000-0000-000000000023'::uuid,
    date '2026-11-30', time '18:00', 90, 'Asia/Dubai', 'weekly', 4,
    'KAN862 post-Z01 smoke series', 'e561f01a-1cb7-447e-9355-5aa97e1fcef2'::uuid, date '2026-12-07',
    'public', 'open', 2, 0::numeric)::text$q$));
-- 11/12 search
SELECT pg_temp.k862s_rec(11, 'rpc_unified_search_sectioned', pg_temp.k862s_as('authenticated',
  $q$SELECT (SELECT string_agg(k || '=' || jsonb_array_length(v), ',' ORDER BY k) FROM jsonb_each(public.rpc_unified_search_sectioned('padel')) x(k, v) WHERE jsonb_typeof(v) = 'array')$q$));
SELECT pg_temp.k862s_rec(12, 'rpc_search_entities (known 42P01 v_person_card, all scopes)', pg_temp.k862s_as('authenticated',
  $q$SELECT count(*)::text || ' rows: ' || coalesce(string_agg(DISTINCT entity_type, ','), '-') FROM public.rpc_search_entities('padel', ARRAY['people','venues','squads','games','arenas','meetups'])$q$), '42P01');
-- 17 rpc_search_entities fails on v_person_card before it reaches its games section (any scope), so that section's
-- query (v_game_card JOIN kan714_games_read on search_tsv) is run directly, as its definer (postgres) runs it.
DO $s17$
DECLARE r text;
BEGIN
  BEGIN
    SELECT 'OK ' || count(*) || ' games' INTO r FROM public.v_game_card g JOIN public.kan714_games_read gm ON gm.id = g.id
     WHERE gm.search_tsv @@ plainto_tsquery('simple', 'padel');
  EXCEPTION WHEN OTHERS THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM pg_temp.k862s_rec(17, 'search games section: v_game_card JOIN kan714_games_read.search_tsv', r);
END $s17$;
-- 13 client read paths over meetups (views) and the meetups table itself
SELECT pg_temp.k862s_rec(13, 'reads: v_meetup_list / kan718_meetups_compat / meetups as authenticated', pg_temp.k862s_as('authenticated',
  $q$SELECT (SELECT count(*) FROM public.v_meetup_list) || '/' || (SELECT count(*) FROM public.kan718_meetups_compat) || '/' || (SELECT count(*) FROM public.meetups)$q$));
-- 14 M3: events UPDATE on one game and one meetup (as postgres)
DO $m3$
DECLARE n int; r text;
BEGIN
  BEGIN
    UPDATE public.events SET updated_at = updated_at WHERE id IN ('b8a42a77-f572-4b9d-996b-e84e69cd7ae0', '6a48cba4-2b1a-4759-93ea-29ca9fa4feff');
    GET DIAGNOSTICS n = ROW_COUNT;
    r := 'OK ' || n || ' rows';
  EXCEPTION WHEN OTHERS THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM pg_temp.k862s_rec(14, 'M3 events UPDATE (game + meetup)', r);
END $m3$;
-- 15 M3: the authorised shared-write path as service_role (recorded; 55000 kan712_not_cut_over is pre-existing)
SELECT pg_temp.k862s_rec(15, 'M3 kan712_update_event_shared as service_role (no schema error)', pg_temp.k862s_as('service_role',
  $q$SELECT public.kan712_update_event_shared('6a48cba4-2b1a-4759-93ea-29ca9fa4feff'::uuid, '{"title":"Dubai community workout"}'::jsonb)::text$q$));
-- 16 parity of the created meetup
INSERT INTO k862s_tap SELECT 16,
  count(*) = 1 AND bool_and(e.event_type = 'meetup' AND m.event_id = m.id AND e.title = 'KAN862 post-Z01 smoke updated' AND e.capacity = 10 AND e.is_cancelled),
  'created meetup: one events parent, updated title/capacity, cancelled',
  string_agg(e.title || ' cap=' || e.capacity || ' cancelled=' || e.is_cancelled || ' host_actor=' || (m.host_actor_id IS NOT NULL), '; ')
  FROM public.meetups m JOIN public.events e ON e.id = m.id
 WHERE m.id = (SELECT v::uuid FROM k862s_ctx WHERE k = 'mid');
INSERT INTO k862s_tap SELECT 18,
  count(*) FILTER (WHERE pa.id = x.mid AND pa.activity_type = 'meetup_create' AND pa.is_deleted) = 1
  AND count(*) FILTER (WHERE pa.parent_activity_id = x.mid AND pa.activity_type = 'meetup_join') = 1,
  'created meetup: meetup_create activity (deleted by the cancel) + host meetup_join child',
  string_agg(pa.activity_type || ' deleted=' || pa.is_deleted, '; ' ORDER BY pa.activity_type)
  FROM (SELECT v::uuid mid FROM k862s_ctx WHERE k = 'mid') x
  JOIN public.public_activities pa ON pa.id = x.mid OR pa.parent_activity_id = x.mid;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || ' :: ' || coalesce(detail, ''), E'\n' ORDER BY n) AS tap,
       count(*) FILTER (WHERE ok) AS n_ok, count(*) FILTER (WHERE NOT ok) AS n_not_ok
  FROM k862s_tap;
ROLLBACK;
