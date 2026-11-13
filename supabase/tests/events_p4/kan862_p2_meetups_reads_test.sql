-- KAN-862 P2 live proof for supabase/migrations/20261113152746_kan862_p2_meetups_reads.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Nothing persists: the fixture edits, every call (each in its own subtransaction, always undone) and the pg_temp
-- twins are undone by the final ROLLBACK.
--
-- OBJECTS. can_current_user_rsvp_meetup, rpc_meetup_rsvp, rpc_meetup_decide_request, rpc_meetup_remove_attendee,
-- join_open_meetups_for_seeding, plan_traffic_campaign_jobs, run_traffic_campaign_jobs read the Z01-dropped meetups
-- columns from public.events. getnearbymeetups and rpc_meetup_visible were already broken before the migration
-- (42P01 / 42703); only their Z01 reads moved, and they must still raise exactly the same error.
--
-- TWINS. pg_temp.k862_pre_<fn> is the verbatim live pre-image body (T0 proves md5(prosrc) equals the pinned
-- pre-image md5), with SECURITY DEFINER dropped (the test runs as postgres, the owner). The twins were generated
-- from the migration's new bodies by reversing each change, so T0 also proves the new bodies differ from the
-- pre-images by exactly those changes. Mutants, derived from the twins: can_current_user ignores cancellation;
-- run_traffic_campaign_jobs ignores cancellation. They are the negative controls.
-- PHASES. 'live' uses the data as it is (32 meetups, none cancelled, policies mostly open). 'fixture' (kan712
-- contract on, events and meetups both written, parity asserted): one Dubai future meetup cancelled, one future
-- meetup full, one 'link'; four past meetups moved into the future as 'request' (+ a pending RSVP), 'invite'
-- (+ a pending invite), 'open' ('circle' is outside the events/meetups CHECK), 'closed'; today's traffic_jobs aged two days; queued meetup_join jobs added.
-- Each call captures the return value (or error) plus a snapshot of meetup_rsvps rows written in the transaction,
-- meetup_invites and traffic_jobs, taken inside the call's subtransaction before it is undone.
--   T0  twins are the pinned pre-images; mutants differ from their twins
--   T1  no public function outside the declared exceptions reads a Z01-dropped meetups column; the nine are clean;
--       the same scanner flags every pre-image twin                                             RED before apply
--   T2..T8 each changed function = its pre-image twin on every scenario, both phases
--   T9  getnearbymeetups / rpc_meetup_visible raise the same pre-existing error
--   T10 fixture parity: events and meetups agree on every shared column
--   T11 negative controls: each mutant differs from its twin
--   T12 capture not trivial
--   T13 attributes / ACL unchanged on all nine
--   T14 guard: in the fixture every enabled traffic campaign is inside its active window (the fixture opens it to 0..24),
--       so the jobs reach the meetup checks at any hour; without that, T7/T8 pass vacuously outside 09-22 Dubai
-- VALID ONLY BEFORE Z01: the twins read the columns Z01 drops.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862_cap (ph text, fn text, variant text, k text, v text) ON COMMIT DROP;

