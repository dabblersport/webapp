-- KAN-862 P1 live proof for supabase/migrations/20261113145408_kan803_p1_rebased_frozen_guards_a.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-803: the invite, join-request and waitlist frozen guards take the host from kan803_game_host_uid (events).
-- METHOD: user Z is frozen (user_freezes row) and made G's host in events only (games keeps unfrozen H). Each guarded
-- insert, as postgres, succeeds BEFORE the divergence (probes 2-4: the probe can fail) and raises user_frozen after it.
-- A games reader would still see H and let every insert through.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k803_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k803_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k803_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
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
    RAISE EXCEPTION 'k803_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k803_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k803_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k803_case ON COMMIT DROP AS
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

INSERT INTO k803_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k803_case;

SELECT pg_temp.k803_call('a_pre_invite', NULL, format('INSERT INTO public.game_invites (game_id, to_user_id, status) VALUES (%L, %L, %L) RETURNING %L', gid, y, 'pending', 'inserted')) FROM k803_case;
SELECT pg_temp.k803_call('b_pre_joinreq', NULL, format('INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (%L, %L, %L, %L) RETURNING %L', gid, yp, y, 'pending', 'inserted')) FROM k803_case;
SELECT pg_temp.k803_call('c_pre_waitlist', NULL, format('INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (%L, %L, %L, 999) RETURNING %L', gid, yp, y, 'inserted')) FROM k803_case;

INSERT INTO public.user_freezes (user_id, is_frozen, is_active, reason, created_by) SELECT z, true, true, 'KAN-862 P1 probe (rolled back)', x FROM k803_case;
UPDATE public.events SET creator_user_id = (SELECT z FROM k803_case) WHERE id = (SELECT eid FROM k803_case);

SELECT pg_temp.k803_call('d_invite', NULL, format('INSERT INTO public.game_invites (game_id, to_user_id, status) VALUES (%L, %L, %L) RETURNING %L', gid, y, 'pending', 'inserted')) FROM k803_case;
SELECT pg_temp.k803_call('e_joinreq', NULL, format('INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (%L, %L, %L, %L) RETURNING %L', gid, yp, y, 'pending', 'inserted')) FROM k803_case;
SELECT pg_temp.k803_call('f_waitlist', NULL, format('INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (%L, %L, %L, 999) RETURNING %L', gid, yp, y, 'inserted')) FROM k803_case;

INSERT INTO k803_tap SELECT 2, v = 'inserted', 'before divergence: invite insert passes the guard (probe can fail)', v FROM k803_out WHERE k = 'a_pre_invite';
INSERT INTO k803_tap SELECT 3, v = 'inserted', 'before divergence: join-request insert passes the guard (probe can fail)', v FROM k803_out WHERE k = 'b_pre_joinreq';
INSERT INTO k803_tap SELECT 4, v = 'inserted', 'before divergence: waitlist insert passes the guard (probe can fail)', v FROM k803_out WHERE k = 'c_pre_waitlist';
INSERT INTO k803_tap SELECT 5, public.is_frozen(c.z) AND NOT public.is_frozen(c.host)
  AND public.kan803_game_host_uid(c.gid) = c.z AND (to_jsonb(g) ->> 'creator_user_id') IS DISTINCT FROM c.z::text,
  'control: Z frozen, H not; helper answers Z (events), games does not', public.kan803_game_host_uid(c.gid)::text
  FROM k803_case c JOIN public.games g ON g.id = c.gid;
INSERT INTO k803_tap SELECT 6, v = 'ERR P0001 user_frozen', 'events host frozen: invite insert -> user_frozen', v FROM k803_out WHERE k = 'd_invite';
INSERT INTO k803_tap SELECT 7, v = 'ERR P0001 user_frozen', 'events host frozen: join-request insert -> user_frozen', v FROM k803_out WHERE k = 'e_joinreq';
INSERT INTO k803_tap SELECT 8, v = 'ERR P0001 user_frozen', 'events host frozen: waitlist insert -> user_frozen', v FROM k803_out WHERE k = 'f_waitlist';
INSERT INTO k803_tap SELECT 9,
  proowner = 'postgres'::regrole AND prosecdef AND provolatile = 's' AND proconfig::text = '{"search_path=public, pg_temp"}'
  AND proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND NOT has_function_privilege('anon', oid, 'EXECUTE') AND has_function_privilege('authenticated', oid, 'EXECUTE')
  AND has_function_privilege('service_role', oid, 'EXECUTE'),
  'helper kan803_game_host_uid: postgres, DEFINER, STABLE, search_path, EXECUTE authenticated+service_role only', proacl::text
  FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure;
INSERT INTO k803_tap SELECT 10,
  md5(prosrc) = '81e302c646fd39c0c809009d4debc382' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 'v'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.trgfn_invite_block_frozen_guard(): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.trgfn_invite_block_frozen_guard()'::regprocedure;
INSERT INTO k803_tap SELECT 11,
  md5(prosrc) = 'a883c3cb708111f5e52f441e3c9e26d3' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 'v'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.trgfn_joinreq_block_frozen_guard(): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure;
INSERT INTO k803_tap SELECT 12,
  md5(prosrc) = '03296c42de73e93b4b5eefba9583e2ba' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 'v'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.trgfn_waitlist_block_frozen_guard(): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure;
INSERT INTO k803_tap SELECT 13, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.creator_user_id)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.creator_user_id']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure, 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k803_tap) t
ORDER BY n;
ROLLBACK;
