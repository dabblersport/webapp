-- KAN-776 (KAN-718 D08, Epic KAN-708): rollback, temporary-sync-disable and write-loss-guard probe.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. The guard refuses a Supabase-looking database and any database whose name
-- does not start with k776. Companion runbook: supabase/tests/events_p4/KAN718_RUNBOOK.md (sections R0-R3, G1-G5).
-- Nothing here is a migration. Everything below runs inside ONE transaction that ends in ROLLBACK, and the probe
-- proves afterwards that the catalogue and the table data are md5-identical to what they were before it started.
--
-- INPUT: the KAN-774 manifest, verbatim. This file does not restate the column/object list. It needs the TEMP
-- tables k774_retained and k774_manifest created by the manifest section of
-- supabase/tests/events_p4/kan718_d06_manifest_check.sql (from "CREATE TEMP TABLE k774_retained" up to the
-- "M1-M5" banner), loaded into the SAME psql session first:
--   sed -n '/^CREATE TEMP TABLE k774_retained/,/^-- M1-M5/p' supabase/tests/events_p4/kan718_d06_manifest_check.sql > /tmp/k774_manifest.sql
--   psql -X -h <socket> -p <port> -U postgres -d k776<name> -v ON_ERROR_STOP=1 \
--        -f /tmp/k774_manifest.sql -f supabase/tests/events_p4/kan718_d08_rollback_probe.sql
--
--   P0  guard + before-fingerprint (catalogue of schema public + md5 of games, meetups, events, meetup_attendees)
--   P1  seed one game + one meetup through the legacy path, with fixed original timestamps and NULLs
--   P2  the "backup": a copy of games/meetups/events taken now. Everything written after this is post-backup
--   P3  W1, a post-cutover write through the authorised ops path kan712_update_event_shared (service_role)
--   P4  R0 temporary sync disable: compat mirror off, divergence detected, resync, parity back to 0
--   P5  capture the shape of every manifest object (columns, triggers + enabled state, constraints, indexes,
--       policies, publication) and the legacy rows; the visibility baseline for a stranger and a blocked user
--   P6  phase 4 under the write-loss guard: G1 lock, G2 parity, G3 fingerprint, sync off, the manifest in order
--       (hard-blocked entries refused, baseline-only entries skipped), NEGATIVE 2a (a write landed mid-surgery
--       is caught), G4 fingerprint equal
--   P7  post-phase-4 writes: the ops path is closed (55000), the compat mirror breaks every events UPDATE once
--       the columns are gone (finding), W2 an events UPDATE, W3 a brand-new game (events + games row)
--   P8  NEGATIVE 1: a backup restore loses W1, W2 and W3
--   P9  R2 rollback: rebuild the dropped columns from events + subtype rows (the complete restore source)
--   P10 verify: shapes equal the capture, parity 0, counts equal, every row equals its pre-phase-4 value or its
--       post-phase-4 write, ids/NULLs/original timestamps kept, nobody sees anything extra
--   P11 NEGATIVE 2b: a divergence between legacy and events makes the phase-4 preflight refuse
--   P12 ROLLBACK; after-fingerprint equals before-fingerprint
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------
-- P0 guard
-- ---------------------------------------------------------------------------------------------
DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-776: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^k776' THEN
    RAISE EXCEPTION 'KAN-776: database % is not a KAN-776 throwaway database (name must start with k776); refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-776: run as a superuser (the probe alters tables inside a rolled-back transaction)';
  END IF;
  IF to_regclass('pg_temp.k774_manifest') IS NULL OR to_regclass('pg_temp.k774_retained') IS NULL THEN
    RAISE EXCEPTION 'KAN-776: k774_manifest/k774_retained not loaded; run the manifest section of kan718_d06_manifest_check.sql first in this session';
  END IF;
  IF (SELECT count(*) FROM k774_manifest) <> 130 OR (SELECT count(*) FROM k774_manifest WHERE kind = 'column') <> 47 THEN
    RAISE EXCEPTION 'KAN-776: the loaded manifest has % entries (% columns); KAN-774 has 130 (47 columns)',
      (SELECT count(*) FROM k774_manifest), (SELECT count(*) FROM k774_manifest WHERE kind = 'column');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'KAN-776: the database is not cut over (KAN-712 compat mirror missing or disabled); the probe needs phase 3';
  END IF;
END $g$;

-- Catalogue fingerprint of schema public (names and definitions, never OIDs) and data fingerprint.
CREATE FUNCTION pg_temp.k776_catalog_md5() RETURNS text LANGUAGE sql AS $f$
SELECT md5(concat_ws('#',
  (SELECT string_agg(c.relname || ':' || c.relkind::text, ',' ORDER BY c.relname) FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || '.' || a.attname || ':' || a.attnum || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull
                     || ':' || coalesce(pg_get_expr(d.adbin, d.adrelid), '') || ':' || coalesce(a.attacl::text, ''), ',' ORDER BY c.relname, a.attnum)
     FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE c.relnamespace = 'public'::regnamespace AND a.attnum > 0 AND NOT a.attisdropped),
  (SELECT string_agg(c.relname || '.' || t.tgname || ':' || t.tgenabled::text || ':' || pg_get_triggerdef(t.oid), ',' ORDER BY c.relname, t.tgname)
     FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal),
  (SELECT string_agg(c.relname || '.' || k.conname || ':' || pg_get_constraintdef(k.oid), ',' ORDER BY c.relname, k.conname)
     FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || ':' || pg_get_indexdef(i.indexrelid), ',' ORDER BY c.relname)
     FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(c.relname || '.' || p.polname || ':' || p.polcmd::text || ':' || p.polroles::text || ':' || coalesce(pg_get_expr(p.polqual, p.polrelid), '')
                     || ':' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), ',' ORDER BY c.relname, p.polname)
     FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid WHERE c.relnamespace = 'public'::regnamespace),
  (SELECT string_agg(pb.pubname || ':' || c.relname || ':' || coalesce(r.prattrs::text, '*') || ':' || coalesce(pg_get_expr(r.prqual, r.prrelid), ''), ',' ORDER BY pb.pubname, c.relname)
     FROM pg_publication_rel r JOIN pg_publication pb ON pb.oid = r.prpubid JOIN pg_class c ON c.oid = r.prrelid),
  (SELECT string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || '):' || md5(p.prosrc) || ':' || p.prosecdef || ':'
                     || coalesce(p.proconfig::text, '') || ':' || coalesce(p.proacl::text, ''), ',' ORDER BY p.proname, pg_get_function_identity_arguments(p.oid))
     FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace)))
