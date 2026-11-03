-- KAN-770 (KAN-718 D02, Epic KAN-708): catalogue re-scan for SQL consumers of the slated games/meetups columns.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- Companion: supabase/tests/events_p4/KAN718_D02_NON_SQL_CONSUMERS.md (Edge Functions, scripts, the
-- messaging Worker, admin tooling, and the repo-wide dynamic-SQL scan that covers what the local
-- catalogue does not hold).
--
-- Session-local TEMP helpers are created first (nothing persistent). Then Part A runs in one
-- READ ONLY transaction (a write to a real table fails with 25006) and derives from the catalogue:
--   A1  every object with a COLUMN-LEVEL pg_depend on a slated column (views, policies, indexes,
--       constraints, defaults, publications, statistics): exact, no text heuristics
--   A2  every function whose body names games/meetups and a slated column token (textual, conservative),
--       classified infra / converted (B15 list) / trigger / open. A legacy-looking NAME is reported, but
--       the class comes from the body only: no RPC is called retired because of its name
--   A3  every function with dynamic SQL (EXECUTE of a string), and whether that SQL can reach games/meetups
--   A4  triggers on games/meetups and the slated NEW./OLD. columns their functions read
--   A5  policies on OTHER tables whose expression names games/meetups
--   A6  pg_cron jobs naming games/meetups (when the cron schema exists)
--   A7  the B15 (KAN-734) converted objects present here, and whether each still names a legacy table
--   A8  verdict: DELETION BLOCKED while any non-infra consumer remains
-- Part B seeds one game and one meetup through the legacy INSERT path inside BEGIN ... ROLLBACK and checks
-- legacy shapes, no doubling, counts equal legacy, a stranger/blocked user sees nothing extra, and that
-- ROLLBACK leaves games/meetups/events byte-identical (md5).
--
-- Run (repository root; the chain builder is supabase/tests/events_p2/build_kan731.sh):
--   psql -X -h /tmp -p <port> -U postgres -d <db> -v ON_ERROR_STOP=1 -P pager=off \
--        -f supabase/tests/events_p4/kan718_d02_dynamic_and_functions_scan.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-770: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF NOT (SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-770: run as a superuser or BYPASSRLS role (meetups is RLS-protected; counts would undercount)';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------
-- TEMP helpers (session-local)
-- ---------------------------------------------------------------------------------------------
-- Slated columns: the legacy columns kan711_events_map_game / _meetup copy into events, minus id
-- (20261102110000_kan711_events_mirror_triggers.sql; the same list KAN-771 parses from that file).
CREATE TEMP TABLE k770_slated(tbl text, col text);
INSERT INTO k770_slated
SELECT 'games', unnest(ARRAY['creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
  'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id','venue_id','min_skill',
  'max_skill','joining_rule','cost_cover','request_id','created_at','updated_at'])
UNION ALL
SELECT 'meetups', unnest(ARRAY['creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
  'rsvp_policy','is_cancelled','sport_id','area_id','geo_location_id','venue_id','min_skill','max_skill','joining_rule',
  'cost_cover','request_id','created_at','updated_at']);

-- KAN-734 (B15) converted objects, verbatim from kan714_b15_coverage_probe.sql k734_conv_names.
CREATE TEMP TABLE k770_b15(kind text, name text);
INSERT INTO k770_b15 VALUES
 ('function','_can_view_game'),('function','_can_view_game_for_join'),('function','_is_game_host'),('function','_slot_conflicts_game'),
 ('function','active_stream'),('function','admin_cleanup_user_data'),('function','admin_overview_row'),
 ('function','can_current_user_join_game'),('function','can_current_user_rsvp_meetup'),('function','game_slots_left'),
 ('function','meetup_slots_left'),('function','msg_authorize'),('function','msg_evaluate'),('function','msg_my_conversations'),
 ('function','rpc_booking_hold_for_meetup'),('function','rpc_cancel_game_series'),('function','rpc_edit_game_series_future'),
 ('function','rpc_edit_game_series_occurrence'),('function','rpc_games_following_joined'),('function','rpc_get_activity_feed'),
 ('function','rpc_get_nearby_games'),('function','rpc_meetup_attendees'),('function','rpc_meetup_card'),('function','rpc_rate_game'),
 ('function','rpc_rate_user'),('function','rpc_rate_venue'),('function','rpc_sport_overview'),('function','rpc_unified_search_sectioned'),
 ('function','settle_game'),('function','trg_meetup_rsvps_notify'),('function','trg_meetups_cancel_notify'),
 ('view','v_game_card'),('view','v_host_weekly_metrics'),('view','v_meetup_counts'),('view','v_meetup_list'),('view','v_my_games'),
 ('view','v_rateable_after_game');
-- KAN-772 (KAN-718 D04 return-for-fix 1): the D01 "B15 open" functions converted by
-- 20261104110100_kan718_d04_last_shared_field_reads.sql. Same rule as B15: 'converted' only when the body reads events,
-- else 'converted-without-events' (blocking). Disposition of all 34: KAN718_D04_DISPOSITION.md.
INSERT INTO k770_b15 VALUES
 ('function','_recent_activity_score'),('function','_user_hosted_game'),('function','game_is_joinable'),
 ('function','get_games_needing_players'),('function','get_open_games_for_seeding'),('function','meetup_counts'),
 ('function','rpc_create_game'),('function','rpc_create_meetup');

-- Function bodies, comments stripped, extension members and test-harness reference functions excluded.
CREATE TEMP TABLE k770_fn AS
SELECT p.oid, p.oid::regprocedure::text AS ident, p.proname AS name, p.prorettype = 'trigger'::regtype AS is_trigger,
       regexp_replace(regexp_replace(coalesce(p.prosrc, ''), '/\*([^*]|\*+[^*/])*\*+/', '', 'g'), '--[^\n]*', '', 'g') AS src
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f', 'p')
  AND p.prolang IN (SELECT oid FROM pg_language WHERE lanname IN ('sql', 'plpgsql'))
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
  AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_)';