-- Pre-image twins (verbatim live bodies, SECURITY DEFINER dropped).
CREATE FUNCTION pg_temp.k862_pre_can_current_user_rsvp_meetup(p_meetup_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
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

  visible := public.can_view_with_scope(u, m.creator_user_id, m.listing_visibility, null)
         and public.can_view_with_scope(u, e.creator_user_id, e.listing_visibility, null);   -- KAN-713
  if not visible then
    return jsonb_build_object('allowed', false, 'cta','not_visible','reason','visibility_denied');
  end if;

  if m.is_cancelled or e.is_cancelled then
    return jsonb_build_object('allowed', false, 'cta','cancelled','reason','cancelled');
  end if;
  if m.start_at <= now() or e.start_at <= now() then
    return jsonb_build_object('allowed', false, 'cta','started','reason','started');
  end if;
  if e.join_policy is distinct from m.rsvp_policy then                                    -- KAN-713: fail closed
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','policy_mismatch');
  end if;

  if exists (select 1 from public.meetup_rsvps r where r.meetup_id=m.id and r.user_id=u and r.status in ('going','interested','pending')) then
    return jsonb_build_object('allowed', false, 'cta','already','reason','already');
  end if;

  case m.rsvp_policy
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
      if public.are_synced(u, m.creator_user_id) and public.are_synced(u, e.creator_user_id) then   -- KAN-713
        return jsonb_build_object('allowed', true, 'cta','rsvp_going');
      else
        return jsonb_build_object('allowed', false, 'cta','circle_only','reason','not_in_circle');
      end if;

    else
      return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','unknown_policy');
  end case;
end;
$function$;

CREATE FUNCTION pg_temp.k862_pre_rpc_meetup_rsvp(p_meetup_id uuid, p_action text, p_profile_id uuid DEFAULT NULL::uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
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
  if (d->>'cta') = 'rsvp_going' and (select rsvp_policy from public.meetups where id=p_meetup_id) = 'link' then
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

CREATE FUNCTION pg_temp.k862_pre_rpc_meetup_decide_request(p_meetup_id uuid, p_user_id uuid, p_decision text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_cur   text;
  v_new   text;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  if p_decision is null or p_decision not in ('approve','decline') then
    raise exception using errcode='P0001', message='invalid_decision';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
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

CREATE FUNCTION pg_temp.k862_pre_rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me  uuid := auth.uid();
  m   public.meetups%rowtype;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
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

CREATE FUNCTION pg_temp.k862_pre_join_open_meetups_for_seeding(p_max_meetups integer DEFAULT 10, p_joiners_per_meetup integer DEFAULT 1)
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
 SELECT mm.*,a.city FROM public.meetups mm
 JOIN public.areas a ON a.id=mm.area_id JOIN public.sports s ON s.id=mm.sport_id
 LEFT JOIN public.venues v ON v.id=mm.venue_id
 WHERE NOT mm.is_cancelled AND mm.start_at>now() AND mm.listing_visibility='public' AND mm.rsvp_policy='open'
 AND NOT mm.members_only AND mm.joining_rule='free' AND mm.cost_cover='free'
 AND mm.min_skill IS NULL AND mm.max_skill IS NULL AND s.is_active AND s.can_solo
 AND (v.id IS NULL OR (v.is_active AND v.name_en !~* '(ladies|women|female|men[ -]?only|male[ -]?only)'))
 ORDER BY mm.start_at,mm.id LIMIT p_max_meetups FOR UPDATE OF mm SKIP LOCKED
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

CREATE FUNCTION pg_temp.k862_pre_plan_traffic_campaign_jobs(p_limit integer DEFAULT 4)
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
 SELECT m.id INTO target FROM public.meetups m JOIN public.areas ar ON ar.id=m.area_id
 JOIN public.public_activities pa ON pa.id=m.id LEFT JOIN public.venues v ON v.id=m.venue_id
 WHERE ar.city=c.city AND m.sport_id=c.sport_id AND NOT m.is_cancelled AND m.start_at>now()
 AND m.listing_visibility='public' AND m.rsvp_policy='open' AND NOT m.members_only AND m.joining_rule='free' AND m.cost_cover='free'
 AND m.min_skill IS NULL AND m.max_skill IS NULL AND m.creator_user_id<>a.user_id
 AND (v.id IS NULL OR (v.is_active AND v.name_en !~* '(ladies|women|female|men[ -]?only|male[ -]?only)'))
 AND (m.capacity IS NULL OR (SELECT count(*) FROM public.meetup_rsvps r WHERE r.meetup_id=m.id AND r.status='going')<m.capacity)
 AND public.can_view_with_scope(a.user_id,m.creator_user_id,m.listing_visibility,null)
 AND NOT EXISTS(SELECT 1 FROM public.meetup_rsvps r WHERE r.meetup_id=m.id AND r.user_id=a.user_id)
 AND NOT EXISTS(SELECT 1 FROM public.traffic_jobs j WHERE j.actor_profile_id=a.id AND j.target_activity_id=m.id AND j.action_type=act)
 ORDER BY m.start_at,m.id LIMIT 1;
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

CREATE FUNCTION pg_temp.k862_pre_run_traffic_campaign_jobs(p_limit integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE j record; c public.traffic_campaigns%rowtype; a public.profiles%rowtype; po public.posts%rowtype; m public.meetups%rowtype;
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
 SELECT * INTO STRICT m FROM public.meetups WHERE id=j.target_activity_id FOR UPDATE;
 IF m.sport_id<>c.sport_id OR NOT EXISTS(SELECT 1 FROM public.areas WHERE id=m.area_id AND city=c.city)
 OR m.is_cancelled OR m.start_at<=now() OR m.listing_visibility<>'public' OR m.rsvp_policy<>'open' OR m.members_only OR m.joining_rule<>'free' OR m.cost_cover<>'free'
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

-- Mutants (negative controls), derived from the twins.
DO $mut$
DECLARE d text; n text;
BEGIN
  d := pg_get_functiondef('pg_temp.k862_pre_can_current_user_rsvp_meetup(uuid,uuid)'::regprocedure);
  n := replace(replace(d, 'k862_pre_can_current_user_rsvp_meetup', 'k862_mut_can_current_user_rsvp_meetup'),
               '  if m.is_cancelled or e.is_cancelled then', '  if false then');
  IF n = replace(d, 'k862_pre_can_current_user_rsvp_meetup', 'k862_mut_can_current_user_rsvp_meetup') THEN RAISE EXCEPTION 'mutant 1 unchanged'; END IF;
  EXECUTE n;
  d := pg_get_functiondef('pg_temp.k862_pre_run_traffic_campaign_jobs(integer)'::regprocedure);
  n := replace(replace(d, 'k862_pre_run_traffic_campaign_jobs', 'k862_mut_run_traffic_campaign_jobs'),
               ' OR m.is_cancelled OR m.start_at<=now()', ' OR m.start_at<=now()');
  IF n = replace(d, 'k862_pre_run_traffic_campaign_jobs', 'k862_mut_run_traffic_campaign_jobs') THEN RAISE EXCEPTION 'mutant 2 unchanged'; END IF;
  EXECUTE n;
END
$mut$;

-- The service_role jobs run their twins as service_role: grant it the twins (temp functions get no default grant here).
DO $grant$
DECLARE f regprocedure;
BEGIN
  FOR f IN SELECT p.oid::regprocedure FROM pg_proc p WHERE p.pronamespace = pg_my_temp_schema() AND p.proname ~ '^k862_(pre|mut)_' LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$grant$;

-- Lexical scanner: functions in a namespace that read a Z01-dropped meetups column (alias.col of a meetups alias or
-- meetups%rowtype variable; unqualified "select col from public.meetups where"; update set / insert column list;
-- NEW/OLD.col in a function attached to a meetups trigger).
CREATE FUNCTION pg_temp.k862_scan(p_nsp oid) RETURNS TABLE(fn text, why text)
LANGUAGE sql STABLE AS $f$
with d(c) as (values ('creator_profile_id'),('creator_user_id'),('title'),('listing_visibility'),('rsvp_policy'),('capacity'),
  ('start_at'),('end_at'),('is_cancelled'),('created_at'),('updated_at'),('search_tsv'),('geo_location_id'),('sport_id'),
  ('area_id'),('venue_id'),('min_skill'),('max_skill'),('joining_rule'),('cost_cover'),('request_id')),
dre as (select '(' || string_agg(c,'|') || ')' r from d),
f as (select p.oid, p.proname::text fn, p.prosrc s from pg_proc p where p.pronamespace = p_nsp and p.prosrc ~* '\mmeetups\M'),
al as (select f.oid, lower(x[1]) a from f, regexp_matches(f.s, 'public\.meetups\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') x
        where lower(x[1]) not in ('where','on','join','set','for','left','inner','order','group','limit','using','values','returning','select','and','or')
       union select f.oid, lower(x[1]) from f, regexp_matches(f.s, '([a-z_][a-z0-9_]*)\s+public\.meetups%rowtype', 'gi') x),
hits as (
  select f.fn, 'alias '||al.a||'.'||lower(h[1]) why from f join al using(oid), dre, regexp_matches(f.s, '\m'||al.a||'\.'||dre.r||'\M', 'gi') h
  union select f.fn, 'unqualified select '||lower(h[1]) from f, dre, regexp_matches(f.s, 'select\s+(?:[a-z_]+\.)?'||dre.r||'\s+from\s+public\.meetups\s+where', 'gi') h
  union select f.fn, 'update set '||lower(h[1]) from f, dre, regexp_matches(f.s, 'update\s+public\.meetups\s+set[^;]*?\m'||dre.r||'\s*=', 'gi') h
  union select f.fn, 'insert '||lower(h[1]) from f, dre, regexp_matches(f.s, 'insert\s+into\s+public\.meetups\s*\([^)]*\m'||dre.r||'\M', 'gi') h
  union select p.proname::text, 'trigger NEW/OLD.'||lower(h[1]) from pg_trigger t join pg_proc p on p.oid=t.tgfoid, dre,
         regexp_matches(p.prosrc, '\m(?:new|old)\.'||dre.r||'\M','gi') h
   where t.tgrelid='public.meetups'::regclass and not t.tgisinternal and p.pronamespace = p_nsp
) select fn, string_agg(distinct why, ', ') from hits group by fn
$f$;

-- Callers.
CREATE TEMP TABLE k862_u ON COMMIT DROP AS
SELECT * FROM (SELECT 'plain1'::text AS kind, x.user_id AS uid FROM (
  SELECT p.user_id, row_number() OVER (ORDER BY min(p.created_at), p.user_id) rn FROM public.profiles p
   WHERE p.is_active AND p.is_original IS DISTINCT FROM false AND NOT public.is_frozen(p.user_id) AND NOT public.is_admin(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r WHERE r.user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.meetup_invites i WHERE i.to_user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.event_type = 'meetup' AND e.creator_user_id = p.user_id)
   GROUP BY p.user_id) x WHERE x.rn = 1) a
UNION ALL SELECT * FROM (SELECT 'plain2', x.user_id FROM (
  SELECT p.user_id, row_number() OVER (ORDER BY min(p.created_at), p.user_id) rn FROM public.profiles p
   WHERE p.is_active AND p.is_original IS DISTINCT FROM false AND NOT public.is_frozen(p.user_id) AND NOT public.is_admin(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r WHERE r.user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.meetup_invites i WHERE i.to_user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.event_type = 'meetup' AND e.creator_user_id = p.user_id)
   GROUP BY p.user_id) x WHERE x.rn = 2) b
UNION ALL SELECT * FROM (SELECT 'going', r.user_id FROM public.meetup_rsvps r
   JOIN public.meetups m ON m.id = r.meetup_id JOIN public.events e ON e.id = m.event_id
  WHERE r.meetup_id = '78952b6c-5de2-40ed-98b3-e4962c5317af' AND r.status = 'going' AND r.user_id <> e.creator_user_id
    AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = r.user_id AND p.is_active)
  ORDER BY r.created_at, r.user_id LIMIT 1) c
UNION ALL SELECT * FROM (SELECT 'admin', g.user_id FROM public.role_grants g WHERE g.role IN ('admin', 'super_admin')
  ORDER BY g.user_id LIMIT 1) d   -- the only live admin has no profile row
UNION ALL SELECT 'anon', NULL::uuid;

-- Meetups: the four upcoming, the four most recent past, and a missing id.
CREATE TEMP TABLE k862_m ON COMMIT DROP AS
SELECT * FROM (VALUES ('Fa', '51d8495d-f065-4817-a233-c5791590fa35'::uuid), ('Fb', '6a48cba4-2b1a-4759-93ea-29ca9fa4feff'::uuid),
                      ('Fc', 'b08d10c6-ee20-4c7a-8cbb-7f7dbe6aecfd'::uuid), ('Fd', '78952b6c-5de2-40ed-98b3-e4962c5317af'::uuid)) v(tag, id)
UNION ALL SELECT 'P' || row_number() OVER (ORDER BY e.start_at DESC, m.id), m.id FROM (
  SELECT m.id, m.event_id FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE e.start_at <= now() ORDER BY e.start_at DESC, m.id LIMIT 4) m JOIN public.events e ON e.id = m.event_id
UNION ALL SELECT 'X', '86200000-0000-0000-0000-0000000000ee'::uuid;

-- Side-effect snapshot, read as postgres inside the call's subtransaction.
CREATE FUNCTION pg_temp.k862_snap() RETURNS text LANGUAGE sql VOLATILE AS $f$
  SELECT 'rsvp[' || coalesce((SELECT string_agg(r.meetup_id || ':' || r.user_id || ':' || r.status || ':' || coalesce(r.profile_id::text, ''), ',' ORDER BY r.meetup_id, r.user_id)
                                FROM public.meetup_rsvps r WHERE r.updated_at = now() OR r.created_at = now()), '') || ']'
      || ' inv=' || md5(coalesce((SELECT string_agg(i.id || ':' || i.status, ',' ORDER BY i.id) FROM public.meetup_invites i), ''))
      || ' jobs=' || md5(coalesce((SELECT string_agg(j.actor_profile_id || ':' || j.target_activity_id || ':' || j.action_type || ':' || j.status || ':' || j.attempts
                                     || ':' || coalesce(j.last_error, '') || ':' || coalesce((j.result - 'record_id')::text, '') || ':' || j.scheduled_at
                                     || ':' || coalesce(j.finished_at::text, ''), ',' ORDER BY j.actor_profile_id, j.target_activity_id, j.action_type)
                                   FROM public.traffic_jobs j), ''))
      || ' njobs_now=' || (SELECT count(*) FROM public.traffic_jobs j WHERE j.created_at = now() OR j.finished_at = now())
$f$;

-- One call as a caller (and role), in a subtransaction that is always undone. Returns result # snapshot, or the error.
CREATE FUNCTION pg_temp.k862_call(p_uid uuid, p_role text, p_sql text) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE r text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims',
      CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO r;
    IF p_role IS NOT NULL THEN RESET ROLE; END IF;
    s := pg_temp.k862_snap();
    r := coalesce(r, '<null>') || ' # ' || s;
    RAISE EXCEPTION 'k862_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(r, '<null>');
END $f$;

DO $run$
DECLARE ph text; mm record; u record; var text; fq text; tok uuid; act text; tgt record; dec text; host uuid; acc text; lim int[];
  v_camp uuid; v_sport uuid;
BEGIN
  FOREACH ph IN ARRAY ARRAY['live', 'fixture'] LOOP
    IF ph = 'fixture' THEN
      PERFORM set_config('kan712.contract', 'on', true);
      CREATE TEMP TABLE k862_fx ON COMMIT DROP AS
      SELECT m.tag, mt.id, mt.event_id FROM pg_temp.k862_m m JOIN public.meetups mt ON mt.id = m.id;
      -- events side
      UPDATE public.events e SET is_cancelled = true FROM k862_fx f WHERE f.tag = 'Fb' AND e.id = f.event_id;
      UPDATE public.events e SET capacity = (SELECT count(*) FROM public.meetup_rsvps r WHERE r.meetup_id = f.id AND r.status = 'going')
        FROM k862_fx f WHERE f.tag = 'Fa' AND e.id = f.event_id;
      UPDATE public.events e SET join_policy = 'link' FROM k862_fx f WHERE f.tag = 'Fc' AND e.id = f.event_id;
      UPDATE public.events e SET start_at = now() + interval '2 days', end_at = now() + interval '2 days 2 hours',
             join_policy = CASE f.tag WHEN 'P1' THEN 'request' WHEN 'P2' THEN 'invite' WHEN 'P3' THEN 'open' ELSE 'closed' END
        FROM k862_fx f WHERE f.tag IN ('P1', 'P2', 'P3', 'P4') AND e.id = f.event_id;
      -- meetups side (same values; the columns still exist before Z01)
      UPDATE public.meetups x SET is_cancelled = e.is_cancelled, capacity = e.capacity, rsvp_policy = e.join_policy,
             start_at = e.start_at, end_at = e.end_at
        FROM k862_fx f JOIN public.events e ON e.id = f.event_id WHERE x.id = f.id;
      INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
      SELECT f.id, uu.uid, (SELECT p.id FROM public.profiles p WHERE p.user_id = uu.uid AND p.is_active ORDER BY p.created_at LIMIT 1), 'pending'
        FROM k862_fx f, pg_temp.k862_u uu WHERE f.tag = 'P1' AND uu.kind = 'plain2';
      INSERT INTO public.meetup_invites (meetup_id, to_user_id, created_by, status)
      SELECT f.id, uu.uid, e.creator_user_id, 'pending'
        FROM k862_fx f JOIN public.events e ON e.id = f.event_id, pg_temp.k862_u uu WHERE f.tag = 'P2' AND uu.kind = 'plain1';
      UPDATE public.traffic_jobs SET created_at = created_at - interval '2 days', scheduled_at = scheduled_at - interval '2 days',
             expires_at = expires_at - interval '2 days', finished_at = finished_at - interval '2 days'
       WHERE created_at > now() - interval '2 days';
      -- Time independence: plan/run skip every campaign outside active_hour_start..active_hour_end (local), before any
      -- meetup check. Open the window to the whole day so the fixture exercises the meetup paths at any hour. T14 guards it.
      UPDATE public.traffic_campaigns SET active_hour_start = 0, active_hour_end = 24 WHERE enabled;
      INSERT INTO pg_temp.k862_cap
      SELECT ph, 'guard', 'guard', 'window',
             count(*) || ' enabled, ' || count(*) FILTER (WHERE extract(hour FROM now() AT TIME ZONE c.timezone) < c.active_hour_start
                                                              OR extract(hour FROM now() AT TIME ZONE c.timezone) >= c.active_hour_end) || ' outside window'
        FROM public.traffic_campaigns c WHERE c.enabled;
      SELECT c.id, c.sport_id INTO v_camp, v_sport FROM public.traffic_campaigns c WHERE c.enabled ORDER BY c.id LIMIT 1;
      INSERT INTO public.traffic_jobs (campaign_id, actor_profile_id, target_activity_id, action_type, scheduled_at, expires_at)
      -- Fb jobs first, ahead of the aged backlog, so the worker's LIMIT reaches them; actors with no RSVP on Fb/Fd.
      SELECT v_camp, a.id, f.id, 'meetup_join',
             now() - CASE f.tag WHEN 'Fb' THEN interval '3 days 1 minute' ELSE interval '3 days' END, now() + interval '1 hour'
        FROM (SELECT p.id FROM public.profiles p JOIN public.traffic_campaigns c ON c.id = v_camp
               WHERE p.is_original = false AND p.is_active AND p.city = c.city AND p.primary_sport = c.sport_id
                 AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r JOIN k862_fx f2 ON f2.id = r.meetup_id AND f2.tag IN ('Fb', 'Fd')
                                  WHERE r.user_id = p.user_id)
               ORDER BY p.id LIMIT 3) a, k862_fx f WHERE f.tag IN ('Fb', 'Fd')
          ON CONFLICT (actor_profile_id, target_activity_id, action_type) DO UPDATE SET status = 'queued', attempts = 0, last_error = NULL,
             result = NULL, finished_at = NULL, scheduled_at = excluded.scheduled_at, expires_at = excluded.expires_at;
    END IF;

    FOREACH var IN ARRAY ARRAY['live', 'pre', 'mut'] LOOP
      -- can_current_user_rsvp_meetup
      fq := CASE var WHEN 'live' THEN 'public.can_current_user_rsvp_meetup' WHEN 'pre' THEN 'pg_temp.k862_pre_can_current_user_rsvp_meetup'
                     ELSE 'pg_temp.k862_mut_can_current_user_rsvp_meetup' END;
      FOR mm IN SELECT m.tag, m.id, e.creator_user_id AS host FROM pg_temp.k862_m m
                  LEFT JOIN public.meetups x ON x.id = m.id LEFT JOIN public.events e ON e.id = x.event_id LOOP
        FOR u IN SELECT 'host'::text AS kind, mm.host AS uid UNION ALL SELECT * FROM pg_temp.k862_u LOOP
          FOREACH tok IN ARRAY ARRAY[NULL, '86200000-0000-0000-0000-00000000aaaa']::uuid[] LOOP
            INSERT INTO pg_temp.k862_cap VALUES (ph, 'can_current_user_rsvp_meetup', var, mm.tag || '/' || u.kind || '/' || coalesce(tok::text, '-'),
              pg_temp.k862_call(u.uid, NULL, format('SELECT %s(%L::uuid, %L::uuid)::text', fq, mm.id, tok)));
          END LOOP;
        END LOOP;
      END LOOP;
      CONTINUE WHEN var = 'mut';

      FOR mm IN SELECT m.tag, m.id, e.creator_user_id AS host FROM pg_temp.k862_m m
                  LEFT JOIN public.meetups x ON x.id = m.id LEFT JOIN public.events e ON e.id = x.event_id LOOP
        -- rpc_meetup_rsvp
        fq := CASE var WHEN 'live' THEN 'public.rpc_meetup_rsvp' ELSE 'pg_temp.k862_pre_rpc_meetup_rsvp' END;
        FOR u IN SELECT 'host'::text AS kind, mm.host AS uid UNION ALL SELECT * FROM pg_temp.k862_u WHERE kind <> 'admin' LOOP
          FOREACH act IN ARRAY ARRAY['going', 'interested', 'request', 'cancel', 'accept_invite', 'bogus'] LOOP
            INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_meetup_rsvp', var, mm.tag || '/' || u.kind || '/' || act,
              pg_temp.k862_call(u.uid, NULL, format('SELECT %s(%L::uuid, %L, NULL, NULL)', fq, mm.id, act)));
          END LOOP;
        END LOOP;
        -- rpc_meetup_decide_request
        fq := CASE var WHEN 'live' THEN 'public.rpc_meetup_decide_request' ELSE 'pg_temp.k862_pre_rpc_meetup_decide_request' END;
        FOR u IN SELECT 'host'::text AS kind, mm.host AS uid UNION ALL SELECT * FROM pg_temp.k862_u WHERE kind IN ('plain1', 'admin', 'anon') LOOP
          FOR tgt IN SELECT kind, uid FROM pg_temp.k862_u WHERE kind IN ('plain2', 'going') LOOP
            FOREACH dec IN ARRAY ARRAY['approve', 'decline'] LOOP
              INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_meetup_decide_request', var, mm.tag || '/' || u.kind || '/' || tgt.kind || '/' || dec,
                pg_temp.k862_call(u.uid, NULL, format('SELECT %s(%L::uuid, %L::uuid, %L)', fq, mm.id, tgt.uid, dec)));
            END LOOP;
          END LOOP;
        END LOOP;
        -- rpc_meetup_remove_attendee
        fq := CASE var WHEN 'live' THEN 'public.rpc_meetup_remove_attendee' ELSE 'pg_temp.k862_pre_rpc_meetup_remove_attendee' END;
        FOR u IN SELECT 'host'::text AS kind, mm.host AS uid UNION ALL SELECT * FROM pg_temp.k862_u WHERE kind IN ('plain1', 'admin') LOOP
          FOR tgt IN SELECT 'host'::text AS kind, mm.host AS uid UNION ALL SELECT kind, uid FROM pg_temp.k862_u WHERE kind IN ('plain1', 'plain2', 'going') LOOP
            INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_meetup_remove_attendee', var, mm.tag || '/' || u.kind || '/' || tgt.kind,
              pg_temp.k862_call(u.uid, NULL, format('SELECT %s(%L::uuid, %L::uuid)', fq, mm.id, tgt.uid)));
          END LOOP;
        END LOOP;
      END LOOP;

      -- service_role jobs (and one call as postgres, which must refuse)
      fq := CASE var WHEN 'live' THEN 'public.join_open_meetups_for_seeding' ELSE 'pg_temp.k862_pre_join_open_meetups_for_seeding' END;
      FOREACH lim SLICE 1 IN ARRAY ARRAY[[10, 1], [20, 3], [0, 1]] LOOP
        INSERT INTO pg_temp.k862_cap VALUES (ph, 'join_open_meetups_for_seeding', var, 'svc/' || lim[1] || '/' || lim[2],
          pg_temp.k862_call(NULL, 'service_role', format('SELECT %s(%s, %s)::text', fq, lim[1], lim[2])));
      END LOOP;
      INSERT INTO pg_temp.k862_cap VALUES (ph, 'join_open_meetups_for_seeding', var, 'postgres/10/1',
        pg_temp.k862_call(NULL, NULL, format('SELECT %s(10, 1)::text', fq)));
      fq := CASE var WHEN 'live' THEN 'public.plan_traffic_campaign_jobs' ELSE 'pg_temp.k862_pre_plan_traffic_campaign_jobs' END;
      FOREACH lim SLICE 1 IN ARRAY ARRAY[[4], [10]] LOOP
        INSERT INTO pg_temp.k862_cap VALUES (ph, 'plan_traffic_campaign_jobs', var, 'svc/' || lim[1],
          pg_temp.k862_call(NULL, 'service_role', format('SELECT %s(%s)::text', fq, lim[1])));
      END LOOP;
    END LOOP;

    FOREACH var IN ARRAY ARRAY['live', 'pre', 'mut'] LOOP
      fq := CASE var WHEN 'live' THEN 'public.run_traffic_campaign_jobs' WHEN 'pre' THEN 'pg_temp.k862_pre_run_traffic_campaign_jobs'
                     ELSE 'pg_temp.k862_mut_run_traffic_campaign_jobs' END;
      FOREACH lim SLICE 1 IN ARRAY ARRAY[[3], [10]] LOOP
        INSERT INTO pg_temp.k862_cap VALUES (ph, 'run_traffic_campaign_jobs', var, 'svc/' || lim[1],
          pg_temp.k862_call(NULL, 'service_role', format('SELECT %s(%s)::text', fq, lim[1])));
      END LOOP;
    END LOOP;

    -- already-broken SQL functions: the error itself is the result
    INSERT INTO pg_temp.k862_cap VALUES (ph, 'getnearbymeetups', 'live', 'dubai',
      pg_temp.k862_call(NULL, NULL, 'SELECT count(*)::text FROM public.getnearbymeetups(25.2, 55.27, 50000)'));
    INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_meetup_visible', 'live', 'all',
      pg_temp.k862_call(NULL, NULL, 'SELECT count(*)::text FROM public.rpc_meetup_visible()'));
  END LOOP;
