-- KAN-726 (KAN-714 piece B07) test: rpc_sport_overview game/meetup counts and v_host_weekly_metrics read shared
-- columns from public.events.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
--
-- Load order (database must already hold the migration):
--   tests/events_p1/local_harness_kan711.sql, tests/events_p1/local_seed_kan711.sql,
--   tests/events_p2/local_harness_kan712.sql, tests/events_p2_kan713/local_harness_kan713.sql,
--   tests/events_p2_kan714/local_harness_kan714.sql   (fixture: rpc_sport_overview + v_host_weekly_metrics pre-images),
--   migrations 20261101140000, 20261102110000, 20261102120000,
--     CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();
--   migrations 20261103100000, 20261103110000, 20261104100000, 20261104110000, 20261104110300,
--   migrations 20261104100100 (B01), 20261104100200 (B02),
--   migrations/20261104100700_kan714_b07_sport_overview_counts.sql, then THIS FILE.
--
-- Flow: extra fixture rows (idempotent) -> snapshot NEW -> provenance probes on NEW -> rollback block (verbatim copy
-- of the migration's KAN726-ROLLBACK section) -> snapshot OLD -> the same probes on OLD (they must fail there) ->
-- compare -> re-apply the migration with \ir -> verify round trip and data intact. Leaves the database migrated.
-- Assertions: A signature/shape, B counts equal legacy per sport/city/viewer + no doubling, C provenance from
-- events, D per-viewer results incl. anon/blocked/non-owner, E rollback byte-for-byte + data intact + re-apply,
-- F plan (one events scan per legacy games/meetups read, none under a correlated SubPlan, no added SubPlan).

\set ON_ERROR_STOP 1
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------------------
-- T0. Preconditions
-- ---------------------------------------------------------------------------------------------------------
DO $t0$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_sport_overview(uuid,text)'::regprocedure)
       <> 'e7eb361a30f342e9e98df7b944638787'
     OR NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                     WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'T0 FAIL: migration 20261104100700 not applied (rpc_sport_overview body / v_host_weekly_metrics not on events)';
  END IF;
  IF (SELECT count(*) FROM public.games) = 0 OR (SELECT count(*) FROM public.meetups) = 0 THEN
    RAISE EXCEPTION 'T0 FAIL: harness must hold games and meetups';
  END IF;
  RAISE NOTICE 'T0 PASS preconditions (games=%, meetups=%, events=%)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);
END
$t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Extra fixture (idempotent, fixed ids, inserted through the KAN-712 guard so each row gets its events parent).
-- The bulk seed has one sport, every in-window row in DXB and no in-window row by the blocked creator (a6, blocked
-- by a1). These rows add: a second sport, AUH in-window rows, an in-window blocked-creator row, in-window cancelled,
-- ended, ended+cancelled, non-public and outside-window rows, for both types.
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO public.sports (id, sport_key, name_en, is_challenge_sport, is_active, can_solo)
VALUES ('00000000-0000-0000-0000-0000000000e2', 'padel', 'Padel', true, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                          join_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled)
SELECT ('72600000-0000-0000-0000-00000000000' || f.n)::uuid, 'B07 game ' || f.n,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid, ('00000000-0000-0000-0000-0000000000a' || f.who)::uuid,
       date_trunc('minute', now()) + f.off, date_trunc('minute', now()) + f.off + interval '1 hour', 10, f.vis, 'open',
       ('00000000-0000-0000-0000-0000000000' || f.sp)::uuid, ('00000000-0000-0000-0000-0000000000d' || f.ar)::uuid,
       ('00000000-0000-0000-0000-0000000000c' || f.ar)::uuid, 1, 6, 'pickup', f.canc
  FROM (VALUES (1, '6', interval '2 days',  'public',    false, 'e2', '2'),   -- in-window, blocked creator, AUH
               (2, '2', interval '2 days',  'public',    true,  'e2', '2'),   -- in-window cancelled
               (3, '2', interval '-3 days', 'public',    false, 'e2', '2'),   -- ended
               (4, '2', interval '-3 days', 'public',    true,  'e2', '2'),   -- ended + cancelled
               (5, '5', interval '2 days',  'followers', false, 'e2', '2'),   -- in-window non-public
               (6, '2', interval '8 days',  'public',    false, 'e2', '2'),   -- outside window
               (7, '7', interval '3 days',  'public',    false, 'e2', '1'),   -- in-window DXB (probe row)
               (8, '6', interval '1 day',   'public',    false, 'e1', '2'))   -- sport e1, blocked creator, AUH
       AS f(n, who, off, vis, canc, sp, ar)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at,
                            listing_visibility, rsvp_policy, sport_id, geo_location_id, area_id, min_skill, max_skill,
                            capacity, is_cancelled, location_name, is_indoor)
