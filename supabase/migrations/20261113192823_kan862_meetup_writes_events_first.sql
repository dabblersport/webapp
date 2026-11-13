-- KAN-862 (Z01 blocker): the meetup write paths read and write the Z01-dropped meetups columns on public.events and
-- name only the retained meetups columns (id, event_id, vibe_key, meta, host_actor_id, members_only, description,
-- location_name, is_indoor), so they keep working after Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql) drops the 21 shared meetups columns.
--
-- Authored from the live pg_get_functiondef, 2026-11-13, project wtncuzcskpigqpmnxwws. The pre-image guard pins
-- md5(prosrc) (functiondef md5 in brackets):
--   rpc_meetup_cancel_kan712_inner(uuid)                 dbb3088138a9e241d19ee3dca5f4c20d [a827290b2a6a749f59e98a780cc89b71]
--   rpc_meetup_update_kan712_inner(uuid,text,text,timestamptz,timestamptz,text,integer)
--                                                        59a27e5f0d23c4c2593e585cb0a6bd40 [6c357ce1fd97675998d30cc229d5b81c]
--   run_seed_meetup_template(uuid,jsonb)                 74e763538070a1460fa4e1dc62f7cdf6 [de1270d7244933175cafb96e136b90b1]
--   rpc_meetup_set_attendee(uuid,uuid,text)              118f1db9bf66dff0d4a275c89b3703de [f66e31db4988c3218aec04b4f16e1a9c]
--   rpc_meetup_invite_user(uuid,uuid,timestamptz)        08d8cc7c0d7b99653b81d9cbeaf33b82 [6f30c21082fde8ab6da9c6e64cb4f143]
--   rpc_meetup_mint_link(uuid,timestamptz,integer)       2364638777f63f9f8fe6fa9e704b4153 [755c5c568e6f3d64b7d1e1c3f705976b]
--   kan712_legacy_guard()                                95d3f5da60e5647ed84a55ad1fa0fdce [014caa191a39c6489e6dcb76c9b4b95b]
-- CREATE OR REPLACE keeps owner, ACL, SECURITY, volatility and search_path; all are re-asserted below.
--
-- 1. rpc_meetup_cancel_kan712_inner: host/admin check reads events.creator_user_id. Cancel writes events
--    (is_cancelled, updated_at) where it wrote meetups. On a real transition it then
--      a. touches the meetups row (SET is_indoor = is_indoor) flagged in kan712.events_first: the guard copies the
--         events row onto the legacy columns (parity) and does not route back into events (no double write); the
--         meetups AFTER triggers (activity sync, outbox, kan711 mirror) fire as before;
--      b. sends the 'meetup.cancelled' notifications itself, exactly as trg_meetups_cancel_notify did. That trigger
--         is AFTER UPDATE OF is_cancelled and no longer fires (the statement no longer names is_cancelled), so the
--         notifications are sent once. They also survive Z01, which drops that trigger (seq 324).
-- 2. rpc_meetup_update_kan712_inner: reads and locks events + meetups; same validations and errors in the same
--    order; writes title/start_at/end_at/capacity/updated_at on events and description/location_name on meetups
--    (flagged, as 1a). Return value unchanged (rpc_meetup_card).
-- 3. run_seed_meetup_template: idempotency lookup reads events.request_id. Writes the events parent first
--    (event_type 'meetup'), deriving what the meetups BEFORE INSERT triggers derived (geo/area from the venue,
--    joining_rule/cost_cover as fn_meetups_sync_joining_rule, which runs last, decided), then the meetups row with
--    retained columns only; host_actor_id = the seed host profile. Unique violations keep the legacy key name.
-- 4. rpc_meetup_set_attendee / rpc_meetup_invite_user / rpc_meetup_mint_link: raised 42703 on m.owner_user_id (no such
--    column; it is the pre-rename name of creator_user_id, see 20260912190747 and 20260915120000). The owner is now
--    events.creator_user_id; invite/mint keep their is_admin path, set_attendee keeps can_write_row (owner or admin).
-- 5. kan712_legacy_guard: the KAN-862 events-first branch now also takes UPDATE (it took INSERT only) and accepts
--    service_role as well as postgres/supabase_admin (run_seed_meetup_template is SECURITY INVOKER as service_role).
--    Still honoured only for the row id the writer flagged. Every other path is byte-identical. Z01 seq 304 drops the
--    trigger, after which the branch is dead and the writers need nothing from it.
-- Test: supabase/tests/events_p4/kan862_meetup_writes_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.rpc_meetup_cancel_kan712_inner(uuid)', 'dbb3088138a9e241d19ee3dca5f4c20d'),
    ('public.rpc_meetup_update_kan712_inner(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)', '59a27e5f0d23c4c2593e585cb0a6bd40'),
    ('public.run_seed_meetup_template(uuid,jsonb)', '74e763538070a1460fa4e1dc62f7cdf6'),
    ('public.rpc_meetup_set_attendee(uuid,uuid,text)', '118f1db9bf66dff0d4a275c89b3703de'),
    ('public.rpc_meetup_invite_user(uuid,uuid,timestamp with time zone)', '08d8cc7c0d7b99653b81d9cbeaf33b82'),
    ('public.rpc_meetup_mint_link(uuid,timestamp with time zone,integer)', '2364638777f63f9f8fe6fa9e704b4153'),
    ('public.kan712_legacy_guard()', '95d3f5da60e5647ed84a55ad1fa0fdce')) v(fn, pre)
  loop
    if (select md5(p.prosrc) from pg_proc p where p.oid = to_regprocedure(k.fn)) is distinct from k.pre then
      raise exception 'KAN-862 pre: % absent or drifted', k.fn;
    end if;
  end loop;
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

  -- KAN-862 events-first write (meetups): the writer (rpc_create_meetup_legacy_v2, run_seed_meetup_template,
  -- rpc_meetup_cancel_kan712_inner, rpc_meetup_update_kan712_inner) has written the events parent and names only the
  -- retained meetups columns. Copy the parent onto the legacy columns instead of writing events again. Honoured only
  -- for a trusted caller (or service_role, which bypasses every check anyway) and only for the row id the writer flagged.
  IF TG_OP IN ('INSERT', 'UPDATE') AND v_type = 'meetup' AND (v_trusted OR current_user = 'service_role')
     AND coalesce(current_setting('kan712.events_first', true), '') = NEW.id::text THEN
    IF TG_OP = 'UPDATE' AND NEW.id IS DISTINCT FROM OLD.id THEN
      RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan712_id_immutable';
    END IF;
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

