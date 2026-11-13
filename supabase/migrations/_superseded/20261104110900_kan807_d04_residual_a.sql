-- KAN-807 (supporting KAN-778 / KAN-719, a KAN-781 finding): D04 residual, part (a). These SECURITY DEFINER
-- functions still read games / meetups columns that KAN-719 Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql)
-- drops, so after Z01 they raise 42703. Each body stops reading those columns and reads them from public.events
-- (games.event_id / meetups.event_id -> events.id), which every body here already joins.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan807_d04_residual_test.sql (throwaway PG16, KAN-781 judge chain + D04).
-- Part (b) is the other file of this ticket; the two are independent and may be applied in either order.
--
--   function                                                                                     removed read
--   public._can_view_game(uuid)                                                                  g.creator_user_id, g.listing_visibility (games half of the KAN-713 intersection removed; events half kept)
--   public._is_game_host(uuid)                                                                   g.creator_user_id (games half removed; e.creator_user_id kept)
--   public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)            g.is_cancelled, g.creator_user_id, m.is_cancelled, m.creator_user_id, m.listing_visibility (games/meetups halves removed; the e.* halves and kan713_meetup_visible kept)
--   public.rpc_get_activity_feed(text, integer, timestamp with time zone)                        g.is_cancelled (removed; e.is_cancelled kept)
--   public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text, numeric) g.listing_visibility, g.creator_user_id (games visibility block removed; events block kept)
--   public.rpc_rate_game(uuid, uuid, jsonb, text)                                                g0.is_cancelled -> e.is_cancelled
--
-- WHY THE RESULT IS UNCHANGED. Every removed read was one half of a KAN-713/723/727/731 intersection (or union, for
-- the rating cancel flag) whose other half already reads the same field from events. Section 0 refuses unless the
-- removed columns equal their events counterparts on every row (KAN-711 parity, D09), so dropping the games/meetups
-- half selects exactly the same rows. No other byte of any body changes (bodies authored from pg_get_functiondef).
--
-- WHO CAN CALL. All of these are SECURITY DEFINER owned by postgres; they already read FORCE-RLS public.events as
-- their owner today, for anon and authenticated callers alike. No SECURITY INVOKER function is touched, so no API
-- caller gains a new events read (the KAN-803 42501 trap does not arise).
--
-- Replaced in place (CREATE OR REPLACE, same signature, same return type): SECURITY, volatility, search_path, owner
-- and ACL are kept and asserted in section 2. No table, column, policy, trigger, grant or row is touched.
--
-- T-058 SUBSTITUTE (as KAN-772 / KAN-799 / KAN-803): production is not read here. Section 0 pins md5(prosrc) of each
-- pre-image; any drift fails closed -- re-author from pg_get_functiondef on the live catalogue then. Section 2 pins
-- md5(prosrc) of each new body.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  r record;
  v_n bigint;
  c record;
  v_attr jsonb;
begin
  if to_regclass('public.events') is null then
    raise exception 'KAN-807 pre: public.events missing (KAN-710 not applied)';
  end if;
  for r in select * from (values
    ('public._can_view_game(uuid)', '7ee01526ff64e59691ada52fa77474ce', '4ff7a7eebc30f157066f93e7b38e35d3'),
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text, numeric)', 'b96323a71f8726e0ce6ab8ccc1a1dc69', '3a27dca7144c61e9615f25517ba814c9'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42')) k(fn, pre_md5, post_md5) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'KAN-807 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pre_md5 then
      raise exception 'KAN-807 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pre_md5;
    end if;
    if not (select prosecdef from pg_proc where oid = to_regprocedure(r.fn)) then
      raise exception 'KAN-807 pre: % is no longer SECURITY DEFINER; an events read would change who can call it', r.fn;
    end if;
  end loop;
  -- KAN-711 parity on every column whose read is removed. Checked only where the column still exists, so the
  -- migration is also safe to re-check after Z01 (it then has nothing to compare).
  for c in select * from (values ('games','game','creator_user_id'), ('games','game','listing_visibility'),
                                 ('games','game','is_cancelled'), ('games','game','start_at'),
                                 ('meetups','meetup','creator_user_id'), ('meetups','meetup','listing_visibility'),
                                 ('meetups','meetup','is_cancelled')) v(tbl, etype, col) loop
    if exists (select 1 from pg_attribute where attrelid = ('public.' || c.tbl)::regclass and attname = c.col and not attisdropped) then
      execute format('select count(*) from public.%I x left join public.events e on e.id = x.event_id and e.event_type = %L
                       where e.id is null or x.%I is distinct from e.%I', c.tbl, c.etype, c.col, c.col) into v_n;
      if v_n <> 0 then
        raise exception 'KAN-807 pre: % row(s) of public.% lack their typed events parent or differ on % (KAN-711 parity)', v_n, c.tbl, c.col;
      end if;
    end if;
  end loop;
  -- Attribute snapshot for section 2, kept in a transaction-local setting (no helper object is created).
  select jsonb_object_agg(k.fn, jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
           p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset))
    into v_attr
    from (values
    ('public._can_view_game(uuid)', '7ee01526ff64e59691ada52fa77474ce', '4ff7a7eebc30f157066f93e7b38e35d3'),
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text, numeric)', 'b96323a71f8726e0ce6ab8ccc1a1dc69', '3a27dca7144c61e9615f25517ba814c9'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42')) k(fn, pre_md5, post_md5) join pg_proc p on p.oid = to_regprocedure(k.fn);
  perform set_config('kan807.a_attr', v_attr::text, true);
