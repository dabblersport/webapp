-- KAN-714 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load order (KAN714_CONTRACT.md section 8):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, THIS FILE, KAN-710, KAN-711 (+ CALL kan711_events_backfill_run(200)
--   + kan711_events_validate_links()), KAN-712 stage A + B, KAN-713 x2, then KAN-714.
--
-- It is loaded BEFORE KAN-710 so every row below is backfilled into public.events by KAN-711 exactly as live
-- rows were, and every reader below exists in its PRE-KAN-714 form when KAN-714 runs.
--
-- What it adds:
--   * reference columns/tables the readers KAN-714 repoints join to (baseline 20260829080500 column names;
--     only the columns a reader touches). HARNESS ASSUMPTIONS are marked.
--   * PostGIS stub: no PostGIS in local PG16. geometry is a composite (x, y) and st_x / st_y read it, so the
--     verbatim `st_y(gl.location::geometry)` in v_game_card executes. Identical before and after KAN-714.
--   * EVERY reader KAN-714 replaces, VERBATIM from the latest migration file:line printed above it (extracted
--     by script from the repo, latest CREATE per object), owned by postgres, with the ACL the repo leaves.
--   * rpc_meetup_card(uuid): the KAN-712 harness one-argument stub is dropped and replaced by the real
--     (uuid, text) function (live has only that one; rpc_meetup_update calls it with one argument).
--   * PG16 has no MAINTAIN privilege (PG17+). View grants here omit it; post-conditions compare the ACL
--     captured before KAN-714 with the ACL after, so the live MAINTAIN bits are asserted unchanged, not assumed.
--   * a seeded population of 3,000 games and 2,000 meetups (equal start_at groups of 5 for keyset tie-break,
--     every visibility, cancelled rows, rows in the next 7 days) plus rsvps / roster / follows / favourites.
SET check_function_bodies = off;

CREATE EXTENSION IF NOT EXISTS citext;

-- PostGIS stub ---------------------------------------------------------------------------------------------------
CREATE TYPE public.geometry AS (x double precision, y double precision);
CREATE FUNCTION public.st_x(public.geometry) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT ($1).x $$;
CREATE FUNCTION public.st_y(public.geometry) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$ SELECT ($1).y $$;
ALTER TABLE public.geo_locations ADD COLUMN location public.geometry;

-- Reference columns ----------------------------------------------------------------------------------------------
ALTER TABLE public.sports ADD COLUMN sport_key text, ADD COLUMN name_en text, ADD COLUMN name_ar text, ADD COLUMN emoji text;
ALTER TABLE public.sport_variants ADD COLUMN name_ar text;
ALTER TABLE public.profiles ADD COLUMN username citext, ADD COLUMN display_name text, ADD COLUMN avatar_url text, ADD COLUMN interests uuid[];
ALTER TABLE public.areas ADD COLUMN name text, ADD COLUMN city_code text;
ALTER TABLE public.venue_spaces ADD COLUMN name_en text, ADD COLUMN indoor boolean, ADD COLUMN is_active boolean DEFAULT true;
ALTER TABLE public.venues ADD COLUMN name_en text, ADD COLUMN is_active boolean DEFAULT true, ADD COLUMN sports text[];
ALTER TABLE public.meetup_rsvps ADD COLUMN created_at timestamptz DEFAULT now();
ALTER TABLE public.posts ADD COLUMN sport_id uuid, ADD COLUMN visibility text, ADD COLUMN is_deleted boolean DEFAULT false,
  ADD COLUMN is_hidden_admin boolean DEFAULT false, ADD COLUMN is_active boolean, ADD COLUMN expires_at timestamptz, ADD COLUMN author_user_id uuid;

