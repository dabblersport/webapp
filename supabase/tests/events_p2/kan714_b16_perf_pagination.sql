-- KAN-735 (KAN-714 B16, Epic KAN-708): performance before/after, no N+1, no duplicate cards, and
-- equal-start_at keyset pagination for the converted listing surfaces:
--   v_game_card            (B01, 20261104100100)      v_meetup_list (B02, 20261104100200)
--   rpc_get_nearby_games(6 args), rpc_games_following_joined  (B04, 20261104100400)
--   rpc_unified_search_sectioned games + meetups sections + events_game_public_search_tsv_idx (B05, 20261104100500)
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
-- No migration belongs to this ticket; this file measures and asserts.
--
-- BASELINE. The ticket says "against the E1 baseline". No E1 performance artifact exists in the repository
-- (grep: "E1" appears only as KAN714_CONTRACT.md exception E1 = rpc_meetup_my, unrelated;
-- rpc_meetup_my itself was since RETIRED by KAN-785, 20261104110400). The baseline is
-- therefore defined as the PRE-IMAGE: the database the existing harness chain builds BEFORE B01/B02/B04/B05,
-- i.e. the legacy definitions verbatim from the repo (local_harness_kan714.sql for both views and
-- rpc_games_following_joined, local_harness_kan724.sql for rpc_unified_search_sectioned, and the 6-arg
-- rpc_get_nearby_games created below verbatim from 20261008140000:360-442, md5-pinned by B04's precondition).
--
-- TWO MODES, ONE FILE (run order is fixed; /Users/.../clean735.sh does it end to end):
--   -v mode=before   on the PRE-IMAGE database (B01/B02/B04/B05 NOT applied). COMMITS, local only:
--                    (a) stand-ins the chain lacks for the nearby RPC: a geography domain over the KAN-714
--                        harness geometry composite + st_makepoint/st_setsrid/st_distance/st_dwithin (planar
--                        haversine), and the 6-arg rpc_get_nearby_games pre-image verbatim + its repo grant;
--                    (b) the KAN-735 fixture: 8 games and 8 meetups sharing ONE start_at (mixed visibility, one
--                        cancelled each) + one upcoming "prov" game and meetup — on top of the harness population
--                        of 3,000 games / 2,000 meetups that already carries equal-start_at groups of 5;
--                    (c) public.kan735_baseline / kan735_perf / kan735_preimage: per-viewer row sets of every
--                        surface, EXPLAIN (ANALYZE, BUFFERS) plans + median timings, and the pre-image DDL.
--   (default) test   after B01, B02, B04, B05 are applied. ONE transaction, ROLLBACK at the end: T0 A B C D E F
--                    H P sections, ends with NOTICE 'KAN-735 ALL PASS'. Nothing is committed.
--
-- PLANS OF FUNCTION BODIES. A SECURITY DEFINER function shows only "Function Scan" in EXPLAIN. To see the body's
-- plan, both phases build an INLINABLE pg_temp copy from the CURRENT prosrc (same body, no SECURITY DEFINER /
-- SET), which the planner inlines; the plan is asserted to be inlined (no Function Scan on the copy). For the
-- plpgsql unified search, the games and meetups section SELECTs are extracted from the CURRENT prosrc by regex,
-- with v_tsquery / p_limit_per_section substituted. Timings of the real call are measured on the real function.
-- All plans/timings run as postgres (the owner and definer of every surface) with request.jwt.claim.sub set.

\set ON_ERROR_STOP 1
SET client_min_messages = warning;
\if :{?mode}
\else
\set mode test
\endif
SELECT :'mode' = 'before' AS k735_before \gset

-- ===========================================================================================================
-- Shared helpers (pg_temp; identical in both modes)
-- ===========================================================================================================
DROP FUNCTION IF EXISTS pg_temp.k735_stats(jsonb);
CREATE FUNCTION pg_temp.k735_stats(j jsonb) RETURNS jsonb LANGUAGE sql AS $f$
  WITH RECURSIVE n(node, in_sub, parent) AS (
    SELECT j->0->'Plan', false, ''::text
    UNION ALL
    SELECT c, n.in_sub OR coalesce(c->>'Parent Relationship', '') IN ('SubPlan', 'InitPlan'), n.node->>'Node Type'
      FROM n, jsonb_array_elements(coalesce(n.node->'Plans', '[]'::jsonb)) c
  )
  SELECT jsonb_build_object(
    'exec_ms', round((j->0->>'Execution Time')::numeric, 3),
    'top', j->0->'Plan'->>'Node Type',
    'events_nodes', count(*) FILTER (WHERE node->>'Relation Name' = 'events'),
    'events_in_subplan', count(*) FILTER (WHERE node->>'Relation Name' = 'events' AND in_sub),
    'events_access', coalesce(string_agg(DISTINCT (node->>'Node Type') || ' under ' || parent || ' loops=' || coalesce(node->>'Actual Loops', '?'),
                                         '; ') FILTER (WHERE node->>'Relation Name' = 'events'), '-'),
    'subplans', count(*) FILTER (WHERE node->>'Parent Relationship' = 'SubPlan'),
    'function_scans', coalesce(string_agg(DISTINCT node->>'Function Name', ',') FILTER (WHERE node->>'Node Type' = 'Function Scan'), '-'),
    'shared_hit', coalesce((j->0->'Plan'->>'Shared Hit Blocks')::bigint, 0),
    'shared_read', coalesce((j->0->'Plan'->>'Shared Read Blocks')::bigint, 0))
  FROM n
$f$;

-- One warm-up, then p_reps EXPLAIN (ANALYZE, BUFFERS) runs; median execution time + the last plan.
DROP FUNCTION IF EXISTS pg_temp.k735_measure(text, int);
CREATE FUNCTION pg_temp.k735_measure(p_sql text, p_reps int DEFAULT 7, OUT median_ms numeric, OUT plan jsonb)
LANGUAGE plpgsql AS $f$
DECLARE
  j json;
  t numeric[] := '{}';
BEGIN
  EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
  FOR i IN 1..p_reps LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
    t := t || ((j::jsonb)->0->>'Execution Time')::numeric;
  END LOOP;
  SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY x)::numeric, 3) INTO median_ms FROM unnest(t) x;
  plan := j::jsonb;
END
$f$;

