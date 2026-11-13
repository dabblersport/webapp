-- KAN-780 (KAN-719 Z03, Epic KAN-708): the pre-application dependency re-scan gate, proven on a local DB.
-- KAN-862: probes re-pointed at the regenerated Z01 slate (manifest 254f6202893607899592380ee724a79b: games.search_tsv
-- and 21 meetups columns; no other games column is slated, so the probes read meetups).
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- The gate itself (kan719_z03_prestop_gate.sql) is read-only and production-safe; this TEST creates probe objects,
-- always inside a transaction that rolls back. R1 proves nothing persisted.
--
--   G1  baseline: the gate passes inside BEGIN READ ONLY (it writes nothing), 0 NEW; also passes with the D05
--       compatibility views applied (kan718_meetups_compat is KNOWN, not new)
--   G2  one NEW dependency of each kind makes it STOP and name exactly that object: a view, a SQL function, a
--       plpgsql trigger on meetups, a policy on another table, an index, a check constraint, extended statistics
--   G3  a new object that reads only RETAINED columns (id, event_id, vibe_key) does not stop it (no false stop)
--   G4  composition: gate then a destructive statement in one block; on STOP the DROP never runs and the column
--       is still there
--   S1  seeded with one game + one meetup through the legacy path: the gate passes, rows not doubled, counts equal
--       legacy, owner/stranger/blocked/anon see the same before and after the gate; ROLLBACK
--   R1  after everything: games/meetups/events data, column shape and dependent-object census byte-identical
--
-- Run (repository root) on the cluster built by supabase/tests/events_p2/build_kan788.sh plus KAN-716/D07/KAN-785:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan719_z03_prestop_gate_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-780: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k780|kan780)' THEN
    RAISE EXCEPTION 'KAN-780: database % is not a KAN-780/788 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-780: run as a superuser'; END IF;
  IF to_regclass('public.kan718_games_compat') IS NOT NULL THEN RAISE EXCEPTION 'KAN-780: D05 views already applied; use a fresh DB'; END IF;
END $g$;

CREATE TEMP TABLE k780_fp AS SELECT
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e,
  (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
     FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped) shape,
  (SELECT md5(string_agg(classid::regclass || ':' || objid || ':' || refobjid || ':' || refobjsubid, ',' ORDER BY classid::regclass::text, objid, refobjid, refobjsubid))
     FROM pg_depend WHERE refobjid IN ('public.games'::regclass, 'public.meetups'::regclass)) deps,
  (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace) nproc;

\set gtext `cat supabase/tests/events_p4/kan719_z03_prestop_gate.sql`
CREATE TEMP TABLE k780_gate AS SELECT substring(:'gtext'::text FROM '(DO \$z03\$.*?END \$z03\$)') AS sql;
-- NULL = the gate passed; otherwise its STOP message
CREATE FUNCTION pg_temp.k780_gate() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE err text; BEGIN
  EXECUTE (SELECT sql FROM k780_gate);
  RETURN NULL;
EXCEPTION WHEN raise_exception THEN GET STACKED DIAGNOSTICS err = MESSAGE_TEXT; RETURN err; END $f$;

-- G1 baseline, read-only (the shipped file itself, via \i)
BEGIN READ ONLY;
\i supabase/tests/events_p4/kan719_z03_prestop_gate.sql
ROLLBACK;

BEGIN;
\i supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql
DO $g1$ DECLARE e text; BEGIN
  IF (SELECT sql FROM k780_gate) IS NULL THEN RAISE EXCEPTION 'KAN-780 G1 FAIL: gate block not found'; END IF;
  e := pg_temp.k780_gate();
  IF e IS NOT NULL THEN RAISE EXCEPTION 'KAN-780 G1 FAIL: gate stopped with D05 applied: %', e; END IF;
  RAISE NOTICE 'KAN-780 G1 PASS: baseline passes read-only (above) and with the D05 compat views applied (kan718_meetups_compat is KNOWN)';
END $g1$;
ROLLBACK;