END
$run$;

-- T0
INSERT INTO k862_tap SELECT 0,
  count(*) = 7 AND bool_and(md5(p.prosrc) = k.pre)
  AND (SELECT md5(prosrc) FROM pg_proc WHERE proname = 'k862_mut_can_current_user_rsvp_meetup' AND pronamespace = pg_my_temp_schema()) <> 'c88d88bb660071e03f0ec8785a767924'
  AND (SELECT md5(prosrc) FROM pg_proc WHERE proname = 'k862_mut_run_traffic_campaign_jobs' AND pronamespace = pg_my_temp_schema()) <> 'bcb0f52c06efd4fe7a91d91d31322d51',
  'twins are the pinned pre-images; mutants differ from their twins',
  string_agg(k.fn || '=' || left(md5(p.prosrc), 8), ' ' ORDER BY k.fn)
  FROM (VALUES ('can_current_user_rsvp_meetup', 'c88d88bb660071e03f0ec8785a767924'), ('rpc_meetup_rsvp', 'acc145f2fa5cf81db600beef47fc6a6d'),
               ('rpc_meetup_decide_request', 'd8c60f06cbc35e6b1e579a266863ba14'), ('rpc_meetup_remove_attendee', '7fec2761af25e3e0fd414922b7d07e6d'),
               ('join_open_meetups_for_seeding', '807234bf46b19845e6a4e6c405f81859'), ('plan_traffic_campaign_jobs', 'fa4bedc173a4fb988ed1fc112b52117a'),
               ('run_traffic_campaign_jobs', 'bcb0f52c06efd4fe7a91d91d31322d51')) k(fn, pre)
  JOIN pg_proc p ON p.proname = 'k862_pre_' || k.fn AND p.pronamespace = pg_my_temp_schema();

