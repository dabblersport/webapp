-- KAN-862 (PEER comment 16219, Z01 blocker): the meetup create path writes its events parent itself and
-- names only the retained meetups columns, so it keeps working after Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql) drops the 21 shared meetups columns.
--
-- Authored from the live pg_get_functiondef, 2026-11-13, project wtncuzcskpigqpmnxwws:
--   public.rpc_create_meetup_legacy_v2(20 args)  functiondef md5 d6bc1a4403fc600a2a7cb471a011f60c (prosrc 88ed8d98d1da30de03ffd99747a4fab8)
--   public.kan712_legacy_guard()                 functiondef md5 a0899aa5803480f52ab2993a3a6c2559 (prosrc 30687c53fc53c229af23df616b9852a3)
-- CREATE OR REPLACE keeps owner, ACL, SECURITY, volatility and search_path; all are re-asserted below.
--
-- 1. rpc_create_meetup_legacy_v2: validations unchanged, in the same order. Only the INSERT INTO public.meetups
--    changes. The writer now
--      a. derives what the meetups BEFORE INSERT triggers derived from the old full row, in their order:
--         kan713_meetups_location (venue -> geo_location_id/area_id), kan713_meetups_joining
--         (meta.venue_space_id -> joining_rule/cost_cover, kan713_space_not_found / kan713_space_venue_mismatch),
--         fn_meetups_enforce_solo_sport (can_solo), kan611_stamp_request_id (thebes.create_request_id);
--      b. INSERTs the events parent (event_type 'meetup', id = the meetup id) with the guard's unique-violation
--         translation (events_type_creator_request_id_key -> meetups_creator_user_request_id_key);
--      c. INSERTs public.meetups naming only retained columns (id, event_id, host_actor_id, description,
--         location_name, members_only, vibe_key, meta, is_indoor);
--      d. reads joining_rule / cost_cover back from the events row (was RETURNING from meetups).
--    The host RSVP and the return value are unchanged. rpc_create_meetup (request_id idempotency) is unchanged.
-- 2. kan712_legacy_guard: one branch, INSERT on meetups only, honoured only for postgres/supabase_admin and only
--    for the row id the writer flagged in kan712.events_first. It copies the parent onto the legacy columns
--    (as branch 2a does for the compat UPDATE) instead of inserting a second parent, and recomputes search_tsv
--    (meetups_search_tsv_trigger ran before the title was on the row). Every other path is byte-identical.
--    The guard is attached only to meetups.trg_zz_kan712_meetups_guard (KAN-918 dropped the games one);
--    Z01 seq 304 drops that trigger, after which the branch is dead and the writer needs nothing from it.
-- Test: supabase/tests/events_p4/kan862_meetup_create_live_test.sql.

do $pre$
begin
  if md5(pg_get_functiondef(to_regprocedure('public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)')))
     is distinct from 'd6bc1a4403fc600a2a7cb471a011f60c' then
    raise exception 'KAN-862 pre: rpc_create_meetup_legacy_v2 absent or drifted';
  end if;
  if md5(pg_get_functiondef(to_regprocedure('public.kan712_legacy_guard()'))) is distinct from 'a0899aa5803480f52ab2993a3a6c2559' then
    raise exception 'KAN-862 pre: kan712_legacy_guard absent or drifted';
  end if;
end
$pre$;

CREATE OR REPLACE FUNCTION public.kan712_legacy_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_type     text := CASE TG_TABLE_NAME WHEN 'games' THEN 'game' WHEN 'meetups' THEN 'meetup' END;
  v_contract boolean := current_user IN ('postgres','supabase_admin') AND coalesce(current_setting('kan712.contract', true), '') = 'on';
  v_trusted  boolean := current_user IN ('postgres', 'supabase_admin');
  m          public.events;
  e          public.events;
  v_shared   boolean;
  v_con      text;