-- Reference tables (baseline column names, only those read) -------------------------------------------------------
CREATE TABLE public.news (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), area_id uuid, sport_id uuid, status text, published_at timestamptz, expires_at timestamptz);
CREATE TABLE public.privacy_settings (user_id uuid PRIMARY KEY, show_game_history boolean DEFAULT true);
CREATE TABLE public.profile_verifications (profile_id uuid PRIMARY KEY, verified boolean);
CREATE TABLE public.organiser (profile_id uuid, sport text, is_verified boolean, is_active boolean);
CREATE TABLE public.likes (parent_activity_id uuid, actor_user_id uuid);
CREATE TABLE public.favorites (game_id uuid, meetup_id uuid, user_id uuid);
CREATE TABLE public.game_rating_aggregate (game_id uuid PRIMARY KEY, composite_score numeric, event_count integer, dim_sums jsonb, dim_counts jsonb, last_event_at timestamptz);
-- HARNESS ASSUMPTION: reference tables RLS-off, SELECT to the API roles (as the KAN-713 harness does). Every
-- reader KAN-714 touches is owner-run (definer function or owner view), so these grants do not change results.
GRANT SELECT ON public.news, public.privacy_settings, public.profile_verifications, public.organiser, public.likes,
  public.favorites, public.game_rating_aggregate TO anon, authenticated, service_role;