$f$;
CREATE FUNCTION pg_temp.k776_data_md5() RETURNS text LANGUAGE sql AS $f$
SELECT concat_ws(' ',
  'games=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t),
  'meetups=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t),
  'events=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t),
  'meetup_attendees=' || (SELECT count(*) || ':' || md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.meetup_attendees t))
$f$;
CREATE TEMP TABLE k776_fp0 AS SELECT pg_temp.k776_catalog_md5() AS cat, pg_temp.k776_data_md5() AS data;

-- ---------------------------------------------------------------------------------------------
-- The write-loss guard (runbook G1-G4), as session-local functions. The runbook uses these bodies verbatim.
-- ---------------------------------------------------------------------------------------------
-- The manifest's dropped (non-hard) columns of one table.
CREATE FUNCTION pg_temp.k776_dropped(p_tbl text) RETURNS text[] LANGUAGE sql STABLE AS $f$
  SELECT coalesce(array_agg(obj ORDER BY seq), '{}') FROM k774_manifest WHERE kind = 'column' AND NOT hard AND tbl = p_tbl
$f$;
-- G3/G4: count + md5 of every events row and of every surviving subtype column. Identical before and after the
-- column surgery unless a row was written in between.
CREATE FUNCTION pg_temp.k776_fp() RETURNS text LANGUAGE sql AS $f$
SELECT concat_ws('|',
  (SELECT count(*) || ':' || md5(coalesce(string_agg(to_jsonb(e)::text, ',' ORDER BY e.id), '')) FROM public.events e),
  (SELECT count(*) || ':' || md5(coalesce(string_agg((to_jsonb(g) - pg_temp.k776_dropped('games'))::text, ',' ORDER BY g.id), '')) FROM public.games g),
  (SELECT count(*) || ':' || md5(coalesce(string_agg((to_jsonb(m) - pg_temp.k776_dropped('meetups'))::text, ',' ORDER BY m.id), '')) FROM public.meetups m))
$f$;
-- G2: refuse when legacy and events diverge (KAN-711 parity view: missing, orphan, unlinked, mismatched field).
CREATE FUNCTION pg_temp.k776_guard_parity() RETURNS void LANGUAGE plpgsql AS $f$
DECLARE n bigint; x text;
BEGIN
  SELECT count(*), string_agg(kind || ':' || id || ':' || array_to_string(mismatched_fields, '+'), ', ')
    INTO n, x FROM public.kan711_events_parity;
  IF n > 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k776_legacy_events_diverged',
      DETAIL = format('%s divergent row(s): %s', n, left(x, 400)), HINT = 'Run runbook R0 resync; do not start phase 4.';
  END IF;
END $f$;
-- G1+G2+G3: the phase-4 preflight. Returns the fingerprint the surgery must preserve.
CREATE FUNCTION pg_temp.k776_phase4_preflight() RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;
  PERFORM pg_temp.k776_guard_parity();
  RETURN pg_temp.k776_fp();
END $f$;
-- G4: refuse to continue (and so to COMMIT) when the fingerprint moved.
CREATE FUNCTION pg_temp.k776_assert_fp(p_expected text, p_stage text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_fp text := pg_temp.k776_fp();
BEGIN
  IF now_fp IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k776_write_landed_mid_surgery',
      DETAIL = format('%s: fingerprint %s, expected %s', p_stage, left(md5(now_fp), 12), left(md5(p_expected), 12)),
      HINT = 'ROLLBACK the phase-4 transaction; never COMMIT past this.';
  END IF;
END $f$;
-- R0 resync: with the compat mirror enabled again, re-fire it for every diverged row by a no-op events UPDATE;
-- the KAN-711 keeper pins updated_at to the events value, so the resync stamps nothing new. Returns rows touched.
CREATE FUNCTION pg_temp.k776_r0_resync() RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE r record; n bigint := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass
                  AND tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'k776_r0_sync_still_off', HINT = 'ENABLE the compat mirror first.';
  END IF;
  LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;
  FOR r IN SELECT p.id, e.updated_at FROM public.kan711_events_parity p JOIN public.events e ON e.id = p.id
            WHERE NOT p.missing_event AND NOT p.orphan_event AND NOT p.unlinked LOOP
    PERFORM set_config('kan711.src_updated_at', r.updated_at::text, true);
    UPDATE public.events SET updated_at = updated_at WHERE id = r.id;
    n := n + 1;
  END LOOP;
  PERFORM set_config('kan711.src_updated_at', '', true);
  RETURN n;
END $f$;
-- The shape of every manifest object, by name (never OID). Used for the capture and for the after-rebuild check.
CREATE FUNCTION pg_temp.k776_shape() RETURNS TABLE(kind text, tbl text, name text, def text, extra text, ord int) LANGUAGE sql AS $f$
  SELECT 'column', c.relname::text, a.attname::text, format_type(a.atttypid, a.atttypmod),
         jsonb_build_object('notnull', a.attnotnull, 'default', pg_get_expr(d.adbin, d.adrelid),
                            'comment', col_description(a.attrelid, a.attnum), 'acl', a.attacl::text)::text, a.attnum::int
    FROM k774_manifest m JOIN pg_class c ON c.relnamespace = 'public'::regnamespace AND c.relname = m.tbl
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = m.obj AND NOT a.attisdropped
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
   WHERE m.kind = 'column' AND NOT m.hard
  UNION ALL
  SELECT 'trigger', c.relname::text, t.tgname::text, pg_get_triggerdef(t.oid), t.tgenabled::text, 0
    FROM k774_manifest m JOIN pg_trigger t ON t.tgname = m.obj JOIN pg_class c ON c.oid = t.tgrelid AND c.relname = m.tbl
   WHERE m.kind = 'trigger'
  UNION ALL
  SELECT 'constraint', c.relname::text, k.conname::text, pg_get_constraintdef(k.oid), '', 0
    FROM k774_manifest m JOIN pg_constraint k ON k.conname = m.obj JOIN pg_class c ON c.oid = k.conrelid AND c.relname = m.tbl
   WHERE m.kind = 'constraint'
  UNION ALL
  SELECT 'index', m.tbl, i.relname::text, pg_get_indexdef(i.oid), '', 0
    FROM k774_manifest m JOIN pg_class i ON i.relnamespace = 'public'::regnamespace AND i.relname = m.obj AND i.relkind = 'i'
   WHERE m.kind = 'index'
  UNION ALL
  SELECT 'policy', c.relname::text, p.polname::text, coalesce(pg_get_expr(p.polqual, p.polrelid), ''),
         jsonb_build_object('wc', pg_get_expr(p.polwithcheck, p.polrelid), 'cmd', p.polcmd, 'roles', p.polroles::text, 'perm', p.polpermissive)::text, 0
    FROM k774_manifest m JOIN pg_policy p ON p.polname = split_part(m.obj, ' ', 1) JOIN pg_class c ON c.oid = p.polrelid
   WHERE m.kind = 'policy'
  UNION ALL
  SELECT 'publication', c.relname::text, pb.pubname::text,
         format('ONLY %s', r.prrelid::regclass)
           || coalesce(' (' || (SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attname) FROM pg_attribute a
                                  WHERE a.attrelid = r.prrelid AND a.attnum = ANY (r.prattrs::int2[])) || ')', '')
           || coalesce(' WHERE (' || pg_get_expr(r.prqual, r.prrelid) || ')', ''), '', 0
    FROM pg_publication_rel r JOIN pg_publication pb ON pb.oid = r.prpubid AND pb.pubname = 'supabase_realtime'
    JOIN pg_class c ON c.oid = r.prrelid