-- G2 / G3 / G4
BEGIN;
DO $g2$
DECLARE r record; e text; n int := 0;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('view:k780_probe_view',          $s$CREATE VIEW public.k780_probe_view AS SELECT id, title FROM public.meetups$s$),
      ('function:k780_probe_fn',        $s$CREATE FUNCTION public.k780_probe_fn() RETURNS timestamptz LANGUAGE sql AS 'SELECT max(m.start_at) FROM public.meetups m'$s$),
      ('trigger:k780_probe_trg',        $s$CREATE FUNCTION public.k780_probe_trgfn() RETURNS trigger LANGUAGE plpgsql AS 'BEGIN IF NEW.capacity < 0 THEN RAISE EXCEPTION ''x''; END IF; RETURN NEW; END';
                                           CREATE TRIGGER k780_probe_trg BEFORE UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.k780_probe_trgfn()$s$),
      ('policy:k780_probe_pol',         $s$CREATE POLICY k780_probe_pol ON public.meetup_attendees FOR SELECT USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND m.start_at > now()))$s$),
      ('index:k780_probe_idx',          $s$CREATE INDEX k780_probe_idx ON public.meetups (start_at)$s$),
      ('constraint:k780_probe_chk',     $s$ALTER TABLE public.meetups ADD CONSTRAINT k780_probe_chk CHECK (title IS NOT NULL OR title IS NULL) NOT VALID$s$),
      ('statistics:k780_probe_stx',     $s$CREATE STATISTICS k780_probe_stx ON sport_id, area_id FROM public.meetups$s$)
    ) v(want, ddl) LOOP
    BEGIN
      EXECUTE r.ddl;
      e := pg_temp.k780_gate();
      IF e IS NULL OR e NOT LIKE 'KAN-780 STOP: % NEW %' OR position(r.want IN e) = 0 THEN
        RAISE EXCEPTION 'KAN-780 G2 FAIL: % did not stop the gate by name: %', r.want, coalesce(e, '<passed>');
      END IF;
      RAISE NOTICE 'KAN-780 G2 % -> %', r.want, e;
      n := n + 1;
      RAISE EXCEPTION 'k780_undo';
    EXCEPTION WHEN raise_exception THEN
      GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
      IF e <> 'k780_undo' THEN RAISE; END IF;
    END;
  END LOOP;
  IF pg_temp.k780_gate() IS NOT NULL THEN RAISE EXCEPTION 'KAN-780 G2 FAIL: probes leaked out of their savepoints'; END IF;
  RAISE NOTICE 'KAN-780 G2 PASS: % of 7 new-dependency kinds each STOP the gate and are named (view, function, trigger, policy, index, constraint, statistics)', n;

  -- G3 retained-only dependents are not a stop
  CREATE VIEW public.k780_probe_retained AS SELECT g.id, g.event_id FROM public.games g UNION ALL SELECT m.id, m.event_id FROM public.meetups m;
  CREATE INDEX k780_probe_retained_idx ON public.meetups (vibe_key);
  e := pg_temp.k780_gate();
  IF e IS NOT NULL THEN RAISE EXCEPTION 'KAN-780 G3 FAIL: a retained-column dependent stopped the gate: %', e; END IF;
  RAISE NOTICE 'KAN-780 G3 PASS: a view on games/meetups (id, event_id) and an index on meetups (vibe_key) do not stop the gate';

  -- G4 composition: the gate is the first statement of the destructive transaction
  CREATE VIEW public.k780_probe_late AS SELECT id, end_at FROM public.meetups;
  BEGIN
    EXECUTE (SELECT sql FROM k780_gate);
    ALTER TABLE public.meetups DROP COLUMN end_at CASCADE;   -- would silently take the view with it
    RAISE EXCEPTION 'KAN-780 G4 FAIL: the destructive statement ran after a STOP-worthy dependency';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'KAN-780 STOP:%view:k780_probe_late%' THEN RAISE; END IF;
  END;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attname = 'end_at' AND NOT attisdropped)
     OR to_regclass('public.k780_probe_late') IS NULL THEN
    RAISE EXCEPTION 'KAN-780 G4 FAIL: column or dependent view gone';
  END IF;
  RAISE NOTICE 'KAN-780 G4 PASS: a view created just before application stops the transaction at the gate; even a CASCADE DROP behind it never runs (column and view intact): %', e;
END $g2$;
ROLLBACK;

-- Runs p_sql (returning one text) as an API role. p_uid NULL = no JWT claims.
CREATE FUNCTION pg_temp.k780_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
  EXECUTE p_sql INTO r;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN r; END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.k780_as(text, uuid, text) TO anon, authenticated, service_role;

-- S1 seeded legacy path
BEGIN;
CREATE TEMP TABLE k780_n0 AS SELECT (SELECT count(*) FROM public.games) g, (SELECT count(*) FROM public.meetups) m, (SELECT count(*) FROM public.events) ev;
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id)
VALUES ('78000000-0000-0000-0000-000000000001', 'Z03 game', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2031-06-01 18:00+00', '2031-06-01 20:00+00', 10, 'public', 'open',
        '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
    'id', '78000000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'Z03 meetup',
    'start_at', '2031-06-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public'))).*
  FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
