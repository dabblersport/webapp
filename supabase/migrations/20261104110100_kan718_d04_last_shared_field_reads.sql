-- KAN-772 (KAN-718 D04, Epic KAN-708): the last legacy shared-field READS named by D01 (B15 open rows) now come
-- from public.events.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan718_d04_last_reads.sql (D-checks); disposition of all 34 B15 open
-- functions: supabase/tests/events_p4/KAN718_D04_DISPOSITION.md. Rollback: supabase/tests/events_p4/kan718_d04_rollback.sql.
--
-- No DROP, no table/column/grant/policy change, no row written, no write path changed. Eight function bodies are
-- replaced in place (CREATE OR REPLACE, same signature, so owner and ACL are kept; asserted in section 3):
--
--   function                         field(s) now read from events                     SECURITY  pre-image
--   _user_hosted_game(uuid,uuid)     creator_user_id                                   INVOKER   local chain (baseline:1455-ish, unchanged since)
--   _recent_activity_score(uuid,int) start_at                                          INVOKER   baseline 20260829080500:1493-1510
--   game_is_joinable(uuid)           is_cancelled, start_at                            INVOKER   baseline :6812-6824
--   get_games_needing_players()      sport_id, area_id, capacity, is_cancelled, start_at DEFINER  baseline :7164-7201
--   get_open_games_for_seeding()     sport_id, area_id, capacity, is_cancelled, start_at DEFINER  baseline :7617-7662
--   meetup_counts(uuid)              creator_user_id, listing_visibility               DEFINER   20260915120000:104 (+ :781-782 grants)
--   rpc_create_game(26 args)         creator_user_id, request_id (idempotency lookups)  DEFINER   20261021120200 (delegator)
--   rpc_create_meetup(21 args)       creator_user_id, request_id (idempotency lookups)  DEFINER   20261021120300 (delegator)
--
-- Each reads its parent as `public.events e ON e.id = <subtype>.event_id AND e.event_type = '<type>'` (INNER:
-- event_id is NOT NULL + FK-validated since the KAN-712 cutover, events.id is the PK, so the join neither drops
-- nor doubles a row; the type filter keeps a parent of the other type out). Subtype-only fields stay on the
-- subtype (games.id, game_roster, meetup_rsvps). Return types, OUT/JSON key names, ORDER BY, LIMIT and NULL
-- behaviour (game_is_joinable returns NULL for an unknown game) are the pre-image's.
--
-- Visibility / authority: events-only, as KAN-721 B02 did for v_meetup_counts (can_view_owner(e.creator_user_id,
-- e.listing_visibility)). Section 0 refuses unless no game or meetup differs from its events parent on any field
-- this file starts reading, so applying it cannot change a single result; afterwards events is the only source
-- (KAN-712: events is the write target, the legacy columns are its mirror).
--
-- INVOKER functions (_user_hosted_game, _recent_activity_score, game_is_joinable) are granted to PUBLIC/anon/
-- authenticated, and public.events is FORCE RLS with no client grant (KAN-710). They therefore follow KAN-727 B08's
-- game_slots_left pattern: has_table_privilege('public.events','SELECT') selects the events read for callers that
-- may read events (SECURITY DEFINER callers such as rpc_rate_venue -> _user_hosted_game, service_role) and the
-- pre-image read otherwise, so a direct client call never starts raising 42501. That needs per-call planning, so
-- the three move from LANGUAGE sql to plpgsql (a SQL function with SET search_path is never inlined, so no plan
-- is lost). Volatility, owner, ACL, SECURITY and search_path are kept and asserted. The client fallback branch is
-- retired with the legacy columns (KAN-719 Z01), exactly as B08's.
--
-- KAN-712 INTERACTION: rpc_create_game / rpc_create_meetup are the ALLOWLISTED delegators of the KAN-712 contract
-- (supabase/tests/events_p2/KAN712_CONTRACT.md rows 12 and 15). Only their two request_id lookups change; the
-- INSERT still happens inside rpc_create_*_legacy_v2 through the KAN-712 guard (events first), the unique_violation
-- handler still keys on the legacy constraint NAME that the guard re-raises, and no write is added (no dual write).
-- None of the eight is on the KAN-712 wrap list (kan712_wrapped_rpcs); section 0 refuses if one has been wrapped.
--
-- T-058 SUBSTITUTE (as KAN-713/KAN-727): production is not read here. Section 0 pins md5(prosrc), SECURITY,
-- volatility and search_path of each pre-image as authored from the local catalogue (pg_get_functiondef) and the
-- repository; any drift fails closed -- re-author from pg_get_functiondef on the live catalogue in that case.

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
    raise exception 'KAN-772 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-772 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_zz_kan712_events_compat_mirror' and tgenabled <> 'D') then
    raise exception 'KAN-772 pre: KAN-712 cutover not live (compat mirror trigger on events missing or disabled)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w
        where w.name in ('_user_hosted_game', '_recent_activity_score', 'game_is_joinable', 'get_games_needing_players',
                         'get_open_games_for_seeding', 'meetup_counts', 'rpc_create_game', 'rpc_create_meetup')) then
    raise exception 'KAN-772 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY DEFINER | volatility | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public._user_hosted_game(uuid,uuid)',            'dc84da3e337f875afecad11c80bf6e2e', false, 's'),
      ('public._recent_activity_score(uuid,integer)',    'ab433ed36ceb91e748ddabb252505d14', false, 's'),
      ('public.game_is_joinable(uuid)',                  '186286ad1e096c062296d0bc1b2f5890', false, 's'),
      ('public.get_games_needing_players()',             '2938404e665ffa0ce504826bfd55b146', true,  'v'),
      ('public.get_open_games_for_seeding()',            '261911f5b095b992ce3b463818ecf99f', true,  'v'),
      ('public.meetup_counts(uuid)',                     'ec29fe4c662d0c6fbe1117a5d01a7652', true,  'v'),
      ('public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
                                                         'aa4876c674fafe5d0f6984b29b4f1938', true,  'v'),
      ('public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
                                                         'ef0d41b5e1717e966e5dad1ae3445903', true,  'v')
    ) t(f, src, secdef, vol)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or p.prosecdef <> t.secdef or p.provolatile <> t.vol
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-772 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Every subtype row has exactly its typed parent (KAN-712 cutover invariant).
  select (select count(*) from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null)
       + (select count(*) from public.meetups m left join public.events e on e.id = m.event_id and e.event_type = 'meetup' where e.id is null)
    into v_n;
  if v_n <> 0 then
    raise exception 'KAN-772 pre: % game/meetup row(s) without their typed events parent', v_n;
  end if;

  -- No value this file starts reading from events may differ from the legacy mirror.
  select (select count(*) from public.games g join public.events e on e.id = g.event_id
           where (g.creator_user_id, g.request_id, g.start_at, g.is_cancelled, g.capacity, g.sport_id, g.area_id)
                 is distinct from (e.creator_user_id, e.request_id, e.start_at, e.is_cancelled, e.capacity, e.sport_id, e.area_id))
       + (select count(*) from public.meetups m join public.events e on e.id = m.event_id
           where (m.creator_user_id, m.request_id, m.listing_visibility)
                 is distinct from (e.creator_user_id, e.request_id, e.listing_visibility))
    into v_n;
  if v_n <> 0 then
    raise exception 'KAN-772 pre: % game/meetup row(s) differ from events on a field this migration starts reading; reconcile first (KAN-711 parity)', v_n;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image attributes (asserted unchanged in section 3).
