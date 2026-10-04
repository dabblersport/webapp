-- KAN-427 WP1 -- probe pack for 20260915120000_meetups_hardening.sql
--
-- LOCATION: supabase/tests/kan427/ follows the existing probe convention in this
-- repository (supabase/tests/kan173/probes.sql, kan178/20_probes.sql). It is NOT
-- under supabase/migrations/ so the Supabase CLI can never try to run it.
--
-- STATUS: AUTHORED, NOT RUN. No database was available while writing this (and
-- the live project was off limits). Every probe below must be run by the apply
-- step TWICE: once BEFORE applying (the post-apply assertions are expected to
-- FAIL -- that is the proof each probe can fail), once AFTER applying (all must
-- pass). A probe nobody has seen fail is not evidence.
--
-- Every block is marked:
--   [READ-ONLY]                      reads catalogue / counts only
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK; nothing
--                                    persists. Run each as ONE statement batch.
-- No block deletes or updates an existing meetups row: scenario blocks create
-- their own meetup inside the transaction and roll it back.
--
-- ROLE CAVEAT: probes that matter run as `anon` / `authenticated` (SET LOCAL
-- ROLE) with request.jwt.claims set. Run as postgres they pass vacuously.

-- ===========================================================================
-- A. PRE-FLIGHT -- run BEFORE applying
-- ===========================================================================

-- A1 [READ-ONLY] live definitions of every function the migration replaces
--    (T-058: diff these against the bodies in the migration; stop on a surprise).
select p.oid::regprocedure as signature, pg_get_functiondef(p.oid) as def
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('rpc_create_meetup','rpc_meetup_cancel','rpc_meetup_attendees',
                    'rpc_meetup_card','meetup_counts','meetup_my_status')
order by 1;

-- A2 [READ-ONLY] DB-internal callers of the functions being dropped (expect 0 rows).
select p.oid::regprocedure as caller
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','util')
  and p.prosrc ~* '(rpc_meetup_create|rpc_meetup_unrsvp)'
  and p.proname not in ('rpc_meetup_create','rpc_meetup_unrsvp');
-- the legacy rpc_meetup_rsvp(uuid,text,text) is called by name 'rpc_meetup_rsvp'
-- too; callers using three args:
select p.oid::regprocedure as possible_caller
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','util') and p.prosrc ~* 'rpc_meetup_rsvp'
  and p.oid::regprocedure::text !~ '^rpc_meetup_rsvp';

-- A3 [READ-ONLY] BEFORE grant listing for every meetup function (save the output).
select p.oid::regprocedure as signature,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       p.proacl
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname ~ '^(rpc_meetup_|meetup_|rpc_draft_publish_meetup|rpc_booking_hold_for_meetup|rpc_create_meetup|can_current_user_rsvp_meetup|can_create_meetup)')
order by 1;

-- A4 [READ-ONLY] policy listing for meetup_rsvps (BEFORE: rsvp_self_write only;
--    AFTER: zero rows) and for meetups.
select polrelid::regclass as tbl, polname, polcmd, pg_get_expr(polqual, polrelid) as using_expr
from pg_policy where polrelid in ('public.meetup_rsvps'::regclass, 'public.meetups'::regclass)
order by 1, 2;

-- A5 [READ-ONLY] data-safety baseline: record these, they must be identical after.
select (select count(*) from public.meetups)        as meetups_rows,   -- expect 1
       (select count(*) from public.meetup_rsvps)   as rsvp_rows;      -- expect 0

-- ===========================================================================
-- B. POST-APPLY STATIC ASSERTIONS -- each raises if wrong.
--    Run BEFORE applying too: expected to RAISE (demonstrates the probe can fail).
-- ===========================================================================

