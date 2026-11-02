-- KAN-723 (KAN-714 B04, Epic KAN-708) NEARBY / FOLLOWING READ-CONVERSION PROOF.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE (either mode).
--
-- Two modes, one file:
--   -v mode=harness   COMMITS local stand-ins the chain harness does not carry: a PostGIS shim (domains
--                     geography/geometry over point + st_* functions; refuses if a real geography type exists),
--                     the columns/tables the RPC bodies read (geo_locations.location, sports.name_en/sport_key,
--                     sport_variants.name_ar, venues.name_en, profile_verifications, organiser, favorites,
--                     privacy_settings), and the three PRE-IMAGE functions created VERBATIM from the repo files
--                     (20261008140000:360-442, 20261008160000:25-104, 20261008170000:39-80) with their repo
--                     grants. The verbatim DDL is kept in public.b04_harness_preimage: it is the reference
--                     (b04_ref_*) and the ROLLBACK SQL.
--   (default) test    One transaction, ROLLBACK at the end; nothing is committed.
--
-- Build:
--   OLD  = build775.sh <db> ; psql -v mode=harness -f this
--   NEW  = OLD + 20261104100400_kan714_b04_rpc_nearby_following.sql
-- Run this file (test mode) on both:
--   NEW: every probe PASSes.  OLD (control): every [K] probe FAILs, every [=] probe PASSes.
-- Each probe: id | PASS/FAIL | expected (LIKE pattern) | actual | name.  Last line: #TOTAL|pass=N|fail=M|...
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
\if :{?mode}
\else
\set mode test
\endif
SELECT :'mode' = 'harness' AS b04_is_harness \gset

\if :b04_is_harness
-- =========================================================================================================
-- HARNESS (commits; local only)
-- =========================================================================================================
BEGIN;
DO $g$
BEGIN
  IF to_regtype('public.geography') IS NOT NULL OR EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    RAISE EXCEPTION 'B04 harness: a geography type / PostGIS exists here; this harness is for the local chain only';
  END IF;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'B04 harness: build the events chain first (build775.sh)';
  END IF;
  IF to_regclass('public.b04_harness_preimage') IS NOT NULL THEN
    RAISE EXCEPTION 'B04 harness: already applied';
  END IF;
END $g$;

-- PostGIS shim: point(lng, lat); great-circle metres (haversine, mean earth radius).
CREATE DOMAIN public.geography AS point;
CREATE DOMAIN public.geometry AS point;
CREATE FUNCTION public.st_makepoint(double precision, double precision) RETURNS point LANGUAGE sql IMMUTABLE AS $$ SELECT point($1, $2) $$;
CREATE FUNCTION public.st_setsrid(point, integer) RETURNS point LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
CREATE FUNCTION public.st_x(point) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT $1[0] $$;
CREATE FUNCTION public.st_y(point) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT $1[1] $$;
CREATE FUNCTION public.st_distance(point, point) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$
  SELECT 2 * 6371008.8 * asin(sqrt(
           power(sin(radians($2[1] - $1[1]) / 2), 2)
           + cos(radians($1[1])) * cos(radians($2[1])) * power(sin(radians($2[0] - $1[0]) / 2), 2))) $$;
CREATE FUNCTION public.st_dwithin(point, point, double precision) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT public.st_distance($1, $2) <= $3 $$;

ALTER TABLE public.geo_locations ADD COLUMN location public.geography;
UPDATE public.geo_locations SET location = point(55.2700, 25.2000) WHERE id = '00000000-0000-0000-0000-0000000000d1';
UPDATE public.geo_locations SET location = point(55.9000, 25.8000) WHERE id = '00000000-0000-0000-0000-0000000000d2';  -- ~90 km away
ALTER TABLE public.sports ADD COLUMN name_en text, ADD COLUMN sport_key text;
UPDATE public.sports SET name_en = 'Football', sport_key = 'football';
ALTER TABLE public.sport_variants ADD COLUMN name_ar text;
ALTER TABLE public.venues ADD COLUMN name_en text;
CREATE TABLE public.profile_verifications (profile_id uuid PRIMARY KEY, verified boolean NOT NULL DEFAULT false);
CREATE TABLE public.organiser (profile_id uuid, sport text, is_verified boolean, is_active boolean);
CREATE TABLE public.favorites (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid, user_id uuid);
CREATE TABLE public.privacy_settings (user_id uuid PRIMARY KEY, show_game_history boolean NOT NULL DEFAULT true);

