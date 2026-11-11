-- KAN-825: proof for supabase/migrations/20261105150000_kan825_helper_consolidation.sql.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. The guard refuses anything that looks like Supabase, a database whose name
-- does not start with k825, and a non-superuser. Never point this at a hosted project.
--
-- Precondition: a database with KAN-803 (20261104110800) and KAN-804 (20261104110900) applied and their triggers
-- installed. Reproduced locally (2026-11-05) as:
--   1. supabase/tests/events_p4/build_kan851.sh <datadir> <port> 61ebab0d        -> database k851
--   2. CREATE DATABASE k804y TEMPLATE k851; postgres promoted to SUPERUSER
--   3. kan804_d04_frozen_guards_b.sql -v phase=setup, 20261104110900, then -v phase=check (KAN-804 TOTAL fail=0)
--   4. the KAN-803 fixture exactly as section F of kan803_d04_frozen_guards_a.sql builds it, minus
--      guard_user_not_frozen (the KAN-804 stand-in, which freezes through public.kan804_frozen, is kept), then
--      20261104110800
--   5. rename to k825_base; each run uses a fresh copy: CREATE DATABASE k825_<x> TEMPLATE k825_base
-- Run from the repository root:
--   psql -X -h /tmp -p <port> -U postgres -d k825_<x> -v ON_ERROR_STOP=1 -P pager=off \
--        -f supabase/tests/events_p4/kan825_helper_consolidation_test.sql
-- RED evidence: add -v skip_migration=1; the migration is not applied and T1 must fail (exit 3).
--
-- What it does. S seeds (committed, in this throwaway database only) four games beside the harness game G-pub:
--   S1 game whose events parent is event_type 'game' (host a5)
--   (a game with event_id NULL cannot exist: CHECK games_event_id_not_null, which replica mode does not bypass;
--    "a game with no event" is S4)
--   S3 game whose event_id points at an event_type 'meetup' row   S4 game whose event_id points at no events row
-- and uses an unknown id U and NULL. Every case runs in a rolled-back subtransaction; outcomes are captured into temp
-- tables in phase 'pre', the migration is applied (\i), and captured again in phase 'post'.
--   T0 parity, pre:  kan803_game_host_uid(id) = (SELECT creator_user_id FROM kan804_game_event_facts(id)) for every
--                    games row + S1, S3, S4 + U + NULL, and the expected values for G-pub/S1, S3, S4/U/NULL.
--   T0n negative:    the same parity probe against a deliberately wrong helper (no event_type filter, rolled back)
--                    must report S3 -- the probe seen failing.
--   T1 body:         post body reads through kan804_game_event_facts and not public.events directly.
--   T2 parity, post: as T0.
--   T3 catalogue:    signature, return type, prosecdef, proconfig, proacl, owner, ... of kan803_game_host_uid,
--                    kan804_game_event_facts and the 3 KAN-803 trigger functions = pre; their bodies = pre except
--                    kan803_game_host_uid; the 3 trigger rows = pre.
--   T4 triggers:     invite / joinreq / waitlist frozen guards, frozen and non-frozen host, as postgres (the RPC
--                    path) and, for joinreq, as authenticated (test-only games SELECT policy, so the trigger reaches
--                    the helper as authenticated): post = pre, and frozen host => user_frozen, non-frozen => inserted.
--   T5 callers:      every direct helper call (postgres, service_role, authenticated, anon) post = pre.
-- Any mismatch raises 'KAN-825 ... FAIL', so psql exits non-zero. Success ends with 'KAN-825: ALL PASS'.
\set ON_ERROR_STOP 1
SET client_min_messages = notice;
\if :{?skip_migration}
\else
  \set skip_migration 0
