-- KAN-1013 (CEO 2026-11-17): a "Going" tap on a full meetup is stored as Interested, and the organiser was told
-- "X showed interest". It now sends its own kind, meetup.wants_to_join_full. A real Interested still sends
-- meetup.rsvp_interested, unchanged.
--
-- Where the two cases split: rpc_meetup_rsvp, branch p_action in ('going','accept_invite') with meetup_slots_left = 0.
-- The row is the same ('interested') in both cases, so around that one write the RPC sets a transaction-local marker
-- dabbler.rsvp_full_downgrade = <meetup id> (same pattern as dabbler.push_body) and clears it right after.
-- trg_meetup_rsvp_interested_notify (the one sender) picks the kind from the marker.
--
-- Grouping: like Interested (KAN-980) -- 1-hour window, push cap 900 s, in-app only (push off) -- but its own group
-- family, so a "wants to come" card never merges into an "interested" card.
-- CREATE OR REPLACE only, from the live definitions; one kind row and one rule row inserted. No DROP, no DELETE.
-- Out of scope: the request-approval gap (KAN-1012), bans (KAN-1014).

-- 0. Pre-image guard ---------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure))
       <> 'ed912f8ab3cb642f2527505cbeda433c' THEN
    RAISE EXCEPTION 'KAN-1013 guard: rpc_meetup_rsvp changed since it was read';
  END IF;
  IF md5(pg_get_functiondef('public.trg_meetup_rsvp_interested_notify()'::regprocedure))
       <> 'e793b9be88ebac4b53a0122b0e446b9b' THEN
    RAISE EXCEPTION 'KAN-1013 guard: trg_meetup_rsvp_interested_notify changed since it was read';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds WHERE key = 'meetup.wants_to_join_full')
     OR EXISTS (SELECT 1 FROM public.notification_aggregation_rules WHERE kind_key = 'meetup.wants_to_join_full') THEN
    RAISE EXCEPTION 'KAN-1013 guard: meetup.wants_to_join_full already exists';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.notification_aggregation_rules
                  WHERE kind_key = 'meetup.rsvp_interested' AND enabled AND aggregation_window_seconds = 3600
                    AND push_cap_seconds = 900 AND NOT push_enabled AND group_family = 'meetup_interested') THEN
    RAISE EXCEPTION 'KAN-1013 guard: the meetup.rsvp_interested rule is not the one this copies';
  END IF;
END
$guard$;

-- 1. Kind and its grouping rule --------------------------------------------------------------------------------------
INSERT INTO public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, is_active,
   title_template_en, title_template_ar, body_template_en, body_template_ar, breaks_quiet, can_mute, category)
VALUES
  ('meetup.wants_to_join_full',
   'Someone wants to come to your full meet-up', 'شخص يريد حضور لقائك المكتمل',
   'low', '{inapp}', true,
   '{actor} wants to come to {title}, but it''s full', '{actor} يريد حضور {title}، لكنه مكتمل',
   'They''ll get a place if one opens.', 'سيحصل على مكان إذا توفّر.',
   false, true, 'meetups');

INSERT INTO public.notification_aggregation_rules
  (kind_key, aggregation_window_seconds, min_actors_to_aggregate, enabled, group_family, mixed_kind_key,
   push_enabled, push_cap_seconds)
VALUES ('meetup.wants_to_join_full', 3600, 1, true, 'meetup_wants_full', NULL, false, 900);

-- 2. rpc_meetup_rsvp (from the live definition): mark the full-meetup downgrade --------------------------------------
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

-- 3. trg_meetup_rsvp_interested_notify (from the live definition): pick the kind ------------------------------------
CREATE OR REPLACE FUNCTION public.trg_meetup_rsvp_interested_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_host  uuid;
  v_title text;
  v_full  boolean;
  v_kind  text;
  v_key   text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'interested' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  -- the host approving a request into 'interested' (meet-up full) is not the member's own Interested RSVP
  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND v_actor IS NOT NULL AND v_actor <> NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT e.creator_user_id, e.title INTO v_host, v_title
    FROM public.kan714_meetups_read m
    JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE m.id = NEW.meetup_id;
  IF v_host IS NULL OR v_host = NEW.user_id THEN RETURN NEW; END IF;

  -- KAN-1013: a "Going" tap on a full meetup (marked by rpc_meetup_rsvp) is its own kind.
  v_full := COALESCE(current_setting('dabbler.rsvp_full_downgrade', true), '') = NEW.meetup_id::text;
  v_kind := CASE WHEN v_full THEN 'meetup.wants_to_join_full' ELSE 'meetup.rsvp_interested' END;
  v_key  := 'meetup_rsvps:' || NEW.id::text || CASE WHEN v_full THEN ':wants_full' ELSE ':interested' END;

  PERFORM public.notify_v2(
    v_host, v_kind, jsonb_build_object('title', COALESCE(v_title, '')),
    'meetup', NEW.meetup_id, NEW.user_id,
    v_key, v_key);
  RETURN NEW;
END;
$function$;
