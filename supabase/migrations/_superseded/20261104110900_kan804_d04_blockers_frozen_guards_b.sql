-- KAN-804 (KAN-718 D04 blockers, frozen guards part b; Epic KAN-708): trgfn_roster_block_frozen_guard() and
-- trgfn_posts_set_geo() read the host / geo_location_id / area_id from public.events instead of
-- games.creator_user_id, games.geo_location_id and games.area_id, which KAN-719 Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql, seq 603, 618, 619) removes.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan804_d04_frozen_guards_b.sql (before/after/after-Z01 role matrix,
-- helper ACL probe, catalogue and trigger-definition equality, Z01-removed-column scan).
--
-- RULING dreq-9bc08a26, option (i) (cto/orchestrator). Both triggers are SECURITY INVOKER and must stay so.
-- public.games has RLS enabled and NO SELECT policy, so today the games read inside each trigger returns a row
-- ONLY to a role that bypasses RLS (postgres, service_role, a definer function owned by one of them). For a client
-- role (authenticated) the roster guard raises game_not_found and a game-tied post gets NULL geo. public.events
-- is FORCE RLS with no client grant (KAN-710), so a direct events read would turn that into 42501 for clients.
-- The ruling keeps the games-visibility gate exactly where it is and moves only the column read:
--
--   1. NEW helper public.kan804_game_event_facts(p_game_id uuid) -> (creator_user_id, geo_location_id, area_id),
--      read through games.event_id joined to events with event_type = 'game'. STABLE, SECURITY DEFINER,
--      SET search_path = public, pg_temp, owner postgres. NO _can_view_game filter (it answers only for a caller
--      that already saw the games row, step 2). EXECUTE: service_role only. PUBLIC, anon and authenticated are
--      revoked explicitly (Supabase default privileges grant anon/authenticated by name; revoking PUBLIC alone
--      would leave them executable).
--      Nothing else the posts trigger copies comes from games: geo_lat / geo_lng are computed from
--      geo_locations.location (ST_Y/ST_X), joined on the geo_location_id, exactly as in the pre-image.
--   2. Each trigger body STARTS with  PERFORM 1 FROM public.games g WHERE g.id = NEW.game_id;  run as the calling
--      role, so games RLS applies unchanged. FOUND is kept in a local variable.
--        NOT FOUND -> what the pre-image does with no row: roster guard raises game_not_found; posts PATH 2 sets
--                     geo_location_id, area_id, geo_lat, geo_lng to NULL (SELECT ... INTO with no row).
--        FOUND     -> the helper supplies the value the removed games column supplied.
--      The PERFORM has no side effect and raises nothing, so the error order is the pre-image's (the joiner
--      frozen check still runs before game_not_found).
--   3. Nothing else changes: still SECURITY INVOKER, same signatures, proconfig, owner, ACL and CREATE TRIGGER
--      definitions (asserted in section 3). CREATE OR REPLACE on the two bodies; no DROP.
--
--   function                              was                                    now
--   trgfn_roster_block_frozen_guard()     select g.creator_user_id into host_uid  perform 1 from games (gate);
--                                           from public.games g                   if found: select f.creator_user_id
--                                                                                   from kan804_game_event_facts(..) f
--   trgfn_posts_set_geo() PATH 2          SELECT g.geo_location_id, g.area_id,   perform 1 from games (gate);
--                                           ... FROM games g JOIN geo_locations   IF found: SELECT f.geo_location_id,
--                                           gl ON gl.id = g.geo_location_id        f.area_id, ... FROM
--                                                                                   kan804_game_event_facts(..) f JOIN
--                                                                                   geo_locations gl ...; ELSE NULLs
--
-- Z01 ORDER: works BEFORE Z01 (legacy columns present) and AFTER Z01 (columns gone). The equality refusal in
-- section 0 is dynamic SQL and runs only while the legacy columns exist; the orphan refusal runs always.
--
-- T-058 SUBSTITUTE (as KAN-798): production is not read here. Section 0 pins md5(prosrc), SECURITY INVOKER,
-- volatility, proconfig and owner of each pre-image. The pins equal the measured pre-image (baseline
-- 20260829080500:19384-19488 and :19668-19685 installed verbatim; no later migration in this tree redefines
-- either body; 20261013135000:152,160 only revokes PUBLIC/anon). Any drift fails closed: re-author from
-- pg_get_functiondef on the live catalogue in that case.

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
    raise exception 'KAN-804 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-804 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'event_id'
                  and attnum > 0 and not attisdropped) then
    raise exception 'KAN-804 pre: public.games.event_id missing (KAN-711 not applied)';
  end if;
  select string_agg(c, ', ') into v_bad
    from unnest(array['creator_user_id', 'geo_location_id', 'area_id', 'event_type']) c
   where not exists (select 1 from pg_attribute where attrelid = 'public.events'::regclass and attname = c
                      and attnum > 0 and not attisdropped);
  if v_bad is not null then
    raise exception 'KAN-804 pre: public.events lacks column(s): %', v_bad;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'postgres') then
    raise exception 'KAN-804 pre: role postgres missing';
  end if;
  select string_agg(r, ', ') into v_bad
    from unnest(array['anon', 'authenticated', 'service_role']) r
   where not exists (select 1 from pg_roles where rolname = r);
  if v_bad is not null then
    raise exception 'KAN-804 pre: role(s) missing: %', v_bad;
  end if;
  if to_regprocedure('public.kan804_game_event_facts(uuid)') is not null then
    raise exception 'KAN-804 pre: public.kan804_game_event_facts(uuid) already exists; re-triage';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w
        where w.name in ('trgfn_roster_block_frozen_guard', 'trgfn_posts_set_geo')) then
    raise exception 'KAN-804 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY INVOKER | volatility | proconfig | owner postgres
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text
                    || '|' || p.proconfig::text || '|' || p.proowner::regrole::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.trgfn_roster_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70'),
      ('public.trgfn_posts_set_geo()', 'a99a85249f7a15e5564a88a2afa163ba')
    ) as t(f, pin)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null
      or md5(p.prosrc) <> t.pin
      or p.prosecdef
      or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=public, pg_temp']
      or p.proowner <> 'postgres'::regrole;
  if v_bad is not null then
    raise exception 'KAN-804 pre: pre-image absent or drifted (re-author from pg_get_functiondef on the live catalogue): %', v_bad;
  end if;

  -- Every game has exactly its 'game' events parent (the helper's INNER join must not drop a row).
  select count(*) into v_n
    from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null;
  if v_n > 0 then
    raise exception 'KAN-804 pre: % games row(s) without a ''game'' events parent; reconcile first', v_n;
  end if;

  -- While a legacy column exists, it must equal its events counterpart (applying cannot change a result).
  if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'creator_user_id'
              and attnum > 0 and not attisdropped) then
    execute $q$select count(*) from public.games g
                 join public.events e on e.id = g.event_id and e.event_type = 'game'
                where e.creator_user_id is distinct from g.creator_user_id$q$ into v_n;
    if v_n > 0 then
      raise exception 'KAN-804 pre: % games row(s) whose creator_user_id differs from events; reconcile first', v_n;
    end if;
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'geo_location_id'
              and attnum > 0 and not attisdropped) then
    execute $q$select count(*) from public.games g
                 join public.events e on e.id = g.event_id and e.event_type = 'game'
                where e.geo_location_id is distinct from g.geo_location_id$q$ into v_n;
    if v_n > 0 then
      raise exception 'KAN-804 pre: % games row(s) whose geo_location_id differs from events; reconcile first', v_n;
    end if;
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'area_id'
              and attnum > 0 and not attisdropped) then
    execute $q$select count(*) from public.games g
                 join public.events e on e.id = g.event_id and e.event_type = 'game'
                where e.area_id is distinct from g.area_id$q$ into v_n;
    if v_n > 0 then
      raise exception 'KAN-804 pre: % games row(s) whose area_id differs from events; reconcile first', v_n;
    end if;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Capture what must not change.
