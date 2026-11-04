-- KAN-803 (supporting KAN-772 / KAN-719): proof for 20261104110800_kan803_d04_blockers_frozen_guards_a.sql.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- It COMMITS a fixture and helper tables into the throwaway database; every case runs inside a subtransaction that
-- is rolled back (freezes, inserts, test-only policies, Z01 dry run), so each phase starts from the same state.
--
-- The local chain has none of the three functions or their triggers (KAN718_D04_DISPOSITION.md rows 30/31/34).
-- F installs, VERBATIM from 20260829080500_baseline_schema.sql (cut by sed/grep): guard_user_not_frozen and the three
-- trigger functions with their baseline GRANT lines, the REVOKE lines of 20261013135000 for the three, the three
-- baseline CREATE TRIGGER lines, and ENABLE ROW LEVEL SECURITY on game_invites (baseline :32347; the harness leaves it
-- off). is_frozen, user_freezes, the game_join_requests / game_waitlist policies and grants are the KAN-713 harness's.
-- trgfn_roster_block_frozen_guard is out of scope and not installed.
--
-- ROLES. Every case runs under `SET LOCAL ROLE authenticated` with request.jwt.claim.sub / request.jwt.claims set,
-- which is how the harness auth.uid() (events_p1/local_harness_kan711.sql) reads the caller. Three paths:
--   direct  : the session inserts as authenticated, so the SECURITY INVOKER trigger runs as authenticated.
--             Real for game_join_requests (authenticated keeps INSERT, 20260901190000_kan86 :167). For game_invites and
--             game_waitlist authenticated has no INSERT, so the direct path stops at 42501 before any trigger.
--   rpc     : the session calls public.k803_rpc_path, a SECURITY DEFINER wrapper owned by postgres, so the trigger runs
--             as postgres -- the role the real paths use: rpc_invite_user (baseline :13367), rpc_join_game (:13417) and
--             rpc_decide_join_request (:12064) are all SECURITY DEFINER owned by postgres.
--   visible : direct as authenticated, plus a test-only, rolled-back SELECT policy on games (USING true). The repo has
--             NO policy on games (RLS enabled, baseline :32378), so on the direct path the invoker trigger cannot see
--             any game and always answers game_not_found. This variant is the one where the trigger actually reaches
--             the host read as authenticated, i.e. where an inline events read would raise 42501 (shown in X4).
--
-- Phases: pre (pre-image) / pre_z01 (pre-image after a Z01 dry run: must be RED 42703) / migration / post (new body)
-- / post_z01 (new body after Z01: must equal pre). Z01 dry run = every `...;  -- <seq>` statement of
-- 20261105100000_kan719_z01_remove_replaced_columns.sql, each in its own savepoint, in file order (as kan799 does);
-- seq 603 (games.creator_user_id) must succeed.
--
-- Run (repository root) on a fresh cluster built by supabase/tests/events_p2/build_kan788.sh:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan803_d04_frozen_guards_a_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-803: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k803)' THEN
    RAISE EXCEPTION 'KAN-803: database % is not a throwaway k788/k803 database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-803: run as a superuser'; END IF;
  IF to_regprocedure('public.trgfn_joinreq_block_frozen_guard()') IS NOT NULL
     OR to_regprocedure('public.kan803_game_host_uid(uuid)') IS NOT NULL
     OR to_regclass('public.k803_res') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-803: functions or results already present; use a fresh DB';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------------------
