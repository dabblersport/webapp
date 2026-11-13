-- KAN-862 P1 live proof for supabase/migrations/20261113144944_kan798_p1_rebased_join_invite.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-798: rpc_decide_join_request, rpc_invite_user and rpc_mint_join_link take the host from events.creator_user_id.
-- METHOD: events.creator_user_id of G is set to X while games keeps H (divergence). A body that reads the host from
-- events must now treat X as host and refuse H; one that reads games does the opposite. Probes 1-2 run BEFORE the
-- divergence and show the same probe refusing X (the probe can fail); the control shows games still says H.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k798_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k798_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k798_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
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
    RAISE EXCEPTION 'k798_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k798_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k798_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k798_case ON COMMIT DROP AS
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

INSERT INTO k798_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k798_case;

SELECT pg_temp.k798_call('a_pre_mint_x', x, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', gid)) FROM k798_case;
SELECT pg_temp.k798_call('b_pre_invite_x', x, format('SELECT public.rpc_invite_user(%L::uuid, %L::uuid)::text', gid, y)) FROM k798_case;

UPDATE public.events SET creator_user_id = (SELECT x FROM k798_case) WHERE id = (SELECT eid FROM k798_case);
INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status)
  SELECT gid, yp, y, 'pending' FROM k798_case;
CREATE TEMP TABLE k798_req ON COMMIT DROP AS
  SELECT q.id FROM public.game_join_requests q, k798_case c WHERE q.game_id = c.gid AND q.from_user_id = c.y AND q.status = 'pending';

SELECT pg_temp.k798_call('c_mint_x', x, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', gid)) FROM k798_case;
SELECT pg_temp.k798_call('d_mint_h', host, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', gid)) FROM k798_case;
SELECT pg_temp.k798_call('e_invite_x', x, format('SELECT public.rpc_invite_user(%L::uuid, %L::uuid)::text', gid, y)) FROM k798_case;
SELECT pg_temp.k798_call('f_invite_h', host, format('SELECT public.rpc_invite_user(%L::uuid, %L::uuid)::text', gid, y)) FROM k798_case;
SELECT pg_temp.k798_call('g_decide_h', host, format('SELECT public.rpc_decide_join_request(%L::uuid, false)', r.id)) FROM k798_case, k798_req r;
SELECT pg_temp.k798_call('h_decide_x', x, format('SELECT public.rpc_decide_join_request(%L::uuid, false)', r.id)) FROM k798_case, k798_req r;

INSERT INTO k798_tap SELECT 2, v = 'ERR P0001 not_host', 'before divergence: X mint -> not_host (probe can fail)', v FROM k798_out WHERE k = 'a_pre_mint_x';
INSERT INTO k798_tap SELECT 3, v = 'ERR P0001 not_host', 'before divergence: X invite -> not_host (probe can fail)', v FROM k798_out WHERE k = 'b_pre_invite_x';
INSERT INTO k798_tap SELECT 4, (SELECT creator_user_id FROM public.events WHERE id = c.eid) = c.x
  AND (to_jsonb(g) ->> 'creator_user_id') IS DISTINCT FROM c.x::text,
  'control: events says host X, games does not (a games reader refuses X)', to_jsonb(g) ->> 'creator_user_id'
  FROM k798_case c JOIN public.games g ON g.id = c.gid;
INSERT INTO k798_tap SELECT 5, v ~ '^[0-9a-f-]{36}$', 'events host X: rpc_mint_join_link -> token', v FROM k798_out WHERE k = 'c_mint_x';
INSERT INTO k798_tap SELECT 6, v = 'ERR P0001 not_host', 'games host H: rpc_mint_join_link -> not_host', v FROM k798_out WHERE k = 'd_mint_h';
INSERT INTO k798_tap SELECT 7, v ~ '^[0-9a-f-]{36}$', 'events host X: rpc_invite_user -> invite id', v FROM k798_out WHERE k = 'e_invite_x';
INSERT INTO k798_tap SELECT 8, v = 'ERR P0001 not_host', 'games host H: rpc_invite_user -> not_host', v FROM k798_out WHERE k = 'f_invite_h';
INSERT INTO k798_tap SELECT 9, v = 'ERR P0001 not_host', 'games host H: rpc_decide_join_request -> not_host', v FROM k798_out WHERE k = 'g_decide_h';
INSERT INTO k798_tap SELECT 10, v = 'denied', 'events host X: rpc_decide_join_request(deny) -> denied', v FROM k798_out WHERE k = 'h_decide_x';
INSERT INTO k798_tap SELECT 11, count(*) FILTER (WHERE who = 'authenticated') = 8,
  'the client-path probes ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k798_out;
INSERT INTO k798_tap SELECT 12,
  md5(prosrc) = '2fcf8e73dedc9917abce87d4b5ac30e6' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_decide_join_request(uuid,boolean): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_decide_join_request(uuid,boolean)'::regprocedure;
INSERT INTO k798_tap SELECT 13,
  md5(prosrc) = '265a120631a1ea3885d7c4f2f2527c32' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_invite_user(uuid,uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_invite_user(uuid,uuid)'::regprocedure;
INSERT INTO k798_tap SELECT 14,
  md5(prosrc) = 'd6f6d1f5ea0e1205432378795ea5b369' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_mint_join_link(uuid,timestamp with time zone,integer): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_mint_join_link(uuid,timestamp with time zone,integer)'::regprocedure;
INSERT INTO k798_tap SELECT 15, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.creator_user_id, jr.*, g.)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.creator_user_id', 'jr.*, g.']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.rpc_decide_join_request(uuid,boolean)'::regprocedure, 'public.rpc_invite_user(uuid,uuid)'::regprocedure, 'public.rpc_mint_join_link(uuid,timestamp with time zone,integer)'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k798_tap) t
ORDER BY n;
ROLLBACK;
