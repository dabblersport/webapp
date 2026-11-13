-- SUPERSEDED 2026-11-13 by KAN-718 (20261113052351_kan718_writers_update.sql): the T3 post-image md5 below is the
-- KAN-913 body; live is now the KAN-718 body. Point-in-time proof of its own migration; the current proof is
-- kan718_writers_equality_live_test.sql.
-- KAN-913: proof for supabase/migrations/20261111121500_kan714_w_rpc_cancel_game_kan712_inner.sql.
--
-- LOCAL THROWAWAY DATABASES ONLY. The guard refuses anything that looks like Supabase, a non-local server address and
-- any database whose name does not start with k913. Never point this at a hosted project.
--
-- TAP output (ok / not ok lines, plan 1..7). pgTAP is not installed on the local toolchain, so the assertions are plain
-- SQL that print TAP; any "not ok" makes the last statement raise, so psql exits non-zero.
--
-- Precondition: the tracked chain built by supabase/tests/events_p4/build_kan810.sh (database k810, with the fixtures
-- of local_seed_kan711.sql: games G 71300000-...-0001 and G2 ...-0002, host a1, a2 not admin, a3 admin), then
-- 20261104112000_kan810_cancel_game_idempotent.sql applied, so the inner is the KAN-810 post-image
-- (md5(prosrc) f5b4c52d...). No later migration redefines rpc_cancel_game / rpc_cancel_game_kan712_inner.
-- build_kan810.sh is run from a `git archive HEAD supabase scripts` export with B03 taken from fbae534e^ and B06 from
-- cdc1810b^, exactly as kan887_part2_after_kan794_test.sh does (the HEAD order check refuses on rpc_meetup_my).
-- Each run uses a fresh copy:  CREATE DATABASE k913_<x> TEMPLATE <k810 + KAN-810>;
-- Run from the repository root:
--   psql -X -h /tmp -p <port> -U postgres -d k913_<x> -P pager=off \
--        -f supabase/tests/events_p4/kan714_w_rpc_cancel_game_kan712_inner_test.sql
-- RED evidence: add -v red_file=<path> to apply that file INSTEAD of the migration (e.g. the KAN-810 rollback block,
-- which restores the pre-KAN-810 body that rewrites a repeat cancel); T3 and T5 must then report "not ok".
--
-- METHOD. One scenario (seven calls through the public wrapper, as the API calls it) runs twice on identical inputs:
-- once on the pre-image, inside a transaction that is rolled back, its capture carried out in a psql variable; then
-- the migration is applied; then again on the post-image. Captured per step: the call's result (or ERR sqlstate
-- message) and the full games and events rows of G and G2 plus their notification / msg_system_lines counts. A
-- timestamp equal to now() is recorded as "NOW" (each run is one transaction, so now() differs between runs only).
--   S1 host a1 cancels G 'r1'            R1 host a1 repeats on G 'r2'       A1 admin a3 repeats on G 'r3'
--   N1 non-host a2 cancels G (cancelled) N2 a1 cancels a missing game       N3 non-host a2 cancels live G2
--   A2 admin a3 cancels live G2 'r4'
--   T1 inner is the pre-image before (md5(prosrc) f5b4c52d331cc03f6d6a7ae806cd3f36)
--   T2 the pre-image run reached every branch: cancelled x3 on G, P0001 x3, admin first cancel on G2
--   T3 inner is the post-image after (md5(prosrc) 39f496234ef7fd35295ab0ab4740f703)
--   T4 the legacy-read probe (the migration's two post-condition expressions) fires on the pre-image body, not the post
--   T5 pre-run capture EXCEPT post-run capture, both ways, is empty
--   T6 the capture compared is not empty (7 steps x 7 keys = 49 rows in each run)
--   T7 owner, ACL, SECURITY DEFINER, volatility, search_path, arguments and result of both functions unchanged
\set ON_ERROR_STOP 1
SET client_min_messages = warning;
\set G   '''71300000-0000-0000-0000-000000000001'''
\set G2  '''71300000-0000-0000-0000-000000000002'''
\set GX  '''71300000-0000-0000-0000-0000000000ff'''
\set a1  '''00000000-0000-0000-0000-0000000000a1'''
\set a2  '''00000000-0000-0000-0000-0000000000a2'''
\set a3  '''00000000-0000-0000-0000-0000000000a3'''

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('supabase_admin', 'supabase_auth_admin', 'authenticator'))
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions', 'vault', 'graphql')) THEN
    RAISE EXCEPTION 'KAN-913 test: this looks like a Supabase database; refusing';
  END IF;
  IF current_database() !~ '^k913' THEN
    RAISE EXCEPTION 'KAN-913 test: database % does not start with k913; refusing', current_database();
  END IF;
  IF inet_server_addr() IS NOT NULL AND NOT (inet_server_addr() << '127.0.0.0/8'::inet OR inet_server_addr() = '::1'::inet) THEN
    RAISE EXCEPTION 'KAN-913 test: server address % is not local; refusing', inet_server_addr();
  END IF;