-- F. Fixture, VERBATIM from the repository.
-- ---------------------------------------------------------------------------------------------------------
\set fx `B=supabase/migrations/20260829080500_baseline_schema.sql; for f in guard_user_not_frozen trgfn_invite_block_frozen_guard trgfn_joinreq_block_frozen_guard trgfn_waitlist_block_frozen_guard; do sed -n "/^CREATE OR REPLACE FUNCTION \"public\".\"$f\"(/,/^ALTER FUNCTION \"public\".\"$f\"(/p" $B; grep "^GRANT ALL ON FUNCTION \"public\".\"$f\"(" $B; done; grep -E "^REVOKE EXECUTE ON FUNCTION public.trgfn_(invite|joinreq|waitlist)_block_frozen_guard\(\)" supabase/migrations/20261013135000_revoke_public_anon_trigger_functions.sql; grep -E "^CREATE OR REPLACE TRIGGER \"(trg_invite_block_frozen_guard|trg_joinreq_block_frozen_guard|trg_zz_waitlist_block_frozen)\"" $B; grep -E "^ALTER TABLE \"public\".\"game_invites\" ENABLE ROW LEVEL SECURITY;" $B`
:fx

SELECT 'fixture triggers' AS k, tgrelid::regclass AS tbl, tgname, tgfoid::regprocedure AS fn
  FROM pg_trigger WHERE NOT tgisinternal AND tgfoid::regprocedure::text LIKE 'trgfn_%_block_frozen_guard()' ORDER BY 2;

-- T0: the fixture pre-images equal the migration's pins.
DO $t0$
DECLARE x text;
BEGIN
  SELECT string_agg(t.f || '=' || coalesce(md5(p.prosrc), 'absent'), ', ') INTO x
    FROM (VALUES ('public.trgfn_invite_block_frozen_guard()',  'af79f8013de8db8fd3a970e78308b0a5'),
                 ('public.trgfn_joinreq_block_frozen_guard()', '5986334a1449ecaffc530ec1301fdba6'),
                 ('public.trgfn_waitlist_block_frozen_guard()','e9e1d50b5a46d1daefc73f295b8c0b70')) t(f, want)
    LEFT JOIN pg_proc p ON p.oid = to_regprocedure(t.f)
   WHERE p.oid IS NULL OR md5(p.prosrc) <> t.want;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-803 T0 FAIL: fixture pre-image differs from the pin: %', x; END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgfoid IN (
        'public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
        'public.trgfn_waitlist_block_frozen_guard()'::regprocedure)) <> 3 THEN
    RAISE EXCEPTION 'KAN-803 T0 FAIL: expected the 3 baseline triggers';
  END IF;
  RAISE NOTICE 'KAN-803 T0 PASS: fixture pre-images match the migration pins; 3 baseline triggers installed';
END $t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Ids. G = harness game G-pub (host a1 / b1). a2/b2 requester, a5/b5 stranger, a7/b7 invitee / waitlister.
-- ---------------------------------------------------------------------------------------------------------
CREATE TABLE public.k803_ids AS SELECT
  '71300000-0000-0000-0000-000000000001'::uuid AS g, '00000000-0000-0000-0000-00000000dead'::uuid AS g_unknown,
  '00000000-0000-0000-0000-0000000000a1'::uuid AS host_u, '00000000-0000-0000-0000-0000000000b1'::uuid AS host_p,
  '00000000-0000-0000-0000-0000000000a2'::uuid AS req_u,  '00000000-0000-0000-0000-0000000000b2'::uuid AS req_p,
  '00000000-0000-0000-0000-0000000000a5'::uuid AS str_u,  '00000000-0000-0000-0000-0000000000b5'::uuid AS str_p,
  '00000000-0000-0000-0000-0000000000a7'::uuid AS inv_u,  '00000000-0000-0000-0000-0000000000b7'::uuid AS inv_p;
SELECT 'seed' AS k, i.g, g.creator_user_id AS games_host, e.creator_user_id AS events_host
  FROM public.k803_ids i JOIN public.games g ON g.id = i.g JOIN public.events e ON e.id = g.event_id;