$f$;
-- Run a count as an API user (copy of the KAN-774 S4 helper).
CREATE FUNCTION pg_temp.k776_as(p_uid uuid, p_sql text) RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE n bigint; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  EXECUTE 'SET LOCAL ROLE ' || CASE WHEN p_uid IS NULL THEN 'anon' ELSE 'authenticated' END;
  EXECUTE p_sql INTO n;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN n; END $f$;

BEGIN;
SET LOCAL lock_timeout = '10s';
-- ALTER TABLE refuses a table with pending deferred trigger events (the KAN-710 link-check constraint triggers):
-- check constraints at statement end for this whole transaction. The runbook does the same (R2.0).
SET CONSTRAINTS ALL IMMEDIATE;

-- ---------------------------------------------------------------------------------------------
-- P1 seed: one game + one meetup through the legacy path, fixed original timestamps
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k776_ids(k text PRIMARY KEY, id uuid) ON COMMIT DROP;
INSERT INTO k776_ids VALUES ('G', '77600000-0000-0000-0000-000000000001'), ('M', '77600000-0000-0000-0000-00000000f001'),
                            ('N', '77600000-0000-0000-0000-000000000003');
DO $p1$
DECLARE owner uuid := '00000000-0000-0000-0000-0000000000a1';
BEGIN
  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                            sport_id, geo_location_id, area_id, created_at, updated_at)
  VALUES ('77600000-0000-0000-0000-000000000001', 'D08 game', '00000000-0000-0000-0000-0000000000b1', owner,
          '2031-03-01 18:00+00', '2031-03-01 19:00+00', 10, 'public', 'open',
          '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
          '2026-01-01 10:00+00', '2026-01-01 10:00+00');
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
      'id', '77600000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'D08 meetup',
      'start_at', '2031-03-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public',
      'created_at', '2026-01-02 10:00+00', 'updated_at', '2026-01-02 10:00+00'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
  IF (SELECT count(*) FROM public.events WHERE id IN ('77600000-0000-0000-0000-000000000001', '77600000-0000-0000-0000-00000000f001')) <> 2 THEN
    RAISE EXCEPTION 'KAN-776 P1 FAIL: the legacy inserts did not create exactly two events parents';
  END IF;
  IF (SELECT created_at FROM public.games WHERE id = '77600000-0000-0000-0000-000000000001') <> '2026-01-01 10:00+00'
     OR (SELECT created_at FROM public.events WHERE id = '77600000-0000-0000-0000-000000000001') <> '2026-01-01 10:00+00'
     OR (SELECT created_at FROM public.events WHERE id = '77600000-0000-0000-0000-00000000f001') <> '2026-01-02 10:00+00' THEN
    RAISE EXCEPTION 'KAN-776 P1 FAIL: original created_at not carried into events';
  END IF;
  PERFORM pg_temp.k776_guard_parity();
  RAISE NOTICE 'KAN-776 P1 PASS: 1 game + 1 meetup seeded through the legacy path; events parents created; parity 0';
END $p1$;

-- ---------------------------------------------------------------------------------------------
-- P2 the backup. A pre-phase-4 dump is exactly this: a copy of the rows as they were at backup time.
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k776_bk_games   ON COMMIT DROP AS SELECT * FROM public.games;
CREATE TEMP TABLE k776_bk_meetups ON COMMIT DROP AS SELECT * FROM public.meetups;
CREATE TEMP TABLE k776_bk_events  ON COMMIT DROP AS SELECT * FROM public.events;

-- ---------------------------------------------------------------------------------------------
-- P3 W1: a post-cutover write through the authorised write path (kan712_update_event_shared, service_role).
-- updated_at is pinned to a distinct instant (kan711.src_updated_at, the KAN-711 keeper) so that a rebuild which
-- stamps now() instead of carrying the original would be caught: inside one transaction now() never moves.
-- ---------------------------------------------------------------------------------------------
DO $p3$
DECLARE r jsonb;
BEGIN
  PERFORM set_config('kan711.src_updated_at', '2026-07-01 12:00+00', true);
  SET LOCAL ROLE service_role;
  r := public.kan712_update_event_shared('77600000-0000-0000-0000-000000000001', '{"title": "W1 game", "capacity": 12}');
  r := public.kan712_update_event_shared('77600000-0000-0000-0000-00000000f001', '{"title": "W1 meetup"}');
  RESET ROLE;
  PERFORM set_config('kan711.src_updated_at', '', true);
  IF (SELECT row(title, capacity, updated_at, created_at)::text FROM public.games WHERE id = '77600000-0000-0000-0000-000000000001')
       IS DISTINCT FROM row('W1 game', 12, '2026-07-01 12:00+00'::timestamptz, '2026-01-01 10:00+00'::timestamptz)::text
     OR (SELECT row(title, end_at, capacity, updated_at)::text FROM public.meetups WHERE id = '77600000-0000-0000-0000-00000000f001')
       IS DISTINCT FROM row('W1 meetup', NULL::timestamptz, NULL::int, '2026-07-01 12:00+00'::timestamptz)::text THEN
    RAISE EXCEPTION 'KAN-776 P3 FAIL: W1 did not reach legacy through the compat mirror with its timestamps';
  END IF;
  PERFORM pg_temp.k776_guard_parity();
  RAISE NOTICE 'KAN-776 P3 PASS: W1 written through kan712_update_event_shared as service_role; legacy mirrored it (title, capacity, updated_at 2026-07-01, created_at kept, meetup NULLs kept); parity 0';