-- Inlinable copy of a SQL function's CURRENT body (no SECURITY DEFINER, no SET): exposes the body's plan.
DROP FUNCTION IF EXISTS pg_temp.k735_inline(regprocedure, text);
CREATE FUNCTION pg_temp.k735_inline(p_fn regprocedure, p_name text) RETURNS void LANGUAGE plpgsql
SET client_min_messages = warning AS $f$
BEGIN
  EXECUTE format('DROP FUNCTION IF EXISTS pg_temp.%I', p_name);
  EXECUTE (SELECT format('CREATE FUNCTION pg_temp.%I(%s) RETURNS %s LANGUAGE sql STABLE AS %L', p_name,
                         pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosrc)
             FROM pg_proc p WHERE p.oid = p_fn);
END
$f$;

-- A section SELECT of the CURRENT rpc_unified_search_sectioned body, with its plpgsql variables substituted.
DROP FUNCTION IF EXISTS pg_temp.k735_section(text, text, text);
CREATE FUNCTION pg_temp.k735_section(p_name text, p_next text, p_query text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  s text;
BEGIN
  SELECT substring(prosrc FROM '''' || p_name || ''', \((.*?)\),\s+''' || p_next || ''', \(') INTO s
    FROM pg_proc WHERE oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure;
  IF s IS NULL THEN
    RAISE EXCEPTION 'H FAIL: could not extract the % section from rpc_unified_search_sectioned', p_name;
  END IF;
  s := regexp_replace(s, '\mv_tsquery\M', format('plainto_tsquery(%L, unaccent(%L))', 'simple', p_query), 'g');
  RETURN regexp_replace(s, '\mp_limit_per_section\M', '10', 'g');
END
$f$;

SET client_min_messages = notice;

-- Viewers. a1 = fixture host (blocks a6), a2 = follower (b2 follows b4/b5/b7), a3 = harness admin, a6 = blocked by a1.
CREATE TEMP TABLE k735_viewers (label text PRIMARY KEY, uid uuid);
INSERT INTO k735_viewers VALUES
  ('anon', NULL), ('stranger', '00000000-0000-0000-0000-00000000fff1'),
  ('host_a1', '00000000-0000-0000-0000-0000000000a1'), ('follower_a2', '00000000-0000-0000-0000-0000000000a2'),
  ('admin_a3', '00000000-0000-0000-0000-0000000000a3'), ('blocked_a6', '00000000-0000-0000-0000-0000000000a6');

-- Row-set fingerprint of every surface for one viewer: n, distinct ids, md5 of the sorted rows.
-- nearby: LIMIT 50 ordered by distance, price, start_at has NO id tie-break (pre-existing, B05 inventory X3), so
-- rows of the LAST start_at in the result are compared by count only; everything before that is compared exactly.
CREATE FUNCTION pg_temp.k735_rowsets(p_label text)
RETURNS TABLE(surface text, n bigint, nd bigint, h text, foreign_ids bigint) LANGUAGE plpgsql AS $f$
DECLARE
  v_uid uuid := (SELECT uid FROM k735_viewers WHERE label = p_label);
  v_ids text := (SELECT quote_literal(array_agg(id ORDER BY id)::text) || '::uuid[]'
                   FROM (SELECT id FROM public.games ORDER BY id LIMIT 200) s);
  r record;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(v_uid::text, ''), true);
  EXECUTE 'SET LOCAL ROLE ' || CASE WHEN v_uid IS NULL THEN 'anon' ELSE 'authenticated' END;
  SELECT count(*) AS c, count(DISTINCT t.id) AS cd, md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) AS m,
         count(*) FILTER (WHERE t.id IN (SELECT id FROM public.meetups)) AS f INTO r FROM public.v_game_card t;
  surface := 'v_game_card'; n := r.c; nd := r.cd; h := r.m; foreign_ids := r.f; RETURN NEXT;
  SELECT count(*) AS c, count(DISTINCT t.id) AS cd, md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) AS m,
         count(*) FILTER (WHERE t.id IN (SELECT id FROM public.games)) AS f INTO r FROM public.v_meetup_list t;
  surface := 'v_meetup_list'; n := r.c; nd := r.cd; h := r.m; foreign_ids := r.f; RETURN NEXT;
  WITH t AS (SELECT * FROM public.rpc_get_nearby_games(25.2, 55.27, 50000))
  SELECT count(*) AS c, count(DISTINCT t.id) AS cd,
         md5(coalesce(string_agg(t::text, '|' ORDER BY t::text) FILTER (WHERE t.scheduled_at < (SELECT max(scheduled_at) FROM t)), '')
             || ':' || count(*) FILTER (WHERE t.scheduled_at = (SELECT max(scheduled_at) FROM t))) AS m,
         count(*) FILTER (WHERE t.id IN (SELECT id FROM public.meetups)) AS f INTO r FROM t;
  surface := 'rpc_get_nearby_games'; n := r.c; nd := r.cd; h := r.m; foreign_ids := r.f; RETURN NEXT;
  -- anon has no EXECUTE on this RPC (legacy grant: authenticated only); the denial itself is the parity row.
  BEGIN
    EXECUTE 'SELECT count(*) AS c, count(DISTINCT t.game_id) AS cd, md5(coalesce(string_agg(t::text, ''|'' ORDER BY t::text), '''')) AS m,'
            ' count(*) FILTER (WHERE t.game_id IN (SELECT id FROM public.meetups)) AS f'
            ' FROM public.rpc_games_following_joined(' || v_ids || ') t' INTO r;
    surface := 'rpc_games_following_joined'; n := r.c; nd := r.cd; h := r.m; foreign_ids := r.f;
  EXCEPTION WHEN insufficient_privilege THEN
    surface := 'rpc_games_following_joined'; n := 0; nd := 0; h := 'permission denied'; foreign_ids := 0;
  END;
  RETURN NEXT;
  FOR r IN
    WITH j AS (SELECT public.rpc_unified_search_sectioned('bulk', NULL, NULL, NULL, NULL, 5000) AS j
               UNION ALL SELECT public.rpc_unified_search_sectioned('k735', NULL, NULL, NULL, NULL, 5000)),
         x AS (SELECT s.sec, e AS item FROM j, unnest(ARRAY['games', 'meetups']) s(sec), jsonb_array_elements(j.j -> s.sec) e)
    SELECT x.sec, count(*) AS c, count(DISTINCT x.item->>'entity_id') AS cd,
           md5(coalesce(string_agg(x.item::text, '|' ORDER BY x.item::text), '')) AS m,
           count(*) FILTER (WHERE (x.sec = 'games' AND (x.item->>'entity_id')::uuid IN (SELECT id FROM public.meetups))
                               OR (x.sec = 'meetups' AND (x.item->>'entity_id')::uuid IN (SELECT id FROM public.games))) AS f
      FROM x GROUP BY x.sec
  LOOP
    surface := 'unified_search.' || r.sec; n := r.c; nd := r.cd; h := r.m; foreign_ids := r.f; RETURN NEXT;
  END LOOP;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

-- The measured queries. *_call = the real surface as the app calls it; *_body = the plan of the body.
CREATE FUNCTION pg_temp.k735_queries() RETURNS TABLE(qkey text, qsql text, is_body boolean) LANGUAGE plpgsql AS $f$
DECLARE
  v_ids text := (SELECT quote_literal(array_agg(id ORDER BY id)::text) || '::uuid[]'
                   FROM (SELECT id FROM public.games ORDER BY id LIMIT 200) s);
BEGIN
  PERFORM pg_temp.k735_inline('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'k735_nb');
  PERFORM pg_temp.k735_inline('public.rpc_games_following_joined(uuid[])', 'k735_fj');
  RETURN QUERY VALUES
    ('gc_page', 'SELECT * FROM public.v_game_card WHERE is_cancelled = false ORDER BY start_at, id LIMIT 50', true),
    ('gc_full', 'SELECT * FROM public.v_game_card', true),
    ('ml_page', 'SELECT * FROM public.v_meetup_list WHERE is_cancelled = false ORDER BY start_at LIMIT 20 OFFSET 0', true),
    ('ml_full', 'SELECT * FROM public.v_meetup_list', true),
    ('nb_call', 'SELECT * FROM public.rpc_get_nearby_games(25.2, 55.27, 50000)', false),
    ('nb_body', 'SELECT * FROM pg_temp.k735_nb(25.2, 55.27, 50000)', true),
    ('fj_call', 'SELECT * FROM public.rpc_games_following_joined(' || v_ids || ')', false),
    ('fj_body', 'SELECT * FROM pg_temp.k735_fj(' || v_ids || ')', true),
    ('us_call', 'SELECT public.rpc_unified_search_sectioned(''bulk'')', false),
    ('us_games', pg_temp.k735_section('games', 'venues', 'bulk'), true),
    ('us_meetups', pg_temp.k735_section('meetups', 'challenges', 'bulk'), true);
END
$f$;

\if :k735_before
-- ===========================================================================================================
-- MODE before: pre-image stand-ins + fixture + baseline capture (COMMITS; local only)
-- ===========================================================================================================
BEGIN;
DO $t0$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'T0 FAIL: this looks like a Supabase database; local throwaway cluster only';
  END IF;
  IF to_regclass('public.kan735_baseline') IS NOT NULL THEN
    RAISE EXCEPTION 'T0 FAIL: baseline already captured; mode=before runs once, on the fresh pre-image chain';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
              WHERE rw.ev_class IN ('public.v_game_card'::regclass, 'public.v_meetup_list'::regclass)
                AND d.refobjid = 'public.events'::regclass)
     OR to_regclass('public.events_game_public_search_tsv_idx') IS NOT NULL
     OR (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_games_following_joined(uuid[])'::regprocedure) LIKE '%KAN-723%' THEN
    RAISE EXCEPTION 'T0 FAIL: a B01/B02/B04/B05 change is already applied; mode=before needs the PRE-IMAGE chain';
  END IF;
  IF to_regclass('public.events') IS NULL OR (SELECT count(*) FROM public.games) < 3000 OR (SELECT count(*) FROM public.meetups) < 2000 THEN
    RAISE EXCEPTION 'T0 FAIL: build the KAN-714 harness chain first (events + 3,000 games / 2,000 meetups)';
  END IF;
  IF to_regtype('public.geography') IS NOT NULL THEN
    RAISE EXCEPTION 'T0 FAIL: a geography type exists; these stand-ins are for the local chain only';
  END IF;
  RAISE NOTICE 'T0 PASS (before) pre-image chain: games=%, meetups=%, events=%',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);
END
$t0$;

-- (a) nearby stand-ins. geometry is the KAN-714 harness composite (x = lng, y = lat).
CREATE DOMAIN public.geography AS public.geometry;
CREATE FUNCTION public.st_makepoint(double precision, double precision) RETURNS public.geometry LANGUAGE sql IMMUTABLE
  AS $$ SELECT ROW($1, $2)::public.geometry $$;
CREATE FUNCTION public.st_setsrid(public.geometry, integer) RETURNS public.geometry LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
CREATE FUNCTION public.st_distance(public.geometry, public.geometry) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$
  SELECT 2 * 6371008.8 * asin(sqrt(power(sin(radians(($2).y - ($1).y) / 2), 2)
         + cos(radians(($1).y)) * cos(radians(($2).y)) * power(sin(radians(($2).x - ($1).x) / 2), 2))) $$;
CREATE FUNCTION public.st_dwithin(public.geometry, public.geometry, double precision) RETURNS boolean LANGUAGE sql IMMUTABLE
  AS $$ SELECT public.st_distance($1, $2) <= $3 $$;

-- 6-arg pre-image, VERBATIM from supabase/migrations/20261008140000_game_price_meetup_setting.sql:360-442 (+ :444 grant).
CREATE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text, p_max_price numeric DEFAULT NULL::numeric)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean, price_aed numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    g.id,
    coalesce(g.title, 'Untitled Game')    as title,
    s.name_en                              as sport_name,
    g.start_at                             as scheduled_at,
    case
      when g.is_cancelled         then 'cancelled'
      when now() >= g.end_at      then 'ended'
      when now() >= g.start_at    then 'live'
      else                             'upcoming'
    end                                    as status,
    ven.name_en                            as venue_name,
    st_y(gl.location::geometry)            as latitude,
    st_x(gl.location::geometry)            as longitude,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    )                                      as distance_meters,
    coalesce(roster.cnt, 0)::int           as player_count,
    greatest(g.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
    (g.listing_visibility = 'public')      as is_public,
    g.min_skill,
    g.max_skill,
    g.end_at,
    sv.name_en                             as variant_name_en,
    sv.name_ar                             as variant_name_ar,
    g.cost_cover,
    g.joining_rule,
    (coalesce((select pv.verified from profile_verifications pv
                where pv.profile_id = g.creator_profile_id), false)
     or exists (select 1 from organiser o
                where o.profile_id = g.creator_profile_id and o.sport = s.sport_key
                  and o.is_verified and o.is_active)) as host_verified,
    (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
    exists (select 1 from public.favorites f
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me,
    g.price_aed
  from   games g
  join   geo_locations gl on g.geo_location_id = gl.id
  join   sports s         on s.id = g.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = coalesce(vs.venue_id, g.venue_id)
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
  ) roster on true
  where  g.is_cancelled = false
    and  g.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or g.sport_id = p_sport_id)
    and  (p_max_price is null or g.price_aed <= p_max_price)
    and  (
           (g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
           or g.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
              )
         )
  order  by
    case when p_sort = 'distance'
         then st_distance(
                gl.location,
                st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
              )
    end asc nulls last,
    case when p_sort = 'price' then g.price_aed end asc nulls last,
    g.start_at asc
  limit 50;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric) TO anon, authenticated, service_role;

DO $pin$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure)
     <> 'e14430bad3dedb8540287f70ccfaa208' THEN
    RAISE EXCEPTION 'T0 FAIL: nearby pre-image is not the body B04 pins (e14430bad3dedb8540287f70ccfaa208)';
  END IF;
END
$pin$;

-- (b) fixture: one start_at shared by 8 games and 8 meetups (normal write path: the KAN-712 guard writes events
-- first), host a1/b1. g1-g5 public, g6 followers, g7 private, g8 public + cancelled; meetups public x5, circle,
-- hidden, public + cancelled. Identical titles/descriptions per type so the unified search scores tie too.
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled)
SELECT ('73500000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid, 'K735 tie game',
       '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
       timestamptz '2031-06-01 10:00+00', timestamptz '2031-06-01 11:00+00', 10,
       (ARRAY['public','public','public','public','public','followers','private','public'])[i], 'open',
       '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
       1, 10, 'pickup', i = 8
  FROM generate_series(1, 8) i;
INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at, listing_visibility,
                            rsvp_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, capacity, is_cancelled, location_name, is_indoor)
SELECT ('73500000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid, 'K735 tie meetup', 'k735 tie',
       '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
       timestamptz '2031-06-01 10:00+00', timestamptz '2031-06-01 12:00+00',
       (ARRAY['public','public','public','public','public','circle','hidden','public'])[i], 'open',
       '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
       1, 10, 10, i = 8, 'K735 Hall', true
  FROM generate_series(1, 8) i;
-- Upcoming provenance rows (the nearby RPC only returns start_at > now(); LIMIT 50 by start_at).
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled)
VALUES ('73500000-0000-0000-0000-000000000099', 'K735 prov game', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        date_trunc('minute', now()) + interval '2 hours', date_trunc('minute', now()) + interval '3 hours', 10, 'public', 'open',
        '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
        1, 10, 'pickup', false);
INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at, listing_visibility,
                            rsvp_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, capacity, is_cancelled, location_name, is_indoor)
VALUES ('73500000-0000-0000-0001-000000000099', 'K735 prov meetup', 'k735 prov', '00000000-0000-0000-0000-0000000000b1',
        '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
        date_trunc('minute', now()) + interval '2 hours', date_trunc('minute', now()) + interval '3 hours', 'public', 'open',
        '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
        1, 10, 10, false, 'K735 Hall', true);

-- (c) baseline tables
CREATE TABLE public.kan735_baseline (viewer text, surface text, n bigint, nd bigint, h text, foreign_ids bigint,
                                     PRIMARY KEY (viewer, surface));
CREATE TABLE public.kan735_perf (qkey text PRIMARY KEY, median_ms numeric, stats jsonb, plan jsonb);
CREATE TABLE public.kan735_preimage (ord int PRIMARY KEY, obj text, sig text, ddl text);
REVOKE ALL ON public.kan735_baseline, public.kan735_perf, public.kan735_preimage FROM PUBLIC, anon, authenticated;

INSERT INTO public.kan735_preimage
SELECT 1, 'v_meetup_counts', (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
                                 FROM pg_attribute a WHERE a.attrelid = 'public.v_meetup_counts'::regclass AND a.attnum > 0),
       'CREATE OR REPLACE VIEW public.v_meetup_counts' || coalesce(' WITH (' || array_to_string(c.reloptions, ', ') || ')', '')
       || ' AS ' || pg_get_viewdef(c.oid) FROM pg_class c WHERE c.oid = 'public.v_meetup_counts'::regclass
UNION ALL
SELECT o.ord, o.v, (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
                      FROM pg_attribute a WHERE a.attrelid = ('public.' || o.v)::regclass AND a.attnum > 0),
       'CREATE OR REPLACE VIEW public.' || o.v || coalesce(' WITH (' || array_to_string(c.reloptions, ', ') || ')', '')
       || ' AS ' || pg_get_viewdef(c.oid)
  FROM (VALUES (2, 'v_meetup_list'), (3, 'v_game_card'), (4, 'v_my_games')) o(ord, v)
  JOIN pg_class c ON c.oid = ('public.' || o.v)::regclass
UNION ALL
SELECT o.ord, o.f, pg_get_function_arguments(p.oid) || ' -> ' || pg_get_function_result(p.oid) || ' secdef=' || p.prosecdef
                   || ' config=' || coalesce(p.proconfig::text, '-') || ' acl=' || coalesce(p.proacl::text, '-'),
       pg_get_functiondef(p.oid)
  FROM (VALUES (5, 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'),
               (6, 'public.rpc_games_following_joined(uuid[])'),
               (7, 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)')) o(ord, f)
  JOIN pg_proc p ON p.oid = o.f::regprocedure;

ANALYZE;

INSERT INTO public.kan735_baseline SELECT v.label, r.* FROM k735_viewers v, LATERAL pg_temp.k735_rowsets(v.label) r;

DO $cap$
DECLARE
  q record;
  m record;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true);
  FOR q IN SELECT * FROM pg_temp.k735_queries() LOOP
    SELECT * INTO m FROM pg_temp.k735_measure(q.qsql);
    INSERT INTO public.kan735_perf VALUES (q.qkey, m.median_ms, pg_temp.k735_stats(m.plan), m.plan);
    RAISE NOTICE 'BASELINE % median % ms  %', rpad(q.qkey, 10), m.median_ms, pg_temp.k735_stats(m.plan);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'KAN-735 BASELINE CAPTURED: % row sets, % plans, % pre-image objects',
    (SELECT count(*) FROM public.kan735_baseline), (SELECT count(*) FROM public.kan735_perf), (SELECT count(*) FROM public.kan735_preimage);
END
$cap$;
COMMIT;

\else
-- ===========================================================================================================
-- MODE test: after B01/B02/B04/B05. One transaction, rolled back.
-- ===========================================================================================================
BEGIN;

-- T0. Preconditions: the four migrations are applied and the baseline exists ---------------------------------
DO $t0$
DECLARE
  v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  IF to_regclass('public.kan735_baseline') IS NULL OR (SELECT count(*) FROM public.kan735_perf) <> 11 THEN
    RAISE EXCEPTION 'T0 FAIL: baseline not captured; run this file with -v mode=before on the pre-image chain first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_game_card'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    v_missing := v_missing || ' 20261104100100(B01)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_meetup_list'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    v_missing := v_missing || ' 20261104100200(B02)';
  END IF;
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure)
       NOT LIKE '%KAN-723%'
     OR (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_games_following_joined(uuid[])'::regprocedure) NOT LIKE '%KAN-723%' THEN
    v_missing := v_missing || ' 20261104100400(B04)';
  END IF;
  IF to_regclass('public.events_game_public_search_tsv_idx') IS NULL
     OR (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure)
          NOT LIKE '%FROM public.events e%' THEN
    v_missing := v_missing || ' 20261104100500(B05)';
  END IF;
  IF v_missing <> '' THEN
    RAISE EXCEPTION 'T0 FAIL: migration(s) not applied:%', v_missing;
  END IF;
  RAISE NOTICE 'T0 PASS B01/B02/B04/B05 applied; baseline present; games=%, meetups=%, events=%',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);
END
$t0$;

CREATE TEMP TABLE k735_after (viewer text, surface text, n bigint, nd bigint, h text, foreign_ids bigint, PRIMARY KEY (viewer, surface));
INSERT INTO k735_after SELECT v.label, r.* FROM k735_viewers v, LATERAL pg_temp.k735_rowsets(v.label) r;

-- A. Shape: column signatures, function arguments/results/attributes unchanged ------------------------------
DO $a$
DECLARE
  r record;
  v_now text;
BEGIN
  FOR r IN SELECT * FROM public.kan735_preimage ORDER BY ord LOOP
    IF r.ord <= 4 THEN
      SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v_now
        FROM pg_attribute a WHERE a.attrelid = ('public.' || r.obj)::regclass AND a.attnum > 0;
    ELSE
      SELECT pg_get_function_arguments(p.oid) || ' -> ' || pg_get_function_result(p.oid) || ' secdef=' || p.prosecdef
             || ' config=' || coalesce(p.proconfig::text, '-') || ' acl=' || coalesce(p.proacl::text, '-') INTO v_now
        FROM pg_proc p WHERE p.oid = r.obj::regprocedure;
    END IF;
    IF v_now IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'A FAIL: % shape changed: before [%] after [%]', r.obj, r.sig, v_now;
    END IF;
  END LOOP;
  RAISE NOTICE 'A PASS legacy shapes unchanged (4 views column signatures, 3 RPC args/result/secdef/config/acl)';
END
$a$;

-- B. Counts equal legacy, no doubling, no cross-type ids; both types, every viewer -------------------------
DO $b$
DECLARE
  r record;
  v_n int := 0;
BEGIN
  FOR r IN SELECT b.*, a.n AS an, a.nd AS and_, a.h AS ah, a.foreign_ids AS af
             FROM public.kan735_baseline b JOIN k735_after a USING (viewer, surface) ORDER BY surface, viewer LOOP
    IF r.an <> r.and_ THEN
      RAISE EXCEPTION 'B FAIL: % as % returns duplicate rows (count % distinct %)', r.surface, r.viewer, r.an, r.and_;
    END IF;
    IF r.an <> r.n OR r.and_ <> r.nd THEN
      RAISE EXCEPTION 'B FAIL: % as % count changed: legacy %/% after %/%', r.surface, r.viewer, r.n, r.nd, r.an, r.and_;
    END IF;
    IF r.af <> 0 THEN
      RAISE EXCEPTION 'B FAIL: % as % surfaces % id(s) of the other event type', r.surface, r.viewer, r.af;
    END IF;
    IF r.ah <> r.h THEN
      RAISE EXCEPTION 'B FAIL: % as % row content differs from legacy (md5 % vs %)', r.surface, r.viewer, r.h, r.ah;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  IF v_n <> 36 THEN
    RAISE EXCEPTION 'B FAIL: expected 36 (6 surfaces x 6 viewers) comparisons, got %', v_n;
  END IF;
  RAISE NOTICE 'B PASS 36 row sets (6 surfaces x 6 viewers; unified search counted per section): count = count(distinct id) = legacy, identical rows, no cross-type ids';
  RAISE NOTICE 'B     admin_a3 counts: %', (SELECT string_agg(surface || '=' || n, ' ' ORDER BY surface) FROM k735_after WHERE viewer = 'admin_a3');
  IF (SELECT n FROM k735_after WHERE viewer = 'admin_a3' AND surface = 'v_game_card') = 0
     OR (SELECT n FROM k735_after WHERE viewer = 'admin_a3' AND surface = 'v_meetup_list') = 0
     OR (SELECT n FROM k735_after WHERE viewer = 'stranger' AND surface = 'rpc_get_nearby_games') = 0
     OR (SELECT n FROM k735_after WHERE viewer = 'follower_a2' AND surface = 'rpc_games_following_joined') = 0
     OR (SELECT n FROM k735_after WHERE viewer = 'stranger' AND surface = 'unified_search.games') = 0
     OR (SELECT n FROM k735_after WHERE viewer = 'stranger' AND surface = 'unified_search.meetups') = 0 THEN
    RAISE EXCEPTION 'B FAIL: a surface returned no rows for its probe viewer; the parity above would be vacuous';
  END IF;
END
$b$;

-- B-neg. The duplicate detector fires on a join that does double rows (shows the probe can fail).
DO $bn$
DECLARE
  n bigint; nd bigint;
BEGIN
  SELECT count(*), count(DISTINCT g.id) INTO n, nd
    FROM public.games g JOIN public.events e ON e.creator_user_id = g.creator_user_id AND e.event_type = 'game'
   WHERE g.id::text LIKE '73500000%';
  IF n = nd THEN
    RAISE EXCEPTION 'B-neg FAIL: the duplicate detector did not fire on a doubling join';
  END IF;
  RAISE NOTICE 'B-neg PASS duplicate detector fires on a doubling join (count % vs distinct %)', n, nd;
END
$bn$;

-- C. Provenance: events and the legacy row made to DISAGREE (triggers off, savepoint, rolled back) ----------
SAVEPOINT k735_c;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET title = 'K735PROV events game' WHERE id = '73500000-0000-0000-0000-000000000099';
UPDATE public.events SET title = 'K735PROV events meetup' WHERE id = '73500000-0000-0000-0001-000000000099';
SET LOCAL session_replication_role = origin;
DO $c$
DECLARE
  v text;
  ok int := 0;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
  IF (SELECT title FROM public.games WHERE id = '73500000-0000-0000-0000-000000000099') <> 'K735 prov game' THEN
    RAISE EXCEPTION 'C FAIL: setup: legacy title changed too';
  END IF;
  SELECT title INTO v FROM public.v_game_card WHERE id = '73500000-0000-0000-0000-000000000099';
  IF v = 'K735PROV events game' THEN ok := ok + 1; ELSE RAISE EXCEPTION 'C FAIL: v_game_card title % (not from events)', v; END IF;
  SELECT title INTO v FROM public.v_meetup_list WHERE id = '73500000-0000-0000-0001-000000000099';
  IF v = 'K735PROV events meetup' THEN ok := ok + 1; ELSE RAISE EXCEPTION 'C FAIL: v_meetup_list title % (not from events)', v; END IF;
  SELECT title INTO v FROM public.rpc_get_nearby_games(25.2, 55.27, 50000) WHERE id = '73500000-0000-0000-0000-000000000099';
  IF v = 'K735PROV events game' THEN ok := ok + 1; ELSE RAISE EXCEPTION 'C FAIL: rpc_get_nearby_games title % (not from events)', v; END IF;
  SELECT e->>'title' INTO v FROM jsonb_array_elements(public.rpc_unified_search_sectioned('k735 prov', NULL, NULL, NULL, NULL, 50)->'games') e
   WHERE e->>'entity_id' = '73500000-0000-0000-0000-000000000099';
  IF v = 'K735PROV events game' THEN ok := ok + 1; ELSE RAISE EXCEPTION 'C FAIL: unified search games title % (not from events)', v; END IF;
  SELECT e->>'title' INTO v FROM jsonb_array_elements(public.rpc_unified_search_sectioned('k735 prov', NULL, NULL, NULL, NULL, 50)->'meetups') e
   WHERE e->>'entity_id' = '73500000-0000-0000-0001-000000000099';
  IF v = 'K735PROV events meetup' THEN ok := ok + 1; ELSE RAISE EXCEPTION 'C FAIL: unified search meetups title % (not from events)', v; END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'C PASS provenance: % surfaces return the events title when events and the legacy row disagree', ok;
END
$c$;
ROLLBACK TO SAVEPOINT k735_c;

-- D. Access parity: non-owner and blocked viewers see nothing extra ---------------------------------------
DO $d$
DECLARE
  v_extra bigint;
  r record;
BEGIN
  -- Row-set identity per viewer is asserted in B (identical md5 to legacy for anon/stranger/blocked/...).
  -- Explicit: non-public fixture rows never reach a stranger, anon, or the blocked user.
  FOR r IN SELECT * FROM k735_viewers WHERE label IN ('anon', 'stranger', 'blocked_a6') LOOP
    PERFORM set_config('request.jwt.claim.sub', coalesce(r.uid::text, ''), true);
    EXECUTE 'SET LOCAL ROLE ' || CASE WHEN r.uid IS NULL THEN 'anon' ELSE 'authenticated' END;
    SELECT (SELECT count(*) FROM public.v_game_card WHERE id IN ('73500000-0000-0000-0000-000000000006', '73500000-0000-0000-0000-000000000007'))
         + (SELECT count(*) FROM public.v_meetup_list WHERE id IN ('73500000-0000-0000-0001-000000000006', '73500000-0000-0000-0001-000000000007'))
      INTO v_extra;
    RESET ROLE;
    IF v_extra <> 0 THEN
      RAISE EXCEPTION 'D FAIL: % sees % non-public fixture row(s)', r.label, v_extra;
    END IF;
  END LOOP;
  -- Blocked a6 vs host a1 (a1 blocks a6): whatever legacy showed a6 of a1's public rows, after shows the same.
  IF (SELECT h FROM k735_after WHERE viewer = 'blocked_a6' AND surface = 'rpc_get_nearby_games')
     <> (SELECT h FROM public.kan735_baseline WHERE viewer = 'blocked_a6' AND surface = 'rpc_get_nearby_games') THEN
    RAISE EXCEPTION 'D FAIL: blocked viewer nearby set changed';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a6', true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v_extra FROM public.rpc_get_nearby_games(25.2, 55.27, 50000) WHERE id = '73500000-0000-0000-0000-000000000099';
  RESET ROLE;
  IF v_extra <> 0 THEN
    RAISE EXCEPTION 'D FAIL: blocked a6 sees the blocker a1''s public game in nearby';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'D PASS access parity: anon/stranger/blocked see no non-public fixture row; blocked a6 does not see a1''s game in nearby; per-viewer sets = legacy (B)';
END
$d$;

-- E. Rollback leaves data intact: restore the pre-image DDL in a savepoint, compare, roll the savepoint back --
CREATE TEMP TABLE k735_hash AS
SELECT (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) AS games,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) AS meetups,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) AS events;
SAVEPOINT k735_e;
DO $e$
DECLARE
  r record;
  v_mig text := (SELECT md5(pg_get_viewdef('public.v_game_card'::regclass)));
BEGIN
  FOR r IN SELECT * FROM public.kan735_preimage ORDER BY ord LOOP
    EXECUTE r.ddl;
  END LOOP;
  DROP INDEX public.events_game_public_search_tsv_idx;
  IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
              WHERE rw.ev_class IN ('public.v_game_card'::regclass, 'public.v_meetup_list'::regclass)
                AND d.refobjid = 'public.events'::regclass)
     OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure) <> 'e14430bad3dedb8540287f70ccfaa208'
     OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_games_following_joined(uuid[])'::regprocedure) <> 'd3b31f55b000b4991be313f4c96d88d9'
     OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure) <> 'fe3382197842fa66564b2f62d9b754f5' THEN
    RAISE EXCEPTION 'E FAIL: pre-image not restored';
  END IF;
  IF (SELECT md5(pg_get_viewdef('public.v_game_card'::regclass))) = v_mig THEN
    RAISE EXCEPTION 'E FAIL: v_game_card definition unchanged by the rollback';
  END IF;
END
$e$;
CREATE TEMP TABLE k735_rb (viewer text, surface text, n bigint, nd bigint, h text, foreign_ids bigint);
INSERT INTO k735_rb SELECT v.label, r.* FROM k735_viewers v, LATERAL pg_temp.k735_rowsets(v.label) r;
DO $e2$
BEGIN
  IF (SELECT games FROM k735_hash) <> (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT meetups FROM k735_hash) <> (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT events FROM k735_hash) <> (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) THEN
    RAISE EXCEPTION 'E FAIL: data changed by the rollback DDL';
  END IF;
  IF EXISTS (SELECT 1 FROM k735_rb r JOIN public.kan735_baseline b USING (viewer, surface)
              WHERE (r.n, r.nd, r.h) IS DISTINCT FROM (b.n, b.nd, b.h)) THEN
    RAISE EXCEPTION 'E FAIL: rolled-back surfaces differ from the baseline';
  END IF;
  RAISE NOTICE 'E PASS rollback (pre-image DDL of 4 views + 3 RPCs, DROP the B05 index) restores the pre-image; games/meetups/events hashes unchanged; 36 row sets = baseline';
END
$e2$;
ROLLBACK TO SAVEPOINT k735_e;
DO $e3$
BEGIN
  IF to_regclass('public.events_game_public_search_tsv_idx') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                     WHERE rw.ev_class = 'public.v_game_card'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'E FAIL: migrated state not back after ROLLBACK TO SAVEPOINT';
  END IF;
END
$e3$;

-- F / H. Plans and timings after vs before; N+1 assertions -----------------------------------------------
CREATE TEMP TABLE k735_perf_after (qkey text PRIMARY KEY, median_ms numeric, stats jsonb, plan jsonb);
DO $f$
DECLARE
  q record;
  m record;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', true);
  FOR q IN SELECT * FROM pg_temp.k735_queries() LOOP
    SELECT * INTO m FROM pg_temp.k735_measure(q.qsql);
    INSERT INTO k735_perf_after VALUES (q.qkey, m.median_ms, pg_temp.k735_stats(m.plan), m.plan);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$f$;

DO $h$
DECLARE
  r record;
  v_body boolean;
BEGIN
  FOR r IN SELECT q.qkey, q.is_body, b.median_ms AS bms, a.median_ms AS ams, b.stats AS bs, a.stats AS st
             FROM pg_temp.k735_queries() q JOIN public.kan735_perf b USING (qkey) JOIN k735_perf_after a USING (qkey)
            ORDER BY q.qkey LOOP
    RAISE NOTICE 'F % before % ms  after % ms  (x%)  subplans %->%  events nodes %->% [%]',
      rpad(r.qkey, 10), r.bms, r.ams, round(r.ams / nullif(r.bms, 0), 2),
      r.bs->>'subplans', r.st->>'subplans', r.bs->>'events_nodes', r.st->>'events_nodes', r.st->>'events_access';
    IF r.is_body THEN
      IF r.st->>'function_scans' LIKE '%k735_%' OR r.bs->>'function_scans' LIKE '%k735_%' THEN
        RAISE EXCEPTION 'H FAIL: % body copy was not inlined; its plan is not the body plan', r.qkey;
      END IF;
      IF (r.st->>'events_nodes')::int < 1 THEN
        RAISE EXCEPTION 'H FAIL: % after-plan does not read public.events', r.qkey;
      END IF;
      IF (r.st->>'events_in_subplan')::int <> 0 THEN
        RAISE EXCEPTION 'H FAIL: % reads public.events inside a SubPlan/InitPlan (per-row lookup): %', r.qkey, r.st;
      END IF;
      IF (r.st->>'subplans')::int > (r.bs->>'subplans')::int THEN
        RAISE EXCEPTION 'H FAIL: % adds SubPlans: before % after %', r.qkey, r.bs->>'subplans', r.st->>'subplans';
      END IF;
    END IF;
    -- Gross-regression guard only: local timings are noisy and indicative.
    IF r.ams > 3 * r.bms + 25 THEN
      RAISE EXCEPTION 'H FAIL: % median % ms after vs % ms before (> 3x + 25 ms)', r.qkey, r.ams, r.bms;
    END IF;
  END LOOP;
  RAISE NOTICE 'H PASS no N+1: every body/view plan reads events in a set-based join (never in a SubPlan/InitPlan), adds no SubPlan, and no surface regresses past 3x + 25 ms';
END
$h$;

-- H-neg. The N+1 detector fires on a correlated per-row events lookup (shows the probe can fail).
DO $hn$
DECLARE
  j json;
  s jsonb;
BEGIN
  EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) SELECT g.id, (SELECT e.title FROM public.events e WHERE e.id = g.event_id OFFSET 0) FROM public.games g' INTO j;
  s := pg_temp.k735_stats(j::jsonb);
  IF (s->>'events_in_subplan')::int = 0 THEN
    RAISE EXCEPTION 'H-neg FAIL: the N+1 detector did not fire on a correlated events SubPlan: %', s;
  END IF;
  RAISE NOTICE 'H-neg PASS N+1 detector fires on a correlated events lookup (events in SubPlan: %, %)', s->>'events_in_subplan', s->>'events_access';
END
$hn$;

-- P. Equal-start_at pagination, both event types ------------------------------------------------------------
-- Ordering under test: (start_at, id) — the tie-break B05 (c1d7d13d) gives the search sections, applied to the
-- card/list views as keyset and as OFFSET pages. Windows: W1 = the fixture instant (8 games / 8 meetups share one
-- start_at), W2 = harness day 2030-01-02 (24 groups of 5 equal start_at, every visibility). Page sizes 3 and 4
-- (neither divides 5 or 8, so page boundaries fall inside tie groups). Viewer host a1 (sees its private rows).
DO $p$
DECLARE
  v text; w record; ps int; mode text;
  full_ids uuid[]; paged uuid[]; page uuid[];
  ls timestamptz; lid uuid; off int;
  checks int := 0; v_nd bigint;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
  SET LOCAL ROLE authenticated;
  FOREACH v IN ARRAY ARRAY['v_game_card', 'v_meetup_list'] LOOP
    FOR w IN SELECT * FROM (VALUES ('W1', timestamptz '2031-06-01 10:00+00', timestamptz '2031-06-01 10:00:01+00'),
                                   ('W2', timestamptz '2030-01-02 00:00+00', timestamptz '2030-01-03 00:00+00')) x(wn, lo, hi) LOOP
      EXECUTE format('SELECT array_agg(id ORDER BY start_at, id) FROM public.%I WHERE start_at >= $1 AND start_at < $2', v)
        INTO full_ids USING w.lo, w.hi;
      EXECUTE format('SELECT count(DISTINCT start_at) FROM public.%I WHERE start_at >= $1 AND start_at < $2', v) INTO v_nd USING w.lo, w.hi;
      IF coalesce(array_length(full_ids, 1), 0) < 6 THEN
        RAISE EXCEPTION 'P FAIL: % % holds % rows; not enough to paginate', v, w.wn, coalesce(array_length(full_ids, 1), 0);
      END IF;
      IF w.wn = 'W1' AND v_nd <> 1 THEN
        RAISE EXCEPTION 'P FAIL: W1 rows do not share one start_at';
      END IF;
      FOREACH ps IN ARRAY ARRAY[3, 4] LOOP
        FOREACH mode IN ARRAY ARRAY['keyset', 'offset'] LOOP
          paged := '{}'; ls := NULL; lid := NULL; off := 0;
          LOOP
            IF mode = 'keyset' THEN
              EXECUTE format('SELECT array_agg(id ORDER BY start_at, id), (array_agg(start_at ORDER BY start_at DESC, id DESC))[1],'
                             ' (array_agg(id ORDER BY start_at DESC, id DESC))[1] FROM (SELECT id, start_at FROM public.%I'
                             ' WHERE start_at >= $1 AND start_at < $2 AND ($3::timestamptz IS NULL OR (start_at, id) > ($3, $4))'
                             ' ORDER BY start_at, id LIMIT $5) s', v)
                INTO page, ls, lid USING w.lo, w.hi, ls, lid, ps;
            ELSE
              EXECUTE format('SELECT array_agg(id ORDER BY start_at, id) FROM (SELECT id, start_at FROM public.%I'
                             ' WHERE start_at >= $1 AND start_at < $2 ORDER BY start_at, id LIMIT $3 OFFSET $4) s', v)
                INTO page USING w.lo, w.hi, ps, off;
              off := off + ps;
            END IF;
            EXIT WHEN page IS NULL;
            paged := paged || page;
            EXIT WHEN array_length(page, 1) < ps;
          END LOOP;
          IF paged IS DISTINCT FROM full_ids THEN
            RAISE EXCEPTION 'P FAIL: % % % page=% skipped or repeated rows: full % paged %', v, w.wn, mode, ps,
              array_length(full_ids, 1), array_length(paged, 1);
          END IF;
          IF (SELECT count(DISTINCT x) FROM unnest(paged) x) <> array_length(full_ids, 1) THEN
            RAISE EXCEPTION 'P FAIL: % % % page=% repeated a row', v, w.wn, mode, ps;
          END IF;
          checks := checks + 1;
        END LOOP;
      END LOOP;
      RAISE NOTICE 'P   % % rows=% (distinct start_at %): keyset + offset, page 3 and 4: union = full set, no skip, no repeat',
        rpad(v, 13), w.wn, array_length(full_ids, 1), v_nd;
    END LOOP;
  END LOOP;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'P PASS equal-start_at pagination: % checks (2 types x 2 windows x 2 page sizes x keyset/offset)', checks;
END
$p$;

-- P-neg. Keyset on start_at alone (no id tie-break) over the 8-row tie group skips rows: the probe can fail.
DO $pn$
DECLARE
  n_full int; n_paged int; page uuid[]; ls timestamptz;
BEGIN
  SELECT count(*) INTO n_full FROM public.v_game_card WHERE start_at = timestamptz '2031-06-01 10:00+00';
  SELECT array_agg(id), max(start_at) INTO page FROM (SELECT id, start_at FROM public.v_game_card
     WHERE start_at >= timestamptz '2031-06-01 10:00+00' AND start_at < timestamptz '2031-06-01 10:00:01+00' ORDER BY start_at LIMIT 3) s;
  ls := timestamptz '2031-06-01 10:00+00';
  SELECT 3 + count(*) INTO n_paged FROM public.v_game_card
   WHERE start_at > ls AND start_at < timestamptz '2031-06-01 10:00:01+00';
  IF n_paged = n_full THEN
    RAISE EXCEPTION 'P-neg FAIL: start_at-only keyset did not lose rows (% of %)', n_paged, n_full;
  END IF;
  RAISE NOTICE 'P-neg PASS start_at-only keyset over the tie group returns % of % rows (detector fires)', n_paged, n_full;
END
$pn$;

-- P2. Unified search ties: equal score AND equal start_at resolve by id, and a smaller limit is a prefix of a larger.
DO $p2$
DECLARE
  sec text; l3 text[]; l10 text[]; lall text[];
BEGIN
  FOREACH sec IN ARRAY ARRAY['games', 'meetups'] LOOP
    SELECT array_agg(e->>'entity_id' ORDER BY o) INTO l3
      FROM jsonb_array_elements(public.rpc_unified_search_sectioned('k735 tie', NULL, NULL, NULL, NULL, 3)->sec) WITH ORDINALITY x(e, o);
    SELECT array_agg(e->>'entity_id' ORDER BY o) INTO l10
      FROM jsonb_array_elements(public.rpc_unified_search_sectioned('k735 tie', NULL, NULL, NULL, NULL, 10)->sec) WITH ORDINALITY x(e, o);
    SELECT array_agg(e->>'entity_id' ORDER BY o) INTO lall
      FROM jsonb_array_elements(public.rpc_unified_search_sectioned('k735 tie', NULL, NULL, NULL, NULL, 1000)->sec) WITH ORDINALITY x(e, o);
    IF coalesce(array_length(lall, 1), 0) <> 5 THEN
      RAISE EXCEPTION 'P2 FAIL: % section for "k735 tie" returned % rows, expected the 5 public non-cancelled fixture rows', sec, array_length(lall, 1);
    END IF;
    IF l3 <> lall[1:3] OR l10 <> lall[1:5] THEN
      RAISE EXCEPTION 'P2 FAIL: % limit 3 / 10 is not a prefix of the full ordered result', sec;
    END IF;
    IF lall <> (SELECT array_agg(x ORDER BY x::uuid) FROM unnest(lall) x) THEN
      RAISE EXCEPTION 'P2 FAIL: % equal-score equal-start_at rows not ordered by id: %', sec, lall;
    END IF;
    RAISE NOTICE 'P2  unified_search.% "k735 tie": 5 tied rows ordered by id; limit 3 and 10 are prefixes', sec;
  END LOOP;
  RAISE NOTICE 'P2 PASS unified search tie-break deterministic for both types';
END
$p2$;

DO $end$ BEGIN RAISE NOTICE 'KAN-735 ALL PASS'; END $end$;
ROLLBACK;
\endif