\endif

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-825: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^k825' THEN
    RAISE EXCEPTION 'KAN-825: database % is not a throwaway k825* database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-825: run as a superuser'; END IF;
  IF to_regprocedure('public.kan803_game_host_uid(uuid)') IS NULL OR to_regprocedure('public.kan804_game_event_facts(uuid)') IS NULL
     OR to_regprocedure('public.trgfn_invite_block_frozen_guard()') IS NULL THEN
    RAISE EXCEPTION 'KAN-825: KAN-803 / KAN-804 not present; see the precondition in the header';
  END IF;
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure)) <> '3e6e858b0fb1d80d09e2db2a9bfe770b' THEN
    RAISE EXCEPTION 'KAN-825: kan803_game_host_uid is not the KAN-803 pre-image; use a fresh copy of k825_base';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE id::text LIKE '82500000-%') THEN
    RAISE EXCEPTION 'KAN-825: seed rows already present; use a fresh copy of k825_base';
  END IF;
END $g$;

\echo '== pre-image body of kan803_game_host_uid'
SELECT pg_get_functiondef('public.kan803_game_host_uid(uuid)'::regprocedure) AS pre_image;

-- ---------------------------------------------------------------------------------------------------------
-- S. Seed. Rows cloned from the harness game G-pub and its events parent; replica mode so the KAN-711/712 mirror
--    and guard triggers and the FK checks do not rewrite or refuse the deliberately odd shapes (S3, S4).
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE k825_ids AS SELECT
  '71300000-0000-0000-0000-000000000001'::uuid AS gpub,
  '82500000-0000-0000-0000-000000000001'::uuid AS s1, '82500000-0000-0000-0000-0000000000e1'::uuid AS e1,
  '82500000-0000-0000-0000-000000000003'::uuid AS s3, '82500000-0000-0000-0000-0000000000e3'::uuid AS e3,
  '82500000-0000-0000-0000-000000000004'::uuid AS s4, '82500000-0000-0000-0000-0000000000e4'::uuid AS e4,
  '00000000-0000-0000-0000-00000000dead'::uuid AS unknown,
  '00000000-0000-0000-0000-0000000000a1'::uuid AS a1, '00000000-0000-0000-0000-0000000000b1'::uuid AS b1,
  '00000000-0000-0000-0000-0000000000a2'::uuid AS a2, '00000000-0000-0000-0000-0000000000b2'::uuid AS b2,
  '00000000-0000-0000-0000-0000000000a5'::uuid AS a5, '00000000-0000-0000-0000-0000000000b5'::uuid AS b5,
  '00000000-0000-0000-0000-0000000000a7'::uuid AS a7, '00000000-0000-0000-0000-0000000000b7'::uuid AS b7;

BEGIN;
SET LOCAL session_replication_role = replica;
INSERT INTO public.events
SELECT (jsonb_populate_record(e, jsonb_build_object('id', i.e1, 'creator_user_id', i.a5, 'creator_profile_id', i.b5,
                                                    'request_id', NULL, 'title', 'kan825 S1'))).*
  FROM public.events e, k825_ids i WHERE e.id = (SELECT event_id FROM public.games WHERE id = i.gpub);
INSERT INTO public.events
SELECT (jsonb_populate_record(e, jsonb_build_object('id', i.e3, 'event_type', 'meetup', 'creator_user_id', i.a7,
                                                    'creator_profile_id', i.b7, 'request_id', NULL, 'title', 'kan825 S3'))).*
  FROM public.events e, k825_ids i WHERE e.id = (SELECT event_id FROM public.games WHERE id = i.gpub);
INSERT INTO public.games
SELECT (jsonb_populate_record(g, jsonb_build_object('id', v.id, 'event_id', v.ev, 'creator_user_id', v.host,
                                                    'request_id', NULL, 'series_id', NULL, 'title', v.t))).*
  FROM public.games g, k825_ids i,
       LATERAL (VALUES (i.s1, i.e1, i.a5, 'kan825 S1'),
                       (i.s3, i.e3, i.a1, 'kan825 S3'), (i.s4, i.e4, i.a1, 'kan825 S4')) v(id, ev, host, t)
 WHERE g.id = i.gpub;
COMMIT;

SELECT 'seed' AS k, g.id, g.event_id, e.event_type, e.creator_user_id AS events_host
  FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id, k825_ids i
 WHERE g.id IN (i.gpub, i.s1, i.s3, i.s4) ORDER BY g.id;

