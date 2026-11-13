-- KAN-934 item 3 live test: in a casual (player-created) game the host plays, so the host's active roster row counts
-- toward roster_count and against capacity everywhere; a hosted (organiser) game keeps today's count (host counted).
-- Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- App-facing calls run AS authenticated (SET LOCAL ROLE + JWT claims). kan714_game_slots_left and the legacy nearby
-- overloads have no client grant, so they are read as postgres. game_slots_left is INVOKER and is only reached through
-- definer RPCs (rpc_join_game, rpc_decide_join_request): a client caller cannot read games (no SELECT policy), so it
-- returns 0 there by design; it is read as postgres, the context rpc_join_game gives it.
-- Host: user a3ba3271 (contributor: player + organiser). Three games at the free padel space e561f01a, capacity 4:
--   casual public/open (player), casual link (player, for rpc_game_card_by_link), hosted public/open (organiser).
-- Joiners: four live users (active player persona, not admin/frozen, no blocks, not the host).
-- RED before 20261113234131_kan934_casual_host_counted.sql: T2..T8 (host not counted in casual), T10 (5th person joins: overfill).
--   T1  each game has exactly one active host row and capacity 4
--   T2  casual: game_slots_left = capacity-1 (definer context)
--   T3  casual: v_game_card.roster_count = 1 (as host)
--   T4  casual: rpc_get_nearby_games player_count 1 / spots_remaining capacity-1
--   T5  casual: rpc_get_nearby_games_legacy_v2 / _v3 the same (as postgres)
--   T6  casual: kan714_game_slots_left = capacity-1 (as postgres)
--   T7  casual link: rpc_game_card_by_link roster_count = 1
--   T8  casual: capacity-1 joiners each 'joined'
--   T9  casual: after that, game_slots_left 0, roster_count = capacity
--   T10 casual: the next joiner is not 'joined'; active roster stays = capacity
--   T11 hosted: roster_count 1 and game_slots_left capacity-1 (unchanged; GREEN before and after)
--   T12 hosted: nearby player_count 1
--   T13 ACL/owner/security attributes of the re-authored objects unchanged
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k934_tap (n int PRIMARY KEY, ok boolean, label text NOT NULL, detail text) ON COMMIT DROP;
GRANT ALL ON k934_tap TO authenticated;

