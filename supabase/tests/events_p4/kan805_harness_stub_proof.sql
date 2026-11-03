-- KAN-818 (KAN-805 follow-up) PROOF: the harness host_actor_id stub reads the creator from public.events.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE (the guard below refuses a Supabase-shaped database).
-- One transaction, ROLLBACK at the end; nothing is committed.
--
-- WHAT IT RUNS AGAINST: any throwaway PG16 database loaded with the KAN-712 harness and cut over by KAN-712
-- stage B, i.e. the chain in supabase/tests/events_p2_kan713/local_harness_kan713.sql "Load order":
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, KAN-710, KAN-711 (+ CALL kan711_events_backfill_run(200) +
--   SELECT kan711_events_validate_links()), KAN-712 stage A + B, the two KAN-713 migrations.
-- The database built by supabase/tests/events_p2/build_kan728.sh (same chain + kan714 harness + D07) also works:
--   bash supabase/tests/events_p2/build_kan728.sh /tmp/k818_pg 55818
--   psql -X -h /tmp -p 55818 -U postgres -d k728 -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan805_harness_stub_proof.sql
-- Exit 0 and every line PASS = GREEN. Any FAIL raises at the end (exit 3) = RED. On the pre-KAN-818 harness
-- (stub = coalesce(NEW.host_actor_id, NEW.creator_profile_id)) H1, H2, H5, H6 and H7 FAIL; H3, H4 PASS on both.
--
-- Probes:
--   H1 [b] the body of harness_host_actor_stub reads no NEW./OLD.<column KAN-719 Z01 removes from meetups>
--          (same pattern as kan719_z04_postcheck.sql S4), names no owner_user_id, and names creator_profile_id
--          only as a column of the events parent (e.creator_profile_id / the KAN-711 map result).
--   H2 [b] it reads public.events, and is attached BEFORE INSERT twice: trg_meetups_aaa_host_actor_stub and
--          trg_zzz_harness_host_actor_stub_late, the latter sorting after trg_zz_kan712_meetups_guard.
--   H3 [a] guard path: a meetup inserted with NULL host_actor_id gets host = the creator of its events parent.
--   H4 [a] guard path: an explicit host_actor_id is kept.
--   H5 [a] event-first (the post-Z01 create shape; the guard disabled in a savepoint): the events row is written
--          first with creator b3, the meetup row then carries a DIFFERENT legacy creator b4 and NULL host.
--          host must be b3 (events), not b4 (meetups.creator_profile_id). This is the discriminating probe.
--   H6 [a] event-first with an explicit host: kept.
--   H7 [a] Z01 columns absent (simulated in a savepoint: the 24 Z01 meetups columns are RENAMED, because a real
--          DROP needs the Z01 dependants dropped first; every user trigger on meetups except the two stub triggers
--          is disabled, as Z01 drops them): event-first insert, NULL host -> events creator; no 42703.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-818: this looks like a Supabase database; local throwaway database only';
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-818: run as a superuser'; END IF;
  IF to_regprocedure('public.harness_host_actor_stub()') IS NULL OR to_regclass('public.events') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgname = 'trg_zz_kan712_meetups_guard') THEN
    RAISE EXCEPTION 'KAN-818: needs the KAN-712 harness cut over by KAN-712 stage B (see header)';
  END IF;
END $g$;

BEGIN;
CREATE TEMP TABLE k818_res (n serial, id text, ok boolean, detail text);
CREATE TEMP TABLE k818_z01 (col text PRIMARY KEY);   -- KAN-719 Z01 meetups DROP COLUMN 701-724
INSERT INTO k818_z01 VALUES ('creator_profile_id'), ('creator_user_id'), ('title'), ('description'), ('listing_visibility'),
  ('rsvp_policy'), ('capacity'), ('start_at'), ('end_at'), ('is_cancelled'), ('created_at'), ('updated_at'), ('search_tsv'),
  ('geo_location_id'), ('sport_id'), ('area_id'), ('venue_id'), ('min_skill'), ('max_skill'), ('joining_rule'), ('cost_cover'),
  ('location_name'), ('is_indoor'), ('request_id');

