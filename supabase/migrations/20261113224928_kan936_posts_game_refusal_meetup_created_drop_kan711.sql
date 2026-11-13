-- KAN-936: (1) trgfn_posts_set_geo refuses a game-tied post whose games row the caller cannot see with
-- P0001 game_not_found, instead of leaving geo_lat NULL for the NOT NULL check (23502); the visible-game
-- path is unchanged. (2) rpc_create_meetup_legacy_v2 and run_seed_meetup_template emit meetup.created,
-- as trgfn_meetups_outbox did before Z01 (emit_event is a no-op shim today). (3) The dead kan711 tooling
-- that names dropped meetups columns is dropped, with kan711_events_parity, the postgres-only view that
-- depends on kan711_events_map_meetup, cannot run (42P01 from the function) and is read only by
-- kan711_events_validate_links. Bodies authored from pg_get_functiondef on the live catalogue; CREATE OR
-- REPLACE keeps proacl, owner, SECURITY and search_path, asserted at the end.
DO $pin$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trgfn_posts_set_geo()'::regprocedure)
     IS DISTINCT FROM '0c8944fe8e54448f7dc76f7def862f74' THEN
    RAISE EXCEPTION 'kan936: trgfn_posts_set_geo drifted from the pinned body';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure)
     IS DISTINCT FROM '8e8997841daedd511ace2bcac8e6cc94' THEN
    RAISE EXCEPTION 'kan936: rpc_create_meetup_legacy_v2 drifted from the pinned body';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure)
     IS DISTINCT FROM '7ede1ba291875dc5c4dcc75cb7ce1f10' THEN
    RAISE EXCEPTION 'kan936: run_seed_meetup_template drifted from the pinned body';
  END IF;
END $pin$;