-- B1 [READ-ONLY] anon cannot execute any meetup write function; PUBLIC neither.
do $$
declare s text; o oid;
begin
  foreach s in array array[
    'public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb)',
    'public.rpc_meetup_rsvp(uuid, text, uuid, uuid)',
    'public.rpc_meetup_cancel(uuid)',
    'public.rpc_meetup_set_attendee(uuid, uuid, text)',
    'public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)',
    'public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)',
    'public.rpc_meetup_update(uuid, text, text, timestamp with time zone, timestamp with time zone, text, integer)',
    'public.rpc_meetup_decide_request(uuid, uuid, text)',
    'public.rpc_meetup_remove_attendee(uuid, uuid)',
    'public.rpc_draft_publish_meetup(uuid)',
    'public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone)']
  loop
    o := s::regprocedure;   -- raises if the function does not exist
    if has_function_privilege('anon', o, 'EXECUTE') then
      raise exception 'B1 FAIL: anon can EXECUTE %', s; end if;
    if not has_function_privilege('authenticated', o, 'EXECUTE') then
      raise exception 'B1 FAIL: authenticated cannot EXECUTE %', s; end if;
  end loop;
  raise notice 'B1 PASS';
end $$;

-- B2 [READ-ONLY] anon attempted call is refused at the privilege check.
begin;
set local role anon;
do $$
begin
  begin
    perform public.rpc_meetup_cancel(gen_random_uuid());
    raise exception 'B2 FAIL: anon call was not refused';
  exception when insufficient_privilege then raise notice 'B2 PASS (42501)';
  end;
end $$;
rollback;

-- B3 [READ-ONLY] v_meetup_list has no creator_user_id, keeps creator_profile_id,
--    stays anon-readable (T-002 allowlist), v_meetup_counts is not anon-readable.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public'
             and table_name='v_meetup_list' and column_name='creator_user_id') then
    raise exception 'B3 FAIL: creator_user_id still in v_meetup_list'; end if;
  if not exists (select 1 from information_schema.columns where table_schema='public'
             and table_name='v_meetup_list' and column_name='creator_profile_id') then
    raise exception 'B3 FAIL: creator_profile_id missing'; end if;
  if not has_table_privilege('anon','public.v_meetup_list','SELECT') then
    raise exception 'B3 FAIL: anon lost v_meetup_list'; end if;
  if has_table_privilege('anon','public.v_meetup_counts','SELECT') then
    raise exception 'B3 FAIL: anon can read v_meetup_counts'; end if;
  raise notice 'B3 PASS';
end $$;
-- B3b [READ-ONLY] gate-equivalent: the anon-readable view set must still be within
--     the allowlist (scripts/ci/check_anon_allowlist.sh is the authority).
begin;
set local role anon;
select count(*) as anon_visible_meetups from public.v_meetup_list;  -- must not error
rollback;

-- B4 [READ-ONLY] rsvp_self_write gone; no client write path on the table.
do $$
begin
  if exists (select 1 from pg_policy where polrelid='public.meetup_rsvps'::regclass) then
    raise exception 'B4 FAIL: meetup_rsvps still has a policy'; end if;
  if has_table_privilege('authenticated','public.meetup_rsvps','INSERT')
     or has_table_privilege('authenticated','public.meetup_rsvps','UPDATE') then
    raise exception 'B4 FAIL: authenticated still holds table write grants'; end if;
  raise notice 'B4 PASS';
end $$;

-- B4b [READ-ONLY] meetup_rsvps readers are SECURITY DEFINER with a pinned search_path
-- (can_current_user_rsvp_meetup is called directly by the app, meetup_slots_left by
-- rpc_meetup_rsvp); both would fail for the caller once the table grants are revoked.
do $$
declare v_sig text; v_oid oid;
begin
  foreach v_sig in array array['public.can_current_user_rsvp_meetup(uuid, uuid)','public.meetup_slots_left(uuid)'] loop
    v_oid := v_sig::regprocedure;
    if not (select prosecdef from pg_proc where oid = v_oid) then
      raise exception 'B4b FAIL: % is not SECURITY DEFINER', v_sig; end if;
    if (select proconfig from pg_proc where oid = v_oid) is null then
      raise exception 'B4b FAIL: % has no search_path', v_sig; end if;
  end loop;
  if not has_function_privilege('anon','public.can_current_user_rsvp_meetup(uuid, uuid)','EXECUTE') then
    raise exception 'B4b FAIL: anon lost EXECUTE on can_current_user_rsvp_meetup'; end if;
  if has_function_privilege('anon','public.meetup_slots_left(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.meetup_slots_left(uuid)','EXECUTE') then
    raise exception 'B4b FAIL: anon or authenticated can EXECUTE meetup_slots_left(uuid)'; end if;
  raise notice 'B4b PASS';