-- results are written only OUTSIDE the savepoints (a ROLLBACK TO SAVEPOINT would erase them): each probe's observed
-- value is taken into a psql variable with \gset inside its savepoint and checked after the rollback.
CREATE FUNCTION pg_temp.chk(p_id text, p_ok boolean, p_detail text) RETURNS void LANGUAGE sql AS
$$ INSERT INTO k818_res(id, ok, detail) VALUES (p_id, coalesce(p_ok, false), p_detail) $$;

-- H1 / H2: the body --------------------------------------------------------------------------------------------
DO $h1$
DECLARE src text := (SELECT prosrc FROM pg_proc WHERE oid = 'public.harness_host_actor_stub()'::regprocedure);
        hits text; rest text;
BEGIN
  SELECT string_agg(col, ',' ORDER BY col) INTO hits FROM k818_z01 WHERE src ~* ('\m(new|old)\.' || col || '\M');
  rest := regexp_replace(regexp_replace(src, '\me\.creator_profile_id\M', '', 'gi'), '\)\.creator_profile_id\M', '', 'gi');
  PERFORM pg_temp.chk('H1', hits IS NULL AND src !~* '\mowner_user_id\M' AND rest !~* '\mcreator_profile_id\M',
    format('NEW/OLD.<Z01 col> hits=%s owner_user_id=%s creator_profile_id outside events=%s',
           coalesce(hits, 'none'), src ~* '\mowner_user_id\M', rest ~* '\mcreator_profile_id\M'));
  PERFORM pg_temp.chk('H2',
    src ~* '\mpublic\.events\M'
    AND (SELECT count(*) FROM pg_trigger t WHERE t.tgrelid = 'public.meetups'::regclass AND NOT t.tgisinternal
           AND t.tgfoid = 'public.harness_host_actor_stub()'::regprocedure AND t.tgenabled = 'O'
           AND t.tgtype::int & 2 = 2 AND t.tgtype::int & 4 = 4 AND t.tgtype::int & 1 = 1
           AND t.tgname IN ('trg_meetups_aaa_host_actor_stub', 'trg_zzz_harness_host_actor_stub_late')) = 2
    AND 'trg_zzz_harness_host_actor_stub_late' COLLATE "C" > 'trg_zz_kan712_meetups_guard' COLLATE "C",
    format('reads public.events=%s; BEFORE INSERT ROW triggers on meetups using it: %s', src ~* '\mpublic\.events\M',
      (SELECT string_agg(tgname, ',' ORDER BY tgname COLLATE "C") FROM pg_trigger
        WHERE tgrelid = 'public.meetups'::regclass AND tgfoid = 'public.harness_host_actor_stub()'::regprocedure)));
END $h1$;

-- behavioural probes: each in its own subtransaction, the error (if any) is the observed value ------------------
CREATE FUNCTION pg_temp.run(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text; m text;
BEGIN
  EXECUTE p_sql INTO v; RETURN coalesce(v, '<null>');
EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT; RETURN 'ERR ' || s || ' ' || m;
END $$;

-- H3 guard path, NULL host
SAVEPOINT h3;
SELECT pg_temp.run($q$
    WITH m AS (INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at)
               VALUES ('81800000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b4',
                       '00000000-0000-0000-0000-0000000000a4', 'k818 h3', '2030-06-01 10:00+00') RETURNING id, host_actor_id)
    SELECT m.host_actor_id || '|' || (SELECT e.creator_profile_id FROM public.events e WHERE e.id = m.id) FROM m $q$) AS r \gset h3_
ROLLBACK TO SAVEPOINT h3;
SELECT pg_temp.chk('H3', :'h3_r' = '00000000-0000-0000-0000-0000000000b4|00000000-0000-0000-0000-0000000000b4', 'host|events.creator = ' || :'h3_r');

-- H4 guard path, explicit host
SAVEPOINT h4;
SELECT pg_temp.run($q$
    INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at, host_actor_id)
    VALUES ('81800000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000b4',
            '00000000-0000-0000-0000-0000000000a4', 'k818 h4', '2030-06-01 10:00+00', '00000000-0000-0000-0000-0000000000b1')
    RETURNING host_actor_id::text $q$) AS r \gset h4_
ROLLBACK TO SAVEPOINT h4;
SELECT pg_temp.chk('H4', :'h4_r' = '00000000-0000-0000-0000-0000000000b1', 'host = ' || :'h4_r');

