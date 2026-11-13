-- KAN-800 (supporting KAN-772 / KAN-719, Epic KAN-708; meetup twin of KAN-799): the two D04 BLOCKER functions that
-- are absent from the local chain (supabase/tests/events_p4/KAN718_D04_DISPOSITION.md rows 19/22) now read their
-- shared fields from public.events, so they keep working after KAN-719 Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql) drops those columns from public.meetups.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan800_d04_meetup_requests_test.sql (throwaway PG16; it installs the
-- pre-images as a fixture because the local chain has neither function).
--
-- No DROP, no table/column/grant/policy change, no row written, no write path changed. Two bodies are replaced in
-- place (CREATE OR REPLACE, same signature, so owner and ACL are kept; asserted in section 3):
--
--   function                                     field(s) now read from events   pre-image
--   rpc_meetup_decide_request(uuid,uuid,text)    creator_user_id, is_cancelled   20260915120000_meetups_hardening:622-686
--   rpc_meetup_remove_attendee(uuid,uuid)        creator_user_id                 20260915120000_meetups_hardening:691-731
--
-- Each pre-image read the whole meetups row (`m public.meetups%rowtype; select * into m ... for update`) and then
-- used only m.creator_user_id (both) and m.is_cancelled (decide). The rowtype becomes `m record`, filled with exactly
-- those columns from events; every later `m.<field>` reference is byte-identical. The row lock is unchanged: it stays
-- on public.meetups (`for update of mt`), which is the KAN-712 lock order (meetups before events) that KAN-714 part 2
-- also kept. The parent is joined as `public.events ev ON ev.id = mt.event_id AND ev.event_type = 'meetup'` (INNER:
-- event_id is NOT NULL and FK-validated since the KAN-712 cutover and events.id is the PK, so the join neither drops
-- nor doubles a row; section 0 also refuses if any meetup lacks its typed parent). Every other byte of each body is
-- the pre-image's.
--
-- KAN-712 INTERACTION: neither function writes public.meetups or public.events. Both write public.meetup_rsvps
-- (status, updated_at) and call public.emit_event (outbox); decide also calls public.meetup_slots_left (unchanged,
-- already events-backed since KAN-714 B08). So there is no write to route through the KAN-712 contract and none is
-- added (no dual write). Section 0 refuses if either has been put on the KAN-712 wrap list (kan712_wrapped_rpcs).
--
-- KAN-714 PART 2 INTERACTION: 20261105110000_kan714_events_parent_reads_2.sql (authored, not applied) drift-pins
-- these two functions' md5(prosrc) to the same values pinned below and re-authors them through its overlay view.
-- Once this file is applied, that file's drift pin refuses for these two (by design: re-author it from
-- pg_get_functiondef, or drop them from its list).
--
-- T-058 SUBSTITUTE (as KAN-772 / KAN-799): production is not read here. Section 0 pins md5(prosrc), SECURITY,
-- volatility and search_path of each pre-image as authored in 20260915120000 (the same md5 values KAN-714 part 2
-- pinned independently); any drift fails closed -- re-author from pg_get_functiondef on the live catalogue then.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_n bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-800 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-800 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_zz_kan712_events_compat_mirror' and tgenabled <> 'D') then
    raise exception 'KAN-800 pre: KAN-712 cutover not live (compat mirror trigger on events missing or disabled)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w where w.name in ('rpc_meetup_decide_request', 'rpc_meetup_remove_attendee')) then
    raise exception 'KAN-800 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY DEFINER | volatility | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.rpc_meetup_decide_request(uuid,uuid,text)', 'd8c60f06cbc35e6b1e579a266863ba14'),
      ('public.rpc_meetup_remove_attendee(uuid,uuid)',     '7fec2761af25e3e0fd414922b7d07e6d')
    ) t(f, src)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or not p.prosecdef or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-800 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Every meetup has exactly its typed parent (KAN-712 cutover invariant).
  select count(*) into v_n
    from public.meetups m left join public.events e on e.id = m.event_id and e.event_type = 'meetup'
   where e.id is null;
  if v_n <> 0 then
    raise exception 'KAN-800 pre: % meetup row(s) without their typed events parent', v_n;
  end if;

  -- No value this file starts reading from events may differ from the legacy mirror.
  select count(*) into v_n
    from public.meetups m join public.events e on e.id = m.event_id
   where (m.creator_user_id, m.is_cancelled) is distinct from (e.creator_user_id, e.is_cancelled);
  if v_n <> 0 then
    raise exception 'KAN-800 pre: % meetup row(s) differ from events on a field this migration starts reading; reconcile first (KAN-711 parity)', v_n;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image attributes (asserted unchanged in section 3).
-- ---------------------------------------------------------------------------------------------------------
create temp table kan800_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as res, p.prorettype, p.prosecdef, p.provolatile, p.proconfig, p.proacl,
       p.proowner, p.proretset, p.proisstrict, p.proparallel, p.pronargdefaults
  from pg_proc p
 where p.oid in ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure,
                 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacements. Pre-image bodies verbatim except the reads listed in the header.
-- ---------------------------------------------------------------------------------------------------------
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

  select ev.creator_user_id, ev.is_cancelled into m from public.meetups mt join public.events ev on ev.id = mt.event_id and ev.event_type = 'meetup' where mt.id = p_meetup_id for update of mt;
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

  select ev.creator_user_id into m from public.meetups mt join public.events ev on ev.id = mt.event_id and ev.event_type = 'meetup' where mt.id = p_meetup_id for update of mt;
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

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions: signature, result, security, volatility, search_path, owner and ACL unchanged.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare v_bad text;
begin
  select string_agg(b.fn, ', ') into v_bad
    from kan800_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or (pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prorettype, p.prosecdef,
          p.provolatile, p.proconfig, p.proacl::text, p.proowner, p.proretset, p.proisstrict, p.proparallel,
          p.pronargdefaults)
         is distinct from
         (b.args, b.res, b.prorettype, b.prosecdef, b.provolatile, b.proconfig, b.proacl::text, b.proowner,
          b.proretset, b.proisstrict, b.proparallel, b.pronargdefaults);
  if v_bad is not null then
    raise exception 'KAN-800 post: attributes changed for %', v_bad;
  end if;
  if (select count(*) from kan800_pre) <> 2 then
    raise exception 'KAN-800 post: expected 2 functions, saw %', (select count(*) from kan800_pre);
  end if;
end
$post$;

commit;
