-- KAN-779 (KAN-719 Z02, Epic KAN-708): pre-removal snapshot, tested restore path, restricted surgery window.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. The guard refuses a Supabase-looking database and any database whose name
-- does not start with k779. Companion doc: supabase/tests/events_p4/KAN719_RESTORE_PATH.md.
-- Nothing here is a migration. Everything below runs in ONE transaction that ends in ROLLBACK; Z7 proves the
-- catalogue and the table data are md5-identical afterwards.
--
-- The restore path is KAN-776 D08 runbook R2, fed from the R3 restore source (public.events + the surviving
-- games/meetups rows). It is NOT re-invented here: each step below carries the D08 step label it implements.
-- The snapshot replaces D08's session-temp capture (P5) with an in-database schema kan719_z02_snap plus a G5
-- restore-point record, and captures the WHOLE games/meetups shape, not only the manifest objects.
--
-- INPUT (psql variables, the clean779.sh harness passes both):
--   :mansql  the KAN-774 manifest section of kan718_d06_manifest_check.sql (k774_retained, k774_manifest TEMP)
--   :migtext the text of supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql. Its own
--            ALTER/DROP statements are extracted in file order and run here ("Z01-local", as KAN-781): Z01
--            verbatim refuses on the local chain (its G3: 13 baseline-only indexes absent), so those 13 are
--            skipped and the 3 HARD entries (704/722/723, G6 v_meetup_list) are held, exactly as Z01's gate would.
-- Expects the database to carry the one seeded game and one seeded meetup of k781/seed781.sql (78100000-...).
--
--   Z0  guard + before-fingerprint (catalogue + data) for Z7
--   Z1  SNAPSHOT: schema kan719_z02_snap (shape, rows, visibility, G5 restore point), closed to API roles
--   Z2  REMOVAL inside the surgery window: G1 lock, G2 parity, G3 fingerprint, Z01-local, G4 fingerprint
--   Z3  POST-CUTOVER WRITES: W2 an events edit of the seeded game, W3 a brand-new game (events + games row)
--   Z4  NEGATIVE: restore from the snapshot alone (no events) loses W2 and W3, and the verifier catches it;
--       the savepoint ROLLBACK leaves data md5 identical
--   Z5  RESTORE (D08 R2.1-R2.12) from events + surviving subtype rows, inside the same window
--   Z6  VERIFY: shapes, counts, writes survive, ids/NULLs/timestamps, RLS for a non-owner and a blocked user
--   Z7  ROLLBACK; catalogue + data md5 equal Z0
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------
-- Z0 guard
-- ---------------------------------------------------------------------------------------------
DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-779: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^k779' THEN
    RAISE EXCEPTION 'KAN-779: database % is not a KAN-779 throwaway database (name must start with k779); refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-779: run as a superuser (the test alters tables inside a rolled-back transaction)';
  END IF;
  IF to_regnamespace('kan719_z02_snap') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-779: schema kan719_z02_snap already exists; a snapshot is taken once, never overwritten';
  END IF;
  IF (SELECT count(*) FROM public.games WHERE id = '78100000-0000-0000-0000-000000000001') <> 1
     OR (SELECT count(*) FROM public.meetups WHERE id = '78100000-0000-0000-0000-00000000f001') <> 1 THEN
    RAISE EXCEPTION 'KAN-779: the seeded game/meetup (k781/seed781.sql) is missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'KAN-779: the database is not cut over (KAN-712 compat mirror missing or disabled)';
  END IF;
END $g$;

:mansql
DO $m$ BEGIN
  IF (SELECT count(*) FROM k774_manifest) <> 130 OR (SELECT count(*) FROM k774_manifest WHERE kind = 'column') <> 47 THEN
    RAISE EXCEPTION 'KAN-779: the loaded manifest has % entries; KAN-774 has 130', (SELECT count(*) FROM k774_manifest);
  END IF;
END $m$;
CREATE TEMP TABLE z_src AS SELECT :'migtext'::text AS src;
CREATE TEMP TABLE z_stmt AS SELECT ord, x[1] AS stmt, x[2]::int AS seq
  FROM z_src, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);

-- Catalogue + data fingerprint (copy of D08 k776_catalog_md5 / k776_data_md5, plus the snapshot schema's existence).
CREATE FUNCTION pg_temp.z_catalog_md5() RETURNS text LANGUAGE sql AS $f$
SELECT md5(concat_ws('#',
  (SELECT string_agg(n.nspname, ',' ORDER BY n.nspname) FROM pg_namespace n),
  (SELECT string_agg(c.relname || ':' || c.relkind::text, ',' ORDER BY c.relname) FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || '.' || a.attname || ':' || a.attnum || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull
                     || ':' || coalesce(pg_get_expr(d.adbin, d.adrelid), ''), ',' ORDER BY c.relname, a.attnum)
     FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE c.relnamespace = 'public'::regnamespace AND a.attnum > 0 AND NOT a.attisdropped),
  (SELECT string_agg(c.relname || '.' || t.tgname || ':' || t.tgenabled::text || ':' || pg_get_triggerdef(t.oid), ',' ORDER BY c.relname, t.tgname)
     FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal),
  (SELECT string_agg(c.relname || '.' || k.conname || ':' || pg_get_constraintdef(k.oid), ',' ORDER BY c.relname, k.conname)
     FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || ':' || pg_get_indexdef(i.indexrelid), ',' ORDER BY c.relname)
     FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || '.' || p.polname || ':' || coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ':' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), ',' ORDER BY c.relname, p.polname)
     FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(pb.pubname || ':' || c.relname || ':' || coalesce(r.prattrs::text, '*'), ',' ORDER BY pb.pubname, c.relname)
     FROM pg_publication_rel r JOIN pg_publication pb ON pb.oid = r.prpubid JOIN pg_class c ON c.oid = r.prrelid)))