CREATE TABLE public.b04_harness_preimage (sig text PRIMARY KEY, ref_name text NOT NULL, ddl text NOT NULL,
                                         grants text NOT NULL, acl aclitem[], prosrc_md5 text);
INSERT INTO public.b04_harness_preimage (sig, ref_name, ddl, grants) VALUES
('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'b04_ref_nearby6', $ddl$
CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text, p_max_price numeric DEFAULT NULL::numeric)
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
$ddl$, 'GRANT EXECUTE ON FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric) TO anon, authenticated, service_role'),
('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)', 'b04_ref_nearby5', $ddl$
CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
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
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me
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
    g.start_at asc
  limit 50;
$function$;
$ddl$, 'GRANT EXECUTE ON FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text) TO anon, authenticated, service_role'),
('public.rpc_games_following_joined(uuid[])', 'b04_ref_following', $ddl$
CREATE OR REPLACE FUNCTION public.rpc_games_following_joined(p_game_ids uuid[])
RETURNS TABLE(game_id uuid, following_count integer)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  with me as (
    select auth.uid() as uid
  ),
  my_following as (
    select distinct pf.following_profile_id as profile_id
    from public.profile_follows pf
    join public.profiles p on p.id = pf.follower_profile_id
    where p.user_id = (select uid from me)
  ),
  blocked as (
    select case when ub.blocker_user_id = (select uid from me)
                then ub.blocked_user_id else ub.blocker_user_id end as other_user_id
    from public.user_blocks ub
    where ub.blocker_user_id = (select uid from me)
       or ub.blocked_user_id = (select uid from me)
  ),
  visible as (
    select g.id
    from public.games g
    where (select uid from me) is not null
      and g.id = any (p_game_ids[1:200])
      and g.is_cancelled = false
      and public._can_view_game(g.id)
  )
  select gr.game_id, count(distinct gr.user_id)::int as following_count
  from public.game_roster gr
  join visible v on v.id = gr.game_id
  join my_following mf on mf.profile_id = gr.profile_id
  where gr.status = 'active'
    and gr.role in ('host', 'player', 'sub')
    and gr.user_id <> (select uid from me)
    and not exists (select 1 from blocked b where b.other_user_id = gr.user_id)
    and not exists (select 1 from public.privacy_settings ps
                    where ps.user_id = gr.user_id and ps.show_game_history = false)
  group by gr.game_id;
$function$;
$ddl$, 'ALTER FUNCTION public.rpc_games_following_joined(uuid[]) OWNER TO postgres; REVOKE ALL ON FUNCTION public.rpc_games_following_joined(uuid[]) FROM PUBLIC, anon; GRANT EXECUTE ON FUNCTION public.rpc_games_following_joined(uuid[]) TO authenticated');

DO $h$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM public.b04_harness_preimage ORDER BY sig LOOP
    EXECUTE r.ddl;
    EXECUTE r.grants;
    -- the reference twin: same text, other name, never granted to an API role
    EXECUTE replace(replace(r.ddl, 'public.rpc_get_nearby_games(', 'public.' || r.ref_name || '('),
                    'public.rpc_games_following_joined(', 'public.' || r.ref_name || '(');
    EXECUTE format('REVOKE ALL ON FUNCTION public.%I FROM PUBLIC', r.ref_name);
  END LOOP;
  UPDATE public.b04_harness_preimage h SET acl = p.proacl, prosrc_md5 = md5(p.prosrc)
    FROM pg_proc p WHERE p.oid = to_regprocedure(h.sig);
END $h$;
REVOKE ALL ON public.b04_harness_preimage FROM PUBLIC, anon, authenticated, service_role;
SELECT 'harness|' || sig || '|md5=' || prosrc_md5 FROM public.b04_harness_preimage ORDER BY sig;
COMMIT;
\quit
\endif

-- =========================================================================================================
-- TEST (one transaction, rolled back)
-- =========================================================================================================
BEGIN;
SET LOCAL lock_timeout = '3s';
DO $g$ BEGIN
  IF to_regclass('public.b04_harness_preimage') IS NULL THEN RAISE EXCEPTION 'run -v mode=harness first'; END IF;
END $g$;
SELECT 'mode|' || CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_get_nearby_games' AND prosrc LIKE '%KAN-723%')
                       THEN 'NEW (B04 applied)' ELSE 'OLD (control, no B04)' END;

