-- KAN-786 (Events P3, KAN-717 D1) -- a joined member can leave a meetup exactly once.
--
-- AUTHORED FOR REVIEW. Local proof only (throwaway PG16, clean git-archive build):
-- supabase/tests/events_p3/kan786_meetup_leave.sql.
--
-- ROOT CAUSE. public.rpc_meetup_rsvp(uuid,text,uuid,uuid) -- last defined at
-- 20260912190747_kan180_finding_b_meetup_rsvp_identity_and_profile_derivation.sql:116 (grants
-- 20260915120000_meetups_hardening.sql:740-741) -- calls can_current_user_rsvp_meetup() for EVERY action, at
-- kan180:142-146, and raises P0001 with the helper's cta whenever allowed=false. That helper (live body:
-- 20261104100000_kan713_access_helpers.sql:323; same check at kan180:68-70) returns allowed=false, cta='already'
-- whenever the caller holds a going/interested/pending RSVP (kan713_access_helpers.sql:367-369). So the only
-- callers who can reach the 'cancel' branch (kan180:188-192) are the ones who have nothing to cancel, and a
-- joined member's leave always raises P0001 'already'. The app's leave is exactly this call
-- (RsvpAction.cancel -> rpc_meetup_rsvp(p_action => 'cancel'); lib/features/meetups/domain/models/
-- meetup_enums.dart:57, data/datasources/supabase_meetup_datasource.dart:128-131).
--
-- FIX (only this function; the eligibility helper, RLS, visibility and games paths are untouched). For
-- p_action = 'cancel' the helper's 'already' denial is accepted (it means "is a member"); any other denial
-- raises as before. The update is the same statement as before; the old 'cancel' branch is removed because it is
-- now handled ahead of the join gate. Every other action is byte-for-byte the pre-image.
--
-- SECOND LEAVE (chosen behaviour): a 'cancel' by a caller with no going/interested/pending RSVP raises
-- SQLSTATE P0001, message 'not_attending' (same SQLSTATE as every other refusal of this RPC -> HTTP 400 through
-- PostgREST; a distinct message; never 'already'). No row changes and no second 'meetup.rsvp_cancelled' event.
-- The row lock taken by the UPDATE makes this hold under concurrency: of two racing leaves, one updates the row,
-- the other re-checks the status predicate, matches nothing and gets 'not_attending'.
--
-- KAN-712 HANDLING. rpc_meetup_rsvp is NOT KAN-712-wrapped: it writes meetup_rsvps only, never meetups/games,
-- and is absent from the 11-row inventory (supabase/tests/events_p2/KAN712_CONTRACT.md:52,68-78). The guard
-- below refuses if a kan712_wrapped_rpcs row or rpc_meetup_rsvp_kan712_inner exists (then the contract's
-- kan712_unwrap_rpc / kan712_wrap_rpc path must be used instead). Nothing to unwrap today.
--
-- DRIFT GUARD. The live body could not be read for this ticket (no production access); the pre-image is the
-- latest tracked definition (kan180:116). md5(prosrc) must equal that pre-image (a0a9a2176c9ccf11b3e1ca853b2c740a)
-- or this migration's own body (re-apply); anything else refuses. NOTE: the untracked
-- 20261105110000_kan714_events_parent_reads_2.sql (:2045) re-creates rpc_meetup_rsvp from the pre-image; if it
-- is applied after this migration it re-introduces the defect.
--
-- ATTRIBUTES / ACL. CREATE OR REPLACE keeps owner and proacl; SECURITY DEFINER and search_path=public restated
-- verbatim. Post-conditions assert: secdef, config, one overload, anon and PUBLIC cannot EXECUTE,
-- authenticated and service_role can.
--
-- IDEMPOTENT. A re-run passes the drift guard on the post-image md5 and re-creates the same body.
--
-- ROLLBACK (verbatim pre-image, kan180:116-206; CREATE OR REPLACE keeps the ACL):
--   CREATE OR REPLACE FUNCTION public.rpc_meetup_rsvp(p_meetup_id uuid, p_action text, p_profile_id uuid DEFAULT NULL::uuid, p_link_token uuid DEFAULT NULL::uuid)
--    RETURNS text
--    LANGUAGE plpgsql
--    SECURITY DEFINER
--    SET search_path TO 'public'
--   AS $function$
--   declare
--     d jsonb;
--     u uuid := auth.uid();
--     slots int;
--     v_profile_id uuid;
--   begin
--     if u is null then raise exception using errcode='P0001', message='auth_required'; end if;
--
--     -- p_profile_id is accepted for signature compatibility and deliberately ignored.
--     select p.id into v_profile_id
--     from public.profiles p
--     where p.user_id = u and p.is_active = true
--     order by p.created_at asc
--     limit 1;
--
--     -- 'cancel' stores no attribution, so it is not gated on having a profile.
--     if p_action <> 'cancel' and v_profile_id is null then
--       raise exception using errcode='P0001', message='no_active_profile';
--     end if;
--
--     d := public.can_current_user_rsvp_meetup(p_meetup_id, p_link_token);
--
--     if coalesce((d->>'allowed')::boolean, false) = false then
--       raise exception using errcode='P0001', message=coalesce(d->>'cta','not_allowed');
--     end if;
--
--     -- Accept invite path
--     if p_action = 'accept_invite' then
--       update public.meetup_invites
--          set status='accepted'
--        where meetup_id = p_meetup_id and to_user_id = u and status='pending';
--     end if;
--
--     -- Link consumption if needed
--     if (d->>'cta') = 'rsvp_going' and (select rsvp_policy from public.meetups where id=p_meetup_id) = 'link' then
--       perform public._meetup_link_consume(p_meetup_id, p_link_token);
--     end if;
--
--     -- Capacity check for 'going' (interested doesn't consume)
--     if p_action in ('going','accept_invite') then
--       select public.meetup_slots_left(p_meetup_id) into slots;
--       if slots = 0 then
--         -- mark as interested instead of failing hard
--         insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
--         values (p_meetup_id, u, v_profile_id, 'interested')
--         on conflict (meetup_id, user_id) do update set status='interested', profile_id=excluded.profile_id, updated_at=now();
--         perform public.emit_event('meetup.waitlisted','meetup', p_meetup_id, u, jsonb_build_object('reason','full'));
--         return 'interested';
--       end if;
--     end if;
--
--     -- Apply action
--     if p_action = 'going' or p_action = 'accept_invite' then
--       insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
--       values (p_meetup_id, u, v_profile_id, 'going')
--       on conflict (meetup_id, user_id) do update set status='going', profile_id=excluded.profile_id, updated_at=now();
--       perform public.emit_event('meetup.rsvp_going','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
--       return 'going';
--
--     elsif p_action = 'interested' then
--       insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
--       values (p_meetup_id, u, v_profile_id, 'interested')
--       on conflict (meetup_id, user_id) do update set status='interested', profile_id=excluded.profile_id, updated_at=now();
--       perform public.emit_event('meetup.rsvp_interested','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
--       return 'interested';
--
--     elsif p_action = 'cancel' then
--       update public.meetup_rsvps set status='cancelled', updated_at=now()
--       where meetup_id = p_meetup_id and user_id = u and status in ('going','interested','pending');
--       perform public.emit_event('meetup.rsvp_cancelled','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
--       return 'cancelled';
--
--     elsif p_action = 'request' then
--       -- translate to pending; owner may approve later (future)
--       insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
--       values (p_meetup_id, u, v_profile_id, 'pending')
--       on conflict (meetup_id, user_id) do update set status='pending', profile_id=excluded.profile_id, updated_at=now();
--       perform public.emit_event('meetup.rsvp_requested','meetup', p_meetup_id, u, jsonb_build_object('profile_id', v_profile_id));
--       return 'pending';
--
--     else
--       raise exception using errcode='P0001', message='invalid_action';
--     end if;
--   end;
--   $function$;
--

BEGIN;

DO $$
DECLARE v_md5 text;
BEGIN
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_meetup_rsvp') THEN
      RAISE EXCEPTION 'KAN-786: rpc_meetup_rsvp is KAN-712-wrapped -- use kan712_unwrap_rpc/kan712_wrap_rpc (KAN712_CONTRACT.md), stop';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_meetup_rsvp_kan712_inner') THEN
    RAISE EXCEPTION 'KAN-786: rpc_meetup_rsvp_kan712_inner exists -- use the KAN-712 unwrap path, stop';
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_meetup_rsvp') <> 1 THEN
    RAISE EXCEPTION 'KAN-786: expected exactly one rpc_meetup_rsvp overload, stop';
  END IF;
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure;
  IF v_md5 NOT IN ('a0a9a2176c9ccf11b3e1ca853b2c740a', 'acc145f2fa5cf81db600beef47fc6a6d') THEN
    RAISE EXCEPTION 'KAN-786: rpc_meetup_rsvp drifted from the reviewed pre-image (md5 %), re-author from pg_get_functiondef, stop', v_md5;
  END IF;
END $$;

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

DO $$
DECLARE p record;
BEGIN
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure;
  IF md5(p.prosrc) <> 'acc145f2fa5cf81db600beef47fc6a6d' THEN
    RAISE EXCEPTION 'KAN-786: post-condition failed, body md5 %', md5(p.prosrc);
  END IF;
  IF NOT p.prosecdef OR p.proconfig::text <> '{search_path=public}' THEN
    RAISE EXCEPTION 'KAN-786: post-condition failed, secdef=% config=%', p.prosecdef, p.proconfig;
  END IF;
  IF has_function_privilege('anon', p.oid, 'EXECUTE')
     OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0)
     OR NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     OR NOT has_function_privilege('service_role', p.oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-786: post-condition failed, ACL %', p.proacl;
  END IF;
END $$;

COMMIT;