SELECT ('72600000-0000-0000-0001-00000000000' || f.n)::uuid, 'B07 meetup ' || f.n, 'B07',
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid, ('00000000-0000-0000-0000-0000000000a' || f.who)::uuid,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid,
       date_trunc('minute', now()) + f.off, date_trunc('minute', now()) + f.off + interval '1 hour', f.vis, 'open',
       ('00000000-0000-0000-0000-0000000000' || f.sp)::uuid, ('00000000-0000-0000-0000-0000000000d' || f.ar)::uuid,
       ('00000000-0000-0000-0000-0000000000c' || f.ar)::uuid, 1, 6, 5, f.canc, 'B07 place', true
  FROM (VALUES (1, '6', interval '2 days',  'public', false, 'e2', '2'),
               (2, '2', interval '2 days',  'public', true,  'e2', '2'),
               (3, '2', interval '-3 days', 'public', false, 'e2', '2'),
               (4, '2', interval '-3 days', 'public', true,  'e2', '2'),
               (5, '5', interval '2 days',  'circle', false, 'e2', '2'),
               (6, '2', interval '8 days',  'public', false, 'e2', '2'),
               (7, '7', interval '3 days',  'public', false, 'e2', '1'),
               (8, '6', interval '1 day',   'public', false, 'e1', '2'))
       AS f(n, who, off, vis, canc, sp, ar)
ON CONFLICT (id) DO NOTHING;

SELECT 'fixture' AS t,
       (SELECT count(*) FROM public.games   WHERE id::text LIKE '72600000-0000-0000-0000-%') AS b07_games,
       (SELECT count(*) FROM public.meetups WHERE id::text LIKE '72600000-0000-0000-0001-%') AS b07_meetups,
       (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
         WHERE g.id::text LIKE '72600000-%') AS b07_games_with_parent,
       (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
         WHERE m.id::text LIKE '72600000-%') AS b07_meetups_with_parent;

-- ---------------------------------------------------------------------------------------------------------
-- Probe viewers: anon, a stranger, the harness admin, blocker (a1) / blocked (a6), and the other creators.
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan726_users;
CREATE TEMP TABLE kan726_users (label text PRIMARY KEY, uid uuid);
INSERT INTO kan726_users VALUES ('anon', NULL), ('stranger', '72600000-0000-0000-00ff-000000000001');
INSERT INTO kan726_users SELECT 'admin', admin_uid FROM public.harness_admins ORDER BY admin_uid LIMIT 1;
INSERT INTO kan726_users SELECT 'blocker', blocker_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan726_users SELECT 'blocked', blocked_user_id FROM public.user_blocks ORDER BY id LIMIT 1;
INSERT INTO kan726_users
SELECT 'creator_' || row_number() OVER (ORDER BY c.u), c.u
  FROM (SELECT DISTINCT creator_user_id AS u FROM public.games
        UNION SELECT DISTINCT creator_user_id FROM public.meetups) c
 WHERE c.u NOT IN (SELECT uid FROM kan726_users WHERE uid IS NOT NULL);
SELECT string_agg(label, ',' ORDER BY label) AS probe_viewers FROM kan726_users;

-- ---------------------------------------------------------------------------------------------------------
-- Snapshot helpers
-- ---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS pg_temp.kan726_meta, pg_temp.kan726_rows, pg_temp.kan726_host, pg_temp.kan726_plan,
                     pg_temp.kan726_prov, pg_temp.kan726_data;
CREATE TEMP TABLE kan726_meta (phase text, args text, full_args text, result text, lang text, secdef boolean, vol "char",
                               par "char", config text[], owner text, acl text, comment text, src_md5 text, def_md5 text,
                               v_sig text, v_owner text, v_acl text, v_opts text, v_def_md5 text, v_reads_events boolean);
CREATE TEMP TABLE kan726_rows (phase text, label text, sport text, city text, res text);
CREATE TEMP TABLE kan726_host (phase text, label text, n bigint, hosted bigint, row_md5 text);
CREATE TEMP TABLE kan726_plan (phase text, target text, events_scans int, games_scans int, meetups_scans int,
                               events_under_subplan int, subplans int);
CREATE TEMP TABLE kan726_prov (phase text, kind text, col text, base text, after text);
CREATE TEMP TABLE kan726_data (phase text, games_md5 text, meetups_md5 text, events_md5 text, roster_md5 text);

-- games_next7 / meetups_next7 for one viewer, called as postgres (provenance only needs auth.uid()).
CREATE FUNCTION pg_temp.kan726_cnt(p_uid uuid, p_sport uuid, p_city text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r record;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
  SELECT * INTO r FROM public.rpc_sport_overview(p_sport, p_city);
  RETURN r.games_next7 || '/' || r.meetups_next7;
END
$f$;

CREATE FUNCTION pg_temp.kan726_plan_of(p_sql text) RETURNS TABLE(events_scans int, games_scans int, meetups_scans int,
                                                                 events_under_subplan int, subplans int)
LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE 'EXPLAIN (FORMAT JSON, COSTS OFF) ' || p_sql INTO j;
  RETURN QUERY
  WITH RECURSIVE n(node, in_sub) AS (
    SELECT j->0->'Plan', false
    UNION ALL
    SELECT c, n.in_sub OR c->>'Parent Relationship' = 'SubPlan'
      FROM n, jsonb_array_elements(coalesce(n.node->'Plans', '[]'::jsonb)) c)
  SELECT count(*) FILTER (WHERE node->>'Relation Name' = 'events')::int,
         count(*) FILTER (WHERE node->>'Relation Name' = 'games')::int,
         count(*) FILTER (WHERE node->>'Relation Name' = 'meetups')::int,
         count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND in_sub)::int,
         count(*) FILTER (WHERE node->>'Parent Relationship' = 'SubPlan')::int
    FROM n;
END
$f$;

