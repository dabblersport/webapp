-- KAN-778 (KAN-719 Z01, Epic KAN-708): the phase-4 removal migration, proven against the D06 manifest and a local DB.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- Nothing persists: every block that writes runs inside a transaction that rolls back. R1 proves it afterwards.
--
--   Z1  the migration's statements ARE the D06 manifest (k774_manifest, loaded from kan718_d06_manifest_check.sql):
--       63 entries (re-scoped by KAN-861 F8, CTO ruling dreq-0f6e9434), same text, same order, header md5 matches;
--       the only differences are the named correction 202 and the named addition 690/691 (compat mirror replace)
--   Z2  as shipped the migration refuses: without authorisation (G1), and on this harness also with it. The
--       refusal is exactly G3 (the 4 baseline-only indexes and the 3 baseline-only RPCs 801-803 absent here).
--       G2 role, G4 events replacements, G5 D09 parity and G6 (no view on a dropped column) hold
--   Z3  the manifest's 202 text (ALTER PUBLICATION ... SET TABLE) removes every other realtime table; the
--       corrected DROP/ADD pair keeps them (games unchanged) and leaves meetups (id, vibe_key)
--   Z4  authorised dry run, rolled back, seeded with one game + one meetup, D05 compatibility views applied, the
--       3 baseline RPC pre-images loaded: every statement runs in file order, each in its own savepoint, no CASCADE,
--       none refused; the 4 baseline-only indexes are skipped. Then: retained columns, ids and event_id intact;
--       inbound FKs intact; counts equal; old-client compatibility views identical; per-role visibility unchanged;
--       no slated column survives; the post-condition passes. Smokes: (a) events UPDATE on a game row and a meetup
--       row, no error, the game row follows (and the pre-F8 mirror is shown failing 42703 on the meetup row);
--       (b) the mirror's games SET list = D03's retained games set, its prosrc = the pre-image minus the meetups
--       branch, SECURITY DEFINER / search_path / proacl unchanged; (c) a direct games UPDATE works
--   R1  after ROLLBACK: games/meetups/events data, column shape and publication lists byte-identical
--
-- Run (repository root) on the cluster built by supabase/tests/events_p2/build_kan788.sh plus KAN-716/D07/KAN-785:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan719_z01_removal_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-778: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k778|kan778)' THEN
    RAISE EXCEPTION 'KAN-778: database % is not a KAN-778/788 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-778: run as a superuser'; END IF;
  IF to_regclass('public.kan718_games_compat') IS NOT NULL THEN RAISE EXCEPTION 'KAN-778: D05 views already applied; use a fresh DB'; END IF;
END $g$;

CREATE TEMP TABLE k778_fp AS SELECT
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e,
  (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
     FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped) shape,
  (SELECT md5(string_agg(tablename || ':' || attnames::text, ',' ORDER BY tablename)) FROM pg_publication_tables WHERE pubname = 'supabase_realtime') pub,
  (SELECT md5(string_agg(tgrelid::regclass || '.' || tgname, ',' ORDER BY tgrelid::regclass::text, tgname)) FROM pg_trigger
    WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND NOT tgisinternal) trg;

