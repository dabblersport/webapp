-- KAN-862 P1 live proof for supabase/migrations/20261113145508_kan804_p1_rebased_frozen_guards_b.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-804: the roster frozen guard and trgfn_posts_set_geo PATH 2 read host / geo / area through
-- kan804_game_event_facts (events) for a caller that sees the games row, and never reach it otherwise.
-- METHOD: as postgres, a roster insert and a game-tied post insert BEFORE the divergence (probes 2-3: roster passes,
-- post geo = G's geo); then Z is frozen and made host in events, and events geo_location_id is moved to another
-- location L2 (games keeps H and its geo). After: roster insert -> user_frozen, post geo = L2. As authenticated (games
-- invisible), neither path may raise a permission error on the service_role-only helper.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k804_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k804_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k804_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE r text; who text;
BEGIN
  BEGIN
    IF p_uid IS NOT NULL THEN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
      IF p_role = 'authenticated' THEN PERFORM set_config('role', 'authenticated', true); END IF;
    END IF;
    who := current_user;
    EXECUTE p_sql INTO r;
    RAISE EXCEPTION 'k804_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k804_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k804_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k804_case ON COMMIT DROP AS
WITH g AS (
  SELECT g.id, g.event_id, e.creator_user_id AS host
    FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE e.start_at > now() + interval '1 day' AND NOT e.is_cancelled AND e.join_policy = 'open'
     AND e.listing_visibility = 'public' AND g.squad_id IS NULL AND public.game_slots_left(g.id) > 0
     AND NOT public.is_frozen(e.creator_user_id) AND NOT public.is_admin(e.creator_user_id)
   ORDER BY e.start_at, g.id LIMIT 1),
v AS (
  SELECT p.user_id AS uid, p.id AS pid, row_number() OVER (ORDER BY p.created_at, p.id) AS rn
    FROM public.profiles p, g
   WHERE p.is_active AND p.persona_type = 'player' AND p.user_id IS NOT NULL
     AND p.user_id IS DISTINCT FROM g.host
     AND NOT public.is_admin(p.user_id) AND NOT public.is_frozen(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id AND (r.user_id = p.user_id OR r.profile_id = p.id))
     AND NOT EXISTS (SELECT 1 FROM public.game_waitlist w WHERE w.game_id = g.id AND w.user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = g.id AND q.from_user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.user_id = p.user_id AND p2.id <> p.id)
     AND public.can_view_with_scope(p.user_id, g.host, 'public', NULL))
SELECT g.id AS gid, g.event_id AS eid, g.host,
       (SELECT uid FROM v WHERE rn = 1) AS x, (SELECT pid FROM v WHERE rn = 1) AS xp,
       (SELECT uid FROM v WHERE rn = 2) AS y, (SELECT pid FROM v WHERE rn = 2) AS yp,
       (SELECT uid FROM v WHERE rn = 3) AS z
  FROM g;

INSERT INTO k804_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k804_case;

CREATE TEMP TABLE k804_geo ON COMMIT DROP AS
  SELECT e.geo_location_id AS l1,
         (SELECT gl.id FROM public.geo_locations gl WHERE gl.location IS NOT NULL AND gl.id IS DISTINCT FROM e.geo_location_id
           ORDER BY gl.id LIMIT 1) AS l2
    FROM k804_case c JOIN public.events e ON e.id = c.eid;

SELECT pg_temp.k804_call('a_pre_roster', NULL, format('INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (%L, %L, %L, %L, %L) RETURNING %L', gid, yp, y, 'player', 'active', 'inserted')) FROM k804_case;
SELECT pg_temp.k804_call('b_pre_post', NULL, format('INSERT INTO public.posts (author_profile_id, author_user_id, kind, visibility, game_id, geo_lat, geo_lng, geo_location_id, area_id) VALUES (%L, %L, %L, %L, %L, 0, 0, %L, %L) RETURNING geo_location_id::text', yp, y, 'original', 'public', gid, l2, (SELECT area_id FROM public.geo_locations WHERE id = l2))) FROM k804_case, k804_geo;

INSERT INTO public.user_freezes (user_id, is_frozen, is_active, reason, created_by) SELECT z, true, true, 'KAN-862 P1 probe (rolled back)', x FROM k804_case;
UPDATE public.events SET creator_user_id = (SELECT z FROM k804_case), geo_location_id = (SELECT l2 FROM k804_geo)
 WHERE id = (SELECT eid FROM k804_case);

SELECT pg_temp.k804_call('c_roster', NULL, format('INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (%L, %L, %L, %L, %L) RETURNING %L', gid, yp, y, 'player', 'active', 'inserted')) FROM k804_case;
SELECT pg_temp.k804_call('d_post', NULL, format('INSERT INTO public.posts (author_profile_id, author_user_id, kind, visibility, game_id, geo_lat, geo_lng, geo_location_id, area_id) VALUES (%L, %L, %L, %L, %L, 0, 0, %L, %L) RETURNING geo_location_id::text', yp, y, 'original', 'public', gid, l1, (SELECT area_id FROM public.geo_locations WHERE id = l1))) FROM k804_case, k804_geo;
SELECT pg_temp.k804_call('e_client_roster', y, format('INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (%L, %L, %L, %L, %L) RETURNING %L', gid, yp, y, 'player', 'active', 'inserted')) FROM k804_case;
SELECT pg_temp.k804_call('f_client_post', y, format('INSERT INTO public.posts (author_profile_id, author_user_id, kind, visibility, game_id, geo_lat, geo_lng, geo_location_id, area_id) VALUES (%L, %L, %L, %L, %L, 0, 0, %L, %L) RETURNING geo_location_id::text', yp, y, 'original', 'public', gid, l1, (SELECT area_id FROM public.geo_locations WHERE id = l1))) FROM k804_case, k804_geo;

INSERT INTO k804_tap SELECT 2, v = 'inserted', 'before divergence: roster insert passes the guard (probe can fail)', v FROM k804_out WHERE k = 'a_pre_roster';
INSERT INTO k804_tap SELECT 3, o.v = g.l1::text, 'before divergence: game-tied post takes G''s geo L1, not the supplied L2 (probe can fail)', o.v
  FROM k804_out o, k804_geo g WHERE o.k = 'b_pre_post';
INSERT INTO k804_tap SELECT 4, e.creator_user_id = c.z AND e.geo_location_id = gg.l2 AND public.is_frozen(c.z)
  AND (to_jsonb(g) ->> 'creator_user_id') IS DISTINCT FROM c.z::text AND (to_jsonb(g) ->> 'geo_location_id') IS DISTINCT FROM gg.l2::text,
  'control: events says frozen host Z and geo L2, games does not', e.geo_location_id::text
  FROM k804_case c JOIN public.events e ON e.id = c.eid JOIN public.games g ON g.id = c.gid, k804_geo gg;
INSERT INTO k804_tap SELECT 5, v = 'ERR P0001 user_frozen', 'events host frozen: roster insert -> user_frozen', v FROM k804_out WHERE k = 'c_roster';
INSERT INTO k804_tap SELECT 6, o.v = g.l2::text, 'events geo L2: game-tied post takes L2 from events', o.v
  FROM k804_out o, k804_geo g WHERE o.k = 'd_post';
INSERT INTO k804_tap SELECT 7, v LIKE 'ERR %' AND v NOT LIKE '%kan804_game_event_facts%' AND v NOT LIKE 'ERR 42501 permission denied for function%',
  'client roster insert (games invisible) is refused without reaching the helper', v FROM k804_out WHERE k = 'e_client_roster';
INSERT INTO k804_tap SELECT 8, coalesce(v, '') NOT LIKE '%kan804_game_event_facts%' AND coalesce(v, '') NOT LIKE 'ERR 42501 permission denied for function%',
  'client game-tied post (games invisible) never reaches the helper', v FROM k804_out WHERE k = 'f_client_post';
INSERT INTO k804_tap SELECT 9,
  proowner = 'postgres'::regrole AND prosecdef AND provolatile = 's' AND proconfig::text = '{"search_path=public, pg_temp"}'
  AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND NOT has_function_privilege('anon', oid, 'EXECUTE') AND NOT has_function_privilege('authenticated', oid, 'EXECUTE')
  AND has_function_privilege('service_role', oid, 'EXECUTE'),
  'helper kan804_game_event_facts: postgres, DEFINER, STABLE, search_path, EXECUTE service_role only', proacl::text
  FROM pg_proc WHERE oid = 'public.kan804_game_event_facts(uuid)'::regprocedure;
INSERT INTO k804_tap SELECT 10, count(*) FILTER (WHERE who = 'authenticated') = 2,
  'the client-path probes ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k804_out;
INSERT INTO k804_tap SELECT 11,
  md5(prosrc) = '2429035e07db8daa686fe873e204d183' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 'v'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.trgfn_roster_block_frozen_guard(): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.trgfn_roster_block_frozen_guard()'::regprocedure;
INSERT INTO k804_tap SELECT 12,
  md5(prosrc) = '0c8944fe8e54448f7dc76f7def862f74' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 'v'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.trgfn_posts_set_geo(): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.trgfn_posts_set_geo()'::regprocedure;
INSERT INTO k804_tap SELECT 13, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.creator_user_id, g.geo_location_id, g.area_id)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.creator_user_id', 'g.geo_location_id', 'g.area_id']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.trgfn_roster_block_frozen_guard()'::regprocedure, 'public.trgfn_posts_set_geo()'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k804_tap) t
ORDER BY n;
ROLLBACK;
