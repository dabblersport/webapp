-- KAN-862 live proof for the meetup write paths (migration 20261113192823_kan862_meetup_writes_events_first.sql): rpc_meetup_cancel_kan712_inner,
-- rpc_meetup_update_kan712_inner, run_seed_meetup_template, rpc_meetup_set_attendee, rpc_meetup_invite_user,
-- rpc_meetup_mint_link (and the kan712_legacy_guard events-first branch they use).
-- Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK; every call runs in
-- its own subtransaction that is always undone.
--
-- TWINS. pg_temp.k862w_pre_<fn> is the verbatim pre-image body (T0 proves md5(prosrc) = the pinned pre-image md5),
-- SECURITY DEFINER dropped; they are called as postgres (the owner), seed as service_role, like the originals.
-- The 'new' variant calls what the client calls: rpc_meetup_cancel / rpc_meetup_update (wrappers) and the three
-- owner RPCs as role authenticated; run_seed_meetup_template as service_role.
-- Each call captures its return value (or error) plus a snapshot of the target meetup taken inside the
-- subtransaction: events row, legacy meetups row, events/meetups parity, public_activities, notification_aggregates,
-- invites, link tokens, attendees; and the number of events / meetups row updates the call made.
--   T0  twins are the pinned pre-images
--   T1  catalog: none of the six live bodies reads a Z01-dropped meetups column (or owner_user_id); the scanner flags
--       all six twins                                                                               RED before apply
--   T2  cancel  = pre-image on every scenario; host cancel notifies the RSVPs once; parity holds
--   T3  seed    = pre-image on every scenario (meetup id normalised); host_actor_id = host profile; parity holds
--   T4  update  = pre-image on every scenario; parity holds
--   T5..T7 invite_user / mint_link / set_attendee: pre-image raises 42703 (owner_user_id), new = expected outcome
--                                                                                                 RED before apply
--   T8  no double write: each new cancel/update makes no more events updates than the pre-image
--   T9  parity over every meetup after a combined cancel + update + seed
--   T10 final catalog probe: no public function outside the declared set reads a Z01-dropped meetups column
--   T11 attributes / ACL of the six and the guard
-- VALID ONLY BEFORE Z01: the twins and the parity probe read the columns Z01 drops.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862w_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862w_cap (fn text, variant text, k text, v text) ON COMMIT DROP;