-- ---------------------------------------------------------------------------------------------------------
create temp table kan772_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as res, p.prosecdef, p.provolatile, p.proconfig, p.proacl, p.proowner,
       p.proretset, p.proisstrict, p.proparallel
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname in ('_user_hosted_game', '_recent_activity_score', 'game_is_joinable', 'get_games_needing_players',
                     'get_open_games_for_seeding', 'meetup_counts', 'rpc_create_game', 'rpc_create_meetup');

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacements.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._user_hosted_game(p_user_id uuid, p_game_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: creator from events for callers that may read events (rpc_rate_venue, SECURITY DEFINER);
-- pre-image read otherwise (INVOKER, granted to clients; events has no client grant -- KAN-727 pattern).
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    RETURN EXISTS (
      SELECT 1 FROM public.games g
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE g.id = p_game_id
         AND e.creator_user_id = p_user_id);
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.games g
     WHERE g.id = p_game_id
       AND g.creator_user_id = p_user_id);
END
$function$;

CREATE OR REPLACE FUNCTION public._recent_activity_score(u uuid, p_recent_days integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: start_at from events for callers that may read events; pre-image read otherwise (INVOKER).
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    IF EXISTS (
      SELECT 1
        FROM public.game_roster gr
        JOIN public.games g ON g.id = gr.game_id
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE gr.user_id = u
         AND gr.status = 'active'
         AND e.start_at >= now() - (p_recent_days || ' days')::interval) THEN
      RETURN 1.0;
    END IF;
    RETURN 0.0;
  END IF;
  IF EXISTS (
    SELECT 1
      FROM public.game_roster gr
      JOIN public.games g ON g.id = gr.game_id
     WHERE gr.user_id = u
       AND gr.status = 'active'
       AND g.start_at >= now() - (p_recent_days || ' days')::interval) THEN
    RETURN 1.0;
  END IF;
  RETURN 0.0;
END
$function$;

CREATE OR REPLACE FUNCTION public.game_is_joinable(p_game uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: cancel state and start from events for callers that may read events; pre-image read otherwise
-- (INVOKER). An unknown game returns NULL, as the pre-image's one-row SQL select did.
DECLARE
  v boolean;
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    SELECT NOT e.is_cancelled AND e.start_at > now() INTO v
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE g.id = p_game;
  ELSE
    SELECT NOT g.is_cancelled AND g.start_at > now() INTO v
      FROM public.games g
     WHERE g.id = p_game;
  END IF;
  RETURN v;
END
$function$;

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

CREATE OR REPLACE FUNCTION public.meetup_counts(p_meetup_id uuid)
 RETURNS TABLE(going integer, interested integer, declined integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-772: visibility gate from events (as KAN-721 B02's v_meetup_counts).
  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  left join public.meetup_rsvps r on r.meetup_id = m.id
  where m.id = p_meetup_id
    and public.can_view_owner(e.creator_user_id, e.listing_visibility)
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
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
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
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
$function$
;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
begin
  -- Same oid (replaced in place), signature, result, SECURITY, volatility, search_path, ACL, owner, set-returning,
  -- strictness and parallel safety as the pre-image.
  select string_agg(k.fn, ', ') into v_bad
    from kan772_pre k
    left join pg_proc p on p.oid = k.oid
   where p.oid is null
      or (pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
          p.proconfig, p.proacl, p.proowner, p.proretset, p.proisstrict, p.proparallel)
         is distinct from (k.args, k.res, k.prosecdef, k.provolatile, k.proconfig, k.proacl, k.proowner, k.proretset,
          k.proisstrict, k.proparallel);
  if v_bad is not null then
    raise exception 'KAN-772 post: attributes changed for %', v_bad;
  end if;
  if (select count(*) from kan772_pre) <> 8 then
    raise exception 'KAN-772 post: expected 8 replaced functions, found %', (select count(*) from kan772_pre);
  end if;

  -- Every body reads public.events by the subtype's event_id.
  select string_agg(k.fn, ', ') into v_bad
    from kan772_pre k join pg_proc p on p.oid = k.oid
   where regexp_replace(p.prosrc, '--[^\n]*', '', 'g') !~* 'public\.events e\s+on e\.id = [gm]\.event_id and e\.event_type = ''(game|meetup)''';
  if v_bad is not null then
    raise exception 'KAN-772 post: no events join in %', v_bad;
  end if;

  -- The five SECURITY DEFINER bodies read no legacy shared column any more (the three INVOKER bodies keep the
  -- pre-image read only in their no-events-privilege branch, by design -- see the header).
  select string_agg(k.fn, ', ') into v_bad
    from kan772_pre k join pg_proc p on p.oid = k.oid
   where k.prosecdef
     and regexp_replace(p.prosrc, '--[^\n]*', '', 'g')
         ~* '\m[gm]\.(creator_user_id|creator_profile_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|request_id|sport_id|area_id|geo_location_id|venue_id|rsvp_policy)\M';
  if v_bad is not null then
    raise exception 'KAN-772 post: legacy shared-column read left in %', v_bad;
  end if;
end
$post$;

commit;
