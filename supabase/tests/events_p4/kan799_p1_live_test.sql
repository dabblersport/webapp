-- KAN-862 P1 live proof for supabase/migrations/20261113145326_kan799_p1_rebased_remove_recreate.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-799: rpc_recreate_from_game reads the host and the copied fields from events; rpc_remove_player reads the host and
-- is_cancelled from events. METHOD: events of G gets creator_user_id X, a probe title and capacity + 3 while games keeps
-- H and its own values. Probes 1-2 run BEFORE the divergence and refuse X (the probe can fail). Y is put on G's roster.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k799_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k799_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k799_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
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
    RAISE EXCEPTION 'k799_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k799_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k799_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k799_case ON COMMIT DROP AS
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

INSERT INTO k799_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k799_case;

INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) SELECT gid, yp, y, 'player', 'active' FROM k799_case;

SELECT pg_temp.k799_call('a_pre_recreate_x', x, format('SELECT public.rpc_recreate_from_game(%L::uuid, false)::text', gid)) FROM k799_case;
SELECT pg_temp.k799_call('b_pre_remove_x', x, format('SELECT public.rpc_remove_player(%L::uuid, %L::uuid)', gid, yp)) FROM k799_case;

UPDATE public.events SET creator_user_id = (SELECT x FROM k799_case), title = 'k799 probe title', capacity = capacity + 3
 WHERE id = (SELECT eid FROM k799_case);

SELECT pg_temp.k799_call('c_recreate_x', x, format('SELECT public.rpc_recreate_from_game(%L::uuid, false)::text', gid)) FROM k799_case;
SELECT pg_temp.k799_call('d_recreate_h', host, format('SELECT public.rpc_recreate_from_game(%L::uuid, false)::text', gid)) FROM k799_case;
-- The draft row is read in a second statement (its own snapshot), inside the same undone subtransaction.
CREATE FUNCTION pg_temp.k799_payload(p_gid uuid) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE d uuid; r text;
BEGIN
  d := public.rpc_recreate_from_game(p_gid, false);
  SELECT payload::text INTO r FROM public.content_drafts WHERE id = d;
  RETURN r;
END $f$;
SELECT pg_temp.k799_call('e_payload_x', x, format('SELECT pg_temp.k799_payload(%L::uuid)', gid), 'postgres') FROM k799_case;
SELECT pg_temp.k799_call('f_remove_h', host, format('SELECT public.rpc_remove_player(%L::uuid, %L::uuid)', gid, yp)) FROM k799_case;
SELECT pg_temp.k799_call('g_remove_x', x, format('SELECT public.rpc_remove_player(%L::uuid, %L::uuid)', gid, yp)) FROM k799_case;
UPDATE public.events SET is_cancelled = true WHERE id = (SELECT eid FROM k799_case);
SELECT pg_temp.k799_call('h_remove_x_cancelled', x, format('SELECT public.rpc_remove_player(%L::uuid, %L::uuid)', gid, yp)) FROM k799_case;

INSERT INTO k799_tap SELECT 2, v = 'ERR P0001 not_authorized', 'before divergence: X recreate -> not_authorized (probe can fail)', v FROM k799_out WHERE k = 'a_pre_recreate_x';
INSERT INTO k799_tap SELECT 3, v = 'ERR P0001 not_host', 'before divergence: X remove -> not_host (probe can fail)', v FROM k799_out WHERE k = 'b_pre_remove_x';
INSERT INTO k799_tap SELECT 4, (to_jsonb(g) ->> 'creator_user_id') IS DISTINCT FROM c.x::text
  AND (to_jsonb(g) ->> 'title') IS DISTINCT FROM 'k799 probe title',
  'control: games keeps H and its own title (a games reader refuses X and copies the games title)', to_jsonb(g) ->> 'title'
  FROM k799_case c JOIN public.games g ON g.id = c.gid;
INSERT INTO k799_tap SELECT 5, v ~ '^[0-9a-f-]{36}$', 'events host X: rpc_recreate_from_game -> draft id', v FROM k799_out WHERE k = 'c_recreate_x';
INSERT INTO k799_tap SELECT 6, v = 'ERR P0001 not_authorized', 'games host H: rpc_recreate_from_game -> not_authorized', v FROM k799_out WHERE k = 'd_recreate_h';
INSERT INTO k799_tap SELECT 7, coalesce(o.v::jsonb ->> 'title' = 'k799 probe title'
  AND (o.v::jsonb ->> 'capacity')::int = e.capacity AND (o.v::jsonb ->> 'start_at')::timestamptz = e.start_at
  AND (o.v::jsonb ->> 'join_policy') = e.join_policy::text AND (o.v::jsonb ->> 'listing_visibility') = e.listing_visibility::text, false),
  'draft payload copies title, capacity, start_at, join_policy, listing_visibility from events', o.v
  FROM k799_out o, k799_case c JOIN public.events e ON e.id = c.eid WHERE o.k = 'e_payload_x';
INSERT INTO k799_tap SELECT 8, v = 'ERR P0001 not_host', 'games host H: rpc_remove_player -> not_host', v FROM k799_out WHERE k = 'f_remove_h';
INSERT INTO k799_tap SELECT 9, v IN ('removed', 'removed_promoted_waitlist'), 'events host X: rpc_remove_player -> removed', v FROM k799_out WHERE k = 'g_remove_x';
INSERT INTO k799_tap SELECT 10, v = 'ERR P0001 game_not_found', 'events cancelled (games not): rpc_remove_player -> game_not_found', v FROM k799_out WHERE k = 'h_remove_x_cancelled';
INSERT INTO k799_tap SELECT 11, count(*) FILTER (WHERE who = 'authenticated') = 7,
  'the client-path probes ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k799_out;
INSERT INTO k799_tap SELECT 12,
  md5(prosrc) = '1ff1447738e359d097002ac3ea5d2099' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_recreate_from_game(uuid,boolean): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure;
INSERT INTO k799_tap SELECT 13,
  md5(prosrc) = 'ff739900a0cfc72e482e8f4c8543fbb0' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_remove_player(uuid,uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_remove_player(uuid,uuid)'::regprocedure;
INSERT INTO k799_tap SELECT 14, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.creator_user_id, g.is_cancelled, gm.sport_id, gm.start_at, gm.title, gm.capacity, gm.join_policy, gg.creator_user_id)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.creator_user_id', 'g.is_cancelled', 'gm.sport_id', 'gm.start_at', 'gm.title', 'gm.capacity', 'gm.join_policy', 'gg.creator_user_id']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.rpc_recreate_from_game(uuid,boolean)'::regprocedure, 'public.rpc_remove_player(uuid,uuid)'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k799_tap) t
ORDER BY n;
ROLLBACK;