$f$;
CREATE FUNCTION pg_temp.z_data_md5() RETURNS text LANGUAGE sql AS $f$
SELECT concat_ws(' ',
  'games=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t),
  'meetups=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t),
  'events=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t))
$f$;
CREATE TEMP TABLE z_fp0 AS SELECT pg_temp.z_catalog_md5() AS cat, pg_temp.z_data_md5() AS data;

-- The shape of games and meetups, WHOLE (every column, trigger, constraint, index), the policies on games,
-- meetups and meetup_attendees, the events compat mirror (Z01 seq 334), and the supabase_realtime list.
-- By name, never OID. Same fields as D08 k776_shape (types, NOT NULL, default, comment, ACL, tgenabled, ...).
CREATE FUNCTION pg_temp.z_shape() RETURNS TABLE(kind text, tbl text, name text, def text, extra text, ord int) LANGUAGE sql AS $f$
  SELECT 'column', c.relname::text, a.attname::text, format_type(a.atttypid, a.atttypmod),
         jsonb_build_object('notnull', a.attnotnull, 'default', pg_get_expr(d.adbin, d.adrelid),
                            'comment', col_description(a.attrelid, a.attnum), 'acl', a.attacl::text,
                            'identity', a.attidentity, 'generated', a.attgenerated)::text, a.attnum::int
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
  UNION ALL
  SELECT 'trigger', c.relname::text, t.tgname::text, pg_get_triggerdef(t.oid), t.tgenabled::text, 0
    FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE NOT t.tgisinternal AND (c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
          OR (c.oid = 'public.events'::regclass AND t.tgname = 'trg_zz_kan712_events_compat_mirror'))
  UNION ALL
  SELECT 'constraint', c.relname::text, k.conname::text, pg_get_constraintdef(k.oid), k.contype::text, 0
    FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
  UNION ALL
  SELECT 'index', c.relname::text, i.relname::text, pg_get_indexdef(i.oid), '', 0
    FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid JOIN pg_class c ON c.oid = x.indrelid
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
  UNION ALL
  SELECT 'policy', c.relname::text, p.polname::text, coalesce(pg_get_expr(p.polqual, p.polrelid), ''),
         jsonb_build_object('wc', pg_get_expr(p.polwithcheck, p.polrelid), 'cmd', p.polcmd, 'roles', p.polroles::text, 'perm', p.polpermissive)::text, 0
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.meetup_attendees'::regclass)
  UNION ALL
  SELECT 'publication', c.relname::text, pb.pubname::text,
         format('ONLY %s', r.prrelid::regclass)
           || coalesce(' (' || (SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attname) FROM pg_attribute a
                                  WHERE a.attrelid = r.prrelid AND a.attnum = ANY (r.prattrs::int2[])) || ')', '')
           || coalesce(' WHERE (' || pg_get_expr(r.prqual, r.prrelid) || ')', ''), '', 0
    FROM pg_publication_rel r JOIN pg_publication pb ON pb.oid = r.prpubid AND pb.pubname = 'supabase_realtime'
    JOIN pg_class c ON c.oid = r.prrelid
$f$;
-- G3/G4 (D08 k776_fp): events rows + surviving subtype columns. Unchanged by column surgery unless a row was written.
CREATE FUNCTION pg_temp.z_dropped(p_tbl text) RETURNS text[] LANGUAGE sql STABLE AS $f$
  SELECT coalesce(array_agg(obj ORDER BY seq), '{}') FROM k774_manifest WHERE kind = 'column' AND NOT hard AND tbl = p_tbl
$f$;
CREATE FUNCTION pg_temp.z_fp() RETURNS text LANGUAGE sql AS $f$
SELECT concat_ws('|',
  (SELECT count(*) || ':' || md5(coalesce(string_agg(to_jsonb(e)::text, ',' ORDER BY e.id), '')) FROM public.events e),
  (SELECT count(*) || ':' || md5(coalesce(string_agg((to_jsonb(g) - pg_temp.z_dropped('games'))::text, ',' ORDER BY g.id), '')) FROM public.games g),
  (SELECT count(*) || ':' || md5(coalesce(string_agg((to_jsonb(m) - pg_temp.z_dropped('meetups'))::text, ',' ORDER BY m.id), '')) FROM public.meetups m))
$f$;
CREATE FUNCTION pg_temp.z_events_md5() RETURNS text LANGUAGE sql AS $f$
  SELECT count(*) || ':' || md5(coalesce(string_agg(to_jsonb(e)::text, ',' ORDER BY e.id), '')) FROM public.events e
$f$;
-- G2 (D08 k776_guard_parity)
CREATE FUNCTION pg_temp.z_guard_parity() RETURNS void LANGUAGE plpgsql AS $f$
DECLARE n bigint; x text;
BEGIN
  SELECT count(*), string_agg(kind || ':' || id || ':' || array_to_string(mismatched_fields, '+'), ', ') INTO n, x FROM public.kan711_events_parity;
  IF n > 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k779_legacy_events_diverged', DETAIL = format('%s divergent row(s): %s', n, left(x, 400)),
      HINT = 'Run D08 runbook R0 resync first.';
  END IF;
