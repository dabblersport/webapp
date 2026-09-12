-- KAN-180 Finding B.
--
-- Both bodies below were taken verbatim from pg_get_functiondef() on the live
-- catalogue (2026-09-12) and changed only where noted, so no stale attribute
-- can be reintroduced from a migration file.
--
-- Verified live before this migration:
--   1. public.can_current_user_rsvp_meetup(uuid,uuid) raises 42703
--      "record m has no field owner_user_id" for an authenticated caller on a
--      real meetup. public.meetups has no owner_user_id column; it has
--      creator_user_id, creator_profile_id and host_actor_id.
--      creator_user_id is the identity that governs meetup authorization:
--      the table's own live RLS SELECT policy meetups_select_visible calls
--      can_view_owner(creator_user_id, listing_visibility), can_view_owner is a
--      thin wrapper over can_view_with_scope(auth.uid(), owner_user_id, ...),
--      and can_view_with_scope compares that parameter as a user id throughout
--      (is_blocked, equality, are_synced, and a profile_follows join keyed by
--      profiles.user_id). host_actor_id appears in no authorization function.
--      m.owner_user_id here is a stale reference from before a column rename.
--   2. public.rpc_meetup_rsvp(uuid,text,uuid,uuid) stored the caller-supplied
--      p_profile_id verbatim into meetup_rsvps.profile_id. Proven live in a
--      rolled-back transaction: user 6996e1b2 RSVPed supplying profile
--      91f31cad, which belongs to user 36f785a2, and that spoofed profile was
--      the value stored (and propagated to public_activities.actor_profile_id
--      by fn_meetup_rsvps_activity_sync).
--
-- Security posture (SECURITY DEFINER / STABLE, search_path, and the existing
-- grants to anon/authenticated/service_role) is restated unchanged.

-- (1) Stale identity column. Only m.owner_user_id -> m.creator_user_id, in the
--     can_view_with_scope call and in the 'circle' branch's are_synced call.
--     m.listing_visibility is already correct and is left alone.
CREATE OR REPLACE FUNCTION public.can_current_user_rsvp_meetup(p_meetup_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  u uuid := auth.uid();
  m public.meetups%rowtype;
  visible boolean;
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

  visible := public.can_view_with_scope(u, m.creator_user_id, m.listing_visibility, null);
  if not visible then
    return jsonb_build_object('allowed', false, 'cta','not_visible','reason','visibility_denied');
  end if;

  if m.is_cancelled then
    return jsonb_build_object('allowed', false, 'cta','cancelled','reason','cancelled');
  end if;
  if m.start_at <= now() then
    return jsonb_build_object('allowed', false, 'cta','started','reason','started');
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
      if public.are_synced(u, m.creator_user_id) then
        return jsonb_build_object('allowed', true, 'cta','rsvp_going');
      else
        return jsonb_build_object('allowed', false, 'cta','circle_only','reason','not_in_circle');
      end if;

    else
      return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','unknown_policy');
  end case;
end;
$function$;

-- (2) Stored attribution must not be attacker-controlled. The wire signature is
--     unchanged (removing a parameter is an unruled API decision, out of scope,
--     and lib/ has zero call sites for rpc_meetup_rsvp); p_profile_id is now
--     ignored and the stored value is derived from auth.uid(), following the
--     caller's-own-active-profile pattern already used by choose_actor().
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

  elsif p_action = 'cancel' then
    update public.meetup_rsvps set status='cancelled', updated_at=now()
    where meetup_id = p_meetup_id and user_id = u and status in ('going','interested','pending');
    perform public.emit_event('meetup.rsvp_cancelled','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
    return 'cancelled';

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
