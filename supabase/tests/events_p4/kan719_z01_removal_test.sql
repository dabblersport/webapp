-- KAN-778 (KAN-719 Z01, Epic KAN-708): the phase-4 removal migration, proven against the D06 manifest and a local DB.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- Nothing persists: every block that writes runs inside a transaction that rolls back. R1 proves it afterwards.
--
--   Z1  the migration's statements ARE the D06 manifest (k774_manifest, loaded from kan718_d06_manifest_check.sql):
--       130 entries, same text, same order, header md5 matches; the only differences are the named corrections
--       201/202 and the named addition 334
--   Z2  as shipped the migration refuses: without authorisation (G1), and on this harness also with it. The
--       refusals are exactly G3 (the 13 baseline-only indexes) and G6 (v_meetup_list reads the 3 homeless columns).
--       G2 role, G4 events replacements and G5 D09 parity hold
--   Z3  the manifest's 201 text (ALTER PUBLICATION ... SET TABLE) removes every other realtime table; the
--       corrected DROP/ADD pair keeps them and leaves games (id)
--   Z4  authorised dry run, rolled back, seeded with one game + one meetup, D05 compatibility views applied:
--       every statement runs in file order, each in its own savepoint, no CASCADE. Only the 3 homeless columns are
--       refused (view dependency), and the 13 baseline-only indexes are skipped. Then: retained columns, ids and
--       event_id intact; inbound FKs intact; counts equal; no doubling; old-client compatibility views return
--       identical rows; per-role visibility unchanged (owner, stranger, blocked, anon, service_role); an events
--       UPDATE fails with 42703 before 334 and works after it; the post-condition names only the 3 held columns
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
CREATE TEMP TABLE k778_stmt AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM k778_src, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);

-- Z1
DO $z1$
DECLARE x text; want text;
BEGIN
  IF (SELECT count(*) FROM k774_manifest) <> 130 THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: manifest has % entries, expected 130', (SELECT count(*) FROM k774_manifest); END IF;
  want := md5((SELECT string_agg(stmt, E'\n' ORDER BY seq) FROM k774_manifest));
  IF position(want IN (SELECT src FROM k778_src)) = 0 THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: header md5 is not the manifest md5 %', want; END IF;
  SELECT string_agg(coalesce(m.seq, s.seq)::text, ', ') INTO x
    FROM (SELECT * FROM k774_manifest WHERE seq NOT IN (201, 202)) m
    FULL JOIN (SELECT * FROM k778_stmt WHERE seq NOT IN (201, 202, 334)) s USING (seq)
   WHERE m.stmt IS DISTINCT FROM s.stmt;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: statements differ from the manifest at seq %', x; END IF;
  IF EXISTS (SELECT 1 FROM (SELECT * FROM k778_stmt WHERE seq <> 334) a JOIN (SELECT * FROM k778_stmt WHERE seq <> 334) b ON b.ord = a.ord + 1 WHERE b.seq < a.seq)
     OR (SELECT max(ord) FROM k778_stmt) <> (SELECT ord FROM k778_stmt WHERE seq = 334) THEN
    RAISE EXCEPTION 'KAN-778 Z1 FAIL: file order is not manifest order (334 last)';
  END IF;
  IF (SELECT string_agg(stmt, ' / ' ORDER BY ord) FROM k778_stmt WHERE seq IN (201, 202)) <>
     'ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.games / ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.games (id) / '
     || 'ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.meetups / ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.meetups (id, vibe_key)'
     OR (SELECT stmt FROM k778_stmt WHERE seq = 334) <> 'DROP TRIGGER trg_zz_kan712_events_compat_mirror ON public.events' THEN
    RAISE EXCEPTION 'KAN-778 Z1 FAIL: the named corrections/addition are not as documented';
  END IF;
  IF EXISTS (SELECT 1 FROM k778_stmt WHERE stmt ~* '\mcascade\M|\mif exists\M|[*%]') THEN RAISE EXCEPTION 'KAN-778 Z1 FAIL: CASCADE/IF EXISTS/wildcard'; END IF;
  RAISE NOTICE 'KAN-778 Z1 PASS: % migration statements; 128 of the 130 manifest entries verbatim and in manifest order; 201/202 corrected to DROP/ADD pairs; 334 added last; header md5 % = manifest; no CASCADE/IF EXISTS/wildcard',
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
  PERFORM set_config('kan719.phase4_manifest_md5', '614c1f8d29cd017126bca92588e96d9f', true);
  e2 := pg_temp.k778_gate_fails();
  PERFORM set_config('kan719.phase4_manifest_md5', '', true);
  RAISE NOTICE 'KAN-778 Z2 authorised   -> %', e2;
  IF e2 IS NULL OR e2 LIKE '%G1 %' OR e2 LIKE '%G2 %' OR e2 LIKE '%G4 %' OR e2 LIKE '%G5 %' OR e2 NOT LIKE '%G3 %' OR e2 NOT LIKE '%G6 %' THEN
    RAISE EXCEPTION 'KAN-778 Z2 FAIL: expected exactly G3 + G6 on this harness';
  END IF;
  SELECT string_agg(seq || ' ' || kind || ' ' || tbl || '.' || obj, ', ' ORDER BY seq) INTO x FROM k774_manifest WHERE NOT local;
  IF split_part(split_part(e2, 'G3 manifest objects missing (regenerate the manifest for this database): ', 2), ' | ', 1) IS DISTINCT FROM x THEN
    RAISE EXCEPTION 'KAN-778 Z2 FAIL: G3 does not list exactly the baseline-only entries (%)', x;
  END IF;
  IF e2 !~ 'v_meetup_list -> meetups\.description' OR e2 !~ 'v_meetup_list -> meetups\.is_indoor' OR e2 !~ 'v_meetup_list -> meetups\.location_name' THEN
    RAISE EXCEPTION 'KAN-778 Z2 FAIL: G6 does not name the three homeless columns';
  END IF;
  RAISE NOTICE 'KAN-778 Z2 PASS: refused unauthorised (G1); authorised it still refuses on exactly G3 (% baseline-only indexes absent here) and G6 (v_meetup_list reads description/location_name/is_indoor); G2, G4, G5 (D09 parity) hold',
    (SELECT count(*) FROM k774_manifest WHERE NOT local);
