-- KAN-717 F2 live proof for supabase/migrations/20261113110100_kan717_f2_rpc_leave_game.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Nothing persists: the seeded waitlist rows and every call's effects are undone.
--
-- DEFECT (KAN-766 comment 15476, F2): rpc_leave_game tests IF NOT was_active after UPDATE ... RETURNING true INTO
-- was_active. With no active roster row the variable stays NULL, the guard is skipped, and the caller promotes the
-- head of the waitlist while being told 'left_promoted_waitlist'.
--
-- METHOD. One future, uncancelled game G with an active roster member L. Three more player users not on G's roster:
-- W1 and W2 are seeded on G's waitlist (positions 1, 2) as postgres, N is not on the roster or the waitlist. Each user
-- has exactly one profile (so choose_actor('player') resolves to it), and none is frozen. Every call runs as
-- SET LOCAL ROLE authenticated with request.jwt.claims {sub, role}, in its own subtransaction that is always undone;
-- the state is read back as postgres inside that subtransaction, before the undo. A is G's active roster count.
--   T1 N (not on roster)       -> 'not_on_roster', state unchanged: active=A wl=W1,W2 w1=none l=active   (RED before)
--   T2 L (real leaver)         -> 'left_promoted_waitlist': active=A wl=W2 w1=active l=left      (GREEN before and after)
--   T3 L, waitlist emptied     -> 'left': active=A-1 wl= w1=none l=left                           (GREEN before and after)
--   T4 every call really ran as role authenticated
--   T5 attributes unchanged: owner postgres, SECURITY DEFINER, VOLATILE, search_path=public, ACL as recorded
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k717f2_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k717f2_out (k text PRIMARY KEY, who text, v text, state text) ON COMMIT DROP;

CREATE TEMP TABLE k717f2_case ON COMMIT DROP AS
WITH single AS (
  SELECT p.id AS pid, p.user_id AS uid, p.created_at
    FROM public.profiles p
   WHERE p.is_active AND p.persona_type = 'player' AND p.user_id IS NOT NULL
     AND NOT public.is_frozen(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.user_id = p.user_id AND p2.id <> p.id)),
g AS (
  SELECT g.id AS gid, r.profile_id AS l_pid, s.uid AS l_uid
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.game_roster r ON r.game_id = g.id AND r.status = 'active'
    JOIN single s ON s.pid = r.profile_id
   WHERE g.start_at > now() + interval '1 day' AND NOT g.is_cancelled AND NOT e.is_cancelled
     AND NOT EXISTS (SELECT 1 FROM public.game_waitlist w WHERE w.game_id = g.id)
   ORDER BY g.start_at, g.id, r.profile_id LIMIT 1),
o AS (
  SELECT s.pid, s.uid, row_number() OVER (ORDER BY s.created_at, s.pid) AS rn
    FROM single s, g
   WHERE NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.gid AND (r.profile_id = s.pid OR r.user_id = s.uid)))
SELECT g.gid, g.l_pid, g.l_uid,
       (SELECT pid FROM o WHERE rn = 1) AS w1_pid, (SELECT pid FROM o WHERE rn = 2) AS w2_pid,
       (SELECT uid FROM o WHERE rn = 3) AS n_uid,
       (SELECT count(*) FROM public.game_roster r WHERE r.game_id = g.gid AND r.status = 'active') AS a
  FROM g;

INSERT INTO public.game_waitlist (game_id, profile_id, position)
SELECT gid, w1_pid, 1 FROM k717f2_case UNION ALL SELECT gid, w2_pid, 2 FROM k717f2_case;

CREATE FUNCTION pg_temp.k717f2_state() RETURNS text LANGUAGE sql AS $s$
  SELECT format('active=%s wl=%s w1=%s l=%s',
    (SELECT count(*) FROM public.game_roster r WHERE r.game_id = c.gid AND r.status = 'active'),
    coalesce((SELECT string_agg(CASE w.profile_id WHEN c.w1_pid THEN 'W1' WHEN c.w2_pid THEN 'W2' ELSE '?' END, ',' ORDER BY w.position)
                FROM public.game_waitlist w WHERE w.game_id = c.gid), ''),
    coalesce((SELECT r.status FROM public.game_roster r WHERE r.game_id = c.gid AND r.profile_id = c.w1_pid), 'none'),
    coalesce((SELECT r.status FROM public.game_roster r WHERE r.game_id = c.gid AND r.profile_id = c.l_pid), 'none'))
  FROM pg_temp.k717f2_case c
$s$;

CREATE FUNCTION pg_temp.k717f2_call(p_key text, p_uid uuid, p_gid uuid, p_empty_waitlist boolean DEFAULT false) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE r text; who text; st text;
BEGIN
  BEGIN
    IF p_empty_waitlist THEN DELETE FROM public.game_waitlist WHERE game_id = p_gid; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('role', 'authenticated', true);
    who := current_user;
    r := public.rpc_leave_game('player', p_gid);
    PERFORM set_config('role', 'none', true);     -- read the state back as postgres
    st := pg_temp.k717f2_state();
    RAISE EXCEPTION 'k717f2_undo';
  EXCEPTION WHEN OTHERS THEN                      -- the subtransaction rollback undoes the call and reverts the role
    IF SQLERRM <> 'k717f2_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k717f2_out VALUES (p_key, who, r, st);
END $f$;

SELECT pg_temp.k717f2_call('t1_non_roster', n_uid, gid) FROM k717f2_case;
SELECT pg_temp.k717f2_call('t2_leaver', l_uid, gid) FROM k717f2_case;
SELECT pg_temp.k717f2_call('t3_leaver_empty_wl', l_uid, gid, true) FROM k717f2_case;

INSERT INTO k717f2_tap SELECT 1, o.v = 'not_on_roster' AND o.state = format('active=%s wl=W1,W2 w1=none l=active', c.a),
  'non-roster caller -> not_on_roster, roster and waitlist unchanged', o.v || ' | ' || coalesce(o.state, '')
  FROM k717f2_out o, k717f2_case c WHERE o.k = 't1_non_roster';
INSERT INTO k717f2_tap SELECT 2, o.v = 'left_promoted_waitlist' AND o.state = format('active=%s wl=W2 w1=active l=left', c.a),
  'real leaver -> left_promoted_waitlist, exactly the head (W1) promoted', o.v || ' | ' || coalesce(o.state, '')
  FROM k717f2_out o, k717f2_case c WHERE o.k = 't2_leaver';
INSERT INTO k717f2_tap SELECT 3, o.v = 'left' AND o.state = format('active=%s wl= w1=none l=left', c.a - 1),
  'real leaver, empty waitlist -> left', o.v || ' | ' || coalesce(o.state, '')
  FROM k717f2_out o, k717f2_case c WHERE o.k = 't3_leaver_empty_wl';
INSERT INTO k717f2_tap SELECT 4, count(*) = 3 AND bool_and(who = 'authenticated'),
  'every call ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k) FROM k717f2_out;
INSERT INTO k717f2_tap SELECT 5,
  proowner = 'postgres'::regrole AND prosecdef AND provolatile = 'v' AND proconfig = '{search_path=public}'
  AND proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}',
  'attributes and ACL unchanged', 'md5(prosrc) ' || md5(prosrc) || ' ' || proacl::text
  FROM pg_proc WHERE oid = 'public.rpc_leave_game(text,uuid)'::regprocedure;

SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
  FROM k717f2_tap ORDER BY n;
ROLLBACK;