BEGIN
  IF v_type IS NULL OR TG_WHEN <> 'BEFORE' OR TG_LEVEL <> 'ROW' THEN
    RAISE EXCEPTION 'kan712_legacy_guard: unsupported attachment %.% % %', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_WHEN, TG_LEVEL;
  END IF;

  -- KAN-862 events-first INSERT (meetups): rpc_create_meetup_legacy_v2 has inserted the events parent and names
  -- only the retained meetups columns. Copy the parent onto the legacy columns instead of inserting a second
  -- parent. Honoured only for a trusted caller and only for the row id the writer flagged.
  IF TG_OP = 'INSERT' AND v_type = 'meetup' AND v_trusted
     AND coalesce(current_setting('kan712.events_first', true), '') = NEW.id::text THEN
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('%s %s', TG_TABLE_NAME, NEW.id);
    END IF;
    IF NEW.event_id IS NULL THEN
      NEW.event_id := NEW.id;
    END IF;
    NEW.creator_profile_id := e.creator_profile_id; NEW.creator_user_id := e.creator_user_id;
    NEW.title := e.title; NEW.start_at := e.start_at; NEW.end_at := e.end_at; NEW.capacity := e.capacity;
    NEW.listing_visibility := e.listing_visibility; NEW.is_cancelled := e.is_cancelled;
    NEW.sport_id := e.sport_id; NEW.area_id := e.area_id; NEW.geo_location_id := e.geo_location_id;
    NEW.venue_id := e.venue_id; NEW.min_skill := e.min_skill; NEW.max_skill := e.max_skill;
    NEW.joining_rule := e.joining_rule; NEW.cost_cover := e.cost_cover; NEW.request_id := e.request_id;
    NEW.created_at := e.created_at; NEW.updated_at := e.updated_at;
    NEW.rsvp_policy := e.join_policy;
    NEW.search_tsv :=                       -- meetups_search_tsv_trigger, now that the title is on the row
        setweight(to_tsvector('simple', coalesce(NEW.title,'')), 'A') ||
        setweight(to_tsvector('simple', coalesce(NEW.description,'')), 'B') ||
        setweight(to_tsvector('simple', coalesce(NEW.location_name,'')), 'C');
    RETURN NEW;
  END IF;

  -- 2a. Compat write (events -> legacy): events is authoritative; copy its values onto NEW, including
  -- updated_at (legacy touch triggers set now()). Nothing is written to events here. Honoured only when
  -- nested inside the compat mirror (trigger depth > 1): a session-level SET kan712.compat is ignored.
  IF TG_OP = 'UPDATE' AND pg_trigger_depth() > 1
     AND coalesce(current_setting('kan712.compat', true), '') = NEW.id::text THEN
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('%s %s', TG_TABLE_NAME, NEW.id);
    END IF;
    NEW.creator_profile_id := e.creator_profile_id; NEW.creator_user_id := e.creator_user_id;
    NEW.title := e.title; NEW.start_at := e.start_at; NEW.end_at := e.end_at; NEW.capacity := e.capacity;
    NEW.listing_visibility := e.listing_visibility; NEW.is_cancelled := e.is_cancelled;
    NEW.sport_id := e.sport_id; NEW.area_id := e.area_id; NEW.geo_location_id := e.geo_location_id;
    NEW.venue_id := e.venue_id; NEW.min_skill := e.min_skill; NEW.max_skill := e.max_skill;
    NEW.joining_rule := e.joining_rule; NEW.cost_cover := e.cost_cover; NEW.request_id := e.request_id;
    NEW.created_at := e.created_at; NEW.updated_at := e.updated_at;
    IF v_type = 'game' THEN
      NEW.join_policy := e.join_policy; NEW.cancelled_at := e.cancelled_at; NEW.cancelled_reason := e.cancelled_reason;
    ELSE
      NEW.rsvp_policy := e.join_policy;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan712_id_immutable';
  END IF;
  IF NEW.event_id IS NULL THEN
    NEW.event_id := NEW.id;                -- KAN-711's assign trigger normally did this already
  END IF;

  -- 2b. Map NEW (final legacy values: this trigger sorts last among BEFORE triggers).
  m.id := NEW.id; m.event_type := v_type;
  m.creator_profile_id := NEW.creator_profile_id; m.creator_user_id := NEW.creator_user_id;
  m.title := NEW.title; m.start_at := NEW.start_at; m.end_at := NEW.end_at; m.capacity := NEW.capacity;
  m.listing_visibility := NEW.listing_visibility; m.is_cancelled := NEW.is_cancelled;
  m.sport_id := NEW.sport_id; m.area_id := NEW.area_id; m.geo_location_id := NEW.geo_location_id;
  m.venue_id := NEW.venue_id; m.min_skill := NEW.min_skill::smallint; m.max_skill := NEW.max_skill::smallint;
  m.joining_rule := NEW.joining_rule; m.cost_cover := NEW.cost_cover; m.request_id := NEW.request_id;
  m.created_at := NEW.created_at; m.updated_at := NEW.updated_at;
  IF v_type = 'game' THEN
    m.join_policy := NEW.join_policy; m.cancelled_at := NEW.cancelled_at; m.cancelled_reason := NEW.cancelled_reason;
  ELSE
    m.join_policy := NEW.rsvp_policy; m.cancelled_at := NULL; m.cancelled_reason := NULL;
  END IF;

  -- 2c. INSERT: parent first. A unique_violation on the parent's request key is re-raised under the
  -- legacy key name, so the KAN-611 create wrappers (which only catch
  -- <table>_creator_user_request_id_key) keep their replay semantics. Same creator profile implies
  -- the same creator user, so the legacy key would have collided too.
  IF TG_OP = 'INSERT' THEN
    BEGIN
      INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
             capacity, listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id,
             area_id, geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id,
             created_at, updated_at)
      VALUES (m.id, m.event_type, m.creator_profile_id, m.creator_user_id, m.title, m.start_at, m.end_at,
             m.capacity, m.listing_visibility, m.join_policy, m.is_cancelled, m.cancelled_at, m.cancelled_reason,
             m.sport_id, m.area_id, m.geo_location_id, m.venue_id, m.min_skill, m.max_skill, m.joining_rule,
             m.cost_cover, m.request_id, m.created_at, m.updated_at);
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      IF v_con = 'events_type_creator_request_id_key' THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
          CONSTRAINT = TG_TABLE_NAME || '_creator_user_request_id_key',
          MESSAGE = format('duplicate key value violates unique constraint "%s_creator_user_request_id_key"', TG_TABLE_NAME),
          DETAIL = format('kan712: events parent for request_id %s already exists', m.request_id);
      END IF;
      RAISE;
    END;
    RETURN NEW;
  END IF;

  -- 2d. UPDATE from a legacy write. Lock the parent: a wrapped RPC already holds it (events first),
  -- so the wait is a no-op; any other writer already holds the legacy row and must not wait on
  -- events (that is the deadlock shape), so it fails fast with 55P03 instead.
  IF v_contract THEN
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type FOR UPDATE;
  ELSE
    SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = v_type FOR UPDATE NOWAIT;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('%s %s', TG_TABLE_NAME, NEW.id);
  END IF;

  v_shared := ROW(m.creator_profile_id, m.creator_user_id, m.title, m.start_at, m.end_at, m.capacity,
                  m.listing_visibility, m.join_policy, m.is_cancelled, m.cancelled_at, m.cancelled_reason,
                  m.sport_id, m.area_id, m.geo_location_id, m.venue_id, m.min_skill, m.max_skill,
                  m.joining_rule, m.cost_cover, m.request_id, m.created_at)
              IS DISTINCT FROM
              ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
                  e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
                  e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
                  e.joining_rule, e.cost_cover, e.request_id, e.created_at);

  IF v_shared AND NOT v_contract AND NOT v_trusted THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'kan712_direct_shared_write_refused',
      DETAIL = format('%s %s: shared fields are owned by public.events since KAN-712 (role %s)', TG_TABLE_NAME, NEW.id, current_user),
      HINT = 'Use the owning RPC, or public.kan712_update_event_shared(event_id, patch).';
  END IF;

  IF v_shared OR m.updated_at IS DISTINCT FROM e.updated_at THEN
    PERFORM set_config('kan712.routing', NEW.id::text, true);
    PERFORM set_config('kan711.src_updated_at', m.updated_at::text, true);   -- KAN-711 keeper semantics
    UPDATE public.events SET
      creator_profile_id = m.creator_profile_id, creator_user_id = m.creator_user_id, title = m.title,
      start_at = m.start_at, end_at = m.end_at, capacity = m.capacity, listing_visibility = m.listing_visibility,
      join_policy = m.join_policy, is_cancelled = m.is_cancelled, cancelled_at = m.cancelled_at,
      cancelled_reason = m.cancelled_reason, sport_id = m.sport_id, area_id = m.area_id,
      geo_location_id = m.geo_location_id, venue_id = m.venue_id, min_skill = m.min_skill,
      max_skill = m.max_skill, joining_rule = m.joining_rule, cost_cover = m.cost_cover,
      request_id = m.request_id, created_at = m.created_at, updated_at = m.updated_at
    WHERE id = NEW.id;
    PERFORM set_config('kan711.src_updated_at', '', true);
    PERFORM set_config('kan712.routing', '', true);
  END IF;
  RETURN NEW;
END $function$;

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

  RETURN mid;
END;
$function$;

do $post$
declare
  r record;
begin
  select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p
   where p.oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure;
  if r.acl <> '{postgres=X/postgres,service_role=X/postgres}' or r.prosecdef is not true or r.vol <> 'v'
     or r.cfg <> 'search_path=public, pg_temp' or r.own <> 'postgres' then
    raise exception 'KAN-862 post: rpc_create_meetup_legacy_v2 attributes drifted: %', r;
  end if;
  select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p where p.oid = 'public.kan712_legacy_guard()'::regprocedure;
  if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not false or r.vol <> 'v'
     or r.cfg <> 'search_path=""' or r.own <> 'postgres' then
    raise exception 'KAN-862 post: kan712_legacy_guard attributes drifted: %', r;
  end if;
end
$post$;
