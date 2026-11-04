-- KAN-823 (supports KAN-794; KAN-718 D04): proof for 20261105120000_kan794_d04_on_live_bodies.sql -- the KAN-772 D04
-- behaviour re-authored on PRODUCTION'S LIVE BODIES of get_games_needing_players, get_open_games_for_seeding,
-- rpc_create_game and rpc_create_meetup.
--
-- LOCAL DISPOSABLE DATABASE ONLY. The guard refuses any database whose name does not start with 'k772' or 'k794',
-- anything that looks like Supabase, and a non-superuser. Never point this at a hosted project.
--
-- Chain: the KAN-772 local chain (base772.sh <supabase dir> <db> full) + local_harness_kan772.sql. In that chain
-- rpc_create_* are the four-file delegators, so section P installs the PRODUCTION pre-image itself (the KAN-611
-- request_id bodies verbatim, commit 6b478186, and the baseline get_* bodies) with the PRODUCTION ACLs, and pins
-- it to the KAN-794 production snapshot (comment 15264): md5(prosrc), md5(pg_get_functiondef), ACL, SECURITY,
-- volatility, search_path, owner. The file is therefore re-runnable on the same database.
--
-- What it proves:
--   P   the local pre-image is byte-identical to production (prosrc and functiondef md5) with production's ACL.
--   REF the KAN-772 bodies (20261104110100 lines 220-394) are installed verbatim in scratch schema k794_ref
--       (md5(prosrc) pinned to the KAN-772 file) as the behavioural reference.
--   L*  BEFORE the migration the live bodies read the legacy columns (the checks below can fail).
--   M   the migration applies (its own section 0 / section 3 guards run).
--   G*/S*/C*/E*  AFTER: each new body returns what the KAN-772 body returns on the same inputs, including
--       when the events parent is diverged from its legacy mirror (session_replication_role=replica inside a
--       rolled-back sub-transaction) -- the new body FOLLOWS events. rpc_create_*: replay served from events
--       request_id, a non-creator never served, a fresh request creates once and its replay returns the same id,
--       NULL request_id delegates.
--   X   signature, identity, defaults, result, ACL, SECURITY, volatility, search_path and owner equal the
--       production snapshot (C2); the new bodies are neither the production pre-image nor KAN-792 part 2's pins
--       (X2: a rebased part 2 cannot silently re-introduce the pre-KAN-772 bodies).
--   R   every scenario rolled back: games / meetups / events / game_roster / profiles / areas md5 unchanged.
-- Run:  psql -X -h <socket> -p <port> -U postgres -d k772<...> -v ON_ERROR_STOP=1 -f kan794_d04_live_bodies_test.sql
-- Exit: 0 with 'KAN-823 PASS <function>' for each of the four functions and 'KAN-823 TOTAL pass=N fail=0';
-- any failed check raises 'KAN-823 test FAILED'.
\set ON_ERROR_STOP 1
SET client_min_messages = warning;

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k772%' AND current_database() NOT LIKE 'k794%' THEN
    RAISE EXCEPTION 'KAN-823: refusing database %: local disposable k772*/k794* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-823: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-823: run as a superuser (session_replication_role and RLS-free counts need it)';
  END IF;
END $g$;

