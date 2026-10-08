-- CEO 2026-10-08: (1) a required price on games; (2) an Indoor/Outdoor setting required for a
-- meetup that has no venue. APPLIED to wtncuzcskpigqpmnxwws as ordered execute_sql steps
-- (no apply_migration, nothing dropped). Old functions are RENAMED to *_legacy_vN, the new ones are
-- created next to them, and the legacy ones lose EXECUTE so an old signature cannot bypass the
-- new requirements. Guards kept verbatim: rpc_create_game persona gate (KAN-440),
-- rpc_update_game host check, rpc_create_meetup persona / free-only / location / sport guards,
-- rpc_get_nearby_games visibility and block guard.

-- Step 1: columns -------------------------------------------------------------------------
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS price_aed numeric(10,2) CHECK (price_aed >= 0);
COMMENT ON COLUMN public.games.price_aed IS 'What the host charges per player, AED. NULL: a game created before the field existed (shown as "Ask"); 0: free; > 0: AED amount.';
ALTER TABLE public.meetups
  ADD COLUMN IF NOT EXISTS is_indoor boolean;
COMMENT ON COLUMN public.meetups.is_indoor IS 'Setting chosen by the host when the meetup has no venue; NULL when a venue gives the setting.';

-- Step 2: v_meetup_list gains setting_is_indoor (appended; venue_is_indoor unchanged) -----
CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    m.title,
    m.description,
    m.start_at,
    m.end_at,
    m.capacity,
    m.members_only,
    m.listing_visibility,
    m.rsvp_policy,
    m.is_cancelled,
    m.vibe_key,
    m.created_at,
    m.updated_at,
    m.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    m.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    m.area_id,
    a.name AS area_name,
    m.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    m.geo_location_id,
    m.min_skill,
    m.max_skill,
    m.joining_rule,
    m.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
        CASE
            WHEN auth.uid() IS NULL THEN '[]'::jsonb
            ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
               FROM ( SELECT r2.profile_id,
                        r2.updated_at
                       FROM meetup_rsvps r2
                      WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
                      ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
                     LIMIT 5) x
                 JOIN profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
        END AS attendee_avatars,
    ( SELECT bool_or(vs.indoor) AS bool_or
           FROM venue_spaces vs
          WHERE vs.venue_id = m.venue_id AND vs.is_active = true) AS venue_is_indoor,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.meetup_id = m.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.meetup_id = m.id AND f.user_id = auth.uid())) AS favourited_by_me,
    COALESCE(( SELECT bool_or(vs2.indoor)
           FROM venue_spaces vs2
          WHERE vs2.venue_id = m.venue_id AND vs2.is_active = true), m.is_indoor) AS setting_is_indoor
   FROM meetups m
     LEFT JOIN profiles cp ON cp.id = m.creator_profile_id
     LEFT JOIN sports s ON s.id = m.sport_id
     LEFT JOIN areas a ON a.id = m.area_id
     LEFT JOIN venues v ON v.id = m.venue_id
     LEFT JOIN v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE can_view_owner(m.creator_user_id, m.listing_visibility) = true
  ORDER BY (COALESCE(m.updated_at, m.created_at)) DESC;

-- Step 3: v_game_card gains price_aed (appended) --------------------------------------------
CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    g.capacity + g.bench_slots AS total_slots,
    g.min_skill,
    g.max_skill,
    g.listing_visibility,
    g.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    g.is_cancelled,
    g.rules,
    g.created_at,
    g.updated_at,
    g.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name AS area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    g.joining_rule,
    g.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    g.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM profile_verifications pv
          WHERE pv.profile_id = g.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM organiser o
          WHERE o.profile_id = g.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);

-- Step 4: rpc_create_game takes a REQUIRED p_price_aed (0 is Free) --------------------------
ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer) RENAME TO rpc_create_game_legacy_v1;

CREATE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; uid uuid; gid uuid; gtype text;
  v_sport record; v_variant record;
  v_required integer; v_players_per_side integer;
  v_geo_id uuid; v_area_id uuid; v_venue_id uuid;
  v_joining_rule text; v_cost_cover text;
  v_capacity integer; v_rules jsonb;
