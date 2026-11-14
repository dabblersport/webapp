-- KAN-948 (prerequisite of KAN-866): the game readers take the 22 KAN-866 shared columns from the events parent
-- (games.event_id = events.id, event_type 'game') instead of public.games, so the KAN-866 drop does not break them.
--
-- Readers converted (all re-authored from pg_get_functiondef on the live catalogue, md5-pinned below; CREATE OR REPLACE
-- with the same signature, so owner and ACL are kept; SECURITY / volatility / search_path carried verbatim):
--   _can_view_game_for_join, _slot_conflicts_game, game_slots_left (KAN-934 casual-host rule kept),
--   get_nearby_games(double,double,integer) and (double,double,double) (OUT columns and types unchanged),
--   msg_my_conversations_v1, rpc_get_nearby_games_legacy_v1/_v2/_v3,
--   and two readers found by the scan: rpc_get_unrated_coplayers, trgfn_invite_block_frozen (BEFORE INSERT on
--   game_invites).
-- rpc_get_nearby_games already reads every shared column from events (KAN-723); not changed.
-- Not here (KAN-947, backend-7): the game writers, kan718_game_event_sync / kan718_game_derive / kan711_events_map_game /
-- can_current_user_join_game, and every trigger on public.games.
--
-- get_nearby_games (both overloads) is broken in the pre-image and stays broken: it selects g.lat / g.lng, which games
-- does not have, so every call raises 42703 'column g.lat does not exist'. Fixing it is a behaviour change, not this
-- ticket's; reported on KAN-948.
--
-- INVOKER functions (_can_view_game_for_join, _slot_conflicts_game, game_slots_left and the trigger): a caller that
-- can read events takes the events branch. A caller that cannot (anon / authenticated invoker; events has no client
-- grant) used to read public.games, which has RLS on and no policy, so it saw no row: false / 0 / NULL creator. That
-- answer is now returned without reading games.
-- The guard below asserts the facts this rests on.
--
-- Constraints (no change needed, verified live):
--   * create idempotency: events_type_creator_request_id_key UNIQUE (event_type, creator_profile_id, request_id)
--     WHERE request_id IS NOT NULL already holds on events; rpc_create_game already looks the key up on events (KAN-823).
--   * series uniqueness (series_id, start_at): kan718_series_occurrence_guard (AFTER INSERT/UPDATE OF start_at ON events,
--     AFTER INSERT/UPDATE OF series_id, event_id ON games) and the deferred constraint trigger
--     events_check_series_occurrence already enforce it with series_id from games and start_at from events, under a
--     per-series advisory lock; neither reads games.start_at.

DO $guard$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public._can_view_game_for_join(uuid)', '89c011b633f6cc8c1436e9edcc331255'),
    ('public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)', '6b55caf2dd120676bef075536014370b'),
    ('public.game_slots_left(uuid)', 'e2c076441d93cfe5ec0563cb84585a94'),
    ('public.get_nearby_games(double precision,double precision,integer)', '8e32c7f1e2c6161aff6f5193310eede0'),
    ('public.get_nearby_games(double precision,double precision,double precision)', 'b2cfbc7ff220e55462b1e24f97fca9a1'),
    ('public.msg_my_conversations_v1(integer)', '923194dd0f35bfd322228576e0622e2d'),
    ('public.rpc_get_nearby_games_legacy_v1(double precision,double precision,integer,uuid,text)', '5acddc4265458c89f41b9f0777682982'),
    ('public.rpc_get_nearby_games_legacy_v2(double precision,double precision,integer,uuid,text)', 'cc3d88528d1d4c3a8457253ab7cba7b1'),
    ('public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text)', 'c047f8be6b48b704bf7e8bd185fce94f'),
    ('public.rpc_get_unrated_coplayers(uuid)', '9e612df663421a034f07099ece97818d'),
    ('public.trgfn_invite_block_frozen()', '44c19a750a859f7f6076eb022010896d')
  ) v(sig, md5_pre) LOOP
    IF md5(pg_get_functiondef(r.sig::regprocedure)) <> r.md5_pre THEN
      RAISE EXCEPTION 'KAN-948 pre-image guard: % changed (md5 %)', r.sig, md5(pg_get_functiondef(r.sig::regprocedure));
    END IF;
  END LOOP;
  -- The INVOKER fallback answer rests on: games RLS on with no policy, and no role that may read games past RLS
  -- lacks SELECT on events.
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.games'::regclass) THEN
    RAISE EXCEPTION 'KAN-948 guard: RLS is off on public.games';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.games'::regclass) THEN
    RAISE EXCEPTION 'KAN-948 guard: public.games has a policy';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles ro
              WHERE (ro.rolbypassrls OR ro.rolsuper OR ro.oid = (SELECT relowner FROM pg_class WHERE oid = 'public.games'::regclass))
                AND has_table_privilege(ro.oid, 'public.games', 'SELECT')
                AND NOT has_table_privilege(ro.oid, 'public.events', 'SELECT')) THEN
    RAISE EXCEPTION 'KAN-948 guard: a role reads games past RLS but cannot read events';
  END IF;
  IF has_table_privilege('anon', 'public.events', 'SELECT') OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-948 guard: a client role can read events';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public._can_view_game_for_join(p_game uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-948: creator and visibility from the events parent only.
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    RETURN EXISTS (
      SELECT 1 FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
      WHERE g.id = p_game
        AND (
          public.is_admin(auth.uid())
          OR e.creator_user_id = auth.uid()
          OR public.can_view_with_scope(auth.uid(), e.creator_user_id, e.listing_visibility, NULL::uuid)
        )
    );
  END IF;
  -- Caller cannot read events (anon / authenticated invoker). The pre-image read public.games here (RLS on, no
  -- policy), saw no row and returned false; the answer is unchanged.
  RETURN false;