CREATE FUNCTION pg_temp.k934_as(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN COALESCE(v, '<null>');
END $f$;

DO $run$
DECLARE
  host uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  c_padel uuid := '2502490a-0339-436c-8b5e-5ac1514606c9'; c_padel_v uuid := '490ce916-b984-4da5-af37-c0019402359e';
  c_free uuid := 'e561f01a-1cb7-447e-9355-5aa97e1fcef2';
  c_geo uuid := 'fb768cbb-ac02-4867-9ee6-9aa0a09e4e7b';   c_area uuid := 'a0000000-0000-0000-0000-000000000023';
  t0 timestamptz := date_trunc('hour', now()) + interval '10 days';
  create_sql text := 'SELECT public.rpc_create_game(%L, %L::uuid, %L::uuid, %L, %L::uuid, %L::timestamptz, %L::timestamptz, 0, %L, %L, NULL, NULL, NULL, NULL, false, false, NULL, NULL, %L::uuid, %L::uuid, NULL, NULL, NULL, 4, 0::numeric, NULL)::text';
  gc uuid; gl uuid; gh uuid; cap int; lat float8; lng float8; tok uuid;
  joiners uuid[]; v text; i int; res text := '';
BEGIN
  gc := pg_temp.k934_as(host, format(create_sql, 'player', c_padel, c_padel_v, 'K934 casual', c_free, t0, t0 + interval '90 minutes', 'public', 'open', c_geo, c_area))::uuid;
  gl := pg_temp.k934_as(host, format(create_sql, 'player', c_padel, c_padel_v, 'K934 casual link', c_free, t0 + interval '3 hours', t0 + interval '270 minutes', 'private', 'link', c_geo, c_area))::uuid;
  gh := pg_temp.k934_as(host, format(create_sql, 'organiser', c_padel, c_padel_v, 'K934 hosted', c_free, t0 + interval '6 hours', t0 + interval '450 minutes', 'public', 'open', c_geo, c_area))::uuid;

  SELECT e.capacity, st_y(g2.location::geometry), st_x(g2.location::geometry) INTO cap, lat, lng
    FROM public.games g JOIN public.events e ON e.id = g.event_id JOIN public.geo_locations g2 ON g2.id = e.geo_location_id
   WHERE g.id = gc;

  INSERT INTO k934_tap SELECT 1,
    (SELECT bool_and(c = 1) FROM (SELECT count(*) FILTER (WHERE r.role = 'host' AND r.status = 'active') c
       FROM unnest(ARRAY[gc, gl, gh]) x(id) LEFT JOIN public.game_roster r ON r.game_id = x.id GROUP BY x.id) s) AND cap = 4,
    'one active host row per game, capacity 4',
    format('cap=%s types=%s', cap, (SELECT string_agg(game_type, ',' ORDER BY game_type) FROM public.games WHERE id IN (gc, gl, gh)));

  v := public.game_slots_left(gc)::text;
  INSERT INTO k934_tap VALUES (2, v = (cap - 1)::text, 'casual: game_slots_left = capacity-1 (definer context)', v);

  v := pg_temp.k934_as(host, format('SELECT roster_count::text FROM public.v_game_card WHERE id = %L::uuid', gc));
  INSERT INTO k934_tap VALUES (3, v = '1', 'casual: v_game_card.roster_count = 1', v);

  v := pg_temp.k934_as(host, format('SELECT player_count || ''/'' || spots_remaining FROM public.rpc_get_nearby_games(%s, %s, 2000, %L::uuid, ''distance'', NULL) WHERE id = %L::uuid', lat, lng, c_padel, gc));
  INSERT INTO k934_tap VALUES (4, v = '1/' || (cap - 1), 'casual: rpc_get_nearby_games player_count/spots_remaining', v);

  v := (SELECT player_count || '/' || spots_remaining FROM public.rpc_get_nearby_games_legacy_v2(lat, lng, 2000, c_padel, 'distance') WHERE id = gc)
    || ' ' || (SELECT player_count || '/' || spots_remaining FROM public.rpc_get_nearby_games_legacy_v3(lat, lng, 2000, c_padel, 'distance') WHERE id = gc);
  INSERT INTO k934_tap VALUES (5, v = format('1/%s 1/%s', cap - 1, cap - 1), 'casual: legacy_v2 / legacy_v3 nearby', COALESCE(v, '<null>'));

  v := public.kan714_game_slots_left(gc)::text;
  INSERT INTO k934_tap VALUES (6, v = (cap - 1)::text, 'casual: kan714_game_slots_left = capacity-1', v);

  tok := pg_temp.k934_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', gl))::uuid;
  v := pg_temp.k934_as(host, format('SELECT roster_count::text FROM public.rpc_game_card_by_link(%L::uuid, %L::uuid)', gl, tok));
  INSERT INTO k934_tap VALUES (7, v = '1', 'casual link: rpc_game_card_by_link roster_count = 1', v);

  SELECT array_agg(uid) INTO joiners FROM (
    SELECT p.user_id uid FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND p.user_id IS NOT NULL AND p.user_id <> host
       AND NOT public.is_admin(p.user_id) AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
       AND (SELECT count(*) FROM public.profiles p2 WHERE p2.user_id = p.user_id AND p2.persona_type = 'player') = 1
     ORDER BY p.created_at LIMIT 4) s;

  FOR i IN 1 .. cap - 1 LOOP
    res := res || pg_temp.k934_as(joiners[i], format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid, NULL)', gc)) || ',';
  END LOOP;
  INSERT INTO k934_tap VALUES (8, res = repeat('joined,', cap - 1), 'casual: capacity-1 joiners each joined', res);

  v := public.game_slots_left(gc) || '/' || pg_temp.k934_as(host, format('SELECT roster_count::text FROM public.v_game_card WHERE id = %L::uuid', gc));
  INSERT INTO k934_tap VALUES (9, v = '0/' || cap, 'casual: full at capacity (slots 0, roster_count = capacity)', v);

  v := pg_temp.k934_as(joiners[cap], format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid, NULL)', gc));
  INSERT INTO k934_tap VALUES (10,
    v <> 'joined' AND (SELECT count(*) FROM public.game_roster WHERE game_id = gc AND status = 'active') = cap,
    'casual: next joiner not joined; active roster = capacity',
    v || ' active=' || (SELECT count(*) FROM public.game_roster WHERE game_id = gc AND status = 'active'));

  v := pg_temp.k934_as(host, format('SELECT roster_count::text FROM public.v_game_card WHERE id = %L::uuid', gh)) || '/' || public.game_slots_left(gh);
  INSERT INTO k934_tap VALUES (11, v = '1/' || (cap - 1), 'hosted: roster_count 1, slots capacity-1 (unchanged)', v);

  v := pg_temp.k934_as(host, format('SELECT player_count::text FROM public.rpc_get_nearby_games(%s, %s, 2000, %L::uuid, ''distance'', NULL) WHERE id = %L::uuid', lat, lng, c_padel, gh));
  INSERT INTO k934_tap VALUES (12, v = '1', 'hosted: nearby player_count 1', v);
END
$run$;

INSERT INTO k934_tap SELECT 13,
  (SELECT bool_and(ok) FROM (VALUES
    ((SELECT proacl::text FROM pg_proc WHERE oid = 'public.game_slots_left(uuid)'::regprocedure) = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ((SELECT proacl::text FROM pg_proc WHERE oid = 'public.kan714_game_slots_left(uuid)'::regprocedure) = '{postgres=X/postgres}'),
    ((SELECT proacl::text || prosecdef FROM pg_proc WHERE oid = 'public.rpc_game_card_by_link(uuid,uuid)'::regprocedure) = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}true'),
    ((SELECT proacl::text || prosecdef FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure) = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres,anon=X/postgres}true'),
    ((SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games_legacy_v2(double precision,double precision,integer,uuid,text)'::regprocedure) = '{postgres=X/postgres,service_role=X/postgres}'),
    ((SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text)'::regprocedure) = '{postgres=X/postgres,service_role=X/postgres}'),
    ((SELECT relacl::text || pg_get_userbyid(relowner) || COALESCE(reloptions::text, '-') FROM pg_class WHERE oid = 'public.v_game_card'::regclass)
       = '{postgres=arwdDxtm/postgres,anon=rxtm/postgres,authenticated=rxtm/postgres,service_role=arwdDxtm/postgres}postgres-')
  ) x(ok)), 'ACL / owner / security attributes unchanged', NULL;

SELECT n, ok, label, detail FROM k934_tap ORDER BY n;
ROLLBACK;