SET CONSTRAINTS ALL IMMEDIATE;

CREATE TEMP TABLE k780_who(label text, role text, uid uuid);
INSERT INTO k780_who VALUES ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'), ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'), ('anon', 'anon', NULL);
GRANT SELECT ON k780_who TO anon, authenticated;
CREATE TEMP TABLE k780_vis(phase text, who text, res text);
DO $s$ DECLARE w record; q text :=
  'SELECT (SELECT count(*) FROM public.games) || ''/'' || (SELECT count(*) FROM public.meetups) || '':'' || coalesce(md5((SELECT string_agg(id::text, '','' ORDER BY id) FROM public.meetups)), ''-'')';
BEGIN
  FOR w IN SELECT * FROM k780_who LOOP INSERT INTO k780_vis VALUES ('before', w.label, pg_temp.k780_as(w.role, w.uid, q)); END LOOP;
END $s$;

DO $s1$
DECLARE e text; w record; x text; q text :=
  'SELECT (SELECT count(*) FROM public.games) || ''/'' || (SELECT count(*) FROM public.meetups) || '':'' || coalesce(md5((SELECT string_agg(id::text, '','' ORDER BY id) FROM public.meetups)), ''-'')';
BEGIN
  e := pg_temp.k780_gate();
  IF e IS NOT NULL THEN RAISE EXCEPTION 'KAN-780 S1 FAIL: gate stopped on seeded data: %', e; END IF;
  FOR w IN SELECT * FROM k780_who LOOP INSERT INTO k780_vis VALUES ('after', w.label, pg_temp.k780_as(w.role, w.uid, q)); END LOOP;
  SELECT string_agg(b.who || ' ' || b.res || ' -> ' || a.res, '; ') INTO x FROM k780_vis b JOIN k780_vis a ON a.who = b.who AND a.phase = 'after'
   WHERE b.phase = 'before' AND a.res IS DISTINCT FROM b.res;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-780 S1 FAIL: visibility changed across the gate: %', x; END IF;
  IF (SELECT row(g + 1, m + 1, ev + 2) FROM k780_n0) IS DISTINCT FROM row((SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events))
     OR (SELECT count(*) FROM public.events WHERE id IN ('78000000-0000-0000-0000-000000000001', '78000000-0000-0000-0000-00000000f001')) <> 2
     OR (SELECT count(*) FROM public.games WHERE id = '78000000-0000-0000-0000-000000000001' AND event_id = id) <> 1 THEN
    RAISE EXCEPTION 'KAN-780 S1 FAIL: rows doubled or counts not equal to legacy';
  END IF;
  IF (SELECT title FROM public.games WHERE id = '78000000-0000-0000-0000-000000000001') <> 'Z03 game'
     OR (SELECT title FROM public.meetups WHERE id = '78000000-0000-0000-0000-00000000f001') <> 'Z03 meetup' THEN
    RAISE EXCEPTION 'KAN-780 S1 FAIL: legacy shape not readable';
  END IF;
  RAISE NOTICE 'KAN-780 S1 PASS: seeded game + meetup; gate passes; games/meetups/events +1/+1/+2 (one events row each, event_id = id); legacy titles read back; per-caller games/meetups visible = %',
    (SELECT string_agg(who || ' ' || split_part(res, ':', 1), ', ' ORDER BY who) FROM k780_vis WHERE phase = 'after');
END $s1$;
ROLLBACK;

-- R1
DO $r$ BEGIN
  IF (SELECT row(g, m, e, shape, deps, nproc) FROM k780_fp) IS DISTINCT FROM (SELECT row(
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
      (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
      (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
         FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped),
      (SELECT md5(string_agg(classid::regclass || ':' || objid || ':' || refobjid || ':' || refobjsubid, ',' ORDER BY classid::regclass::text, objid, refobjid, refobjsubid))
         FROM pg_depend WHERE refobjid IN ('public.games'::regclass, 'public.meetups'::regclass)),
      (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace))) THEN
    RAISE EXCEPTION 'KAN-780 R1 FAIL: data, shape, dependencies or functions differ after ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-780 R1 PASS: games %, meetups %, events %, column shape, games/meetups dependency census and function count identical after ROLLBACK',
    left((SELECT g FROM k780_fp), 8), left((SELECT m FROM k780_fp), 8), left((SELECT e FROM k780_fp), 8);
  RAISE NOTICE 'KAN-780 PASS';
END $r$;