DROP TABLE IF EXISTS pg_temp.k823_r, pg_temp.k823_snap, pg_temp.k823_live;
CREATE TEMP TABLE k823_r(fn text, id text, ok boolean, want text, got text);
-- Production snapshot, KAN-794 comment 15264 (2026-11-03T20:25:55Z).
CREATE TEMP TABLE k823_snap(fn text, sig text, src_md5 text, def_md5 text, acl text);
INSERT INTO k823_snap VALUES
 ('get_games_needing_players',  'public.get_games_needing_players()',  '2938404e665ffa0ce504826bfd55b146', '3c4d8d44a6ac1c567518b3bec402d5c8',
  '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
 ('get_open_games_for_seeding', 'public.get_open_games_for_seeding()', '261911f5b095b992ce3b463818ecf99f', 'f150e8bd62b9389ce2e61d54f8a192dd',
  '{=X/postgres,postgres=X/postgres,service_role=X/postgres}'),
 ('rpc_create_game', 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
  '0b8161fa591617ba5d2d825d2cc8da14', '8f232cccd892171935764fb3d05bf73f', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
 ('rpc_create_meetup', 'public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
  '713db51a8eb86e2243cbc5f9d5864604', '8f62f07131bc7477d5b2435f99f09948', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}');
CREATE TEMP TABLE k823_live(k text PRIMARY KEY, v text);

-- ---------------------------------------------------------------------------------------------
-- P  production pre-image (verbatim bodies, production ACLs)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_games_needing_players()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT
      g.id                                      AS game_id,
      g.sport_id,
      g.area_id,
      g.capacity,
      s.sport_key,
      a.city,
      COUNT(gr.profile_id)                      AS current_players,
      g.capacity - COUNT(gr.profile_id)         AS spots_remaining,
      -- get all profile_ids already in this game as array
      ARRAY_AGG(gr.profile_id) FILTER (WHERE gr.profile_id IS NOT NULL) AS existing_profiles
    FROM public.games g
    JOIN public.sports s       ON s.id = g.sport_id
    JOIN public.areas a        ON a.id = g.area_id
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id AND gr.status = 'active'
    WHERE g.is_cancelled = false
      AND g.start_at > now()
    GROUP BY g.id, g.sport_id, g.area_id, g.capacity, s.sport_key, a.city
    HAVING g.capacity - COUNT(gr.profile_id) > 0
    ORDER BY spots_remaining DESC
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_open_games_for_seeding()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT DISTINCT ON (g.id)
      g.id                    AS game_id,
      g.sport_id,
      g.area_id,
      g.capacity,
      g.start_at,
      s.sport_key,
      a.city,
      p.id                    AS profile_id,
      p.user_id,
      p.display_name
    FROM public.games g
    JOIN public.sports s       ON s.id = g.sport_id
    JOIN public.areas a        ON a.id = g.area_id
    JOIN public.profiles p     ON p.city = a.city
                               AND p.primary_sport = g.sport_id
                               AND p.is_original = false
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id
                               AND gr.profile_id = p.id
    WHERE g.is_cancelled = false
      AND g.start_at > now()
      AND gr.profile_id IS NULL
      AND (
        SELECT COUNT(*) FROM public.game_roster
        WHERE game_id = g.id AND status = 'active'
      ) < g.capacity
    ORDER BY g.id, random()
    LIMIT 10
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; gid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- choose_actor re-asserts the caller owns the acting profile; a replay is only ever served to the creator.
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_game:' || pid::text || ':' || p_request_id::text, 0));
  SELECT g.id INTO gid FROM public.games g WHERE g.creator_profile_id = pid AND g.request_id = p_request_id;
  IF FOUND THEN RETURN gid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; mid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_meetup:' || pid::text || ':' || p_request_id::text, 0));
  SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_profile_id = pid AND m.request_id = p_request_id;
  IF FOUND THEN RETURN mid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

ALTER FUNCTION public.get_games_needing_players() OWNER TO postgres;
ALTER FUNCTION public.get_open_games_for_seeding() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_games_needing_players() TO PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_open_games_for_seeding() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_open_games_for_seeding() TO PUBLIC, service_role;
REVOKE ALL ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) TO authenticated, service_role;

INSERT INTO k823_r
SELECT s.fn, 'P  pre-image = production snapshot (prosrc, functiondef, ACL, DEFINER, volatile, search_path, owner)',
       p.oid IS NOT NULL AND md5(p.prosrc) = s.src_md5 AND md5(pg_get_functiondef(p.oid)) = s.def_md5 AND p.proacl::text = s.acl
         AND p.prosecdef AND p.provolatile = 'v' AND p.proconfig = array['search_path=public, pg_temp'] AND p.proowner = 'postgres'::regrole,
       left(s.src_md5, 8) || '/' || left(s.def_md5, 8) || ' ' || s.acl,
       CASE WHEN p.oid IS NULL THEN 'absent' ELSE left(md5(p.prosrc), 8) || '/' || left(md5(pg_get_functiondef(p.oid)), 8) || ' ' || p.proacl::text
         || CASE WHEN p.prosecdef AND p.provolatile = 'v' AND p.proconfig = array['search_path=public, pg_temp'] AND p.proowner = 'postgres'::regrole
                 THEN '' ELSE ' (attrs differ)' END END
FROM k823_snap s LEFT JOIN pg_proc p ON p.oid = to_regprocedure(s.sig);

-- ---------------------------------------------------------------------------------------------
-- REF  the KAN-772 bodies, verbatim, in a scratch schema (dropped at the end; plain DROP, no CASCADE)
-- ---------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS k794_ref;
CREATE OR REPLACE FUNCTION k794_ref.get_games_needing_players()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: shared fields from events (same JSON keys, same filters and order).
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT
      g.id                                      AS game_id,
      e.sport_id,
      e.area_id,
      e.capacity,
      s.sport_key,
      a.city,
      COUNT(gr.profile_id)                      AS current_players,
      e.capacity - COUNT(gr.profile_id)         AS spots_remaining,
      -- get all profile_ids already in this game as array
      ARRAY_AGG(gr.profile_id) FILTER (WHERE gr.profile_id IS NOT NULL) AS existing_profiles
    FROM public.games g
    JOIN public.events e       ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.sports s       ON s.id = e.sport_id
    JOIN public.areas a        ON a.id = e.area_id
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id AND gr.status = 'active'
    WHERE e.is_cancelled = false
      AND e.start_at > now()
    GROUP BY g.id, e.sport_id, e.area_id, e.capacity, s.sport_key, a.city
    HAVING e.capacity - COUNT(gr.profile_id) > 0
    ORDER BY spots_remaining DESC
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION k794_ref.get_open_games_for_seeding()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: shared fields from events (same JSON keys, same filters, order and limit).
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO result
  FROM (
    SELECT DISTINCT ON (g.id)
      g.id                    AS game_id,
      e.sport_id,
      e.area_id,
      e.capacity,
      e.start_at,
      s.sport_key,
      a.city,
      p.id                    AS profile_id,
      p.user_id,
      p.display_name
    FROM public.games g
    JOIN public.events e       ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.sports s       ON s.id = e.sport_id
    JOIN public.areas a        ON a.id = e.area_id
    JOIN public.profiles p     ON p.city = a.city
                               AND p.primary_sport = e.sport_id
                               AND p.is_original = false
    LEFT JOIN public.game_roster gr
                               ON gr.game_id = g.id
                               AND gr.profile_id = p.id
    WHERE e.is_cancelled = false
      AND e.start_at > now()
      AND gr.profile_id IS NULL
      AND (
        SELECT COUNT(*) FROM public.game_roster
        WHERE game_id = g.id AND status = 'active'
      ) < e.capacity
    ORDER BY g.id, random()
    LIMIT 10
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION k794_ref.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; gid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT g.id INTO gid FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.creator_user_id = v_uid AND e.request_id = p_request_id;  -- KAN-772: creator + request_id from events
    IF gid IS NOT NULL THEN RETURN gid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'games_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT g.id INTO gid FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.creator_user_id = v_uid AND e.request_id = p_request_id;  -- KAN-772: creator + request_id from events
    IF gid IS NULL THEN RAISE; END IF;
    RETURN gid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION k794_ref.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; mid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT m.id INTO mid FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.creator_user_id = v_uid AND e.request_id = p_request_id;  -- KAN-772: creator + request_id from events
    IF mid IS NOT NULL THEN RETURN mid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'meetups_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT m.id INTO mid FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.creator_user_id = v_uid AND e.request_id = p_request_id;  -- KAN-772: creator + request_id from events
    IF mid IS NULL THEN RAISE; END IF;
    RETURN mid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

INSERT INTO k823_r
SELECT v.fn, 'REF k794_ref body = KAN-772 20261104110100 body (md5(prosrc))', md5(p.prosrc) IS NOT DISTINCT FROM v.src, v.src, coalesce(md5(p.prosrc), 'absent')
FROM (VALUES
  ('get_games_needing_players',  'k794_ref.get_games_needing_players()',  'c818c2082bf1a29e40202776869ad42b'),
  ('get_open_games_for_seeding', 'k794_ref.get_open_games_for_seeding()', '30333cbe1d77a6a5ca5b1e757e3e945f'),
  ('rpc_create_game', 'k794_ref.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
   'e565a2ba82469724f878435a2f8aaeae'),
  ('rpc_create_meetup', 'k794_ref.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
   '77a14a223d4ad16d2f62db46a8ddbcb9')
) v(fn, f, src)
LEFT JOIN pg_proc p ON p.oid = to_regprocedure(v.f);

-- Normalised views of the two jsonb readers (array order made explicit -- the outer array by game_id and the
-- unordered array_agg existing_profiles sorted, both plan-dependent in old and new bodies alike; only the seeded
-- game for seeding, whose single candidate profile makes DISTINCT ON ... random() deterministic).
CREATE OR REPLACE FUNCTION pg_temp.k823_norm(j jsonb) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT coalesce(jsonb_agg(CASE WHEN jsonb_typeof(e->'existing_profiles') = 'array'
                                  THEN jsonb_set(e, '{existing_profiles}', (SELECT coalesce(jsonb_agg(x ORDER BY x::text), '[]'::jsonb)
                                                                            FROM jsonb_array_elements(e->'existing_profiles') x))
                                  ELSE e END ORDER BY e->>'game_id'), '[]'::jsonb)::text
   FROM jsonb_array_elements(j) e $$;
CREATE OR REPLACE FUNCTION pg_temp.k823_seed(j jsonb, g uuid) RETURNS text LANGUAGE sql IMMUTABLE AS
$$ SELECT coalesce(jsonb_agg(e ORDER BY e::text), '[]'::jsonb)::text FROM jsonb_array_elements(j) e WHERE e->>'game_id' = g::text $$;

-- Fingerprints before any scenario.
CREATE TEMP TABLE k823_fp AS
SELECT concat_ws(' ',
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_roster t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.profiles t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.areas t), 8)) fp;