-- T1. Declared exceptions, each reported to the coordinator:
--   trigger functions whose meetups trigger Z01 drops (seq 302-333): fn_meetups_activity_sync, fn_meetups_enforce_solo_sport,
--     fn_meetups_inherit_geo, fn_meetups_sync_joining_rule, kan611_stamp_request_id, kan713_meetups_joining,
--     kan713_meetups_location, meetups_search_tsv_trigger, touch_updated_at, trg_meetups_cancel_notify, trg_touch_updated_at,
--     trgfn_meetups_outbox, kan712_legacy_guard (also out of P2 scope)
--   DECISION: fn_sync_geo_fields (trg_meetups_sync_geo is NOT in Z01's trigger list)
--   STOPPED write paths: rpc_create_meetup_legacy_v1, rpc_create_meetup_legacy_v2, rpc_meetup_cancel_kan712_inner,
--     rpc_meetup_update_kan712_inner, run_seed_meetup_template
INSERT INTO k862_tap SELECT 1,
  NOT EXISTS (SELECT 1 FROM pg_temp.k862_scan('public'::regnamespace) s WHERE s.fn NOT IN (
      'fn_meetups_activity_sync', 'fn_meetups_enforce_solo_sport', 'fn_meetups_inherit_geo', 'fn_meetups_sync_joining_rule',
      'kan611_stamp_request_id', 'kan713_meetups_joining', 'kan713_meetups_location', 'meetups_search_tsv_trigger',
      'touch_updated_at', 'trg_meetups_cancel_notify', 'trg_touch_updated_at', 'trgfn_meetups_outbox', 'kan712_legacy_guard',
      'fn_sync_geo_fields',
      'rpc_create_meetup_legacy_v1', 'rpc_create_meetup_legacy_v2', 'rpc_meetup_cancel_kan712_inner',
      'rpc_meetup_update_kan712_inner', 'run_seed_meetup_template'))
  AND (SELECT count(*) FROM pg_temp.k862_scan(pg_my_temp_schema()) s WHERE s.fn LIKE 'k862_pre_%') = 7,
  'no public function outside the declared exceptions reads a Z01-dropped meetups column; scanner flags all 7 twins',
  'public hits outside exceptions: ' || coalesce((SELECT string_agg(s.fn || ' (' || s.why || ')', '; ' ORDER BY s.fn) FROM pg_temp.k862_scan('public'::regnamespace) s
     WHERE s.fn IN ('can_current_user_rsvp_meetup', 'rpc_meetup_rsvp', 'rpc_meetup_decide_request', 'rpc_meetup_remove_attendee',
                    'join_open_meetups_for_seeding', 'plan_traffic_campaign_jobs', 'run_traffic_campaign_jobs', 'getnearbymeetups', 'rpc_meetup_visible')
        OR s.fn NOT IN ('fn_meetups_activity_sync', 'fn_meetups_enforce_solo_sport', 'fn_meetups_inherit_geo', 'fn_meetups_sync_joining_rule',
      'kan611_stamp_request_id', 'kan713_meetups_joining', 'kan713_meetups_location', 'meetups_search_tsv_trigger',
      'touch_updated_at', 'trg_meetups_cancel_notify', 'trg_touch_updated_at', 'trgfn_meetups_outbox', 'kan712_legacy_guard',
      'fn_sync_geo_fields', 'rpc_create_meetup_legacy_v1', 'rpc_create_meetup_legacy_v2', 'rpc_meetup_cancel_kan712_inner',
      'rpc_meetup_update_kan712_inner', 'run_seed_meetup_template')), 'none')
  || '; twins flagged: ' || (SELECT count(*) FROM pg_temp.k862_scan(pg_my_temp_schema()) s WHERE s.fn LIKE 'k862_pre_%');

-- T2..T8: live = twin
INSERT INTO k862_tap
SELECT 1 + o.ord, x.ndiff = 0 AND x.n > 0,
  o.fn || ' live = pre-image twin on every scenario, both phases',
  x.ndiff || ' differing of ' || x.n || coalesce('; first diff ' || x.d1, '')
FROM (VALUES (1, 'can_current_user_rsvp_meetup'), (2, 'rpc_meetup_rsvp'), (3, 'rpc_meetup_decide_request'), (4, 'rpc_meetup_remove_attendee'),
             (5, 'join_open_meetups_for_seeding'), (6, 'plan_traffic_campaign_jobs'), (7, 'run_traffic_campaign_jobs')) o(ord, fn)
CROSS JOIN LATERAL (
  SELECT count(*) AS n, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) AS ndiff,
         min(ph || '/' || k || ': ' || left(coalesce(a.v, '<none>'), 120) || ' <> ' || left(coalesce(b.v, '<none>'), 120)) FILTER (WHERE a.v IS DISTINCT FROM b.v) AS d1
    FROM (SELECT ph, k, v FROM k862_cap WHERE fn = o.fn AND variant = 'live') a
    FULL JOIN (SELECT ph, k, v FROM k862_cap WHERE fn = o.fn AND variant = 'pre') b USING (ph, k)) x;