END $f$;
-- The id set an API caller sees (D08 k776_as, returning the sorted id list instead of a count).
CREATE FUNCTION pg_temp.z_as_ids_raw(p_uid uuid, p_tbl text) RETURNS uuid[] LANGUAGE plpgsql AS $f$
DECLARE s uuid[]; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  EXECUTE format('SELECT coalesce(array_agg(id ORDER BY id), ''{}'') FROM public.%I', p_tbl) INTO s;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN s; END $f$;
-- Restricted to the rows that existed at snapshot time (W3 is judged separately), as superuser after the role is reset.
CREATE FUNCTION pg_temp.z_as_ids(p_uid uuid, p_tbl text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE a uuid[] := pg_temp.z_as_ids_raw(p_uid, p_tbl); s text; BEGIN
  EXECUTE format('SELECT count(*) || '':'' || md5(coalesce(string_agg(x::text, '','' ORDER BY x), '''')) FROM unnest($1) x WHERE x IN (SELECT id FROM kan719_z02_snap.%I)', p_tbl || '_rows') INTO s USING a;
  RETURN s; END $f$;
CREATE FUNCTION pg_temp.z_sees(p_uid uuid, p_tbl text, p_id uuid) RETURNS boolean LANGUAGE plpgsql AS $f$
DECLARE b boolean; BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE id = $1)', p_tbl) INTO b USING p_id;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN b; END $f$;

-- The data verifier, used by Z6 and by the Z4 negative. Returns '' on PASS, otherwise the failures.
-- W2 = the seeded game edited through events after cutover; W3 = a game created after cutover.
CREATE FUNCTION pg_temp.z_verify_data() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE f text := ''; n bigint;
  v_g uuid := '78100000-0000-0000-0000-000000000001'; v_m uuid := '78100000-0000-0000-0000-00000000f001'; v_n uuid := '78100000-0000-0000-0000-000000000003';
BEGIN
  -- counts equal legacy, nothing doubled
  IF (SELECT count(*) - count(DISTINCT id) FROM public.games) <> 0 OR (SELECT count(*) - count(DISTINCT id) FROM public.meetups) <> 0
     OR (SELECT count(*) - count(DISTINCT id) FROM public.events) <> 0
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM kan719_z02_snap.games_rows) + 1
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM kan719_z02_snap.meetups_rows)
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM public.events WHERE event_type = 'game')
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
     OR EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id) OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id) THEN
    f := f || ' COUNTS(games/meetups/events not snapshot+W3, doubled, or event_id<>id)';
  END IF;
  -- every snapshot row not written after cutover equals itself: ids, NULLs, created_at/updated_at, search_tsv
  SELECT count(*) INTO n FROM (
    SELECT s.id FROM kan719_z02_snap.games_rows s LEFT JOIN public.games t ON t.id = s.id
     WHERE s.id <> v_g AND to_jsonb(s) IS DISTINCT FROM to_jsonb(t)
    UNION ALL
    SELECT s.id FROM kan719_z02_snap.meetups_rows s LEFT JOIN public.meetups t ON t.id = s.id
     WHERE to_jsonb(s) IS DISTINCT FROM to_jsonb(t)) d;
  IF n <> 0 THEN f := f || format(' ROWS(%s untouched legacy rows differ from the snapshot)', n); END IF;
  -- W2 survived, with its own updated_at and the original created_at; nothing else on the row moved
  IF (SELECT row(title, updated_at, created_at)::text FROM public.games WHERE id = v_g)
       IS DISTINCT FROM (SELECT row('Z02 W2 game', '2026-08-01 12:00+00'::timestamptz, s.created_at)::text FROM kan719_z02_snap.games_rows s WHERE s.id = v_g)
     OR (SELECT to_jsonb(t) - '{title,updated_at,search_tsv}'::text[] FROM public.games t WHERE id = v_g)
       IS DISTINCT FROM (SELECT to_jsonb(s) - '{title,updated_at,search_tsv}'::text[] FROM kan719_z02_snap.games_rows s WHERE s.id = v_g)
     OR NOT coalesce((SELECT search_tsv @@ to_tsquery('simple', 'w2') FROM public.games WHERE id = v_g), false) THEN
    f := f || ' W2(post-cutover events edit lost)';
  END IF;
  -- W3 survived: its id, event_id, title, its own created_at/updated_at, and its NULLs equal its events row
  IF (SELECT row(id, event_id, title, created_at, updated_at, capacity, cancelled_reason)::text FROM public.games WHERE id = v_n)
       IS DISTINCT FROM row(v_n, v_n, 'Z02 W3 game', '2026-09-01 12:00+00'::timestamptz, '2026-09-01 12:00+00'::timestamptz, 10, NULL::text)::text THEN
    f := f || ' W3(post-cutover new game lost)';
  END IF;
  -- the seeded meetup kept its NULLs (end_at, capacity)
  IF (SELECT row(end_at, capacity)::text FROM public.meetups WHERE id = v_m) IS DISTINCT FROM row(NULL::timestamptz, NULL::int)::text THEN
    f := f || ' NULLS(meetup end_at/capacity)';
  END IF;
  -- rsvp_policy is join_policy (D08 R3: the one renamed source)
  IF EXISTS (SELECT 1 FROM public.meetups m JOIN public.events e ON e.id = m.event_id WHERE m.rsvp_policy::text IS DISTINCT FROM e.join_policy::text) THEN
    f := f || ' RSVP(rsvp_policy <> join_policy)';
  END IF;
  RETURN f;
END $f$;

BEGIN;
SET LOCAL lock_timeout = '10s';
SET CONSTRAINTS ALL IMMEDIATE;   -- D08 R2.0: ALTER TABLE refuses a table with pending deferred trigger events

-- ---------------------------------------------------------------------------------------------
-- Z1 SNAPSHOT. In production this block is its own committed transaction, taken before the removal window.
-- ---------------------------------------------------------------------------------------------
CREATE SCHEMA kan719_z02_snap;
REVOKE ALL ON SCHEMA kan719_z02_snap FROM PUBLIC;
SELECT set_config('search_path', '', true);
CREATE TABLE kan719_z02_snap.shape_q AS SELECT * FROM pg_temp.z_shape();          -- schema-qualified defs, used to rebuild
SELECT set_config('search_path', '"$user", public', true);
CREATE TABLE kan719_z02_snap.shape AS SELECT * FROM pg_temp.z_shape();            -- as the app's search_path sees it, used to compare
CREATE TABLE kan719_z02_snap.games_rows   AS SELECT * FROM public.games;           -- full copies: ids, NULLs, original timestamps
CREATE TABLE kan719_z02_snap.meetups_rows AS SELECT * FROM public.meetups;
CREATE TABLE kan719_z02_snap.events_rows  AS SELECT * FROM public.events;
CREATE TABLE kan719_z02_snap.visible(who text, uid uuid, tbl text, ids text);
INSERT INTO kan719_z02_snap.visible SELECT w.who, w.uid, t.tbl, pg_temp.z_as_ids(w.uid, t.tbl)
  FROM (VALUES ('stranger', '00000000-0000-0000-0000-00000000dead'::uuid), ('blocked', '00000000-0000-0000-0000-0000000000a6'::uuid)) w(who, uid),
       (VALUES ('games'), ('meetups')) t(tbl);
-- G5 restore point: backup_ts and the G3 fingerprint next to the capture (D08 G5). One row, never overwritten.
CREATE TABLE kan719_z02_snap.restore_point AS
  SELECT now() AS backup_ts, current_user::text AS taken_by, current_database()::text AS db, pg_temp.z_fp() AS g3_fp,
         pg_temp.z_catalog_md5() AS catalog_md5, pg_temp.z_data_md5() AS data_md5,
         (SELECT md5(string_agg(stmt, E'\n' ORDER BY seq)) FROM k774_manifest) AS manifest_md5;
ALTER TABLE kan719_z02_snap.restore_point ADD CONSTRAINT restore_point_one_row CHECK (backup_ts IS NOT NULL);
CREATE UNIQUE INDEX restore_point_singleton ON kan719_z02_snap.restore_point ((true));
DO $z1$
DECLARE leak text := '';
BEGIN
  IF (SELECT count(*) FROM kan719_z02_snap.games_rows) <> (SELECT count(*) FROM public.games)
     OR (SELECT count(*) FROM kan719_z02_snap.meetups_rows) <> (SELECT count(*) FROM public.meetups)
     OR (SELECT md5(string_agg(to_jsonb(s)::text, ',' ORDER BY s.id)) FROM kan719_z02_snap.games_rows s)
        IS DISTINCT FROM (SELECT md5(string_agg(to_jsonb(t)::text, ',' ORDER BY t.id)) FROM public.games t)
     OR (SELECT md5(string_agg(to_jsonb(s)::text, ',' ORDER BY s.id)) FROM kan719_z02_snap.meetups_rows s)
        IS DISTINCT FROM (SELECT md5(string_agg(to_jsonb(t)::text, ',' ORDER BY t.id)) FROM public.meetups t) THEN
    RAISE EXCEPTION 'KAN-779 Z1 FAIL: the snapshot rows are not byte-identical to the live rows';
  END IF;
  IF (SELECT manifest_md5 FROM kan719_z02_snap.restore_point) <> '614c1f8d29cd017126bca92588e96d9f' THEN
    RAISE EXCEPTION 'KAN-779 Z1 FAIL: the loaded manifest md5 % is not the one Z01 is authored against', (SELECT manifest_md5 FROM kan719_z02_snap.restore_point);
  END IF;
  IF (SELECT end_at IS NOT NULL OR capacity IS NOT NULL FROM kan719_z02_snap.meetups_rows WHERE id = '78100000-0000-0000-0000-00000000f001') THEN
    RAISE EXCEPTION 'KAN-779 Z1 FAIL: the seeded meetup NULLs were not captured as NULL';
  END IF;
  -- T-020: the snapshot holds RLS-protected rows; no API role may reach it.
  IF has_schema_privilege('anon', 'kan719_z02_snap', 'USAGE') THEN leak := leak || ' anon'; END IF;
  IF has_schema_privilege('authenticated', 'kan719_z02_snap', 'USAGE') THEN leak := leak || ' authenticated'; END IF;
  IF has_schema_privilege('service_role', 'kan719_z02_snap', 'USAGE') THEN leak := leak || ' service_role'; END IF;
  IF leak <> '' THEN RAISE EXCEPTION 'KAN-779 Z1 FAIL: snapshot schema reachable by:%', leak; END IF;
  RAISE NOTICE 'KAN-779 Z1 PASS: snapshot kan719_z02_snap taken: games %, meetups %, events % rows (byte-identical); shape %; visibility %; restore point backup_ts set, G3 %, manifest md5 %; no USAGE for anon/authenticated/service_role',
    (SELECT count(*) FROM kan719_z02_snap.games_rows), (SELECT count(*) FROM kan719_z02_snap.meetups_rows), (SELECT count(*) FROM kan719_z02_snap.events_rows),
    (SELECT string_agg(kind || '=' || n, ' ' ORDER BY kind) FROM (SELECT kind, count(*) n FROM kan719_z02_snap.shape GROUP BY kind) s),
    (SELECT string_agg(who || '/' || tbl || ' ' || split_part(ids, ':', 1), ', ' ORDER BY who, tbl) FROM kan719_z02_snap.visible),
    left(md5((SELECT g3_fp FROM kan719_z02_snap.restore_point)), 12), (SELECT manifest_md5 FROM kan719_z02_snap.restore_point);
END $z1$;

-- ---------------------------------------------------------------------------------------------
-- Z2 REMOVAL inside the surgery window (D08 G1-G4), Z01's own statements
-- ---------------------------------------------------------------------------------------------
DO $z2$
DECLARE fp text; r record; ran int := 0; sk int := 0; held text := '';
BEGIN
  LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;          -- G1
  PERFORM pg_temp.z_guard_parity();                                                             -- G2
  fp := pg_temp.z_fp();                                                                         -- G3
  IF fp IS DISTINCT FROM (SELECT g3_fp FROM kan719_z02_snap.restore_point) THEN
    RAISE EXCEPTION 'KAN-779 Z2 FAIL: data moved between the snapshot and the removal window; take a fresh snapshot';
  END IF;
  PERFORM set_config('kan719.phase4_manifest_md5', '614c1f8d29cd017126bca92588e96d9f', true);  -- Z01 G1 authorisation
  FOR r IN SELECT s.*, coalesce(m.local, true) AS local, coalesce(m.hard, false) AS hard FROM z_stmt s LEFT JOIN k774_manifest m USING (seq) ORDER BY ord LOOP
    IF NOT r.local THEN sk := sk + 1; CONTINUE; END IF;
    IF r.hard THEN held := held || ' ' || r.seq; CONTINUE; END IF;
    EXECUTE r.stmt; ran := ran + 1;
  END LOOP;
  IF pg_temp.z_fp() IS DISTINCT FROM fp THEN                                                     -- G4
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k779_write_landed_mid_surgery', HINT = 'ROLLBACK, never COMMIT.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped)
     OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_zz_kan712_events_compat_mirror') THEN
    RAISE EXCEPTION 'KAN-779 Z2 FAIL: Z01-local did not remove games.title / the compat mirror';
  END IF;
  RAISE NOTICE 'KAN-779 Z2 PASS: G1 lock, G2 parity 0, G3 = snapshot fingerprint; Z01-local ran % statements, skipped % baseline-only, held (HARD):%; G4 fingerprint unchanged; games now % columns, meetups %',
    ran, sk, held, (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped),
    (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped);
END $z2$;

-- ---------------------------------------------------------------------------------------------
-- Z3 POST-CUTOVER WRITES (they land in events only; there is no other write path after phase 4, D08 F5)
-- ---------------------------------------------------------------------------------------------
DO $z3$ BEGIN
  PERFORM set_config('kan711.src_updated_at', '2026-08-01 12:00+00', true);
  UPDATE public.events SET title = 'Z02 W2 game' WHERE id = '78100000-0000-0000-0000-000000000001';           -- W2
  PERFORM set_config('kan711.src_updated_at', '', true);
  INSERT INTO public.events SELECT (jsonb_populate_record(NULL::public.events, to_jsonb(e) || jsonb_build_object(  -- W3
      'id', '78100000-0000-0000-0000-000000000003', 'title', 'Z02 W3 game', 'request_id', NULL, 'cancelled_reason', NULL,
      'created_at', '2026-09-01 12:00+00', 'updated_at', '2026-09-01 12:00+00'))).*
    FROM public.events e WHERE e.id = '78100000-0000-0000-0000-000000000001';
  INSERT INTO public.games SELECT (jsonb_populate_record(NULL::public.games, to_jsonb(g) || jsonb_build_object(
      'id', '78100000-0000-0000-0000-000000000003', 'event_id', '78100000-0000-0000-0000-000000000003'))).*
    FROM public.games g WHERE g.id = '78100000-0000-0000-0000-000000000001';
  IF (SELECT row(title, updated_at)::text FROM public.events WHERE id = '78100000-0000-0000-0000-000000000001')
       IS DISTINCT FROM row('Z02 W2 game', '2026-08-01 12:00+00'::timestamptz)::text
     OR (SELECT count(*) FROM public.games WHERE id = '78100000-0000-0000-0000-000000000003') <> 1 THEN
    RAISE EXCEPTION 'KAN-779 Z3 FAIL: the post-cutover writes did not land';
  END IF;
  RAISE NOTICE 'KAN-779 Z3 PASS: W2 events edit (title Z02 W2 game, updated_at 2026-08-01) and W3 new game (events + games retained columns, created_at 2026-09-01) written after the cutover';
END $z3$;

-- V1 shape difference vs the snapshot, both directions (NULL = identical). Column order is not compared (D08 F3).
CREATE FUNCTION pg_temp.z_shape_diff() RETURNS text LANGUAGE sql AS $f$
  SELECT string_agg(kind || ':' || tbl || '.' || name, ', ') FROM (
    (SELECT kind, tbl, name, def, extra FROM kan719_z02_snap.shape EXCEPT SELECT kind, tbl, name, def, extra FROM pg_temp.z_shape())
    UNION ALL
    (SELECT kind, tbl, name, def, extra FROM pg_temp.z_shape() EXCEPT SELECT kind, tbl, name, def, extra FROM kan719_z02_snap.shape)) d
$f$;

-- The restore (D08 R2.1-R2.12). p_source = 'events' is the R3 restore source; 'snapshot' is the Z4 negative,
-- which fills the dropped columns from the snapshot rows instead and stops before the fail-closed steps.
CREATE FUNCTION pg_temp.z_restore(p_source text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r record; cols text; srcs text; n bigint; ev0 text; added int := 0;
BEGIN
  IF to_regclass('kan719_z02_snap.restore_point') IS NULL OR (SELECT count(*) FROM kan719_z02_snap.restore_point) <> 1
     OR (SELECT db FROM kan719_z02_snap.restore_point) <> current_database() THEN
    RAISE EXCEPTION 'KAN-779 restore refused: no single restore point for this database (D08 R2.0: without the capture there is no R2)';
  END IF;
  LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;                 -- R2.1
  ev0 := pg_temp.z_events_md5();
  SELECT count(*) INTO n FROM (                                                                        -- R2.2 source complete
    SELECT g.id FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id WHERE e.id IS NULL OR e.event_type <> 'game' OR g.event_id <> g.id
    UNION ALL SELECT m.id FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id WHERE e.id IS NULL OR e.event_type <> 'meetup' OR m.event_id <> m.id
    UNION ALL SELECT e.id FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.event_id = e.id)
                                                 AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.event_id = e.id)) x;
  IF n <> 0 THEN RAISE EXCEPTION 'KAN-779 R2.2 FAIL: % subtype rows without an events parent (or orphan events)', n; END IF;
  CREATE TEMP TABLE z_missing ON COMMIT DROP AS                                                        -- what Z01 removed = snapshot minus live
    SELECT s.* FROM kan719_z02_snap.shape_q s WHERE s.kind = 'column'
       AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || s.tbl)::regclass AND a.attname = s.name AND NOT a.attisdropped);
  FOR r IN SELECT * FROM z_missing ORDER BY tbl, ord LOOP                                               -- R2.3 columns back, nullable
    IF (r.extra::jsonb ->> 'identity') <> '' OR (r.extra::jsonb ->> 'generated') <> '' THEN
      RAISE EXCEPTION 'KAN-779 R2.3: %.% is an identity/generated column; not restorable by this path', r.tbl, r.name;
    END IF;
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN %I %s', r.tbl, r.name, r.def); added := added + 1;
  END LOOP;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q WHERE kind = 'trigger' AND name IN ('trg_games_search_tsv', 'trg_meetups_search_tsv')
             AND NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgname = name AND NOT t.tgisinternal) LOOP
    EXECUTE r.def;                                                                                     -- R2.4 search_tsv triggers, ALWAYS
    EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER %I', r.tbl, r.name);
  END LOOP;
  PERFORM set_config('session_replication_role', 'replica', true);                                     -- R2.5 values
  FOR r IN SELECT tbl FROM (VALUES ('games'), ('meetups')) v(tbl) LOOP
    SELECT string_agg(quote_ident(s.name), ', ' ORDER BY s.ord),
           string_agg(CASE p_source WHEN 'snapshot' THEN 'b.' || quote_ident(s.name)
                                    ELSE 'e.' || quote_ident(CASE s.name WHEN 'rsvp_policy' THEN 'join_policy' ELSE s.name END) END, ', ' ORDER BY s.ord)
      INTO cols, srcs FROM z_missing s WHERE s.tbl = r.tbl AND s.name <> 'search_tsv';
    CONTINUE WHEN cols IS NULL;
    IF p_source = 'events' AND EXISTS (SELECT 1 FROM z_missing s WHERE s.tbl = r.tbl AND s.name <> 'search_tsv'
                AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.events'::regclass AND NOT a.attisdropped
                                 AND a.attname = CASE s.name WHEN 'rsvp_policy' THEN 'join_policy' ELSE s.name END)) THEN
      RAISE EXCEPTION 'KAN-779 R2.5 FAIL: a removed %.column has no events source (R3)', r.tbl;
    END IF;
    IF p_source = 'snapshot' THEN
      EXECUTE format('UPDATE public.%I t SET (%s) = ROW(%s) FROM kan719_z02_snap.%I b WHERE b.id = t.id', r.tbl, cols, srcs, r.tbl || '_rows');
    ELSE
      EXECUTE format('UPDATE public.%I t SET (%s) = ROW(%s) FROM public.events e WHERE e.id = t.event_id', r.tbl, cols, srcs);
    END IF;
  END LOOP;
  PERFORM set_config('session_replication_role', 'origin', true);
  IF p_source = 'snapshot' THEN RETURN format('%s columns re-added and filled from the snapshot rows', added); END IF;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q WHERE kind = 'trigger' AND name IN ('trg_games_search_tsv', 'trg_meetups_search_tsv') LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER %I', r.tbl, r.name);
  END LOOP;
  FOR r IN SELECT * FROM z_missing ORDER BY tbl, ord LOOP                                               -- R2.6 defaults, NOT NULL, comments
    IF (r.extra::jsonb ->> 'default') IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I SET DEFAULT %s', r.tbl, r.name, r.extra::jsonb ->> 'default');
    END IF;
    IF (r.extra::jsonb ->> 'notnull')::boolean THEN EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I SET NOT NULL', r.tbl, r.name); END IF;
    IF (r.extra::jsonb ->> 'comment') IS NOT NULL THEN
      EXECUTE format('COMMENT ON COLUMN public.%I.%I IS %L', r.tbl, r.name, r.extra::jsonb ->> 'comment');
    END IF;
    IF (r.extra::jsonb ->> 'acl') IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-779 R2.6: column % has column-level grants %; restore them by hand', r.name, r.extra::jsonb ->> 'acl';
    END IF;
  END LOOP;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q s WHERE kind = 'constraint'                           -- R2.7 constraints (validated)
             AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = ('public.' || s.tbl)::regclass AND k.conname = s.name) ORDER BY tbl, name LOOP
    EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I %s', r.tbl, r.name, r.def);
  END LOOP;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q s WHERE kind = 'index'                                -- R2.8 indexes
             AND to_regclass('public.' || quote_ident(s.name)) IS NULL ORDER BY name LOOP
    EXECUTE r.def;
  END LOOP;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q s WHERE kind = 'trigger'                              -- R2.9 triggers, then tgenabled
             AND name NOT IN ('trg_games_search_tsv', 'trg_meetups_search_tsv', 'trg_zz_kan712_events_compat_mirror')
             AND NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = ('public.' || s.tbl)::regclass AND t.tgname = s.name) ORDER BY tbl, name LOOP
    EXECUTE r.def;
  END LOOP;
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q WHERE kind = 'trigger' AND name <> 'trg_zz_kan712_events_compat_mirror' LOOP
    IF r.extra = 'D' THEN EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER %I', r.tbl, r.name); END IF;
    IF r.extra = 'A' THEN EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER %I', r.tbl, r.name); END IF;
    IF r.extra = 'R' THEN EXECUTE format('ALTER TABLE public.%I ENABLE REPLICA TRIGGER %I', r.tbl, r.name); END IF;
  END LOOP;
  FOR r IN SELECT s.* FROM kan719_z02_snap.shape_q s JOIN pg_policy p ON p.polname = s.name AND p.polrelid = ('public.' || s.tbl)::regclass
            WHERE s.kind = 'policy' LOOP                                                               -- R2.10 policies back to the capture
    EXECUTE format('ALTER POLICY %I ON public.%I%s%s', r.name, r.tbl, CASE WHEN r.def <> '' THEN ' USING (' || r.def || ')' ELSE '' END,
                   coalesce(' WITH CHECK (' || (r.extra::jsonb ->> 'wc') || ')', ''));
  END LOOP;
  EXECUTE 'ALTER PUBLICATION supabase_realtime SET TABLE '                                             -- R2.11 full captured list (F2)
    || (SELECT string_agg(def, ', ' ORDER BY tbl) FROM kan719_z02_snap.shape_q WHERE kind = 'publication');
  FOR r IN SELECT * FROM kan719_z02_snap.shape_q WHERE kind = 'trigger' AND name = 'trg_zz_kan712_events_compat_mirror' LOOP
    EXECUTE r.def;                                                                                     -- R2.12 sync back: Z01 seq 334 DROPPED it,
    IF r.extra = 'D' THEN EXECUTE format('ALTER TABLE public.events DISABLE TRIGGER %I', r.name); END IF;  -- so recreate, not re-enable
  END LOOP;
  IF pg_temp.z_events_md5() IS DISTINCT FROM ev0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k779_restore_wrote_events', HINT = 'The restore must read events, never write it. ROLLBACK.';
  END IF;
  RETURN format('%s columns re-added and filled from events', added);
END $f$;

-- ---------------------------------------------------------------------------------------------
-- Z4 NEGATIVE: restore from the snapshot alone, without events
-- ---------------------------------------------------------------------------------------------
DO $z4$
DECLARE d0 text := pg_temp.z_data_md5(); c0 text := pg_temp.z_catalog_md5(); msg text; v text; sd text;
BEGIN
  sd := pg_temp.z_shape_diff();
  IF sd IS NULL THEN RAISE EXCEPTION 'KAN-779 NEG FAIL: V1 reports no shape difference after the removal (the probe cannot fail)'; END IF;
  RAISE NOTICE 'KAN-779 NEG V1 PASS: before any restore V1 FAILS as it must: % objects differ from the snapshot', array_length(string_to_array(sd, ', '), 1);
  BEGIN v := pg_temp.z_verify_data(); EXCEPTION WHEN undefined_column THEN v := ' (' || SQLERRM || ')'; END;
  IF v = '' THEN RAISE EXCEPTION 'KAN-779 NEG FAIL: the data verifier passes on the removed state (the probe cannot fail)'; END IF;
  RAISE NOTICE 'KAN-779 NEG VERIFY PASS: before any restore the data verifier FAILS as it must:%', v;
  BEGIN
    msg := pg_temp.z_restore('snapshot');
    v := pg_temp.z_verify_data();
    IF v !~ 'W2' OR v !~ 'W3' THEN
      RAISE EXCEPTION 'KAN-779 NEG FAIL: a snapshot-only restore was not caught losing the post-cutover writes (verifier said: "%")', v;
    END IF;
    RAISE NOTICE 'KAN-779 NEG PASS: snapshot-only restore (%) loses the post-cutover writes; game title back to %, W3 title %; verifier FAILS with:%',
      msg, (SELECT quote_literal(title) FROM public.games WHERE id = '78100000-0000-0000-0000-000000000001'),
      (SELECT coalesce(quote_literal(title), 'NULL') FROM public.games WHERE id = '78100000-0000-0000-0000-000000000003'), v;
    RAISE EXCEPTION 'k779_neg_undo';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'k779_neg_undo' THEN RAISE; END IF;
  END;
  IF pg_temp.z_data_md5() IS DISTINCT FROM d0 OR pg_temp.z_catalog_md5() IS DISTINCT FROM c0 THEN
    RAISE EXCEPTION 'KAN-779 NEG FAIL: rolling back the snapshot-only attempt did not leave data/catalogue intact';
  END IF;
  RAISE NOTICE 'KAN-779 NEG ROLLBACK PASS: the failed attempt rolled back to its savepoint; data md5 % and catalogue md5 % identical before and after',
    md5(d0), left(c0, 12);
END $z4$;

-- ---------------------------------------------------------------------------------------------
-- Z5 RESTORE from events + surviving subtype rows (R3)
-- ---------------------------------------------------------------------------------------------
DO $z5$ DECLARE msg text; BEGIN
  msg := pg_temp.z_restore('events');
  RAISE NOTICE 'KAN-779 Z5 PASS: D08 R2.1-R2.12 under the window lock: %; constraints validated, indexes, triggers + tgenabled, policies, publication, compat mirror recreated; events untouched by the restore', msg;
END $z5$;

-- ---------------------------------------------------------------------------------------------
-- Z6 VERIFY
-- ---------------------------------------------------------------------------------------------
DO $z6$
DECLARE x text; v text; moved bigint; leak text := ''; c text;
BEGIN
  -- V1 legacy shapes unchanged (column set + types + NOT NULL/defaults, triggers + enabled state, constraints,
  -- indexes, policies, publication), both directions. Column ORDER reported separately (D08 F3).
  x := pg_temp.z_shape_diff();
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-779 V1 FAIL: shape differs from the snapshot: %', x; END IF;
  SELECT count(*) INTO moved FROM kan719_z02_snap.shape p JOIN pg_temp.z_shape() s USING (kind, tbl, name) WHERE p.kind = 'column' AND p.ord <> s.ord;
  SELECT string_agg(tbl || ' ' || n || ' cols', ', ' ORDER BY tbl) INTO c FROM (SELECT tbl, count(*) n FROM pg_temp.z_shape() WHERE kind = 'column' GROUP BY tbl) s;
  RAISE NOTICE 'KAN-779 V1 PASS: legacy shapes equal the snapshot (%; types, NOT NULL, defaults; % triggers incl. enabled state, % constraints, % indexes, % policies, publication list)',
    c, (SELECT count(*) FROM kan719_z02_snap.shape WHERE kind = 'trigger'), (SELECT count(*) FROM kan719_z02_snap.shape WHERE kind = 'constraint'),
    (SELECT count(*) FROM kan719_z02_snap.shape WHERE kind = 'index'), (SELECT count(*) FROM kan719_z02_snap.shape WHERE kind = 'policy');
  RAISE NOTICE 'KAN-779 V1 FINDING F3 (D08, not fixed): % restored columns moved to the end of the attribute order (ADD COLUMN appends)', moved;
  -- V2 parity
  PERFORM pg_temp.z_guard_parity();
  -- V3-V5 data
  v := pg_temp.z_verify_data();
  IF v <> '' THEN RAISE EXCEPTION 'KAN-779 V3-V5 FAIL:%', v; END IF;
  RAISE NOTICE 'KAN-779 V2 PASS: kan711_events_parity = 0';
  RAISE NOTICE 'KAN-779 V3 PASS: rows not doubled; games % = snapshot % + W3 = game events, meetups % = snapshot = meetup events; event_id = id everywhere',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM kan719_z02_snap.games_rows), (SELECT count(*) FROM public.meetups);
  RAISE NOTICE 'KAN-779 V4 PASS: post-cutover writes survive: W2 title Z02 W2 game, updated_at 2026-08-01, original created_at %, search_tsv recomputed; W3 id/event_id/title, created_at 2026-09-01',
    (SELECT created_at FROM kan719_z02_snap.games_rows WHERE id = '78100000-0000-0000-0000-000000000001');
  RAISE NOTICE 'KAN-779 V5 PASS: % of % untouched legacy rows equal their snapshot row on every column (ids, NULLs, created_at, updated_at, search_tsv); seeded meetup end_at/capacity still NULL; rsvp_policy = join_policy',
    (SELECT count(*) - 1 FROM kan719_z02_snap.games_rows) + (SELECT count(*) FROM kan719_z02_snap.meetups_rows),
    (SELECT count(*) FROM kan719_z02_snap.games_rows) + (SELECT count(*) FROM kan719_z02_snap.meetups_rows);
  -- V6 RLS: an authenticated non-owner and a blocked user see exactly their snapshot id sets, W3 adds nothing for
  -- the blocked user, events and the snapshot stay closed to API roles.
  SELECT string_agg(s.who || '/' || s.tbl, ', ') INTO x FROM kan719_z02_snap.visible s WHERE pg_temp.z_as_ids(s.uid, s.tbl) IS DISTINCT FROM s.ids;
  IF x IS NOT NULL THEN leak := leak || ' id-set changed for ' || x; END IF;
  IF pg_temp.z_sees('00000000-0000-0000-0000-0000000000a6', 'games', '78100000-0000-0000-0000-000000000003')
     OR pg_temp.z_sees('00000000-0000-0000-0000-0000000000a6', 'games', '78100000-0000-0000-0000-000000000001') THEN leak := leak || ' blocked sees the owner''s game'; END IF;
  IF has_table_privilege('authenticated', 'public.events', 'SELECT') AND EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND NOT relrowsecurity) THEN
    leak := leak || ' events readable without RLS'; END IF;
  IF has_schema_privilege('authenticated', 'kan719_z02_snap', 'USAGE') OR has_schema_privilege('anon', 'kan719_z02_snap', 'USAGE') THEN leak := leak || ' snapshot reachable'; END IF;
  IF leak <> '' THEN RAISE EXCEPTION 'KAN-779 V6 FAIL:%', leak; END IF;
  RAISE NOTICE 'KAN-779 V6 PASS: authenticated non-owner and blocked user see exactly their snapshot id sets (%); blocked user does not see the owner''s game or W3; snapshot schema closed to API roles',
    (SELECT string_agg(who || '/' || tbl || ' ' || split_part(ids, ':', 1), ', ' ORDER BY who, tbl) FROM kan719_z02_snap.visible);
END $z6$;

ROLLBACK;

-- ---------------------------------------------------------------------------------------------
-- Z7 the ROLLBACK left data and catalogue intact
-- ---------------------------------------------------------------------------------------------
DO $z7$ BEGIN
  IF (SELECT cat FROM z_fp0) IS DISTINCT FROM pg_temp.z_catalog_md5() THEN RAISE EXCEPTION 'KAN-779 Z7 FAIL: the catalogue changed'; END IF;
  IF (SELECT data FROM z_fp0) IS DISTINCT FROM pg_temp.z_data_md5() THEN
    RAISE EXCEPTION 'KAN-779 Z7 FAIL: table data changed: before % after %', (SELECT data FROM z_fp0), pg_temp.z_data_md5();
  END IF;
  RAISE NOTICE 'KAN-779 Z7 PASS: after ROLLBACK catalogue md5 % and data (%) identical to before; kan719_z02_snap gone', left((SELECT cat FROM z_fp0), 12), (SELECT data FROM z_fp0);
  RAISE NOTICE 'KAN-779 RESTORE TEST PASS';
END $z7$;