-- The seed (one game, one meetup, legacy INSERT path through the KAN-712 guard; ids 82300000-*), used by both
-- scenario blocks. Owner O = user a1 / profile b1; V = user a5 / profile b5.
CREATE OR REPLACE FUNCTION pg_temp.k823_seed_rows() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                            join_policy, sport_id, geo_location_id, area_id)
  VALUES ('82300000-0000-0000-0000-000000000001', 'K823 game legacy', '00000000-0000-0000-0000-0000000000b1',
          '00000000-0000-0000-0000-0000000000a1', '2031-02-01 18:00+00', '2031-02-01 19:00+00', 10, 'public', 'open',
          '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(src) || jsonb_build_object(
      'id', '82300000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'K823 meetup legacy',
      'creator_profile_id', '00000000-0000-0000-0000-0000000000b1', 'creator_user_id', '00000000-0000-0000-0000-0000000000a1',
      'start_at', '2031-02-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public',
      'created_at', now(), 'updated_at', now()))).*
    FROM public.meetups src WHERE src.id = '71300000-0000-0000-0000-000000000101';
  -- A seeding candidate only the EVENTS area can produce: area c9 (city K823City) on events, c1 on legacy.
  INSERT INTO public.areas (id, name, city) VALUES ('82300000-0000-0000-0000-0000000000c9', 'K823 area', 'K823City');
  UPDATE public.profiles SET city = 'K823City', primary_sport = '00000000-0000-0000-0000-0000000000e1', is_original = false
   WHERE id = '00000000-0000-0000-0000-0000000000b5';