-- Infra: the migration's own machinery (KAN-710..718 mirror, contract, guards). It is retired WITH the
-- columns by the deletion step, so it is listed but does not block on its own.
CREATE TEMP TABLE k770_class AS
SELECT f.ident, f.name, f.is_trigger,
  (SELECT string_agg(DISTINCT s.col, ',' ORDER BY s.col) FROM k770_slated s WHERE f.src ~* ('\m' || s.col || '\M')) AS slated_tokens,
  f.src ~* '\mexecute\M\s+(?!function\M|procedure\M)' AS dynamic,
  f.name ~ '(_legacy_v\d+|_v\d+|^getnearby|^get_nearby|^nearby_)' AS legacy_name,
  CASE WHEN f.name ~ '^(kan71\d_|kan718_|events_check_)' THEN 'infra'
       WHEN f.name IN (SELECT name FROM k770_b15 WHERE kind = 'function') AND f.src ~ '\m(public\.)?events\M' THEN 'converted'
       WHEN f.name IN (SELECT name FROM k770_b15 WHERE kind = 'function') THEN 'converted-without-events'
       WHEN f.is_trigger THEN 'trigger'
       ELSE 'open' END AS class
FROM k770_fn f
WHERE f.src ~* '\m(public\.)?(games|meetups)\M'
  AND EXISTS (SELECT 1 FROM k770_slated s WHERE f.src ~* ('\m' || s.col || '\M'));

CREATE TEMP TABLE k770_fp AS
SELECT (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e,
       (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
          FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass)
           AND attnum > 0 AND NOT attisdropped) shape;
GRANT SELECT ON k770_fp TO PUBLIC;

-- ---------------------------------------------------------------------------------------------
BEGIN TRANSACTION READ ONLY;
-- ---------------------------------------------------------------------------------------------

\echo '== A0 slated columns present in this catalogue (missing ones are reported, not assumed)'
SELECT s.tbl, count(*) FILTER (WHERE a.attname IS NOT NULL) AS present,
       string_agg(s.col, ',' ORDER BY s.col) FILTER (WHERE a.attname IS NULL) AS missing
FROM k770_slated s
LEFT JOIN pg_attribute a ON a.attrelid = ('public.' || s.tbl)::regclass AND a.attname = s.col AND NOT a.attisdropped
GROUP BY s.tbl ORDER BY s.tbl;

\echo '== A1 column-level dependencies on slated columns (pg_depend; owning table indexes/constraints included)'
SELECT pg_describe_object(d.classid, d.objid, d.objsubid) AS dependent,
       d.refobjid::regclass AS legacy_table,
       string_agg(a.attname, ',' ORDER BY a.attname) AS slated_columns,
       d.deptype