CREATE OR REPLACE FUNCTION public.trgfn_posts_set_geo()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
      -- KAN-936: the caller cannot see the games row (or it does not exist); refuse clearly instead
      -- of leaving geo_lat NULL for the NOT NULL check (23502).
      RAISE EXCEPTION USING errcode = 'P0001', message = 'game_not_found';
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
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_meetup_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean)
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
  v_e               public.events;
  v_venue_id        uuid;
  v_geo_id          uuid;
  v_area_id         uuid;
  v_venue_geo       uuid;
  v_venue_area      uuid;
  v_space_txt       text;
  v_space_id        uuid;
  v_space_found     boolean;
  v_space_venue     uuid;
  v_space_rule      text;
  v_can_solo        boolean;
  v_req             uuid;
  v_con             text;
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

  -- KAN-862: what the meetups BEFORE INSERT triggers derived from the full row, in their order.
  mid        := gen_random_uuid();
  v_venue_id := p_venue_id;
  v_geo_id   := p_geo_location_id;
  v_area_id  := p_area_id;
  -- kan713_meetups_location: a venue's geo location and area win.
  IF v_venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id INTO v_venue_geo, v_venue_area
      FROM public.venues        v
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = v_venue_id;
    IF v_venue_geo IS NOT NULL THEN
      v_geo_id  := v_venue_geo;
      v_area_id := v_venue_area;
    END IF;
  END IF;
  -- kan713_meetups_joining (INSERT): meta.venue_space_id decides joining_rule / cost_cover.
  v_space_txt := COALESCE(p_meta, '{}'::jsonb)->>'venue_space_id';
  IF v_space_txt ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    v_space_id := v_space_txt::uuid;
    SELECT true, vs.venue_id, vs.joining_rule INTO v_space_found, v_space_venue, v_space_rule
      FROM public.venue_spaces vs WHERE vs.id = v_space_id;
  END IF;
  IF v_space_txt IS NOT NULL AND v_space_found IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan713_space_not_found',
      DETAIL = format('meetups %s: meta.venue_space_id %s does not exist', mid, v_space_txt);
  END IF;
  IF v_space_venue IS NOT NULL AND v_venue_id IS NOT NULL AND v_venue_id <> v_space_venue THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
      DETAIL = format('meetups %s: venue %s is not the venue (%s) of space %s', mid, v_venue_id, v_space_venue, v_space_id);
  END IF;
  IF v_space_id IS NOT NULL THEN
    v_joining_rule := COALESCE(v_space_rule, 'free');
    v_cost_cover   := v_joining_rule;
  ELSE
    v_joining_rule := 'free';
    v_cost_cover   := 'free';
  END IF;
  -- fn_meetups_enforce_solo_sport
  IF p_sport_id IS NOT NULL THEN
    SELECT s.can_solo INTO v_can_solo FROM public.sports s WHERE s.id = p_sport_id;
    IF v_can_solo IS DISTINCT FROM true THEN
      RAISE EXCEPTION
        'Meetups can only be created for solo-friendly sports (can_solo = true). sport_id: %',
        p_sport_id;
    END IF;
  END IF;
  -- kan611_stamp_request_id
  v_req := nullif(current_setting('thebes.create_request_id', true), '')::uuid;

  -- KAN-862: the events parent carries the shared fields (what kan712_legacy_guard 2c inserted).
  BEGIN
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
           capacity, listing_visibility, join_policy, sport_id, area_id, geo_location_id, venue_id,
           min_skill, max_skill, joining_rule, cost_cover, request_id)
    VALUES (mid, 'meetup', pid, uid, p_title, p_start_at, p_end_at,
           v_final_capacity, 'public', p_rsvp_policy, p_sport_id, v_area_id, v_geo_id, v_venue_id,
           p_min_skill::smallint, p_max_skill::smallint, v_joining_rule, v_cost_cover, v_req)
    RETURNING * INTO v_e;
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
    IF v_con = 'events_type_creator_request_id_key' THEN
      RAISE EXCEPTION USING ERRCODE = '23505',
        CONSTRAINT = 'meetups_creator_user_request_id_key',
        MESSAGE = 'duplicate key value violates unique constraint "meetups_creator_user_request_id_key"',
        DETAIL = format('kan712: events parent for request_id %s already exists', v_req);
    END IF;
    RAISE;
  END;

  -- KAN-862: the subtype row holds only the meetup-only columns. While trg_zz_kan712_meetups_guard is
  -- attached, kan712.events_first tells it to copy the parent onto the legacy columns.
  PERFORM set_config('kan712.events_first', mid::text, true);
  INSERT INTO public.meetups (id, event_id, host_actor_id, description, location_name, members_only, vibe_key, meta, is_indoor)
  VALUES (
    mid,
    mid,
    pid,  -- KAN-717 F6: NOT NULL, no default; the host is the acting creator profile
    p_description,
    p_location_name,
    p_members_only,
    p_vibe_key,
    COALESCE(p_meta, '{}'),
    CASE WHEN p_venue_id IS NULL THEN p_is_indoor ELSE NULL END
  );
  PERFORM set_config('kan712.events_first', '', true);

  v_joining_rule := v_e.joining_rule;
  v_cost_cover   := v_e.cost_cover;
  IF v_joining_rule <> 'free' OR v_cost_cover <> 'free' THEN
    RAISE EXCEPTION USING errcode='P0001', message='free_meetups_only';
  END IF;

  -- The host is the first 'going' RSVP (meetup_rsvps is the source of truth).
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
  VALUES (mid, uid, pid, 'going')
  ON CONFLICT (meetup_id, user_id) DO UPDATE
    SET status = 'going', profile_id = EXCLUDED.profile_id, updated_at = now();

  -- KAN-936: meetup.created, as trgfn_meetups_outbox emitted it before Z01 (emit_event is a no-op shim today).
  PERFORM public.emit_event('meetup.created', 'meetup', mid, uid, jsonb_build_object('start_at', p_start_at));

  RETURN mid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_seed_meetup_template(p_template_id uuid, p_config jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_city text:=trim(p_config->>'city'); v_title text:=trim(p_config->>'title');
 v_zone text:=coalesce(nullif(p_config->>'timezone',''),'Asia/Dubai');
 v_day date; v_start timestamptz; v_end timestamptz;
 v_days int:=coalesce((p_config->>'days_ahead')::int,2);
 v_hour int:=coalesce((p_config->>'start_hour')::int,18);
 v_duration int:=coalesce((p_config->>'duration_minutes')::int,60);
 v_cap int:=coalesce((p_config->>'capacity')::int,8);
 v_going int:=coalesce((p_config->>'seed_going')::int,3);
 v_interested int:=coalesce((p_config->>'seed_interested')::int,2);
 v_sport uuid; v_host public.profiles%rowtype;
 v_venue uuid:=nullif(p_config->>'venue_id','')::uuid;
 v_geo uuid:=nullif(p_config->>'geo_location_id','')::uuid;
 v_area uuid; v_loc text:=trim(p_config->>'location_name');
 v_auto boolean:=coalesce((p_config->>'auto_venue')::boolean,false); v_space uuid; v_indoor boolean:=(p_config->>'is_indoor')::boolean; v_entry_cost text; v_mid uuid; v_request uuid; v_row record; v_n int:=0; v_g int; v_i int;
 v_jr text; v_con text;
BEGIN
 IF current_user <> 'service_role' THEN RAISE EXCEPTION 'service_role_required'; END IF;
 IF p_template_id IS NULL OR v_city IS NULL OR char_length(v_title) NOT BETWEEN 3 AND 80 THEN RAISE EXCEPTION 'template_city_or_title_invalid'; END IF;
 IF v_days NOT BETWEEN 1 AND 14 OR v_hour NOT BETWEEN 0 AND 23 OR v_duration NOT BETWEEN 30 AND 240 OR v_cap NOT BETWEEN 1 AND 30 OR v_going NOT BETWEEN 1 AND v_cap OR v_interested NOT BETWEEN 0 AND 8 THEN RAISE EXCEPTION 'schedule_capacity_or_seed_count_invalid'; END IF;
 IF NOT EXISTS(select 1 from pg_timezone_names where name=v_zone) THEN RAISE EXCEPTION 'invalid_timezone'; END IF;
 v_day:=(now() AT TIME ZONE v_zone)::date;
 v_request:=md5('app_traffic_meetup:'||p_template_id::text||':'||v_day::text)::uuid;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 SELECT mt.id INTO v_mid FROM public.meetups mt JOIN public.events ev ON ev.id=mt.id AND ev.event_type='meetup'
  WHERE ev.request_id=v_request AND mt.meta->>'source'='app_traffic_seed' LIMIT 1;
 IF FOUND THEN RETURN jsonb_build_object('template_id',p_template_id,'status','skipped','meetup_id',v_mid,'message','Already created for this local day'); END IF;
 SELECT id INTO v_sport FROM public.sports WHERE sport_key=p_config->>'sport_key' AND is_active AND can_solo;
 IF v_sport IS NULL THEN RAISE EXCEPTION 'sport_must_be_active_and_solo_friendly'; END IF;
 SELECT * INTO v_host FROM public.profiles p WHERE p.is_original=false AND p.is_active AND p.city=v_city AND p.primary_sport=v_sport
 AND (p.persona_type IN ('player','organiser') OR (p.persona_type='contributor' AND (exists(select 1 from public.player x where x.profile_id=p.id) OR exists(select 1 from public.organiser x where x.profile_id=p.id))))
 ORDER BY md5(p.id::text||v_day::text) LIMIT 1;
 IF v_host.id IS NULL THEN RAISE EXCEPTION 'no_eligible_seed_host_in_city'; END IF;
 
 IF v_auto THEN
   SELECT v.id,vs.id,v.geo_location_id,gl.area_id,v.name_en,vs.indoor,coalesce(v.access_type,'unknown')
   INTO v_venue,v_space,v_geo,v_area,v_loc,v_indoor,v_entry_cost
   FROM public.venues v
   JOIN public.geo_locations gl ON gl.id=v.geo_location_id JOIN public.areas a ON a.id=gl.area_id
   JOIN public.venue_spaces vs ON vs.venue_id=v.id AND vs.sport_id=v_sport
   WHERE a.city=v_city AND v.is_active AND vs.is_active
     AND v.name_en !~* '(ladies|women|female|men[ -]?only|male[ -]?only)'
     AND (p_config->>'sport_key')=ANY(v.sports) AND vs.joining_rule='free'
   ORDER BY md5(v.id::text||p_template_id::text||v_day::text),vs.id LIMIT 1;
   IF v_venue IS NULL THEN RETURN jsonb_build_object('template_id',p_template_id,'status','skipped','message','No active Supabase venue and sport space match this city and sport'); END IF;
 END IF;
 IF v_venue IS NOT NULL THEN
   SELECT v.geo_location_id,gl.area_id,coalesce(nullif(v_loc,''),v.name_en) INTO v_geo,v_area,v_loc
   FROM public.venues v JOIN public.geo_locations gl ON gl.id=v.geo_location_id JOIN public.areas a ON a.id=gl.area_id
   WHERE v.id=v_venue AND v.is_active AND a.city=v_city AND (v_auto OR v.access_type='free');
   IF NOT FOUND THEN RAISE EXCEPTION 'venue_must_be_active_free_and_in_city'; END IF;
 ELSE
   IF v_geo IS NULL OR nullif(v_loc,'') IS NULL OR NOT(p_config ? 'is_indoor') THEN RAISE EXCEPTION 'location_name_geo_and_indoor_required'; END IF;
   SELECT gl.area_id INTO v_area FROM public.geo_locations gl JOIN public.areas a ON a.id=gl.area_id WHERE gl.id=v_geo AND a.city=v_city;
   IF NOT FOUND THEN RAISE EXCEPTION 'geo_location_not_in_city'; END IF;
 END IF;
 v_start:=((v_day+v_days)+make_time(v_hour,0,0)) AT TIME ZONE v_zone;
 v_end:=v_start+make_interval(mins=>v_duration);
 -- KAN-862: what the meetups BEFORE INSERT triggers derived. Geo/area: the venue's (kan713_meetups_location,
 -- fn_meetups_inherit_geo), already read above. joining_rule/cost_cover: fn_meetups_sync_joining_rule runs last and
 -- decides (venue_spaces row keyed by coalesce(venue_id, meta.venue_space_id), else 'free'; cost_cover follows).
 -- kan713_meetups_joining cannot raise here: v_space is read from venue_spaces joined to v_venue.
 v_mid:=gen_random_uuid();
 v_jr:='free';
 IF coalesce(v_venue,v_space) IS NOT NULL THEN
   SELECT vs.joining_rule INTO v_jr FROM public.venue_spaces vs WHERE vs.id=coalesce(v_venue,v_space);
   v_jr:=coalesce(v_jr,'free');
 END IF;
 BEGIN
   INSERT INTO public.events(id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,sport_id,venue_id,geo_location_id,area_id,joining_rule,cost_cover,request_id)
   VALUES(v_mid,'meetup',v_host.id,v_host.user_id,v_title,v_start,v_end,v_cap,'public','open',v_sport,v_venue,v_geo,v_area,v_jr,v_jr,v_request);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
   IF v_con = 'events_type_creator_request_id_key' THEN
     RAISE EXCEPTION USING ERRCODE = '23505', CONSTRAINT = 'meetups_creator_user_request_id_key',
       MESSAGE = 'duplicate key value violates unique constraint "meetups_creator_user_request_id_key"',
       DETAIL = format('kan712: events parent for request_id %s already exists', v_request);
   END IF;
   RAISE;
 END;
 PERFORM set_config('kan712.events_first', v_mid::text, true);
 INSERT INTO public.meetups(id,event_id,host_actor_id,description,location_name,is_indoor,members_only,meta)
 VALUES(v_mid,v_mid,v_host.id,concat_ws(E'\n\n',p_config->>'description',CASE WHEN v_auto THEN 'Meetup participation is free. Venue admission, membership and booking requirements are separate; confirm directly with the venue before attending.' ELSE NULL END),v_loc,v_indoor,false,jsonb_build_object('source','app_traffic_seed','notion_template_id',p_template_id,'seed_day',v_day,'venue_space_id',v_space,'venue_entry_cost',v_entry_cost,'venue_source','supabase'));
 PERFORM set_config('kan712.events_first', '', true);
 INSERT INTO public.meetup_rsvps(meetup_id,user_id,profile_id,status) VALUES(v_mid,v_host.user_id,v_host.id,'going');
 FOR v_row IN SELECT DISTINCT ON (p.user_id) p.id,p.user_id FROM public.profiles p WHERE p.is_original=false AND p.is_active AND p.city=v_city AND p.user_id<>v_host.user_id ORDER BY p.user_id,p.created_at LOOP
   EXIT WHEN v_n >= (v_going-1+v_interested);
   INSERT INTO public.meetup_rsvps(meetup_id,user_id,profile_id,status)
   VALUES(v_mid,v_row.user_id,v_row.id,CASE WHEN v_n<v_going-1 THEN 'going' ELSE 'interested' END) ON CONFLICT(meetup_id,user_id) DO NOTHING;
   v_n:=v_n+1;
 END LOOP;
 SELECT count(*) FILTER(WHERE status='going'), count(*) FILTER(WHERE status='interested') INTO v_g,v_i FROM public.meetup_rsvps WHERE meetup_id=v_mid;
 -- KAN-936: meetup.created, as trgfn_meetups_outbox emitted it before Z01 (emit_event is a no-op shim today).
 PERFORM public.emit_event('meetup.created','meetup',v_mid,v_host.user_id,jsonb_build_object('start_at',v_start));
 RETURN jsonb_build_object('template_id',p_template_id,'status','success','meetup_id',v_mid,'going',v_g,'interested',v_i,'start_at',v_start,'location_name',v_loc,'venue_id',v_venue,'venue_space_id',v_space,'venue_entry_cost',v_entry_cost);
