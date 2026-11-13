-- KAN-862 P1 live proof for supabase/migrations/20261113144858_kan808_p1_rebased_join_recheck_cancelled.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-808: rpc_join_game takes the games row lock before both branches and then re-checks events.is_cancelled.
-- METHOD: X joins G as authenticated (open -> joined; events join_policy 'request' -> request_submitted, the branch
-- that took no games lock before); then events of G is cancelled and the join is refused 'cancelled'. The concurrent
-- cancel-vs-join race itself needs two sessions; probe 4 proves the lock precedes the request branch in the source.
-- Probe 4 is RED on the pre-image (its FOR UPDATE came after the request branch).
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k808_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k808_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k808_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
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
    RAISE EXCEPTION 'k808_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k808_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k808_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k808_case ON COMMIT DROP AS
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

INSERT INTO k808_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k808_case;

SELECT pg_temp.k808_call('a_open_x', x, format('SELECT j.result FROM public.rpc_join_game(%L, %L::uuid, NULL) j', 'player', gid)) FROM k808_case;
UPDATE public.events SET join_policy = 'request' WHERE id = (SELECT eid FROM k808_case);
SELECT pg_temp.k808_call('b_request_x', x, format('SELECT j.result FROM public.rpc_join_game(%L, %L::uuid, NULL) j', 'player', gid)) FROM k808_case;
UPDATE public.events SET join_policy = 'open', is_cancelled = true WHERE id = (SELECT eid FROM k808_case);
SELECT pg_temp.k808_call('c_cancelled_x', x, format('SELECT j.result FROM public.rpc_join_game(%L, %L::uuid, NULL) j', 'player', gid)) FROM k808_case;

INSERT INTO k808_tap SELECT 2, v = 'joined', 'open game: rpc_join_game -> joined (path executes)', v FROM k808_out WHERE k = 'a_open_x';
INSERT INTO k808_tap SELECT 3, v = 'request_submitted', 'request policy: rpc_join_game -> request_submitted (through the new lock)', v FROM k808_out WHERE k = 'b_request_x';
INSERT INTO k808_tap SELECT 4,
  position('FOR UPDATE' IN prosrc) > 0 AND position('FOR UPDATE' IN prosrc) < position('INSERT INTO public.game_join_requests' IN prosrc)
  AND position('e.is_cancelled' IN prosrc) BETWEEN position('FOR UPDATE' IN prosrc) AND position('INSERT INTO public.game_join_requests' IN prosrc),
  'source: games FOR UPDATE and the events cancel re-check precede the request branch',
  position('FOR UPDATE' IN prosrc) || '<' || position('INSERT INTO public.game_join_requests' IN prosrc)
  FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
INSERT INTO k808_tap SELECT 5, v = 'ERR P0001 cancelled', 'events cancelled: rpc_join_game -> P0001 cancelled', v FROM k808_out WHERE k = 'c_cancelled_x';
INSERT INTO k808_tap SELECT 6, count(*) FILTER (WHERE who = 'authenticated') = 3,
  'the client-path probes ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k808_out;
INSERT INTO k808_tap SELECT 7,
  md5(prosrc) = '639151365d83933d1fce0de84d282990' AND proowner = 'postgres'::regrole AND prosecdef = true AND provolatile = 'v'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.rpc_join_game(text,uuid,uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
INSERT INTO k808_tap SELECT 8, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.is_cancelled, g.creator_user_id)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.is_cancelled', 'g.creator_user_id']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.rpc_join_game(text,uuid,uuid)'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k808_tap) t
ORDER BY n;
ROLLBACK;