END $p3$;

-- ---------------------------------------------------------------------------------------------
-- P4 R0: temporary sync disable, divergence detection, resync.
-- ---------------------------------------------------------------------------------------------
DO $p4$
DECLARE n bigint; err text; st text;
BEGIN
  ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;            -- R0.1 sync off
  BEGIN                                                                                       -- R0.2 ops path fails closed
    PERFORM public.kan712_update_event_shared('77600000-0000-0000-0000-00000000f001', '{"title": "never"}');
    RAISE EXCEPTION 'KAN-776 P4 FAIL: kan712_update_event_shared ran with the compat mirror disabled';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, st = RETURNED_SQLSTATE;
    IF err <> 'kan712_not_cut_over' THEN RAISE; END IF;
  END;
  PERFORM set_config('kan711.src_updated_at', '2026-07-15 12:00+00', true);                   -- a write while sync is off
  UPDATE public.events SET title = 'R0 meetup' WHERE id = '77600000-0000-0000-0000-00000000f001';
  PERFORM set_config('kan711.src_updated_at', '', true);
  SELECT count(*) INTO n FROM public.kan711_events_parity;                                    -- R0.3 divergence detected
  IF n <> 1 OR (SELECT title FROM public.meetups WHERE id = '77600000-0000-0000-0000-00000000f001') <> 'W1 meetup' THEN
    RAISE EXCEPTION 'KAN-776 P4 FAIL: expected exactly 1 divergent row while sync is off, got %', n;
  END IF;
  ALTER TABLE public.events ENABLE TRIGGER trg_zz_kan712_events_compat_mirror;             -- R0.4 sync on + resync
  PERFORM pg_temp.k776_r0_resync();
  PERFORM pg_temp.k776_guard_parity();
  IF (SELECT row(title, updated_at, end_at, capacity)::text FROM public.meetups WHERE id = '77600000-0000-0000-0000-00000000f001')
       IS DISTINCT FROM row('R0 meetup', '2026-07-15 12:00+00'::timestamptz, NULL::timestamptz, NULL::int)::text THEN
    RAISE EXCEPTION 'KAN-776 P4 FAIL: resync did not carry the events value and its updated_at into legacy';
  END IF;
  RAISE NOTICE 'KAN-776 P4 PASS: R0 sync off -> ops path refused (55000 %), 1 divergent row detected; sync on + resync -> parity 0, legacy carries the write with its own updated_at', err;
END $p4$;

-- ---------------------------------------------------------------------------------------------
-- P5 capture: the manifest objects' shape, the legacy rows, the visibility baseline.
-- A scratch table is added to supabase_realtime first, standing for every other production table in that
-- publication, so that P6 can show what manifest 201/202 (SET TABLE) does to them.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE public.k776_scratch_pub(id int PRIMARY KEY);
ALTER PUBLICATION supabase_realtime ADD TABLE public.k776_scratch_pub;
CREATE TEMP TABLE k776_shape_pre ON COMMIT DROP AS SELECT * FROM pg_temp.k776_shape();
SELECT set_config('search_path', '', true);
CREATE TEMP TABLE k776_shape_pre_q ON COMMIT DROP AS SELECT * FROM pg_temp.k776_shape();    -- schema-qualified defs, used to rebuild
SELECT set_config('search_path', '"$user", public', true);
CREATE TEMP TABLE k776_pre ON COMMIT DROP AS
  SELECT 'games'::text tbl, g.id, to_jsonb(g) j FROM public.games g UNION ALL SELECT 'meetups', m.id, to_jsonb(m) FROM public.meetups m;
CREATE TEMP TABLE k776_vis ON COMMIT DROP AS
  SELECT w.who, w.uid, pg_temp.k776_as(w.uid, $q$SELECT count(*) FROM public.games WHERE id::text LIKE '77600000%'$q$) g,
         pg_temp.k776_as(w.uid, $q$SELECT count(*) FROM public.meetups WHERE id::text LIKE '77600000%'$q$) m
    FROM (VALUES ('stranger', '00000000-0000-0000-0000-00000000dead'::uuid), ('blocked', '00000000-0000-0000-0000-0000000000a6'::uuid)) w(who, uid);
DO $p5$ BEGIN
  IF (SELECT count(*) FROM k776_shape_pre WHERE kind = 'column') <> 44 OR (SELECT count(*) FROM k776_shape_pre WHERE kind = 'trigger') <> 33
     OR (SELECT count(*) FROM k776_shape_pre WHERE kind = 'constraint') <> 28 OR (SELECT count(*) FROM k776_shape_pre WHERE kind = 'index') <> 3
     OR (SELECT count(*) FROM k776_shape_pre WHERE kind = 'policy') <> 4 THEN
    RAISE EXCEPTION 'KAN-776 P5 FAIL: capture counts differ from the manifest: %',
      (SELECT string_agg(kind || '=' || n, ' ') FROM (SELECT kind, count(*) n FROM k776_shape_pre GROUP BY kind) s);
  END IF;
  RAISE NOTICE 'KAN-776 P5 PASS: captured % (44 dropped columns = 47 minus 3 hard-blocked; 13 baseline-only indexes absent locally); visibility baseline %',
    (SELECT string_agg(kind || '=' || n, ' ' ORDER BY kind) FROM (SELECT kind, count(*) n FROM k776_shape_pre GROUP BY kind) s),
    (SELECT string_agg(who || ':games ' || g || ' meetups ' || m, ', ') FROM k776_vis);
END $p5$;