CREATE TEMP SEQUENCE t_pass; CREATE TEMP SEQUENCE t_fail; CREATE TEMP SEQUENCE t_kfail; CREATE TEMP SEQUENCE t_eqfail;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expected text, p_actual text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_ok boolean := coalesce(p_actual, '<null>') LIKE p_expected;
BEGIN
  IF v_ok THEN PERFORM nextval('t_pass'); ELSE
    PERFORM nextval('t_fail');
    IF p_id LIKE '%[K]%' THEN PERFORM nextval('t_kfail'); ELSE PERFORM nextval('t_eqfail'); END IF;
  END IF;
  RETURN p_id || '|' || CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END || '|' || p_expected || '|' || coalesce(p_actual, '<null>') || '|' || p_name;
END $$;
CREATE FUNCTION pg_temp.tally(p text) RETURNS bigint LANGUAGE sql AS $$
  SELECT CASE p WHEN 'pass' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_pass)
                WHEN 'fail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_fail)
                WHEN 'kfail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_kfail)
                ELSE (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_eqfail) END $$;
-- act as a user: auth.uid() = p_uid (NULL = anon) under role p_role
CREATE FUNCTION pg_temp.as_uid(p_uid uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true) $$;
-- ordered fingerprint of an RPC call: md5 of every row (all columns) in result order, plus the row count
CREATE FUNCTION pg_temp.fp(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  EXECUTE 'SELECT count(*) || '':'' || coalesce(md5(string_agg(r::text, ''|'' ORDER BY r.ord)), ''-'') FROM (SELECT q, row_number() OVER () AS ord FROM ('
          || p_sql || ') q) r' INTO v;
  RETURN v;
END $$;
-- run an RPC both ways as a viewer and compare: 'n=<rows>|same' or 'DIFF new=.. ref=..'
CREATE FUNCTION pg_temp.cmp(p_uid uuid, p_new text, p_ref text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE a text; b text;
BEGIN
  PERFORM pg_temp.as_uid(p_uid);
  a := pg_temp.fp(p_new); b := pg_temp.fp(p_ref);
  PERFORM pg_temp.as_uid(NULL);
  RETURN CASE WHEN a = b THEN 'n=' || split_part(a, ':', 1) || '|same' ELSE 'DIFF new=' || a || ' ref=' || b END;
END $$;
CREATE FUNCTION pg_temp.ids(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  PERFORM pg_temp.as_uid(p_uid);
  EXECUTE 'SELECT coalesce(string_agg(right(id::text, 4), '','' ORDER BY ord), ''-'') FROM (SELECT q.id, row_number() OVER () AS ord FROM (' || p_sql || ') q) r' INTO v;
  PERFORM pg_temp.as_uid(NULL);
  RETURN v;
END $$;
-- data fingerprint the rollback must preserve
CREATE FUNCTION pg_temp.data_md5() RETURNS text LANGUAGE sql AS $$
  SELECT md5((SELECT string_agg(g::text, '|' ORDER BY g.id) FROM public.games g) || '#'
          || (SELECT string_agg(m::text, '|' ORDER BY m.id) FROM public.meetups m) || '#'
          || (SELECT string_agg(e::text, '|' ORDER BY e.id) FROM public.events e) || '#'
          || (SELECT coalesce(string_agg(r::text, '|' ORDER BY r::text), '') FROM public.game_roster r)) $$;
-- plan walk: one boolean per events scan node, true when it sits under a SubPlan / InitPlan (per-row re-read)
CREATE FUNCTION pg_temp.ev_nodes(n jsonb, sub boolean) RETURNS SETOF boolean LANGUAGE plpgsql AS $$
DECLARE c jsonb; s boolean;
BEGIN
  s := sub OR coalesce(n->>'Parent Relationship', '') IN ('SubPlan', 'InitPlan');
  IF n->>'Relation Name' = 'events' THEN RETURN NEXT s; END IF;
  FOR c IN SELECT * FROM jsonb_array_elements(coalesce(n->'Plans', '[]'::jsonb)) LOOP
    RETURN QUERY SELECT * FROM pg_temp.ev_nodes(c, s);
  END LOOP;
END $$;
-- EXPLAIN a function's own body (SECURITY DEFINER sql functions are not inlined into the caller's plan):
-- prosrc with its named parameters rewritten to $n, PREPAREd, EXPLAINed, DEALLOCATEd.
CREATE FUNCTION pg_temp.plan_shape(p_sig text, p_types text, p_names text[], p_args text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE src text; i int; plan jsonb; v text;
BEGIN
  SELECT prosrc INTO src FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  FOR i IN 1 .. array_length(p_names, 1) LOOP
    src := regexp_replace(src, '\m' || p_names[i] || '\M', '$' || i, 'g');
  END LOOP;
  src := regexp_replace(src, ';\s*$', '');
  EXECUTE 'PREPARE b04q(' || p_types || ') AS ' || src;
  EXECUTE 'EXPLAIN (FORMAT JSON, COSTS OFF) EXECUTE b04q(' || p_args || ')' INTO plan;
  DEALLOCATE b04q;
  SELECT 'events_nodes=' || count(*) || '|under_subplan=' || count(*) FILTER (WHERE s)
    INTO v FROM pg_temp.ev_nodes(plan->0->'Plan', false) s;
  RETURN v;
END $$;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (rolled back): 60 future public games by a2 at 6 distinct points (exceeds the RPC's LIMIT 50),
-- one NULL-titled game, roster rows, one favourite, one extra future meetup at d1.
-- Existing chain seed: a1's future games 71300..01 public, ..02 followers, ..03 private, ..04 public;
-- a5 follows a1 (b5 -> b1); a1 has blocked a6; future meetups 71300..101-105 at d1.
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO public.geo_locations (id, area_id, location)
SELECT ('72300000-0000-0000-0000-0000000000' || lpad(k::text, 2, '0'))::uuid, '00000000-0000-0000-0000-0000000000c1',
       point(55.2700 + k * 0.01, 25.2000 + k * 0.005)
  FROM generate_series(1, 6) k;
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                          sport_id, geo_location_id, area_id, price_aed, min_skill, max_skill)
SELECT ('72300000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
       CASE WHEN i = 7 THEN NULL ELSE 'B04-' || i END,
       '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2',
       '2030-01-01'::timestamptz + i * interval '7 hours',
       '2030-01-01'::timestamptz + i * interval '7 hours' + interval '90 minutes',
       10 + (i % 5), 'public', '00000000-0000-0000-0000-0000000000e1',
       ('72300000-0000-0000-0000-0000000000' || lpad((1 + i % 6)::text, 2, '0'))::uuid,
       '00000000-0000-0000-0000-0000000000c1', (i % 9) * 5 + i * 0.01, 1 + i % 3, 5 + i % 5
  FROM generate_series(1, 60) i;
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
VALUES ('72300000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'player', 'active'),
       ('72300000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'player', 'active'),
       ('72300000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'player', 'active'),
       ('71300000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'host',   'active');
INSERT INTO public.favorites (game_id, user_id) VALUES ('72300000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a3');
INSERT INTO public.meetups
SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
          'id', '72300000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'B04 meetup',
          'start_at', '2030-01-02T10:00:00+04', 'end_at', NULL))).*
  FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
CREATE TEMP TABLE fx AS SELECT pg_temp.data_md5() AS data0;

\set a1 '''00000000-0000-0000-0000-0000000000a1'''
\set a2 '''00000000-0000-0000-0000-0000000000a2'''
\set a3 '''00000000-0000-0000-0000-0000000000a3'''
\set a5 '''00000000-0000-0000-0000-0000000000a5'''
\set a6 '''00000000-0000-0000-0000-0000000000a6'''
\set N6  'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 200000, NULL::uuid, '
\set R6  'SELECT * FROM public.b04_ref_nearby6(25.2::float8, 55.27::float8, 200000, NULL::uuid, '
\set N5  'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 200000, NULL::uuid, '
\set R5  'SELECT * FROM public.b04_ref_nearby5(25.2::float8, 55.27::float8, 200000, NULL::uuid, '
\set ALLIDS '(SELECT array_agg(id) FROM public.games)'

-- ---------------------------------------------------------------------------------------------------------
-- S. Shapes and attributes
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('S1 [=]', 'result columns + types identical to the pre-image, all 3 RPCs', '3|0',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE pg_get_function_result(p.oid) <> pg_get_function_result(r.oid)
                                               OR pg_get_function_arguments(p.oid) <> pg_get_function_arguments(r.oid))
     FROM public.b04_harness_preimage h JOIN pg_proc p ON p.oid = to_regprocedure(h.sig)
     JOIN pg_proc r ON r.proname = h.ref_name AND r.pronamespace = 'public'::regnamespace));
SELECT pg_temp.chk('S2 [=]', 'owner postgres, ACL as granted by the repo, SECURITY DEFINER, search_path, STABLE: unchanged', '3|0',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE p.proacl IS DISTINCT FROM h.acl OR p.proowner <> 'postgres'::regrole
                                               OR NOT p.prosecdef OR p.proconfig::text <> '{"search_path=public, pg_temp"}' OR p.provolatile <> 's')
     FROM public.b04_harness_preimage h JOIN pg_proc p ON p.oid = to_regprocedure(h.sig)));
SELECT pg_temp.chk('S3 [=]', 'grants: anon+authenticated keep nearby (6 and 5 args); following stays authenticated-only', 'true|true|true|true|false|true',
  has_function_privilege('anon', 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'EXECUTE') || '|' ||
  has_function_privilege('anon', 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)', 'EXECUTE') || '|' ||
  has_function_privilege('anon', 'public.rpc_games_following_joined(uuid[])', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.rpc_games_following_joined(uuid[])', 'EXECUTE'));
SELECT pg_temp.chk('S4 [K]', 'every converted body joins events on the validated FK with event_type pinned', '3',
  (SELECT count(*)::text FROM public.b04_harness_preimage h JOIN pg_proc p ON p.oid = to_regprocedure(h.sig)
    WHERE p.prosrc LIKE '%join public.events e%on e.id = g.event_id and e.event_type = ''game''%'));

-- ---------------------------------------------------------------------------------------------------------
-- E. Equivalence with the pre-image while legacy and events agree (rows, order, the LIMIT-50 window)
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('E1 [=]', 'anon, sort distance: 50 rows (LIMIT window of 60+ candidates), identical rows + order', 'n=50|same',
  pg_temp.cmp(NULL, :'N6' || '''distance'', NULL)', :'R6' || '''distance'', NULL)'));
SELECT pg_temp.chk('E2 [=]', 'a1 (host), sort default (start_at): identical', 'n=50|same',
  pg_temp.cmp(:a1, :'N6' || '''default'', NULL)', :'R6' || '''default'', NULL)'));
SELECT pg_temp.chk('E3 [=]', 'a3 (stranger), sort price: identical', 'n=50|same',
  pg_temp.cmp(:a3, :'N6' || '''price'', NULL)', :'R6' || '''price'', NULL)'));
SELECT pg_temp.chk('E4 [=]', 'a5 (follower), max_price 20 filter: identical (below the limit)', 'n=%|same',
  pg_temp.cmp(:a5, :'N6' || '''distance'', 20)', :'R6' || '''distance'', 20)'));
SELECT pg_temp.chk('E5 [=]', 'a6 (blocked by a1), world radius: identical', 'n=50|same',
  pg_temp.cmp(:a6, 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 20000000, NULL::uuid, ''default'', NULL)',
                   'SELECT * FROM public.b04_ref_nearby6(25.2::float8, 55.27::float8, 20000000, NULL::uuid, ''default'', NULL)'));
SELECT pg_temp.chk('E6 [=]', 'small radius 1.5 km around d1: identical (distance window)', 'n=%|same',
  pg_temp.cmp(:a2, 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 1500, NULL::uuid, ''distance'', NULL)',
                   'SELECT * FROM public.b04_ref_nearby6(25.2::float8, 55.27::float8, 1500, NULL::uuid, ''distance'', NULL)'));
SELECT pg_temp.chk('E7 [=]', 'sport filter (sport e1): identical', 'n=50|same',
  pg_temp.cmp(:a1, 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 200000, ''00000000-0000-0000-0000-0000000000e1''::uuid, ''distance'', NULL)',
                   'SELECT * FROM public.b04_ref_nearby6(25.2::float8, 55.27::float8, 200000, ''00000000-0000-0000-0000-0000000000e1''::uuid, ''distance'', NULL)'));
-- The 5-arg overload cannot be named while the 6-arg one (all defaults) exists: a 5-argument call is
-- ambiguous (pre-existing drift, reported). To reach it, the 6-arg one is renamed inside a SAVEPOINT.
SAVEPOINT n5;
ALTER FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric) RENAME TO b04_hidden_nearby6;
SELECT pg_temp.chk('E8 [=]', '5-arg overload, a5 sort distance: identical to its pre-image', 'n=50|same',
  pg_temp.cmp(:a5, :'N5' || '''distance'')', :'R5' || '''distance'')'));
ROLLBACK TO SAVEPOINT n5;
SELECT pg_temp.chk('E9 [=]', 'following_joined, a5 over every game id: identical', 'n=%|same',
  pg_temp.cmp(:a5, 'SELECT * FROM public.rpc_games_following_joined(' || :'ALLIDS' || ') ORDER BY 1',
                   'SELECT * FROM public.b04_ref_following(' || :'ALLIDS' || ') ORDER BY 1'));
SELECT pg_temp.chk('E10 [=]', 'following_joined: a5 sees a1 counted in 3 games (01,02 as player; 71300..01 host)', '0001:1,0001:1,0002:1',
  (SELECT string_agg(right(game_id::text, 4) || ':' || following_count, ',' ORDER BY game_id::text)
     FROM (SELECT pg_temp.as_uid(:a5)) s, public.rpc_games_following_joined((SELECT array_agg(id) FROM public.games)) f));
SELECT pg_temp.as_uid(NULL);
SELECT pg_temp.chk('E11 [=]', 'NULL title kept as the legacy literal; nulls not invented', 'Untitled Game',
  (SELECT title FROM public.rpc_get_nearby_games(25.2, 55.27, 200000, NULL, 'default', NULL) WHERE id = '72300000-0000-0000-0000-000000000007'));

-- ---------------------------------------------------------------------------------------------------------
-- D. No doubling, no meetups, private-access parity (absolute values, not only equality with the pre-image)
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('D1 [=]', 'world radius, a1: rows = distinct ids (no doubling)', '50|50',
  (SELECT count(*) || '|' || count(DISTINCT id) FROM (SELECT pg_temp.as_uid(:a1)) s,
          public.rpc_get_nearby_games(25.2, 55.27, 20000000, NULL, 'default', NULL)));
SELECT pg_temp.chk('D2 [=]', 'no meetup id is ever returned (5 seeded + 1 inserted future meetups at d1)', '0',
  (SELECT count(*)::text FROM (SELECT pg_temp.as_uid(:a1)) s, public.rpc_get_nearby_games(25.2, 55.27, 20000000, NULL, 'distance', NULL) r
    WHERE r.id IN (SELECT id FROM public.meetups)));
SELECT pg_temp.chk('D3 [=]', 'a1 game set by viewer (01 public, 02 followers, 03 private, 04 public): anon|a3|a5|a6|a1', '0001,0004|0001,0004|0001,0002,0004|-|0001,0002,0003,0004',
  (SELECT string_agg(v, '|' ORDER BY k) FROM (VALUES
     (1, pg_temp.ids(NULL, 'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%''')),
     (2, pg_temp.ids(:a3,  'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%''')),
     (3, pg_temp.ids(:a5,  'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%''')),
     (4, pg_temp.ids(:a6,  'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%''')),
     (5, pg_temp.ids(:a1,  'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%'''))) t(k, v)));
SELECT pg_temp.chk('D4 [=]', 'following_joined: anon gets nothing; a3 (no follows) gets nothing; a6 not counted for a1 games', '0|0|0',
  (SELECT (SELECT count(*) FROM (SELECT pg_temp.as_uid(NULL)) s, public.rpc_games_following_joined((SELECT array_agg(id) FROM public.games))) || '|' ||
          (SELECT count(*) FROM (SELECT pg_temp.as_uid(:a3)) s, public.rpc_games_following_joined((SELECT array_agg(id) FROM public.games))) || '|' ||
          (SELECT count(*) FROM (SELECT pg_temp.as_uid(:a6)) s, public.rpc_games_following_joined(ARRAY['71300000-0000-0000-0000-000000000001'::uuid]))));
SELECT pg_temp.as_uid(NULL);

-- ---------------------------------------------------------------------------------------------------------
-- K. Source of truth = events. Each divergence is made with the mirror/guard triggers off
--    (session_replication_role = replica) inside a SAVEPOINT, so events and the legacy row disagree, then undone.
-- ---------------------------------------------------------------------------------------------------------
SAVEPOINT k1;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET title = 'EV-TITLE', start_at = '2029-12-31T09:00:00+04', end_at = '2029-12-31T11:00:00+04',
                         capacity = 3, min_skill = 9, max_skill = 10, joining_rule = 'paid', cost_cover = 'paid'
 WHERE id = '72300000-0000-0000-0000-000000000005';
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K0 [=]', 'divergence established: legacy row still has its own values', 'B04-5|10',
  (SELECT title || '|' || capacity FROM public.games WHERE id = '72300000-0000-0000-0000-000000000005'));
SELECT pg_temp.chk('K1 [K]', 'title, scheduled_at, end_at, skills, joining_rule, cost_cover follow events', 'EV-TITLE|2029-12-31 09:00:00+04|2029-12-31 11:00:00+04|9|10|paid|paid',
  (SELECT title || '|' || scheduled_at || '|' || end_at || '|' || min_skill || '|' || max_skill || '|' || joining_rule || '|' || cost_cover
     FROM public.rpc_get_nearby_games(25.2, 55.27, 200000, NULL, 'default', NULL) WHERE id = '72300000-0000-0000-0000-000000000005'));
SELECT pg_temp.chk('K2 [K]', 'spots_remaining from events.capacity (3, roster 0)', '3',
  (SELECT spots_remaining::text FROM public.rpc_get_nearby_games(25.2, 55.27, 200000, NULL, 'default', NULL) WHERE id = '72300000-0000-0000-0000-000000000005'));
SELECT pg_temp.chk('K3 [K]', 'the RPC''s own ORDER BY uses events.start_at (0005 moved before every other game: first row)', '0005',
  split_part(pg_temp.ids(NULL, 'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 200000, NULL, ''default'', NULL)'), ',', 1));
-- The 5-arg overload cannot be named while the 6-arg one (all defaults) exists: a 5-argument call is
-- ambiguous (pre-existing drift, reported). To reach it, the 6-arg one is renamed inside a SAVEPOINT.
SAVEPOINT n5k;
ALTER FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric) RENAME TO b04_hidden_nearby6;
SELECT pg_temp.chk('K4 [K]', '5-arg overload: title follows events', 'EV-TITLE',
  (SELECT title FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 200000, NULL::uuid, 'default'::text) WHERE id = '72300000-0000-0000-0000-000000000005'));
ROLLBACK TO SAVEPOINT n5k;
ROLLBACK TO SAVEPOINT k1;

SAVEPOINT k2;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET is_cancelled = true WHERE id IN ('72300000-0000-0000-0000-000000000001', '71300000-0000-0000-0000-000000000001');
UPDATE public.events SET geo_location_id = '00000000-0000-0000-0000-0000000000d2' WHERE id = '72300000-0000-0000-0000-000000000002';
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K5 [K]', 'events.is_cancelled hides the game (legacy still says not cancelled)', '0',
  (SELECT count(*)::text FROM public.rpc_get_nearby_games(25.2, 55.27, 20000000, NULL, 'default', NULL) WHERE id = '72300000-0000-0000-0000-000000000001'));