-- The D06 manifest itself (k774_retained + k774_manifest), loaded from its only source.
\set mansql `sed -n '/^CREATE TEMP TABLE k774_retained/,/^-- M1-M5/p' supabase/tests/events_p4/kan718_d06_manifest_check.sql`
:mansql
\set migtext `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TEMP TABLE k778_src AS SELECT :'migtext'::text AS src;
-- one row per statement, ordered by position in the file; 690 is the multi-line CREATE OR REPLACE FUNCTION block
CREATE TEMP TABLE k778_stmt AS
  WITH a AS (
    SELECT x[1] AS stmt, x[2]::int AS seq, strpos(src, E'\n' || x[1] || ';  -- ' || x[2]) AS pos
      FROM k778_src, regexp_matches(src, '\n((?:ALTER|DROP|REVOKE) [^\n]*?);  -- (\d+)', 'g') AS r(x)
    UNION ALL
    SELECT substring(src FROM '\n(CREATE OR REPLACE FUNCTION public\.kan712_events_compat_mirror\(\).*?\$function\$);  -- 690'), 690,
           strpos(src, E'\nCREATE OR REPLACE FUNCTION public.kan712_events_compat_mirror()')
      FROM k778_src)
  SELECT row_number() OVER (ORDER BY pos) AS ord, stmt, seq, pos FROM a;

-- Z1
DO $z1$
DECLARE x text; want text;
BEGIN
  IF (SELECT count(*) FROM k774_manifest) <> 63 THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: manifest has % entries, expected 63', (SELECT count(*) FROM k774_manifest); END IF;
  want := md5((SELECT string_agg(stmt, E'\n' ORDER BY seq) FROM k774_manifest));
  IF position(want IN (SELECT src FROM k778_src)) = 0 THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: header md5 is not the manifest md5 %', want; END IF;
  IF EXISTS (SELECT 1 FROM k778_stmt WHERE pos = 0 OR stmt IS NULL) THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: a statement could not be located in the file'; END IF;
  SELECT string_agg(coalesce(m.seq, s.seq)::text, ', ') INTO x
    FROM (SELECT * FROM k774_manifest WHERE seq <> 202) m
    FULL JOIN (SELECT * FROM k778_stmt WHERE seq NOT IN (202, 690, 691)) s USING (seq)
   WHERE m.stmt IS DISTINCT FROM s.stmt;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: statements differ from the manifest at seq %', x; END IF;
  IF EXISTS (SELECT 1 FROM k778_stmt a JOIN k778_stmt b ON b.ord = a.ord + 1 WHERE b.seq < a.seq) THEN
    RAISE EXCEPTION 'KAN-778 Z1 FAIL: file order is not manifest order';
  END IF;
  IF (SELECT max(seq) FROM k778_stmt WHERE ord < (SELECT ord FROM k778_stmt WHERE seq = 690)) <> 616
     OR (SELECT min(seq) FROM k778_stmt WHERE seq > 691) <> 701
     OR (SELECT ord FROM k778_stmt WHERE seq = 691) <> (SELECT ord FROM k778_stmt WHERE seq = 690) + 1 THEN
    RAISE EXCEPTION 'KAN-778 Z1 FAIL: 690/691 are not between the games drop (616) and the meetups drops (7xx)';
  END IF;
  IF (SELECT string_agg(stmt, ' / ' ORDER BY ord) FROM k778_stmt WHERE seq = 202) <>
     'ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.meetups / ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.meetups (id, vibe_key)'
     OR (SELECT stmt FROM k778_stmt WHERE seq = 691) <> 'REVOKE ALL ON FUNCTION public.kan712_events_compat_mirror() FROM PUBLIC, anon, authenticated, service_role'
     OR (SELECT stmt FROM k778_stmt WHERE seq = 690) !~ '^CREATE OR REPLACE FUNCTION public\.kan712_events_compat_mirror\(\)\s+RETURNS trigger'
     OR EXISTS (SELECT 1 FROM k778_stmt WHERE stmt ~* '\mDROP TRIGGER trg_zz_kan712_events_compat_mirror') THEN
    RAISE EXCEPTION 'KAN-778 Z1 FAIL: the named correction/addition are not as documented';
  END IF;
  IF EXISTS (SELECT 1 FROM k778_stmt WHERE seq <> 690 AND stmt ~* '\mcascade\M|\mif exists\M|[*%]')
     OR (SELECT stmt FROM k778_stmt WHERE seq = 690) ~* '\mcascade\M|\mdrop\M' THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: CASCADE/IF EXISTS/wildcard'; END IF;
  RAISE NOTICE 'KAN-778 Z1 PASS: % migration statements; 62 of the 63 manifest entries verbatim and in manifest order; 202 corrected to a DROP/ADD pair; 690/691 (mirror replace + revoke) between 616 and 701; header md5 % = manifest; no CASCADE/IF EXISTS/wildcard',
    (SELECT count(*) FROM k778_stmt), want;
END $z1$;

-- Z2 the shipped gate
CREATE TEMP TABLE k778_gate AS SELECT substring(src FROM '(DO \$gate\$.*?END \$gate\$)') AS sql FROM k778_src;
CREATE FUNCTION pg_temp.k778_gate_fails() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE err text; BEGIN
  EXECUTE (SELECT sql FROM k778_gate);
  RETURN NULL;
EXCEPTION WHEN raise_exception THEN GET STACKED DIAGNOSTICS err = MESSAGE_TEXT; RETURN err; END $f$;

DO $z2$
DECLARE e1 text; e2 text; x text;
BEGIN
  IF (SELECT sql FROM k778_gate) IS NULL THEN RAISE EXCEPTION 'KAN-778 Z2 FAIL: gate block not found'; END IF;
  e1 := pg_temp.k778_gate_fails();
  IF e1 IS NULL OR e1 NOT LIKE '%G1 not authorised%' THEN RAISE EXCEPTION 'KAN-778 Z2 FAIL: unauthorised run not refused by G1: %', e1; END IF;
  RAISE NOTICE 'KAN-778 Z2 unauthorised -> %', e1;
  PERFORM set_config('kan719.phase4_manifest_md5', 'ed136455ca8dfda23a8c83342a4a5110', true);
  e2 := pg_temp.k778_gate_fails();
  PERFORM set_config('kan719.phase4_manifest_md5', '', true);
  RAISE NOTICE 'KAN-778 Z2 authorised   -> %', e2;
  IF e2 IS NULL OR e2 LIKE '%G1 %' OR e2 LIKE '%G2 %' OR e2 LIKE '%G4 %' OR e2 LIKE '%G5 %' OR e2 LIKE '%G6 %' OR e2 NOT LIKE '%G3 %' THEN
    RAISE EXCEPTION 'KAN-778 Z2 FAIL: expected exactly G3 on this harness';
  END IF;
  SELECT string_agg(seq || ' ' || kind || ' ' || tbl || '.' || obj, ', ' ORDER BY seq) INTO x FROM k774_manifest WHERE NOT local;
  IF split_part(split_part(e2, 'G3 manifest objects missing (regenerate the manifest for this database): ', 2), ' | ', 1) IS DISTINCT FROM x THEN
    RAISE EXCEPTION 'KAN-778 Z2 FAIL: G3 does not list exactly the baseline-only entries (%)', x;
  END IF;
  IF e2 LIKE '%690 function%' THEN RAISE EXCEPTION 'KAN-778 Z2 FAIL: G3 says the mirror is not the authored pre-image'; END IF;
  RAISE NOTICE 'KAN-778 Z2 PASS: refused unauthorised (G1); authorised it still refuses on exactly G3 (% baseline-only objects absent here: 4 indexes, 3 RPCs); the mirror pre-image matches; G2, G4, G5 (D09 parity), G6 hold',
    (SELECT count(*) FROM k774_manifest WHERE NOT local);
END $z2$;

-- Z3 publication: the manifest text vs the corrected pair
BEGIN;
CREATE TABLE public.k778_probe(id int PRIMARY KEY);
ALTER PUBLICATION supabase_realtime ADD TABLE public.k778_probe;
DO $z3$
DECLARE before text; after_set text; after_pair text; m_before text; st text;
BEGIN
  before := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
  m_before := (SELECT tablename || coalesce(attnames::text, '') FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'meetups');
  BEGIN
    EXECUTE (SELECT stmt FROM k774_manifest WHERE seq = 202);
    after_set := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
    RAISE EXCEPTION 'k778_undo';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  -- after_set was assigned before the undo; plpgsql variables survive the subtransaction rollback
  FOR st IN SELECT stmt FROM k778_stmt WHERE seq = 202 ORDER BY ord LOOP EXECUTE st; END LOOP;
  after_pair := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
  RAISE NOTICE 'KAN-778 Z3 before          : %', before;
  RAISE NOTICE 'KAN-778 Z3 manifest 202 SET: %', after_set;
  RAISE NOTICE 'KAN-778 Z3 corrected 202   : %', after_pair;
  IF m_before IS NULL OR after_set LIKE '%k778_probe%' OR after_set LIKE '%games%' THEN RAISE EXCEPTION 'KAN-778 Z3 FAIL: expected SET to drop the other tables'; END IF;
  IF after_pair IS DISTINCT FROM replace(before, m_before, 'meetups{id,vibe_key}') THEN
    RAISE EXCEPTION 'KAN-778 Z3 FAIL: corrected pair changed another table or did not shrink meetups';
  END IF;
  RAISE NOTICE 'KAN-778 Z3 PASS: manifest 202 (SET TABLE) removes every other realtime table; the corrected DROP/ADD pair keeps them byte-identical (games included) and leaves meetups (id, vibe_key)';
END $z3$;
ROLLBACK;

-- Runs p_sql (returning one text) as an API role. p_uid NULL = no JWT claims.
CREATE FUNCTION pg_temp.k778_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
  EXECUTE p_sql INTO r;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN r; END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.k778_as(text, uuid, text) TO anon, authenticated, service_role;

-- Z4 authorised dry run
BEGIN;
\i supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql
-- the 3 retired RPCs (801-803) exist in the repo baseline but not in this harness; load their baseline definitions
-- (bodies unchecked, they read columns dropped long ago) so 801-803 are exercised, not skipped
SET LOCAL check_function_bodies = off;
\set nearby `sed -n '7381,7463p;7823,7847p' supabase/migrations/20260829080500_baseline_schema.sql`
:nearby
RESET check_function_bodies;
DO $pre$ BEGIN
  IF to_regprocedure('public.get_nearby_games(double precision,double precision,double precision)') IS NULL
     OR to_regprocedure('public.get_nearby_games(double precision,double precision,integer)') IS NULL
     OR to_regprocedure('public.getnearbygames(double precision,double precision,double precision)') IS NULL THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: baseline RPC pre-images did not load';
  END IF;
END $pre$;
CREATE TEMP TABLE k778_mirror_pre AS
  SELECT prosrc, pg_get_functiondef(oid) AS def, prosecdef, proconfig, proacl::text AS acl
    FROM pg_proc WHERE oid = 'public.kan712_events_compat_mirror()'::regprocedure;

INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id)
VALUES ('77800000-0000-0000-0000-000000000001', 'Z01 game', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2031-05-01 18:00+00', '2031-05-01 20:00+00', 10, 'public', 'open',
        '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
    'id', '77800000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'Z01 meetup',
    'start_at', '2031-05-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public'))).*
  FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';

-- fire the seed's deferred constraint triggers now; ALTER TABLE refuses a table with pending trigger events (55006)
SET CONSTRAINTS ALL IMMEDIATE;
CREATE TEMP TABLE k778_who(label text, role text, uid uuid);
INSERT INTO k778_who VALUES ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'), ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'), ('anon', 'anon', NULL), ('service_role', 'service_role', NULL);
CREATE TEMP TABLE k778_q(k text, sql text);
INSERT INTO k778_q VALUES
  ('games ids',          'SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.games'),
  ('meetups ids',        'SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.meetups'),
  ('games compat rows',  'SELECT count(*) || '':'' || coalesce(md5(string_agg(t::text, ''|'' ORDER BY t.id)), ''-'') FROM public.kan718_games_compat t'),
  ('meetups compat rows','SELECT count(*) || '':'' || coalesce(md5(string_agg(t::text, ''|'' ORDER BY t.id)), ''-'') FROM public.kan718_meetups_compat t');
GRANT SELECT ON k778_q, k778_who TO anon, authenticated, service_role;
CREATE TEMP TABLE k778_snap(phase text, k text, who text, res text);
-- md5 over every retained column (k774_retained) of every row of a subtype table
CREATE FUNCTION pg_temp.k778_keep_md5(p_tbl text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; BEGIN
  EXECUTE format('SELECT md5(string_agg((SELECT jsonb_object_agg(j.key, j.value) FROM jsonb_each(to_jsonb(t)) j
                    WHERE j.key IN (SELECT col FROM k774_retained WHERE tbl = %L))::text, ''|'' ORDER BY t.id)) FROM public.%I t', p_tbl, p_tbl) INTO r;
  RETURN r; END $f$;
CREATE TEMP TABLE k778_keep AS SELECT
  pg_temp.k778_keep_md5('games') g_keep,
  pg_temp.k778_keep_md5('meetups') m_keep,
  (SELECT md5(string_agg(conrelid::regclass || '.' || conname || '=' || pg_get_constraintdef(oid), ',' ORDER BY conrelid::regclass::text, conname))
     FROM pg_constraint WHERE contype = 'f' AND confrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass)) fks,
  (SELECT count(*) FROM pg_constraint WHERE contype = 'f' AND confrelid IN ('public.games'::regclass, 'public.meetups'::regclass)) n_fks,
  (SELECT count(*) FROM public.games) n_g, (SELECT count(*) FROM public.meetups) n_m, (SELECT count(*) FROM public.events) n_e;

DO $s$ DECLARE w record; q record; BEGIN
  FOR w IN SELECT * FROM k778_who LOOP FOR q IN SELECT * FROM k778_q LOOP
    INSERT INTO k778_snap VALUES ('before', q.k, w.label, pg_temp.k778_as(w.role, w.uid, q.sql));
  END LOOP; END LOOP;
END $s$;

DO $z4$
DECLARE r record; ok int := 0; skipped int := 0; refused text := ''; bad text := ''; err text; det text; code text;
BEGIN
  PERFORM set_config('kan719.phase4_manifest_md5', 'ed136455ca8dfda23a8c83342a4a5110', true);
  FOR r IN SELECT s.ord, s.seq, s.stmt, coalesce(m.local, true) AS local, coalesce(m.hard, false) AS hard, m.kind
             FROM k778_stmt s LEFT JOIN k774_manifest m USING (seq) ORDER BY s.ord LOOP
    IF NOT r.local AND r.kind IS DISTINCT FROM 'function' THEN skipped := skipped + 1; CONTINUE; END IF;
    BEGIN
      EXECUTE r.stmt;
      IF r.hard THEN bad := bad || format(' %s ran but is hard-blocked', r.seq); END IF;
      ok := ok + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL, code = RETURNED_SQLSTATE;
      refused := refused || format(' %s', r.seq);
      bad := bad || format(' %s(%s: %s %s %s)', r.seq, left(r.stmt, 120), code, err, coalesce(replace(det, E'\n', '; '), ''));
    END;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL:%', bad; END IF;
  IF refused <> '' THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL: refused set was %', refused; END IF;
  RAISE NOTICE 'KAN-778 Z4 statements: % ran (incl. 690/691 and the 3 DROP FUNCTION), % baseline-only indexes skipped, none refused', ok, skipped;
END $z4$;

DO $c$ DECLARE w record; q record; x text; err text; BEGIN
  FOR w IN SELECT * FROM k778_who LOOP FOR q IN SELECT * FROM k778_q LOOP
    INSERT INTO k778_snap VALUES ('after', q.k, w.label, pg_temp.k778_as(w.role, w.uid, q.sql));
  END LOOP; END LOOP;
  SELECT string_agg(b.k || ' [' || b.who || '] ' || b.res || ' -> ' || coalesce(a.res, '<missing>'), '; ') INTO x
    FROM k778_snap b LEFT JOIN k778_snap a ON a.phase = 'after' AND a.k = b.k AND a.who = b.who
   WHERE b.phase = 'before' AND b.res IS DISTINCT FROM a.res;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL: a caller sees something different after removal: %', x; END IF;
  RAISE NOTICE 'KAN-778 Z4 PASS visibility/compat: % queries x % callers identical before/after (games/meetups id sets, D05 compat rows): %',
    (SELECT count(*) FROM k778_q), (SELECT count(*) FROM k778_who),
    (SELECT string_agg(who || ' ' || k || '=' || split_part(res, ':', 1), ', ' ORDER BY who, k) FROM k778_snap WHERE phase = 'after');

  IF (SELECT g_keep FROM k778_keep) IS DISTINCT FROM pg_temp.k778_keep_md5('games')
     OR (SELECT m_keep FROM k778_keep) IS DISTINCT FROM pg_temp.k778_keep_md5('meetups') THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: retained columns, ids or event_id changed';
  END IF;
  IF (SELECT fks FROM k778_keep) IS DISTINCT FROM (SELECT md5(string_agg(conrelid::regclass || '.' || conname || '=' || pg_get_constraintdef(oid), ',' ORDER BY conrelid::regclass::text, conname))
       FROM pg_constraint WHERE contype = 'f' AND confrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass)) THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: an inbound FK changed';
  END IF;
  IF (SELECT row(n_g, n_m, n_e) FROM k778_keep) IS DISTINCT FROM row((SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events))
     OR (SELECT count(*) FROM public.events) <> (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups) THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: counts changed or doubled';
  END IF;
  SELECT string_agg(a.attrelid::regclass || '.' || a.attname, ', ' ORDER BY a.attrelid::regclass::text, a.attname) INTO x FROM pg_attribute a
   WHERE a.attrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND a.attnum > 0 AND NOT a.attisdropped
     AND NOT EXISTS (SELECT 1 FROM k774_retained r WHERE r.tbl = a.attrelid::regclass::text AND r.col = a.attname);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL: surviving slated columns: %', x; END IF;
  IF EXISTS (SELECT 1 FROM k774_retained r WHERE NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attname = r.col AND NOT a.attisdropped)) THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: a retained column is gone';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_kan718_events_series_occurrence') THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: the D07 series replacement is gone';
  END IF;
  RAISE NOTICE 'KAN-778 Z4 PASS data: all 44 retained columns (games 35, meetups 9) byte-identical; % inbound FKs to games/meetups identical; games %, meetups %, events % (= sum); D07 series trigger kept; no slated column survives',
    (SELECT n_fks FROM k778_keep), (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);

  EXECUTE substring((SELECT src FROM k778_src) FROM '(DO \$post\$.*?END \$post\$)');
  RAISE NOTICE 'KAN-778 Z4 PASS post-condition: the migration''s own post block passes (35/9 columns, linkage, mirror has no meetups branch, RPCs gone)';
END $c$;

-- smokes (a) (b) (c), after the full removal, still inside the Z4 transaction
DO $smoke$
DECLARE x text; err text; pre record; post record; setcols text[]; want text;
BEGIN
  SELECT * INTO pre FROM k778_mirror_pre;
  SELECT prosrc, prosecdef, proconfig, proacl::text AS acl INTO post FROM pg_proc WHERE oid = 'public.kan712_events_compat_mirror()'::regprocedure;

  -- (b) the replaced mirror: games SET columns = D03's retained games set; prosrc = pre-image minus the meetups branch
  setcols := ARRAY(SELECT m[1] FROM regexp_matches(substring(post.prosrc FROM 'UPDATE public\.games g SET(.*?)\n    WHERE'), '(\w+) = NEW\.', 'g') AS m);
  SELECT string_agg(coalesce(a.c, '-' || b.col) || CASE WHEN b.col IS NULL THEN ' (mirror only)' ELSE '' END, ', ') INTO x
    FROM unnest(setcols) a(c) FULL JOIN (SELECT col FROM k774_retained WHERE tbl = 'games' AND why = 'd03') b ON b.col = a.c
   WHERE a.c IS NULL OR b.col IS NULL;
  IF x IS NOT NULL OR cardinality(setcols) <> 22 THEN RAISE EXCEPTION 'KAN-778 smoke (b) FAIL: mirror games SET vs D03 retained games set differ: % (n=%)', x, cardinality(setcols); END IF;
  -- the same comparison against a deliberately wrong set must fail (the probe can fail)
  IF NOT EXISTS (SELECT 1 FROM unnest(setcols) a(c) FULL JOIN (SELECT col FROM k774_retained WHERE tbl = 'games' AND why = 'd03' AND col <> 'title') b ON b.col = a.c
                  WHERE a.c IS NULL OR b.col IS NULL) THEN RAISE EXCEPTION 'KAN-778 smoke (b) FAIL: the set comparison cannot fail'; END IF;
  want := regexp_replace(pre.prosrc, '\n  ELSE\n.*?\n  END IF;', E'\n  END IF;');
  IF want = pre.prosrc OR post.prosrc IS DISTINCT FROM want OR post.prosrc ~ 'meetups' THEN
    RAISE EXCEPTION 'KAN-778 smoke (b) FAIL: mirror prosrc is not the pre-image minus its meetups branch';
  END IF;
  IF post.prosecdef IS DISTINCT FROM pre.prosecdef OR NOT post.prosecdef OR post.proconfig IS DISTINCT FROM pre.proconfig
     OR post.proconfig IS DISTINCT FROM ARRAY['search_path=""'] OR post.acl IS DISTINCT FROM pre.acl OR post.acl IS DISTINCT FROM '{postgres=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-778 smoke (b) FAIL: attributes changed: secdef % config % acl % (pre % % %)', post.prosecdef, post.proconfig, post.acl, pre.prosecdef, pre.proconfig, pre.acl;
  END IF;
  RAISE NOTICE 'KAN-778 smoke (b) PASS: mirror games SET = D03 retained games set (22 columns, set-equal; a wrong set is detected); prosrc = pre-image minus ELSE/meetups branch; SECURITY DEFINER, search_path="" and proacl % unchanged', post.acl;

  -- (a) events UPDATE on a game row and on a meetup row
  UPDATE public.events SET title = 'Z01 game via events' WHERE id = '77800000-0000-0000-0000-000000000001';
  IF (SELECT title FROM public.games WHERE id = '77800000-0000-0000-0000-000000000001') IS DISTINCT FROM 'Z01 game via events' THEN
    RAISE EXCEPTION 'KAN-778 smoke (a) FAIL: games.title did not follow the events UPDATE';
  END IF;
  UPDATE public.events SET title = 'Z01 meetup via events' WHERE id = '77800000-0000-0000-0000-00000000f001';
  IF NOT FOUND THEN RAISE EXCEPTION 'KAN-778 smoke (a) FAIL: meetup events row not found'; END IF;
  -- fail-first: with the pre-F8 mirror (meetups branch) restored, the same meetup UPDATE fails 42703
  BEGIN
    EXECUTE pre.def;
    UPDATE public.events SET title = 'Z01 meetup again' WHERE id = '77800000-0000-0000-0000-00000000f001';
    RAISE EXCEPTION 'k778_no_failure';
  EXCEPTION WHEN undefined_column THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT;
    RAISE NOTICE 'KAN-778 smoke (a) fail-first: pre-F8 mirror + meetups drops -> events UPDATE on the meetup row fails 42703 (%)', err;
  END;
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.kan712_events_compat_mirror()'::regprocedure) IS DISTINCT FROM post.prosrc THEN
    RAISE EXCEPTION 'KAN-778 smoke (a) FAIL: fail-first restore leaked';
  END IF;
  RAISE NOTICE 'KAN-778 smoke (a) PASS: events UPDATE on the game row (games.title followed) and on the meetup row, no error';

  -- (c) direct games UPDATE (legacy games triggers still fire on the kept columns)
  UPDATE public.games SET title = 'Z01 game direct', capacity = 12 WHERE id = '77800000-0000-0000-0000-000000000001';
  IF NOT FOUND OR (SELECT row(title, capacity) FROM public.games WHERE id = '77800000-0000-0000-0000-000000000001') IS DISTINCT FROM row('Z01 game direct'::text, 12) THEN
    RAISE EXCEPTION 'KAN-778 smoke (c) FAIL: direct games UPDATE did not apply';
  END IF;
  RAISE NOTICE 'KAN-778 smoke (c) PASS: direct games UPDATE works; events.title now %',
    (SELECT title FROM public.events WHERE id = '77800000-0000-0000-0000-000000000001');
END $smoke$;

ROLLBACK;

-- R1
DO $r$ BEGIN
  IF (SELECT row(g, m, e, shape, pub, trg) FROM k778_fp) IS DISTINCT FROM (SELECT row(
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
      (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
         FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped),
      (SELECT md5(string_agg(tablename || ':' || attnames::text, ',' ORDER BY tablename)) FROM pg_publication_tables WHERE pubname = 'supabase_realtime'),
      (SELECT md5(string_agg(tgrelid::regclass || '.' || tgname, ',' ORDER BY tgrelid::regclass::text, tgname)) FROM pg_trigger
        WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND NOT tgisinternal))) THEN
    RAISE EXCEPTION 'KAN-778 R1 FAIL: data, shape, publication or triggers differ after ROLLBACK';
  END IF;
  IF to_regclass('public.kan718_games_compat') IS NOT NULL OR to_regclass('public.k778_probe') IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 R1 FAIL: test objects left'; END IF;
  RAISE NOTICE 'KAN-778 R1 PASS: games %, meetups %, events %, column shape, realtime lists and triggers identical after ROLLBACK',
    left((SELECT g FROM k778_fp), 8), left((SELECT m FROM k778_fp), 8), left((SELECT e FROM k778_fp), 8);
  RAISE NOTICE 'KAN-778 PASS';
END $r$;