-- PRE-KAN-714 READERS, VERBATIM ------------------------------------------------------------------------------------
-- 20260915120000_meetups_hardening.sql:104
CREATE OR REPLACE FUNCTION public.meetup_counts(p_meetup_id uuid)
 RETURNS TABLE(going integer, interested integer, declined integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int
  from public.meetups m
  left join public.meetup_rsvps r on r.meetup_id = m.id
  where m.id = p_meetup_id
    and public.can_view_owner(m.creator_user_id, m.listing_visibility)
$function$;
ALTER FUNCTION public.meetup_counts(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.meetup_counts(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.meetup_counts(uuid) TO anon, authenticated, service_role;

-- 20261008170000_games_following_joined.sql:33
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
ALTER FUNCTION public.rpc_games_following_joined(uuid[]) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_games_following_joined(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_games_following_joined(uuid[]) TO authenticated;

-- 20260915120000_meetups_hardening.sql:406
CREATE OR REPLACE FUNCTION public.rpc_meetup_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(actor_profile_id uuid, display_name text, username citext, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  return query
  select
    r.profile_id,
    p.display_name,
    p.username,
    r.status
  from public.meetup_rsvps r
  left join public.profiles p on p.id = r.profile_id
  where r.meetup_id = p_meetup_id
    and (p_status is null or r.status = p_status)
    and (v_host or r.status in ('going','interested'))
  order by r.updated_at desc nulls last, r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;
ALTER FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) TO authenticated, service_role;

-- HARNESS: the KAN-712 harness stub rpc_meetup_card(uuid) does not exist live (live has only (uuid, text)); with
-- both present a one-argument call is ambiguous, so the stub is replaced by the real two-argument function.
DROP FUNCTION public.rpc_meetup_card(uuid);
-- 20260915130000_meetups_card_fields.sql:78
CREATE OR REPLACE FUNCTION public.rpc_meetup_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
  g int; i int; d int; pn int;
  my_status_ text;
  hp_name text;
  hp_user citext;
  counts_ jsonb;
  hp_avatar text;
  sp public.sports%rowtype;
  v_area text;
  v_venue text;
  atts jsonb := '[]'::jsonb;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int,
    (count(*) filter (where r.status = 'pending'))::int
    into g, i, d, pn
  from public.meetup_rsvps r
  where r.meetup_id = p_meetup_id;

  if me is not null then
    select r.status into my_status_
    from public.meetup_rsvps r
    where r.meetup_id = p_meetup_id and r.user_id = me;
  end if;

  select hp.display_name, hp.username, hp.avatar_url into hp_name, hp_user, hp_avatar
  from public.profiles hp where hp.id = m.host_actor_id;

  select * into sp from public.sports s where s.id = m.sport_id;
  select a.name into v_area from public.areas a where a.id = m.area_id;
  select v.name_en into v_venue from public.venues v where v.id = m.venue_id;

  -- member names/avatars: authenticated callers only (the card is anon-callable)
  if me is not null then
    select coalesce(jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name)
                              order by x.updated_at desc nulls last), '[]'::jsonb)
      into atts
    from (select r.profile_id, r.updated_at from public.meetup_rsvps r
          where r.meetup_id = p_meetup_id and r.status = 'going'
          order by r.updated_at desc nulls last, r.created_at desc limit 8) x
    join public.profiles ap on ap.id = x.profile_id;
  end if;

  counts_ := jsonb_build_object(
    'going',      coalesce(g,0),
    'interested', coalesce(i,0),
    'declined',   coalesce(d,0)
  );
  if v_host then
    counts_ := counts_ || jsonb_build_object('pending', coalesce(pn,0));
  end if;

  return jsonb_build_object(
    'id',               m.id,
    'title',            m.title,
    'description',      m.description,
    'start_at',         m.start_at,
    'end_at',           m.end_at,
    'location_name',    m.location_name,
    'capacity',         m.capacity,
    'visibility',       m.listing_visibility,
    'is_cancelled',     m.is_cancelled,
    'owner_profile_id', m.creator_profile_id,
    'host', jsonb_build_object(
      'actor_profile_id', m.host_actor_id,
      'display_name',     hp_name,
      'username',         hp_user,
      'avatar_url',       hp_avatar
    ),
    'counts',    counts_,
    'my_status', my_status_,
    'sport_key',     sp.sport_key,
    'sport_name_en', sp.name_en,
    'sport_name_ar', sp.name_ar,
    'min_skill',     m.min_skill,
    'max_skill',     m.max_skill,
    'area_name',     v_area,
    'venue_name',    v_venue,
    'attendees',     atts,
    'is_host',   v_host
  );
end;
$function$;
ALTER FUNCTION public.rpc_meetup_card(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_meetup_card(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_card(uuid, text) TO anon, authenticated, service_role;

-- 20260829080500_baseline_schema.sql:13832 (pre-existing broken: reads columns meetups does not have)
CREATE OR REPLACE FUNCTION "public"."rpc_meetup_my"() RETURNS TABLE("id" "uuid", "title" "text", "starts_at" timestamp with time zone, "visibility" "text", "host_actor_id" "uuid", "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select m.id, m.title, m.starts_at, m.visibility, m.host_actor_id, m.updated_at
  from public.meetups m
  where m.owner_user_id = auth.uid()
  order by m.starts_at
$$;
ALTER FUNCTION public.rpc_meetup_my() OWNER TO postgres;
GRANT ALL ON FUNCTION public.rpc_meetup_my() TO anon, authenticated, service_role;

-- 20261021115000_sport_overview_counts.sql:40
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
ALTER FUNCTION public.rpc_sport_overview(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.rpc_sport_overview(uuid, text) TO authenticated;

-- Views, verbatim. v_meetup_counts first (v_meetup_list reads it).
-- 20260915120000_meetups_hardening.sql:136 (+ :145 security_invoker = off, :214-216 ACL)
CREATE OR REPLACE VIEW public.v_meetup_counts AS
 SELECT r.meetup_id,
    sum((r.status = 'going')::integer) AS going_count,
    sum((r.status = 'interested')::integer) AS interested_count,
    sum((r.status = 'declined')::integer) AS declined_count
   FROM public.meetup_rsvps r
     JOIN public.meetups m ON m.id = r.meetup_id
  WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
  GROUP BY r.meetup_id;
ALTER VIEW public.v_meetup_counts SET (security_invoker = off);
ALTER VIEW public.v_meetup_counts OWNER TO postgres;
REVOKE ALL ON TABLE public.v_meetup_counts FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.v_meetup_counts TO authenticated;
GRANT ALL ON TABLE public.v_meetup_counts TO service_role;

-- 20261008140000_game_price_meetup_setting.sql:18 (ACL 20260915130000_meetups_card_fields.sql:74-78)
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
ALTER VIEW public.v_meetup_list OWNER TO postgres;
REVOKE ALL ON TABLE public.v_meetup_list FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.v_meetup_list TO anon;
GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.v_meetup_list TO authenticated;
GRANT ALL ON TABLE public.v_meetup_list TO service_role;

-- 20261101120000_kan698_v_game_card_series_columns.sql:9 (ACL baseline 38766-38768)
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
    g.price_aed,
    g.series_id,
    CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
    s2.ends_on AS series_ends_on
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
     LEFT JOIN game_series s2 ON s2.id = g.series_id
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);
ALTER VIEW public.v_game_card OWNER TO postgres;
REVOKE ALL ON TABLE public.v_game_card FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.v_game_card TO anon, authenticated;
GRANT ALL ON TABLE public.v_game_card TO service_role;

-- 20260829080500_baseline_schema.sql:25636 (ACL 38772-38774)
CREATE OR REPLACE VIEW "public"."v_game_rating" AS
 SELECT "g"."id" AS "game_id",
    "gra"."composite_score",
    "gra"."event_count",
    "gra"."dim_sums",
    "gra"."dim_counts",
    "gra"."last_event_at"
   FROM ("public"."games" "g"
     LEFT JOIN "public"."game_rating_aggregate" "gra" ON (("gra"."game_id" = "g"."id")));
ALTER VIEW public.v_game_rating OWNER TO postgres;
REVOKE ALL ON TABLE public.v_game_rating FROM PUBLIC;
GRANT REFERENCES, TRIGGER ON TABLE public.v_game_rating TO anon, authenticated;
GRANT ALL ON TABLE public.v_game_rating TO service_role;

-- 20260829080500_baseline_schema.sql:25662 (ACL 38784-38786)
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
ALTER VIEW public.v_host_weekly_metrics OWNER TO postgres;
REVOKE ALL ON TABLE public.v_host_weekly_metrics FROM PUBLIC;
GRANT REFERENCES, TRIGGER ON TABLE public.v_host_weekly_metrics TO anon, authenticated;
GRANT ALL ON TABLE public.v_host_weekly_metrics TO service_role;

-- 20260829080500_baseline_schema.sql:25858 (ACL 38832-38834)
CREATE OR REPLACE VIEW "public"."v_my_games" AS
 SELECT "g"."id",
    "g"."title",
    "g"."game_type",
    "g"."start_at",
    "g"."end_at",
    "g"."capacity",
    "g"."is_cancelled",
    "g"."listing_visibility",
    "g"."join_policy",
    "g"."created_at",
    "g"."sport_id",
    "s"."sport_key",
    "s"."name_en" AS "sport_name_en",
    "s"."name_ar" AS "sport_name_ar",
    "g"."creator_profile_id",
    "g"."creator_user_id",
    "g"."area_id",
    "a"."name" AS "area_name",
    "g"."venue_id",
    "v"."name_en" AS "venue_name",
    "gr"."status" AS "my_roster_status"
   FROM ((((("public"."games" "g"
     LEFT JOIN "public"."sports" "s" ON (("s"."id" = "g"."sport_id")))
     LEFT JOIN "public"."areas" "a" ON (("a"."id" = "g"."area_id")))
     LEFT JOIN "public"."venue_spaces" "vs" ON (("vs"."id" = "g"."venue_space_id")))
     LEFT JOIN "public"."venues" "v" ON (("v"."id" = COALESCE("vs"."venue_id", "g"."venue_id"))))
     LEFT JOIN "public"."game_roster" "gr" ON ((("gr"."game_id" = "g"."id") AND ("gr"."user_id" = "auth"."uid"()))))
  WHERE (("g"."creator_user_id" = "auth"."uid"()) OR ("gr"."user_id" = "auth"."uid"()));
ALTER VIEW public.v_my_games OWNER TO postgres;
REVOKE ALL ON TABLE public.v_my_games FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.v_my_games TO anon, authenticated;
GRANT ALL ON TABLE public.v_my_games TO service_role;

-- 20260829080500_baseline_schema.sql:26149 (ACL 38922-38924)
CREATE OR REPLACE VIEW "public"."v_rateable_after_game" AS
 WITH "ctx" AS (
         SELECT "g"."id" AS "game_id",
            "g"."creator_user_id" AS "host_user_id",
            "g"."end_at"
           FROM "public"."games" "g"
        )
 SELECT "c"."game_id",
    "rr"."user_id" AS "you_user_id",
    "r"."user_id" AS "ratee_user_id",
        CASE
            WHEN ("r"."user_id" = ( SELECT "ctx"."host_user_id"
               FROM "ctx"
              WHERE ("ctx"."game_id" = "c"."game_id"))) THEN 'organiser'::"text"
            ELSE 'player'::"text"
        END AS "ratee_role"
   FROM (("ctx" "c"
     JOIN "public"."game_roster" "rr" ON ((("rr"."game_id" = "c"."game_id") AND ("rr"."status" = 'active'::"text") AND ("rr"."user_id" = "auth"."uid"()))))
     JOIN "public"."game_roster" "r" ON ((("r"."game_id" = "c"."game_id") AND ("r"."status" = 'active'::"text"))))
  WHERE (("r"."user_id" <> "auth"."uid"()) OR (( SELECT "ctx"."host_user_id"
           FROM "ctx"
          WHERE ("ctx"."game_id" = "c"."game_id")) <> "auth"."uid"()));
ALTER VIEW public.v_rateable_after_game OWNER TO postgres;
REVOKE ALL ON TABLE public.v_rateable_after_game FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.v_rateable_after_game TO anon, authenticated;
GRANT ALL ON TABLE public.v_rateable_after_game TO service_role;

-- Reference data ---------------------------------------------------------------------------------------------------
UPDATE public.sports SET sport_key = 'football', name_en = 'Football', name_ar = 'كرة القدم', emoji = 'F' WHERE id = '00000000-0000-0000-0000-0000000000e1';
UPDATE public.areas SET name = 'Area ' || right(id::text, 2), city_code = CASE WHEN right(id::text, 2) = 'c1' THEN 'DXB' ELSE 'AUH' END;
UPDATE public.geo_locations SET location = ROW(55.27, 25.20)::public.geometry;
UPDATE public.venues SET name_en = 'Venue ' || right(id::text, 4), sports = ARRAY['football'];
UPDATE public.venue_spaces SET name_en = 'Space ' || right(id::text, 4), indoor = (right(id::text, 1) = '1'), sport_id = '00000000-0000-0000-0000-0000000000e1';
UPDATE public.profiles SET username = 'user_' || right(id::text, 2), display_name = 'User ' || right(id::text, 2),
  avatar_url = 'https://img/' || right(id::text, 2), interests = ARRAY['00000000-0000-0000-0000-0000000000e1'::uuid];
UPDATE public.sport_variants SET name_ar = 'متغير';
INSERT INTO public.profile_verifications VALUES ('00000000-0000-0000-0000-0000000000b1', true);
INSERT INTO public.privacy_settings VALUES ('00000000-0000-0000-0000-0000000000a7', false);
INSERT INTO public.game_rating_aggregate (game_id, composite_score, event_count) VALUES ('71300000-0000-0000-0000-000000000001', 4.5, 3);

-- Bulk population: 3,000 games, 2,000 meetups -----------------------------------------------------------------------
-- Creators rotate over a1, a2, a5, a6, a7 (profiles b1, b2, b5, b6, b7). start_at groups of 5 share one instant
-- (keyset tie-break). Every 50th row is in the next 1..6 days (rpc_sport_overview window). Every 17th is cancelled.
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled, venue_id)
SELECT ('71400000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
       'Bulk game ' || i,
       ('00000000-0000-0000-0000-0000000000b' || (ARRAY['1','2','5','6','7'])[1 + i % 5])::uuid,
       ('00000000-0000-0000-0000-0000000000a' || (ARRAY['1','2','5','6','7'])[1 + i % 5])::uuid,
       CASE WHEN i % 50 = 0 THEN date_trunc('hour', now()) + ((1 + i % 6) || ' days')::interval + interval '3 hours'
            ELSE timestamptz '2030-01-01 00:00+00' + ((i / 5) || ' hours')::interval END,
       CASE WHEN i % 50 = 0 THEN date_trunc('hour', now()) + ((1 + i % 6) || ' days')::interval + interval '4 hours'
            ELSE timestamptz '2030-01-01 01:00+00' + ((i / 5) || ' hours')::interval END,
       2 + i % 20,
       (ARRAY['public','followers','private'])[1 + i % 3],
       (ARRAY['open','request','invite','link'])[1 + i % 4],
       '00000000-0000-0000-0000-0000000000e1',
       ('00000000-0000-0000-0000-0000000000d' || (ARRAY['1','2'])[1 + i % 2])::uuid,
       ('00000000-0000-0000-0000-0000000000c' || (ARRAY['1','2'])[1 + i % 2])::uuid,
       1 + i % 5, 6 + i % 5,
       (ARRAY['pickup','training','hosted','casual'])[1 + i % 4],
       (i % 17 = 0),
       CASE WHEN i % 7 = 0 THEN '00000000-0000-0000-0000-00000000ee01'::uuid END
  FROM generate_series(1, 3000) i;

INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at, listing_visibility,
                            rsvp_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, capacity, is_cancelled, location_name, is_indoor)
SELECT ('71400000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid,
       'Bulk meetup ' || i,
       'Description ' || i,
       ('00000000-0000-0000-0000-0000000000b' || (ARRAY['1','2','5','6','7'])[1 + i % 5])::uuid,
       ('00000000-0000-0000-0000-0000000000a' || (ARRAY['1','2','5','6','7'])[1 + i % 5])::uuid,
       ('00000000-0000-0000-0000-0000000000b' || (ARRAY['1','2','5','6','7'])[1 + i % 5])::uuid,
       CASE WHEN i % 50 = 0 THEN date_trunc('hour', now()) + ((1 + i % 6) || ' days')::interval + interval '5 hours'
            ELSE timestamptz '2030-01-01 00:00+00' + ((i / 5) || ' hours')::interval END,
       CASE WHEN i % 50 = 0 THEN date_trunc('hour', now()) + ((1 + i % 6) || ' days')::interval + interval '6 hours'
            ELSE timestamptz '2030-01-01 02:00+00' + ((i / 5) || ' hours')::interval END,
       (ARRAY['public','circle','invite','link','hidden'])[1 + i % 5],
       (ARRAY['open','request','invite','link','closed'])[1 + i % 5],
       '00000000-0000-0000-0000-0000000000e1',
       ('00000000-0000-0000-0000-0000000000d' || (ARRAY['1','2'])[1 + i % 2])::uuid,
       ('00000000-0000-0000-0000-0000000000c' || (ARRAY['1','2'])[1 + i % 2])::uuid,
       1 + i % 5, 6 + i % 5,
       CASE WHEN i % 3 = 0 THEN NULL ELSE 5 + i % 30 END,
       (i % 17 = 0),
       'Place ' || i,
       (i % 2 = 0)
  FROM generate_series(1, 2000) i;

-- Relationships on the bulk rows (+ the matrix rows): roster, rsvps, follows, favourites, likes.
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
SELECT g.id, ('00000000-0000-0000-0000-0000000000a' || x)::uuid, ('00000000-0000-0000-0000-0000000000b' || x)::uuid,
       CASE WHEN x = '1' THEN 'host' ELSE 'player' END, CASE WHEN x = '7' THEN 'left' ELSE 'active' END
  FROM public.games g CROSS JOIN unnest(ARRAY['1','4','5','7']) x
 WHERE g.id::text LIKE '71400000%' AND (right(g.id::text, 4)::int % 3 = 0);
-- (No extra roster rows on the KAN-713 matrix games: KAN-713 probes A8 and E-2 depend on that roster.)
INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status, updated_at, created_at)
SELECT m.id, ('00000000-0000-0000-0000-0000000000a' || x)::uuid, ('00000000-0000-0000-0000-0000000000b' || x)::uuid,
       (ARRAY['going','interested','declined','pending'])[1 + (right(m.id::text, 4)::int + x::int) % 4],
       timestamptz '2029-01-01 00:00+00' + (right(m.id::text, 4)::int || ' minutes')::interval + (x || ' seconds')::interval,
       timestamptz '2028-01-01 00:00+00' + (x || ' seconds')::interval
  FROM public.meetups m CROSS JOIN unnest(ARRAY['2','4','5','6']) x;
INSERT INTO public.favorites (game_id, user_id)
SELECT g.id, '00000000-0000-0000-0000-0000000000a4' FROM public.games g WHERE right(g.id::text, 2) IN ('01', '11', '21');
INSERT INTO public.favorites (meetup_id, user_id)
SELECT m.id, '00000000-0000-0000-0000-0000000000a5' FROM public.meetups m WHERE right(m.id::text, 2) IN ('02', '12', '01');
INSERT INTO public.likes SELECT g.id, '00000000-0000-0000-0000-0000000000a5' FROM public.games g WHERE right(g.id::text, 2) = '05';
INSERT INTO public.profile_follows (follower_profile_id, following_profile_id)
SELECT '00000000-0000-0000-0000-0000000000b2', p FROM unnest(ARRAY['00000000-0000-0000-0000-0000000000b4','00000000-0000-0000-0000-0000000000b5',
  '00000000-0000-0000-0000-0000000000b7']::uuid[]) p;
INSERT INTO public.posts (id, author_profile_id, sport_id, visibility, author_user_id)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000e1', 'public', '00000000-0000-0000-0000-0000000000a1');
INSERT INTO public.news (sport_id, area_id, status, published_at) VALUES
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'published', now() - interval '1 day');
ANALYZE;