end $pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. New bodies (pg_get_functiondef of the pre-image; only the reads listed above change).
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._can_view_game(p_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      -- KAN-713 / KAN-807: the predicate on the events fields (the games half was removed with Z01's columns).
      and (
        e.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
           )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public._is_game_host(p_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      and e.creator_user_id = auth.uid()                                  -- KAN-713 / KAN-807: host from events
  );
$function$;

CREATE OR REPLACE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, e.created_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
  ),
  filtered AS (
    SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
      FROM ev, prm
     WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
       AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
       AND (
         p_before IS NULL
         OR ev.event_at < p_before
         OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
             AND ev.event_at = p_before
             AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
       )
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
  )
  SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
    FROM filtered f
   ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
   LIMIT (SELECT lim FROM prm);
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH me AS (
    SELECT auth.uid() AS user_id
  ),
  game_created AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'created'::text                                               AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      e.created_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON e.creator_user_id = me.user_id
    WHERE e.is_cancelled = false                                           -- KAN-731 / KAN-807: events half only
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND e.is_cancelled = false                                           -- KAN-731 / KAN-807: events half only
      AND e.creator_user_id <> me.user_id
  ),
  game_events AS (
    SELECT * FROM game_created
    UNION ALL
    SELECT * FROM game_joined
  ),
  filtered AS (
    SELECT * FROM game_events e
    WHERE (_period = 'all' OR e.time_bucket = _period)
      AND (_cursor IS NULL OR e.happened_at < _cursor)
  )
  SELECT f.* FROM filtered f
  ORDER BY
    CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
    f.scheduled_for ASC,
    f.happened_at DESC,
    f.priority DESC
  LIMIT _limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text, p_max_price numeric DEFAULT NULL::numeric)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean, price_aed numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-723: shared facts from events e (authoritative); game-only fields from g; access from events (KAN-807).
  select
    g.id,
    coalesce(e.title, 'Untitled Game')    as title,
    s.name_en                              as sport_name,
    e.start_at                             as scheduled_at,
    case
      when e.is_cancelled         then 'cancelled'
      when now() >= e.end_at      then 'ended'
      when now() >= e.start_at    then 'live'
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
    greatest(e.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
    (e.listing_visibility = 'public')      as is_public,
    e.min_skill::int                       as min_skill,
    e.max_skill::int                       as max_skill,
    e.end_at,
    sv.name_en                             as variant_name_en,
    sv.name_ar                             as variant_name_ar,
    e.cost_cover,
    e.joining_rule,
    (coalesce((select pv.verified from profile_verifications pv
                where pv.profile_id = e.creator_profile_id), false)
     or exists (select 1 from organiser o
                where o.profile_id = e.creator_profile_id and o.sport = s.sport_key
                  and o.is_verified and o.is_active)) as host_verified,
    (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
    exists (select 1 from public.favorites f
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me,
    g.price_aed
  from   games g
  join public.events e on e.id = g.event_id and e.event_type = 'game'
  join   geo_locations gl on e.geo_location_id = gl.id
  join   sports s         on s.id = e.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = coalesce(vs.venue_id, e.venue_id)
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
    and  (p_max_price is null or g.price_aed <= p_max_price)
    and  (
           (e.listing_visibility = 'public' and not public.is_blocked(auth.uid(), e.creator_user_id))
           or e.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
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
    e.start_at asc
  limit 50;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- KAN-727 / KAN-807: end_at and cancelled from events.
  select g0.id, e.end_at, e.is_cancelled as is_cancelled into g
    from public.games g0 join public.events e on e.id = g0.event_id and e.event_type = 'game'
   where g0.id=p_game_id;
  if not found or g.is_cancelled then raise exception using errcode='P0001', message='game_not_ratable'; end if;
  if now() > g.end_at + interval '7 days' then raise exception using errcode='P0001', message='rating_window_closed'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_rater_profile_id;
  if not found or prof.user_id <> auth.uid() then raise exception using errcode='P0001', message='not_profile_owner'; end if;
  if prof.profile_type <> 'player' then raise exception using errcode='P0001', message='organiser_cannot_rate_game'; end if;
  r_user := prof.user_id;

  if not public._user_played_in_game(r_user, p_game_id) then
    raise exception using errcode='P0001', message='rater_not_in_game';
  end if;

  if exists (select 1 from public.game_rating_events where game_id=p_game_id and rater_user_id=r_user) then
    raise exception using errcode='P0001', message='already_rated';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode='P0001', message='invalid_scores';
  end if;

  for d in select key from public.game_rating_dimensions where is_active loop
    if p_scores ? d.key then
      v := (p_scores ->> d.key)::numeric;
      if v is null then raise exception using errcode='P0001', message='score_not_numeric'; end if;
      if v < 0 or v > 5 then raise exception using errcode='P0001', message='score_out_of_range'; end if;
    end if;
  end loop;

  insert into public.game_rating_events(game_id, rater_user_id, rater_profile_id, scores, comment)
  values (p_game_id, r_user, p_rater_profile_id, p_scores, left(p_comment, 280));

  perform public.game_rating_recompute(p_game_id);

  return 'ok';
end;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Postconditions: new body pinned; signature, result, SECURITY, volatility, search_path, owner, ACL unchanged.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  r record;
  v_attr jsonb := current_setting('kan807.a_attr')::jsonb;
  v_now jsonb;
begin
  for r in select * from (values
    ('public._can_view_game(uuid)', '7ee01526ff64e59691ada52fa77474ce', '4ff7a7eebc30f157066f93e7b38e35d3'),
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text, numeric)', 'b96323a71f8726e0ce6ab8ccc1a1dc69', '3a27dca7144c61e9615f25517ba814c9'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42')) k(fn, pre_md5, post_md5) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post_md5 then
      raise exception 'KAN-807 post: % body is not the authored one', r.fn;
    end if;
    select jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
             p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset)
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'KAN-807 post: % changed signature/result/SECURITY/volatility/search_path/owner/ACL: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end $post$;

commit;