FROM pg_depend d
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
JOIN k770_slated s ON ('public.' || s.tbl)::regclass = d.refobjid AND s.col = a.attname
WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND d.refobjsubid > 0
GROUP BY 1, 2, 4 ORDER BY 2, 1;

\echo '== A1b views reading slated columns (the subset of A1 that is a read consumer)'
SELECT DISTINCT r.ev_class::regclass AS view, d.refobjid::regclass AS legacy_table,
       (SELECT name FROM k770_b15 b WHERE b.kind = 'view' AND b.name = r.ev_class::regclass::text) IS NOT NULL AS b15_converted
FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid AND d.classid = 'pg_rewrite'::regclass
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
JOIN k770_slated s ON ('public.' || s.tbl)::regclass = d.refobjid AND s.col = a.attname
WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND r.ev_class <> d.refobjid
ORDER BY 1, 2;

\echo '== A2 functions naming games/meetups and a slated column (textual; class from body, never from name)'
SELECT class, ident, dynamic, legacy_name, slated_tokens FROM k770_class ORDER BY class, ident;
SELECT class, count(*) FROM k770_class GROUP BY class ORDER BY class;

\echo '== A3 dynamic SQL: every function that EXECUTEs a string, and whether it can reach a legacy table'
SELECT f.ident,
       f.src ~* '\m(public\.)?(games|meetups)\M' AS names_legacy_table,
       f.src ~ '%I' AS builds_identifiers,
       f.src ~* 'information_schema\.columns|pg_attribute' AS table_list_from_catalogue,
       coalesce((SELECT c.class FROM k770_class c WHERE c.ident = f.ident), 'no-slated-token') AS class
FROM k770_fn f WHERE f.src ~* '\mexecute\M\s+(?!function\M|procedure\M)' ORDER BY 1;

\echo '== A4 triggers on games/meetups: function and the slated NEW./OLD. columns it reads'
SELECT t.tgrelid::regclass AS legacy_table, t.tgname, t.tgfoid::regprocedure AS fn,
       (SELECT string_agg(DISTINCT lower(m[1]) || '.' || lower(m[2]), ',')
          FROM k770_fn f, regexp_matches(f.src, '\m(new|old)\.([a-z_]+)\M', 'gi') m
         WHERE f.oid = t.tgfoid AND EXISTS (SELECT 1 FROM k770_slated s WHERE s.tbl = t.tgrelid::regclass::text AND s.col = lower(m[2]))) AS slated_row_reads,
       CASE WHEN p.proname ~ '^(kan71\d_|kan718_|events_check_)' THEN 'infra' ELSE 'consumer' END AS class
FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT t.tgisinternal
ORDER BY 1, 2;

\echo '== A5 policies on other tables whose expression names games/meetups'
SELECT pol.polrelid::regclass AS on_table, pol.polname,
       coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~*
         (SELECT '\m(' || string_agg(DISTINCT col, '|') || ')\M' FROM k770_slated) AS names_slated_token
FROM pg_policy pol
WHERE pol.polrelid NOT IN ('public.games'::regclass, 'public.meetups'::regclass)
  AND coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~* '\m(public\.)?(games|meetups)\M'
ORDER BY 1, 2;

\echo '== A6 pg_cron jobs naming games/meetups'
SELECT CASE WHEN to_regclass('cron.job') IS NULL THEN 'cron schema absent: no jobs to scan here' ELSE 'cron.job present: see next query' END AS cron;
SELECT to_regclass('cron.job') IS NOT NULL AS k770_has_cron \gset
\if :k770_has_cron
SELECT jobid, jobname, command FROM cron.job WHERE command ~* '\m(games|meetups)\M' ORDER BY jobid;
\endif

\echo '== A7 B15 converted objects present here: does each still name a legacy table? (needs review, not retired)'
SELECT b.kind, b.name,
       CASE b.kind WHEN 'view' THEN to_regclass('public.' || b.name) IS NOT NULL
                   ELSE EXISTS (SELECT 1 FROM k770_fn f WHERE f.name = b.name) END AS present,
       CASE b.kind WHEN 'view' THEN EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
                                             WHERE r.ev_class = to_regclass('public.' || b.name) AND d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass))
                   ELSE EXISTS (SELECT 1 FROM k770_fn f WHERE f.name = b.name AND f.src ~* '\m(public\.)?(games|meetups)\M') END AS names_legacy_table,
       CASE b.kind WHEN 'view' THEN EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
                                             WHERE r.ev_class = to_regclass('public.' || b.name) AND d.refobjid = 'public.events'::regclass)
                   ELSE EXISTS (SELECT 1 FROM k770_fn f WHERE f.name = b.name AND f.src ~ '\m(public\.)?events\M') END AS reads_events