-- T9: the two already-broken functions raise exactly the pre-existing error, both phases
INSERT INTO k862_tap SELECT 9,
  count(*) = 4 AND bool_and(v = CASE fn WHEN 'getnearbymeetups' THEN 'ERR 42P01 relation "public.geolocations" does not exist'
                                       ELSE 'ERR 42703 column m.starts_at does not exist' END),
  'getnearbymeetups / rpc_meetup_visible raise the same pre-existing error',
  string_agg(DISTINCT fn || ': ' || v, ' | ')
  FROM k862_cap WHERE fn IN ('getnearbymeetups', 'rpc_meetup_visible');

-- T10: fixture parity (still inside the transaction, after the fixture)
INSERT INTO k862_tap SELECT 10, count(*) = 0, 'fixture keeps events/meetups parity on every shared column', count(*) || ' rows out of parity'
  FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE e.id IS NULL
    OR (m.creator_user_id, m.title, m.listing_visibility, m.rsvp_policy, m.capacity, m.start_at, m.is_cancelled, m.sport_id, m.area_id,
        m.venue_id, m.min_skill, m.max_skill, m.joining_rule, m.cost_cover)
       IS DISTINCT FROM
       (e.creator_user_id, e.title, e.listing_visibility, e.join_policy, e.capacity, e.start_at, e.is_cancelled, e.sport_id, e.area_id,
        e.venue_id, e.min_skill::integer, e.max_skill::integer, e.joining_rule, e.cost_cover);