SELECT pg_temp.chk('K6 [K]', 'radius uses events.geo_location_id (moved ~90 km out of a 10 km radius)', '0',
  (SELECT count(*)::text FROM public.rpc_get_nearby_games(25.2, 55.27, 10000, NULL, 'default', NULL) WHERE id = '72300000-0000-0000-0000-000000000002'));
SELECT pg_temp.chk('K7 [K]', 'following_joined: events-cancelled games are dropped (a5 keeps only 0002)', '0002:1',
  (SELECT coalesce(string_agg(right(game_id::text, 4) || ':' || following_count, ',' ORDER BY game_id::text), '-')
     FROM (SELECT pg_temp.as_uid(:a5)) s, public.rpc_games_following_joined((SELECT array_agg(id) FROM public.games)) f));
SELECT pg_temp.as_uid(NULL);
ROLLBACK TO SAVEPOINT k2;

SAVEPOINT k3;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET listing_visibility = 'private' WHERE id = '71300000-0000-0000-0000-000000000001';  -- narrower on events
UPDATE public.events SET listing_visibility = 'public'  WHERE id = '71300000-0000-0000-0000-000000000003';  -- wider on events
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K8 [K]', 'visibility narrowed on events is honoured: stranger a3 loses 0001 (legacy still public)', '0004',
  pg_temp.ids(:a3, 'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%'''));