CREATE FUNCTION pg_temp.kan726_snapshot(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  u record; s text; c text; r record; v_res text; v_q text;
  f oid := 'public.rpc_sport_overview(uuid,text)'::regprocedure;
BEGIN
  INSERT INTO kan726_data
  SELECT p_phase,
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
         (SELECT md5(string_agg(t::text, '|' ORDER BY t::text)) FROM public.game_roster t);

  INSERT INTO kan726_meta
  SELECT p_phase, pg_get_function_identity_arguments(p.oid), pg_get_function_arguments(p.oid), pg_get_function_result(p.oid),
         l.lanname, p.prosecdef, p.provolatile, p.proparallel, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text,
         obj_description(p.oid, 'pg_proc'), md5(p.prosrc), md5(pg_get_functiondef(p.oid)),
         (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
            FROM pg_attribute a WHERE a.attrelid = vc.oid AND a.attnum > 0 AND NOT a.attisdropped),
         pg_get_userbyid(vc.relowner), vc.relacl::text, coalesce(vc.reloptions::text, ''), md5(pg_get_viewdef(vc.oid)),
         EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = vc.oid AND d.refobjid = 'public.events'::regclass)
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang, pg_class vc
   WHERE p.oid = f AND vc.oid = 'public.v_host_weekly_metrics'::regclass;

  -- B/D: every sport (plus an unknown id) x every city filter x every viewer, as the API role the viewer would use.
  FOR u IN SELECT * FROM kan726_users ORDER BY label LOOP
    FOREACH s IN ARRAY ARRAY['00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2',
                             '00000000-0000-0000-0000-0000000000e9'] LOOP
      FOREACH c IN ARRAY ARRAY['*', 'DXB', 'AUH', 'XXX'] LOOP
        PERFORM set_config('request.jwt.claim.sub', coalesce(u.uid::text, ''), true);
        EXECUTE 'SET LOCAL ROLE ' || CASE WHEN u.uid IS NULL THEN 'anon' ELSE 'authenticated' END;
        BEGIN
          SELECT t::text INTO v_res FROM public.rpc_sport_overview(s::uuid, nullif(c, '*')) t;
          RESET ROLE;
        EXCEPTION WHEN insufficient_privilege THEN
          RESET ROLE;
          v_res := 'ERR:' || SQLSTATE;
        END;
        INSERT INTO kan726_rows VALUES (p_phase, u.label, s, c, v_res);
      END LOOP;
    END LOOP;

    -- v_host_weekly_metrics through the API role: no SELECT grant for anon/authenticated (must match both phases).
    EXECUTE 'SET LOCAL ROLE ' || CASE WHEN u.uid IS NULL THEN 'anon' ELSE 'authenticated' END;
    BEGIN
      SELECT count(*) AS n, sum(games_hosted) AS h, md5(string_agg(t::text, '|' ORDER BY t::text)) AS m INTO r
        FROM public.v_host_weekly_metrics t;
      RESET ROLE;
      INSERT INTO kan726_host VALUES (p_phase, u.label, r.n, r.h, r.m);
    EXCEPTION WHEN insufficient_privilege THEN
      RESET ROLE;
      INSERT INTO kan726_host VALUES (p_phase, u.label, NULL, NULL, 'ERR:' || SQLSTATE);
    END;
  END LOOP;
  -- full view row set as its owner (the path award_top_host_weekly / v_top_hosts_week use)
  SELECT count(*) AS n, sum(games_hosted) AS h, md5(string_agg(t::text, '|' ORDER BY t::text)) AS m INTO r
    FROM public.v_host_weekly_metrics t;
  INSERT INTO kan726_host VALUES (p_phase, 'postgres', r.n, r.h, r.m);

  -- F: plan of the function's own RETURN QUERY (extracted from the live prosrc, variables bound to literals)
  SELECT substring(p.prosrc FROM 'RETURN QUERY(.*);\s*END;') INTO v_q FROM pg_proc p WHERE p.oid = f;
  v_q := regexp_replace(v_q, '\mp_sport_id\M', '''00000000-0000-0000-0000-0000000000e1''::uuid', 'g');
  v_q := regexp_replace(v_q, '\mv_uid\M', '''00000000-0000-0000-0000-0000000000a1''::uuid', 'g');
  v_q := regexp_replace(v_q, '\mv_window\M', '''7 days''::interval', 'g');
  v_q := regexp_replace(v_q, '\mv_key\M', '''football''::text', 'g');
  v_q := regexp_replace(v_q, '\mv_city\M', '''DXB''::text', 'g');
  INSERT INTO kan726_plan SELECT p_phase, 'rpc_sport_overview', x.* FROM pg_temp.kan726_plan_of(v_q) x;
  INSERT INTO kan726_plan SELECT p_phase, 'v_host_weekly_metrics', x.*
    FROM pg_temp.kan726_plan_of('SELECT * FROM public.v_host_weekly_metrics') x;
END
$f$;

-- C: provenance probes. Inside a rolled-back subtransaction with triggers off (replica), make ONE events parent
-- disagree with its subtype row and measure. On the new definitions the result must follow events; on the old it
-- must not move (the probe is shown failing there). The subtype row is never touched.
CREATE FUNCTION pg_temp.kan726_probe(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
  g7 uuid := '72600000-0000-0000-0000-000000000007';
  m7 uuid := '72600000-0000-0000-0001-000000000007';
  e2 uuid := '00000000-0000-0000-0000-0000000000e2';
  a1 uuid := '00000000-0000-0000-0000-0000000000a1';
  a5 uuid := '00000000-0000-0000-0000-0000000000a5';
  a7 uuid := '00000000-0000-0000-0000-0000000000a7';
  strg uuid := '72600000-0000-0000-00ff-000000000001';
  pr record; v_base text; v_after text; v_tbl text; v_sub uuid; v_eid uuid; v_cap uuid;
  v_y int; v_w int; v_host uuid;
BEGIN
  -- count probes: (column, SET clause, viewer, city)
  FOR pr IN SELECT * FROM (VALUES
      ('sport_id',           'sport_id = ''00000000-0000-0000-0000-0000000000e1''',                  'strg', NULL),
      ('is_cancelled',       'is_cancelled = true',                                                  'strg', NULL),
      ('listing_visibility', 'listing_visibility = CASE event_type WHEN ''game'' THEN ''private'' ELSE ''circle'' END', 'strg', NULL),
      ('start_at',           'start_at = start_at + interval ''30 days'', end_at = end_at + interval ''30 days''', 'strg', NULL),
      ('creator_user_id',    'creator_user_id = ''00000000-0000-0000-0000-0000000000a6''',            'a1',   NULL),
      ('area_id',            'area_id = ''00000000-0000-0000-0000-0000000000c2''',                    'strg', 'DXB')) AS t(col, setc, who, city)
  LOOP
    FOREACH v_tbl IN ARRAY ARRAY['games', 'meetups'] LOOP
      v_sub := CASE v_tbl WHEN 'games' THEN g7 ELSE m7 END;
      EXECUTE format('SELECT event_id FROM public.%I WHERE id = $1', v_tbl) INTO v_eid USING v_sub;
      v_base := pg_temp.kan726_cnt(CASE pr.who WHEN 'a1' THEN a1 ELSE strg END, e2, pr.city);
      BEGIN
        SET LOCAL session_replication_role = replica;
        EXECUTE 'UPDATE public.events SET ' || pr.setc || ' WHERE id = $1' USING v_eid;
        v_after := pg_temp.kan726_cnt(CASE pr.who WHEN 'a1' THEN a1 ELSE strg END, e2, pr.city);
        RAISE EXCEPTION 'kan726_probe_rollback';
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'kan726_probe_rollback' THEN RAISE; END IF;
      END;
      -- keep the measured type's half of 'games_next7/meetups_next7'
      INSERT INTO kan726_prov VALUES (p_phase, v_tbl, pr.col,
        split_part(v_base,  '/', CASE v_tbl WHEN 'games' THEN 1 ELSE 2 END),
        split_part(v_after, '/', CASE v_tbl WHEN 'games' THEN 1 ELSE 2 END));
    END LOOP;
  END LOOP;

  -- host-metric probes on v_host_weekly_metrics (as owner): games_hosted for g7's host/week
  SELECT e.event_id INTO v_eid FROM public.games e WHERE e.id = g7;
  SELECT (date_part('isoyear', start_at))::int, (date_part('week', start_at))::int INTO v_y, v_w FROM public.games WHERE id = g7;
  FOR pr IN SELECT * FROM (VALUES
      ('creator_user_id', 'creator_user_id = ''00000000-0000-0000-0000-0000000000a5'''),
      ('is_cancelled',    'is_cancelled = true'),
      ('start_at',        'start_at = start_at + interval ''30 days'', end_at = end_at + interval ''30 days''')) AS t(col, setc)
  LOOP
    SELECT coalesce(sum(games_hosted), 0)::text INTO v_base FROM public.v_host_weekly_metrics
     WHERE user_id = a7 AND isoy = v_y AND isow = v_w;
    BEGIN
      SET LOCAL session_replication_role = replica;
      EXECUTE 'UPDATE public.events SET ' || pr.setc || ' WHERE id = $1' USING v_eid;
      SELECT coalesce(sum(games_hosted), 0)::text INTO v_after FROM public.v_host_weekly_metrics
       WHERE user_id = a7 AND isoy = v_y AND isow = v_w;
      RAISE EXCEPTION 'kan726_probe_rollback';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'kan726_probe_rollback' THEN RAISE; END IF;
    END;
    INSERT INTO kan726_prov VALUES (p_phase, 'host', pr.col, v_base, v_after);
  END LOOP;

  -- capacity -> fill_rate, on a game that has active roster rows
  SELECT g.id, g.event_id, g.creator_user_id, (date_part('isoyear', g.start_at))::int, (date_part('week', g.start_at))::int
    INTO v_cap, v_eid, v_host, v_y, v_w
    FROM public.games g JOIN public.game_roster r ON r.game_id = g.id AND r.status = 'active'
   WHERE g.capacity < 64 GROUP BY g.id ORDER BY g.id LIMIT 1;
  IF v_cap IS NULL THEN RAISE EXCEPTION 'C FAIL: fixture has no game with an active roster row'; END IF;
  SELECT fill_rate::text INTO v_base FROM public.v_host_weekly_metrics WHERE user_id = v_host AND isoy = v_y AND isow = v_w;
  BEGIN
    SET LOCAL session_replication_role = replica;
    UPDATE public.events SET capacity = 64 WHERE id = v_eid;
    SELECT fill_rate::text INTO v_after FROM public.v_host_weekly_metrics WHERE user_id = v_host AND isoy = v_y AND isow = v_w;
    RAISE EXCEPTION 'kan726_probe_rollback';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'kan726_probe_rollback' THEN RAISE; END IF;
  END;
  INSERT INTO kan726_prov VALUES (p_phase, 'host', 'capacity', v_base, v_after);
END
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- T1. NEW definitions
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
SELECT pg_temp.kan726_snapshot('new');
SELECT pg_temp.kan726_probe('new');
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- T2. Rollback: verbatim copy of the migration's KAN726-ROLLBACK-BEGIN..END block, comment prefix removed.
-- ---------------------------------------------------------------------------------------------------------
-- KAN726-ROLLBACK-BEGIN (copy)
BEGIN;
CREATE OR REPLACE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint,
               posts bigint, news bigint, mutual_followers jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_window interval := interval '7 days';
  v_key    text;
  v_city   text := p_city_code;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'permission denied for function rpc_sport_overview' USING ERRCODE = '42501';
  END IF;

  SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id;

  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT p.id) FROM public.profiles p
      WHERE p.interests @> ARRAY[p_sport_id]
        AND NOT public.is_blocked(v_uid, p.user_id)),

    (SELECT count(DISTINCT g.id) FROM public.games g
       LEFT JOIN public.areas a ON a.id = g.area_id
      WHERE g.sport_id = p_sport_id AND g.is_cancelled = false
        AND g.listing_visibility = 'public'
        AND g.start_at >= now() AND g.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, g.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT m.id) FROM public.meetups m
       LEFT JOIN public.areas a ON a.id = m.area_id
      WHERE m.sport_id = p_sport_id AND m.is_cancelled = false
        AND m.listing_visibility = 'public'
        AND m.start_at >= now() AND m.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, m.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT v.id) FROM public.venues v
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE v.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)
        AND ( (v_key IS NOT NULL AND v.sports @> ARRAY[v_key])
              OR EXISTS (SELECT 1 FROM public.venue_spaces vs
                          WHERE vs.venue_id = v.id AND vs.sport_id = p_sport_id AND vs.is_active = true) )),

    (SELECT count(DISTINCT vs.id) FROM public.venue_spaces vs
       JOIN public.venues v ON v.id = vs.venue_id AND v.is_active = true
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE vs.sport_id = p_sport_id AND vs.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT po.id) FROM public.posts po
      WHERE po.sport_id = p_sport_id AND po.visibility = 'public'
        AND po.is_deleted = false AND po.is_hidden_admin = false
        AND coalesce(po.is_active, true) = true
        AND (po.expires_at IS NULL OR po.expires_at > now())
        AND NOT public.is_blocked(v_uid, po.author_user_id)),

    (SELECT count(DISTINCT n.id) FROM public.news n
       LEFT JOIN public.areas a ON a.id = n.area_id
      WHERE n.sport_id = p_sport_id AND n.status = 'published'
        AND n.published_at <= now() AND (n.expires_at IS NULL OR n.expires_at > now())
        AND (v_city IS NULL OR a.city_code = v_city)),

    coalesce((SELECT jsonb_agg(jsonb_build_object('display_name', x.display_name,
                                                  'avatar_url', x.avatar_url,
                                                  'username', x.username::text) ORDER BY x.username)
                FROM (SELECT DISTINCT ON (p.id) p.id, p.display_name, p.avatar_url, p.username
                        FROM public.profile_follows f
                        JOIN public.profiles me ON me.id = f.follower_profile_id AND me.user_id = v_uid
                        JOIN public.profiles p  ON p.id = f.following_profile_id
                       WHERE p.interests @> ARRAY[p_sport_id]
                         AND p.user_id <> v_uid
                         AND NOT public.is_blocked(v_uid, p.user_id)
                       ORDER BY p.id
                       LIMIT 3) x), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE VIEW "public"."v_host_weekly_metrics" AS
 WITH "g" AS (
         SELECT "g"."id",
            "g"."creator_user_id" AS "host_user_id",
            ("date_trunc"('week'::"text", "g"."start_at"))::"date" AS "week_start",
            ("date_part"('isoyear'::"text", "g"."start_at"))::integer AS "isoy",
            ("date_part"('week'::"text", "g"."start_at"))::integer AS "isow",
            "g"."capacity",
            "g"."is_cancelled"
           FROM "public"."games" "g"
        ), "r" AS (
         SELECT "game_roster"."game_id",
            "count"(*) FILTER (WHERE ("game_roster"."status" = 'active'::"text")) AS "active_cnt"
           FROM "public"."game_roster"
          GROUP BY "game_roster"."game_id"
        ), "m" AS (
         SELECT "g"."host_user_id" AS "user_id",
            "g"."isoy",
            "g"."isow",
            "count"(*) FILTER (WHERE (NOT "g"."is_cancelled")) AS "games_hosted",
            "round"("avg"(GREATEST(0.0, LEAST(1.0, (COALESCE(("r"."active_cnt")::numeric, (0)::numeric) / (NULLIF("g"."capacity", 0))::numeric)))), 3) AS "fill_rate"
           FROM ("g"
             LEFT JOIN "r" ON (("r"."game_id" = "g"."id")))
          GROUP BY "g"."host_user_id", "g"."isoy", "g"."isow"
        )
 SELECT "user_id",
    "isoy",
    "isow",
    "games_hosted",
    "fill_rate"
   FROM "m";
COMMIT;
-- KAN726-ROLLBACK-END (copy)

-- ---------------------------------------------------------------------------------------------------------
-- T3. OLD definitions (restored by T2)
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
SELECT pg_temp.kan726_snapshot('old');
SELECT pg_temp.kan726_probe('old');
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- T4. Assertions
-- ---------------------------------------------------------------------------------------------------------
DO $t4$
DECLARE
  n_new kan726_meta%ROWTYPE; n_old kan726_meta%ROWTYPE;
  v_users int := (SELECT count(*) FROM kan726_users);
  v int; r record; v_txt text;
BEGIN
  -- A. signature / shape / attributes
  SELECT * INTO n_new FROM kan726_meta WHERE phase = 'new';
  SELECT * INTO n_old FROM kan726_meta WHERE phase = 'old';
  IF (n_new.args, n_new.full_args, n_new.result, n_new.lang, n_new.secdef, n_new.vol, n_new.par, n_new.config,
      n_new.owner, n_new.acl, n_new.comment)
     IS DISTINCT FROM
     (n_old.args, n_old.full_args, n_old.result, n_old.lang, n_old.secdef, n_old.vol, n_old.par, n_old.config,
      n_old.owner, n_old.acl, n_old.comment) THEN
    RAISE EXCEPTION 'A FAIL: rpc_sport_overview signature/result/attributes/owner/ACL/comment differ new vs old: % | %',
      row_to_json(n_new), row_to_json(n_old);
  END IF;
  IF NOT n_new.secdef OR n_new.vol <> 's' OR n_new.config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR n_new.owner <> 'postgres' THEN
    RAISE EXCEPTION 'A FAIL: rpc_sport_overview lost SECURITY DEFINER / STABLE / search_path / owner';
  END IF;
  IF (n_new.v_sig, n_new.v_owner, n_new.v_acl, n_new.v_opts) IS DISTINCT FROM (n_old.v_sig, n_old.v_owner, n_old.v_acl, n_old.v_opts) THEN
    RAISE EXCEPTION 'A FAIL: v_host_weekly_metrics columns/owner/ACL/reloptions differ new vs old';
  END IF;
  IF n_new.src_md5 = n_old.src_md5 OR n_new.v_def_md5 = n_old.v_def_md5 THEN
    RAISE EXCEPTION 'A FAIL: rollback did not change the definitions (test is not comparing two versions)';
  END IF;
  RAISE NOTICE 'A PASS signature + return shape identical: rpc_sport_overview(%) RETURNS % | secdef=% vol=% config=% owner=% acl=% ; v_host_weekly_metrics cols=% acl=%',
    n_new.args, n_new.result, n_new.secdef, n_new.vol, n_new.config, n_new.owner, n_new.acl, n_new.v_sig, n_new.v_acl;

  -- B. every count equals legacy, every sport x city x viewer, and the fixture is not trivial
  SELECT count(*) INTO v FROM kan726_rows WHERE phase = 'new';
  IF v <> v_users * 12 OR (SELECT count(*) FROM kan726_rows WHERE phase = 'old') <> v THEN
    RAISE EXCEPTION 'B FAIL: expected % calls per phase, new=% old=%', v_users * 12, v,
      (SELECT count(*) FROM kan726_rows WHERE phase = 'old');
  END IF;
  FOR r IN SELECT n.label, n.sport, n.city, n.res AS new_res, o.res AS old_res
             FROM kan726_rows n FULL JOIN kan726_rows o
               ON o.phase = 'old' AND (o.label, o.sport, o.city) = (n.label, n.sport, n.city)
            WHERE n.phase = 'new' AND n.res IS DISTINCT FROM o.res LOOP
    RAISE EXCEPTION 'B FAIL: % sport=% city=% new=% old=%', r.label, r.sport, r.city, r.new_res, r.old_res;
  END LOOP;
  -- exact expected values on the B07 sport: cancelled, ended, ended+cancelled, non-public and outside-window rows
  -- are excluded; the blocked creator's (a6) row is excluded for the blocker (a1) but a6 still sees its own; AUH and DXB split.
  FOR r IN SELECT * FROM (VALUES
      ('stranger', '*',   2, 2), ('stranger', 'AUH', 1, 1), ('stranger', 'DXB', 1, 1), ('stranger', 'XXX', 0, 0),
      ('blocker',  '*',   1, 1), ('blocker',  'AUH', 0, 0), ('blocked',  '*',   2, 2)) AS t(label, city, eg, em)
  LOOP
    SELECT split_part(trim(both '()' FROM res), ',', 2) || '/' || split_part(trim(both '()' FROM res), ',', 3) INTO v_txt
      FROM kan726_rows WHERE phase = 'new' AND label = r.label
       AND sport = '00000000-0000-0000-0000-0000000000e2' AND city = r.city;
    IF v_txt IS DISTINCT FROM (r.eg || '/' || r.em) THEN
      RAISE EXCEPTION 'B FAIL: % e2/% games/meetups_next7=% expected %/%', r.label, r.city, v_txt, r.eg, r.em;
    END IF;
  END LOOP;
  -- no doubling: each subtype row has exactly one typed parent, so the join is 1:1
  IF (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game')
       <> (SELECT count(*) FROM public.games)
     OR (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup')
       <> (SELECT count(*) FROM public.meetups) THEN
    RAISE EXCEPTION 'B FAIL: games/meetups -> events join is not 1:1 (doubling or loss)';
  END IF;
  IF (SELECT count(*) FROM kan726_rows WHERE phase = 'new' AND res NOT LIKE 'ERR:%'
        AND split_part(trim(both '()' FROM res), ',', 2)::int > 0) = 0 THEN
    RAISE EXCEPTION 'B FAIL: every games_next7 is zero; the fixture proves nothing';
  END IF;
  IF (SELECT count(DISTINCT res) FROM kan726_rows WHERE phase = 'new' AND label IN ('stranger', 'blocker')
        AND sport = '00000000-0000-0000-0000-0000000000e2' AND city = '*') <> 2 THEN
    RAISE EXCEPTION 'B FAIL: blocker and stranger see the same counts; the blocked-creator path is not exercised';
  END IF;
  FOR r IN SELECT n.label, n.n AS nn, o.n AS no_, n.row_md5 AS nm, o.row_md5 AS om
             FROM kan726_host n JOIN kan726_host o ON o.phase = 'old' AND o.label = n.label
            WHERE n.phase = 'new' AND (n.n, n.hosted, n.row_md5) IS DISTINCT FROM (o.n, o.hosted, o.row_md5) LOOP
    RAISE EXCEPTION 'B FAIL: v_host_weekly_metrics for % differs new(%,%) vs old(%,%)', r.label, r.nn, r.nm, r.no_, r.om;
  END LOOP;
  RAISE NOTICE 'B PASS counts equal legacy: % rpc_sport_overview calls per phase identical (3 sports x 4 city filters x % viewers); e2 expected values hold; joins 1:1 (games %, meetups %); v_host_weekly_metrics owner row set identical (rows=%, games_hosted=%)',
    v, v_users, (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups),
    (SELECT n FROM kan726_host WHERE phase = 'new' AND label = 'postgres'),
    (SELECT hosted FROM kan726_host WHERE phase = 'new' AND label = 'postgres');

  -- C. provenance: follows events on NEW, does not on OLD
  IF (SELECT count(*) FROM kan726_prov WHERE phase = 'new') <> 16 OR (SELECT count(*) FROM kan726_prov WHERE phase = 'old') <> 16 THEN
    RAISE EXCEPTION 'C FAIL: expected 16 probes per phase';
  END IF;
  FOR r IN SELECT * FROM kan726_prov ORDER BY phase, kind, col LOOP
    IF r.phase = 'new' AND r.col = 'capacity' AND r.after IS NOT DISTINCT FROM r.base THEN
      RAISE EXCEPTION 'C FAIL new: host fill_rate did not follow events.capacity (% -> %)', r.base, r.after;
    ELSIF r.phase = 'new' AND r.col <> 'capacity' AND r.after::int <> r.base::int - 1 THEN
      RAISE EXCEPTION 'C FAIL new: % did not follow events.% (% -> %)', r.kind, r.col, r.base, r.after;
    ELSIF r.phase = 'old' AND r.after IS DISTINCT FROM r.base THEN
      RAISE EXCEPTION 'C FAIL old: % moved with events.% on the OLD definition (% -> %); probe does not discriminate', r.kind, r.col, r.base, r.after;
    END IF;
  END LOOP;
  RAISE NOTICE 'C PASS provenance: new follows events on %; old ignores the same edits (probe fails on old: %)',
    (SELECT string_agg(kind || '.' || col || ' ' || base || '->' || after, ', ' ORDER BY kind, col) FROM kan726_prov WHERE phase = 'new'),
    (SELECT string_agg(kind || '.' || col || ' ' || base || '->' || after, ', ' ORDER BY kind, col) FROM kan726_prov WHERE phase = 'old');

  -- D. per-viewer: anon refused identically, API roles refused on the owner-only view identically
  IF EXISTS (SELECT 1 FROM kan726_rows WHERE label = 'anon' AND res <> 'ERR:42501') THEN
    RAISE EXCEPTION 'D FAIL: anon reached rpc_sport_overview';
  END IF;
  IF EXISTS (SELECT 1 FROM kan726_rows WHERE label <> 'anon' AND res LIKE 'ERR:%') THEN
    RAISE EXCEPTION 'D FAIL: an authenticated viewer was refused';
  END IF;
  IF EXISTS (SELECT 1 FROM kan726_host WHERE label <> 'postgres' AND row_md5 <> 'ERR:42501') THEN
    RAISE EXCEPTION 'D FAIL: an API role can SELECT v_host_weekly_metrics';
  END IF;
  RAISE NOTICE 'D PASS viewers: % (anon ERR:42501 both phases; stranger/admin/blocker/blocked/creators identical row by row; v_host_weekly_metrics ERR:42501 for API roles both phases)',
    (SELECT string_agg(label, ',' ORDER BY label) FROM kan726_users);

  -- E (part 1). rollback restored the old definitions byte for byte; data untouched
  IF n_old.def_md5 <> 'eef538193cdd4e28a8f24ac463090457' OR n_old.src_md5 <> '1ba644397046241ae6c1f7f81c5bc9b7'
     OR n_old.v_def_md5 <> '2be17f3097b0ad36d834bdc90d34b790' THEN
    RAISE EXCEPTION 'E FAIL: rollback did not restore pre-migration definitions (def % src % view %)',
      n_old.def_md5, n_old.src_md5, n_old.v_def_md5;
  END IF;
  IF (SELECT (games_md5, meetups_md5, events_md5, roster_md5) FROM kan726_data WHERE phase = 'new')
     IS DISTINCT FROM (SELECT (games_md5, meetups_md5, events_md5, roster_md5) FROM kan726_data WHERE phase = 'old') THEN
    RAISE EXCEPTION 'E FAIL: data changed across rollback (or a probe leaked)';
  END IF;
  RAISE NOTICE 'E PASS rollback: md5(pg_get_functiondef)=% md5(prosrc)=% md5(viewdef)=% = pre-migration; games/meetups/events/game_roster md5 unchanged',
    n_old.def_md5, n_old.src_md5, n_old.v_def_md5;

  -- F. plans
  SELECT * INTO r FROM kan726_plan WHERE phase = 'new' AND target = 'rpc_sport_overview';
  IF r.events_scans <> 2 OR r.events_under_subplan <> 0
     OR (r.games_scans, r.meetups_scans, r.subplans) IS DISTINCT FROM
        (SELECT ROW(games_scans, meetups_scans, subplans) FROM kan726_plan WHERE phase = 'old' AND target = 'rpc_sport_overview')
     OR (SELECT events_scans FROM kan726_plan WHERE phase = 'old' AND target = 'rpc_sport_overview') <> 0 THEN
    RAISE EXCEPTION 'F FAIL rpc_sport_overview plan: new % old %', row_to_json(r),
      (SELECT row_to_json(p) FROM kan726_plan p WHERE phase = 'old' AND target = 'rpc_sport_overview');
  END IF;
  SELECT * INTO r FROM kan726_plan WHERE phase = 'new' AND target = 'v_host_weekly_metrics';
  IF r.events_scans <> 1 OR r.events_under_subplan <> 0
     OR (r.games_scans, r.subplans) IS DISTINCT FROM
        (SELECT ROW(games_scans, subplans) FROM kan726_plan WHERE phase = 'old' AND target = 'v_host_weekly_metrics')
     OR (SELECT events_scans FROM kan726_plan WHERE phase = 'old' AND target = 'v_host_weekly_metrics') <> 0 THEN
    RAISE EXCEPTION 'F FAIL v_host_weekly_metrics plan: new % old %', row_to_json(r),
      (SELECT row_to_json(p) FROM kan726_plan p WHERE phase = 'old' AND target = 'v_host_weekly_metrics');
  END IF;
  RAISE NOTICE 'F PASS plans: %', (SELECT string_agg(format('%s/%s events=%s games=%s meetups=%s events_under_subplan=%s subplans=%s',
      phase, target, events_scans, games_scans, meetups_scans, events_under_subplan, subplans), '; ' ORDER BY target, phase) FROM kan726_plan);
END
$t4$;

-- ---------------------------------------------------------------------------------------------------------
-- T5. Re-apply the migration and verify the round trip
-- ---------------------------------------------------------------------------------------------------------
\ir ../../migrations/20261104100700_kan714_b07_sport_overview_counts.sql

BEGIN;
SELECT pg_temp.kan726_snapshot('reapply');
COMMIT;

DO $t5$
DECLARE a kan726_meta%ROWTYPE; b kan726_meta%ROWTYPE;
BEGIN
  SELECT * INTO a FROM kan726_meta WHERE phase = 'new';
  SELECT * INTO b FROM kan726_meta WHERE phase = 'reapply';
  IF row_to_json(a)::jsonb - 'phase' <> row_to_json(b)::jsonb - 'phase' THEN
    RAISE EXCEPTION 'E FAIL: re-apply catalogue differs from first apply: % | %', row_to_json(a), row_to_json(b);
  END IF;
  IF EXISTS (SELECT 1 FROM kan726_rows n FULL JOIN kan726_rows x
               ON x.phase = 'reapply' AND (x.label, x.sport, x.city) = (n.label, n.sport, n.city)
              WHERE n.phase = 'new' AND n.res IS DISTINCT FROM x.res)
     OR (SELECT count(*) FROM kan726_rows WHERE phase = 'reapply') <> (SELECT count(*) FROM kan726_rows WHERE phase = 'new') THEN
    RAISE EXCEPTION 'E FAIL: re-apply results differ from first apply';
  END IF;
  IF (SELECT (games_md5, meetups_md5, events_md5, roster_md5) FROM kan726_data WHERE phase = 'new')
     IS DISTINCT FROM (SELECT (games_md5, meetups_md5, events_md5, roster_md5) FROM kan726_data WHERE phase = 'reapply') THEN
    RAISE EXCEPTION 'E FAIL: data changed by re-apply';
  END IF;
  RAISE NOTICE 'E PASS re-apply round trip: md5(pg_get_functiondef)=% md5(viewdef)=% identical to first apply; results and data identical',
    b.def_md5, b.v_def_md5;
  RAISE NOTICE 'KAN-726 ALL PASS';
END
$t5$;
