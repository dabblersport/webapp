-- KAN-862 P1 live proof for supabase/migrations/20261113145617_kan834_p1_rebased_residual_c.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- fixture write (an events divergence, a roster/join-request/freeze row) is undone by the final ROLLBACK, and every
-- probe call runs in its own subtransaction that is always undone.
--
-- KAN-834: can_current_user_join_game (rebased on KAN-717 F1), _recent_activity_score, _user_hosted_game and
-- game_is_joinable read every shared field from events.
-- METHOD: X joins G through rpc_join_game (open -> joined) BEFORE the divergence; then events join_policy of G becomes
-- 'invite' (X holds no invite) while games keeps 'open' -> P0001 invite_only (a games reader still sees 'open' and
-- joins, so probe 3 is RED on it; probe 2 shows the same probe passing a join, so it can fail). 'closed' is not a
-- value events_game_join_policy_check allows for a game. The helpers are checked as postgres
-- (events readable) against an events divergence, and as authenticated (fallback answers).
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k834_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k834_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql once, undone. p_uid set: JWT claims for p_uid; p_role 'authenticated' also switches role (else postgres).
CREATE FUNCTION pg_temp.k834_call(p_key text, p_uid uuid, p_sql text, p_role text DEFAULT 'authenticated') RETURNS void
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
    RAISE EXCEPTION 'k834_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k834_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k834_out VALUES (p_key, who, r);
END $f$;

-- Fixture: one future, uncancelled, public, open game G (read from events) with a free slot and an unfrozen host H;
-- player users X, Y, Z (single profile, not admin, not frozen, not H, not on G's roster).
CREATE TEMP TABLE k834_case ON COMMIT DROP AS
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

INSERT INTO k834_tap SELECT 1, gid IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND z IS NOT NULL,
  'fixture found (game G, users X, Y, Z)', gid::text FROM k834_case;

SELECT pg_temp.k834_call('a_pre_join_x', x, format('SELECT j.result FROM public.rpc_join_game(%L, %L::uuid, NULL) j', 'player', gid)) FROM k834_case;
SELECT pg_temp.k834_call('b_pre_joinable', NULL, format('SELECT public.game_is_joinable(%L::uuid)::text', gid)) FROM k834_case;
UPDATE public.events SET join_policy = 'invite' WHERE id = (SELECT eid FROM k834_case);
SELECT pg_temp.k834_call('c_invite_x', x, format('SELECT j.result FROM public.rpc_join_game(%L, %L::uuid, NULL) j', 'player', gid)) FROM k834_case;
SELECT pg_temp.k834_call('d_direct_x', x, format('SELECT public.can_current_user_join_game(%L::uuid, %L, NULL)->>%L', gid, 'player', 'reason')) FROM k834_case;
UPDATE public.events SET join_policy = 'open', creator_user_id = (SELECT x FROM k834_case) WHERE id = (SELECT eid FROM k834_case);
INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) SELECT gid, yp, y, 'player', 'active' FROM k834_case;
SELECT pg_temp.k834_call('e_hosted_pg', NULL, format('SELECT public._user_hosted_game(%L::uuid, %L::uuid)::text', x, gid)) FROM k834_case;
SELECT pg_temp.k834_call('f_hosted_auth', x, format('SELECT public._user_hosted_game(%L::uuid, %L::uuid)::text', x, gid)) FROM k834_case;
SELECT pg_temp.k834_call('g_score_pg', NULL, format('SELECT public._recent_activity_score(%L::uuid, 30)::text', y)) FROM k834_case;
SELECT pg_temp.k834_call('h_score_auth', y, format('SELECT public._recent_activity_score(%L::uuid, 30)::text', y)) FROM k834_case;
UPDATE public.events SET is_cancelled = true WHERE id = (SELECT eid FROM k834_case);
SELECT pg_temp.k834_call('i_joinable_pg', NULL, format('SELECT public.game_is_joinable(%L::uuid)::text', gid)) FROM k834_case;
SELECT pg_temp.k834_call('j_joinable_auth', x, format('SELECT coalesce(public.game_is_joinable(%L::uuid)::text, %L)', gid, 'null')) FROM k834_case;

