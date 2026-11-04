-- KAN-851 (supporting ticket under KAN-844, D-046). Capture of a production-only function.
--
-- public.run_seed_meetup_template(uuid, jsonb) exists on production (wtncuzcskpigqpmnxwws) with no migration in this
-- repository. CTO ruling (Khnum, 2026-11-04, option c): put it under version control unchanged, and classify it in the
-- KAN-712 step-7 cutover (20261103110000, section 4d) as an allowed INSERT writer. Its callers are unknown, so it is not
-- removed or rewritten.
--
-- Source: pg_get_functiondef read-only dump, KAN-844 comment 15527. Production prosrc md5
-- 74e763538070a1460fa4e1dc62f7cdf6 (length 6605). The body below reproduces that md5 byte for byte (proven on a local
-- PG16 load, supabase/tests/events_p4/kan851_run_seed_meetup_template_test.sql). One whitespace-only difference from the
-- transcribed dump: the blank line after 'no_eligible_seed_host_in_city' holds a single space on production; the
-- execute_sql transcription had dropped it.
--
-- Attributes match production: LANGUAGE plpgsql, SECURITY INVOKER, proconfig {"search_path=public, pg_temp"},
-- owner postgres, proacl {postgres=X/postgres,service_role=X/postgres}. On production this migration is a no-op.
--
-- KAN-712: the body only INSERTs into public.meetups and public.meetup_rsvps (no UPDATE, no DELETE, no dynamic SQL, no
-- trigger bypass). A meetups INSERT is routed by kan712_legacy_guard (BEFORE INSERT: the events parent is written
-- first); kan712_legacy_after_delete (AFTER DELETE) covers removal. Classification: KAN712_CONTRACT.md section 3.1.
CREATE OR REPLACE FUNCTION public.run_seed_meetup_template(p_template_id uuid, p_config jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
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

ALTER FUNCTION public.run_seed_meetup_template(uuid, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.run_seed_meetup_template(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.run_seed_meetup_template(uuid, jsonb) TO service_role;