-- H5 / H6 event-first: parent written first (creator b3), guard disabled (the post-Z01 shape has no guard)
SAVEPOINT h5;
ALTER TABLE public.meetups DISABLE TRIGGER trg_zz_kan712_meetups_guard;
INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at)
VALUES ('81800000-0000-0000-0000-000000000005', 'meetup', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a3', 'k818 h5', '2030-06-02 10:00+00'),
       ('81800000-0000-0000-0000-000000000006', 'meetup', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a3', 'k818 h6', '2030-06-02 10:00+00');
SELECT pg_temp.run($q$
    INSERT INTO public.meetups (id, event_id, creator_profile_id, creator_user_id, title, start_at)
    VALUES ('81800000-0000-0000-0000-000000000005', '81800000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000b4',
            '00000000-0000-0000-0000-0000000000a4', 'k818 h5', '2030-06-02 10:00+00')
    RETURNING host_actor_id::text $q$) AS r \gset h5_
SELECT pg_temp.run($q$
    INSERT INTO public.meetups (id, event_id, creator_profile_id, creator_user_id, title, start_at, host_actor_id)
    VALUES ('81800000-0000-0000-0000-000000000006', '81800000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000b4',
            '00000000-0000-0000-0000-0000000000a4', 'k818 h6', '2030-06-02 10:00+00', '00000000-0000-0000-0000-0000000000b1')
    RETURNING host_actor_id::text $q$) AS r \gset h6_
ROLLBACK TO SAVEPOINT h5;
SELECT pg_temp.chk('H5', :'h5_r' = '00000000-0000-0000-0000-0000000000b3', 'host = ' || :'h5_r' || ' (events creator b3; legacy row creator b4)');
SELECT pg_temp.chk('H6', :'h6_r' = '00000000-0000-0000-0000-0000000000b1', 'host = ' || :'h6_r');

-- H7 Z01 columns absent (renamed), Z01-dropped triggers off, event-first insert
SAVEPOINT h7;
DO $z$ DECLARE c text; BEGIN
  FOR c IN SELECT col FROM k818_z01 JOIN pg_attribute a ON a.attrelid = 'public.meetups'::regclass AND a.attname = col AND NOT a.attisdropped LOOP
    EXECUTE format('ALTER TABLE public.meetups RENAME COLUMN %I TO %I', c, 'k818_gone_' || c);
  END LOOP;
END $z$;
ALTER TABLE public.meetups DISABLE TRIGGER USER;
DO $e$ DECLARE r record; BEGIN   -- re-enable only the stub triggers that exist (the old harness has only "aaa")
  FOR r IN SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass
            AND tgname IN ('trg_meetups_aaa_host_actor_stub', 'trg_zzz_harness_host_actor_stub_late') LOOP
    EXECUTE format('ALTER TABLE public.meetups ENABLE TRIGGER %I', r.tgname);
  END LOOP;
END $e$;
INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at)
VALUES ('81800000-0000-0000-0000-000000000007', 'meetup', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a3', 'k818 h7', '2030-06-03 10:00+00');
SELECT (SELECT count(*) FROM k818_z01 JOIN pg_attribute a ON a.attrelid = 'public.meetups'::regclass AND a.attname = col AND NOT a.attisdropped) AS left_cols,
       pg_temp.run($q$
    INSERT INTO public.meetups (id, event_id, k818_gone_creator_profile_id, k818_gone_creator_user_id, k818_gone_title, k818_gone_start_at)
    VALUES ('81800000-0000-0000-0000-000000000007', '81800000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-0000000000b4',
            '00000000-0000-0000-0000-0000000000a4', 'k818 h7', '2030-06-03 10:00+00')
    RETURNING host_actor_id::text $q$) AS r \gset h7_
ROLLBACK TO SAVEPOINT h7;
SELECT pg_temp.chk('H7', :'h7_r' = '00000000-0000-0000-0000-0000000000b3',
       format('host = %s; meetups columns named by Z01 still present during the insert = %s', :'h7_r', :'h7_left_cols'));

SELECT id || '|' || CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || detail FROM k818_res ORDER BY n;
SELECT '#SUMMARY|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM k818_res;
DO $f$ BEGIN
  IF EXISTS (SELECT 1 FROM k818_res WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-818: % probe(s) FAIL', (SELECT count(*) FROM k818_res WHERE NOT ok); END IF;
END $f$;
ROLLBACK;
