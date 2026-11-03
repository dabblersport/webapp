-- KAN-801 (KAN-718 D04 blockers #23, #24; Epic KAN-708): rpc_meetup_rsvp and rpc_meetup_set_attendee read their
-- shared meetup fields from public.events (via meetups.event_id), so both keep working after KAN-719 Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql) removes the legacy meetups columns.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof (throwaway PG16, git-archive build): supabase/tests/events_p4/kan801_meetup_rsvp_attendee.sql.
--
-- Two function bodies are replaced in place (CREATE OR REPLACE, same signature: owner and proacl are kept;
-- SECURITY DEFINER, volatility and search_path restated verbatim; all asserted in section 2). Exactly ONE
-- statement changes in each body; every other line is the pre-image byte for byte (pg_get_functiondef).
--
--   function                                   pre-image                          read moved to events
--   rpc_meetup_rsvp(uuid,text,uuid,uuid)        20261104110500_kan786 (md5 acc145f2) meetups.rsvp_policy -> events.join_policy
--                                                                                  (the link-consumption gate only; the KAN-786
--                                                                                  'cancel' / 'not_attending' path is untouched)
--   rpc_meetup_set_attendee(uuid,uuid,text)     baseline 20260829080500:13981      owner gate: m.owner_user_id -> events.creator_user_id
--                                               (md5 118f1db9; grants
--                                                20260915120000:746-747)
--
-- Each reads its parent as `public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'`
-- (the KAN-772 D04 pattern: event_id is NOT NULL + FK-validated since the KAN-712 cutover and events.id is the PK, so
-- the join neither drops nor doubles a row; an unknown meetup still yields NULL, exactly as before). The KAN-711
-- mirror maps meetups.rsvp_policy to events.join_policy (20261102110000:72). Both functions are SECURITY DEFINER,
-- owned by an RLS-bypassing owner, so FORCE RLS on public.events (KAN-710) does not affect them; no client grant
-- on events is needed or added. meetup_slots_left and can_current_user_rsvp_meetup already read events (KAN-727,
-- KAN-713) and are not touched.
--
-- rpc_meetup_set_attendee: the pre-image reads m.owner_user_id, a column public.meetups has never had (identity is
-- creator_user_id: 20260915120000_meetups_hardening.sql:16,370 recorded the same defect for rpc_meetup_cancel and
-- rewrote it on creator_user_id; KAN714_READ_MANIFEST.md:112). Whether the hosted body raises 42703 is not
-- documented (no production access). This rewrite takes the owner from events.creator_user_id, which is the
-- meetups_hardening reading of "owner"; the not_authenticated / rsvp_status_invalid / meetup_not_found /
-- not_meetup_owner checks, their order and messages, and the attendee upsert are unchanged.
--
-- Section 0 refuses unless (a) no meetup lacks its events parent, and (b) while the legacy columns still exist,
-- no meetup differs from its parent on rsvp_policy/join_policy or creator_user_id -- so applying this cannot change
-- a single result of the rsvp gate; afterwards events is the only source (KAN-712: events is the write target).
--
-- KAN-712: neither function is on the wrap list (KAN712_CONTRACT.md) -- both write meetup_rsvps / meetup_invites /
-- meetup_attendees, never meetups/games; section 0 refuses if either has been wrapped.
--
-- T-058 SUBSTITUTE (as KAN-772/KAN-786): production is not read here. Section 0 pins md5(prosrc) of each pre-image
-- as authored from the local catalogue (pg_get_functiondef) or this migration's own post-image (re-apply); any
-- other body refuses -- re-author from pg_get_functiondef on the live catalogue in that case.
--
-- KAN-714 part 2 (20261105110000_kan714_events_parent_reads_2.sql, sorts after Z01) also re-creates rpc_meetup_rsvp
-- and pins its pre-image to the KAN-786 md5 acc145f2; once this migration is applied that pin refuses
-- ('body drifted'). That file is not edited here.
--
-- No DROP, no table/column/grant/policy change, no row written.
--
-- ROLLBACK: re-run the two pre-image bodies (CREATE OR REPLACE keeps the ACL): rpc_meetup_rsvp from
-- 20261104110500_kan786_meetup_leave.sql (its CREATE OR REPLACE statement), rpc_meetup_set_attendee from
-- 20260829080500_baseline_schema.sql:13981-14007. Both are pinned by md5 in section 0 above.