-- ---------------------------------------------------------------------------------------------
-- P6 phase 4 under the write-loss guard
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k776_run(k text PRIMARY KEY, v text) ON COMMIT DROP;
DO $p6$
DECLARE fp1 text; r record; ok int := 0; refused int := 0; skipped int := 0; bad text := ''; err text; det text;
BEGIN
  fp1 := pg_temp.k776_phase4_preflight();                                                     -- G1 lock, G2 parity, G3 fingerprint
  INSERT INTO k776_run VALUES ('fp1', fp1);
  ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;            -- sync off for the surgery (finding F1)
  FOR r IN SELECT * FROM k774_manifest ORDER BY seq LOOP
    IF NOT r.local THEN skipped := skipped + 1; CONTINUE; END IF;
    BEGIN
      EXECUTE r.stmt;
      IF r.hard THEN bad := bad || format(' %s ran but is hard-blocked', r.seq); END IF;
      ok := ok + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL;
      IF r.hard AND coalesce(det, '') ~ 'v_meetup_list' THEN refused := refused + 1;
      ELSE bad := bad || format(' %s(%s)', r.seq, err); END IF;
    END;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'KAN-776 P6 FAIL: manifest run:%', bad; END IF;
  IF EXISTS (SELECT 1 FROM pg_publication_rel pr JOIN pg_class c ON c.oid = pr.prrelid WHERE c.relname = 'k776_scratch_pub') THEN
    RAISE EXCEPTION 'KAN-776 P6: expected manifest 201/202 (SET TABLE) to remove other tables from supabase_realtime';
  END IF;
  RAISE NOTICE 'KAN-776 P6 FINDING F2: manifest 201/202 use ALTER PUBLICATION ... SET TABLE, which REPLACES the publication list: after 202 supabase_realtime holds only %; k776_scratch_pub (standing for every other realtime table) was removed',
    (SELECT string_agg(c.relname || coalesce(pr.prattrs::text, ''), ', ') FROM pg_publication_rel pr JOIN pg_publication pb ON pb.oid = pr.prpubid AND pb.pubname = 'supabase_realtime' JOIN pg_class c ON c.oid = pr.prrelid);

  -- NEGATIVE 2a: a write that lands between G3 and G4 (simulated in-session; a second session cannot reach the
  -- tables because G1 holds SHARE ROW EXCLUSIVE, which clean776.sh proves with two real sessions).
  BEGIN
    UPDATE public.events SET title = 'mid-surgery write' WHERE id = '77600000-0000-0000-0000-000000000001';
    PERFORM pg_temp.k776_assert_fp(fp1, 'G4 after manifest');
    RAISE EXCEPTION 'KAN-776 NEG2a FAIL: the guard did not fire on a write that landed mid-surgery';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL;
    IF err <> 'k776_write_landed_mid_surgery' THEN RAISE EXCEPTION '%', err; END IF;
    RAISE NOTICE 'KAN-776 NEG2a PASS: a write that landed mid-surgery made the guard refuse: % (%)', err, det;
  END;
  PERFORM pg_temp.k776_assert_fp(fp1, 'G4 after manifest');                                -- the real G4
  RAISE NOTICE 'KAN-776 P6 PASS: G1 lock + G2 parity 0 + G3 fingerprint; % manifest statements ran without CASCADE, % refused exactly where hard-blocked (v_meetup_list), % baseline-only skipped; G4 fingerprint unchanged',
    ok, refused, skipped;
END $p6$;

-- ---------------------------------------------------------------------------------------------
-- P7 post-phase-4 writes
-- ---------------------------------------------------------------------------------------------
DO $p7$
DECLARE err text; st text;
BEGIN
  BEGIN                                                                                       -- finding F5: no ops path after phase 4
    PERFORM public.kan712_update_event_shared('77600000-0000-0000-0000-000000000001', '{"title": "never"}');
    RAISE EXCEPTION 'KAN-776 P7 FAIL: the ops path ran after phase 4';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL;
  END;
  BEGIN                                                                                       -- finding F1: compat mirror vs dropped columns
    ALTER TABLE public.events ENABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET title = title WHERE id = '77600000-0000-0000-0000-000000000001';
    err := 'none'; st := '-';
    RAISE EXCEPTION 'k776_no_error';
  EXCEPTION WHEN OTHERS THEN
    IF err IS NULL THEN GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, st = RETURNED_SQLSTATE; END IF;
  END;
  IF st = '-' THEN
    RAISE NOTICE 'KAN-776 P7 note: with trg_zz_kan712_events_compat_mirror re-enabled an events UPDATE still succeeded after phase 4';
  ELSE
    RAISE NOTICE 'KAN-776 P7 FINDING F1: trg_zz_kan712_events_compat_mirror is not in the manifest; enabled after phase 4 it makes every events UPDATE fail: % (%)', err, st;
  END IF;
  -- W2: an events UPDATE after phase 4 (stand-in for the post-phase-4 write path, which is not authored).
  PERFORM set_config('kan711.src_updated_at', '2026-08-01 12:00+00', true);
  UPDATE public.events SET title = 'W2 game', cancelled_reason = NULL WHERE id = '77600000-0000-0000-0000-000000000001';
  PERFORM set_config('kan711.src_updated_at', '', true);
  -- W3: a brand-new game created after phase 4: events row + a games row holding only retained columns.
  INSERT INTO public.events SELECT (jsonb_populate_record(NULL::public.events, to_jsonb(e) || jsonb_build_object(
      'id', '77600000-0000-0000-0000-000000000003', 'title', 'W3 game', 'request_id', NULL,
      'created_at', '2026-09-01 12:00+00', 'updated_at', '2026-09-01 12:00+00'))).*
    FROM public.events e WHERE e.id = '77600000-0000-0000-0000-000000000001';
  INSERT INTO public.games SELECT (jsonb_populate_record(NULL::public.games, to_jsonb(g) || jsonb_build_object(
      'id', '77600000-0000-0000-0000-000000000003', 'event_id', '77600000-0000-0000-0000-000000000003'))).*
    FROM public.games g WHERE g.id = '77600000-0000-0000-0000-000000000001';
  RAISE NOTICE 'KAN-776 P7 PASS: ops path closed after phase 4 (55000); W2 events UPDATE (updated_at 2026-08-01) and W3 new game (events + games retained columns) written';
END $p7$;