END $z2$;

-- Z3 publication: the manifest text vs the corrected pair
BEGIN;
CREATE TABLE public.k778_probe(id int PRIMARY KEY);
ALTER PUBLICATION supabase_realtime ADD TABLE public.k778_probe;
DO $z3$
DECLARE before text; after_set text; after_pair text;
BEGIN
  before := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
  BEGIN
    EXECUTE (SELECT stmt FROM k774_manifest WHERE seq = 201);
    after_set := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
    RAISE EXCEPTION 'k778_undo';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  -- after_set was assigned before the undo; plpgsql variables survive the subtransaction rollback
  FOR after_pair IN SELECT stmt FROM k778_stmt WHERE seq = 201 ORDER BY ord LOOP EXECUTE after_pair; END LOOP;
  after_pair := (SELECT string_agg(tablename || coalesce(attnames::text, ''), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime');
  RAISE NOTICE 'KAN-778 Z3 before          : %', before;
  RAISE NOTICE 'KAN-778 Z3 manifest 201 SET: %', after_set;
  RAISE NOTICE 'KAN-778 Z3 corrected 201   : %', after_pair;
  IF after_set LIKE '%k778_probe%' OR after_set LIKE '%meetups%' THEN RAISE EXCEPTION 'KAN-778 Z3 FAIL: expected SET to drop the other tables'; END IF;
  IF after_pair NOT LIKE '%k778_probe%' OR after_pair NOT LIKE '%meetups%' OR after_pair NOT LIKE '%games{id}%' THEN
    RAISE EXCEPTION 'KAN-778 Z3 FAIL: corrected pair lost a table or did not shrink games';
  END IF;
  RAISE NOTICE 'KAN-778 Z3 PASS: manifest 201 (SET TABLE) removes every other realtime table; the corrected DROP/ADD pair keeps them and leaves games (id)';
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
CREATE TEMP TABLE k778_keep AS SELECT
  (SELECT md5(string_agg(row(id, event_id, game_type, venue_space_id, sport_variant_id, allow_spectators, rules, squad_id, sport_specific_data,
                             allows_waitlist, bench_slots, price_aed, series_id)::text, '|' ORDER BY id)) FROM public.games) g_keep,
  (SELECT md5(string_agg(row(id, event_id, vibe_key, meta, host_actor_id, members_only)::text, '|' ORDER BY id)) FROM public.meetups) m_keep,
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
  PERFORM set_config('kan719.phase4_manifest_md5', '614c1f8d29cd017126bca92588e96d9f', true);
  FOR r IN SELECT s.ord, s.seq, s.stmt, coalesce(m.local, true) AS local, coalesce(m.hard, false) AS hard
             FROM k778_stmt s LEFT JOIN k774_manifest m USING (seq) ORDER BY s.ord LOOP
    IF NOT r.local THEN skipped := skipped + 1; CONTINUE; END IF;
    IF r.seq = 334 THEN
      BEGIN
        UPDATE public.events SET title = title WHERE id = '77800000-0000-0000-0000-000000000001';
        bad := bad || ' events UPDATE worked before 334 (the addition would be unneeded)';
      EXCEPTION WHEN undefined_column THEN
        GET STACKED DIAGNOSTICS err = MESSAGE_TEXT;
        RAISE NOTICE 'KAN-778 Z4 before 334: events UPDATE fails 42703 (%), from kan712_events_compat_mirror', err;
      END;
    END IF;
    BEGIN
      EXECUTE r.stmt;
      IF r.hard THEN bad := bad || format(' %s ran but is hard-blocked', r.seq); END IF;
      ok := ok + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL, code = RETURNED_SQLSTATE;
      IF r.hard AND det ~ 'v_meetup_list' THEN refused := refused || format(' %s', r.seq);
        RAISE NOTICE 'KAN-778 Z4 refused as expected: % % -> % % (%)', r.seq, r.stmt, code, err, replace(det, E'\n', '; ');
      ELSE bad := bad || format(' %s(%s: %s %s)', r.seq, r.stmt, code, err); END IF;
    END;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL:%', bad; END IF;
  IF refused <> ' 704 722 723' THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL: refused set was %', refused; END IF;
  UPDATE public.events SET title = title WHERE id = '77800000-0000-0000-0000-000000000001';
  RAISE NOTICE 'KAN-778 Z4 statements: % ran, % baseline-only skipped, refused (hard, v_meetup_list):%; events UPDATE works after 334', ok, skipped, refused;
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

  IF (SELECT g_keep FROM k778_keep) IS DISTINCT FROM (SELECT md5(string_agg(row(id, event_id, game_type, venue_space_id, sport_variant_id, allow_spectators, rules,
        squad_id, sport_specific_data, allows_waitlist, bench_slots, price_aed, series_id)::text, '|' ORDER BY id)) FROM public.games)
     OR (SELECT m_keep FROM k778_keep) IS DISTINCT FROM (SELECT md5(string_agg(row(id, event_id, vibe_key, meta, host_actor_id, members_only)::text, '|' ORDER BY id)) FROM public.meetups) THEN
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
  IF x IS DISTINCT FROM 'meetups.description, meetups.is_indoor, meetups.location_name' THEN RAISE EXCEPTION 'KAN-778 Z4 FAIL: surviving slated columns: %', x; END IF;
  IF EXISTS (SELECT 1 FROM k774_retained r WHERE NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attname = r.col AND NOT a.attisdropped)) THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: a retained column is gone';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_kan718_events_series_occurrence') THEN
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: the D07 series replacement is gone';
  END IF;
  RAISE NOTICE 'KAN-778 Z4 PASS data: retained columns + ids + event_id byte-identical; % inbound FKs to games/meetups identical; games %, meetups %, events % (= sum); D07 series trigger kept; only the 3 held meetups columns survive',
    (SELECT n_fks FROM k778_keep), (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);

  BEGIN
    EXECUTE substring((SELECT src FROM k778_src) FROM '(DO \$post\$.*?END \$post\$)');
    RAISE EXCEPTION 'KAN-778 Z4 FAIL: post-condition passed although 3 columns are held';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT;
    IF err LIKE 'KAN-778 Z4 FAIL%' OR err NOT LIKE '%meetups.description%' THEN RAISE; END IF;
    RAISE NOTICE 'KAN-778 Z4 PASS post-condition is live: %', err;
  END;
END $c$;
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