END $$;

-- ---------------------------------------------------------------------------------------------
-- L  BEFORE the migration: the production bodies read the legacy columns (so the AFTER checks can fail)
-- ---------------------------------------------------------------------------------------------
DO $l$
DECLARE
  O uuid := '00000000-0000-0000-0000-0000000000a1';
  G uuid := '82300000-0000-0000-0000-000000000001';
  M uuid := '82300000-0000-0000-0000-00000000f001';
  R2 uuid := '82300000-0000-0000-0000-0000000000e2';
  res jsonb := '[]'; got text; ret uuid; live_gnp text;
BEGIN
  BEGIN
    PERFORM pg_temp.k823_seed_rows();
    -- the undiverged outputs, kept for the AFTER comparison (same seed, same values)
    live_gnp := pg_temp.k823_norm(public.get_games_needing_players());

    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET capacity = 7 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT 'cap=' || coalesce(max(j->>'capacity'), 'absent') INTO got
        FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_games_needing_players', 'id', 'L1 live body ignores events capacity (reads legacy)', 'want', 'cap=10', 'got', got);

    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET area_id = '82300000-0000-0000-0000-0000000000c9' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT 'b5_candidate=' || count(*) FILTER (WHERE j->>'profile_id' = '00000000-0000-0000-0000-0000000000b5') INTO got
        FROM jsonb_array_elements(public.get_open_games_for_seeding()) j WHERE j->>'game_id' = G::text;
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_open_games_for_seeding', 'id', 'L2 live body ignores events area (reads legacy)', 'want', 'b5_candidate=0', 'got', got);

    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id IN (G, M);
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      BEGIN
        ret := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN ret := NULL; END;
      got := 'game_served_seed=' || coalesce((ret = G)::text, 'false');
      BEGIN
        ret := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823', p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN ret := NULL; END;
      got := got || ' meetup_served_seed=' || coalesce((ret = M)::text, 'false');
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_game', 'id', 'L3 live bodies ignore events request_id (read legacy)', 'want', 'game_served_seed=false meetup_served_seed=false', 'got', got);

    RAISE EXCEPTION 'k823_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k823_undo' THEN
      res := res || jsonb_build_object('fn', 'scenario', 'id', 'L  aborted', 'want', 'no error', 'got', 'ERR ' || SQLSTATE || ' ' || SQLERRM);
    END IF;
  END;
  INSERT INTO k823_live VALUES ('gnp', live_gnp);
  INSERT INTO k823_r SELECT r->>'fn', r->>'id', (r->>'got') IS NOT DISTINCT FROM (r->>'want'), r->>'want', r->>'got' FROM jsonb_array_elements(res) r;
