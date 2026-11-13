-- KAN-857 (KAN-718 F4): rpc_meetup_visible() converted off the Z01-dropped meetups columns.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY (the guard refuses a Supabase database). Everything runs in one transaction
-- that ROLLS BACK; nothing persists.
--
-- Viewer classes (seed of supabase/tests/events_p2_kan713/local_harness_kan713.sql; owner a1 creates every
-- seeded meetup): owner a1, attendee a4 (going on all five), invitee a7 (pending invite to M-invite),
-- blocked a6 (a1 blocks a6), anon, unrelated user ...dead. service_role is probed as well.
--
--   C2a  pre-image, before Z01: the baseline body raises for every viewer (it reads columns meetups never had).
--        The reference for "same visibility" is therefore meetups RLS itself, the decider the pre-image names:
--        ORACLE = (id, title, start_at, listing_visibility, creator_user_id) FROM public.meetups, per viewer.
--        The oracle is shown to discriminate (owner, anon and blocked see different sets).
--   C4a  ACL (anon / authenticated / service_role / PUBLIC EXECUTE), prosecdef, proconfig before the migration.
--   C2b  new body, before Z01: rpc_meetup_visible() rows = ORACLE for every viewer.
--   C4b  the same attributes after the migration: identical.
--   C1   pg_get_functiondef of the new body: no public.meetups / public.games relation, and every value it reads
--        comes from public.events through kan718_meetups_compat.
--   Z01  every ALTER/DROP statement of 20261105100000 run in file order, each in its own savepoint (as
--        kan719_z01_removal_test.sql Z4); title, start_at, listing_visibility, creator_user_id must be gone.
--   C3r  RED after Z01: the pre-image raises; the pre-image with its column names corrected to the CURRENT
--        meetups columns (the obvious non-conversion) also raises 42703. Both rolled back to a savepoint.
--   C3g  GREEN after Z01: new body rows = the pre-Z01 ORACLE for every viewer, and its ids = meetups RLS ids now.
--
-- Run (repository root), on the k788 database of supabase/tests/events_p2/build_kan788.sh (KAN-710..713 + B01/B02):
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan718_f4_rpc_meetup_visible_test.sql
-- RED run of C2b (migration not applied): add  -v premig_only=1
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-857: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|kan857)' THEN
    RAISE EXCEPTION 'KAN-857: database % is not a throwaway k788/kan857 database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-857: run as a superuser'; END IF;
  IF to_regclass('public.kan718_meetups_compat') IS NOT NULL THEN RAISE EXCEPTION 'KAN-857: D05 views already applied; use a fresh DB'; END IF;
END $g$;

BEGIN;
\i supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql

-- Pre-image, verbatim from the baseline (the harness does not carry it). Owner and grants as baseline 14050 / 36535-36537.
SET check_function_bodies = off;
\set preimage `sed -n '14040,14047p' supabase/migrations/20260829080500_baseline_schema.sql`
:preimage
RESET check_function_bodies;
ALTER FUNCTION public.rpc_meetup_visible() OWNER TO postgres;
GRANT ALL ON FUNCTION public.rpc_meetup_visible() TO anon, authenticated, service_role;
CREATE TEMP TABLE k857_preimage AS SELECT pg_get_functiondef('public.rpc_meetup_visible()'::regprocedure) AS def;

-- Runs p_sql (returning one text) as an API role; p_uid NULL = no JWT. An error is returned as 'ERR <sqlstate>'.
CREATE FUNCTION pg_temp.k857_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO r;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    r := 'ERR ' || SQLSTATE;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN r; END $f$;