-- The RPC path: SECURITY DEFINER, owned by postgres (as rpc_invite_user / rpc_join_game / rpc_decide_join_request).
CREATE FUNCTION public.k803_rpc_path(p_kind text, p_game uuid, p_user uuid, p_profile uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
BEGIN
  IF p_kind = 'invite' THEN
    INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (p_game, p_user, '00000000-0000-0000-0000-0000000000b1', 'pending');
  ELSIF p_kind = 'waitlist' THEN
    INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (p_game, p_profile, p_user, 1);
  ELSE
    INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (p_game, p_profile, p_user, 'pending');
  END IF;
  RETURN current_user;
END $f$;
REVOKE ALL ON FUNCTION public.k803_rpc_path(text, uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.k803_rpc_path(text, uuid, uuid, uuid) TO authenticated;

\set z01text `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TABLE public.k803_z01 AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM (SELECT :'z01text'::text AS src) s, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);
SELECT 'z01 statements' AS k, count(*) AS n, count(*) FILTER (WHERE seq BETWEEN 601 AND 623) AS games_drop_columns,
       max(stmt) FILTER (WHERE seq = 603) AS seq_603 FROM public.k803_z01;

CREATE TABLE public.k803_res (phase text, case_name text, outcome jsonb, PRIMARY KEY (phase, case_name));
CREATE TABLE public.k803_attr (phase text, kind text, name text, attrs text, PRIMARY KEY (phase, kind, name));

-- Case table: (name, path, kind, caller, game, user, profile, frz = users frozen for the case).
CREATE TABLE public.k803_cases (ord int PRIMARY KEY, name text, path text, kind text, caller text, game text, u text, p text, frz text[]);
INSERT INTO public.k803_cases VALUES
  -- game_join_requests, direct as authenticated, repo RLS (no games policy)
  ( 1, 'jr_direct_ok',             'direct',  'joinreq',  'req', 'g', 'req',  'req',  '{}'),
  ( 2, 'jr_direct_frozen_game',    'direct',  'joinreq',  'req', 'g', 'req',  'req',  '{host}'),
  ( 3, 'jr_direct_frozen_req',     'direct',  'joinreq',  'req', 'g', 'req',  'req',  '{req}'),
  ( 4, 'jr_direct_host',           'direct',  'joinreq',  'host','g', 'host', 'host', '{}'),
  ( 5, 'jr_direct_stranger',       'direct',  'joinreq',  'str', 'g', 'req',  'req',  '{}'),
  -- game_join_requests, direct as authenticated, test-only games SELECT policy (trigger reaches the host read)
  ( 6, 'jr_visible_ok',            'visible', 'joinreq',  'req', 'g', 'req',  'req',  '{}'),
  ( 7, 'jr_visible_frozen_game',   'visible', 'joinreq',  'req', 'g', 'req',  'req',  '{host}'),
  ( 8, 'jr_visible_frozen_req',    'visible', 'joinreq',  'req', 'g', 'req',  'req',  '{req}'),
  ( 9, 'jr_visible_host',          'visible', 'joinreq',  'host','g', 'host', 'host', '{}'),
  (10, 'jr_visible_host_frozen',   'visible', 'joinreq',  'host','g', 'host', 'host', '{host}'),
  (11, 'jr_visible_stranger',      'visible', 'joinreq',  'str', 'g', 'req',  'req',  '{}'),
  (12, 'jr_visible_unknown_game',  'visible', 'joinreq',  'req', 'u', 'req',  'req',  '{}'),
  -- game_join_requests, rpc path (trigger runs as postgres)
  (13, 'jr_rpc_ok',                'rpc',     'joinreq',  'req', 'g', 'req',  'req',  '{}'),
  (14, 'jr_rpc_frozen_game',       'rpc',     'joinreq',  'req', 'g', 'req',  'req',  '{host}'),
  (15, 'jr_rpc_unknown_game',      'rpc',     'joinreq',  'req', 'u', 'req',  'req',  '{}'),
  -- game_invites
  (16, 'inv_rpc_ok',               'rpc',     'invite',   'host','g', 'inv',  'inv',  '{}'),
  (17, 'inv_rpc_frozen_game',      'rpc',     'invite',   'host','g', 'inv',  'inv',  '{host}'),
  (18, 'inv_rpc_frozen_invitee',   'rpc',     'invite',   'host','g', 'inv',  'inv',  '{inv}'),
  (19, 'inv_rpc_unknown_game',     'rpc',     'invite',   'host','u', 'inv',  'inv',  '{}'),
  (20, 'inv_rpc_stranger',         'rpc',     'invite',   'str', 'g', 'inv',  'inv',  '{}'),
  (21, 'inv_direct_authenticated', 'direct',  'invite',   'host','g', 'inv',  'inv',  '{}'),
  -- game_waitlist
  (22, 'wl_rpc_ok',                'rpc',     'waitlist', 'inv', 'g', 'inv',  'inv',  '{}'),
  (23, 'wl_rpc_frozen_game',       'rpc',     'waitlist', 'inv', 'g', 'inv',  'inv',  '{host}'),
  (24, 'wl_rpc_frozen_user',       'rpc',     'waitlist', 'inv', 'g', 'inv',  'inv',  '{inv}'),
  (25, 'wl_rpc_unknown_game',      'rpc',     'waitlist', 'inv', 'u', 'inv',  'inv',  '{}'),
  (26, 'wl_rpc_stranger',          'rpc',     'waitlist', 'str', 'g', 'inv',  'inv',  '{}'),
  (27, 'wl_direct_authenticated',  'direct',  'waitlist', 'inv', 'g', 'inv',  'inv',  '{}');

CREATE FUNCTION public.k803_uid(p text) RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT CASE p WHEN 'host' THEN host_u WHEN 'req' THEN req_u WHEN 'str' THEN str_u WHEN 'inv' THEN inv_u END FROM public.k803_ids $f$;
CREATE FUNCTION public.k803_pid(p text) RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT CASE p WHEN 'host' THEN host_p WHEN 'req' THEN req_p WHEN 'str' THEN str_p WHEN 'inv' THEN inv_p END FROM public.k803_ids $f$;

-- One case, inside the caller's subtransaction. Returns {ok, rows, trigger_role} or {error:{sqlstate,message}}.
CREATE FUNCTION public.k803_case(c public.k803_cases) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE i public.k803_ids; gid uuid; uid uuid; pid uuid; n bigint; who text; caller uuid; d text; f text;
BEGIN
  SELECT * INTO i FROM public.k803_ids;
  gid := CASE c.game WHEN 'g' THEN i.g ELSE i.g_unknown END;
  uid := public.k803_uid(c.u); pid := public.k803_pid(c.p); caller := public.k803_uid(c.caller);
  FOREACH f IN ARRAY c.frz LOOP
    INSERT INTO public.user_freezes (user_id, reason) VALUES (public.k803_uid(f), 'kan803 test');
  END LOOP;
  IF c.path = 'visible' THEN
    EXECUTE 'CREATE POLICY k803_games_visible_probe ON public.games FOR SELECT TO authenticated USING (true)';
  END IF;
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', caller::text, true);
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', caller, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF public.auth_uid_probe() IS DISTINCT FROM caller OR current_user <> 'authenticated' THEN
      RAISE EXCEPTION 'k803 harness: caller not established';
    END IF;
    IF c.path = 'rpc' THEN
      who := public.k803_rpc_path(c.kind, gid, uid, pid); n := 1;
    ELSIF c.kind = 'joinreq' THEN
      INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (gid, pid, uid, 'pending');
      GET DIAGNOSTICS n = ROW_COUNT; who := current_user;
    ELSIF c.kind = 'invite' THEN
      INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (gid, uid, i.host_p, 'pending');
      GET DIAGNOSTICS n = ROW_COUNT; who := current_user;
    ELSE
      INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (gid, pid, uid, 1);
      GET DIAGNOSTICS n = ROW_COUNT; who := current_user;
    END IF;
    RAISE EXCEPTION 'k803_ok' USING DETAIL = jsonb_build_object('ok', true, 'rows', n, 'trigger_role', who)::text;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'k803_ok' THEN
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
      RETURN d::jsonb;
    END IF;
    RETURN jsonb_build_object('error', jsonb_build_object('sqlstate', SQLSTATE, 'message', SQLERRM));
  END;
END $f$;
-- auth.uid() as the cases see it (invoker, so it reads the claim the case set).
CREATE FUNCTION public.auth_uid_probe() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT auth.uid() $f$;

-- One phase: every case in its own rolled-back subtransaction, optionally after a Z01 dry run.
CREATE FUNCTION public.k803_phase(p_phase text, p_z01 boolean) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c public.k803_cases; s record; r jsonb; d text; skipped text[]; gone int; first boolean := true;
BEGIN
  FOR c IN SELECT * FROM public.k803_cases ORDER BY ord LOOP
    skipped := '{}';
    BEGIN
      IF p_z01 THEN
        FOR s IN SELECT seq, stmt FROM public.k803_z01 ORDER BY ord LOOP
          BEGIN EXECUTE s.stmt; EXCEPTION WHEN OTHERS THEN skipped := skipped || (s.seq || ':' || SQLSTATE); END;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'creator_user_id' AND NOT attisdropped) THEN
          RAISE EXCEPTION 'KAN-803: Z01 dry run did not drop games.creator_user_id (seq 603)';
        END IF;
        SELECT count(*) INTO gone FROM public.k803_z01 z WHERE z.seq BETWEEN 601 AND 623
           AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.games'::regclass AND NOT a.attisdropped
                            AND a.attname = substring(z.stmt FROM 'DROP COLUMN ([a-z_]+)'));
      END IF;
      r := public.k803_case(c);
      RAISE EXCEPTION 'k803_rollback' USING DETAIL = jsonb_build_object('r', r, 'skipped', to_jsonb(skipped), 'gone', gone)::text;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'k803_rollback' THEN RAISE; END IF;
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
    END;
    INSERT INTO public.k803_res VALUES (p_phase, c.name, (d::jsonb)->'r');
    IF p_z01 AND first THEN
      RAISE NOTICE 'KAN-803 % Z01 dry run: games.creator_user_id dropped (seq 603 ok); games columns removed %/23; harness-skipped (seq:sqlstate): %',
        p_phase, (d::jsonb)->'gone', (d::jsonb)->'skipped';
      first := false;
    END IF;
  END LOOP;
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'KAN-803: role leaked out of a case (%)', current_user; END IF;
END $f$;

-- Attribute snapshot for C4.
CREATE FUNCTION public.k803_snapshot(p_phase text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO public.k803_attr
  SELECT p_phase, 'proc', p.oid::regprocedure::text,
         concat_ws(' | ', 'args=' || pg_get_function_identity_arguments(p.oid), 'argtypes=' || p.proargtypes::text,
                   'ret=' || pg_get_function_result(p.oid), 'secdef=' || p.prosecdef, 'vol=' || p.provolatile::text,
                   'config=' || p.proconfig::text, 'owner=' || pg_get_userbyid(p.proowner), 'acl=' || coalesce(p.proacl::text, 'NULL'))
    FROM pg_proc p
   WHERE p.oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                   'public.trgfn_waitlist_block_frozen_guard()'::regprocedure)
  UNION ALL
  SELECT p_phase, 'trigger', t.tgrelid::regclass::text || '.' || t.tgname,
         concat_ws(' | ', 'fn=' || t.tgfoid::regprocedure::text, 'type=' || t.tgtype, 'enabled=' || t.tgenabled::text, pg_get_triggerdef(t.oid))
    FROM pg_trigger t
   WHERE NOT t.tgisinternal AND t.tgrelid IN ('public.game_invites'::regclass, 'public.game_join_requests'::regclass, 'public.game_waitlist'::regclass)
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- T1 / T2: pre-image, before and after a Z01 dry run.
-- ---------------------------------------------------------------------------------------------------------
SELECT public.k803_snapshot('pre');
SELECT public.k803_phase('pre', false);
SELECT public.k803_phase('pre_z01', true);
\echo '== T1 pre (pre-image) and T2 pre_z01 (pre-image after Z01: cases that reach the host read must be RED 42703)'
SELECT a.case_name, a.outcome AS pre, b.outcome AS pre_z01
  FROM public.k803_res a JOIN public.k803_cases c ON c.name = a.case_name
  JOIN public.k803_res b ON b.case_name = a.case_name AND b.phase = 'pre_z01'
 WHERE a.phase = 'pre' ORDER BY c.ord;
DO $t2$ DECLARE n42703 int; nbad int; BEGIN
  SELECT count(*) FILTER (WHERE b.outcome->'error'->>'sqlstate' = '42703'),
         count(*) FILTER (WHERE b.outcome IS DISTINCT FROM a.outcome AND b.outcome->'error'->>'sqlstate' IS DISTINCT FROM '42703')
    INTO n42703, nbad
    FROM public.k803_res a JOIN public.k803_res b ON b.case_name = a.case_name AND b.phase = 'pre_z01' WHERE a.phase = 'pre';
  IF EXISTS (SELECT 1 FROM public.k803_res WHERE phase = 'pre' AND outcome->'error'->>'sqlstate' = '42703') OR n42703 = 0 OR nbad <> 0 THEN
    RAISE EXCEPTION 'KAN-803 T2 FAIL: expected pre free of 42703 and every changed pre_z01 case 42703 (42703=%, other=%)', n42703, nbad;
  END IF;
  RAISE NOTICE 'KAN-803 T2 PASS (RED shown): the pre-images fail 42703 in % of 27 cases once Z01 has run; the rest stop before the host read', n42703;
END $t2$;

-- ---------------------------------------------------------------------------------------------------------
-- T3: the migration (its own BEGIN/COMMIT, pre/post-conditions).
-- ---------------------------------------------------------------------------------------------------------
\echo '== T3 apply 20261104110800_kan803_d04_blockers_frozen_guards_a.sql'
\i supabase/migrations/20261104110800_kan803_d04_blockers_frozen_guards_a.sql
SELECT public.k803_snapshot('post');

-- ---------------------------------------------------------------------------------------------------------
-- T4 / T5: new body, before and after a Z01 dry run. Must equal pre, case by case.
-- ---------------------------------------------------------------------------------------------------------
SELECT public.k803_phase('post', false);
SELECT public.k803_phase('post_z01', true);
\echo '== T4 post and T5 post_z01: outcome per case vs pre'
SELECT a.case_name, a.outcome AS pre, (a.outcome = b.outcome) AS post_equal, (a.outcome = z.outcome) AS post_z01_equal
  FROM public.k803_res a JOIN public.k803_cases c ON c.name = a.case_name
  JOIN public.k803_res b ON b.case_name = a.case_name AND b.phase = 'post'
  JOIN public.k803_res z ON z.case_name = a.case_name AND z.phase = 'post_z01'
 WHERE a.phase = 'pre' ORDER BY c.ord;
DO $t5$ BEGIN
  IF (SELECT count(*) FROM public.k803_res WHERE phase = 'pre') <> 27
     OR EXISTS (SELECT 1 FROM public.k803_res a JOIN public.k803_res b ON b.case_name = a.case_name AND b.phase IN ('post', 'post_z01')
                 WHERE a.phase = 'pre' AND a.outcome IS DISTINCT FROM b.outcome)
     OR (SELECT count(*) FROM public.k803_res WHERE phase IN ('post', 'post_z01')) <> 54
     OR EXISTS (SELECT 1 FROM public.k803_res WHERE phase IN ('post', 'post_z01') AND outcome->'error'->>'sqlstate' = '42703') THEN
    RAISE EXCEPTION 'KAN-803 T4/T5 FAIL: post or post_z01 differs from pre, or a 42703 remains';
  END IF;
  RAISE NOTICE 'KAN-803 T4/T5 PASS (GREEN): all 27 cases identical to the pre-image, before and after Z01; no 42703';
END $t5$;

-- ---------------------------------------------------------------------------------------------------------
-- X: why the helper is needed, and who may call it.
-- ---------------------------------------------------------------------------------------------------------
\echo '== X1-X5: events reads as authenticated, helper ACL in use'
CREATE FUNCTION public.k803_try2(p_role text, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text; d text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RAISE EXCEPTION 'k803_ok' USING DETAIL = coalesce(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'k803_ok' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN 'ok: ' || d; END IF;
    RETURN SQLSTATE || ': ' || SQLERRM;
  END;
END $f$;
SELECT 'X1 authenticated: select from public.events' AS k,
       public.k803_try2('authenticated', 'select creator_user_id::text from public.events limit 1') AS result
UNION ALL
SELECT 'X2 authenticated: old-style games JOIN events host read',
       public.k803_try2('authenticated', 'select e.creator_user_id::text from public.games g join public.events e on e.id = g.event_id where g.id = ''71300000-0000-0000-0000-000000000001''')
UNION ALL
SELECT 'X3 authenticated: public.kan803_game_host_uid(G-pub)',
       public.k803_try2('authenticated', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text')
UNION ALL
SELECT 'X3b service_role: public.kan803_game_host_uid(G-pub)',
       public.k803_try2('service_role', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text')
UNION ALL
SELECT 'X5 anon: public.kan803_game_host_uid(G-pub)',
       public.k803_try2('anon', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text');

-- X4: the trigger itself, as authenticated with the game visible, if the host were read inline from events (no
-- helper). Installed and exercised inside a rolled-back subtransaction; the migrated body is left in place.
DO $x4$ DECLARE r jsonb; st text; BEGIN
  BEGIN
    EXECUTE $b$CREATE OR REPLACE FUNCTION public.trgfn_joinreq_block_frozen_guard() RETURNS trigger LANGUAGE plpgsql
      SET search_path TO 'public', 'pg_temp' AS $$
      declare host_uid uuid;
      begin
        perform public.guard_user_not_frozen(new.from_user_id);
        select e.creator_user_id into host_uid from public.games g join public.events e on e.id = g.event_id where g.id = new.game_id;
        if host_uid is null then raise exception using errcode='P0001', message='game_not_found'; end if;
        perform public.guard_user_not_frozen(host_uid);
        return new;
      end; $$$b$;
    r := public.k803_case((SELECT c FROM public.k803_cases c WHERE c.name = 'jr_visible_ok'));
    RAISE EXCEPTION 'k803_rollback' USING DETAIL = r::text;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k803_rollback' THEN RAISE; END IF;
    GET STACKED DIAGNOSTICS st = PG_EXCEPTION_DETAIL;
  END;
  RAISE NOTICE 'KAN-803 X4 jr_visible_ok with an inline events read instead of the helper: %', st;
  IF (st::jsonb)->'error'->>'sqlstate' IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'KAN-803 X4 FAIL: expected 42501'; END IF;
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure))
     = '5986334a1449ecaffc530ec1301fdba6' THEN RAISE EXCEPTION 'KAN-803 X4: unexpected body'; END IF;
  RAISE NOTICE 'KAN-803 X4 PASS: without the helper the authenticated trigger path raises 42501; the migrated body is back in place';
END $x4$;
DO $x$ BEGIN
  IF public.k803_try2('authenticated', 'select creator_user_id::text from public.events limit 1') NOT LIKE '42501:%'
     OR public.k803_try2('authenticated', 'select e.creator_user_id::text from public.games g join public.events e on e.id = g.event_id limit 1') NOT LIKE '42501:%'
     OR public.k803_try2('authenticated', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text') <> 'ok: 00000000-0000-0000-0000-0000000000a1'
     OR public.k803_try2('service_role', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text') <> 'ok: 00000000-0000-0000-0000-0000000000a1'
     OR public.k803_try2('anon', 'select public.kan803_game_host_uid(''71300000-0000-0000-0000-000000000001'')::text') NOT LIKE '42501:%' THEN
    RAISE EXCEPTION 'KAN-803 X1-X5 FAIL';
  END IF;
  RAISE NOTICE 'KAN-803 X1-X5 PASS: authenticated gets 42501 on events directly and via the old join; the helper answers authenticated and service_role and refuses anon';
END $x$;

-- ---------------------------------------------------------------------------------------------------------
-- T6 (C4): attributes and trigger rows before vs after; helper ACL.
-- ---------------------------------------------------------------------------------------------------------
\echo '== T6 / C4 attributes, pre vs post'
SELECT a.kind, a.name, a.attrs, (a.attrs = b.attrs) AS unchanged
  FROM public.k803_attr a JOIN public.k803_attr b ON (b.kind, b.name, b.phase) = (a.kind, a.name, 'post')
 WHERE a.phase = 'pre' ORDER BY 1, 2;
\echo '== T6 / C4 helper'
SELECT p.oid::regprocedure AS fn, p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_exec,
       EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0) AS public_grant
  FROM pg_proc p WHERE p.oid = 'public.kan803_game_host_uid(uuid)'::regprocedure;
DO $t6$ BEGIN
  IF (SELECT count(*) FROM public.k803_attr WHERE phase = 'pre') <> 6 OR (SELECT count(*) FROM public.k803_attr WHERE phase = 'post') <> 6
     OR EXISTS (SELECT 1 FROM public.k803_attr a LEFT JOIN public.k803_attr b ON (b.kind, b.name, b.phase) = (a.kind, a.name, 'post')
                 WHERE a.phase = 'pre' AND b.attrs IS DISTINCT FROM a.attrs) THEN
    RAISE EXCEPTION 'KAN-803 T6 FAIL: attributes or trigger rows changed';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = 'public.kan803_game_host_uid(uuid)'::regprocedure
              AND a.grantee <> p.proowner AND a.grantee NOT IN ('authenticated'::regrole, 'service_role'::regrole))
     OR has_function_privilege('anon', 'public.kan803_game_host_uid(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-803 T6 FAIL: helper ACL wider than authenticated + service_role';
  END IF;
  RAISE NOTICE 'KAN-803 T6 PASS: 3 functions (args, argtypes, result, SECURITY INVOKER, volatility, search_path, owner, ACL) and 3 triggers unchanged; helper EXECUTE = owner + authenticated + service_role only';
END $t6$;

-- ---------------------------------------------------------------------------------------------------------
-- T7 (C3): no Z01-removed games column in the new bodies.
-- ---------------------------------------------------------------------------------------------------------
\echo '== T7 / C3 games-alias (g.) references and creator_user_id mentions in pg_get_functiondef'
SELECT p.proname, m[1] AS ref, count(*)
  FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid), '\m(g\.[a-z_]+|[a-z_]*creator_user_id)', 'g') m
 WHERE p.oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure, 'public.kan803_game_host_uid(uuid)'::regprocedure)
 GROUP BY 1, 2 ORDER BY 1, 2;
DO $t7$ DECLARE x text; BEGIN
  SELECT string_agg(p.proname || ':' || m[1], ', ') INTO x
    FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid), '\mg\.([a-z_]+)', 'g') m
   WHERE p.oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                   'public.trgfn_waitlist_block_frozen_guard()'::regprocedure, 'public.kan803_game_host_uid(uuid)'::regprocedure)
     AND m[1] IN (SELECT substring(stmt FROM 'DROP COLUMN ([a-z_]+)') FROM public.k803_z01 WHERE stmt ~ '^ALTER TABLE public\.games DROP COLUMN');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-803 T7 FAIL: new body reads Z01-removed games column(s): %', x; END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure,
               'public.trgfn_joinreq_block_frozen_guard()'::regprocedure, 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure)
               AND pg_get_functiondef(p.oid) ~ 'creator_user_id') THEN
    RAISE EXCEPTION 'KAN-803 T7 FAIL: a trigger body still mentions creator_user_id';
  END IF;
  RAISE NOTICE 'KAN-803 T7 PASS: the new bodies read games only through g.id; creator_user_id appears only in the helper, as e.creator_user_id';
END $t7$;

\echo 'KAN-803: ALL PASS'