END $l$;

-- Attributes of the pre-image incl. defaults (asserted unchanged in X).
CREATE TEMP TABLE k823_pre AS
SELECT s.fn, p.oid, pg_get_function_arguments(p.oid) AS args_full FROM k823_snap s JOIN pg_proc p ON p.oid = to_regprocedure(s.sig);

-- ---------------------------------------------------------------------------------------------
-- M  the migration (its own transaction, section 0 and section 3 guards)
-- ---------------------------------------------------------------------------------------------
\ir ../../migrations/20261105120000_kan794_d04_on_live_bodies.sql
INSERT INTO k823_r VALUES ('migration', 'M  20261105120000 applied (section 0 + section 3 passed)', true, 'applied', 'applied');

-- ---------------------------------------------------------------------------------------------
-- AFTER: new body (public) vs KAN-772 body (k794_ref) on the same inputs
-- ---------------------------------------------------------------------------------------------
DO $a$
DECLARE
  O uuid := '00000000-0000-0000-0000-0000000000a1';
  VU uuid := '00000000-0000-0000-0000-0000000000a5';
  G uuid := '82300000-0000-0000-0000-000000000001';
  M uuid := '82300000-0000-0000-0000-00000000f001';
  R2 uuid := '82300000-0000-0000-0000-0000000000e2';   -- a request_id written to events only
  R3 uuid := '82300000-0000-0000-0000-0000000000e3';   -- a fresh request_id
  res jsonb := '[]'; got text; want text; a uuid; b uuid; ng bigint; nm bigint; x text; y text;
