-- KAN-823 (supports KAN-794; KAN-718 D04, Epic KAN-708): the KAN-772 D04 behaviour for the four functions whose
-- production body differs from the one KAN-772 was authored against, re-authored on PRODUCTION'S LIVE BODIES.
--
-- AUTHORED, NOT APPLIED. needs-ops: applied by the applying seat under KAN-837 (G-002, after PEER review,
-- schema_change). Release order: step 25 of the KAN-811 CTO ruling (Jira KAN-811 comment 15381), after step 24
-- (kan713 location triggers). Local proof: supabase/tests/events_p4/kan794_d04_live_bodies_test.sql.
--
-- WHY A NEW FILE. 20261104110100_kan718_d04_last_shared_field_reads.sql (KAN-772) pins rpc_create_game /
-- rpc_create_meetup at the four-file delegator bodies (aa4876c6 / ef0d41b5). Production runs the KAN-611
-- request_id bodies instead (KAN-794 snapshot, comment 15264, taken 2026-11-03T20:25:55Z), so that file fails
-- closed there on 'pre-image drift' by design. This file does not edit it; it gives the four functions below the
-- same KAN-772 behaviour starting from the bodies production actually runs:
--
--   function                       production pre-image (md5(prosrc))   provenance of the body re-authored here
--   get_games_needing_players()    2938404e665ffa0ce504826bfd55b146     baseline 20260829080500:7164-7201 (= KAN-772's pre-image)
--   get_open_games_for_seeding()   261911f5b095b992ce3b463818ecf99f     baseline 20260829080500:7617-7662 (= KAN-772's pre-image)
--   rpc_create_game(26 args)       0b8161fa591617ba5d2d825d2cc8da14     20261021120000_kan611_request_id_idempotency.sql:84-106 (commit 6b478186)
--   rpc_create_meetup(21 args)     713db51a8eb86e2243cbc5f9d5864604     20261021120000_kan611_request_id_idempotency.sql:119-141 (commit 6b478186)
--
-- The rpc_create_* md5s above were recomputed from the repository text and equal the production snapshot byte
-- for byte; that is the only reason a live body could be re-authored without reading production (T-058).
--
-- WHAT CHANGES. get_*: the KAN-772 bodies verbatim -- shared fields (sport_id, area_id, capacity, is_cancelled,
-- start_at) from the typed events parent; JSON keys, filters, ORDER BY and LIMIT unchanged. rpc_create_*: ONLY
-- the request_id replay lookup moves to events (creator_profile_id, request_id -- the key of the events unique
-- index events_type_creator_request_id_key). Everything else of the live body is kept as it is: the
-- choose_actor() ownership re-assert, the per-(profile, request_id) advisory lock, IF FOUND, the
-- thebes.create_request_id hand-off to the KAN-712 guard, no exception handler, and the NULL request_id
-- delegation. No write is added (no dual write); the INSERT still happens inside rpc_create_*_legacy_v2 through
-- the KAN-712 guard (events first).
--
-- No DROP, no table/column/grant/policy change, no row written. Four bodies are replaced in place (CREATE OR
-- REPLACE, same signature, so oid, owner and ACL are kept; asserted in section 3). No other function is touched
-- -- the other four KAN-772 functions (_user_hosted_game, _recent_activity_score, game_is_joinable, meetup_counts)
-- are not in this file.
--
-- X2 -- KAN-792 PART 2 (20261105110000_kan714_events_parent_reads_2.sql, release step 30). Part 2 pins these four
-- functions at their pre-KAN-772 md5s and CREATE OR REPLACEs them. After this file it therefore fails closed on
-- drift, which is correct: part 2 must be re-authored ON THESE BODIES (re-pin to the md5s section 3 leaves) and
-- must never re-introduce the pre-KAN-772 bodies of these four functions. The last body applied wins.
--
-- Section 0 refuses unless no game or meetup differs from its events parent on any field this file starts
-- reading, so applying it cannot change a single result; afterwards events is the only source for them.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_n bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-823 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-823 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_zz_kan712_events_compat_mirror' and tgenabled <> 'D') then
    raise exception 'KAN-823 pre: KAN-712 cutover not live (compat mirror trigger on events missing or disabled)';
  end if;
  if to_regclass('public.events_type_creator_request_id_key') is null then
    raise exception 'KAN-823 pre: events_type_creator_request_id_key missing (the replay lookup keys on it)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w
        where w.name in ('get_games_needing_players', 'get_open_games_for_seeding', 'rpc_create_game', 'rpc_create_meetup')) then
    raise exception 'KAN-823 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins (production snapshot, KAN-794 comment 15264): md5(prosrc) | SECURITY DEFINER | volatility | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.get_games_needing_players()',             '2938404e665ffa0ce504826bfd55b146', true, 'v'),
      ('public.get_open_games_for_seeding()',            '261911f5b095b992ce3b463818ecf99f', true, 'v'),
      ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
                                                         '0b8161fa591617ba5d2d825d2cc8da14', true, 'v'),
      ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
                                                         '713db51a8eb86e2243cbc5f9d5864604', true, 'v')
    ) t(f, src, secdef, vol)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or p.prosecdef <> t.secdef or p.provolatile <> t.vol
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-823 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Every subtype row has exactly its typed parent (KAN-712 cutover invariant).
  select (select count(*) from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null)
       + (select count(*) from public.meetups m left join public.events e on e.id = m.event_id and e.event_type = 'meetup' where e.id is null)
    into v_n;
  if v_n <> 0 then
    raise exception 'KAN-823 pre: % game/meetup row(s) without their typed events parent', v_n;
  end if;

  -- No value this file starts reading from events may differ from the legacy mirror.
  select (select count(*) from public.games g join public.events e on e.id = g.event_id
           where (g.creator_profile_id, g.request_id, g.start_at, g.is_cancelled, g.capacity, g.sport_id, g.area_id)
                 is distinct from (e.creator_profile_id, e.request_id, e.start_at, e.is_cancelled, e.capacity, e.sport_id, e.area_id))
       + (select count(*) from public.meetups m join public.events e on e.id = m.event_id
           where (m.creator_profile_id, m.request_id)
                 is distinct from (e.creator_profile_id, e.request_id))
    into v_n;
  if v_n <> 0 then
    raise exception 'KAN-823 pre: % game/meetup row(s) differ from events on a field this migration starts reading; reconcile first (KAN-711 parity)', v_n;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image attributes (asserted unchanged in section 3).