END $g$;

CREATE TEMP TABLE k913_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL);
CREATE TEMP TABLE k913_cap (run text, k text, v text);
CREATE TEMP TABLE k913_attr (run text, sig text, a text);

-- as_(role, uid, sql): run sql as role with auth.uid() = uid; its text result, or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text; m text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE;
    v := 'ERR ' || s || ' ' || m;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('kan712.contract', '', true);
  PERFORM set_config('kan712.routing', '', true);
  PERFORM set_config('kan712.compat', '', true);
  RETURN coalesce(v, '<null>');
END $$;
-- A row as jsonb text, any value equal to now() recorded as "NOW".
CREATE FUNCTION pg_temp.norm(j jsonb) RETURNS text LANGUAGE sql AS $$
  SELECT coalesce((SELECT jsonb_object_agg(key, CASE WHEN value = to_jsonb(now()) THEN '"NOW"'::jsonb ELSE value END)
                     FROM jsonb_each(j))::text, '<none>') $$;
-- Snapshot after a step: games row, events row, notification count, system-line count for G and G2.
CREATE FUNCTION pg_temp.snap(p_run text, p_step text, p_res text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE gid uuid; tag text;
BEGIN
  INSERT INTO k913_cap VALUES (p_run, p_step || ' result', p_res);
  FOR gid, tag IN SELECT * FROM (VALUES ('71300000-0000-0000-0000-000000000001'::uuid, 'G'),
                                        ('71300000-0000-0000-0000-000000000002'::uuid, 'G2')) t LOOP
    INSERT INTO k913_cap SELECT p_run, p_step || ' games ' || tag, pg_temp.norm((SELECT to_jsonb(g) FROM public.games g WHERE g.id = gid));
    INSERT INTO k913_cap SELECT p_run, p_step || ' events ' || tag,
      pg_temp.norm((SELECT to_jsonb(e) FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = gid));
    INSERT INTO k913_cap SELECT p_run, p_step || ' counts ' || tag,
      (SELECT count(*) FROM public.notifications WHERE entity_id = gid) || '|' ||
      (SELECT count(*) FROM public.msg_system_lines WHERE game_id = gid);
  END LOOP;
END $$;
CREATE FUNCTION pg_temp.scenario(p_run text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  G  uuid := '71300000-0000-0000-0000-000000000001'; G2 uuid := '71300000-0000-0000-0000-000000000002';
  GX uuid := '71300000-0000-0000-0000-0000000000ff';
  a1 uuid := '00000000-0000-0000-0000-0000000000a1'; a2 uuid := '00000000-0000-0000-0000-0000000000a2';
  a3 uuid := '00000000-0000-0000-0000-0000000000a3';
  c text := 'SELECT public.rpc_cancel_game(%L, %L)';
BEGIN
  PERFORM pg_temp.snap(p_run, '1 S1', pg_temp.as_('authenticated', a1, format(c, G,  'r1')));
  PERFORM pg_temp.snap(p_run, '2 R1', pg_temp.as_('authenticated', a1, format(c, G,  'r2')));
  PERFORM pg_temp.snap(p_run, '3 A1', pg_temp.as_('authenticated', a3, format(c, G,  'r3')));
  PERFORM pg_temp.snap(p_run, '4 N1', pg_temp.as_('authenticated', a2, format(c, G,  'rX')));
  PERFORM pg_temp.snap(p_run, '5 N2', pg_temp.as_('authenticated', a1, format(c, GX, 'r')));
  PERFORM pg_temp.snap(p_run, '6 N3', pg_temp.as_('authenticated', a2, format(c, G2, 'r')));
  PERFORM pg_temp.snap(p_run, '7 A2', pg_temp.as_('authenticated', a3, format(c, G2, 'r4')));
END $$;
-- The migration's two legacy-read probes on a body: a 22-column read qualified g. / games., or one unqualified outside
-- the unchanged UPDATE SET list (comments stripped). Same expressions as the migration's post-conditions.
CREATE FUNCTION pg_temp.legacy_reads(src text) RETURNS boolean LANGUAGE sql AS $$
  SELECT src ~* '(\mg|\mgames)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'
      OR regexp_replace(replace(src, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', ''),
                        '--[^\n]*', '', 'g') ~* '(^|[^.a-z0-9_])(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M' $$;
CREATE FUNCTION pg_temp.attrs(p_run text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO k913_attr
  SELECT p_run, p.oid::regprocedure::text,
         concat_ws('|', p.proowner::regrole, p.proacl, p.prosecdef, p.provolatile, p.proconfig,
                   pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prolang)
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner') $$;

-- Before
DO $x$ BEGIN PERFORM pg_temp.attrs('pre'); END $x$;
SELECT prosrc AS pre_src, md5(prosrc) AS pre_md5 FROM pg_proc
 WHERE oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)') \gset
INSERT INTO k913_tap VALUES (1, :'pre_md5' = 'f5b4c52d331cc03f6d6a7ae806cd3f36',
  'T1 inner is the pre-image before, md5(prosrc) ' || :'pre_md5');

-- Pre-image run (rolled back; the capture leaves in a psql variable)
BEGIN;
DO $x$ BEGIN PERFORM pg_temp.scenario('pre'); END $x$;
SELECT jsonb_agg(jsonb_build_array(k, v) ORDER BY k)::text AS pre_cap FROM k913_cap WHERE run = 'pre' \gset
ROLLBACK;

INSERT INTO k913_cap SELECT 'pre', x->>0, x->>1 FROM jsonb_array_elements(:'pre_cap'::jsonb) x;
INSERT INTO k913_tap VALUES (2,
  (SELECT string_agg(v, ' / ' ORDER BY k) FROM k913_cap WHERE run = 'pre' AND k LIKE '% result')
  = 'cancelled / cancelled / cancelled / ERR P0001 not_host_or_not_found / ERR P0001 not_host_or_not_found / '
    'ERR P0001 not_host_or_not_found / cancelled',
  'T2 pre-image run reached every branch: ' ||
  (SELECT string_agg(split_part(k, ' ', 2) || '=' || v, ', ' ORDER BY k) FROM k913_cap WHERE run = 'pre' AND k LIKE '% result'));

\if :{?red_file}
\echo '# red_file set: applying' :red_file 'INSTEAD of the migration (RED run)'
\i :red_file
\else
\i supabase/migrations/20261111121500_kan714_w_rpc_cancel_game_kan712_inner.sql
\endif

-- After
DO $x$ BEGIN PERFORM pg_temp.attrs('post'); END $x$;
SELECT prosrc AS post_src, md5(prosrc) AS post_md5 FROM pg_proc
 WHERE oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)') \gset

BEGIN;
DO $x$ BEGIN PERFORM pg_temp.scenario('post'); END $x$;
SELECT jsonb_agg(jsonb_build_array(k, v) ORDER BY k)::text AS post_cap FROM k913_cap WHERE run = 'post' \gset
ROLLBACK;
INSERT INTO k913_cap SELECT 'post', x->>0, x->>1 FROM jsonb_array_elements(:'post_cap'::jsonb) x;

INSERT INTO k913_tap VALUES (3, :'post_md5' = '39f496234ef7fd35295ab0ab4740f703',
  'T3 inner is the post-image after, md5(prosrc) ' || :'post_md5');
INSERT INTO k913_tap VALUES (4, pg_temp.legacy_reads(:'pre_src') AND NOT pg_temp.legacy_reads(:'post_src'),
  'T4 legacy-read probe: fires on pre-image body ' || pg_temp.legacy_reads(:'pre_src') || ', fires on post-image body '
  || pg_temp.legacy_reads(:'post_src'));
INSERT INTO k913_tap SELECT 5, NOT EXISTS (
    (SELECT k, v FROM k913_cap WHERE run = 'pre' EXCEPT SELECT k, v FROM k913_cap WHERE run = 'post')
    UNION ALL
    (SELECT k, v FROM k913_cap WHERE run = 'post' EXCEPT SELECT k, v FROM k913_cap WHERE run = 'pre')),
  'T5 pre-run capture EXCEPT post-run capture, both ways, empty (differing keys: ' || coalesce((SELECT string_agg(DISTINCT k, ', ')
     FROM ((SELECT k, v FROM k913_cap WHERE run = 'pre' EXCEPT SELECT k, v FROM k913_cap WHERE run = 'post')
           UNION ALL
           (SELECT k, v FROM k913_cap WHERE run = 'post' EXCEPT SELECT k, v FROM k913_cap WHERE run = 'pre')) d), 'none') || ')';
INSERT INTO k913_tap VALUES (6,
  (SELECT count(*) FROM k913_cap WHERE run = 'pre') = 49 AND (SELECT count(*) FROM k913_cap WHERE run = 'post') = 49
  AND (SELECT count(DISTINCT k) FROM k913_cap WHERE run = 'pre') = 49,
  'T6 capture compared is not empty: pre ' || (SELECT count(*) FROM k913_cap WHERE run = 'pre') || ' rows, post '
  || (SELECT count(*) FROM k913_cap WHERE run = 'post') || ' rows');
INSERT INTO k913_tap SELECT 7, (SELECT count(*) FROM k913_attr WHERE run = 'pre') = 2 AND NOT EXISTS (
    (SELECT sig, a FROM k913_attr WHERE run = 'pre' EXCEPT SELECT sig, a FROM k913_attr WHERE run = 'post')
    UNION ALL
    (SELECT sig, a FROM k913_attr WHERE run = 'post' EXCEPT SELECT sig, a FROM k913_attr WHERE run = 'pre')),
  'T7 attributes of both functions unchanged (' || (SELECT string_agg(sig || ' ' || a, '; ' ORDER BY sig)
     FROM k913_attr WHERE run = 'post') || ')';

\echo '# post-run results (games G after the last step, normalised):'
\pset tuples_only on
\pset format unaligned
SELECT '# ' || k || ' = ' || v FROM k913_cap WHERE run = 'post' AND (k LIKE '% result' OR k IN ('7 A2 games G', '7 A2 games G2'))
 ORDER BY k;
SELECT '1..7';
SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label FROM k913_tap ORDER BY n;
DO $end$ BEGIN
  IF EXISTS (SELECT 1 FROM k913_tap WHERE NOT ok) THEN
    RAISE EXCEPTION 'KAN-913: FAIL (% not ok)', (SELECT count(*) FROM k913_tap WHERE NOT ok);
  END IF;
END $end$;
SELECT '# KAN-913: ALL PASS';