BEGIN
  BEGIN
    PERFORM pg_temp.k823_seed_rows();

    -- G1 undiverged: new = KAN-772 = production output
    got := format('new=ref:%s new=live:%s', pg_temp.k823_norm(public.get_games_needing_players()) = pg_temp.k823_norm(k794_ref.get_games_needing_players()),
                  pg_temp.k823_norm(public.get_games_needing_players()) = (SELECT v FROM k823_live WHERE k = 'gnp'));
    res := res || jsonb_build_object('fn', 'get_games_needing_players', 'id', 'G1 same output as KAN-772 and as the production body (undiverged)', 'want', 'new=ref:t new=live:t', 'got', got);

    -- G2 events capacity diverged: new = KAN-772, and both follow events
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET capacity = 7 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT format('new=ref:%s cap=%s spots=%s legacy=%s',
                    pg_temp.k823_norm(public.get_games_needing_players()) = pg_temp.k823_norm(k794_ref.get_games_needing_players()),
                    max(j->>'capacity'), max(j->>'spots_remaining'), (SELECT capacity FROM public.games WHERE id = G))
        INTO got FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_games_needing_players', 'id', 'G2 follows events capacity, as KAN-772', 'want', 'new=ref:t cap=7 spots=7 legacy=10', 'got', got);

    -- G3 events cancelled
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      SELECT format('new=ref:%s present=%s legacy_cancelled=%s',
                    pg_temp.k823_norm(public.get_games_needing_players()) = pg_temp.k823_norm(k794_ref.get_games_needing_players()),
                    count(*), (SELECT is_cancelled FROM public.games WHERE id = G))
        INTO got FROM jsonb_array_elements(public.get_games_needing_players()) j WHERE j->>'game_id' = G::text;
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_games_needing_players', 'id', 'G3 follows events is_cancelled, as KAN-772', 'want', 'new=ref:t present=0 legacy_cancelled=f', 'got', got);

    -- S1 events area diverged to the K823City area: the b5 candidate appears, exactly as for KAN-772
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET area_id = '82300000-0000-0000-0000-0000000000c9' WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      x := pg_temp.k823_seed(public.get_open_games_for_seeding(), G);
      y := pg_temp.k823_seed(k794_ref.get_open_games_for_seeding(), G);
      SELECT format('new=ref:%s present=%s profile=%s city=%s keys=%s', x = y, count(*), max(j->>'profile_id'), max(j->>'city'),
                    (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(min(j::text)::jsonb) k))
        INTO got FROM jsonb_array_elements(x::jsonb) j;
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_open_games_for_seeding', 'id', 'S1 follows events area_id (city), as KAN-772; keys unchanged', 'got', got,
      'want', 'new=ref:t present=1 profile=00000000-0000-0000-0000-0000000000b5 city=K823City keys=area_id,capacity,city,display_name,game_id,profile_id,sport_id,sport_key,start_at,user_id');

    -- S2 ... and events cancellation removes it
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET area_id = '82300000-0000-0000-0000-0000000000c9', is_cancelled = true WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      x := pg_temp.k823_seed(public.get_open_games_for_seeding(), G);
      y := pg_temp.k823_seed(k794_ref.get_open_games_for_seeding(), G);
      got := format('new=ref:%s new=%s', x = y, x);
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_open_games_for_seeding', 'id', 'S2 follows events is_cancelled, as KAN-772', 'want', 'new=ref:t new=[]', 'got', got);

    -- S3 events capacity full (2 of 2 active) removes it, as KAN-772
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET area_id = '82300000-0000-0000-0000-0000000000c9', capacity = 2 WHERE id = G;
      INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
      VALUES (G, '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active'),
             (G, '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'player', 'active');
      PERFORM set_config('session_replication_role', 'origin', true);
      x := pg_temp.k823_seed(public.get_open_games_for_seeding(), G);
      y := pg_temp.k823_seed(k794_ref.get_open_games_for_seeding(), G);
      got := format('new=ref:%s new=%s legacy_cap=%s', x = y, x, (SELECT capacity FROM public.games WHERE id = G));
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'get_open_games_for_seeding', 'id', 'S3 follows events capacity, as KAN-772', 'want', 'new=ref:t new=[] legacy_cap=10', 'got', got);

    -- C1 rpc_create_game replay keyed on events request_id (legacy NULL): creator served the seed, nothing created
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT count(*) INTO ng FROM public.games;
      a := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R2);
      b := k794_ref.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R2);
      got := format('legacy_req=%s new_seed=%s ref_seed=%s games_delta=%s', coalesce((SELECT request_id::text FROM public.games WHERE id = G), 'null'),
                    a = G, b = G, (SELECT count(*) FROM public.games) - ng);
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_game', 'id', 'C1 replay served from events request_id, as KAN-772; nothing created', 'want', 'legacy_req=null new_seed=t ref_seed=t games_delta=0', 'got', got);

    -- C2 a non-creator replaying the same request_id is never served the seed (new and KAN-772)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = G;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', VU::text, true);
      BEGIN a := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN a := NULL; END;
      BEGIN b := k794_ref.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN b := NULL; END;
      got := format('new_seed=%s ref_seed=%s', coalesce((a = G)::text, 'false'), coalesce((b = G)::text, 'false'));
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_game', 'id', 'C2 non-creator never served, as KAN-772', 'want', 'new_seed=false ref_seed=false', 'got', got);

    -- C3 a fresh request creates exactly one game and every replay (new or KAN-772 body) returns it
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT count(*) INTO ng FROM public.games;
      a := public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
             p_title => 'K823 create', p_start_at => '2031-05-01 18:00+00', p_end_at => '2031-05-01 19:00+00',
             p_geo_location_id => '00000000-0000-0000-0000-0000000000d1', p_area_id => '00000000-0000-0000-0000-0000000000c1', p_max_players => 10, p_request_id => R3);
      b := k794_ref.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
             p_title => 'K823 create', p_start_at => '2031-05-01 18:00+00', p_end_at => '2031-05-01 19:00+00',
             p_geo_location_id => '00000000-0000-0000-0000-0000000000d1', p_area_id => '00000000-0000-0000-0000-0000000000c1', p_max_players => 10, p_request_id => R3);
      got := format('created=%s ref_replay_same=%s new_replay_same=%s games_delta=%s events_req=%s', a IS NOT NULL, b = a,
                    public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_request_id => R3) = a,
                    (SELECT count(*) FROM public.games) - ng, (SELECT count(*) FROM public.events WHERE id = a AND request_id = R3 AND creator_profile_id = '00000000-0000-0000-0000-0000000000b1'));
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_game', 'id', 'C3 fresh request creates once; replays return it (new and KAN-772)', 'want', 'created=t ref_replay_same=t new_replay_same=t games_delta=1 events_req=1', 'got', got);

    -- C4 NULL request_id delegates in both (same outcome: same validation error from legacy_v2)
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      BEGIN PERFORM public.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL); x := 'ok';
      EXCEPTION WHEN OTHERS THEN x := SQLSTATE || ' ' || SQLERRM; END;
      BEGIN PERFORM k794_ref.rpc_create_game(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL); y := 'ok';
      EXCEPTION WHEN OTHERS THEN y := SQLSTATE || ' ' || SQLERRM; END;
      got := format('same=%s new=%s', x = y, x);
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_game', 'id', 'C4 NULL request_id delegates to legacy_v2, as KAN-772', 'want', 'same=t new=P0001 invalid_time_range', 'got', got);

    -- E1 rpc_create_meetup replay keyed on events request_id; non-creator never served (new and KAN-772)
    BEGIN
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET request_id = R2 WHERE id = M;
      PERFORM set_config('session_replication_role', 'origin', true);
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT count(*) INTO nm FROM public.meetups;
      a := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823 replay', p_request_id => R2);
      b := k794_ref.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823 replay', p_request_id => R2);
      got := format('legacy_req=%s new_seed=%s ref_seed=%s meetups_delta=%s', coalesce((SELECT request_id::text FROM public.meetups WHERE id = M), 'null'),
                    a = M, b = M, (SELECT count(*) FROM public.meetups) - nm);
      PERFORM set_config('request.jwt.claim.sub', VU::text, true);
      BEGIN a := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823 replay', p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN a := NULL; END;
      BEGIN b := k794_ref.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823 replay', p_request_id => R2);
      EXCEPTION WHEN OTHERS THEN b := NULL; END;
      got := got || format(' other_new_seed=%s other_ref_seed=%s', coalesce((a = M)::text, 'false'), coalesce((b = M)::text, 'false'));
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_meetup', 'id', 'E1 replay served from events request_id; non-creator never, as KAN-772', 'got', got,
      'want', 'legacy_req=null new_seed=t ref_seed=t meetups_delta=0 other_new_seed=false other_ref_seed=false');

    -- E2 a fresh request creates exactly one meetup and every replay returns it
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT count(*) INTO nm FROM public.meetups;
      a := public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
             p_title => 'K823 meetup', p_start_at => '2031-05-02 18:00+00', p_area_id => '00000000-0000-0000-0000-0000000000c1', p_request_id => R3);
      b := k794_ref.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
             p_title => 'K823 meetup', p_start_at => '2031-05-02 18:00+00', p_area_id => '00000000-0000-0000-0000-0000000000c1', p_request_id => R3);
      got := format('created=%s ref_replay_same=%s new_replay_same=%s meetups_delta=%s events_req=%s', a IS NOT NULL, b = a,
                    public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL, p_title => 'K823 meetup', p_request_id => R3) = a,
                    (SELECT count(*) FROM public.meetups) - nm, (SELECT count(*) FROM public.events WHERE id = a AND request_id = R3 AND creator_profile_id = '00000000-0000-0000-0000-0000000000b1'));
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_meetup', 'id', 'E2 fresh request creates once; replays return it (new and KAN-772)', 'want', 'created=t ref_replay_same=t new_replay_same=t meetups_delta=1 events_req=1', 'got', got);

    -- E3 NULL request_id delegates in both
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', O::text, true);
      SELECT count(*) INTO nm FROM public.meetups;
      BEGIN PERFORM public.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
              p_title => 'K823 null req', p_start_at => '2031-05-03 18:00+00', p_area_id => '00000000-0000-0000-0000-0000000000c1'); x := 'ok';
      EXCEPTION WHEN OTHERS THEN x := SQLSTATE || ' ' || SQLERRM; END;
      BEGIN PERFORM k794_ref.rpc_create_meetup(p_actor_type => 'player', p_sport_id => '00000000-0000-0000-0000-0000000000e1', p_sport_variant_id => NULL,
              p_title => 'K823 null req', p_start_at => '2031-05-03 18:00+00', p_area_id => '00000000-0000-0000-0000-0000000000c1'); y := 'ok';
      EXCEPTION WHEN OTHERS THEN y := SQLSTATE || ' ' || SQLERRM; END;
      got := format('new=%s ref=%s meetups_delta=%s', x, y, (SELECT count(*) FROM public.meetups) - nm);
      RAISE EXCEPTION 'k823_undo';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'k823_undo' THEN got := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF; END;
    res := res || jsonb_build_object('fn', 'rpc_create_meetup', 'id', 'E3 NULL request_id delegates (no replay key), as KAN-772', 'want', 'new=ok ref=ok meetups_delta=2', 'got', got);

    RAISE EXCEPTION 'k823_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k823_undo' THEN
      res := res || jsonb_build_object('fn', 'scenario', 'id', 'A  aborted', 'want', 'no error', 'got', 'ERR ' || SQLSTATE || ' ' || SQLERRM);
    END IF;
  END;
  INSERT INTO k823_r SELECT r->>'fn', r->>'id', (r->>'got') IS NOT DISTINCT FROM (r->>'want'), r->>'want', r->>'got' FROM jsonb_array_elements(res) r;