-- ---------------------------------------------------------------------------------------------
-- P8 NEGATIVE 1: the backup restore. Put the dropped columns back and fill them from the pre-phase-4 backup
-- (the most generous form: only the dropped columns are restored; a full dump restore also reverts events).
-- ---------------------------------------------------------------------------------------------
DO $p8$
DECLARE r record; cols text; lost text;
BEGIN
  BEGIN
    FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'column' ORDER BY tbl, ord LOOP
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN %I %s', r.tbl, r.name, r.def);
    END LOOP;
    FOR r IN SELECT tbl FROM (VALUES ('games'), ('meetups')) v(tbl) LOOP
      SELECT string_agg(format('%I = b.%I', name, name), ', ') INTO cols FROM k776_shape_pre_q WHERE kind = 'column' AND tbl = r.tbl;
      EXECUTE format('UPDATE public.%I t SET %s FROM pg_temp.%I b WHERE b.id = t.id', r.tbl, cols, 'k776_bk_' || r.tbl);
    END LOOP;
    SELECT concat_ws('; ',
      CASE WHEN (SELECT title FROM public.games WHERE id = '77600000-0000-0000-0000-000000000001') = 'D08 game'
           THEN 'W1+W2 lost (game title back to D08 game, events says W2 game)' END,
      CASE WHEN (SELECT capacity FROM public.games WHERE id = '77600000-0000-0000-0000-000000000001') = 10
           THEN 'W1 capacity 12 lost' END,
      CASE WHEN (SELECT title FROM public.meetups WHERE id = '77600000-0000-0000-0000-00000000f001') = 'D08 meetup'
           THEN 'W1+R0 meetup title lost' END,
      CASE WHEN (SELECT updated_at FROM public.games WHERE id = '77600000-0000-0000-0000-000000000001') = '2026-01-01 10:00+00'
           THEN 'updated_at back to the backup instant' END,
      CASE WHEN (SELECT title IS NULL FROM public.games WHERE id = '77600000-0000-0000-0000-000000000003')
           THEN 'W3 has no backup row: every restored column NULL' END,
      CASE WHEN NOT EXISTS (SELECT 1 FROM pg_temp.k776_bk_events WHERE id = '77600000-0000-0000-0000-000000000003')
           THEN 'a full dump restore drops W3 entirely' END) INTO lost;
    IF lost IS NULL OR lost = '' THEN RAISE EXCEPTION 'KAN-776 NEG1 FAIL: the backup restore did not lose the post-backup writes'; END IF;
    RAISE NOTICE 'KAN-776 NEG1 PASS: a backup restore loses post-backup writes: %', lost;
    RAISE EXCEPTION 'k776_neg1_undo';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'k776_neg1_undo' THEN RAISE; END IF;
  END;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-776 NEG1 FAIL: the naive restore was not undone';
  END IF;
END $p8$;

-- ---------------------------------------------------------------------------------------------
-- P9 R2: rebuild the dropped columns from the complete restore source, events + subtype rows (runbook R2.1-R2.11)
-- ---------------------------------------------------------------------------------------------
DO $p9$
DECLARE r record; cols text; srcs text; n bigint;
BEGIN
  LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;                 -- R2.1
  SELECT count(*) INTO n FROM (                                                                        -- R2.2 source complete
    SELECT g.id FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id WHERE e.id IS NULL OR e.event_type <> 'game' OR g.event_id <> g.id
    UNION ALL SELECT m.id FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id WHERE e.id IS NULL OR e.event_type <> 'meetup' OR m.event_id <> m.id
    UNION ALL SELECT e.id FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.event_id = e.id)
                                                 AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.event_id = e.id)) x;
  IF n <> 0 THEN RAISE EXCEPTION 'KAN-776 R2.2 FAIL: % subtype rows without an events parent (or orphan events); the restore source is incomplete', n; END IF;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'column' ORDER BY tbl, ord LOOP          -- R2.3 columns back, nullable
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN %I %s', r.tbl, r.name, r.def);
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'trigger' AND name IN ('trg_games_search_tsv', 'trg_meetups_search_tsv') LOOP
    EXECUTE r.def;                                                                                  -- R2.4 search_tsv triggers, ALWAYS
    EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER %I', r.tbl, r.name);
  END LOOP;
  PERFORM set_config('session_replication_role', 'replica', true);                                  -- R2.5 values from events
  FOR r IN SELECT tbl FROM (VALUES ('games'), ('meetups')) v(tbl) LOOP
    SELECT string_agg(quote_ident(s.name), ', ' ORDER BY s.ord),
           string_agg('e.' || quote_ident(CASE s.name WHEN 'rsvp_policy' THEN 'join_policy' ELSE s.name END), ', ' ORDER BY s.ord)
      INTO cols, srcs FROM k776_shape_pre_q s WHERE s.kind = 'column' AND s.tbl = r.tbl AND s.name <> 'search_tsv';
    IF EXISTS (SELECT 1 FROM k776_shape_pre_q s WHERE s.kind = 'column' AND s.tbl = r.tbl AND s.name <> 'search_tsv'
                AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.events'::regclass AND NOT a.attisdropped
                                 AND a.attname = CASE s.name WHEN 'rsvp_policy' THEN 'join_policy' ELSE s.name END)) THEN
      RAISE EXCEPTION 'KAN-776 R2.5 FAIL: a dropped %.column has no events source', r.tbl;
    END IF;
    EXECUTE format('UPDATE public.%I t SET (%s) = ROW(%s) FROM public.events e WHERE e.id = t.event_id', r.tbl, cols, srcs);
  END LOOP;
  PERFORM set_config('session_replication_role', 'origin', true);
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'trigger' AND name IN ('trg_games_search_tsv', 'trg_meetups_search_tsv') LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER %I', r.tbl, r.name);
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'column' ORDER BY tbl, ord LOOP            -- R2.6 defaults, NOT NULL, comments
    IF (r.extra::jsonb ->> 'default') IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I SET DEFAULT %s', r.tbl, r.name, r.extra::jsonb ->> 'default');
    END IF;
    IF (r.extra::jsonb ->> 'notnull')::boolean THEN
      EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I SET NOT NULL', r.tbl, r.name);
    END IF;
    IF (r.extra::jsonb ->> 'comment') IS NOT NULL THEN
      EXECUTE format('COMMENT ON COLUMN public.%I.%I IS %L', r.tbl, r.name, r.extra::jsonb ->> 'comment');
    END IF;
    IF (r.extra::jsonb ->> 'acl') IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-776 R2.6: column % has column-level grants %; restore them by hand', r.name, r.extra::jsonb ->> 'acl';
    END IF;
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'constraint' ORDER BY tbl, name LOOP      -- R2.7 constraints
    EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I %s', r.tbl, r.name, r.def);
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'index' ORDER BY name LOOP                  -- R2.8 indexes
    EXECUTE r.def;
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'trigger'                                    -- R2.9 triggers + enabled state
             AND name NOT IN ('trg_games_search_tsv', 'trg_meetups_search_tsv') ORDER BY tbl, name LOOP
    EXECUTE r.def;
    IF r.extra = 'D' THEN EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER %I', r.tbl, r.name); END IF;
    IF r.extra = 'A' THEN EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER %I', r.tbl, r.name); END IF;
    IF r.extra = 'R' THEN EXECUTE format('ALTER TABLE public.%I ENABLE REPLICA TRIGGER %I', r.tbl, r.name); END IF;
  END LOOP;
  FOR r IN SELECT * FROM k776_shape_pre_q WHERE kind = 'policy' LOOP                               -- R2.10 policies
    EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)%s', r.name, r.tbl, r.def,
                   coalesce(' WITH CHECK (' || (r.extra::jsonb ->> 'wc') || ')', ''));
  END LOOP;
  EXECUTE 'ALTER PUBLICATION supabase_realtime SET TABLE '                                         -- R2.11 publication list
    || (SELECT string_agg(def, ', ' ORDER BY tbl) FROM k776_shape_pre_q WHERE kind = 'publication');
  ALTER TABLE public.events ENABLE TRIGGER trg_zz_kan712_events_compat_mirror;                   -- R2.12 sync back on
  RAISE NOTICE 'KAN-776 P9 PASS: R2 rebuilt % columns from events + subtype rows, then % constraints, % indexes, % triggers, % policies, publication list; sync re-enabled',
    (SELECT count(*) FROM k776_shape_pre_q WHERE kind = 'column'), (SELECT count(*) FROM k776_shape_pre_q WHERE kind = 'constraint'),
    (SELECT count(*) FROM k776_shape_pre_q WHERE kind = 'index'), (SELECT count(*) FROM k776_shape_pre_q WHERE kind = 'trigger'),
    (SELECT count(*) FROM k776_shape_pre_q WHERE kind = 'policy');