-- ---------------------------------------------------------------------------------------------------------
create temp table kan804_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, p.proargtypes::text as argtypes, p.prorettype, p.prosecdef,
       p.provolatile, p.proconfig, p.proacl, p.proowner, p.proretset, p.proisstrict, p.proparallel,
       p.pronargdefaults, pg_get_function_arguments(p.oid) as args, pg_get_function_result(p.oid) as res,
       (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname)
          from pg_trigger t where t.tgfoid = p.oid and not t.tgisinternal) as trigdefs
  from pg_proc p
 where p.oid in ('public.trgfn_roster_block_frozen_guard()'::regprocedure,
                 'public.trgfn_posts_set_geo()'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 2a. Helper. Answers only for a caller that has already seen the games row (step 2b); service_role only.
-- ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan804_game_event_facts(p_game_id uuid)
 RETURNS TABLE(creator_user_id uuid, geo_location_id uuid, area_id uuid)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
  SELECT e.creator_user_id, e.geo_location_id, e.area_id
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.id = p_game_id;
$$;

ALTER FUNCTION public.kan804_game_event_facts(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.kan804_game_event_facts(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kan804_game_event_facts(uuid) TO service_role;

COMMENT ON FUNCTION public.kan804_game_event_facts(uuid) IS
  'KAN-804: events host/geo/area of a game for trgfn_roster_block_frozen_guard and trgfn_posts_set_geo. Called only '
  'after the invoker saw the games row (games RLS gate). No visibility filter of its own: never grant to a client role.';

-- ---------------------------------------------------------------------------------------------------------
-- 2b. Replacements. Header identical to the pre-image; body changed only at the games read.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."trgfn_roster_block_frozen_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare host_uid uuid;
  game_visible boolean;
begin
  -- KAN-804: games RLS gate as the calling role; the host comes from events only for a caller that sees the game.
  perform 1 from public.games g where g.id = new.game_id;
  game_visible := found;
  perform public.guard_user_not_frozen(new.user_id);
  if game_visible then
    select f.creator_user_id into host_uid from public.kan804_game_event_facts(new.game_id) f;
  end if;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."trgfn_posts_set_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_geo_id  uuid;
  v_area_id uuid;
  v_lat     double precision;
  v_lng     double precision;
  v_game_visible boolean;
BEGIN
  -- KAN-804: games RLS gate as the calling role; geo/area come from events only for a caller that sees the game.
  PERFORM 1 FROM public.games g WHERE g.id = NEW.game_id;
  v_game_visible := FOUND;

  -- PATH 1: Inherit from venue
  IF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id,
           ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
    INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
    FROM venues v
    JOIN geo_locations gl ON gl.id = v.geo_location_id
    WHERE v.id = NEW.venue_id;

  -- PATH 2: Inherit from game
  ELSIF NEW.game_id IS NOT NULL THEN
    IF v_game_visible THEN
      SELECT f.geo_location_id, f.area_id,
             ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
      INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
      FROM public.kan804_game_event_facts(NEW.game_id) f
      JOIN geo_locations gl ON gl.id = f.geo_location_id;
    ELSE
      -- the pre-image's SELECT ... INTO with no visible games row: every target NULL
      NEW.geo_location_id := NULL;
      NEW.area_id         := NULL;
      NEW.geo_lat         := NULL;
      NEW.geo_lng         := NULL;
    END IF;

  -- PATH 3: Manual lat/lng supplied
  ELSIF NEW.geo_lat IS NOT NULL AND NEW.geo_lng IS NOT NULL THEN
    v_lat := NEW.geo_lat;
    v_lng := NEW.geo_lng;

    SELECT id INTO v_area_id
    FROM areas
    ORDER BY ST_Distance(
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(
        (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
        (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
      ), 4326)::geography
    )
    LIMIT 1;

    INSERT INTO geo_locations (location, area_id, geohash)
    VALUES (
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      v_area_id,
      encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
    )
    RETURNING id INTO v_geo_id;

    NEW.geo_location_id := v_geo_id;
    NEW.area_id         := v_area_id;

  -- PATH 4: Fallback to author profile's last known location
  ELSE
    SELECT p.latitude, p.longitude
    INTO v_lat, v_lng
    FROM profiles p
    WHERE p.id = NEW.author_profile_id
      AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL;

    -- PATH 5: Last resort — use the most active area's center
    IF v_lat IS NULL THEN
      SELECT a.center_lat, a.center_lng
      INTO v_lat, v_lng
      FROM areas a
      WHERE a.is_active = true
      ORDER BY a.is_verified DESC, a.id
      LIMIT 1;
    END IF;

    -- Resolve nearest area
    SELECT id INTO v_area_id
    FROM areas
    ORDER BY ST_Distance(
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(
        (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
        (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
      ), 4326)::geography
    )
    LIMIT 1;

    INSERT INTO geo_locations (location, area_id, geohash)
    VALUES (
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      v_area_id,
      encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
    )
    RETURNING id INTO v_geo_id;

    NEW.geo_location_id := v_geo_id;
    NEW.area_id         := v_area_id;
    NEW.geo_lat         := v_lat;
    NEW.geo_lng         := v_lng;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions: same objects, attributes, ACL and trigger definitions; bodies gate on games and read
--    events through the helper; the helper is DEFINER, owner postgres, service_role-only.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
  v_h oid := to_regprocedure('public.kan804_game_event_facts(uuid)');
begin
  if (select count(*) from kan804_pre) <> 2 then
    raise exception 'KAN-804 post: captured % pre-image rows, expected 2', (select count(*) from kan804_pre);
  end if;
  select string_agg(b.fn, ', ') into v_bad
    from kan804_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or p.proargtypes::text <> b.argtypes
      or p.prorettype <> b.prorettype
      or p.prosecdef <> b.prosecdef
      or p.provolatile <> b.provolatile
      or p.proconfig is distinct from b.proconfig
      or p.proacl is distinct from b.proacl
      or p.proowner <> b.proowner
      or p.proretset <> b.proretset
      or p.proisstrict <> b.proisstrict
      or p.proparallel <> b.proparallel
      or p.pronargdefaults <> b.pronargdefaults
      or pg_get_function_arguments(p.oid) <> b.args
      or pg_get_function_result(p.oid) <> b.res
      or (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname)
            from pg_trigger t where t.tgfoid = p.oid and not t.tgisinternal) is distinct from b.trigdefs;
  if v_bad is not null then
    raise exception 'KAN-804 post: signature/attribute/ACL/owner/trigger definition changed for: %', v_bad;
  end if;

  select string_agg(b.fn, ', ') into v_bad
    from kan804_pre b
    join pg_proc p on p.oid = b.oid
   where p.prosrc !~* 'perform 1 from public\.games g where g\.id = new\.game_id;'
      or p.prosrc !~* 'public\.kan804_game_event_facts\(new\.game_id\) f'
      or p.prosrc ~ '\mg\.(creator_user_id|geo_location_id|area_id)\M';
  if v_bad is not null then
    raise exception 'KAN-804 post: body does not gate on games + read through the helper (or still names a removed games column): %', v_bad;
  end if;

  if v_h is null then
    raise exception 'KAN-804 post: helper missing';
  end if;
  select string_agg(x, ', ') into v_bad from (
    select 'not SECURITY DEFINER' x from pg_proc where oid = v_h and not prosecdef
    union all select 'not STABLE' from pg_proc where oid = v_h and provolatile <> 's'
    union all select 'proconfig ' || coalesce(proconfig::text, 'null') from pg_proc where oid = v_h
       and proconfig is distinct from array['search_path=public, pg_temp']
    union all select 'owner ' || proowner::regrole::text from pg_proc where oid = v_h and proowner <> 'postgres'::regrole
    union all select 'PUBLIC can execute' from pg_proc where oid = v_h
       and exists (select 1 from aclexplode(coalesce(proacl, acldefault('f', proowner))) a where a.grantee = 0)
    union all select r || ' can execute' from unnest(array['anon', 'authenticated']) r
     where has_function_privilege(r, v_h, 'EXECUTE')
    union all select 'service_role cannot execute' where not has_function_privilege('service_role', v_h, 'EXECUTE')
  ) s;
  if v_bad is not null then
    raise exception 'KAN-804 post: helper attributes/ACL wrong: %', v_bad;
  end if;
end
$post$;

commit;