FROM k770_b15 b ORDER BY 1, 2;

\echo '== A8 verdict'
WITH v AS (
  SELECT
    (SELECT count(DISTINCT r.ev_class) FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid AND d.classid = 'pg_rewrite'::regclass
       JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
       JOIN k770_slated s ON ('public.' || s.tbl)::regclass = d.refobjid AND s.col = a.attname
      WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND r.ev_class <> d.refobjid) AS views_on_slated,
    (SELECT count(*) FROM k770_class WHERE class IN ('open', 'trigger', 'converted-without-events')) AS functions_open,
    (SELECT count(*) FROM k770_class WHERE class = 'converted') AS functions_converted_still_naming_legacy,
    (SELECT count(*) FROM k770_class WHERE dynamic AND class <> 'infra') AS dynamic_non_infra,
    (SELECT count(*) FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid JOIN k770_fn f ON f.oid = t.tgfoid
      WHERE t.tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT t.tgisinternal
        AND p.proname !~ '^(kan71\d_|kan718_|events_check_)'
        AND EXISTS (SELECT 1 FROM regexp_matches(f.src, '\m(new|old)\.([a-z_]+)\M', 'gi') m JOIN k770_slated s
                     ON s.tbl = t.tgrelid::regclass::text AND s.col = lower(m[2]))) AS triggers_reading_slated,
    (SELECT count(*) FROM k770_class WHERE class = 'infra') AS infra_retired_with_columns)
SELECT v.*,
       CASE WHEN views_on_slated + functions_open + functions_converted_still_naming_legacy + dynamic_non_infra + triggers_reading_slated > 0
            THEN 'DELETION BLOCKED' ELSE 'NO CATALOGUE CONSUMER (repo + non-SQL scan still decide)' END AS verdict
FROM v;

ROLLBACK;

-- =============================================================================================
-- Part B: scenario. One game + one meetup through the legacy INSERT path; everything rolls back.
-- =============================================================================================
CREATE FUNCTION pg_temp.k770_as(p_uid uuid, p_sql text) RETURNS bigint LANGUAGE plpgsql AS $f$
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
DO $s$
DECLARE
  owner    uuid := '00000000-0000-0000-0000-0000000000a1';
  stranger uuid := '00000000-0000-0000-0000-00000000dead';
  blocked  uuid := '00000000-0000-0000-0000-0000000000a6';   -- blocked by the owner (KAN-713 harness)
  q_g text := $q$SELECT count(*) FROM public.games WHERE id::text LIKE '77000000%'$q$;
  q_m text := $q$SELECT count(*) FROM public.meetups WHERE id::text LIKE '77000000%'$q$;
  q_e text := $q$SELECT count(*) FROM public.events WHERE id::text LIKE '77000000%'$q$;
  n_g0 bigint; n_m0 bigint; n_e0 bigint; x bigint; leak text := '';