END $p9$;

-- ---------------------------------------------------------------------------------------------
-- P10 verify the rollback
-- ---------------------------------------------------------------------------------------------
DO $p10$
DECLARE x text; n bigint; moved bigint; leak text := '';
  v_g uuid := '77600000-0000-0000-0000-000000000001'; v_m uuid := '77600000-0000-0000-0000-00000000f001'; v_n uuid := '77600000-0000-0000-0000-000000000003';
BEGIN
  -- V1 legacy shapes unchanged: every manifest object equals its capture (column ORDER excepted, finding F3)
  SELECT string_agg(kind || ':' || tbl || '.' || name, ', ') INTO x FROM (
    (SELECT kind, tbl, name, def, extra FROM k776_shape_pre EXCEPT SELECT kind, tbl, name, def, extra FROM pg_temp.k776_shape())
    UNION ALL
    (SELECT kind, tbl, name, def, extra FROM pg_temp.k776_shape() EXCEPT SELECT kind, tbl, name, def, extra FROM k776_shape_pre)) d;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-776 V1 FAIL: shape differs after rollback: %', x; END IF;
  SELECT count(*) INTO moved FROM k776_shape_pre p JOIN pg_temp.k776_shape() s USING (kind, tbl, name) WHERE p.kind = 'column' AND p.ord <> s.ord;
  RAISE NOTICE 'KAN-776 V1 PASS: types, NOT NULL, defaults, comments, % triggers (enabled state incl. % disabled), constraints, indexes, policies and the publication list equal the capture',
    (SELECT count(*) FROM k776_shape_pre WHERE kind = 'trigger'), (SELECT count(*) FROM k776_shape_pre WHERE kind = 'trigger' AND extra = 'D');
  RAISE NOTICE 'KAN-776 V1 FINDING F3: % of % restored columns moved to the end of the attribute order (ADD COLUMN appends); positional readers (SELECT *, INSERT without a column list, %%ROWTYPE, ROW(...)::table) see a different column order',
    moved, (SELECT count(*) FROM k776_shape_pre WHERE kind = 'column');

  -- V2 parity: legacy equals events on every shared column again (KAN-711 view, includes created_at/updated_at)
  PERFORM pg_temp.k776_guard_parity();
  -- V3 rows not doubled, counts equal legacy
  IF (SELECT count(*) - count(DISTINCT id) FROM public.events) <> 0
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM public.events WHERE event_type = 'game')
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM pg_temp.k776_bk_games) + 1
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM pg_temp.k776_bk_meetups)
     OR EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id) OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-776 V3 FAIL: counts diverge or rows doubled';
  END IF;
  RAISE NOTICE 'KAN-776 V2/V3 PASS: parity 0; games % = game events, meetups % = meetup events, no duplicate ids, event_id = id everywhere (backup + 1 new game)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups);

  -- V4 every legacy row equals its pre-phase-4 value, all columns by name, except the two rows written after phase 4
  SELECT count(*) INTO n FROM k776_pre p
   WHERE p.id NOT IN (v_g) AND p.j IS DISTINCT FROM (SELECT to_jsonb(t) FROM public.games t WHERE t.id = p.id AND p.tbl = 'games'
                                                    UNION ALL SELECT to_jsonb(t) FROM public.meetups t WHERE t.id = p.id AND p.tbl = 'meetups');
  IF n <> 0 THEN
    RAISE EXCEPTION 'KAN-776 V4 FAIL: % legacy rows differ from their pre-phase-4 value, e.g. %', n,
      (SELECT p.id FROM k776_pre p WHERE p.tbl = 'meetups' AND p.id <> v_g AND p.j IS DISTINCT FROM (SELECT to_jsonb(t) FROM public.meetups t WHERE t.id = p.id) LIMIT 1);
  END IF;
  RAISE NOTICE 'KAN-776 V4 PASS: % of % pre-phase-4 legacy rows equal their pre-phase-4 value on every column incl. search_tsv, created_at, updated_at (the meetup carries W1 + R0)',
    (SELECT count(*) - 1 FROM k776_pre), (SELECT count(*) FROM k776_pre);

  -- V5 the post-phase-4 writes are in legacy, with ids, NULLs and original timestamps
  IF (SELECT (to_jsonb(t) - '{title,updated_at,search_tsv}'::text[]) FROM public.games t WHERE id = v_g)
       IS DISTINCT FROM (SELECT j - '{title,updated_at,search_tsv}'::text[] FROM k776_pre WHERE id = v_g)
     OR (SELECT row(title, capacity, created_at, updated_at, cancelled_reason, cancelled_at)::text FROM public.games WHERE id = v_g)
       IS DISTINCT FROM row('W2 game', 12, '2026-01-01 10:00+00'::timestamptz, '2026-08-01 12:00+00'::timestamptz, NULL::text, NULL::timestamptz)::text
     OR NOT (SELECT search_tsv @@ to_tsquery('simple', 'w2') FROM public.games WHERE id = v_g)
     OR (SELECT row(id, event_id, title, created_at, updated_at)::text FROM public.games WHERE id = v_n)
       IS DISTINCT FROM row(v_n, v_n, 'W3 game', '2026-09-01 12:00+00'::timestamptz, '2026-09-01 12:00+00'::timestamptz)::text
     OR (SELECT row(title, end_at, capacity, created_at, updated_at)::text FROM public.meetups WHERE id = v_m)
       IS DISTINCT FROM row('R0 meetup', NULL::timestamptz, NULL::int, '2026-01-02 10:00+00'::timestamptz, '2026-07-15 12:00+00'::timestamptz)::text
     OR (SELECT rsvp_policy FROM public.meetups WHERE id = v_m) IS DISTINCT FROM (SELECT join_policy FROM public.events WHERE id = v_m) THEN
    RAISE EXCEPTION 'KAN-776 V5 FAIL: a post-cutover write, id, NULL or original timestamp was not carried into legacy';
  END IF;
  RAISE NOTICE 'KAN-776 V5 PASS: W2 (game title, updated_at 2026-08-01, created_at 2026-01-01, cancelled_* NULL, search_tsv recomputed), W3 (new id, created_at 2026-09-01), W1+R0 (meetup end_at/capacity NULL, updated_at 2026-07-15, rsvp_policy = join_policy) all present in legacy';

  -- V6 a stranger or a blocked user sees nothing extra
  IF pg_temp.k776_as('00000000-0000-0000-0000-00000000dead', $q$SELECT count(*) FROM public.games WHERE id::text LIKE '77600000%' AND id <> '77600000-0000-0000-0000-000000000003'$q$)
       <> (SELECT g FROM k776_vis WHERE who = 'stranger')
     OR pg_temp.k776_as('00000000-0000-0000-0000-00000000dead', $q$SELECT count(*) FROM public.meetups WHERE id::text LIKE '77600000%'$q$)
       <> (SELECT m FROM k776_vis WHERE who = 'stranger') THEN leak := leak || ' stranger'; END IF;
  IF pg_temp.k776_as('00000000-0000-0000-0000-0000000000a6', $q$SELECT count(*) FROM public.games WHERE id::text LIKE '77600000%'$q$) <> 0
     OR pg_temp.k776_as('00000000-0000-0000-0000-0000000000a6', $q$SELECT count(*) FROM public.meetups WHERE id::text LIKE '77600000%'$q$) <> 0 THEN
    leak := leak || ' blocked'; END IF;
  BEGIN
    IF pg_temp.k776_as('00000000-0000-0000-0000-00000000dead', $q$SELECT count(*) FROM public.events WHERE id::text LIKE '77600000%'$q$) <> 0 THEN
      leak := leak || ' events'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN RESET ROLE;
  END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a6', true);
  IF public._can_view_game(v_g) OR public._can_view_game(v_n) THEN leak := leak || ' _can_view_game(blocked)'; END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  IF leak <> '' THEN RAISE EXCEPTION 'KAN-776 V6 FAIL: extra visibility after rollback:%', leak; END IF;
  RAISE NOTICE 'KAN-776 V6 PASS: after rollback the stranger sees exactly the pre-phase-4 baseline (%), the blocked user sees 0 games/meetups, events stays closed to API roles',
    (SELECT 'games ' || g || ' meetups ' || m FROM k776_vis WHERE who = 'stranger');