EXCEPTION WHEN OTHERS THEN
 RETURN jsonb_build_object('template_id',p_template_id,'status','error','message',SQLERRM);
END $function$;

-- (3) dead kan711 tooling. No CASCADE: an unexpected dependent makes this fail instead of vanishing.
DROP FUNCTION public.kan711_events_validate_links();
DROP PROCEDURE public.kan711_events_backfill_run(integer, integer);
DROP FUNCTION public.kan711_events_backfill_batch(text, integer);
DROP FUNCTION public.kan711_meetups_mirror();
DROP VIEW public.kan711_events_parity;
DROP FUNCTION public.kan711_events_map_meetup(public.meetups);

DO $post$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig, md5(p.prosrc) AS h, p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl
      FROM pg_proc p
     WHERE p.oid IN ('public.trgfn_posts_set_geo()'::regprocedure,
                     'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure,
                     'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure)
  LOOP
    IF r.owner <> 'postgres' OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
       OR r.acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
       OR r.prosecdef IS DISTINCT FROM (r.sig::text LIKE 'rpc_create_meetup_legacy_v2%') THEN
      RAISE EXCEPTION 'kan936: attributes drifted on %: owner % config % acl % secdef %', r.sig, r.owner, r.proconfig, r.acl, r.prosecdef;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname IN ('kan711_events_map_meetup','kan711_events_backfill_batch',
                    'kan711_meetups_mirror','kan711_events_backfill_run','kan711_events_validate_links'))
     OR to_regclass('public.kan711_events_parity') IS NOT NULL THEN
    RAISE EXCEPTION 'kan936: kan711 tooling still present';
  END IF;
END $post$;