SELECT pg_temp.chk('K9 [=]', 'never widen: events public + legacy private stays hidden from a3 and anon (0003 absent)', '0|0',
  (SELECT count(*) FILTER (WHERE v LIKE '%0003%') || '|' || 0 FROM (VALUES
     (pg_temp.ids(:a3,  'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%''')),
     (pg_temp.ids(NULL, 'SELECT id FROM public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, ''default'', NULL) WHERE id::text LIKE ''71300000%'''))) t(v)));
SELECT pg_temp.chk('K10 [K]', 'host a1 still sees 0001 (private on events), and is_public reports the events value', 'false',
  (SELECT is_public::text FROM (SELECT pg_temp.as_uid(:a1)) s, public.rpc_get_nearby_games(25.2, 55.27, 1000, NULL, 'default', NULL) WHERE id = '71300000-0000-0000-0000-000000000001'));
SELECT pg_temp.as_uid(NULL);
ROLLBACK TO SAVEPOINT k3;

SAVEPOINT k4;
INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a3');
SELECT pg_temp.chk('K11 [=]', 'block guard kept: a2 blocks a3 -> a3 sees none of a2''s 60 games; equal to the pre-image', '0|n=%|same',
  (SELECT count(*) FROM (SELECT pg_temp.as_uid(:a3)) s, public.rpc_get_nearby_games(25.2, 55.27, 20000000, NULL, 'default', NULL) r
    WHERE r.id::text LIKE '72300000%') || '|' ||
  pg_temp.cmp(:a3, 'SELECT * FROM public.rpc_get_nearby_games(25.2::float8, 55.27::float8, 20000000, NULL::uuid, ''default'', NULL)',
                   'SELECT * FROM public.b04_ref_nearby6(25.2::float8, 55.27::float8, 20000000, NULL::uuid, ''default'', NULL)'));
