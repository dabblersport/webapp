-- KAN-906 (KAN-714 chain stage R, KAN-866 follow-up; Epic KAN-708, Events P4): the 5-argument
-- public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text) stops reading the games columns
-- that KAN-866 (20261111120000_kan719b_drop_client_read_games_columns.sql) removes.
--
-- WHY. The body (B04, 20261104100400_kan714_b04_rpc_nearby_following.sql, DO block $n5$, lines 236-324) reads
-- every shared fact from public.events e except in ONE place: the KAN-723 games-side visibility block
--   ((g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
--    or g.creator_user_id = auth.uid()
--    or public.can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id))
-- g.listing_visibility and g.creator_user_id are two of the 22 KAN-866 columns (creator_profile_id,
-- creator_user_id, title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled, cancelled_at,
-- cancelled_reason, sport_id, area_id, geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover,
-- request_id, created_at, updated_at). No other g.<column> in the body is one of them: the body's games reads are
-- g.id, g.event_id, g.game_type, g.price_aed (none in this overload), g.sport_variant_id, g.squad_id,
-- g.venue_space_id, all game-only. The 6-argument overload had the same block removed by KAN-807
-- (20261104110900_kan807_d04_residual_a.sql); this is the same fix for the 5-argument twin.
--
-- WHAT. The games-side block is deleted. The events-side block that follows it,
--   ((e.listing_visibility = 'public' and not public.is_blocked(auth.uid(), e.creator_user_id))
--    or e.creator_user_id = auth.uid()
--    or public.can_view_with_scope(auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id))
-- stays as the sole visibility predicate. The block was one half of the KAN-713/723 intersection; while games and
-- events agree on listing_visibility and creator_user_id (KAN-711 parity, which KAN-866 requires before it drops
-- the games columns) both halves select the same rows, so the result is unchanged. The only other change is the
-- body's first comment line ("access intersected." -> "access from events (KAN-906).", as KAN-807 did for the
-- 6-arg). Signature, defaults, RETURNS TABLE, LANGUAGE sql, STABLE, SECURITY DEFINER and
-- SET search_path TO 'public','pg_temp' are unchanged; CREATE OR REPLACE keeps owner and ACL.
-- No DROP, no CASCADE, no GRANT/REVOKE, no ALTER OWNER, no table, column, policy, trigger or row touched.
-- The 6-argument overload is not touched.
--
-- ONLY WHERE PRESENT. B04 says the 5-arg overload is absent on live (a repo replay creates it). If it is absent this
-- migration raises a notice and does nothing.
--
-- T-058 SUBSTITUTE. Production is not read here. The guard pins md5(prosrc) of the live 5-arg to the B04 body
-- (63e5a660f80100f02e2674db40b58a3a) and refuses on drift; re-author from pg_get_functiondef if it fires. The post
-- check pins the new body (8ba97b088c722df60f863eca264c4de0) and asserts no g.<KAN-866 column> remains.
-- No BEGIN/COMMIT: the Supabase CLI runs each migration in one transaction (with psql use --single-transaction).
--
-- AUTHORED ONLY. Memphis applies it (D-043). Local proof:
--   supabase/tests/events_p4/kan714_r_rpc_get_nearby_games_kan712_inner_test.sql
--
-- ROLLBACK (after COMMIT, only if the 5-arg exists). Run uncommented, in one transaction, as postgres. Pre-image,
-- verbatim from 20261104100400_kan714_b04_rpc_nearby_following.sql:236-324 (md5(prosrc) 63e5a660f80100f02e2674db40b58a3a):
-- KAN906-ROLLBACK-BEGIN
-- CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
--  RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
--  LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
--   -- KAN-723: shared facts from events e (authoritative); game-only fields from g; access intersected.
--   select
--     g.id,
--     coalesce(e.title, 'Untitled Game')    as title,
--     s.name_en                              as sport_name,
--     e.start_at                             as scheduled_at,
--     case
--       when e.is_cancelled         then 'cancelled'
--       when now() >= e.end_at      then 'ended'
--       when now() >= e.start_at    then 'live'
--       else                             'upcoming'
--     end                                    as status,
--     ven.name_en                            as venue_name,
--     st_y(gl.location::geometry)            as latitude,
--     st_x(gl.location::geometry)            as longitude,
--     st_distance(
--       gl.location,
--       st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
--     )                                      as distance_meters,
--     coalesce(roster.cnt, 0)::int           as player_count,
--     greatest(e.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
--     (e.listing_visibility = 'public')      as is_public,
--     e.min_skill::int                       as min_skill,
--     e.max_skill::int                       as max_skill,
--     e.end_at,
--     sv.name_en                             as variant_name_en,
--     sv.name_ar                             as variant_name_ar,
--     e.cost_cover,
--     e.joining_rule,
--     (coalesce((select pv.verified from profile_verifications pv
--                 where pv.profile_id = e.creator_profile_id), false)
--      or exists (select 1 from organiser o
--                 where o.profile_id = e.creator_profile_id and o.sport = s.sport_key
--                   and o.is_verified and o.is_active)) as host_verified,
--     (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
--     exists (select 1 from public.favorites f
--             where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me
--   from   games g
--   join public.events e on e.id = g.event_id and e.event_type = 'game'
--   join   geo_locations gl on e.geo_location_id = gl.id
--   join   sports s         on s.id = e.sport_id
--   left   join sport_variants sv on sv.id = g.sport_variant_id
--   left   join venue_spaces vs on vs.id = g.venue_space_id
--   left   join venues ven      on ven.id = coalesce(vs.venue_id, e.venue_id)
--   left   join lateral (
--     select count(*) as cnt
--     from   game_roster gr
--     where  gr.game_id = g.id
--       and  gr.status  = 'active'
--       and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
--   ) roster on true
--   where  e.is_cancelled = false
--     and  e.start_at > now()
--     and  st_dwithin(
--            gl.location,
--            st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
--            p_radius_meters
--          )
--     and  (p_sport_id is null or e.sport_id = p_sport_id)
--     and  (
--            (g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
--            or g.creator_user_id = auth.uid()
--            or public.can_view_with_scope(
--                 auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
--               )
--          )
--     and  (
--            (e.listing_visibility = 'public' and not public.is_blocked(auth.uid(), e.creator_user_id))
--            or e.creator_user_id = auth.uid()
--            or public.can_view_with_scope(
--                 auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
--               )
--          )
--   order  by
--     case when p_sort = 'distance'
--          then st_distance(
--                 gl.location,
--                 st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
--               )
--     end asc nulls last,
--     e.start_at asc
--   limit 50;
-- $function$
-- KAN906-ROLLBACK-END

do $kan906$
declare
  c_sig  constant text := 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)';
  c_pre  constant text := '63e5a660f80100f02e2674db40b58a3a';
  c_post constant text := '8ba97b088c722df60f863eca264c4de0';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
  v_bad  text;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise notice 'KAN-906: 5-argument rpc_get_nearby_games absent; nothing to convert';
    return;
  end if;

  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_pre then
    raise exception 'KAN-906 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;

  execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-723: shared facts from events e (authoritative); game-only fields from g; access from events (KAN-906).
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
$function$
$ddl$;

  -- Post-conditions. Same oid (replaced in place), the authored body, unchanged attributes, no KAN-866 column read.
  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'KAN-906 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_post then
    raise exception 'KAN-906 post: % body md5 is %, expected %', c_sig, v_md5, c_post;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'KAN-906 post: % attributes changed: % -> %', c_sig, v_before, v_after;
  end if;
  select string_agg(distinct lower(m[1]), ', ') into v_bad
    from pg_proc p, regexp_matches(p.prosrc, '\mg\.([a-z_][a-z0-9_]*)', 'gi') m
   where p.oid = v_oid
     and lower(m[1]) = any ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                              join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                              venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);
  if v_bad is not null then
    raise exception 'KAN-906 post: % still reads KAN-866 games column(s): %', c_sig, v_bad;
  end if;
end
$kan906$;
