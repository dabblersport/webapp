-- KAN-862 P2 (meetups): every live public function that READS a meetups column dropped by Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql, seq 701-724) reads it from public.events
-- instead (events.id = meetups.event_id AND event_type = 'meetup'; meetups.rsvp_policy is events.join_policy).
--
-- Each body below is the live pg_get_functiondef with ONLY the dropped-column reads changed. Signature,
-- return type, language, volatility, SECURITY DEFINER, search_path, owner and grants are unchanged
-- (CREATE OR REPLACE keeps owner and ACL; the trailer asserts both).
--
-- Behaviour is unchanged because the kan712 guard keeps meetups and events in parity on every shared
-- column (asserted below before anything is replaced). Where a body read BOTH copies (KAN-713 belt and
-- braces in can_current_user_rsvp_meetup), the two copies are equal under parity, so reading events once
-- returns the same answer; the 'policy_mismatch' branch can only fire when parity is broken and is removed
-- with the meetups copy it compared against.
--
-- getnearbymeetups and rpc_meetup_visible are ALREADY BROKEN on live before this migration
-- (42P01 relation "public.geolocations" does not exist; 42703 column m.starts_at does not exist).
-- Only their Z01 reads (m.title, m.is_cancelled) move to events; the broken references are left as they are
-- and the same error is raised after this migration. check_function_bodies is switched off locally so the
-- two SQL bodies can be replaced at all (then reset).
--
-- Supersedes the unapplied 20261104110600_kan801_d04_blockers_meetup_rsvp.sql and
-- 20261104110700_kan800_d04_blockers_meetup_requests.sql (moved to _superseded/).

-- 1. Refuse on drift: pre-image md5, attributes, and the parity the equivalence depends on.
do $pre$
declare
  v_bad text;
  v_n   int;
begin
  select string_agg(x.sig || ' expected ' || x.md5 || ' got ' || coalesce(md5(p.prosrc), 'MISSING'), '; ')
    into v_bad
    from (values
      ('public.can_current_user_rsvp_meetup(uuid,uuid)',                                  'c88d88bb660071e03f0ec8785a767924'),
      ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)',                                      'acc145f2fa5cf81db600beef47fc6a6d'),
      ('public.rpc_meetup_decide_request(uuid,uuid,text)',                                 'd8c60f06cbc35e6b1e579a266863ba14'),
      ('public.rpc_meetup_remove_attendee(uuid,uuid)',                                     '7fec2761af25e3e0fd414922b7d07e6d'),
      ('public.join_open_meetups_for_seeding(integer,integer)',                            '807234bf46b19845e6a4e6c405f81859'),
      ('public.plan_traffic_campaign_jobs(integer)',                                       'fa4bedc173a4fb988ed1fc112b52117a'),
      ('public.run_traffic_campaign_jobs(integer)',                                        'bcb0f52c06efd4fe7a91d91d31322d51'),
      ('public.getnearbymeetups(double precision,double precision,double precision)',      '37cd2aeed02a1c4ba6c0c5666137d693'),
      ('public.rpc_meetup_visible()',                                                      'fa63f35fdaf7d91d5956292ad8e2d10f')
    ) as x(sig, md5)
    left join pg_proc p on p.oid = to_regprocedure(x.sig)
   where p.oid is null or md5(p.prosrc) <> x.md5;
  if v_bad is not null then
    raise exception 'KAN-862 P2 refused: pre-image drift: %', v_bad;
  end if;

  select count(*) into v_n
    from public.meetups m
    left join public.events e on e.id = m.event_id and e.event_type = 'meetup'
   where e.id is null
      or (m.creator_user_id, m.title, m.listing_visibility, m.rsvp_policy, m.capacity, m.start_at,
          m.is_cancelled, m.sport_id, m.area_id, m.venue_id, m.min_skill, m.max_skill,
          m.joining_rule, m.cost_cover)
         is distinct from
         (e.creator_user_id, e.title, e.listing_visibility, e.join_policy, e.capacity, e.start_at,
          e.is_cancelled, e.sport_id, e.area_id, e.venue_id, e.min_skill::integer, e.max_skill::integer,
          e.joining_rule, e.cost_cover);
  if v_n <> 0 then
    raise exception 'KAN-862 P2 refused: % meetups rows are orphaned or out of parity with events', v_n;
  end if;
end
$pre$;

create temporary table k862_p2_pre as
select p.oid, p.oid::regprocedure::text as sig, p.proacl::text as acl, p.prosecdef, p.provolatile,
       p.proconfig::text as cfg, p.proowner, p.prorettype, p.proretset, p.prolang
  from pg_proc p
 where p.oid in ('public.can_current_user_rsvp_meetup(uuid,uuid)'::regprocedure,
                 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure,
                 'public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure,
                 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure,
                 'public.join_open_meetups_for_seeding(integer,integer)'::regprocedure,
                 'public.plan_traffic_campaign_jobs(integer)'::regprocedure,
                 'public.run_traffic_campaign_jobs(integer)'::regprocedure,
                 'public.getnearbymeetups(double precision,double precision,double precision)'::regprocedure,
                 'public.rpc_meetup_visible()'::regprocedure);