CREATE OR REPLACE FUNCTION public.rpc_meetup_cancel_kan712_inner(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_creator uuid;
  v_title   text;
  v_rcpt    record;
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if not exists (
    select 1 from public.meetups m
      join public.events e on e.id = m.id and e.event_type = 'meetup'
    where m.id = p_meetup_id
      and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  ) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  update public.events
     set is_cancelled = true, updated_at = now()
   where id = p_meetup_id and event_type = 'meetup' and is_cancelled = false
  returning creator_user_id, title into v_creator, v_title;
  if found then
    -- KAN-862: parity onto the legacy meetups columns and the meetups AFTER triggers, without routing back to events.
    perform set_config('kan712.events_first', p_meetup_id::text, true);
    update public.meetups set is_indoor = is_indoor where id = p_meetup_id;
    perform set_config('kan712.events_first', '', true);
    -- KAN-862: what trg_meetups_cancel_notify sent (it fired on UPDATE OF meetups.is_cancelled, which is no longer named).
    for v_rcpt in
      select distinct s.user_id
        from public.meetup_rsvps s
       where s.meetup_id = p_meetup_id
         and s.status in ('going', 'interested', 'pending')
         and s.user_id is distinct from auth.uid()
    loop
      perform public.process_notification_event(
        v_rcpt.user_id, 'meetup.cancelled', 'meetup', p_meetup_id,
        coalesce(auth.uid(), v_creator),
        'A meet-up you signed up for was cancelled', v_title);
    end loop;
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_update_kan712_inner(p_meetup_id uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location_name text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me        uuid := auth.uid();
  v_ev      public.events%rowtype;
  v_start   timestamptz;
  v_end     timestamptz;
  v_going   integer;
  v_changed jsonb := '[]'::jsonb;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select ev.* into v_ev
    from public.events ev
    join public.meetups mt on mt.id = ev.id
   where ev.id = p_meetup_id and ev.event_type = 'meetup'
     for update of ev, mt;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if v_ev.creator_user_id <> me then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if v_ev.is_cancelled then
    raise exception using errcode='P0001', message='meetup_cancelled';
  end if;

  if p_title is not null then
    if char_length(trim(p_title)) < 3 or char_length(trim(p_title)) > 80 then
      raise exception using errcode='P0001', message='title_invalid';
    end if;
  end if;

  if p_location_name is not null and trim(p_location_name) = '' then
    raise exception using errcode='P0001', message='location_name_required';
  end if;

  v_start := coalesce(p_start_at, v_ev.start_at);
  v_end   := coalesce(p_end_at, v_ev.end_at);
  if v_end is not null and v_end <= v_start then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;

  if p_capacity is not null then
    if p_capacity <= 0 then
      raise exception using errcode='P0001', message='invalid_capacity';
    end if;
    select count(*)::int into v_going
      from public.meetup_rsvps r
     where r.meetup_id = p_meetup_id and r.status = 'going';
    if p_capacity < v_going then
      raise exception using errcode='P0001', message='capacity_below_going_count';
    end if;
  end if;

  if p_title         is not null then v_changed := v_changed || to_jsonb('title'::text); end if;
  if p_description   is not null then v_changed := v_changed || to_jsonb('description'::text); end if;
  if p_start_at      is not null then v_changed := v_changed || to_jsonb('start_at'::text); end if;
  if p_end_at        is not null then v_changed := v_changed || to_jsonb('end_at'::text); end if;
  if p_location_name is not null then v_changed := v_changed || to_jsonb('location_name'::text); end if;
  if p_capacity      is not null then v_changed := v_changed || to_jsonb('capacity'::text); end if;

  -- KAN-862: the shared fields live on events; the meetup-only fields on meetups (flagged: the guard copies the
  -- events row onto the legacy columns and does not route back into events).
  update public.events
     set title      = coalesce(p_title, title),
         start_at   = v_start,
         end_at     = v_end,
         capacity   = coalesce(p_capacity, capacity),
         updated_at = now()
   where id = p_meetup_id and event_type = 'meetup';

  perform set_config('kan712.events_first', p_meetup_id::text, true);
  update public.meetups
     set description   = coalesce(p_description, description),
         location_name = coalesce(p_location_name, location_name)
   where id = p_meetup_id;
  perform set_config('kan712.events_first', '', true);

  perform public.emit_event('meetup.updated','meetup', p_meetup_id, me,
                            jsonb_build_object('fields', v_changed));

  return public.rpc_meetup_card(p_meetup_id);
end;
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
 RETURN jsonb_build_object('template_id',p_template_id,'status','success','meetup_id',v_mid,'going',v_g,'interested',v_i,'start_at',v_start,'location_name',v_loc,'venue_id',v_venue,'venue_space_id',v_space,'venue_entry_cost',v_entry_cost);
EXCEPTION WHEN OTHERS THEN
 RETURN jsonb_build_object('template_id',p_template_id,'status','error','message',SQLERRM);
END $function$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_set_attendee(p_meetup_id uuid, p_target_actor uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  owner uuid;
begin
  if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if p_status not in ('going','interested','declined') then
    raise exception using errcode='P0001', message='rsvp_status_invalid';
  end if;

  -- KAN-862: the owner is the creator (owner_user_id never existed on meetups; it was the pre-rename name).
  select e.creator_user_id into owner
    from public.meetups m join public.events e on e.id = m.id and e.event_type = 'meetup'
   where m.id = p_meetup_id;
  if owner is null then raise exception using errcode='P0001', message='meetup_not_found'; end if;
  if not public.can_write_row(owner) then
    raise exception using errcode='P0001', message='not_meetup_owner';
  end if;

  insert into public.meetup_attendees(meetup_id, actor_profile_id, user_id, status)
  select p_meetup_id, p_target_actor, p.user_id, p_status
  from public.profiles p
  where p.id = p_target_actor
  on conflict (meetup_id, actor_profile_id)
  do update set status = excluded.status, updated_at = now();
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_invite_user(p_meetup_id uuid, p_to_user_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare idd uuid;
begin
  if not exists (select 1 from public.meetups m join public.events e on e.id = m.id and e.event_type = 'meetup'
                  where m.id=p_meetup_id and (e.creator_user_id=auth.uid() or public.is_admin(auth.uid()))) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  insert into public.meetup_invites(meetup_id, to_user_id, created_by, expires_at)
  values (p_meetup_id, p_to_user_id, auth.uid(), p_expires_at)
  returning id into idd;

  perform public.emit_event('meetup.invite_sent','meetup', p_meetup_id, auth.uid(), jsonb_build_object('invite_id', idd, 'to_user_id', p_to_user_id));
  return idd;
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_mint_link(p_meetup_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_uses integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t uuid;
begin
  if not exists (select 1 from public.meetups m join public.events e on e.id = m.id and e.event_type = 'meetup'
                  where m.id=p_meetup_id and (e.creator_user_id=auth.uid() or public.is_admin(auth.uid()))) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  t := gen_random_uuid();
  insert into public.meetup_link_tokens(meetup_id, token, created_by, expires_at, max_uses)
  values (p_meetup_id, t, auth.uid(), p_expires_at, p_max_uses);
  return t;
end;
$function$;

do $post$
declare
  k record;
  r record;
begin
  for k in select * from (values
    ('public.rpc_meetup_cancel_kan712_inner(uuid)', '{postgres=X/postgres}', true, 'search_path=public'),
    ('public.rpc_meetup_update_kan712_inner(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)', '{postgres=X/postgres}', true, 'search_path=public, pg_temp'),
    ('public.run_seed_meetup_template(uuid,jsonb)', '{postgres=X/postgres,service_role=X/postgres}', false, 'search_path=public, pg_temp'),
    ('public.rpc_meetup_set_attendee(uuid,uuid,text)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', true, 'search_path=public'),
    ('public.rpc_meetup_invite_user(uuid,uuid,timestamp with time zone)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', true, 'search_path=public'),
    ('public.rpc_meetup_mint_link(uuid,timestamp with time zone,integer)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', true, 'search_path=public'),
    ('public.kan712_legacy_guard()', '{postgres=X/postgres}', false, 'search_path=""')) v(fn, acl, secdef, cfg)
  loop
    select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
      into r from pg_proc p where p.oid = k.fn::regprocedure;
    if r.acl is distinct from k.acl or r.prosecdef is distinct from k.secdef or r.vol <> 'v'
       or r.cfg is distinct from k.cfg or r.own <> 'postgres' then
      raise exception 'KAN-862 post: % attributes drifted: %', k.fn, r;
    end if;
  end loop;
end
$post$;