BEGIN
  pid := public.choose_actor(p_actor_type);
  -- KAN-440 persona gate (CEO ruling 2026-10-06): player and organiser may create a game;
  -- socialiser and host may not. Also re-asserts that the caller owns the acting profile.
  -- Tests persona_type directly (the profile_type based organiser helper never matches).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = pid
      AND persona_type IN ('player', 'organiser')
      AND is_active
      AND user_id = public.effective_actor_uid()
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;
  IF p_end_at <= p_start_at THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range'; END IF;
  -- CEO 2026-10-08: a game cannot be created without a price (0 is "Free").
  IF p_price_aed IS NULL OR p_price_aed < 0 THEN RAISE EXCEPTION USING errcode='P0001', message='price_required'; END IF;
  SELECT * INTO v_sport FROM public.sports WHERE id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport'; END IF;
  IF v_sport.is_challenge_sport IS DISTINCT FROM true THEN RAISE EXCEPTION USING errcode='P0001', message='sport_not_challenge_eligible'; END IF;
  SELECT * INTO v_variant FROM public.sport_variants WHERE id = p_sport_variant_id AND sport_id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant'; END IF;
  v_required := v_variant.required_players;
  v_players_per_side := v_variant.players_per_side;
  IF p_bench_slots < 0 OR p_bench_slots > v_players_per_side THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_bench_slots'; END IF;

  -- Optional player-count overrides (UI-editable Min/Max players)
  IF p_max_players IS NOT NULL AND p_max_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_max_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_min_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_min_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_max_players IS NOT NULL AND p_min_players > p_max_players THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_player_range';
  END IF;
  v_capacity := COALESCE(p_max_players, v_required);
  v_rules := COALESCE(p_rules, '{}'::jsonb);
  IF p_min_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('min_players', p_min_players);
  END IF;
  IF p_max_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('max_players', p_max_players);
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id, v.id INTO v_geo_id, v_area_id, v_venue_id
      FROM public.venue_spaces vs JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
  END IF;
  IF v_geo_id IS NULL AND p_geo_location_id IS NOT NULL THEN
    v_geo_id := p_geo_location_id; v_area_id := p_area_id;
  END IF;
  IF v_geo_id IS NULL AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations
     ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)) LIMIT 1;
  END IF;
  IF v_geo_id IS NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations ORDER BY created_at LIMIT 1;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT joining_rule INTO v_joining_rule FROM public.venue_spaces WHERE id = p_venue_space_id;
    v_cost_cover := COALESCE(p_cost_cover, v_joining_rule);
  ELSE
    v_joining_rule := 'free'; v_cost_cover := COALESCE(p_cost_cover, 'free');
  END IF;
  gtype := CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END;
  INSERT INTO public.games (
    game_type, sport_id, sport_variant_id, title,
    creator_profile_id, creator_user_id, venue_space_id, venue_id,
    start_at, end_at, capacity, bench_slots,
    listing_visibility, join_policy, min_skill, max_skill, rules,
    squad_id, allow_spectators, allows_waitlist,
    sport_specific_data, joining_rule, cost_cover,
    geo_location_id, area_id, price_aed
  ) VALUES (
    gtype, p_sport_id, p_sport_variant_id, p_title,
    pid, uid, p_venue_space_id, v_venue_id,
    p_start_at, p_end_at, v_capacity, p_bench_slots,
    p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, v_rules,
    p_squad_id, p_allow_spectators, p_allows_waitlist,
    COALESCE(p_sport_specific_data, '{}'), v_joining_rule, v_cost_cover,
    v_geo_id, COALESCE(v_area_id, p_area_id), round(p_price_aed, 2)
  ) RETURNING id INTO gid;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, pid, uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  RETURN gid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) TO anon, authenticated, service_role;

-- Step 5: rpc_update_game takes a REQUIRED p_price_aed ---------------------------------------
ALTER FUNCTION public.rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer) RENAME TO rpc_update_game_legacy_v1;

CREATE FUNCTION public.rpc_update_game(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  -- CEO 2026-10-08: saving a game needs a price (0 is "Free"); an old game with no
  -- price gets one the first time its host saves it.
  if p_price_aed is null or p_price_aed < 0 then
    raise exception using errcode='P0001', message='price_required';
  end if;
  if p_max_players is not null and p_max_players < 1 then
    raise exception using errcode='P0001', message='invalid_max_players';
  end if;
  if p_min_players is not null and p_min_players < 1 then
    raise exception using errcode='P0001', message='invalid_min_players';
  end if;
  if p_min_players is not null and p_max_players is not null
     and p_min_players > p_max_players then
    raise exception using errcode='P0001', message='invalid_player_range';
  end if;

  select count(*) into v_roster_count
  from public.game_roster
  where game_id = p_game_id and status = 'active';

  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), g.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      listing_visibility = coalesce(p_listing_visibility, g.listing_visibility),
      join_policy        = coalesce(p_join_policy, g.join_policy),
      allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill, g.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill, g.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, g.capacity),
                             v_roster_count
                           ),
      rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
                           || case when p_min_players is not null
                                then jsonb_build_object('min_players', p_min_players)
                                else '{}'::jsonb end
                           || case when p_max_players is not null
                                then jsonb_build_object('max_players', p_max_players)
                                else '{}'::jsonb end,
      price_aed          = round(p_price_aed, 2)
  where g.id = p_game_id
    and g.is_cancelled = false
    and g.end_at > now()
    and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()));

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;

  return 'updated';
