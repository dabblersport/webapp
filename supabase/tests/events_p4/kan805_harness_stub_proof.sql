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
-- (stub = coalesce(NEW.host_actor_id, NEW.creator_profile_id)) H1, H2, H5 and H7 FAIL; on 2d1468ff (creator read
-- inline in the stub as e.creator_profile_id) H1 FAILs; H3, H4, H6 PASS on both
-- (on the guard path the old stub's legacy creator equals the parent's creator, so H3 does not discriminate).
--
-- Probes:
--   H1 [b] the body (pg_proc.prosrc) of harness_host_actor_stub contains neither the token creator_profile_id nor
--          owner_user_id anywhere (code, comments, literals; case-insensitive), and reads no NEW./OLD.<column
--          KAN-719 Z01 removes from meetups> (same pattern as kan719_z04_postcheck.sql S4).
--   H2 [b] it reads the creator from public.events -- in its own body or in a public function it calls as
--          public.<name>( (KAN-818 fix 1: harness_meetup_creator(public.meetups)), is attached exactly once (BEFORE INSERT ROW, trg_meetups_aaa_host_actor_stub),
--          and trg_zz_kan712_meetups_guard is still the LAST BEFORE ROW trigger on meetups (the KAN-712 cutover
--          asserts that; a late stub trigger after the guard fails the cutover build).
--   H3 [a] guard path: a meetup inserted with NULL host_actor_id gets host = the creator of its events parent.
--   H4 [a] guard path: an explicit host_actor_id is kept.
--   H5 [a] event-first (the post-Z01 create shape; the guard disabled in a savepoint): the events row is written
--          first with creator b3, the meetup row then carries a DIFFERENT legacy creator b4 and NULL host.
--          host must be b3 (events), not b4 (meetups.creator_profile_id). This is the discriminating probe.
--   H6 [a] event-first with an explicit host: kept.
--   H7 [a] Z01 columns absent (simulated in a savepoint: the 24 Z01 meetups columns are RENAMED, because a real
--          DROP needs the Z01 dependants dropped first; every user trigger on meetups except the stub trigger
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
        hits text; called text; ev_readers text;
BEGIN
  SELECT string_agg(col, ',' ORDER BY col) INTO hits FROM k818_z01 WHERE src ~* ('\m(new|old)\.' || col || '\M');
  -- literal: the tokens may not appear anywhere in the stub body (code, comments, string literals), in any case
  PERFORM pg_temp.chk('H1', hits IS NULL
      AND position('creator_profile_id' IN lower(src)) = 0 AND position('owner_user_id' IN lower(src)) = 0,
    format('stub body names none of creator_profile_id, owner_user_id (creator_profile_id=%s owner_user_id=%s); NEW/OLD.<Z01 col> hits=%s',
           position('creator_profile_id' IN lower(src)) > 0, position('owner_user_id' IN lower(src)) > 0, coalesce(hits, 'none')));
  -- stub -> helper: every public function the stub body calls as public.<name>( ; the read of public.events is
  -- accepted in the stub itself or in one of those callees (plpgsql records no pg_depend for a call). A read is
  -- FROM/JOIN public.events: a to_regclass('public.events') existence test is not a read.
  SELECT string_agg(DISTINCT p.oid::regprocedure::text, ',') INTO called
    FROM regexp_matches(src, '\mpublic\.([a-z_][a-z0-9_]*)\s*\(', 'gi') AS m(g)
    JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname = lower(m.g[1]);
  SELECT string_agg(DISTINCT x.who, ',') INTO ev_readers FROM (
    SELECT 'harness_host_actor_stub()' AS who WHERE src ~* '\m(from|join)\s+public\.events\M'
    UNION ALL
    SELECT p.oid::regprocedure::text FROM regexp_matches(src, '\mpublic\.([a-z_][a-z0-9_]*)\s*\(', 'gi') AS m(g)
      JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname = lower(m.g[1])
     WHERE p.prosrc ~* '\m(from|join)\s+public\.events\M') x;
  PERFORM pg_temp.chk('H2',
    ev_readers IS NOT NULL
    AND (SELECT count(*) FROM pg_trigger t WHERE t.tgrelid = 'public.meetups'::regclass AND NOT t.tgisinternal
           AND t.tgfoid = 'public.harness_host_actor_stub()'::regprocedure AND t.tgenabled = 'O'
           AND t.tgtype::int & 2 = 2 AND t.tgtype::int & 4 = 4 AND t.tgtype::int & 1 = 1
           AND t.tgname = 'trg_meetups_aaa_host_actor_stub') = 1
    AND (SELECT count(*) FROM pg_trigger t WHERE t.tgrelid = 'public.meetups'::regclass
           AND t.tgfoid = 'public.harness_host_actor_stub()'::regprocedure) = 1
    AND (SELECT max(t.tgname::text COLLATE "C") FROM pg_trigger t WHERE t.tgrelid = 'public.meetups'::regclass
           AND NOT t.tgisinternal AND t.tgtype::int & 3 = 3) = 'trg_zz_kan712_meetups_guard',
    format('stub reads creator from events: FROM public.events in %s (stub calls %s); triggers on meetups using it: %s; last BEFORE ROW trigger: %s',
      coalesce(ev_readers, 'NOWHERE'), coalesce(called, 'nothing'),
      (SELECT string_agg(tgname, ',' ORDER BY tgname COLLATE "C") FROM pg_trigger
        WHERE tgrelid = 'public.meetups'::regclass AND tgfoid = 'public.harness_host_actor_stub()'::regprocedure),
      (SELECT max(t.tgname::text COLLATE "C") FROM pg_trigger t WHERE t.tgrelid = 'public.meetups'::regclass
           AND NOT t.tgisinternal AND t.tgtype::int & 3 = 3)));
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
    INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at)
               VALUES ('81800000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b4',
                       '00000000-0000-0000-0000-0000000000a4', 'k818 h3', '2030-06-01 10:00+00')
    RETURNING host_actor_id::text $q$) AS h \gset h3_
SELECT coalesce((SELECT e.creator_profile_id::text FROM public.events e
       WHERE e.id = '81800000-0000-0000-0000-000000000003'), '<no parent>') AS c \gset h3_
\set h3_r :h3_h '|' :h3_c
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
DO $e$ DECLARE r record; BEGIN   -- re-enable only the stub trigger
  FOR r IN SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass
            AND tgname = 'trg_meetups_aaa_host_actor_stub' LOOP
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