-- T11: negative controls
INSERT INTO k862_tap SELECT 11,
  count(*) FILTER (WHERE a.fn = 'can_current_user_rsvp_meetup' AND a.v IS DISTINCT FROM b.v) > 0
  AND count(*) FILTER (WHERE a.fn = 'run_traffic_campaign_jobs' AND a.v IS DISTINCT FROM b.v) > 0,
  'negative controls: each mutant differs from its twin',
  'can_current_user ' || count(*) FILTER (WHERE a.fn = 'can_current_user_rsvp_meetup' AND a.v IS DISTINCT FROM b.v)
  || ', run_traffic ' || count(*) FILTER (WHERE a.fn = 'run_traffic_campaign_jobs' AND a.v IS DISTINCT FROM b.v) || ' differing'
  FROM (SELECT * FROM k862_cap WHERE variant = 'mut') a
  JOIN (SELECT * FROM k862_cap WHERE variant = 'pre') b USING (ph, fn, k);

-- T12: capture not trivial
INSERT INTO k862_tap SELECT 12,
  (SELECT count(*) FROM pg_temp.k862_u WHERE uid IS NOT NULL) = 4
  AND count(DISTINCT v) FILTER (WHERE fn = 'can_current_user_rsvp_meetup') >= 8
  AND count(*) FILTER (WHERE fn = 'rpc_meetup_rsvp' AND v ~ '^(going|interested|pending|cancelled) # rsvp\[.+\]') > 0
  AND count(*) FILTER (WHERE fn = 'rpc_meetup_decide_request' AND ph = 'fixture' AND v ~ '^(going|interested|cancelled) #') > 0
  AND count(*) FILTER (WHERE fn = 'rpc_meetup_remove_attendee' AND v LIKE 'cancelled #%') > 0
  AND count(*) FILTER (WHERE fn = 'run_traffic_campaign_jobs' AND ph = 'fixture' AND v NOT LIKE '%"succeeded": 0, "skipped": 0%') > 0,
  'capture not trivial',
  'callers ' || (SELECT string_agg(kind, ',' ORDER BY kind) FROM pg_temp.k862_u WHERE uid IS NOT NULL)
  || '; can_current outcomes ' || count(DISTINCT v) FILTER (WHERE fn = 'can_current_user_rsvp_meetup')
  || '; join_open ' || coalesce(string_agg(DISTINCT ph || ':' || left(v, 70), ' / ') FILTER (WHERE fn = 'join_open_meetups_for_seeding' AND k = 'svc/10/1'), '')
  || '; plan ' || coalesce(string_agg(DISTINCT ph || ':' || left(v, 45), ' / ') FILTER (WHERE fn = 'plan_traffic_campaign_jobs' AND k = 'svc/4'), '')
  || '; run ' || coalesce(string_agg(DISTINCT ph || ':' || left(v, 60), ' / ') FILTER (WHERE fn = 'run_traffic_campaign_jobs' AND k = 'svc/10'), '')
  FROM k862_cap WHERE variant = 'pre';