END $a$;

-- ---------------------------------------------------------------------------------------------
-- X  C2: signature / grants / return shape identical to the production snapshot; X2 pins
-- ---------------------------------------------------------------------------------------------
INSERT INTO k823_r
SELECT s.fn, 'X1 same oid, signature, defaults, result, ACL, DEFINER, volatile, search_path, owner as production',
       p.oid = k.oid AND pg_get_function_arguments(p.oid) = k.args_full AND p.proacl::text = s.acl
         AND pg_get_function_result(p.oid) = CASE WHEN s.fn LIKE 'get_%' THEN 'jsonb' ELSE 'uuid' END
         AND p.prosecdef AND p.provolatile = 'v' AND p.proconfig = array['search_path=public, pg_temp'] AND p.proowner = 'postgres'::regrole,
       s.acl, coalesce(p.proacl::text, 'absent') || CASE WHEN p.oid = k.oid AND pg_get_function_arguments(p.oid) = k.args_full THEN '' ELSE ' (oid/args differ)' END
FROM k823_snap s JOIN k823_pre k ON k.fn = s.fn LEFT JOIN pg_proc p ON p.oid = to_regprocedure(s.sig);

INSERT INTO k823_r
SELECT s.fn, 'X2 new body is neither the production pre-image nor a KAN-792 part 2 pin',
       md5(p.prosrc) <> s.src_md5 AND left(md5(p.prosrc), 8) NOT IN ('2938404e', '261911f5', 'aa4876c6', 'ef0d41b5'),
       'not ' || left(s.src_md5, 8) || ' and not a part-2 pin', left(md5(p.prosrc), 8)