-- ---------------------------------------------------------------------------------------------------------
-- Machinery (all temporary).
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE k825_res (phase text, kind text, name text, outcome text, PRIMARY KEY (phase, kind, name));
CREATE TEMP TABLE k825_cat (phase text, kind text, name text, attrs text, PRIMARY KEY (phase, kind, name));

-- One probe in a rolled-back subtransaction: freeze users, optional test-only games policy, become p_role with
-- auth sub p_sub, run p_sql. Returns 'ok: <value>' / 'ok: rows=<n>' or 'err <sqlstate>: <message>'.
CREATE FUNCTION pg_temp.k825_run(p_role text, p_sub uuid, p_sql text, p_freeze uuid[], p_policy boolean) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE v text; d text; u uuid; n bigint;
BEGIN
  BEGIN
    FOREACH u IN ARRAY coalesce(p_freeze, '{}'::uuid[]) LOOP
      IF to_regclass('public.kan804_frozen') IS NOT NULL THEN
        EXECUTE 'INSERT INTO public.kan804_frozen (user_id) VALUES ($1)' USING u;
      ELSE
        EXECUTE 'INSERT INTO public.user_freezes (user_id, reason) VALUES ($1, ''kan825 test'')' USING u;
      END IF;
    END LOOP;
    IF p_policy THEN
      EXECUTE 'CREATE POLICY k825_games_visible_probe ON public.games FOR SELECT TO authenticated USING (true)';
    END IF;
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_sub::text, ''), true);
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_sub, 'role', p_role)::text, true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    IF p_sql ~* '^\s*insert' THEN
      EXECUTE p_sql; GET DIAGNOSTICS n = ROW_COUNT; v := 'rows=' || n;
    ELSE
      EXECUTE p_sql INTO v;
    END IF;
    RAISE EXCEPTION 'k825_ok' USING DETAIL = coalesce(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'k825_ok' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN 'ok: ' || d; END IF;
    RETURN 'err ' || SQLSTATE || ': ' || SQLERRM;
  END;
END $f$;

-- Cases. kind: helper (direct call) or trigger. Placeholders resolved from k825_ids by k825_sql.
CREATE TEMP TABLE k825_cases (ord int PRIMARY KEY, kind text, name text, role text, sub text, sql text,
                              frz text[], policy boolean, expect text);
INSERT INTO k825_cases VALUES
  -- direct helper calls, 7 ids x 4 roles
  ( 1, 'helper', 'gpub/postgres',        'postgres',      NULL, 'SELECT public.kan803_game_host_uid(:gpub)::text', '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a1'),
  ( 2, 'helper', 's1/postgres',          'postgres',      NULL, 'SELECT public.kan803_game_host_uid(:s1)::text',   '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a5'),
  ( 4, 'helper', 's3/postgres',          'postgres',      NULL, 'SELECT public.kan803_game_host_uid(:s3)::text',   '{}', false, 'ok: <null>'),
  ( 5, 'helper', 's4/postgres',          'postgres',      NULL, 'SELECT public.kan803_game_host_uid(:s4)::text',   '{}', false, 'ok: <null>'),
  ( 6, 'helper', 'unknown/postgres',     'postgres',      NULL, 'SELECT public.kan803_game_host_uid(:unknown)::text', '{}', false, 'ok: <null>'),
  ( 7, 'helper', 'null/postgres',        'postgres',      NULL, 'SELECT public.kan803_game_host_uid(NULL)::text',  '{}', false, 'ok: <null>'),
  ( 8, 'helper', 'gpub/service_role',    'service_role',  NULL, 'SELECT public.kan803_game_host_uid(:gpub)::text', '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a1'),
  ( 9, 'helper', 's1/service_role',      'service_role',  NULL, 'SELECT public.kan803_game_host_uid(:s1)::text',   '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a5'),
  (10, 'helper', 's3/service_role',      'service_role',  NULL, 'SELECT public.kan803_game_host_uid(:s3)::text',   '{}', false, 'ok: <null>'),
  (11, 'helper', 'unknown/service_role', 'service_role',  NULL, 'SELECT public.kan803_game_host_uid(:unknown)::text', '{}', false, 'ok: <null>'),
  (12, 'helper', 'gpub/authenticated',   'authenticated', 'a2', 'SELECT public.kan803_game_host_uid(:gpub)::text', '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a1'),
  (13, 'helper', 's1/authenticated',     'authenticated', 'a2', 'SELECT public.kan803_game_host_uid(:s1)::text',   '{}', false, 'ok: 00000000-0000-0000-0000-0000000000a5'),
  (15, 'helper', 's3/authenticated',     'authenticated', 'a2', 'SELECT public.kan803_game_host_uid(:s3)::text',   '{}', false, 'ok: <null>'),
  (16, 'helper', 'unknown/authenticated','authenticated', 'a2', 'SELECT public.kan803_game_host_uid(:unknown)::text', '{}', false, 'ok: <null>'),
  (17, 'helper', 'gpub/anon',            'anon',          NULL, 'SELECT public.kan803_game_host_uid(:gpub)::text', '{}', false, 'err 42501: permission denied for function kan803_game_host_uid'),
  (18, 'helper', 'kan804 gpub/authenticated', 'authenticated', 'a2', 'SELECT (SELECT f.creator_user_id FROM public.kan804_game_event_facts(:gpub) f)::text', '{}', false, 'err 42501: permission denied for function kan804_game_event_facts'),
  -- invite frozen guard, RPC path (trigger runs as postgres)
  (31, 'trigger', 'invite/gpub ok',            'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:gpub, :a7, :b1, ''pending'')', '{}',   false, 'ok: rows=1'),
  (32, 'trigger', 'invite/gpub host frozen',   'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:gpub, :a7, :b1, ''pending'')', '{a1}', false, 'err P0001: user_frozen'),
  (33, 'trigger', 'invite/s1 ok',              'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:s1, :a7, :b5, ''pending'')',   '{}',   false, 'ok: rows=1'),
  (34, 'trigger', 'invite/s1 host frozen',     'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:s1, :a7, :b5, ''pending'')',   '{a5}', false, 'err P0001: user_frozen'),
  (35, 'trigger', 'invite/s1 a1 frozen',       'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:s1, :a7, :b5, ''pending'')',   '{a1}', false, 'ok: rows=1'),
  (37, 'trigger', 'invite/s3 meetup event',    'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:s3, :a7, :b1, ''pending'')',   '{}',   false, 'err P0001: game_not_found'),
  (38, 'trigger', 'invite/unknown',            'postgres', NULL, 'INSERT INTO public.game_invites (game_id, to_user_id, invited_by_profile_id, status) VALUES (:unknown, :a7, :b1, ''pending'')', '{}', false, 'err P0001: game_not_found'),
  -- joinreq frozen guard, RPC path
  (41, 'trigger', 'joinreq/gpub ok',           'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:gpub, :b2, :a2, ''pending'')', '{}',   false, 'ok: rows=1'),
  (42, 'trigger', 'joinreq/gpub host frozen',  'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:gpub, :b2, :a2, ''pending'')', '{a1}', false, 'err P0001: user_frozen'),
  (43, 'trigger', 'joinreq/s1 ok',             'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s1, :b2, :a2, ''pending'')',   '{}',   false, 'ok: rows=1'),
  (44, 'trigger', 'joinreq/s1 host frozen',    'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s1, :b2, :a2, ''pending'')',   '{a5}', false, 'err P0001: user_frozen'),
  (46, 'trigger', 'joinreq/s3 meetup event',   'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s3, :b2, :a2, ''pending'')',   '{}',   false, 'err P0001: game_not_found'),
  (47, 'trigger', 'joinreq/unknown',           'postgres', NULL, 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:unknown, :b2, :a2, ''pending'')', '{}', false, 'err P0001: game_not_found'),
  -- joinreq as authenticated, test-only games SELECT policy: trigger -> helper as authenticated -> kan804 as owner
  (51, 'trigger', 'joinreq-auth/gpub ok',          'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:gpub, :b2, :a2, ''pending'')', '{}',   true, 'ok: rows=1'),
  (52, 'trigger', 'joinreq-auth/gpub host frozen', 'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:gpub, :b2, :a2, ''pending'')', '{a1}', true, 'err P0001: user_frozen'),
  (53, 'trigger', 'joinreq-auth/s1 ok',            'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s1, :b2, :a2, ''pending'')',   '{}',   true, 'ok: rows=1'),
  (54, 'trigger', 'joinreq-auth/s1 host frozen',   'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s1, :b2, :a2, ''pending'')',   '{a5}', true, 'err P0001: user_frozen'),
  (55, 'trigger', 'joinreq-auth/s3 meetup event',  'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:s3, :b2, :a2, ''pending'')',   '{}',   true, 'err P0001: game_not_found'),
  (56, 'trigger', 'joinreq-auth/gpub no policy',   'authenticated', 'a2', 'INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES (:gpub, :b2, :a2, ''pending'')', '{}',   false, 'err P0001: game_not_found'),
  -- waitlist frozen guard, RPC path
  (61, 'trigger', 'waitlist/gpub ok',          'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:gpub, :b7, :a7, 1)', '{}',   false, 'ok: rows=1'),
  (62, 'trigger', 'waitlist/gpub host frozen', 'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:gpub, :b7, :a7, 1)', '{a1}', false, 'err P0001: user_frozen'),
  (63, 'trigger', 'waitlist/s1 ok',            'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:s1, :b7, :a7, 1)',   '{}',   false, 'ok: rows=1'),
  (64, 'trigger', 'waitlist/s1 host frozen',   'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:s1, :b7, :a7, 1)',   '{a5}', false, 'err P0001: user_frozen'),
  (66, 'trigger', 'waitlist/s3 meetup event',  'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:s3, :b7, :a7, 1)',   '{}',   false, 'err P0001: game_not_found'),
  (67, 'trigger', 'waitlist/unknown',          'postgres', NULL, 'INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES (:unknown, :b7, :a7, 1)', '{}', false, 'err P0001: game_not_found');

-- Resolve :name placeholders (and user/role shorthands) from k825_ids.
CREATE FUNCTION pg_temp.k825_id(p text) RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT (to_jsonb(i) ->> p)::uuid FROM pg_temp.k825_ids i $f$;
CREATE FUNCTION pg_temp.k825_sql(p text) RETURNS text LANGUAGE plpgsql STABLE AS $f$
DECLARE k text; s text := p;
BEGIN
  FOR k IN SELECT jsonb_object_keys(to_jsonb(i)) FROM pg_temp.k825_ids i ORDER BY length(jsonb_object_keys(to_jsonb(i))) DESC LOOP
    s := replace(s, ':' || k, quote_literal(pg_temp.k825_id(k)) || '::uuid');
  END LOOP;
  RETURN s;
END $f$;

CREATE FUNCTION pg_temp.k825_phase(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c record; f text; frz uuid[];
BEGIN
  FOR c IN SELECT * FROM pg_temp.k825_cases ORDER BY ord LOOP
    frz := '{}';
    FOREACH f IN ARRAY c.frz LOOP frz := frz || pg_temp.k825_id(f); END LOOP;
    INSERT INTO pg_temp.k825_res VALUES (p_phase, c.kind, c.name,
      pg_temp.k825_run(c.role, pg_temp.k825_id(c.sub), pg_temp.k825_sql(c.sql), frz, c.policy));
  END LOOP;
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'KAN-825: role leaked out of a case (%)', current_user; END IF;
END $f$;

CREATE FUNCTION pg_temp.k825_snapshot(p_phase text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO pg_temp.k825_cat
  SELECT p_phase, 'proc', p.oid::regprocedure::text,
         concat_ws(' | ', 'args=' || pg_get_function_arguments(p.oid), 'idargs=' || pg_get_function_identity_arguments(p.oid),
                   'argtypes=' || p.proargtypes::text, 'ret=' || pg_get_function_result(p.oid), 'rettype=' || p.prorettype::regtype::text,
                   'retset=' || p.proretset, 'lang=' || l.lanname, 'secdef=' || p.prosecdef, 'vol=' || p.provolatile::text,
                   'strict=' || p.proisstrict, 'parallel=' || p.proparallel::text, 'config=' || coalesce(p.proconfig::text, 'NULL'),
                   'owner=' || pg_get_userbyid(p.proowner), 'acl=' || coalesce(p.proacl::text, 'NULL'),
                   'comment=' || coalesce(obj_description(p.oid, 'pg_proc'), 'NULL'))
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
   WHERE p.oid IN ('public.kan803_game_host_uid(uuid)'::regprocedure, 'public.kan804_game_event_facts(uuid)'::regprocedure,
                   'public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                   'public.trgfn_waitlist_block_frozen_guard()'::regprocedure, 'public.trgfn_roster_block_frozen_guard()'::regprocedure,
                   'public.trgfn_posts_set_geo()'::regprocedure)
  UNION ALL
  SELECT p_phase, 'body', p.oid::regprocedure::text, md5(p.prosrc)
    FROM pg_proc p
   WHERE p.oid IN ('public.kan803_game_host_uid(uuid)'::regprocedure, 'public.kan804_game_event_facts(uuid)'::regprocedure,
                   'public.trgfn_invite_block_frozen_guard()'::regprocedure, 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                   'public.trgfn_waitlist_block_frozen_guard()'::regprocedure, 'public.trgfn_roster_block_frozen_guard()'::regprocedure,
                   'public.trgfn_posts_set_geo()'::regprocedure)
  UNION ALL
  SELECT p_phase, 'trigger', t.tgrelid::regclass::text || '.' || t.tgname,
         concat_ws(' | ', 'oid=' || t.oid, 'fn=' || t.tgfoid::regprocedure::text, 'type=' || t.tgtype, 'enabled=' || t.tgenabled::text,
                   pg_get_triggerdef(t.oid))
    FROM pg_trigger t
   WHERE NOT t.tgisinternal AND t.tgfoid IN ('public.trgfn_invite_block_frozen_guard()'::regprocedure,
         'public.trgfn_joinreq_block_frozen_guard()'::regprocedure, 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure)
$f$;

-- Parity: ids where the two helpers disagree, over every games row plus S1, S3, S4, U and NULL.
CREATE FUNCTION pg_temp.k825_parity() RETURNS text LANGUAGE sql AS $f$
  SELECT string_agg(coalesce(x.id::text, 'NULL') || '=' || coalesce(public.kan803_game_host_uid(x.id)::text, 'null')
                    || '/' || coalesce((SELECT f.creator_user_id FROM public.kan804_game_event_facts(x.id) f)::text, 'null'), ', ')
    FROM (SELECT id FROM public.games UNION ALL SELECT unknown FROM pg_temp.k825_ids UNION ALL SELECT NULL::uuid) x
   WHERE public.kan803_game_host_uid(x.id) IS DISTINCT FROM (SELECT f.creator_user_id FROM public.kan804_game_event_facts(x.id) f)
$f$;
CREATE FUNCTION pg_temp.k825_parity_check(p_tag text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE x text; n bigint;
BEGIN
  x := pg_temp.k825_parity();
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-825 % FAIL: kan803_game_host_uid <> kan804_game_event_facts.creator_user_id for %', p_tag, x; END IF;
  SELECT count(*) + 2 INTO n FROM public.games;
  RAISE NOTICE 'KAN-825 % PASS: the two helpers agree on all % ids (every games row, S1, S3, S4, unknown, NULL)', p_tag, n;
END $f$;

-- ---------------------------------------------------------------------------------------------------------
-- PRE
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.k825_parity_check('T0 parity pre');

\echo '== T0n negative control: the parity probe against a wrong helper (no event_type filter), rolled back'
DO $t0n$ DECLARE x text; BEGIN
  BEGIN
    EXECUTE $b$CREATE OR REPLACE FUNCTION public.kan803_game_host_uid(p_game_id uuid) RETURNS uuid LANGUAGE sql STABLE
      SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
      select e.creator_user_id from public.games g join public.events e on e.id = g.event_id where g.id = p_game_id $$$b$;
    x := pg_temp.k825_parity();
    RAISE EXCEPTION 'k825_rollback' USING DETAIL = coalesce(x, '<none>');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k825_rollback' THEN RAISE; END IF;
    GET STACKED DIAGNOSTICS x = PG_EXCEPTION_DETAIL;
  END;
  RAISE NOTICE 'KAN-825 T0n mismatches reported by the probe: %', x;
  IF x NOT LIKE '%82500000-0000-0000-0000-000000000003=00000000-0000-0000-0000-0000000000a7/null%' THEN
    RAISE EXCEPTION 'KAN-825 T0n FAIL: the parity probe did not catch the wrong helper on S3';
  END IF;
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure)) <> '3e6e858b0fb1d80d09e2db2a9bfe770b' THEN
    RAISE EXCEPTION 'KAN-825 T0n: pre-image body not restored';
  END IF;
  RAISE NOTICE 'KAN-825 T0n PASS (probe seen failing): the wrong helper is caught on S3; pre-image restored';
END $t0n$;

SELECT pg_temp.k825_snapshot('pre');
SELECT pg_temp.k825_phase('pre');
DO $t0e$ DECLARE x text; BEGIN
  SELECT string_agg(c.name || ' got [' || r.outcome || '] want [' || c.expect || ']', '; ' ORDER BY c.ord) INTO x
    FROM pg_temp.k825_cases c JOIN pg_temp.k825_res r ON r.phase = 'pre' AND r.kind = c.kind AND r.name = c.name
   WHERE r.outcome IS DISTINCT FROM c.expect;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-825 T0e FAIL: pre-image outcomes differ from the expected matrix: %', x; END IF;
  RAISE NOTICE 'KAN-825 T0e PASS: all % pre-image cases match the expected matrix (frozen host blocks, non-frozen inserts)',
    (SELECT count(*) FROM pg_temp.k825_res WHERE phase = 'pre');
END $t0e$;

-- ---------------------------------------------------------------------------------------------------------
-- MIGRATION
-- ---------------------------------------------------------------------------------------------------------
SELECT (:skip_migration)::int = 1 AS k825_skip \gset
\if :k825_skip
  \echo '== RED RUN: -v skip_migration=1, 20261105150000 NOT applied'
\else
  \echo '== apply 20261105150000_kan825_helper_consolidation.sql'
  \i supabase/migrations/20261105150000_kan825_helper_consolidation.sql
\endif
\echo '== post-image body of kan803_game_host_uid'
SELECT pg_get_functiondef('public.kan803_game_host_uid(uuid)'::regprocedure) AS post_image;

-- ---------------------------------------------------------------------------------------------------------
-- POST
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.k825_snapshot('post');
SELECT pg_temp.k825_phase('post');

DO $t1$ DECLARE s text := (SELECT prosrc FROM pg_proc WHERE oid = 'public.kan803_game_host_uid(uuid)'::regprocedure); BEGIN
  IF s !~ 'public\.kan804_game_event_facts\(p_game_id\)' OR s ~* 'public\.events' OR s ~* 'public\.games' THEN
    RAISE EXCEPTION 'KAN-825 T1 FAIL: kan803_game_host_uid does not read through kan804_game_event_facts (body: %)', s;
  END IF;
  RAISE NOTICE 'KAN-825 T1 PASS: kan803_game_host_uid reads only through public.kan804_game_event_facts';
END $t1$;

SELECT pg_temp.k825_parity_check('T2 parity post');

\echo '== T3 catalogue pre vs post (kan803_game_host_uid body is the only expected difference)'
SELECT coalesce(a.kind, b.kind) AS kind, coalesce(a.name, b.name) AS name, (a.attrs IS NOT DISTINCT FROM b.attrs) AS equal
  FROM (SELECT * FROM pg_temp.k825_cat WHERE phase = 'pre') a
  FULL JOIN (SELECT * FROM pg_temp.k825_cat WHERE phase = 'post') b ON b.kind = a.kind AND b.name = a.name
 ORDER BY 1, 2;
DO $t3$ DECLARE x text; BEGIN
  SELECT string_agg(coalesce(a.kind, b.kind) || ':' || coalesce(a.name, b.name), ', ') INTO x
    FROM (SELECT * FROM pg_temp.k825_cat WHERE phase = 'pre') a
    FULL JOIN (SELECT * FROM pg_temp.k825_cat WHERE phase = 'post') b ON b.kind = a.kind AND b.name = a.name
   WHERE a.attrs IS DISTINCT FROM b.attrs AND NOT (coalesce(a.kind, b.kind) = 'body' AND coalesce(a.name, b.name) = 'kan803_game_host_uid(uuid)');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-825 T3 FAIL: changed: %', x; END IF;
  IF (SELECT count(*) FROM pg_temp.k825_cat WHERE phase = 'pre' AND kind = 'proc') <> 7
     OR (SELECT count(*) FROM pg_temp.k825_cat WHERE phase = 'pre' AND kind = 'trigger') <> 3 THEN
    RAISE EXCEPTION 'KAN-825 T3 FAIL: expected 7 functions and 3 triggers in the snapshot';
  END IF;
  IF (SELECT attrs FROM pg_temp.k825_cat WHERE phase = 'post' AND kind = 'proc' AND name = 'kan803_game_host_uid(uuid)')
     NOT LIKE '%secdef=true | vol=s | strict=false | parallel=u | config={"search_path=public, pg_temp"} | owner=postgres | acl={postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}%' THEN
    RAISE EXCEPTION 'KAN-825 T3 FAIL: kan803_game_host_uid attributes are not the KAN-803 ones';
  END IF;
  IF (SELECT attrs FROM pg_temp.k825_cat WHERE phase = 'post' AND kind = 'body' AND name = 'kan803_game_host_uid(uuid)')
     IS NOT DISTINCT FROM (SELECT attrs FROM pg_temp.k825_cat WHERE phase = 'pre' AND kind = 'body' AND name = 'kan803_game_host_uid(uuid)') THEN
    RAISE EXCEPTION 'KAN-825 T3 FAIL: kan803_game_host_uid body unchanged';
  END IF;
  RAISE NOTICE 'KAN-825 T3 PASS: signature, result, prosecdef, proconfig, proacl, owner, comment of 7 functions and 3 trigger rows unchanged; only the kan803_game_host_uid body changed';
END $t3$;

\echo '== T4 / T5 outcome per case, pre vs post'
SELECT c.ord, c.kind, c.name, a.outcome AS pre, (a.outcome = b.outcome) AS post_equal
  FROM pg_temp.k825_cases c
  JOIN pg_temp.k825_res a ON a.phase = 'pre'  AND a.kind = c.kind AND a.name = c.name
  JOIN pg_temp.k825_res b ON b.phase = 'post' AND b.kind = c.kind AND b.name = c.name
 ORDER BY c.ord;
DO $t45$ DECLARE x text; n int := (SELECT count(*) FROM pg_temp.k825_cases); BEGIN
  SELECT string_agg(c.name || ' pre [' || coalesce(a.outcome, 'missing') || '] post [' || coalesce(b.outcome, 'missing') || ']', '; ' ORDER BY c.ord) INTO x
    FROM pg_temp.k825_cases c
    LEFT JOIN pg_temp.k825_res a ON a.phase = 'pre'  AND a.kind = c.kind AND a.name = c.name
    LEFT JOIN pg_temp.k825_res b ON b.phase = 'post' AND b.kind = c.kind AND b.name = c.name
   WHERE a.outcome IS DISTINCT FROM b.outcome OR b.outcome IS DISTINCT FROM c.expect;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-825 T4/T5 FAIL: %', x; END IF;
  RAISE NOTICE 'KAN-825 T4 PASS: % trigger cases (invite, joinreq, joinreq as authenticated, waitlist; frozen and non-frozen host) identical before and after',
    (SELECT count(*) FROM pg_temp.k825_cases WHERE kind = 'trigger');
  RAISE NOTICE 'KAN-825 T5 PASS: % direct helper calls (postgres, service_role, authenticated, anon) identical before and after',
    (SELECT count(*) FROM pg_temp.k825_cases WHERE kind = 'helper');
END $t45$;

\echo 'KAN-825: ALL PASS'
