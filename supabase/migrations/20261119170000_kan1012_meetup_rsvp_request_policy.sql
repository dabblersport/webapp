-- KAN-1012: rpc_meetup_rsvp('going'|'accept_invite') ignored join_policy='request' and wrote
-- status 'going' directly. On a request-policy meetup a non-host's join now becomes a pending
-- request (status 'pending', same row/state rpc_meetup_decide_request approves). Open/link/
-- circle/invite policies, 'interested', 'cancel', the host approval RPC and existing RSVPs are
-- unchanged. Authored from pg_get_functiondef; SECURITY DEFINER, search_path and grants kept
-- (CREATE OR REPLACE preserves proacl).
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

  -- KAN-1012: a request-policy meetup admits nobody straight to 'going' except its host; a
  -- non-host's join is recorded as a pending request for rpc_meetup_decide_request.
  if (d->>'cta') = 'request' and p_action in ('going','accept_invite')
     and not exists (select 1 from public.meetups mt
                       join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
                      where mt.id = p_meetup_id and e.creator_user_id = u) then
    p_action := 'request';
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
      -- KAN-1013: tell the notify trigger this Interested is a "Going" on a full meetup (cleared right after).
      perform set_config('dabbler.rsvp_full_downgrade', p_meetup_id::text, true);
      insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
      values (p_meetup_id, u, v_profile_id, 'interested')
      on conflict (meetup_id, user_id) do update set status='interested', profile_id=excluded.profile_id, updated_at=now();
      perform set_config('dabbler.rsvp_full_downgrade', '', true);
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