end $$;

-- B5 [READ-ONLY] moderation_reports accepts target_type 'meetup' (enum value).
do $$
begin
  if not exists (select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
                 where t.typname='mod_target' and e.enumlabel='meetup') then
    raise exception 'B5 FAIL: mod_target lacks meetup'; end if;
  raise notice 'B5 PASS';
end $$;

-- B6 [READ-ONLY] the cancel body no longer references owner_user_id; attendees /
--    card / counts read meetup_rsvps and not the legacy table.
do $$
begin
  if (select prosrc from pg_proc where oid='public.rpc_meetup_cancel(uuid)'::regprocedure) ~ 'owner_user_id' then
    raise exception 'B6 FAIL: cancel still uses owner_user_id'; end if;
  if (select prosrc from pg_proc where oid='public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure) ~ 'meetup_attendees' then
    raise exception 'B6 FAIL: attendees reads legacy table'; end if;
  if (select prosrc from pg_proc where oid='public.rpc_meetup_card(uuid,text)'::regprocedure) ~ 'meetup_attendees|owner_user_id' then
    raise exception 'B6 FAIL: card reads legacy / owner_user_id'; end if;
  if (select prosrc from pg_proc where oid='public.meetup_counts(uuid)'::regprocedure) ~ 'meetup_attendees' then
    raise exception 'B6 FAIL: meetup_counts reads legacy table'; end if;
  raise notice 'B6 PASS';
end $$;

-- B7 [READ-ONLY] retired duplicates gone; data unchanged.
select (select count(*) from pg_proc where proname in ('rpc_meetup_create','rpc_meetup_unrsvp')) as retired_left,  -- 0
       (select count(*) from pg_proc where proname='rpc_meetup_rsvp') as rsvp_overloads,                          -- 1
       (select count(*) from public.meetups) as meetups_rows,                                                    -- 1
       (select count(*) from public.meetup_rsvps) as rsvp_rows;                                                  -- 0

-- ===========================================================================
-- C. BEHAVIOURAL SCENARIOS -- [WRITE-IN-TRANSACTION-ROLLBACK]
--    Each is one begin ... rollback. They pick real organiser / player users;
--    nothing persists.
-- ===========================================================================

-- C1 authenticated direct insert/update on meetup_rsvps is denied.
begin;
do $$
declare uid uuid; mid uuid;
begin
  select user_id into uid from public.profiles where is_active limit 1;
  select id into mid from public.meetups limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.meetup_rsvps(meetup_id, user_id, status) values (mid, uid, 'going');
    raise exception 'C1 FAIL: direct insert was allowed';
  exception when insufficient_privilege or others then
    if sqlerrm like 'C1 FAIL%' then raise; end if;
    raise notice 'C1 PASS (insert): %', sqlerrm;
  end;
  reset role;
end $$;
rollback;

-- C2 create guards, update guards, cancel guards, decide-request flow.
begin;
do $$
declare
  host_u uuid; host_p uuid; u1 uuid; u2 uuid; u3 uuid;
  sp uuid; var uuid; req int; mid uuid; st text; card jsonb; msg text;
begin
  select p.user_id, p.id into host_u, host_p
    from public.profiles p where p.persona_type='organiser' and p.is_active
      and public.can_create_meetup(p.id) limit 1;
  if host_u is null then raise exception 'FIXTURE: no organiser profile'; end if;

  select x.user_id into u1 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  select x.user_id into u2 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u, u1) order by x.created_at limit 1;
  select x.user_id into u3 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u, u1, u2) order by x.created_at limit 1;
  if u1 is null or u2 is null or u3 is null then raise exception 'FIXTURE: need 3 non-host player users'; end if;

  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  -- ---- host context
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;

  -- paid create rejected (via p_meta)
  begin
    perform public.rpc_create_meetup('organiser', sp, var, 'Probe paid', null, null, 'Probe loc', null, null,
            now()+interval '7 days', null, req+4, 'public', 'open', false, null, null, null,
            '{"joining_rule":"paid"}'::jsonb);
    raise exception 'C2 FAIL: paid create accepted';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'free_meetups_only' then raise exception 'C2 FAIL: paid create gave %', sqlerrm; end if;
  end;

  -- non-public create rejected
  begin
    perform public.rpc_create_meetup('organiser', sp, var, 'Probe circle', null, null, 'Probe loc', null, null,
            now()+interval '7 days', null, req+4, 'circle', 'open', false, null, null, null, null);
    raise exception 'C2 FAIL: circle create accepted';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'visibility_not_supported' then raise exception 'C2 FAIL: circle create gave %', sqlerrm; end if;
  end;

  -- valid create: request policy, capacity = required + 1 slot beyond host
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe meetup', 'd', null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req, 2), 'public', 'request', false, null, null, null, null);
  if mid is null then raise exception 'C2 FAIL: create returned null'; end if;

  -- host RSVP row exists as going in meetup_rsvps
  reset role;
  if not exists (select 1 from public.meetup_rsvps where meetup_id=mid and user_id=host_u and status='going') then
    raise exception 'C2 FAIL: host not recorded in meetup_rsvps'; end if;

  -- ---- u1 requests, host approves -> going (capacity left)
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated;
  st := public.rpc_meetup_rsvp(mid, 'request', null, null);
  if st <> 'pending' then raise exception 'C2 FAIL: request gave %', st; end if;
  -- B4b behavioural: the definer eligibility check still works for the caller after the grant revoke
  if public.can_current_user_rsvp_meetup(mid, null)->>'cta' <> 'already' then
    raise exception 'B4b FAIL: cta %', public.can_current_user_rsvp_meetup(mid, null)->>'cta'; end if;

  -- non-host decide fails
  begin
    perform public.rpc_meetup_decide_request(mid, u1, 'approve');
    raise exception 'C2 FAIL: non-host decide allowed';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'not_host' then raise exception 'C2 FAIL: non-host decide gave %', sqlerrm; end if;
  end;
  reset role;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  st := public.rpc_meetup_decide_request(mid, u1, 'approve');
  if st <> 'going' then raise exception 'C2 FAIL: approve gave % (expected going)', st; end if;
  reset role;

  -- ---- fill to capacity then approve -> interested
  -- (capacity = greatest(req,2): host + u1 are going; add going rows until full via the RPC)
  perform set_config('request.jwt.claims', json_build_object('sub', u2, 'role','authenticated')::text, true);
  set local role authenticated;
  st := public.rpc_meetup_rsvp(mid, 'request', null, null);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  -- raise capacity floor check: update below going count must fail
  begin
    perform public.rpc_meetup_update(mid, p_capacity => 1);
    raise exception 'C2 FAIL: capacity below going count accepted';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'capacity_below_going_count' then raise exception 'C2 FAIL: update gave %', sqlerrm; end if;
  end;
  -- set capacity exactly to current going count (2) so the next approve is "full"
  card := public.rpc_meetup_update(mid, p_capacity => 2, p_title => 'Probe meetup v2');
  if card->>'title' <> 'Probe meetup v2' then raise exception 'C2 FAIL: update did not change title'; end if;
  st := public.rpc_meetup_decide_request(mid, u2, 'approve');
  if st <> 'interested' then raise exception 'C2 FAIL: full approve gave % (expected interested)', st; end if;

  -- ---- decline -> cancelled
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u3, 'role','authenticated')::text, true);
  set local role authenticated;
  st := public.rpc_meetup_rsvp(mid, 'request', null, null);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  st := public.rpc_meetup_decide_request(mid, u3, 'decline');
  if st <> 'cancelled' then raise exception 'C2 FAIL: decline gave %', st; end if;

  -- ---- attendees list reads meetup_rsvps (host sees pending/cancelled too)
  if not exists (select 1 from public.rpc_meetup_attendees(mid) a where a.status = 'going') then
    raise exception 'C2 FAIL: attendees list empty / not from meetup_rsvps'; end if;

  -- ---- rpc_meetup_remove_attendee: host removes a going attendee; the host cannot be removed
  if public.rpc_meetup_remove_attendee(mid, u1) <> 'cancelled' then
    raise exception 'C2 FAIL: host remove_attendee did not return cancelled'; end if;
  begin
    perform public.rpc_meetup_remove_attendee(mid, host_u);
    raise exception 'C2 FAIL: removing the host accepted';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'cannot_remove_host' then raise exception 'C2 FAIL: remove host gave %', sqlerrm; end if;
  end;
  reset role;

  -- non-host remove_attendee fails
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.rpc_meetup_remove_attendee(mid, u3);
    raise exception 'C2 FAIL: non-host remove_attendee allowed';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'not_host' then raise exception 'C2 FAIL: non-host remove_attendee gave %', sqlerrm; end if;
  end;
  reset role;

  -- ---- non-host cancel fails; non-host update fails
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.rpc_meetup_cancel(mid);
    raise exception 'C2 FAIL: non-host cancel allowed';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'not_host' then raise exception 'C2 FAIL: non-host cancel gave %', sqlerrm; end if;
  end;
  begin
    perform public.rpc_meetup_update(mid, p_title => 'hijack');
    raise exception 'C2 FAIL: non-host update allowed';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'not_host' then raise exception 'C2 FAIL: non-host update gave %', sqlerrm; end if;
  end;
  reset role;

  -- ---- host cancel works; update on cancelled fails
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  if public.rpc_meetup_cancel(mid) <> 'ok' then raise exception 'C2 FAIL: host cancel'; end if;
  begin
    perform public.rpc_meetup_update(mid, p_title => 'after cancel');
    raise exception 'C2 FAIL: update on cancelled accepted';
  exception when others then
    if sqlerrm like 'C2 FAIL%' then raise; end if;
    if sqlerrm <> 'meetup_cancelled' then raise exception 'C2 FAIL: update-cancelled gave %', sqlerrm; end if;
  end;
  reset role;
  if not (select is_cancelled from public.meetups where id = mid) then
    raise exception 'C2 FAIL: meetup not flagged cancelled'; end if;

  raise notice 'C2 PASS (all scenario assertions held)';
end $$;
rollback;

-- C3 [READ-ONLY inside rollback] reports accept target_type 'meetup' (needs the
--    enum value committed first, i.e. run AFTER the migration is applied).
begin;
do $$
declare uid uuid; mid uuid; r public.moderation_reports;
begin
  select user_id into uid from public.profiles where is_active limit 1;
  select id into mid from public.meetups limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role','authenticated')::text, true);
  set local role authenticated;
  select * into r from public.report_content('meetup'::public.mod_target, mid, (select e.enumlabel from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='report_reason' order by e.enumsortorder limit 1)::public.report_reason, 'probe');
  if r.target_type::text <> 'meetup' then raise exception 'C3 FAIL'; end if;
  reset role;
  raise notice 'C3 PASS';
end $$;
rollback;   -- the report row is rolled back; no persistent write

-- ===========================================================================
-- D. AFTER grant / policy listing -- rerun A3 and A4 and diff against the BEFORE
--    output. Expected differences: anon_exec false on every write function and on
--    rpc_meetup_attendees / meetup_my_status; rpc_meetup_update,
--    rpc_meetup_decide_request, rpc_meetup_remove_attendee present; the four
--    retired signatures gone; meetup_rsvps policy list empty.
-- ===========================================================================