-- ---------------------------------------------------------------------------------------------------------
create temp table kan823_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_arguments(p.oid) as args_full, pg_get_function_result(p.oid) as res, p.prosecdef,
       p.provolatile, p.proconfig, p.proacl, p.proowner, p.proretset, p.proisstrict, p.proparallel, p.prolang
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname in ('get_games_needing_players', 'get_open_games_for_seeding', 'rpc_create_game', 'rpc_create_meetup');

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacements.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_games_needing_players()
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

CREATE OR REPLACE FUNCTION public.get_open_games_for_seeding()
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
  SELECT g.id INTO gid FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.creator_profile_id = pid AND e.request_id = p_request_id;  -- KAN-823: creator + request_id from events (KAN-772 D04)
  IF FOUND THEN RETURN gid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$
;

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
  SELECT m.id INTO mid FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.creator_profile_id = pid AND e.request_id = p_request_id;  -- KAN-823: creator + request_id from events (KAN-772 D04)
  IF FOUND THEN RETURN mid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$
;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
begin
  if (select count(*) from kan823_pre) <> 4 then
    raise exception 'KAN-823 post: expected 4 replaced functions, found %', (select count(*) from kan823_pre);
  end if;

  -- Same oid (replaced in place), signature incl. defaults, result, SECURITY, volatility, search_path, ACL, owner,
  -- set-returning, strictness, parallel safety and language as the pre-image.
  select string_agg(k.fn, ', ') into v_bad
    from kan823_pre k
    left join pg_proc p on p.oid = k.oid
   where p.oid is null
      or (pg_get_function_identity_arguments(p.oid), pg_get_function_arguments(p.oid), pg_get_function_result(p.oid),
          p.prosecdef, p.provolatile, p.proconfig, p.proacl, p.proowner, p.proretset, p.proisstrict, p.proparallel, p.prolang)
         is distinct from (k.args, k.args_full, k.res, k.prosecdef, k.provolatile, k.proconfig, k.proacl, k.proowner,
          k.proretset, k.proisstrict, k.proparallel, k.prolang);
  if v_bad is not null then
    raise exception 'KAN-823 post: attributes changed for %', v_bad;
  end if;

  -- The bodies this file leaves (X2: KAN-792 part 2 re-pins to exactly these).
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc), 'absent') || ')', '; ') into v_bad
    from (values
      ('public.get_games_needing_players()',  'c818c2082bf1a29e40202776869ad42b'),
      ('public.get_open_games_for_seeding()', '30333cbe1d77a6a5ca5b1e757e3e945f'),
      ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
                                              '5b8883b2ab8b55f8d2119c6fbd023dcc'),
      ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
                                              '0f5ba02e7123f095436350842f229dae')
    ) t(f, src)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src;
  if v_bad is not null then
    raise exception 'KAN-823 post: replacement body is not the reviewed one: %', v_bad;
  end if;

  -- Every body reads public.events by the subtype's event_id.
  select string_agg(k.fn, ', ') into v_bad
    from kan823_pre k join pg_proc p on p.oid = k.oid
   where regexp_replace(p.prosrc, '--[^\n]*', '', 'g') !~* 'public\.events e\s+on e\.id = [gm]\.event_id and e\.event_type = ''(game|meetup)''';
  if v_bad is not null then
    raise exception 'KAN-823 post: no events join in %', v_bad;
  end if;

  -- No legacy shared-column read left in any of the four (all SECURITY DEFINER).
  select string_agg(k.fn, ', ') into v_bad
    from kan823_pre k join pg_proc p on p.oid = k.oid
   where regexp_replace(p.prosrc, '--[^\n]*', '', 'g')
         ~* '\m[gm]\.(creator_user_id|creator_profile_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|request_id|sport_id|area_id|geo_location_id|venue_id|rsvp_policy)\M';
  if v_bad is not null then
    raise exception 'KAN-823 post: legacy shared-column read left in %', v_bad;
  end if;
end
$post$;

commit;
