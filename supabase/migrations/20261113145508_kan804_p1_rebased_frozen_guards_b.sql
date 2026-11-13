-- KAN-804 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104110900_kan804_d04_blockers_frozen_guards_b.sql (authored, never applied).
--
-- WHAT: the roster frozen guard and trgfn_posts_set_geo PATH 2 keep the games RLS gate as the calling role and
--   read host/geo/area from the new DEFINER helper kan804_game_event_facts(uuid), service_role only
--   (ruling dreq-9bc08a26 option (i)).
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.trgfn_roster_block_frozen_guard()  e9e1d50b5a46d1daefc73f295b8c0b70 -> 2429035e07db8daa686fe873e204d183
--   public.trgfn_posts_set_geo()  a99a85249f7a15e5564a88a2afa163ba -> 0c8944fe8e54448f7dc76f7def862f74
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan804_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan804 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.trgfn_roster_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70', '2429035e07db8daa686fe873e204d183'),
    ('public.trgfn_posts_set_geo()', 'a99a85249f7a15e5564a88a2afa163ba', '0c8944fe8e54448f7dc76f7def862f74')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan804 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan804 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pin;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  if to_regprocedure('public.kan804_game_event_facts(uuid)') is not null then
    raise exception 'kan804 pre: helper public.kan804_game_event_facts(uuid) already exists';
  end if;
  select count(*) into v_n from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null;
  if v_n > 0 then
    raise exception 'kan804 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['creator_user_id', 'geo_location_id', 'area_id'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan804 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan804.attr', v_attr::text, true);
end
$pre$;

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

do $post$
declare
  r record; v_attr jsonb := current_setting('kan804.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.trgfn_roster_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70', '2429035e07db8daa686fe873e204d183'),
    ('public.trgfn_posts_set_geo()', 'a99a85249f7a15e5564a88a2afa163ba', '0c8944fe8e54448f7dc76f7def862f74')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan804 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan804 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
  if (select proacl::text from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)')) is distinct from '{postgres=X/postgres,service_role=X/postgres}'
     or (select pg_get_userbyid(proowner) from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)')) <> 'postgres'
     or not (select prosecdef from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)'))
     or (select provolatile from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)')) <> 's'
     or (select proconfig from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)')) is distinct from array['search_path=public, pg_temp'] then
    raise exception 'kan804 post: helper public.kan804_game_event_facts(uuid) attributes/ACL wrong (acl %)', (select proacl::text from pg_proc where oid = to_regprocedure('public.kan804_game_event_facts(uuid)'));
  end if;
end
$post$;