SELECT pg_temp.as_uid(NULL);
ROLLBACK TO SAVEPOINT k4;

-- ---------------------------------------------------------------------------------------------------------
-- N. No N+1: events is read by exactly one plan node, a join, never a per-row SubPlan / InitPlan
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('N1 [K]', 'nearby (6 args) plan: one events node, not under a SubPlan', 'events_nodes=1|under_subplan=0',
  pg_temp.plan_shape('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)',
                     'double precision, double precision, integer, uuid, text, numeric',
                     ARRAY['p_lat', 'p_lng', 'p_radius_meters', 'p_sport_id', 'p_sort', 'p_max_price'],
                     '25.2, 55.27, 200000, NULL, ''distance'', NULL'));
SELECT pg_temp.chk('N2 [K]', 'nearby (5 args) plan: one events node, not under a SubPlan', 'events_nodes=1|under_subplan=0',
  pg_temp.plan_shape('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)',
                     'double precision, double precision, integer, uuid, text',
                     ARRAY['p_lat', 'p_lng', 'p_radius_meters', 'p_sport_id', 'p_sort'],
                     '25.2, 55.27, 200000, NULL, ''distance'''));
SELECT pg_temp.chk('N3 [K]', 'following_joined plan: one events node, not under a SubPlan', 'events_nodes=1|under_subplan=0',
  pg_temp.plan_shape('public.rpc_games_following_joined(uuid[])', 'uuid[]', ARRAY['p_game_ids'],
                     (SELECT quote_literal(array_agg(id)::text) || '::uuid[]' FROM public.games)));