-- 2. can_current_user_rsvp_meetup: visibility, cancelled, started, policy and circle read events only.
CREATE OR REPLACE FUNCTION public.can_current_user_rsvp_meetup(p_meetup_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  u uuid := auth.uid();
  m public.meetups%rowtype;
  visible boolean;
  e public.events%rowtype;   -- KAN-713
begin
  if u is null then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','anon');
  end if;
  if public.is_frozen(u) then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','frozen');
  end if;

  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','not_found');
  end if;
  select * into e from public.events where id = m.event_id and event_type = 'meetup';   -- KAN-713
  if not found then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','not_found');
  end if;

  visible := public.can_view_with_scope(u, e.creator_user_id, e.listing_visibility, null);   -- KAN-713, KAN-862 P2: events only
  if not visible then
    return jsonb_build_object('allowed', false, 'cta','not_visible','reason','visibility_denied');
  end if;

  if e.is_cancelled then
    return jsonb_build_object('allowed', false, 'cta','cancelled','reason','cancelled');
  end if;
  if e.start_at <= now() then
    return jsonb_build_object('allowed', false, 'cta','started','reason','started');
  end if;

  if exists (select 1 from public.meetup_rsvps r where r.meetup_id=m.id and r.user_id=u and r.status in ('going','interested','pending')) then
    return jsonb_build_object('allowed', false, 'cta','already','reason','already');
  end if;

  case e.join_policy
    when 'open' then
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'request' then
      return jsonb_build_object('allowed', true, 'cta','request');

    when 'invite' then
      if exists (select 1 from public.meetup_invites i where i.meetup_id=m.id and i.to_user_id=u and i.status='pending') then
        return jsonb_build_object('allowed', true, 'cta','accept_invite');
      else
        return jsonb_build_object('allowed', false, 'cta','invite_only','reason','invite_required');
      end if;

    when 'link' then
      if p_link_token is null then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','missing_link');
      end if;
      if not public._meetup_link_valid(m.id, p_link_token) then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','invalid_link');
      end if;
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'closed' then
      return jsonb_build_object('allowed', false, 'cta','closed','reason','closed');

    when 'circle' then
      if public.are_synced(u, e.creator_user_id) then   -- KAN-713, KAN-862 P2: events only
        return jsonb_build_object('allowed', true, 'cta','rsvp_going');
      else
        return jsonb_build_object('allowed', false, 'cta','circle_only','reason','not_in_circle');
      end if;

    else
      return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','unknown_policy');
  end case;
end;
$function$;

-- 3. rpc_meetup_rsvp: the link-policy lookup reads events.join_policy.
CREATE OR REPLACE FUNCTION public.rpc_meetup_rsvp(p_meetup_id uuid, p_action text, p_profile_id uuid DEFAULT NULL::uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  d jsonb;
  u uuid := auth.uid();
  slots int;
  v_profile_id uuid;
begin
  if u is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- p_profile_id is accepted for signature compatibility and deliberately ignored.
  select p.id into v_profile_id
  from public.profiles p
  where p.user_id = u and p.is_active = true
  order by p.created_at asc
  limit 1;

  -- 'cancel' stores no attribution, so it is not gated on having a profile.
  if p_action <> 'cancel' and v_profile_id is null then
    raise exception using errcode='P0001', message='no_active_profile';
  end if;

  d := public.can_current_user_rsvp_meetup(p_meetup_id, p_link_token);

  -- KAN-786: leaving. The eligibility helper answers "may this caller JOIN?", and for a current member it
  -- answers allowed=false/cta='already' -- which used to block the member's own leave. For 'cancel' that one
  -- denial is the expected state; every other denial (anon/frozen/not_found/not_visible/cancelled/started/
  -- policy_mismatch) still refuses exactly as before. A caller with no active RSVP gets 'not_attending'.
  if p_action = 'cancel' then
    if coalesce((d->>'allowed')::boolean, false) = false
       and coalesce(d->>'cta','not_allowed') <> 'already' then
      raise exception using errcode='P0001', message=coalesce(d->>'cta','not_allowed');
    end if;
    update public.meetup_rsvps set status='cancelled', updated_at=now()
    where meetup_id = p_meetup_id and user_id = u and status in ('going','interested','pending');
    if not found then
      raise exception using errcode='P0001', message='not_attending';
    end if;
    perform public.emit_event('meetup.rsvp_cancelled','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
    return 'cancelled';
  end if;

  if coalesce((d->>'allowed')::boolean, false) = false then
    raise exception using errcode='P0001', message=coalesce(d->>'cta','not_allowed');
  end if;

  -- Accept invite path
  if p_action = 'accept_invite' then
    update public.meetup_invites
       set status='accepted'
     where meetup_id = p_meetup_id and to_user_id = u and status='pending';
  end if;

  -- Link consumption if needed
  if (d->>'cta') = 'rsvp_going' and (select e.join_policy from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup' where mt.id=p_meetup_id) = 'link' then
    perform public._meetup_link_consume(p_meetup_id, p_link_token);
  end if;

  -- Capacity check for 'going' (interested doesn't consume)
  if p_action in ('going','accept_invite') then
    select public.meetup_slots_left(p_meetup_id) into slots;
    if slots = 0 then
      -- mark as interested instead of failing hard
      insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
      values (p_meetup_id, u, v_profile_id, 'interested')
      on conflict (meetup_id, user_id) do update set status='interested', profile_id=excluded.profile_id, updated_at=now();
      perform public.emit_event('meetup.waitlisted','meetup', p_meetup_id, u, jsonb_build_object('reason','full'));
      return 'interested';
    end if;
  end if;

  -- Apply action
  if p_action = 'going' or p_action = 'accept_invite' then
    insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
    values (p_meetup_id, u, v_profile_id, 'going')
    on conflict (meetup_id, user_id) do update set status='going', profile_id=excluded.profile_id, updated_at=now();
    perform public.emit_event('meetup.rsvp_going','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
    return 'going';

  elsif p_action = 'interested' then
    insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
    values (p_meetup_id, u, v_profile_id, 'interested')
    on conflict (meetup_id, user_id) do update set status='interested', profile_id=excluded.profile_id, updated_at=now();
    perform public.emit_event('meetup.rsvp_interested','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
    return 'interested';

  elsif p_action = 'request' then
    -- translate to pending; owner may approve later (future)
    insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
    values (p_meetup_id, u, v_profile_id, 'pending')
    on conflict (meetup_id, user_id) do update set status='pending', profile_id=excluded.profile_id, updated_at=now();
    perform public.emit_event('meetup.rsvp_requested','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
    return 'pending';

  else
    raise exception using errcode='P0001', message='invalid_action';
  end if;
end;
$function$;

-- 4. rpc_meetup_decide_request: host and cancelled read events; the meetups row is still the row locked.
CREATE OR REPLACE FUNCTION public.rpc_meetup_decide_request(p_meetup_id uuid, p_user_id uuid, p_decision text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me      uuid := auth.uid();
  m       record;
  v_cur   text;
  v_new   text;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  if p_decision is null or p_decision not in ('approve','decline') then
    raise exception using errcode='P0001', message='invalid_decision';
  end if;

  select mt.id, e.creator_user_id, e.is_cancelled into m
    from public.meetups mt
    join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id for update of mt;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if m.is_cancelled then
    raise exception using errcode='P0001', message='meetup_cancelled';
  end if;

  select r.status into v_cur
    from public.meetup_rsvps r
   where r.meetup_id = p_meetup_id and r.user_id = p_user_id
   for update;
  if not found or v_cur <> 'pending' then
    raise exception using errcode='P0001', message='no_pending_request';
  end if;

  if p_decision = 'approve' then
    if public.meetup_slots_left(p_meetup_id) <= 0 then
      v_new := 'interested';
    else
      v_new := 'going';
    end if;
    update public.meetup_rsvps
       set status = v_new, updated_at = now()
     where meetup_id = p_meetup_id and user_id = p_user_id;
    perform public.emit_event('meetup.request_approved','meetup', p_meetup_id, me,
              jsonb_build_object('user_id', p_user_id, 'status', v_new));
  else
    v_new := 'cancelled';
    update public.meetup_rsvps
       set status = v_new, updated_at = now()
     where meetup_id = p_meetup_id and user_id = p_user_id;
    perform public.emit_event('meetup.request_declined','meetup', p_meetup_id, me,
              jsonb_build_object('user_id', p_user_id));
  end if;

  return v_new;
end;
$function$;

-- 5. rpc_meetup_remove_attendee: host reads events; the meetups row is still the row locked.
CREATE OR REPLACE FUNCTION public.rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me  uuid := auth.uid();
  m   record;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select mt.id, e.creator_user_id into m
    from public.meetups mt
    join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id for update of mt;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if p_user_id = m.creator_user_id then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  update public.meetup_rsvps
     set status = 'cancelled', updated_at = now()
   where meetup_id = p_meetup_id and user_id = p_user_id
     and status in ('going','interested','pending');
  if not found then
    raise exception using errcode='P0001', message='attendee_not_found';
  end if;

  perform public.emit_event('meetup.attendee_removed','meetup', p_meetup_id, me,
            jsonb_build_object('user_id', p_user_id));
  return 'cancelled';
end;
$function$;

-- 6. join_open_meetups_for_seeding: the candidate query reads events; members_only stays on meetups.
CREATE OR REPLACE FUNCTION public.join_open_meetups_for_seeding(p_max_meetups integer DEFAULT 10, p_joiners_per_meetup integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m record; p record; v_going int; v_added int; v_changed int; v_total int:=0; v_results jsonb:='[]'::jsonb; v_reason text;
BEGIN
 IF current_user<>'service_role' THEN RAISE EXCEPTION 'service_role_required'; END IF;
 IF p_max_meetups NOT BETWEEN 1 AND 20 OR p_joiners_per_meetup NOT BETWEEN 1 AND 3 OR p_max_meetups IS NULL OR p_joiners_per_meetup IS NULL THEN RAISE EXCEPTION 'invalid_seed_join_limits'; END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('app_traffic_join_open_meetups',0)) THEN
 RETURN jsonb_build_object('status','skipped','joined',0,'message','Another seed meetup join cycle is running','meetups','[]'::jsonb); END IF;
 FOR m IN
 SELECT mm.id,e.title,e.capacity,e.creator_user_id,e.listing_visibility,e.sport_id,a.city FROM public.meetups mm
 JOIN public.events e ON e.id=mm.event_id AND e.event_type='meetup'
 JOIN public.areas a ON a.id=e.area_id JOIN public.sports s ON s.id=e.sport_id
 LEFT JOIN public.venues v ON v.id=e.venue_id
 WHERE NOT e.is_cancelled AND e.start_at>now() AND e.listing_visibility='public' AND e.join_policy='open'
 AND NOT mm.members_only AND e.joining_rule='free' AND e.cost_cover='free'
 AND e.min_skill IS NULL AND e.max_skill IS NULL AND s.is_active AND s.can_solo
 AND (v.id IS NULL OR (v.is_active AND v.name_en !~* '(ladies|women|female|men[ -]?only|male[ -]?only)'))
 ORDER BY e.start_at,mm.id LIMIT p_max_meetups FOR UPDATE OF mm SKIP LOCKED
 LOOP
  v_added:=0; v_reason:='no_eligible_new_seed';
  SELECT count(*) INTO v_going FROM public.meetup_rsvps WHERE meetup_id=m.id AND status='going';
  IF m.capacity IS NOT NULL AND v_going>=m.capacity THEN
    v_results:=v_results||jsonb_build_array(jsonb_build_object('meetup_id',m.id,'title',m.title,'city',m.city,'joined',0,'reason','full'));
    CONTINUE;
  END IF;
  FOR p IN
   SELECT DISTINCT ON (pr.user_id) pr.id,pr.user_id,pr.display_name FROM public.profiles pr
   WHERE pr.is_original=false AND pr.is_active AND pr.city=m.city AND pr.primary_sport=m.sport_id
   AND NOT EXISTS (SELECT 1 FROM public.traffic_campaigns tc WHERE tc.enabled AND tc.city=pr.city AND tc.sport_id=pr.primary_sport)
   AND pr.user_id<>m.creator_user_id AND NOT public.is_frozen(pr.user_id)
   AND public.can_view_with_scope(pr.user_id,m.creator_user_id,m.listing_visibility,null)
   AND NOT EXISTS(SELECT 1 FROM public.meetup_rsvps r WHERE r.meetup_id=m.id AND r.user_id=pr.user_id)
   ORDER BY pr.user_id,pr.created_at
  LOOP
   EXIT WHEN v_added>=p_joiners_per_meetup;
   SELECT count(*) INTO v_going FROM public.meetup_rsvps WHERE meetup_id=m.id AND status='going';
   EXIT WHEN m.capacity IS NOT NULL AND v_going>=m.capacity;
   INSERT INTO public.meetup_rsvps(meetup_id,user_id,profile_id,status)
    VALUES(m.id,p.user_id,p.id,'going') ON CONFLICT(meetup_id,user_id) DO NOTHING;
   GET DIAGNOSTICS v_changed=ROW_COUNT;
   IF v_changed>0 THEN
    PERFORM public.emit_event('meetup.rsvp_going','meetup',m.id,p.user_id,jsonb_build_object('profile_id',p.id,'source','app_traffic_seed'));
    v_added:=v_added+1; v_total:=v_total+1; v_reason:='joined';
   END IF;
  END LOOP;
  v_results:=v_results||jsonb_build_array(jsonb_build_object('meetup_id',m.id,'title',m.title,'city',m.city,'joined',v_added,'reason',v_reason));
 END LOOP;
 RETURN jsonb_build_object('status','success','joined',v_total,'meetups_checked',jsonb_array_length(v_results),'meetups',v_results);
END $function$;

-- 7. plan_traffic_campaign_jobs: the meetup_join target query reads events; members_only stays on meetups.
CREATE OR REPLACE FUNCTION public.plan_traffic_campaign_jobs(p_limit integer DEFAULT 4)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; a record; act text; first_act text; actions text[]:=ARRAY['like','vibe','like','meetup_join','like','vibe','comment'];
 target uuid; vibe uuid; pl jsonb; v_count int:=0; v_today date; v_floor timestamptz; v_due timestamptz; v_hour int; v_n int; v_cap int; k int;
BEGIN
 IF current_user<>'service_role' THEN RAISE EXCEPTION 'service_role_required'; END IF;
 IF p_limit NOT BETWEEN 1 AND 10 OR p_limit IS NULL THEN RAISE EXCEPTION 'invalid_plan_limit'; END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('traffic_planner',0)) THEN RETURN jsonb_build_object('planned',0,'reason','planner_busy'); END IF;
 FOR c IN SELECT * FROM public.traffic_campaigns WHERE enabled ORDER BY id LOOP
 v_today:=(now() AT TIME ZONE c.timezone)::date;
 v_floor:=v_today::timestamp AT TIME ZONE c.timezone;
 v_hour:=extract(hour FROM now() AT TIME ZONE c.timezone);
 IF v_hour<c.active_hour_start OR v_hour>=c.active_hour_end THEN CONTINUE; END IF;
 SELECT count(*) INTO v_n FROM public.traffic_jobs WHERE campaign_id=c.id AND created_at>=v_floor;
 IF v_n>=c.campaign_daily_cap THEN CONTINUE; END IF;
 FOR a IN SELECT p.* FROM public.profiles p WHERE p.is_original=false AND p.is_active
 AND p.city=c.city AND p.primary_sport=c.sport_id AND NOT public.is_frozen(p.user_id)
 AND NOT EXISTS(SELECT 1 FROM public.traffic_jobs j WHERE j.actor_profile_id=p.id AND (j.status IN('queued','running') OR j.created_at>now()-make_interval(mins=>c.actor_cooldown_minutes)))
 ORDER BY md5(p.id::text||v_today::text||floor(extract(epoch FROM now())/900)::text) LOOP
 EXIT WHEN v_count>=p_limit OR v_n>=c.campaign_daily_cap;
 IF (SELECT count(*) FROM public.traffic_jobs WHERE actor_profile_id=a.id AND campaign_id=c.id AND created_at>=v_floor)>=c.actor_daily_cap THEN CONTINUE; END IF;
 k:=(('x'||substr(md5(a.id::text||v_today::text||floor(extract(epoch FROM now())/900)::text),1,7))::bit(28)::int % array_length(actions,1))+1;
 first_act:=actions[k];
 FOREACH act IN ARRAY ARRAY[first_act,'like','vibe','comment','meetup_join'] LOOP
 v_cap:=coalesce((c.action_caps->>act)::int,0);
 IF v_cap<=0 OR (SELECT count(*) FROM public.traffic_jobs WHERE actor_profile_id=a.id AND action_type=act AND created_at>=v_floor AND status IN('queued','running','succeeded'))>=v_cap THEN CONTINUE; END IF;
 target:=NULL; vibe:=NULL; pl:='{}';
 IF act='meetup_join' THEN
 SELECT m.id INTO target FROM public.meetups m JOIN public.events e ON e.id=m.event_id AND e.event_type='meetup' JOIN public.areas ar ON ar.id=e.area_id
 JOIN public.public_activities pa ON pa.id=m.id LEFT JOIN public.venues v ON v.id=e.venue_id
 WHERE ar.city=c.city AND e.sport_id=c.sport_id AND NOT e.is_cancelled AND e.start_at>now()
 AND e.listing_visibility='public' AND e.join_policy='open' AND NOT m.members_only AND e.joining_rule='free' AND e.cost_cover='free'
 AND e.min_skill IS NULL AND e.max_skill IS NULL AND e.creator_user_id<>a.user_id
 AND (v.id IS NULL OR (v.is_active AND v.name_en !~* '(ladies|women|female|men[ -]?only|male[ -]?only)'))
 AND (e.capacity IS NULL OR (SELECT count(*) FROM public.meetup_rsvps r WHERE r.meetup_id=m.id AND r.status='going')<e.capacity)
 AND public.can_view_with_scope(a.user_id,e.creator_user_id,e.listing_visibility,null)
 AND NOT EXISTS(SELECT 1 FROM public.meetup_rsvps r WHERE r.meetup_id=m.id AND r.user_id=a.user_id)
 AND NOT EXISTS(SELECT 1 FROM public.traffic_jobs j WHERE j.actor_profile_id=a.id AND j.target_activity_id=m.id AND j.action_type=act)
 ORDER BY e.start_at,m.id LIMIT 1;
 ELSE
 SELECT po.id INTO target FROM public.posts po JOIN public.areas ar ON ar.id=po.area_id JOIN public.public_activities pa ON pa.id=po.id
 WHERE ar.city=c.city AND po.sport_id=c.sport_id AND po.author_user_id<>a.user_id
 AND po.visibility='public' AND NOT po.is_deleted AND NOT po.is_hidden_admin AND po.is_active IS DISTINCT FROM false
 AND NOT pa.is_deleted AND NOT pa.is_hidden_admin AND (po.expires_at IS NULL OR po.expires_at>now())
 AND po.created_at>now()-interval '30 days' AND public.can_view_with_scope(a.user_id,po.author_user_id,po.visibility,null)
 AND NOT EXISTS(SELECT 1 FROM public.traffic_jobs j WHERE j.actor_profile_id=a.id AND j.target_activity_id=po.id AND j.action_type=act)
 AND CASE act
 WHEN 'like' THEN NOT EXISTS(SELECT 1 FROM public.likes l WHERE l.parent_activity_id=po.id AND l.profile_id=a.id)
 WHEN 'vibe' THEN NOT EXISTS(SELECT 1 FROM public.reactions r WHERE r.parent_activity_id=po.id AND r.actor_profile_id=a.id)
  AND EXISTS(SELECT 1 FROM public.vibes v WHERE v.is_active AND po.post_type::text=ANY(v.contexts))
 WHEN 'comment' THEN NOT EXISTS(SELECT 1 FROM public.comments cc WHERE cc.parent_activity_id=po.id AND cc.author_user_id=a.user_id)
  AND (SELECT count(*) FROM public.comments cc WHERE cc.author_user_id=a.user_id AND cc.created_at>=v_floor)<v_cap
  AND (SELECT count(*) FROM public.comments cc JOIN public.profiles pp ON pp.id=cc.author_profile_id WHERE cc.parent_activity_id=po.id AND pp.is_original=false AND cc.created_at>=v_floor)<3
 ELSE false END
 ORDER BY po.created_at DESC,po.id LIMIT 1;
 IF act='vibe' AND target IS NOT NULL THEN
 SELECT v.id INTO vibe FROM public.vibes v JOIN public.posts po ON po.id=target
 WHERE v.is_active AND po.post_type::text=ANY(v.contexts)
 ORDER BY CASE WHEN v.key IN('positive','supportive','inspired','motivated','energetic') THEN 0 ELSE 1 END,md5(v.id::text||a.id::text||target::text) LIMIT 1;
 pl:=jsonb_build_object('vibe_id',vibe);
 ELSIF act='comment' THEN
 pl:=jsonb_build_object('body',(ARRAY['Thanks for sharing this workout update 💪','Nice to see fitness activity in Dubai 💪','Thanks for sharing with the local fitness community.'])[1+(('x'||substr(md5(a.id::text||target::text),1,7))::bit(28)::int % 3)]);
 END IF;
 END IF;
 IF target IS NULL THEN CONTINUE; END IF;
 v_due:=now()+make_interval(mins=>1+(('x'||substr(md5(a.id::text||target::text||act),1,7))::bit(28)::int % 20));
 IF extract(hour FROM v_due AT TIME ZONE c.timezone)>=c.active_hour_end THEN CONTINUE; END IF;
 INSERT INTO public.traffic_jobs(campaign_id,actor_profile_id,target_activity_id,action_type,payload,scheduled_at,expires_at)
 VALUES(c.id,a.id,target,act,pl,v_due,v_due+interval '1 hour') ON CONFLICT(actor_profile_id,target_activity_id,action_type) DO NOTHING;
 GET DIAGNOSTICS k=ROW_COUNT;
 IF k>0 THEN v_count:=v_count+1;v_n:=v_n+1;EXIT; END IF;
 END LOOP;
 END LOOP;
 END LOOP;
 RETURN jsonb_build_object('status','success','planned',v_count);
END $function$;

-- 8. run_traffic_campaign_jobs: the meetup_join eligibility re-check reads events; the meetups row is still locked.
CREATE OR REPLACE FUNCTION public.run_traffic_campaign_jobs(p_limit integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE j record; c public.traffic_campaigns%rowtype; a public.profiles%rowtype; po public.posts%rowtype; m record;
 v_day timestamptz; v_hour int; v_done int:=0;v_skip int:=0;v_fail int:=0;v_rows int;v_id uuid;v_error text;v_state text;v_cap int;
BEGIN
 IF current_user<>'service_role' THEN RAISE EXCEPTION 'service_role_required'; END IF;
 IF p_limit NOT BETWEEN 1 AND 10 OR p_limit IS NULL THEN RAISE EXCEPTION 'invalid_worker_limit'; END IF;
 FOR j IN SELECT * FROM public.traffic_jobs WHERE status='queued' AND scheduled_at<=now()
 ORDER BY scheduled_at,id LIMIT p_limit FOR UPDATE SKIP LOCKED LOOP
 UPDATE public.traffic_jobs SET status='running',attempts=attempts+1 WHERE id=j.id;
 BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('traffic_campaign:'||j.campaign_id::text,0));
 SELECT * INTO STRICT c FROM public.traffic_campaigns WHERE id=j.campaign_id;
 SELECT * INTO STRICT a FROM public.profiles WHERE id=j.actor_profile_id;
 PERFORM pg_advisory_xact_lock(hashtextextended('traffic_actor:'||a.id::text,0));
 v_day:=((now() AT TIME ZONE c.timezone)::date)::timestamp AT TIME ZONE c.timezone;
 v_hour:=extract(hour FROM now() AT TIME ZONE c.timezone);
 v_cap:=coalesce((c.action_caps->>j.action_type)::int,0);
 IF NOT c.enabled OR a.is_original IS DISTINCT FROM false OR NOT coalesce(a.is_active,false) OR a.city<>c.city OR a.primary_sport<>c.sport_id OR public.is_frozen(a.user_id)
 OR j.expires_at<=now() OR v_hour<c.active_hour_start OR v_hour>=c.active_hour_end THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='disabled_ineligible_expired_or_quiet_hours'; END IF;
 IF (SELECT count(*) FROM public.traffic_jobs WHERE campaign_id=c.id AND actor_profile_id=a.id AND status='succeeded' AND finished_at>=v_day)>=c.actor_daily_cap
 OR (SELECT count(*) FROM public.traffic_jobs WHERE campaign_id=c.id AND actor_profile_id=a.id AND action_type=j.action_type AND status='succeeded' AND finished_at>=v_day)>=v_cap
 OR (SELECT count(*) FROM public.traffic_jobs WHERE campaign_id=c.id AND status='succeeded' AND finished_at>=v_day)>=c.campaign_daily_cap
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='daily_limit_reached'; END IF;
 IF EXISTS(SELECT 1 FROM public.traffic_jobs WHERE actor_profile_id=a.id AND status='succeeded' AND finished_at>now()-make_interval(mins=>c.actor_cooldown_minutes)) THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='actor_cooldown'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sports WHERE id=c.sport_id AND is_active) THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='inactive_sport'; END IF;
 v_rows:=0;v_id:=NULL;
 IF j.action_type='meetup_join' THEN
 SELECT mt.id,mt.members_only,e.sport_id,e.area_id,e.is_cancelled,e.start_at,e.listing_visibility,e.join_policy,e.joining_rule,e.cost_cover,e.min_skill,e.max_skill,e.venue_id,e.creator_user_id,e.capacity
 INTO STRICT m FROM public.meetups mt JOIN public.events e ON e.id=mt.event_id AND e.event_type='meetup' WHERE mt.id=j.target_activity_id FOR UPDATE OF mt;
 IF m.sport_id<>c.sport_id OR NOT EXISTS(SELECT 1 FROM public.areas WHERE id=m.area_id AND city=c.city)
 OR m.is_cancelled OR m.start_at<=now() OR m.listing_visibility<>'public' OR m.join_policy<>'open' OR m.members_only OR m.joining_rule<>'free' OR m.cost_cover<>'free'
 OR m.min_skill IS NOT NULL OR m.max_skill IS NOT NULL
 OR NOT EXISTS(SELECT 1 FROM public.sports WHERE id=m.sport_id AND can_solo)
 OR EXISTS(SELECT 1 FROM public.venues WHERE id=m.venue_id AND (NOT is_active OR name_en ~* '(ladies|women|female|men[ -]?only|male[ -]?only)'))
 OR m.creator_user_id=a.user_id OR NOT public.can_view_with_scope(a.user_id,m.creator_user_id,m.listing_visibility,null)
 OR (m.capacity IS NOT NULL AND (SELECT count(*) FROM public.meetup_rsvps WHERE meetup_id=m.id AND status='going')>=m.capacity)
 OR EXISTS(SELECT 1 FROM public.meetup_rsvps WHERE meetup_id=m.id AND user_id=a.user_id)
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='meetup_no_longer_eligible'; END IF;
 INSERT INTO public.meetup_rsvps(meetup_id,user_id,profile_id,status) VALUES(m.id,a.user_id,a.id,'going') ON CONFLICT(meetup_id,user_id) DO NOTHING RETURNING id INTO v_id;
 GET DIAGNOSTICS v_rows=ROW_COUNT;
 IF v_rows>0 THEN PERFORM public.emit_event('meetup.rsvp_going','meetup',m.id,a.user_id,jsonb_build_object('profile_id',a.id,'source','traffic_campaign')); END IF;
 ELSE
 SELECT * INTO STRICT po FROM public.posts WHERE id=j.target_activity_id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.public_activities WHERE id=po.id AND NOT is_deleted AND NOT is_hidden_admin) OR po.sport_id<>c.sport_id OR NOT EXISTS(SELECT 1 FROM public.areas WHERE id=po.area_id AND city=c.city)
 OR po.author_user_id=a.user_id OR po.is_deleted OR po.is_hidden_admin OR po.is_active IS FALSE OR po.visibility<>'public'
 OR (po.expires_at IS NOT NULL AND po.expires_at<=now())
 OR NOT public.can_view_with_scope(a.user_id,po.author_user_id,po.visibility,null)
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='post_no_longer_eligible'; END IF;
 IF j.action_type='like' THEN
 INSERT INTO public.likes(parent_activity_id,profile_id,actor_user_id) VALUES(po.id,a.id,a.user_id) ON CONFLICT(parent_activity_id,profile_id) DO NOTHING RETURNING id INTO v_id;
 GET DIAGNOSTICS v_rows=ROW_COUNT;
 ELSIF j.action_type='vibe' THEN
 IF NOT EXISTS(SELECT 1 FROM public.vibes WHERE id=(j.payload->>'vibe_id')::uuid AND is_active AND po.post_type::text=ANY(contexts))
 OR EXISTS(SELECT 1 FROM public.reactions WHERE parent_activity_id=po.id AND actor_profile_id=a.id)
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='vibe_no_longer_eligible'; END IF;
 INSERT INTO public.reactions(parent_activity_id,actor_profile_id,actor_user_id,vibe_id)
 VALUES(po.id,a.id,a.user_id,(j.payload->>'vibe_id')::uuid) ON CONFLICT(parent_activity_id,actor_profile_id,vibe_id) DO NOTHING RETURNING id INTO v_id;
 GET DIAGNOSTICS v_rows=ROW_COUNT;
 ELSIF j.action_type='comment' THEN
 IF EXISTS(SELECT 1 FROM public.comments WHERE parent_activity_id=po.id AND author_user_id=a.user_id)
 OR (SELECT count(*) FROM public.comments WHERE author_user_id=a.user_id AND created_at>=v_day)>=v_cap
 OR (SELECT count(*) FROM public.comments cc JOIN public.profiles pp ON pp.id=cc.author_profile_id WHERE cc.parent_activity_id=po.id AND pp.is_original=false AND cc.created_at>=v_day)>=3
 THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='comment_limit_or_duplicate'; END IF;
 INSERT INTO public.comments(parent_activity_id,author_profile_id,author_user_id,actor_user_id,body)
 VALUES(po.id,a.id,a.user_id,a.user_id,j.payload->>'body') RETURNING id INTO v_id;
 GET DIAGNOSTICS v_rows=ROW_COUNT;
 END IF;
 END IF;
 IF v_rows>0 THEN
 UPDATE public.traffic_jobs SET status='succeeded',result=jsonb_build_object('record_id',v_id,'action_type',j.action_type),last_error=NULL,finished_at=now() WHERE id=j.id;
 v_done:=v_done+1;
 ELSE
 UPDATE public.traffic_jobs SET status='skipped',last_error='Already exists',finished_at=now() WHERE id=j.id;v_skip:=v_skip+1;
 END IF;
 EXCEPTION WHEN OTHERS THEN
 GET STACKED DIAGNOSTICS v_error=MESSAGE_TEXT,v_state=RETURNED_SQLSTATE;
 IF v_state='P0002' THEN
 UPDATE public.traffic_jobs SET status='skipped',last_error=v_error,finished_at=now() WHERE id=j.id;v_skip:=v_skip+1;
 ELSIF v_state IN('40001','40P01','55P03','57014') AND j.attempts+1<j.max_attempts AND now()+interval '2 minutes'<j.expires_at THEN
 UPDATE public.traffic_jobs SET status='queued',scheduled_at=now()+interval '2 minutes',last_error=v_state||': '||v_error WHERE id=j.id;
 ELSE
 UPDATE public.traffic_jobs SET status='failed',last_error=v_state||': '||v_error,finished_at=now() WHERE id=j.id;v_fail:=v_fail+1;
 END IF;
 END;
 END LOOP;
 RETURN jsonb_build_object('status','success','succeeded',v_done,'skipped',v_skip,'failed',v_fail);
END $function$;

-- 9 and 10. Already-broken SQL bodies: only the Z01 reads move to events; the broken references stay.
SET check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.getnearbymeetups(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 10000)
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    m.id, e.title, m.starts_at,
    m.lat, m.lng, m.areaid,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    ) as distance_m
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  join public.geolocations gl on gl.id = m.geolocationid
  where e.is_cancelled = false
    and m.starts_at > now()
    and st_dwithin(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )
  order by distance_m asc;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_visible()
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, visibility text, owner_user_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select m.id, e.title, m.starts_at, m.visibility, m.owner_user_id
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  order by m.starts_at
$function$;

RESET check_function_bodies;

-- 11. Attributes and ACLs are exactly as before.
do $post$
declare
  v_bad text;
begin
  select string_agg(k.sig, ', ') into v_bad
    from k862_p2_pre k
    left join pg_proc p on p.oid = k.oid
   where p.oid is null
      or p.proacl::text      is distinct from k.acl
      or p.prosecdef         is distinct from k.prosecdef
      or p.provolatile       is distinct from k.provolatile
      or p.proconfig::text   is distinct from k.cfg
      or p.proowner          is distinct from k.proowner
      or p.prorettype        is distinct from k.prorettype
      or p.proretset         is distinct from k.proretset
      or p.prolang           is distinct from k.prolang;
  if v_bad is not null then
    raise exception 'KAN-862 P2: attributes or ACL changed on %', v_bad;
  end if;
  if (select count(*) from k862_p2_pre) <> 9 then
    raise exception 'KAN-862 P2: expected 9 functions in the pre-image snapshot';
  end if;
end
$post$;

drop table k862_p2_pre;