INSERT INTO k834_tap SELECT 2, v = 'joined', 'before divergence: open game, rpc_join_game -> joined (probe can fail)', v FROM k834_out WHERE k = 'a_pre_join_x';
INSERT INTO k834_tap SELECT 3, v = 'ERR P0001 invite_only', 'events invite, games open, no invite: rpc_join_game -> P0001 invite_only (from events)', v FROM k834_out WHERE k = 'c_invite_x';
INSERT INTO k834_tap SELECT 4, v = 'not_found', 'direct INVOKER call as authenticated (games RLS, no policy) -> not_found, no 42501', v FROM k834_out WHERE k = 'd_direct_x';
INSERT INTO k834_tap SELECT 5, v = 'true', 'events host X: _user_hosted_game as postgres -> true', v FROM k834_out WHERE k = 'e_hosted_pg';
INSERT INTO k834_tap SELECT 6, (to_jsonb(g) ->> 'creator_user_id') IS DISTINCT FROM c.x::text,
  'control: games does not name X as host (a games reader answers false)', to_jsonb(g) ->> 'creator_user_id'
  FROM k834_case c JOIN public.games g ON g.id = c.gid;
INSERT INTO k834_tap SELECT 7, v = 'false', '_user_hosted_game as authenticated -> false (fallback)', v FROM k834_out WHERE k = 'f_hosted_auth';
INSERT INTO k834_tap SELECT 8, v = '1.0', '_recent_activity_score as postgres, Y active on G -> 1.0', v FROM k834_out WHERE k = 'g_score_pg';
INSERT INTO k834_tap SELECT 9, v = '0.0', '_recent_activity_score as authenticated -> 0.0 (fallback)', v FROM k834_out WHERE k = 'h_score_auth';
INSERT INTO k834_tap SELECT 10, b.v = 'true' AND i.v = 'false', 'game_is_joinable as postgres: true, then false once events (only) is cancelled', b.v || ' -> ' || i.v
  FROM k834_out b, k834_out i WHERE b.k = 'b_pre_joinable' AND i.k = 'i_joinable_pg';
INSERT INTO k834_tap SELECT 11, v = 'null', 'game_is_joinable as authenticated -> NULL (fallback)', v FROM k834_out WHERE k = 'j_joinable_auth';
INSERT INTO k834_tap SELECT 12, position('to_profile_id' IN prosrc) = 0 AND position('policy_mismatch' IN prosrc) = 0
  AND position('i.to_user_id = viewer) THEN   -- KAN-717 F1' IN prosrc) > 0,
  'can_current_user_join_game keeps the F1 invite arm, drops policy_mismatch', md5(prosrc)
  FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;
INSERT INTO k834_tap SELECT 13, count(*) FILTER (WHERE who = 'authenticated') = 6,
  'the client-path probes ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k834_out;
INSERT INTO k834_tap SELECT 14,
  md5(prosrc) = '085495b09a90c68d2f009ffcdc5a46d5' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 's'
  AND proconfig::text = '{search_path=public}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.can_current_user_join_game(uuid,text,uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;
INSERT INTO k834_tap SELECT 15,
  md5(prosrc) = '2202f744a38453ddb883089c274dd2e1' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 's'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public._recent_activity_score(uuid,integer): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public._recent_activity_score(uuid,integer)'::regprocedure;
INSERT INTO k834_tap SELECT 16,
  md5(prosrc) = '792f07c44f71c4dc154716a5905b0659' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 's'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public._user_hosted_game(uuid,uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public._user_hosted_game(uuid,uuid)'::regprocedure;
INSERT INTO k834_tap SELECT 17,
  md5(prosrc) = '7075cd9e1f42e083960708f11bf7d0f1' AND proowner = 'postgres'::regrole AND prosecdef = false AND provolatile = 's'
  AND proconfig::text = '{"search_path=public, pg_temp"}' AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND position('search_tsv' IN prosrc) = 0 AND position('meetups' IN prosrc) = 0,
  'public.game_is_joinable(uuid): body as applied, owner/SECURITY/volatility/search_path/ACL unchanged, no Z01 manifest name',
  md5(prosrc) || ' ' || proacl::text FROM pg_proc WHERE oid = 'public.game_is_joinable(uuid)'::regprocedure;
INSERT INTO k834_tap SELECT 18, count(*) FILTER (WHERE hit) = 0,
  'no owned body reads a moved games column (g.creator_user_id, g.listing_visibility, g.is_cancelled, g.start_at, g.join_policy)',
  coalesce(string_agg(oid::regprocedure::text, ' ') FILTER (WHERE hit), 'none')
  FROM (SELECT oid, EXISTS (SELECT 1 FROM unnest(array['g.creator_user_id', 'g.listing_visibility', 'g.is_cancelled', 'g.start_at', 'g.join_policy']) t WHERE position(t IN prosrc) > 0) AS hit
          FROM pg_proc WHERE oid IN ('public.can_current_user_join_game(uuid,text,uuid)'::regprocedure, 'public._recent_activity_score(uuid,integer)'::regprocedure, 'public._user_hosted_game(uuid,uuid)'::regprocedure, 'public.game_is_joinable(uuid)'::regprocedure)) s;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k834_tap) t
ORDER BY n;
ROLLBACK;