-- ---------------------------------------------------------------------------------------------------------
-- R. Rollback: re-run the verbatim pre-image DDL (the rollback SQL), in a SAVEPOINT
-- ---------------------------------------------------------------------------------------------------------
SAVEPOINT r;
CREATE TEMP TABLE fx_r AS SELECT pg_temp.data_md5() AS before_rb;
DO $rb$ DECLARE r record; BEGIN
  FOR r IN SELECT * FROM public.b04_harness_preimage ORDER BY sig LOOP EXECUTE r.ddl; END LOOP;
END $rb$;
SELECT pg_temp.chk('R1 [=]', 'after rollback every body md5 equals the pinned pre-image', '3',
  (SELECT count(*)::text FROM public.b04_harness_preimage h JOIN pg_proc p ON p.oid = to_regprocedure(h.sig) WHERE md5(p.prosrc) = h.prosrc_md5));
SELECT pg_temp.chk('R2 [=]', 'after rollback owner + ACL + attributes unchanged', '0',
  (SELECT count(*)::text FROM public.b04_harness_preimage h JOIN pg_proc p ON p.oid = to_regprocedure(h.sig)
    WHERE p.proacl IS DISTINCT FROM h.acl OR p.proowner <> 'postgres'::regrole OR NOT p.prosecdef));
SELECT pg_temp.chk('R3 [=]', 'rollback is data-neutral (games, meetups, events, roster fingerprint)', 'true',
  (SELECT (pg_temp.data_md5() = before_rb)::text FROM fx_r));
SELECT pg_temp.chk('R4 [=]', 'after rollback output equals the pre-image', 'n=50|same',
  pg_temp.cmp(:a1, :'N6' || '''distance'', NULL)', :'R6' || '''distance'', NULL)'));
ROLLBACK TO SAVEPOINT r;

SELECT pg_temp.chk('Z1 [=]', 'data fingerprint at the end equals the one after seeding (probes changed nothing)', 'true',
  (SELECT (pg_temp.data_md5() = data0)::text FROM fx));

SELECT '#TOTAL|pass=' || pg_temp.tally('pass') || '|fail=' || pg_temp.tally('fail')
       || '|K_fail=' || pg_temp.tally('kfail') || '|eq_fail=' || pg_temp.tally('eqfail');
ROLLBACK;