BEGIN;
SET LOCAL lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
DO $pre$
DECLARE v_n bigint; r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-801 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL OR NOT EXISTS (SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'meetups' AND column_name = 'event_id') THEN
    RAISE EXCEPTION 'KAN-801 pre: public.events / meetups.event_id missing (KAN-710/711 not applied)';
  END IF;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name IN ('rpc_meetup_rsvp', 'rpc_meetup_set_attendee')) THEN
      RAISE EXCEPTION 'KAN-801 pre: a target function is KAN-712-wrapped; use kan712_unwrap_rpc/kan712_wrap_rpc, stop';
    END IF;
  END IF;
  FOR r IN SELECT * FROM (VALUES
      ('rpc_meetup_rsvp',         'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)',      'acc145f2fa5cf81db600beef47fc6a6d', '179b6c26a62edbd08d66acaba8f7a9a2'),
      ('rpc_meetup_set_attendee', 'public.rpc_meetup_set_attendee(uuid,uuid,text)',   '118f1db9bf66dff0d4a275c89b3703de', 'a2c59c757417b9d8fd2d687ba7b7e181'))
      AS t(name, sig, pre_md5, post_md5) LOOP
    IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = r.name || '_kan712_inner') THEN
      RAISE EXCEPTION 'KAN-801 pre: %_kan712_inner exists -- use the KAN-712 unwrap path, stop', r.name;
    END IF;
    IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = r.name) <> 1
       OR to_regprocedure(r.sig) IS NULL THEN
      RAISE EXCEPTION 'KAN-801 pre: expected exactly one overload %, stop', r.sig;
    END IF;
    IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig)) NOT IN (r.pre_md5, r.post_md5) THEN
      RAISE EXCEPTION 'KAN-801 pre: % drifted from the reviewed pre-image (md5 %), re-author from pg_get_functiondef, stop',
        r.sig, (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig));
    END IF;
    IF NOT (SELECT prosecdef AND provolatile = 'v' AND proconfig::text = '{search_path=public}'
              FROM pg_proc WHERE oid = to_regprocedure(r.sig)) THEN
      RAISE EXCEPTION 'KAN-801 pre: % attributes drifted (secdef/volatility/search_path), stop', r.sig;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_n FROM public.meetups m
    LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.id IS NULL;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-801 pre: % meetups have no events parent, stop', v_n;
  END IF;
  -- Only while the legacy columns exist (before Z01); a re-apply after Z01 skips this check.
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'meetups'
        AND column_name IN ('rsvp_policy', 'creator_user_id')) = 2 THEN
    EXECUTE $q$SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
               WHERE m.rsvp_policy IS DISTINCT FROM e.join_policy OR m.creator_user_id IS DISTINCT FROM e.creator_user_id$q$
      INTO v_n;
    IF v_n <> 0 THEN
      RAISE EXCEPTION 'KAN-801 pre: % meetups differ from their events parent on rsvp_policy/creator_user_id, stop', v_n;
    END IF;
  END IF;
END $pre$;

CREATE TEMP TABLE k801_acl ON COMMIT DROP AS
  SELECT oid, proacl::text AS acl, proowner FROM pg_proc
   WHERE oid IN ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure,
                 'public.rpc_meetup_set_attendee(uuid,uuid,text)'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 1. Bodies (pg_get_functiondef of the pre-image; one statement changed in each, marked in the header).
-- ---------------------------------------------------------------------------------------------------------
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
  if (d->>'cta') = 'rsvp_going' and (select e.join_policy from public.meetups m join public.events e on e.id = m.event_id and e.event_type = 'meetup' where m.id = p_meetup_id) = 'link' then
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

  select e.creator_user_id into owner from public.meetups m join public.events e on e.id = m.event_id and e.event_type = 'meetup' where m.id = p_meetup_id;
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

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; p record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)',    '179b6c26a62edbd08d66acaba8f7a9a2', 'text'),
      ('public.rpc_meetup_set_attendee(uuid,uuid,text)', 'a2c59c757417b9d8fd2d687ba7b7e181',   'void'))
      AS t(sig, post_md5, ret) LOOP
    SELECT * INTO p FROM pg_proc WHERE oid = r.sig::regprocedure;
    IF md5(p.prosrc) <> r.post_md5 THEN
      RAISE EXCEPTION 'KAN-801 post: % body md5 %', r.sig, md5(p.prosrc);
    END IF;
    IF NOT p.prosecdef OR p.provolatile <> 'v' OR p.proconfig::text <> '{search_path=public}'
       OR pg_get_function_result(p.oid) <> r.ret THEN
      RAISE EXCEPTION 'KAN-801 post: % attributes changed (secdef=% vol=% config=% ret=%)', r.sig, p.prosecdef, p.provolatile,
        p.proconfig, pg_get_function_result(p.oid);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM k801_acl a WHERE a.oid = p.oid AND a.acl IS NOT DISTINCT FROM p.proacl::text
                     AND a.proowner = p.proowner) THEN
      RAISE EXCEPTION 'KAN-801 post: % owner/ACL changed (now %)', r.sig, p.proacl;
    END IF;
    IF has_function_privilege('anon', p.oid, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE a.grantee = 0)
       OR NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
       OR NOT has_function_privilege('service_role', p.oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-801 post: % ACL %', r.sig, p.proacl;
    END IF;
    IF p.prosrc ~ 'rsvp_policy|owner_user_id' THEN
      RAISE EXCEPTION 'KAN-801 post: % still reads a legacy meetups column', r.sig;
    END IF;
  END LOOP;
END $post$;

COMMIT;