END;
$function$;

CREATE OR REPLACE FUNCTION public._slot_conflicts_game(p_space uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- KAN-728/KAN-948: start, end and cancelled from the events parent. venue_space_id is games-only and stays on games.
  if has_table_privilege('public.events', 'SELECT') then
    return exists(
      select 1 from public.games g
      join public.events e on e.id = g.event_id and e.event_type = 'game'
      where g.venue_space_id = p_space
        and e.is_cancelled = false
        and tstzrange(e.start_at, e.end_at, '[)') && tstzrange(p_start, p_end, '[)')
    );
  end if;
  -- Caller cannot read events (anon / authenticated invoker). The pre-image read public.games here (RLS on, no
  -- policy), saw no row and returned false; the answer is unchanged.
  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.game_slots_left(p_game uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-727/KAN-948: capacity from events for callers that may read events (INVOKER, granted to clients; events has no
-- client grant -- KAN-713's v_events pattern).
DECLARE
  v_capacity  integer;
  v_game_type text;
  v_active    integer;
BEGIN
  IF NOT has_table_privilege('public.events', 'SELECT') THEN
    RETURN 0;                                   -- pre-image read public.games (RLS on, no policy): no row, so 0
  END IF;
  SELECT e.capacity, g.game_type INTO v_capacity, v_game_type
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.id = p_game;
  IF NOT FOUND THEN
    RETURN 0;                                   -- pre-image: GREATEST(NULL - 0, 0) = 0 for an unknown game
  END IF;
  SELECT count(*)::int INTO v_active
    FROM public.game_roster r
   WHERE r.game_id = p_game AND r.status = 'active'
     AND (r.role = 'player' OR (r.role = 'host' AND v_game_type IN ('hosted', 'casual'))  /* KAN-934: a casual host plays */);
  RETURN GREATEST(v_capacity - v_active, 0);
END
$function$;

CREATE OR REPLACE FUNCTION public.get_nearby_games(p_lat double precision, p_lng double precision, p_radius integer DEFAULT 5000)
 RETURNS TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, distance_meters double precision)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-948: shared facts from events. g.lat / g.lng do not exist on games, so this raises 42703 at parse for every
  -- caller, exactly as the pre-image did; kept as is (equivalence), reported on KAN-948.
  RETURN QUERY
  SELECT
    g.id,
    e.title,
    g.lat,
    g.lng,
    e.start_at,
    e.capacity,

    ST_Distance(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) AS distance_meters

  FROM games g
  JOIN events e ON e.id = g.event_id AND e.event_type = 'game'
  JOIN geo_locations gl ON e.geo_location_id = gl.id

  WHERE
    e.is_cancelled = false
    -- 🔥 TEMP REMOVE THIS
    -- AND e.start_at > now()

    AND ST_DWithin(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )

  ORDER BY
    distance_meters ASC,
    e.start_at ASC

  LIMIT 20;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_nearby_games(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 5000)
 RETURNS TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, sport_id uuid, area_id uuid, distance_meters double precision)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-948: shared facts from events. g.lat / g.lng do not exist on games, so this raises 42703 at parse for every
  -- caller, exactly as the pre-image did; kept as is (equivalence), reported on KAN-948.
  RETURN QUERY
  SELECT
    g.id,
    e.title,
    g.lat,
    g.lng,
    e.start_at,
    e.capacity,
    e.sport_id,
    e.area_id,
    ST_Distance(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) AS distance_meters
  FROM games g
  JOIN events e ON e.id = g.event_id AND e.event_type = 'game'
  JOIN geo_locations gl ON e.geo_location_id = gl.id
  WHERE
    e.is_cancelled = false
    AND e.start_at > now()
    AND ST_DWithin(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )
  ORDER BY
    distance_meters ASC,
    e.start_at ASC
  LIMIT 20;
END;
$function$;

CREATE OR REPLACE FUNCTION public.msg_my_conversations_v1(p_limit integer DEFAULT 50)
 RETURNS TABLE(conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamp with time zone, end_at timestamp with time zone, state text, last_activity_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-948: title, sport, start, end and cancelled from the events parent.
  SELECT c.id,
         g.id,
         e.title,
         s.name_en,
         e.start_at,
         e.end_at,
         CASE
           WHEN m.status = 'left' THEN 'left'
           WHEN e.is_cancelled OR e.end_at < now() THEN 'read_only'
           ELSE 'send'
         END,
         c.last_activity_at
    FROM public.msg_conversations c
    JOIN public.games g ON g.id = c.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    LEFT JOIN public.sports s ON s.id = e.sport_id
    CROSS JOIN LATERAL (
      SELECT r.status
        FROM public.game_roster r
       WHERE r.game_id = c.game_id
         AND r.user_id = auth.uid()
         AND r.role IN ('host', 'player', 'sub')
       ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
       LIMIT 1
    ) m
   WHERE auth.uid() IS NOT NULL
     AND m.status IN ('active', 'left')
   ORDER BY c.last_activity_at DESC, e.start_at DESC
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games_legacy_v1(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-948: shared facts from events e; game-only fields from g.
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
    (e.capacity - coalesce(roster.cnt, 0))::int as spots_remaining,
    (e.listing_visibility = 'public')      as is_public,
    e.min_skill::int                       as min_skill,
    e.max_skill::int                       as max_skill
  from   games g
  join   public.events e on e.id = g.event_id and e.event_type = 'game'
  join   geo_locations gl on e.geo_location_id = gl.id
  join   sports s         on s.id = e.sport_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = vs.venue_id
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  gr.role    = 'player'
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
    and  (
           e.listing_visibility = 'public'
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
    e.start_at asc
  limit 50;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games_legacy_v2(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, liked_by_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-948: shared facts from events e; game-only fields from g.
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
    exists (select 1 from likes lk
            where lk.parent_activity_id = g.id and lk.actor_user_id = auth.uid()) as liked_by_me
  from   games g
  join   public.events e on e.id = g.event_id and e.event_type = 'game'
  join   geo_locations gl on e.geo_location_id = gl.id
  join   sports s         on s.id = e.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = vs.venue_id
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type in ('hosted', 'casual'))  /* KAN-934: a casual host plays */)
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
    and  (
           e.listing_visibility = 'public'
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
    e.start_at asc
  limit 50;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games_legacy_v3(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-948: shared facts from events e; game-only fields from g.
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
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me
  from   games g
  join   public.events e on e.id = g.event_id and e.event_type = 'game'
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
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type in ('hosted', 'casual'))  /* KAN-934: a casual host plays */)
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
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
    e.start_at asc
  limit 50;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_unrated_coplayers(p_game_id uuid)
 RETURNS TABLE(user_id uuid, profile_id uuid, is_host boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  me uuid := auth.uid();
  g  record;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-948: creator, end and cancelled from the events parent.
  SELECT gm.id, e.creator_user_id, e.creator_profile_id, e.end_at, e.is_cancelled INTO g
    FROM public.games gm
    JOIN public.events e ON e.id = gm.event_id AND e.event_type = 'game'
   WHERE gm.id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;
  IF now() < g.end_at THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_finished'; END IF;
  IF now() > g.end_at + interval '7 days' THEN RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed'; END IF;

  -- same participant rule as rpc_rate_user: the rater must be an active roster member
  IF NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.user_id = me AND r.status = 'active') THEN
    RAISE EXCEPTION USING errcode='P0001', message='rater_not_in_game';
  END IF;

  RETURN QUERY
  WITH cands AS (
    SELECT DISTINCT ON (r.user_id) r.user_id AS cuser, r.profile_id AS cprofile, (r.user_id = g.creator_user_id) AS chost
    FROM public.game_roster r
    WHERE r.game_id = p_game_id AND r.status = 'active' AND r.user_id <> me
    ORDER BY r.user_id, r.joined_at
  ), host_c AS (
    SELECT g.creator_user_id AS cuser, g.creator_profile_id AS cprofile, true AS chost
    WHERE g.creator_user_id <> me AND NOT EXISTS (SELECT 1 FROM cands c WHERE c.cuser = g.creator_user_id)
  ), allc AS (
    SELECT cuser, cprofile, chost FROM cands
    UNION ALL
    SELECT cuser, cprofile, chost FROM host_c
  )
  SELECT a.cuser, a.cprofile, a.chost
  FROM allc a
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_reputation_events e
    WHERE e.game_id = p_game_id AND e.rater_user_id = me AND e.ratee_user_id = a.cuser
  )
  ORDER BY a.chost DESC, a.cuser;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_invite_block_frozen()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare uid uuid;
begin
  -- KAN-948: the game's creator from the events parent. A caller that cannot read events used to read games (RLS on,
  -- no policy), found no row and passed NULL; it still does.
  if has_table_privilege('public.events', 'SELECT') then
    select e.creator_user_id into uid
      from public.games g
      join public.events e on e.id = g.event_id and e.event_type = 'game'
     where g.id = new.game_id;
  end if;
  perform public.guard_user_not_frozen(uid);
  return new;
end;
$function$;

-- Post-assert: owner, ACL, SECURITY, volatility and search_path unchanged; no body reads a games alias for a shared column.
DO $post$
DECLARE bad text;
BEGIN
  SELECT string_agg(v.sig, ', ') INTO bad
    FROM (VALUES
      ('public._can_view_game_for_join(uuid)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false, 's'),
      ('public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false, 's'),
      ('public.game_slots_left(uuid)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false, 's'),
      ('public.get_nearby_games(double precision,double precision,integer)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false, 'v'),
      ('public.get_nearby_games(double precision,double precision,double precision)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false, 's'),
      ('public.msg_my_conversations_v1(integer)', '{postgres=X/postgres,service_role=X/postgres}', true, 's'),
      ('public.rpc_get_nearby_games_legacy_v1(double precision,double precision,integer,uuid,text)', '{postgres=X/postgres,service_role=X/postgres}', true, 's'),
      ('public.rpc_get_nearby_games_legacy_v2(double precision,double precision,integer,uuid,text)', '{postgres=X/postgres,service_role=X/postgres}', true, 's'),
      ('public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text)', '{postgres=X/postgres,service_role=X/postgres}', true, 's'),
      ('public.rpc_get_unrated_coplayers(uuid)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', true, 's'),
      ('public.trgfn_invite_block_frozen()', '{postgres=X/postgres,service_role=X/postgres}', false, 'v')
    ) v(sig, acl, secdef, vol)
    JOIN pg_proc p ON p.oid = v.sig::regprocedure
   WHERE p.proacl::text <> v.acl
      OR p.prosecdef <> v.secdef
      OR p.provolatile::text <> v.vol
      OR pg_get_userbyid(p.proowner) <> 'postgres'
      OR p.proconfig IS NULL
      OR (v.sig <> 'public.rpc_get_unrated_coplayers(uuid)'   -- its g is a record of events values, not a games alias
          AND p.prosrc ~* '\m(g|gm)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M');
  IF bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-948 post-assert failed: %', bad;
  END IF;
END
$post$;
