-- KAN-717 F1 live proof for supabase/migrations/20261113110000_kan717_f1_can_current_user_join_game.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Nothing persists: the policy flip and the invite row are undone by the final ROLLBACK.
--
-- DEFECT (KAN-766 comment 15476, F1): the 'invite' arm of public.can_current_user_join_game reads
-- game_invites.to_profile_id, a column that does not exist (game_invites: id, game_id, to_user_id NOT NULL,
-- invited_by_profile_id, status, created_at, responded_at; rpc_invite_user writes to_user_id only). Every join check on an
-- invite-policy game raises 42703.
--
-- METHOD. One future, uncancelled, public, open game G with a free slot is flipped to join_policy 'invite' as postgres
-- (the KAN-712 guard mirrors it to events; events is also set directly in case the guard is gone). Two player users
-- who are not on G's roster, not its creator, not admin and not frozen: V1 gets a pending invite to G, V2 none.
-- Every call runs as SET LOCAL ROLE authenticated with request.jwt.claims {sub, role}, in its own subtransaction that
-- is always undone (so a successful join leaves no row behind).
-- The production path is public.rpc_join_game (SECURITY DEFINER), the only caller of can_current_user_join_game (no
-- client calls it). A direct call as authenticated cannot reach the policy arms: the function is SECURITY INVOKER and
-- public.games has RLS enabled with no policy, so it returns reason 'not_found' for every game (recorded as '# note').
--   T1 sanity: the path executes. With join_policy 'open', V1 -> rpc_join_game 'joined'      (GREEN before and after)
--   T2 V1 (pending invite) on the invite game -> 'joined'                                     (RED before: ERR 42703)
--   T3 V2 (no invite) on the invite game      -> ERR P0001 invite_only                        (RED before: ERR 42703)
--   T4 V1 with the invite no longer pending   -> ERR P0001 invite_only                        (RED before: ERR 42703)
--   T5 every call really ran as role authenticated
--   T6 the live source no longer names to_profile_id                                          (RED before)
--   T7 attributes unchanged: owner postgres, SECURITY INVOKER, STABLE, search_path=public, ACL as recorded
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k717f1_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k717f1_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.k717f1_call(p_key text, p_uid uuid, p_gid uuid, p_direct boolean DEFAULT false) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE r text; who text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('role', 'authenticated', true);
    who := current_user;
    IF p_direct THEN
      r := public.can_current_user_join_game(p_gid, 'player', NULL)::text;
    ELSE
      SELECT j.result INTO r FROM public.rpc_join_game('player', p_gid, NULL) j;
    END IF;
    RAISE EXCEPTION 'k717f1_undo';
  EXCEPTION WHEN OTHERS THEN                    -- the subtransaction rollback undoes the join and reverts the role
    IF SQLERRM <> 'k717f1_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k717f1_out VALUES (p_key, who, r);
END $f$;

CREATE TEMP TABLE k717f1_case ON COMMIT DROP AS
WITH g AS (
  SELECT g.id, g.creator_user_id FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.start_at > now() + interval '1 day' AND NOT g.is_cancelled AND NOT e.is_cancelled
     AND g.join_policy = 'open' AND e.join_policy = 'open' AND g.squad_id IS NULL
     AND g.listing_visibility = 'public' AND e.listing_visibility = 'public'
     AND public.game_slots_left(g.id) > 0
   ORDER BY g.start_at, g.id LIMIT 1),
v AS (
  SELECT p.user_id AS uid, row_number() OVER (ORDER BY p.created_at, p.id) AS rn
    FROM public.profiles p, g
   WHERE p.is_active AND p.persona_type = 'player' AND p.user_id IS NOT NULL
     AND p.user_id IS DISTINCT FROM g.creator_user_id
     AND NOT public.is_admin(p.user_id) AND NOT public.is_frozen(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id AND (r.user_id = p.user_id OR r.profile_id = p.id))
     AND NOT EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.user_id = p.user_id AND p2.id <> p.id)
     AND public.can_view_with_scope(p.user_id, g.creator_user_id, 'public', NULL))
SELECT g.id AS gid, (SELECT uid FROM v WHERE rn = 1) AS v1, (SELECT uid FROM v WHERE rn = 2) AS v2 FROM g;

-- T1 (policy still 'open')
SELECT pg_temp.k717f1_call('t1_open_v1', v1, gid) FROM k717f1_case;

-- Flip G to invite; invite V1.
UPDATE public.games SET join_policy = 'invite' WHERE id = (SELECT gid FROM k717f1_case);
UPDATE public.events SET join_policy = 'invite' WHERE id = (SELECT gid FROM k717f1_case) AND join_policy <> 'invite';
INSERT INTO public.game_invites (game_id, to_user_id, status) SELECT gid, v1, 'pending' FROM k717f1_case;

SELECT pg_temp.k717f1_call('t2_invited_v1', v1, gid) FROM k717f1_case;
SELECT pg_temp.k717f1_call('note_direct_v1', v1, gid, true) FROM k717f1_case;
SELECT pg_temp.k717f1_call('t3_uninvited_v2', v2, gid) FROM k717f1_case;
UPDATE public.game_invites SET status = 'declined', responded_at = now() WHERE game_id = (SELECT gid FROM k717f1_case);
SELECT pg_temp.k717f1_call('t4_declined_v1', v1, gid) FROM k717f1_case;

INSERT INTO k717f1_tap SELECT 1, v = 'joined',
  'sanity: open policy, V1 -> joined (path executes)', v FROM k717f1_out WHERE k = 't1_open_v1';
INSERT INTO k717f1_tap SELECT 2, v = 'joined',
  'invite policy, pending invite -> joined', v FROM k717f1_out WHERE k = 't2_invited_v1';
INSERT INTO k717f1_tap SELECT 3, v = 'ERR P0001 invite_only',
  'invite policy, no invite -> P0001 invite_only', v FROM k717f1_out WHERE k = 't3_uninvited_v2';
INSERT INTO k717f1_tap SELECT 4, v = 'ERR P0001 invite_only',
  'invite policy, declined invite -> P0001 invite_only', v FROM k717f1_out WHERE k = 't4_declined_v1';
INSERT INTO k717f1_tap SELECT 5, count(*) = 5 AND bool_and(who = 'authenticated'),
  'every call ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k717f1_out;
INSERT INTO k717f1_tap SELECT 6, position('to_profile_id' IN prosrc) = 0,
  'live source names no game_invites.to_profile_id', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;
INSERT INTO k717f1_tap SELECT 7,
  proowner = 'postgres'::regrole AND NOT prosecdef AND provolatile = 's' AND proconfig = '{search_path=public}'
  AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}',
  'attributes and ACL unchanged', proacl::text
  FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k717f1_tap
  UNION ALL
  SELECT 99, '# note: direct invoker call as authenticated (games RLS on, no policy): ' || v
    FROM k717f1_out WHERE k = 'note_direct_v1') t
ORDER BY n;
ROLLBACK;