BEGIN
  SELECT count(*) INTO n_g0 FROM public.games;
  SELECT count(*) INTO n_m0 FROM public.meetups;
  SELECT count(*) INTO n_e0 FROM public.events;

  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                            sport_id, geo_location_id, area_id)
  VALUES ('77000000-0000-0000-0000-000000000001', 'D02 game', '00000000-0000-0000-0000-0000000000b1', owner,
          '2031-02-01 18:00+00', '2031-02-01 19:00+00', 10, 'public', 'open',
          '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
      'id', '77000000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'D02 meetup',
      'start_at', '2031-02-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';

  -- B1 rows not doubled: exactly one events parent each, id kept, no duplicate events ids
  SELECT count(*) INTO x FROM public.events WHERE id::text LIKE '77000000%';
  IF x <> 2 OR (SELECT count(*) - count(DISTINCT id) FROM public.events) <> 0
     OR EXISTS (SELECT 1 FROM public.games WHERE id::text LIKE '77000000%' AND event_id IS DISTINCT FROM id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE id::text LIKE '77000000%' AND event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-770 B1 FAIL: expected 2 events parents with event_id = id and no duplicate ids, got %', x;
  END IF;
  RAISE NOTICE 'KAN-770 B1 PASS: 1 game + 1 meetup seeded; one events parent each, id kept, no duplicate events ids';

  -- B2 counts equal legacy: per type and in total, +1/+1/+2
  IF (SELECT count(*) FROM public.games) <> n_g0 + 1 OR (SELECT count(*) FROM public.meetups) <> n_m0 + 1
     OR (SELECT count(*) FROM public.events) <> n_e0 + 2
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM public.events WHERE event_type = 'game')
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM public.events WHERE event_type = 'meetup') THEN
    RAISE EXCEPTION 'KAN-770 B2 FAIL: counts diverge (games %, meetups %, events %)',
      (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);
  END IF;
  RAISE NOTICE 'KAN-770 B2 PASS: games % = game events, meetups % = meetup events, events % = sum',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);

  -- B3 legacy shapes unchanged: the seeded rows read back through the legacy tables with the values written,
  -- and the events parent carries the same slated values (NULL end_at/capacity preserved, not invented)
  IF (SELECT row(title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled)::text FROM public.games WHERE id = '77000000-0000-0000-0000-000000000001')
     IS DISTINCT FROM (SELECT row(title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled)::text FROM public.events WHERE id = '77000000-0000-0000-0000-000000000001')
     OR (SELECT row(title, start_at, end_at, capacity, listing_visibility)::text FROM public.meetups WHERE id = '77000000-0000-0000-0000-00000000f001')
     IS DISTINCT FROM (SELECT row(title, start_at, end_at, capacity, listing_visibility)::text FROM public.events WHERE id = '77000000-0000-0000-0000-00000000f001')
     OR (SELECT end_at IS NOT NULL OR capacity IS NOT NULL FROM public.events WHERE id = '77000000-0000-0000-0000-00000000f001') THEN
    RAISE EXCEPTION 'KAN-770 B3 FAIL: legacy row and events parent disagree, or a NULL was invented';
  END IF;
  RAISE NOTICE 'KAN-770 B3 PASS: legacy reads return what was written; events parent equal; meetup NULL end_at/capacity preserved';

  -- B4 a stranger / blocked user sees nothing extra. games: RLS with no policy (live), so API roles see 0
  -- of the new game; events: closed to API roles. meetups: public meetup is visible to a stranger (legacy
  -- behaviour, +1) and NOT to the user the owner blocked (+0). The helper verdicts agree.
  IF pg_temp.k770_as(stranger, q_g) <> 0 OR pg_temp.k770_as(blocked, q_g) <> 0 THEN leak := leak || ' games'; END IF;
  BEGIN
    IF pg_temp.k770_as(stranger, q_e) <> 0 OR pg_temp.k770_as(blocked, q_e) <> 0 THEN leak := leak || ' events'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN RESET ROLE; RAISE NOTICE 'KAN-770 B4: events refused to API roles (42501), as designed';
  END;
  IF pg_temp.k770_as(blocked, q_m) <> 0 THEN leak := leak || ' meetups(blocked)'; END IF;
  IF pg_temp.k770_as(stranger, q_m) <> 1 THEN leak := leak || ' meetups(stranger<>1)'; END IF;
  IF to_regprocedure('public._can_view_game(uuid)') IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.sub', blocked::text, true);
    IF public._can_view_game('77000000-0000-0000-0000-000000000001') THEN leak := leak || ' _can_view_game(blocked)'; END IF;
    PERFORM set_config('request.jwt.claim.sub', '', true);
  END IF;
  IF leak <> '' THEN RAISE EXCEPTION 'KAN-770 B4 FAIL: extra visibility:%', leak; END IF;
  RAISE NOTICE 'KAN-770 B4 PASS: stranger and blocked see 0 new games/events; stranger sees the public meetup (legacy), blocked sees 0; _can_view_game(blocked) = false';
END $s$;
ROLLBACK;

-- B5 rollback leaves data and shapes intact
DO $r$
BEGIN
  IF (SELECT g FROM k770_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT m FROM k770_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT e FROM k770_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t)
     OR (SELECT shape FROM k770_fp) IS DISTINCT FROM (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
          FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-770 B5 FAIL: games/meetups/events data or column shape changed after ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-770 B5 PASS: md5 of games %, meetups %, events % and the column shape identical after ROLLBACK',
    left((SELECT g FROM k770_fp), 8), left((SELECT m FROM k770_fp), 8), left((SELECT e FROM k770_fp), 8);
  RAISE NOTICE 'KAN-770 SCENARIO PASS';
END $r$;