CREATE TEMP TABLE k857_who(ord int, label text, role text, uid uuid);
INSERT INTO k857_who VALUES
  (1, 'owner',     'authenticated', '00000000-0000-0000-0000-0000000000a1'),
  (2, 'attendee',  'authenticated', '00000000-0000-0000-0000-0000000000a4'),
  (3, 'invitee',   'authenticated', '00000000-0000-0000-0000-0000000000a7'),
  (4, 'blocked',   'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  (5, 'anon',      'anon',          NULL),
  (6, 'unrelated', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  (7, 'service_role', 'service_role', NULL);
CREATE TEMP TABLE k857_q(k text, sql text);
INSERT INTO k857_q VALUES
  ('rpc',     'SELECT count(*) || '':'' || coalesce(md5(string_agg(row(t.id, t.title, t.starts_at, t.visibility, t.owner_user_id)::text, ''|'' ORDER BY t.id)), ''-'') FROM public.rpc_meetup_visible() t'),
  ('rpc_ids', 'SELECT count(*) || '':'' || coalesce(md5(string_agg(t.id::text, '','' ORDER BY t.id)), ''-'') FROM public.rpc_meetup_visible() t'),
  ('oracle',  'SELECT count(*) || '':'' || coalesce(md5(string_agg(row(m.id, m.title, m.start_at, m.listing_visibility, m.creator_user_id)::text, ''|'' ORDER BY m.id)), ''-'') FROM public.meetups m'),
  ('rls_ids', 'SELECT count(*) || '':'' || coalesce(md5(string_agg(m.id::text, '','' ORDER BY m.id)), ''-'') FROM public.meetups m'),
  ('seed5',   'SELECT coalesce(string_agg(m.title, '','' ORDER BY m.title), ''-'') FROM public.meetups m WHERE m.id::text LIKE ''71300000-0000-0000-0000-0000000001%''');
CREATE TEMP TABLE k857_snap(phase text, k text, who text, res text);
CREATE FUNCTION pg_temp.k857_snap(p_phase text, p_keys text[]) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE w record; q record; BEGIN
  FOR w IN SELECT * FROM k857_who ORDER BY ord LOOP FOR q IN SELECT * FROM k857_q WHERE k = ANY (p_keys) LOOP
    INSERT INTO k857_snap VALUES (p_phase, q.k, w.label, pg_temp.k857_as(w.role, w.uid, q.sql));
  END LOOP; END LOOP; END $f$;
CREATE FUNCTION pg_temp.k857_attrs() RETURNS text LANGUAGE sql AS $f$
  SELECT format('anon=%s authenticated=%s service_role=%s PUBLIC=%s prosecdef=%s proconfig=%s owner=%s',
                has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE'),
                has_function_privilege('service_role', p.oid, 'EXECUTE'),
                EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'),
                p.prosecdef, p.proconfig, p.proowner::regrole)
    FROM pg_proc p WHERE p.oid = 'public.rpc_meetup_visible()'::regprocedure $f$;

-- C2a ----------------------------------------------------------------------------------------------------------
SELECT pg_temp.k857_snap('pre', ARRAY['rpc', 'oracle', 'rls_ids', 'seed5']);
\echo '== C2a pre-image, before Z01 (rpc = pre-image result; oracle = meetups RLS rows; seed5 = which seeded meetups RLS shows)'
SELECT w.label, s1.res AS rpc_preimage, s2.res AS oracle, s3.res AS seed5
  FROM k857_who w JOIN k857_snap s1 ON s1.who = w.label AND s1.phase = 'pre' AND s1.k = 'rpc'
  JOIN k857_snap s2 ON s2.who = w.label AND s2.phase = 'pre' AND s2.k = 'oracle'
  JOIN k857_snap s3 ON s3.who = w.label AND s3.phase = 'pre' AND s3.k = 'seed5' ORDER BY w.ord;
DO $c2a$ DECLARE n int; BEGIN
  IF EXISTS (SELECT 1 FROM k857_snap WHERE phase = 'pre' AND k = 'rpc' AND res <> 'ERR 42703') THEN
    RAISE EXCEPTION 'KAN-857 C2a FAIL: the pre-image did not raise 42703 for every viewer';
  END IF;
  IF EXISTS (SELECT 1 FROM k857_snap WHERE phase = 'pre' AND k IN ('oracle', 'rls_ids', 'seed5') AND res LIKE 'ERR%') THEN
    RAISE EXCEPTION 'KAN-857 C2a FAIL: the oracle itself errors';
  END IF;
  SELECT count(DISTINCT res) INTO n FROM k857_snap WHERE phase = 'pre' AND k = 'seed5';
  IF n < 3
     OR (SELECT res FROM k857_snap WHERE phase = 'pre' AND k = 'seed5' AND who = 'owner') !~ 'M-hidden'
     OR (SELECT res FROM k857_snap WHERE phase = 'pre' AND k = 'seed5' AND who = 'anon') ~ 'M-circle|M-hidden'
     OR (SELECT res FROM k857_snap WHERE phase = 'pre' AND k = 'seed5' AND who = 'blocked') ~ 'M-public' THEN
    RAISE EXCEPTION 'KAN-857 C2a FAIL: the oracle does not discriminate the viewer classes (% distinct)', n;
  END IF;
  RAISE NOTICE 'KAN-857 C2a PASS: pre-image raises 42703 for all 7 viewers; oracle (meetups RLS) gives % distinct seeded sets', n;
END $c2a$;

-- C4a + migration ----------------------------------------------------------------------------------------------
CREATE TEMP TABLE k857_attr AS SELECT 'before'::text AS phase, pg_temp.k857_attrs() AS a;
\if :{?premig_only}
\echo '== premig_only: migration NOT applied (RED run of C2b)'
\else
\i supabase/migrations/20261105130500_kan718_f4_rpc_meetup_visible.sql
\endif
INSERT INTO k857_attr SELECT 'after', pg_temp.k857_attrs();
\echo '== C4 attributes before / after the migration'
SELECT phase, a FROM k857_attr ORDER BY phase DESC;

-- C2b ----------------------------------------------------------------------------------------------------------
SELECT pg_temp.k857_snap('new', ARRAY['rpc', 'rpc_ids']);
\echo '== C2b new body, before Z01: rpc vs oracle per viewer'
SELECT w.label, o.res AS oracle, n.res AS rpc_new, o.res = n.res AS same
  FROM k857_who w JOIN k857_snap o ON o.who = w.label AND o.phase = 'pre' AND o.k = 'oracle'
  JOIN k857_snap n ON n.who = w.label AND n.phase = 'new' AND n.k = 'rpc' ORDER BY w.ord;
DO $c2b$ DECLARE x text; BEGIN
  SELECT string_agg(o.who || ': ' || o.res || ' -> ' || n.res, '; ') INTO x
    FROM k857_snap o JOIN k857_snap n ON n.who = o.who AND n.phase = 'new' AND n.k = 'rpc'
   WHERE o.phase = 'pre' AND o.k = 'oracle' AND o.res IS DISTINCT FROM n.res;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-857 C2b FAIL: rpc_meetup_visible() differs from meetups RLS: %', x; END IF;
  RAISE NOTICE 'KAN-857 C2b PASS: rpc_meetup_visible() = meetups RLS rows for all 7 viewers before Z01';
END $c2b$;

DO $c4$ BEGIN
  IF (SELECT a FROM k857_attr WHERE phase = 'before') IS DISTINCT FROM (SELECT a FROM k857_attr WHERE phase = 'after') THEN
    RAISE EXCEPTION 'KAN-857 C4 FAIL: ACL / SECURITY mode / proconfig / owner changed';
  END IF;
  RAISE NOTICE 'KAN-857 C4 PASS: EXECUTE for anon/authenticated/service_role/PUBLIC, prosecdef, proconfig and owner unchanged';
END $c4$;

-- C1 -----------------------------------------------------------------------------------------------------------
\echo '== C1 pg_get_functiondef (new body)'
SELECT pg_get_functiondef('public.rpc_meetup_visible()'::regprocedure) AS def \gset
\echo :def
DO $c1$ DECLARE d text := pg_get_functiondef('public.rpc_meetup_visible()'::regprocedure); v text := pg_get_viewdef('public.kan718_meetups_compat'::regclass); BEGIN
  IF d ~ '(public\.meetups|public\.games|\mm\.)' THEN RAISE EXCEPTION 'KAN-857 C1 FAIL: body reads meetups/games'; END IF;
  IF d !~* 'from public\.kan718_meetups_compat c' THEN RAISE EXCEPTION 'KAN-857 C1 FAIL: body does not read kan718_meetups_compat'; END IF;
  IF v !~ 'e\.title' OR v !~ 'e\.start_at' OR v !~ 'e\.listing_visibility' OR v !~ 'e\.creator_user_id' OR v !~ 'JOIN events e' THEN
    RAISE EXCEPTION 'KAN-857 C1 FAIL: kan718_meetups_compat does not source title/start_at/listing_visibility/creator_user_id from events';
  END IF;
  RAISE NOTICE 'KAN-857 C1 PASS: no public.meetups / public.games read; c.title, c.start_at, c.listing_visibility, c.creator_user_id are events columns via kan718_meetups_compat';
END $c1$;

-- Z01 ----------------------------------------------------------------------------------------------------------
\set migtext `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TEMP TABLE k857_z01 AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM (SELECT :'migtext'::text AS src) s, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);
SET CONSTRAINTS ALL IMMEDIATE;
DO $z01$ DECLARE r record; ok int := 0; failed text := ''; gone text; BEGIN
  FOR r IN SELECT * FROM k857_z01 ORDER BY ord LOOP
    BEGIN EXECUTE r.stmt; ok := ok + 1;
    EXCEPTION WHEN OTHERS THEN failed := failed || ' ' || r.seq; END;
  END LOOP;
  SELECT string_agg(c, ',') INTO gone FROM unnest(ARRAY['title', 'start_at', 'listing_visibility', 'creator_user_id']) c
   WHERE EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attname = c AND NOT attisdropped);
  IF gone IS NOT NULL THEN RAISE EXCEPTION 'KAN-857 Z01 FAIL: meetups still has %', gone; END IF;
  RAISE NOTICE 'KAN-857 Z01 applied: % of % statements ran; not run (baseline-only objects / held homeless columns):%', ok, (SELECT count(*) FROM k857_z01), failed;
END $z01$;
\echo '== meetups columns after Z01'
SELECT string_agg(attname, ', ' ORDER BY attnum) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped;

-- C3r ----------------------------------------------------------------------------------------------------------
SAVEPOINT c3r;
SET check_function_bodies = off;
:preimage
SELECT pg_temp.k857_snap('red_preimage', ARRAY['rpc']);
CREATE OR REPLACE FUNCTION public.rpc_meetup_visible()
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, visibility text, owner_user_id uuid)
 LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $$ select m.id, m.title, m.start_at, m.listing_visibility, m.creator_user_id from public.meetups m order by m.start_at $$;
SELECT pg_temp.k857_snap('red_columns_fixed', ARRAY['rpc']);
RESET check_function_bodies;
-- carry the RED results across the rollback (the savepoint discards the bodies and the snapshot rows alike)
SELECT string_agg(format('(%L, %L, %L, %L)', phase, k, who, res), ', ') AS red_rows FROM k857_snap WHERE phase LIKE 'red%' \gset
ROLLBACK TO SAVEPOINT c3r;
INSERT INTO k857_snap VALUES :red_rows;
\echo '== C3 RED after Z01 (pre-image; pre-image with current meetups column names)'
SELECT w.label, a.res AS preimage, b.res AS columns_fixed
  FROM k857_who w JOIN k857_snap a ON a.who = w.label AND a.phase = 'red_preimage'
  JOIN k857_snap b ON b.who = w.label AND b.phase = 'red_columns_fixed' ORDER BY w.ord;
DO $c3r$ BEGIN
  IF EXISTS (SELECT 1 FROM k857_snap WHERE phase IN ('red_preimage', 'red_columns_fixed') AND res <> 'ERR 42703')
     OR (SELECT count(*) FROM k857_snap WHERE phase IN ('red_preimage', 'red_columns_fixed')) <> 14 THEN
    RAISE EXCEPTION 'KAN-857 C3 RED FAIL: a non-converted body survived Z01';
  END IF;
  RAISE NOTICE 'KAN-857 C3 RED PASS: after Z01 both non-converted bodies raise 42703 for all 7 viewers';
END $c3r$;

-- C3g ----------------------------------------------------------------------------------------------------------
SELECT pg_temp.k857_snap('post', ARRAY['rpc', 'rpc_ids', 'rls_ids']);
\echo '== C3 GREEN after Z01: pre-Z01 oracle vs new body; meetups RLS ids now vs new body ids'
SELECT w.label, o.res AS oracle_pre_z01, n.res AS rpc_post_z01, o.res = n.res AS same_rows,
       l.res AS rls_ids_post_z01, i.res AS rpc_ids_post_z01, l.res = i.res AS same_ids
  FROM k857_who w
  JOIN k857_snap o ON o.who = w.label AND o.phase = 'pre'  AND o.k = 'oracle'
  JOIN k857_snap n ON n.who = w.label AND n.phase = 'post' AND n.k = 'rpc'
  JOIN k857_snap l ON l.who = w.label AND l.phase = 'post' AND l.k = 'rls_ids'
  JOIN k857_snap i ON i.who = w.label AND i.phase = 'post' AND i.k = 'rpc_ids' ORDER BY w.ord;
DO $c3g$ DECLARE x text; BEGIN
  SELECT string_agg(o.who, ', ') INTO x
    FROM k857_snap o
    JOIN k857_snap n ON n.who = o.who AND n.phase = 'post' AND n.k = 'rpc'
    JOIN k857_snap l ON l.who = o.who AND l.phase = 'post' AND l.k = 'rls_ids'
    JOIN k857_snap i ON i.who = o.who AND i.phase = 'post' AND i.k = 'rpc_ids'
    JOIN k857_snap p ON p.who = o.who AND p.phase = 'pre'  AND p.k = 'rls_ids'
   WHERE o.phase = 'pre' AND o.k = 'oracle'
     AND (o.res IS DISTINCT FROM n.res OR l.res IS DISTINCT FROM i.res OR p.res IS DISTINCT FROM l.res OR n.res LIKE 'ERR%');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-857 C3 GREEN FAIL for: %', x; END IF;
  RAISE NOTICE 'KAN-857 C3 GREEN PASS: after Z01 rpc_meetup_visible() = pre-Z01 meetups RLS rows and = meetups RLS ids now, all 7 viewers';
END $c3g$;

ROLLBACK;
\echo 'KAN-857: ALL PASS (rolled back)'