end$function$;

GRANT EXECUTE ON FUNCTION public.rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric) TO authenticated, service_role;

-- Step 6: rpc_get_nearby_games gains p_max_price, p_sort 'price', returns price_aed ----------
ALTER FUNCTION public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text) RENAME TO rpc_get_nearby_games_legacy_v3;

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

-- Step 7: rpc_create_meetup takes p_is_indoor (required when there is no venue) -------------
ALTER FUNCTION public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb) RENAME TO rpc_create_meetup_legacy_v1;

CREATE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid               uuid;
  uid               uuid;
  mid               uuid;
  v_sport           record;
  v_variant         record;
  v_required        integer;
  v_final_capacity  integer;
  v_joining_rule    text;
  v_cost_cover      text;
BEGIN
  pid := public.choose_actor(p_actor_type);

  -- KAN-439 (CEO ruling 2026-10-06): player and organiser personas may create; socialiser and
  -- host may not.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles pr
    WHERE pr.id = pid AND pr.user_id = public.effective_actor_uid() AND pr.is_active = true
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_owned';
  END IF;
  IF NOT public.can_create_meetup(pid) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;

  IF COALESCE(p_listing_visibility, 'public') <> 'public' THEN
    RAISE EXCEPTION USING errcode='P0001', message='visibility_not_supported';
  END IF;

  IF p_meta IS NOT NULL AND (
       COALESCE(p_meta->>'joining_rule', 'free') <> 'free'
    OR COALESCE(p_meta->>'cost_cover',   'free') <> 'free'
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  IF p_location_name IS NULL OR trim(p_location_name) = '' THEN
    RAISE EXCEPTION USING errcode='P0001', message='location_name_required';
  END IF;

  -- CEO 2026-10-08: with no venue the host must say Indoor or Outdoor.
  IF p_venue_id IS NULL AND p_is_indoor IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='setting_required';
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION USING errcode='P0001', message='title_required';
  END IF;

  IF p_start_at IS NOT NULL AND p_end_at IS NOT NULL
     AND p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range';
  END IF;

  SELECT * INTO v_sport
    FROM public.sports
   WHERE id = p_sport_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_sport';
  END IF;

  SELECT * INTO v_variant
    FROM public.sport_variants
   WHERE id = p_sport_variant_id
     AND sport_id = p_sport_id
     AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant';
  END IF;

  v_required := v_variant.required_players;

  IF p_capacity IS NOT NULL THEN
    IF p_capacity < v_required THEN
      RAISE EXCEPTION USING errcode='P0001', message='capacity_below_required_players';
    END IF;
    v_final_capacity := p_capacity;
  ELSE
    v_final_capacity := NULL;
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found';
  END IF;

  INSERT INTO public.meetups (
    creator_profile_id, creator_user_id, sport_id, title, description, venue_id, location_name,
    geo_location_id, area_id, start_at, end_at, capacity, listing_visibility, rsvp_policy,
    members_only, min_skill, max_skill, vibe_key, meta, is_indoor
  )
  VALUES (
    pid, uid, p_sport_id, p_title, p_description, p_venue_id, p_location_name,
    p_geo_location_id, p_area_id, p_start_at, p_end_at, v_final_capacity, 'public', p_rsvp_policy,
    p_members_only, p_min_skill, p_max_skill, p_vibe_key, COALESCE(p_meta, '{}'),
    CASE WHEN p_venue_id IS NULL THEN p_is_indoor ELSE NULL END
  )
  RETURNING id, joining_rule, cost_cover INTO mid, v_joining_rule, v_cost_cover;

  IF v_joining_rule <> 'free' OR v_cost_cover <> 'free' THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  -- The host is the first 'going' RSVP (meetup_rsvps is the source of truth).
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  VALUES (mid, uid, pid, 'going')
  ON CONFLICT (meetup_id, user_id) DO UPDATE
    SET status = 'going', profile_id = EXCLUDED.profile_id, updated_at = now();

  RETURN mid;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean) TO authenticated, service_role;

-- Step 8: the renamed legacy overloads are not callable by clients --------------------------
REVOKE ALL ON FUNCTION public.rpc_create_game_legacy_v1(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_update_game_legacy_v1(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_create_meetup_legacy_v1(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb) FROM PUBLIC, anon, authenticated;