FROM k823_snap s JOIN pg_proc p ON p.oid = to_regprocedure(s.sig);

INSERT INTO k823_r
SELECT 'scenario', 'R  every scenario rolled back (games/meetups/events/roster/profiles/areas md5)', f.fp = n.fp, f.fp, n.fp
FROM k823_fp f, (SELECT concat_ws(' ',
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.games t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.meetups t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t.id), '')) FROM public.events t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.game_roster t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.profiles t), 8),
  left((SELECT md5(coalesce(string_agg(t::text, '|' ORDER BY t::text), '')) FROM public.areas t), 8)) fp) n;

-- scratch reference removed (plain DROP, no CASCADE)
DROP FUNCTION k794_ref.get_games_needing_players();
DROP FUNCTION k794_ref.get_open_games_for_seeding();
DROP FUNCTION k794_ref.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid);
DROP FUNCTION k794_ref.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid);
DROP SCHEMA k794_ref;

SET client_min_messages = notice;
DO $t$
DECLARE r record; p int := 0; f int := 0;
BEGIN
  FOR r IN SELECT * FROM k823_r ORDER BY fn, id LOOP
    IF r.ok THEN p := p + 1; RAISE NOTICE 'KAN-823 ok   [%] %: %', r.fn, r.id, r.got;
    ELSE f := f + 1; RAISE NOTICE 'KAN-823 FAIL [%] %: want=[%] got=[%]', r.fn, r.id, r.want, r.got; END IF;
  END LOOP;
  -- per function: PASS only if every check of that function passed and the shared checks passed
  FOR r IN SELECT s.fn, bool_and(k.ok) AND (SELECT bool_and(ok) FROM k823_r WHERE fn IN ('migration', 'scenario')) AS ok, count(*) AS n
             FROM k823_snap s JOIN k823_r k ON k.fn = s.fn GROUP BY s.fn ORDER BY s.fn LOOP
    RAISE NOTICE 'KAN-823 % % (% checks)', CASE WHEN r.ok THEN 'PASS' ELSE 'FAIL' END, r.fn, r.n;
  END LOOP;
  RAISE NOTICE 'KAN-823 TOTAL pass=% fail=%', p, f;
  IF f > 0 THEN RAISE EXCEPTION 'KAN-823 test FAILED (% of % checks)', f, p + f; END IF;
END $t$;