-- Pre-image twins (verbatim live bodies, SECURITY DEFINER dropped).
CREATE FUNCTION pg_temp.k862w_pre_rpc_meetup_cancel_kan712_inner(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if not exists (
    select 1 from public.meetups m
    where m.id = p_meetup_id
      and (m.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  ) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  update public.meetups
     set is_cancelled = true, updated_at = now()
   where id = p_meetup_id and is_cancelled = false;
  if found then
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

CREATE FUNCTION pg_temp.k862w_pre_rpc_meetup_update_kan712_inner(p_meetup_id uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location_name text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me        uuid := auth.uid();
  m         public.meetups%rowtype;
  v_start   timestamptz;
  v_end     timestamptz;
  v_going   integer;
  v_changed jsonb := '[]'::jsonb;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if m.creator_user_id <> me then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if m.is_cancelled then
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

  v_start := coalesce(p_start_at, m.start_at);
  v_end   := coalesce(p_end_at, m.end_at);
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

  update public.meetups
     set title         = coalesce(p_title, title),
         description   = coalesce(p_description, description),
         start_at      = v_start,
         end_at        = v_end,
         location_name = coalesce(p_location_name, location_name),
         capacity      = coalesce(p_capacity, capacity),
         updated_at    = now()
   where id = p_meetup_id;

  perform public.emit_event('meetup.updated','meetup', p_meetup_id, me,
                            jsonb_build_object('fields', v_changed));

  return public.rpc_meetup_card(p_meetup_id);
end;
$function$;

CREATE FUNCTION pg_temp.k862w_pre_run_seed_meetup_template(p_template_id uuid, p_config jsonb)
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
BEGIN
 IF current_user <> 'service_role' THEN RAISE EXCEPTION 'service_role_required'; END IF;
 IF p_template_id IS NULL OR v_city IS NULL OR char_length(v_title) NOT BETWEEN 3 AND 80 THEN RAISE EXCEPTION 'template_city_or_title_invalid'; END IF;
 IF v_days NOT BETWEEN 1 AND 14 OR v_hour NOT BETWEEN 0 AND 23 OR v_duration NOT BETWEEN 30 AND 240 OR v_cap NOT BETWEEN 1 AND 30 OR v_going NOT BETWEEN 1 AND v_cap OR v_interested NOT BETWEEN 0 AND 8 THEN RAISE EXCEPTION 'schedule_capacity_or_seed_count_invalid'; END IF;
 IF NOT EXISTS(select 1 from pg_timezone_names where name=v_zone) THEN RAISE EXCEPTION 'invalid_timezone'; END IF;
 v_day:=(now() AT TIME ZONE v_zone)::date;
 v_request:=md5('app_traffic_meetup:'||p_template_id::text||':'||v_day::text)::uuid;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 SELECT id INTO v_mid FROM public.meetups WHERE request_id=v_request AND meta->>'source'='app_traffic_seed' LIMIT 1;
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
 INSERT INTO public.meetups(creator_profile_id,creator_user_id,host_actor_id,title,description,sport_id,venue_id,geo_location_id,area_id,location_name,is_indoor,start_at,end_at,capacity,listing_visibility,rsvp_policy,members_only,joining_rule,cost_cover,request_id,meta)
 VALUES(v_host.id,v_host.user_id,v_host.id,v_title,concat_ws(E'\n\n',p_config->>'description',CASE WHEN v_auto THEN 'Meetup participation is free. Venue admission, membership and booking requirements are separate; confirm directly with the venue before attending.' ELSE NULL END),v_sport,v_venue,v_geo,v_area,v_loc,v_indoor,v_start,v_end,v_cap,'public','open',false,'free','free',v_request,jsonb_build_object('source','app_traffic_seed','notion_template_id',p_template_id,'seed_day',v_day,'venue_space_id',v_space,'venue_entry_cost',v_entry_cost,'venue_source','supabase'))
 RETURNING id INTO v_mid;
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

CREATE FUNCTION pg_temp.k862w_pre_rpc_meetup_set_attendee(p_meetup_id uuid, p_target_actor uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
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

  select m.owner_user_id into owner from public.meetups m where m.id = p_meetup_id;
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

CREATE FUNCTION pg_temp.k862w_pre_rpc_meetup_invite_user(p_meetup_id uuid, p_to_user_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare idd uuid;
begin
  if not exists (select 1 from public.meetups m where m.id=p_meetup_id and (m.owner_user_id=auth.uid() or public.is_admin(auth.uid()))) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  insert into public.meetup_invites(meetup_id, to_user_id, created_by, expires_at)
  values (p_meetup_id, p_to_user_id, auth.uid(), p_expires_at)
  returning id into idd;

  perform public.emit_event('meetup.invite_sent','meetup', p_meetup_id, auth.uid(), jsonb_build_object('invite_id', idd, 'to_user_id', p_to_user_id));
  return idd;
end;
$function$;

CREATE FUNCTION pg_temp.k862w_pre_rpc_meetup_mint_link(p_meetup_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_uses integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare t uuid;
begin
  if not exists (select 1 from public.meetups m where m.id=p_meetup_id and (m.owner_user_id=auth.uid() or public.is_admin(auth.uid()))) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  t := gen_random_uuid();
  insert into public.meetup_link_tokens(meetup_id, token, created_by, expires_at, max_uses)
  values (p_meetup_id, t, auth.uid(), p_expires_at, p_max_uses);
  return t;
end;
$function$;

-- The seed twin runs as service_role (it checks current_user), like the original.
GRANT EXECUTE ON FUNCTION pg_temp.k862w_pre_run_seed_meetup_template(uuid, jsonb) TO service_role;

-- Lexical scanner (P2's, kan862_p2_meetups_reads_test.sql), with the column list as a parameter.
CREATE FUNCTION pg_temp.k862w_scan(p_nsp oid, p_cols text[]) RETURNS TABLE(fn text, why text)
LANGUAGE sql STABLE AS $f$
with dre as (select '(' || array_to_string(p_cols, '|') || ')' r),
f as (select p.oid, p.proname::text fn, p.prosrc s from pg_proc p where p.pronamespace = p_nsp and p.prosrc ~* '\mmeetups\M'),
al as (select f.oid, lower(x[1]) a from f, regexp_matches(f.s, 'public\.meetups\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') x
        where lower(x[1]) not in ('where','on','join','set','for','left','inner','order','group','limit','using','values','returning','select','and','or')
       union select f.oid, lower(x[1]) from f, regexp_matches(f.s, '([a-z_][a-z0-9_]*)\s+public\.meetups%rowtype', 'gi') x),
hits as (
  select f.fn, 'alias '||al.a||'.'||lower(h[1]) why from f join al using(oid), dre, regexp_matches(f.s, '\m'||al.a||'\.'||dre.r||'\M', 'gi') h
  union select f.fn, 'unqualified select '||lower(h[1]) from f, dre, regexp_matches(f.s, 'select\s+(?:[a-z_]+\.)?'||dre.r||'\s+from\s+public\.meetups\s+where', 'gi') h
  union select f.fn, 'where '||lower(h[1]) from f, dre, regexp_matches(f.s, 'from\s+public\.meetups\s+where\s+'||dre.r||'\M', 'gi') h
  union select f.fn, 'update set '||lower(h[1]) from f, dre, regexp_matches(f.s, 'update\s+public\.meetups\s+set[^;]*?\m'||dre.r||'\s*=', 'gi') h
  union select f.fn, 'insert '||lower(h[1]) from f, dre, regexp_matches(f.s, 'insert\s+into\s+public\.meetups\s*\([^)]*\m'||dre.r||'\M', 'gi') h
  union select p.proname::text, 'trigger NEW/OLD.'||lower(h[1]) from pg_trigger t join pg_proc p on p.oid=t.tgfoid, dre,
         regexp_matches(p.prosrc, '\m(?:new|old)\.'||dre.r||'\M','gi') h
   where t.tgrelid='public.meetups'::regclass and not t.tgisinternal and p.pronamespace = p_nsp
) select fn, string_agg(distinct why, ', ') from hits group by fn
$f$;

CREATE TEMP TABLE k862w_z01 (c text) ON COMMIT DROP;
INSERT INTO k862w_z01 VALUES ('creator_profile_id'),('creator_user_id'),('title'),('listing_visibility'),('rsvp_policy'),('capacity'),
  ('start_at'),('end_at'),('is_cancelled'),('created_at'),('updated_at'),('search_tsv'),('geo_location_id'),('sport_id'),
  ('area_id'),('venue_id'),('min_skill'),('max_skill'),('joining_rule'),('cost_cover'),('request_id');

-- Callers and targets.
CREATE TEMP TABLE k862w_u ON COMMIT DROP AS
SELECT 'host'::text AS kind, e.creator_user_id AS uid FROM public.events e WHERE e.id = '78952b6c-5de2-40ed-98b3-e4962c5317af'
UNION ALL SELECT * FROM (SELECT 'going', r.user_id FROM public.meetup_rsvps r JOIN public.events e ON e.id = r.meetup_id
  WHERE r.meetup_id = '78952b6c-5de2-40ed-98b3-e4962c5317af' AND r.status = 'going' AND r.user_id <> e.creator_user_id
    AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = r.user_id AND p.is_active)
  ORDER BY r.user_id LIMIT 1) g
UNION ALL SELECT * FROM (SELECT 'plain', p.user_id FROM public.profiles p
  WHERE p.is_active AND NOT public.is_admin(p.user_id)
    AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r WHERE r.user_id = p.user_id AND r.meetup_id = '78952b6c-5de2-40ed-98b3-e4962c5317af')
    AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.event_type = 'meetup' AND e.creator_user_id = p.user_id)
  ORDER BY p.created_at, p.user_id LIMIT 1) pl
UNION ALL SELECT * FROM (SELECT 'admin', g.user_id FROM public.role_grants g WHERE g.role IN ('admin', 'super_admin')
  ORDER BY g.user_id LIMIT 1) ad   -- the only live admin has no profile row
UNION ALL SELECT 'anon', NULL::uuid;

-- Snapshot of one meetup, read as postgres inside the call's subtransaction.
CREATE FUNCTION pg_temp.k862w_snap(p_mid uuid) RETURNS text LANGUAGE sql VOLATILE AS $f$
  SELECT 'ev=' || coalesce((SELECT (to_jsonb(x) - 'search_tsv')::text || ' tsv=' || md5(coalesce(x.search_tsv::text, '')) FROM public.events x WHERE x.id = p_mid), '-')
      || ' mt=' || coalesce((SELECT (to_jsonb(y) - 'search_tsv')::text || ' tsv=' || md5(coalesce(y.search_tsv::text, '')) FROM public.meetups y WHERE y.id = p_mid), '-')
      || ' parity=' || coalesce((SELECT (ROW(x.creator_profile_id, x.creator_user_id, x.title, x.start_at, x.end_at, x.capacity, x.listing_visibility,
                  x.join_policy, x.is_cancelled, x.sport_id, x.area_id, x.geo_location_id, x.venue_id, x.min_skill, x.max_skill, x.joining_rule,
                  x.cost_cover, x.request_id, x.created_at, x.updated_at)
                  IS NOT DISTINCT FROM ROW(y.creator_profile_id, y.creator_user_id, y.title, y.start_at, y.end_at, y.capacity, y.listing_visibility,
                  y.rsvp_policy, y.is_cancelled, y.sport_id, y.area_id, y.geo_location_id, y.venue_id, y.min_skill::smallint, y.max_skill::smallint,
                  y.joining_rule, y.cost_cover, y.request_id, y.created_at, y.updated_at))::text
                FROM public.events x JOIN public.meetups y ON y.id = x.id WHERE x.id = p_mid), '-')
      || ' pa=' || coalesce((SELECT a.is_deleted || ':' || a.updated_at FROM public.public_activities a WHERE a.id = p_mid), '-')
      || ' notif=[' || coalesce((SELECT string_agg(n.to_user_id || ':' || n.kind_key || ':' || n.total_count || ':' || array_to_string(n.actors, '|'), ',' ORDER BY n.to_user_id, n.kind_key)
                                   FROM public.notification_aggregates n WHERE n.entity_id = p_mid AND n.created_at = now()), '')
                  || coalesce((SELECT string_agg(n.to_user_id || ':' || n.kind_key || ':' || coalesce(n.title, '') || ':' || coalesce(n.body, '') || ':' || n.context::text, ',' ORDER BY n.to_user_id, n.kind_key)
                                   FROM public.notifications n WHERE n.context->>'entity_id' = p_mid::text AND n.created_at = now()), '') || ']'
      || ' inv=[' || coalesce((SELECT string_agg(i.to_user_id || ':' || i.created_by || ':' || i.status || ':' || coalesce(i.expires_at::text, ''), ',' ORDER BY i.to_user_id)
                                 FROM public.meetup_invites i WHERE i.meetup_id = p_mid AND i.created_at = now()), '') || ']'
      || ' tok=[' || coalesce((SELECT string_agg(t.created_by || ':' || coalesce(t.max_uses::text, '') || ':' || t.active, ',')
                                 FROM public.meetup_link_tokens t WHERE t.meetup_id = p_mid AND t.created_at = now()), '') || ']'
      || ' att=[' || coalesce((SELECT string_agg(a.actor_profile_id || ':' || a.user_id || ':' || a.status, ',' ORDER BY a.actor_profile_id)
                                 FROM public.meetup_attendees a WHERE a.meetup_id = p_mid AND a.updated_at = now()), '') || ']'
$f$;

-- Snapshot of what a seed run created (located by its request id), meetup id normalised.
CREATE FUNCTION pg_temp.k862w_seedsnap(p_tid uuid) RETURNS text LANGUAGE sql VOLATILE AS $f$
  WITH k AS (SELECT md5('app_traffic_meetup:' || p_tid::text || ':' || (now() AT TIME ZONE 'Asia/Dubai')::date::text)::uuid rq),
       x AS (SELECT e.* FROM public.events e, k WHERE e.request_id = k.rq AND e.event_type = 'meetup')
  SELECT 'n=' || (SELECT count(*) FROM x)
      || ' ev=' || coalesce((SELECT (to_jsonb(x) - 'id' - 'search_tsv')::text FROM x), '-')
      || ' mt=' || coalesce((SELECT (to_jsonb(y) - 'id' - 'event_id' - 'search_tsv')::text || ' tsv=' || md5(coalesce(y.search_tsv::text, ''))
                               || ' hostok=' || (y.host_actor_id = y.creator_profile_id)::text FROM public.meetups y JOIN x ON x.id = y.id), '-')
      || ' parity=' || coalesce((SELECT pg_temp.k862w_snap(x.id) ~ 'parity=true' FROM x)::text, '-')
      || ' rsvp=[' || coalesce((SELECT string_agg(r.user_id || ':' || r.status, ',' ORDER BY r.user_id) FROM public.meetup_rsvps r JOIN x ON x.id = r.meetup_id), '') || ']'
      || ' pa=' || coalesce((SELECT (to_jsonb(a) - 'id')::text FROM public.public_activities a JOIN x ON x.id = a.id), '-')
$f$;

-- rpc_meetup_card's avatar preview is ordered by updated_at desc, and rows tie (now()), so its array order is not
-- deterministic between two calls. Arrays are compared as sorted multisets; nothing else is normalised.
CREATE FUNCTION pg_temp.k862w_norm(j jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $f$
BEGIN
  RETURN CASE jsonb_typeof(j)
    WHEN 'object' THEN (SELECT coalesce(jsonb_object_agg(e.k, pg_temp.k862w_norm(e.v)), '{}'::jsonb) FROM jsonb_each(j) e(k, v))
    WHEN 'array'  THEN (SELECT coalesce(jsonb_agg(s.x ORDER BY s.x::text), '[]'::jsonb) FROM (SELECT pg_temp.k862w_norm(a.v) x FROM jsonb_array_elements(j) a(v)) s)
    ELSE j END;
END $f$;

-- One call as a caller (and role), in a subtransaction that is always undone. Returns result # snapshot # updates.
CREATE FUNCTION pg_temp.k862w_call(p_uid uuid, p_role text, p_contract boolean, p_sql text, p_mid uuid, p_tid uuid) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE r text; s text; u0e bigint; u0m bigint; u1e bigint; u1m bigint;
BEGIN
  SELECT n_tup_upd INTO u0e FROM pg_stat_xact_user_tables WHERE relid = 'public.events'::regclass;
  SELECT n_tup_upd INTO u0m FROM pg_stat_xact_user_tables WHERE relid = 'public.meetups'::regclass;
  BEGIN
    PERFORM set_config('request.jwt.claims',
      CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_contract THEN PERFORM set_config('kan712.contract', 'on', true); END IF;
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO r;
    IF p_role IS NOT NULL THEN RESET ROLE; END IF;
    IF r ~ '^\{' AND position(' / ' in r) = 0 THEN r := pg_temp.k862w_norm(r::jsonb)::text; END IF;
    PERFORM set_config('kan712.contract', '', true);
    SELECT n_tup_upd INTO u1e FROM pg_stat_xact_user_tables WHERE relid = 'public.events'::regclass;
    SELECT n_tup_upd INTO u1m FROM pg_stat_xact_user_tables WHERE relid = 'public.meetups'::regclass;
    s := CASE WHEN p_tid IS NOT NULL THEN pg_temp.k862w_seedsnap(p_tid) ELSE pg_temp.k862w_snap(p_mid) END;
    r := coalesce(r, '<null>') || ' # ' || s || ' # upd ev=' || (u1e - u0e) || ' mt=' || (u1m - u0m);
    RAISE EXCEPTION 'k862w_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862w_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(r, '<null>');
END $f$;

DO $run$
DECLARE
  v_fd   uuid := '78952b6c-5de2-40ed-98b3-e4962c5317af';
  v_x    uuid := '86200000-0000-0000-0000-0000000000ee';
  v_tid  uuid := '86200000-0000-4000-8000-00000000c001';
  v_host uuid; v_going uuid; v_plain uuid; v_admin uuid; v_gprof uuid;
  sc record; var text; v_sql text; v_res text; v_fn text;
BEGIN
  SELECT uid INTO v_host FROM pg_temp.k862w_u WHERE kind = 'host';
  SELECT uid INTO v_going FROM pg_temp.k862w_u WHERE kind = 'going';
  SELECT uid INTO v_plain FROM pg_temp.k862w_u WHERE kind = 'plain';
  SELECT uid INTO v_admin FROM pg_temp.k862w_u WHERE kind = 'admin';
  SELECT p.id INTO v_gprof FROM public.profiles p WHERE p.user_id = v_going AND p.is_active ORDER BY p.created_at LIMIT 1;

  -- cancel / update: {C} and {U} are the variant's cancel and update entry points.
  FOR sc IN SELECT * FROM (VALUES
    ('cancel',  'host',  'SELECT {C}(%L)::text', v_fd),
    ('cancel',  'host2', 'SELECT {C}(%1$L) || {C}(%1$L)', v_fd),
    ('cancel',  'admin', 'SELECT {C}(%L)::text', v_fd),
    ('cancel',  'going', 'SELECT {C}(%L)::text', v_fd),
    ('cancel',  'plain', 'SELECT {C}(%L)::text', v_fd),
    ('cancel',  'anon',  'SELECT {C}(%L)::text', v_fd),
    ('cancel',  'hostX', 'SELECT {C}(%L)::text', v_x),
    ('update',  'host',  'SELECT {U}(%L, ''KAN862 edited title'', ''new description'', now() + interval ''3 days'', now() + interval ''3 days 2 hours'', ''New place'', 12)::text', v_fd),
    ('update',  'hostT', 'SELECT {U}(%L, p_title => ''Only the title'')::text', v_fd),
    ('update',  'hostN', 'SELECT {U}(%L)::text', v_fd),
    ('update',  'hostbadtitle', 'SELECT {U}(%L, p_title => ''ab'')::text', v_fd),
    ('update',  'hostbadloc', 'SELECT {U}(%L, p_location_name => '' '')::text', v_fd),
    ('update',  'hostbadtime', 'SELECT {U}(%L, p_start_at => now() + interval ''5 days'', p_end_at => now() + interval ''4 days'')::text', v_fd),
    ('update',  'hostcap0', 'SELECT {U}(%L, p_capacity => 0)::text', v_fd),
    ('update',  'hostcap1', 'SELECT {U}(%L, p_capacity => 1)::text', v_fd),
    ('update',  'hostcancelled', 'SELECT {C}(%1$L) || {U}(%1$L, p_title => ''After cancel'')::text', v_fd),
    ('update',  'going', 'SELECT {U}(%L, p_title => ''Not mine'')::text', v_fd),
    ('update',  'anon',  'SELECT {U}(%L, p_title => ''Not mine'')::text', v_fd),
    ('update',  'hostX', 'SELECT {U}(%L, p_title => ''Missing'')::text', v_x)
  ) v(fn, k, tpl, mid) LOOP
    FOREACH var IN ARRAY ARRAY['pre', 'new'] LOOP
      v_sql := replace(replace(format(sc.tpl, sc.mid),
        '{C}', CASE var WHEN 'pre' THEN 'pg_temp.k862w_pre_rpc_meetup_cancel_kan712_inner' ELSE 'public.rpc_meetup_cancel' END),
        '{U}', CASE var WHEN 'pre' THEN 'pg_temp.k862w_pre_rpc_meetup_update_kan712_inner' ELSE 'public.rpc_meetup_update' END);
      v_res := pg_temp.k862w_call(
        CASE regexp_replace(sc.k, '^host.*', 'host') WHEN 'host' THEN v_host WHEN 'admin' THEN v_admin WHEN 'going' THEN v_going
             WHEN 'plain' THEN v_plain ELSE NULL END,
        CASE var WHEN 'new' THEN 'authenticated' END, var = 'pre', v_sql, sc.mid, NULL);
      INSERT INTO k862w_cap VALUES (sc.fn, var, sc.k, v_res);
    END LOOP;
  END LOOP;

  -- seed, as service_role.
  FOR sc IN SELECT * FROM (VALUES
    ('manual', jsonb_build_object('city', 'Dubai', 'title', 'KAN862 seed probe', 'sport_key', 'gym_training',
                 'geo_location_id', '035c3855-ce1d-4ffd-ba4d-c12642271065', 'location_name', 'Probe park', 'is_indoor', false,
                 'description', 'seed probe'), 1),
    ('replay', jsonb_build_object('city', 'Dubai', 'title', 'KAN862 seed probe', 'sport_key', 'gym_training',
                 'geo_location_id', '035c3855-ce1d-4ffd-ba4d-c12642271065', 'location_name', 'Probe park', 'is_indoor', false), 2),
    ('auto',   jsonb_build_object('city', 'Dubai', 'title', 'KAN862 seed auto', 'sport_key', 'gym_training', 'auto_venue', true,
                 'seed_going', 2, 'seed_interested', 1), 1),
    ('badtitle', jsonb_build_object('city', 'Dubai', 'title', 'ab', 'sport_key', 'gym_training'), 1),
    ('nohost', jsonb_build_object('city', 'Nowhere', 'title', 'KAN862 seed nohost', 'sport_key', 'gym_training'), 1)
  ) v(k, cfg, times) LOOP
    FOREACH var IN ARRAY ARRAY['pre', 'new'] LOOP
      v_fn := CASE var WHEN 'pre' THEN 'pg_temp.k862w_pre_run_seed_meetup_template' ELSE 'public.run_seed_meetup_template' END;
      v_sql := CASE sc.times WHEN 1 THEN format('SELECT (%1$s(%2$L, %3$L) - ''meetup_id'')::text', v_fn, v_tid, sc.cfg)
               ELSE format('SELECT (%1$s(%2$L, %3$L) - ''meetup_id'')::text || '' / '' || (%1$s(%2$L, %3$L) - ''meetup_id'')::text', v_fn, v_tid, sc.cfg) END;
      v_res := pg_temp.k862w_call(NULL, 'service_role', false, v_sql, NULL, v_tid);
      INSERT INTO k862w_cap VALUES ('seed', var, sc.k, v_res);
    END LOOP;
  END LOOP;

  -- set_attendee / invite_user / mint_link. Pre-image twins as postgres (the definer), new as authenticated.
  FOR sc IN SELECT * FROM (VALUES
    ('set_attendee', 'host',     format('SELECT {F}(%L, %L, ''going'')::text', v_fd, v_gprof)),
    ('set_attendee', 'admin',    format('SELECT {F}(%L, %L, ''interested'')::text', v_fd, v_gprof)),
    ('set_attendee', 'plain',    format('SELECT {F}(%L, %L, ''going'')::text', v_fd, v_gprof)),
    ('set_attendee', 'hostX',    format('SELECT {F}(%L, %L, ''going'')::text', v_x, v_gprof)),
    ('set_attendee', 'hostbad',  format('SELECT {F}(%L, %L, ''maybe'')::text', v_fd, v_gprof)),
    ('set_attendee', 'anon',     format('SELECT {F}(%L, %L, ''going'')::text', v_fd, v_gprof)),
    ('invite_user',  'host',     format('SELECT {F}(%L, %L)::text', v_fd, v_plain)),
    ('invite_user',  'admin',    format('SELECT {F}(%L, %L, now() + interval ''1 day'')::text', v_fd, v_plain)),
    ('invite_user',  'plain',    format('SELECT {F}(%L, %L)::text', v_fd, v_going)),
    ('invite_user',  'hostX',    format('SELECT {F}(%L, %L)::text', v_x, v_plain)),
    ('invite_user',  'anon',     format('SELECT {F}(%L, %L)::text', v_fd, v_plain)),
    ('mint_link',    'host',     format('SELECT {F}(%L)::text', v_fd)),
    ('mint_link',    'admin',    format('SELECT {F}(%L, now() + interval ''1 day'', 5)::text', v_fd)),
    ('mint_link',    'plain',    format('SELECT {F}(%L)::text', v_fd)),
    ('mint_link',    'hostbad',  format('SELECT {F}(%L, NULL, 0)::text', v_fd)),
    ('mint_link',    'anon',     format('SELECT {F}(%L)::text', v_fd))
  ) v(fn, k, tpl) LOOP
    FOREACH var IN ARRAY ARRAY['pre', 'new'] LOOP
      v_sql := replace(sc.tpl, '{F}', CASE var WHEN 'pre' THEN 'pg_temp.k862w_pre_rpc_meetup_' ELSE 'public.rpc_meetup_' END || sc.fn);
      v_res := pg_temp.k862w_call(
        CASE regexp_replace(sc.k, '^host.*', 'host') WHEN 'host' THEN v_host WHEN 'admin' THEN v_admin WHEN 'going' THEN v_going
             WHEN 'plain' THEN v_plain ELSE NULL END,
        CASE var WHEN 'new' THEN 'authenticated' END, false, v_sql, v_fd, NULL);
      INSERT INTO k862w_cap VALUES (sc.fn, var, sc.k,
        regexp_replace(v_res, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<uuid>'));
    END LOOP;
  END LOOP;

  -- T9: combined cancel + update + seed in one subtransaction, then parity over every meetup.
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_host::text, true);
    SET LOCAL ROLE authenticated;
    PERFORM public.rpc_meetup_update(v_fd, p_title => 'KAN862 parity title', p_location_name => 'Parity place', p_capacity => 10);
    PERFORM public.rpc_meetup_cancel(v_fd);
    RESET ROLE;
    SET LOCAL ROLE service_role;
    PERFORM public.run_seed_meetup_template(v_tid, jsonb_build_object('city', 'Dubai', 'title', 'KAN862 parity seed', 'sport_key', 'gym_training',
      'geo_location_id', '035c3855-ce1d-4ffd-ba4d-c12642271065', 'location_name', 'Parity park', 'is_indoor', true));
    RESET ROLE;
    v_res :=
      'meetups=' || (SELECT count(*) FROM public.meetups) || ' events_meetup=' || (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
      || ' mismatch=' || (SELECT count(*) FROM public.meetups y JOIN public.events x ON x.id = y.id
          WHERE x.event_type IS DISTINCT FROM 'meetup' OR pg_temp.k862w_snap(y.id) !~ 'parity=true')
      || ' orphans=' || (SELECT count(*) FROM public.meetups y WHERE NOT EXISTS (SELECT 1 FROM public.events x WHERE x.id = y.id))
      || ' fd_cancelled=' || (SELECT x.is_cancelled || '/' || y.is_cancelled || '/' || x.title || '/' || y.title FROM public.events x JOIN public.meetups y ON y.id = x.id WHERE x.id = v_fd)
      || ' seeded=' || (SELECT count(*) FROM public.events x WHERE x.request_id = md5('app_traffic_meetup:' || v_tid::text || ':' || (now() AT TIME ZONE 'Asia/Dubai')::date::text)::uuid);
    RAISE EXCEPTION 'k862w_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862w_undo' THEN v_res := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  INSERT INTO k862w_cap VALUES ('parity', 'new', 'all', v_res);   -- after the undo, or it is undone too
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$run$;

-- T0: twins are the pinned pre-images
INSERT INTO k862w_tap SELECT 0, count(*) = 6 AND bool_and(md5(p.prosrc) = k.pre), 'twins are the pinned pre-images (md5 prosrc)',
  string_agg(k.fn || '=' || (md5(p.prosrc) = k.pre)::text, ', ' ORDER BY k.fn)
  FROM (VALUES ('rpc_meetup_cancel_kan712_inner', 'dbb3088138a9e241d19ee3dca5f4c20d'), ('rpc_meetup_update_kan712_inner', '59a27e5f0d23c4c2593e585cb0a6bd40'),
               ('run_seed_meetup_template', '74e763538070a1460fa4e1dc62f7cdf6'), ('rpc_meetup_set_attendee', '118f1db9bf66dff0d4a275c89b3703de'),
               ('rpc_meetup_invite_user', '08d8cc7c0d7b99653b81d9cbeaf33b82'), ('rpc_meetup_mint_link', '2364638777f63f9f8fe6fa9e704b4153')) k(fn, pre)
  JOIN pg_proc p ON p.proname = 'k862w_pre_' || k.fn AND p.pronamespace = pg_my_temp_schema();

-- T1: catalog, the six
INSERT INTO k862w_tap SELECT 1,
  NOT EXISTS (SELECT 1 FROM pg_temp.k862w_scan('public'::regnamespace, (SELECT array_agg(c) FROM k862w_z01) || ARRAY['owner_user_id']) s
               WHERE s.fn IN ('rpc_meetup_cancel_kan712_inner', 'rpc_meetup_update_kan712_inner', 'run_seed_meetup_template',
                              'rpc_meetup_set_attendee', 'rpc_meetup_invite_user', 'rpc_meetup_mint_link'))
  AND (SELECT count(*) FROM pg_temp.k862w_scan(pg_my_temp_schema(), (SELECT array_agg(c) FROM k862w_z01) || ARRAY['owner_user_id']) s
        WHERE s.fn LIKE 'k862w_pre_%') = 6,
  'none of the six live bodies reads a Z01-dropped meetups column or owner_user_id; scanner flags all 6 twins',
  'live hits: ' || coalesce((SELECT string_agg(s.fn || ' (' || s.why || ')', '; ' ORDER BY s.fn)
     FROM pg_temp.k862w_scan('public'::regnamespace, (SELECT array_agg(c) FROM k862w_z01) || ARRAY['owner_user_id']) s
    WHERE s.fn IN ('rpc_meetup_cancel_kan712_inner', 'rpc_meetup_update_kan712_inner', 'run_seed_meetup_template',
                   'rpc_meetup_set_attendee', 'rpc_meetup_invite_user', 'rpc_meetup_mint_link')), 'none')
  || '; twins flagged: ' || (SELECT count(*) FROM pg_temp.k862w_scan(pg_my_temp_schema(), (SELECT array_agg(c) FROM k862w_z01) || ARRAY['owner_user_id']) s WHERE s.fn LIKE 'k862w_pre_%');

-- T2..T4: new = pre-image (the update-count suffix is compared in T8, not here)
INSERT INTO k862w_tap
SELECT 1 + row_number() OVER (ORDER BY f.fn), f.ok, f.fn || ' = pre-image on every scenario' || f.extra_label, f.detail
FROM (
  SELECT a.fn,
    bool_and(split_part(a.v, ' # upd', 1) = split_part(b.v, ' # upd', 1))
      AND CASE a.fn
        WHEN 'cancel' THEN bool_or(a.k = 'host' AND b.v ~ '^ok # .* parity=true .*notif=\[[^]]+\]')
                       AND bool_or(a.k = 'host2' AND b.v ~ '^okok # .* parity=true')
                       AND bool_or(a.k = 'plain' AND b.v ~ 'not_host') AND bool_or(a.k = 'anon' AND b.v ~ 'auth_required')
        WHEN 'update' THEN bool_or(a.k = 'host' AND b.v ~ ' parity=true' AND b.v ~ 'KAN862 edited title' AND b.v ~ 'New place')
                       AND bool_or(a.k = 'hostcancelled' AND b.v ~ 'meetup_cancelled') AND bool_or(a.k = 'hostcap1' AND b.v ~ 'capacity_below_going_count')
                       AND bool_or(a.k = 'hostX' AND b.v ~ 'meetup_not_found')
        WHEN 'seed'   THEN bool_or(a.k = 'manual' AND b.v ~ '"status": "success"' AND b.v ~ 'n=1 ' AND b.v ~ 'hostok=true' AND b.v ~ 'parity=true')
                       AND bool_or(a.k = 'replay' AND b.v ~ '"status": "skipped"' AND b.v ~ 'n=1 ')
                       AND bool_or(a.k = 'badtitle' AND b.v ~ 'template_city_or_title_invalid')
      END,
    CASE a.fn WHEN 'cancel' THEN ' (host cancel notifies once, parity holds)' WHEN 'update' THEN ' (parity holds)'
              ELSE ' (host_actor_id = host profile, parity holds)' END,
    string_agg(a.k || CASE WHEN split_part(a.v, ' # upd', 1) = split_part(b.v, ' # upd', 1) THEN ' same: ' || left(regexp_replace(b.v, ' ev=\{.*?\} tsv', ' ev={..} tsv', 'g'), 120)
               ELSE ' DIFF pre-only tokens: ' || coalesce((SELECT string_agg(t, ' ') FROM (SELECT unnest(regexp_split_to_array(a.v, '[ ,{}]+')) t
                      EXCEPT SELECT unnest(regexp_split_to_array(b.v, '[ ,{}]+'))) z), '') || ' / new-only tokens: '
                    || coalesce((SELECT string_agg(t, ' ') FROM (SELECT unnest(regexp_split_to_array(b.v, '[ ,{}]+')) t
                      EXCEPT SELECT unnest(regexp_split_to_array(a.v, '[ ,{}]+'))) z), '') END, ' | ' ORDER BY a.k)
  FROM k862w_cap a JOIN k862w_cap b ON b.fn = a.fn AND b.k = a.k AND b.variant = 'new'
  WHERE a.variant = 'pre' AND a.fn IN ('cancel', 'update', 'seed')
  GROUP BY a.fn) f(fn, ok, extra_label, detail);

-- T5..T7: owner RPCs. RED: the pre-image raises 42703 on owner_user_id. GREEN: the new body gives the expected outcome.
INSERT INTO k862w_tap
SELECT 4 + row_number() OVER (ORDER BY o.fn), o.ok, o.fn || ': pre-image raises 42703, new gives the expected outcome', o.detail
FROM (
  SELECT a.fn,
    bool_and(CASE WHEN a.k IN ('anon', 'hostbad') AND a.fn = 'set_attendee' THEN split_part(a.v, ' # upd', 1) = split_part(b.v, ' # upd', 1)
                  ELSE a.v ~ '^ERR 42703 .*owner_user_id' END)
    AND bool_and(b.v ~ x.expect),
    string_agg(a.k || ': pre=' || left(a.v, 60) || ' new=' || left(regexp_replace(b.v, ' ev=\{.*?\} mt=\{.*?\} tsv=[0-9a-f]+', ' ', 'g'), 200), ' | ' ORDER BY a.k)
  FROM k862w_cap a
  JOIN k862w_cap b ON b.fn = a.fn AND b.k = a.k AND b.variant = 'new'
  JOIN (VALUES
    ('set_attendee', 'host',    '^ # .*att=\[[^]]+:going\]'),
    ('set_attendee', 'admin',   '^ # .*att=\[[^]]+:interested\]'),
    ('set_attendee', 'plain',   '^ERR P0001 not_meetup_owner'),
    ('set_attendee', 'hostX',   '^ERR P0001 meetup_not_found'),
    ('set_attendee', 'hostbad', '^ERR P0001 rsvp_status_invalid'),
    ('set_attendee', 'anon',    '^ERR P0001 not_authenticated'),
    ('invite_user',  'host',    '^<uuid> # .*inv=\[[^]]+:pending:\]'),
    ('invite_user',  'admin',   '^<uuid> # .*inv=\[[^]]+:pending:[0-9]'),
    ('invite_user',  'plain',   '^ERR P0001 not_host'),
    ('invite_user',  'hostX',   '^ERR P0001 not_host'),
    ('invite_user',  'anon',    '^ERR P0001 not_host'),
    ('mint_link',    'host',    '^<uuid> # .*tok=\[[^]]+::true\]'),
    ('mint_link',    'admin',   '^<uuid> # .*tok=\[[^]]+:5:true\]'),
    ('mint_link',    'plain',   '^ERR P0001 not_host'),
    ('mint_link',    'hostbad', '^ERR 23514 .*meetup_link_tokens_max_uses_check'),
    ('mint_link',    'anon',    '^ERR P0001 not_host')) x(fn, k, expect) ON x.fn = a.fn AND x.k = a.k
  WHERE a.variant = 'pre'
  GROUP BY a.fn) o(fn, ok, detail);

-- T8: no double write (events updates per call: new <= pre)
INSERT INTO k862w_tap SELECT 8,
  bool_and(substring(b.v from ' # upd ev=([0-9]+)')::int <= substring(a.v from ' # upd ev=([0-9]+)')::int)
  AND bool_or(a.k = 'host' AND a.fn = 'cancel'),
  'no double write: events updates per call new <= pre-image',
  string_agg(a.fn || '/' || a.k || ' pre ' || substring(a.v from ' # upd (.*)$') || ' new ' || substring(b.v from ' # upd (.*)$'), '; ' ORDER BY a.fn, a.k)
  FROM k862w_cap a JOIN k862w_cap b ON b.fn = a.fn AND b.k = a.k AND b.variant = 'new'
 WHERE a.variant = 'pre' AND a.fn IN ('cancel', 'update') AND a.v LIKE '% # upd %' AND b.v LIKE '% # upd %';

-- T9: parity over every meetup after a combined cancel + update + seed
INSERT INTO k862w_tap SELECT 9,
  v ~ '^meetups=([0-9]+) events_meetup=\1 mismatch=0 orphans=0 fd_cancelled=true/true/KAN862 parity title/KAN862 parity title seeded=1$',
  'parity over every meetup after cancel + update + seed', v
  FROM k862w_cap WHERE fn = 'parity';

-- T10: final catalog probe. Declared set: the six (clean by T1), the dead kan711 tooling, and the trigger functions whose
-- meetups triggers Z01 drops (seq 302-333). fn_sync_geo_fields (trg_meetups_sync_geo, NOT in Z01's list) is reported as the
-- known exception.
INSERT INTO k862w_tap SELECT 10,
  NOT EXISTS (SELECT 1 FROM pg_temp.k862w_scan('public'::regnamespace, (SELECT array_agg(c) FROM k862w_z01)) s
               WHERE s.fn NOT IN ('kan711_events_map_meetup', 'kan711_events_backfill_batch', 'kan711_meetups_mirror',
                                  'kan711_events_backfill_run', 'kan711_events_validate_links', 'fn_sync_geo_fields')
                 AND s.fn NOT IN (SELECT p.proname FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
                                   WHERE t.tgrelid = 'public.meetups'::regclass AND NOT t.tgisinternal
                                     AND t.tgname IN ('trg_kan711_meetups_mirror', 'trg_zz_kan712_meetups_guard', 'trg_kan713_meetups_a_location',
                                       'trg_kan713_meetups_b_joining', 'trg_meetups_search_tsv', 'trg_meetups_touch', 'trg_meetups_updated',
                                       'trg_meetups_inherit_geo', 'tr_meetups_activity_sync', 'trg_meetups_cancel_notify', 'trg_meetups_outbox',
                                       'trg_meetups_stamp_request_id', 'trg_meetups_enforce_solo_sport', 'trg_meetups_sync_joining_rule'))),
  'no public function outside the declared set reads a Z01-dropped meetups column (known exception: fn_sync_geo_fields)',
  'outside: ' || coalesce((SELECT string_agg(s.fn || ' (' || s.why || ')', '; ' ORDER BY s.fn)
     FROM pg_temp.k862w_scan('public'::regnamespace, (SELECT array_agg(c) FROM k862w_z01)) s
    WHERE s.fn NOT IN ('kan711_events_map_meetup', 'kan711_events_backfill_batch', 'kan711_meetups_mirror',
                       'kan711_events_backfill_run', 'kan711_events_validate_links', 'fn_sync_geo_fields')
      AND s.fn NOT IN (SELECT p.proname FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
                        WHERE t.tgrelid = 'public.meetups'::regclass AND NOT t.tgisinternal
                          AND t.tgname IN ('trg_kan711_meetups_mirror', 'trg_zz_kan712_meetups_guard', 'trg_kan713_meetups_a_location',
                            'trg_kan713_meetups_b_joining', 'trg_meetups_search_tsv', 'trg_meetups_touch', 'trg_meetups_updated',
                            'trg_meetups_inherit_geo', 'tr_meetups_activity_sync', 'trg_meetups_cancel_notify', 'trg_meetups_outbox',
                            'trg_meetups_stamp_request_id', 'trg_meetups_enforce_solo_sport', 'trg_meetups_sync_joining_rule'))), 'none')
  || '; known exception present: ' || EXISTS (SELECT 1 FROM pg_temp.k862w_scan('public'::regnamespace, (SELECT array_agg(c) FROM k862w_z01)) s WHERE s.fn = 'fn_sync_geo_fields');

-- T11: attributes / ACL
INSERT INTO k862w_tap SELECT 11,
  count(*) = 7 AND bool_and(p.proowner = 'postgres'::regrole AND p.prosecdef = k.secdef AND p.provolatile = 'v'
    AND p.proconfig::text = k.cfg AND p.proacl::text = k.acl),
  'attributes / ACL of the six and the guard', string_agg(k.fn || ' ' || p.proacl::text || ' ' || p.prosecdef || ' ' || p.proconfig::text, '; ' ORDER BY k.fn)
  FROM (VALUES
    ('public.rpc_meetup_cancel_kan712_inner(uuid)', true, '{search_path=public}', '{postgres=X/postgres}'),
    ('public.rpc_meetup_update_kan712_inner(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)', true, '{"search_path=public, pg_temp"}', '{postgres=X/postgres}'),
    ('public.run_seed_meetup_template(uuid,jsonb)', false, '{"search_path=public, pg_temp"}', '{postgres=X/postgres,service_role=X/postgres}'),
    ('public.rpc_meetup_set_attendee(uuid,uuid,text)', true, '{search_path=public}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.rpc_meetup_invite_user(uuid,uuid,timestamp with time zone)', true, '{search_path=public}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.rpc_meetup_mint_link(uuid,timestamp with time zone,integer)', true, '{search_path=public}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.kan712_legacy_guard()', false, '{"search_path=\"\""}', '{postgres=X/postgres}')
  ) k(fn, secdef, cfg, acl)
  JOIN pg_proc p ON p.oid = k.fn::regprocedure;

SELECT (SELECT count(*) FILTER (WHERE ok) || '/' || count(*) FROM k862w_tap) || E'\n'
    || string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || left(detail, 700) || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k862w_tap;
ROLLBACK;