END $p10$;

-- ---------------------------------------------------------------------------------------------
-- P11 NEGATIVE 2b: legacy and events diverge -> the phase-4 preflight refuses
-- ---------------------------------------------------------------------------------------------
DO $p11$
DECLARE err text; det text;
BEGIN
  BEGIN
    ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
    UPDATE public.events SET capacity = 20 WHERE id = '77600000-0000-0000-0000-000000000001';
    PERFORM pg_temp.k776_phase4_preflight();
    RAISE EXCEPTION 'KAN-776 NEG2b FAIL: the preflight accepted a diverged database';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL;
    IF err <> 'k776_legacy_events_diverged' THEN RAISE EXCEPTION '%', err; END IF;
    RAISE NOTICE 'KAN-776 NEG2b PASS: legacy/events divergence made the phase-4 preflight refuse: % (%)', err, det;
  END;
  PERFORM pg_temp.k776_guard_parity();
END $p11$;

ROLLBACK;

-- ---------------------------------------------------------------------------------------------
-- P12 the probe left nothing behind
-- ---------------------------------------------------------------------------------------------
DO $p12$ BEGIN
  IF (SELECT cat FROM k776_fp0) IS DISTINCT FROM pg_temp.k776_catalog_md5() THEN
    RAISE EXCEPTION 'KAN-776 P12 FAIL: the public catalogue changed';
  END IF;
  IF (SELECT data FROM k776_fp0) IS DISTINCT FROM pg_temp.k776_data_md5() THEN
    RAISE EXCEPTION 'KAN-776 P12 FAIL: table data changed: before % after %', (SELECT data FROM k776_fp0), pg_temp.k776_data_md5();
  END IF;
  RAISE NOTICE 'KAN-776 P12 PASS: after ROLLBACK catalogue md5 % and data % identical to before', left((SELECT cat FROM k776_fp0), 12), (SELECT data FROM k776_fp0);
  RAISE NOTICE 'KAN-776 PROBE PASS: sync disable/resync, phase 4 under the write-loss guard, rollback from events + subtype rows keeps every post-cutover write; backup restore and both guard negatives behave as specified';
END $p12$;