-- T13: attributes / ACL unchanged
INSERT INTO k862_tap SELECT 13,
  count(*) = 9 AND bool_and(p.proowner = 'postgres'::regrole AND p.prosecdef = k.secdef AND p.provolatile::text = k.vol
    AND p.proconfig::text = k.cfg AND p.proacl::text = k.acl AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = k.lang)),
  'attributes / ACL unchanged on all nine', string_agg(k.fn || ' ' || p.proacl::text, '; ' ORDER BY k.fn)
  FROM (VALUES
    ('public.can_current_user_rsvp_meetup(uuid,uuid)', true, 's', '{search_path=public}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)', true, 'v', '{search_path=public}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_meetup_decide_request(uuid,uuid,text)', true, 'v', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_meetup_remove_attendee(uuid,uuid)', true, 'v', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.join_open_meetups_for_seeding(integer,integer)', false, 'v', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.plan_traffic_campaign_jobs(integer)', false, 'v', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.run_traffic_campaign_jobs(integer)', false, 'v', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.getnearbymeetups(double precision,double precision,double precision)', false, 's', '{"search_path=public, pg_temp"}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'sql'),
    ('public.rpc_meetup_visible()', false, 's', '{"search_path=public, pg_temp"}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'sql')
  ) k(fn, secdef, vol, cfg, acl, lang)
  JOIN pg_proc p ON p.oid = k.fn::regprocedure;

-- T14: the fixture's traffic jobs are not skipped for the time window (a vacuous T7/T8 is red, not green)
INSERT INTO k862_tap SELECT 14,
  count(*) = 1 AND bool_and(v ~ '^[1-9][0-9]* enabled, 0 outside window$'),
  'fixture: every enabled traffic campaign is inside its active window, so plan/run reach the meetup checks',
  coalesce(string_agg(v, ' | '), 'no guard row')
  FROM k862_cap WHERE fn = 'guard' AND ph = 'fixture';

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k862_tap;
ROLLBACK;
