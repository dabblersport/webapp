-- KAN-431 WP5 -- probe pack for 20260915150000_meetups_notifications.sql
--
-- STATUS: AUTHORED, NOT RUN. No database was available while writing this and the
-- live project was off limits. Run the apply step's probes TWICE: once BEFORE
-- applying (section B/C are expected to FAIL -- the proof each probe can fail),
-- once AFTER applying (all must pass). A probe nobody has seen fail is not evidence.
--
-- Every block is marked:
--   [READ-ONLY]                      reads catalogue / counts only
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK; nothing persists
-- No block deletes or updates an existing row: scenarios create their own meetup
-- inside the transaction and roll it back.
-- ROLE CAVEAT: actions run as `authenticated` with request.jwt.claims set (the
-- triggers read auth.uid()); assertions run after RESET ROLE. As postgres with no
-- claims, auth.uid() is null and the approve/decline paths are (correctly) silent.
--
-- PRECONDITION for the push probes (C5): vault secrets supabase_anon_key and
-- push_trigger_secret exist. Without them trg_push_on_notification_insert raises a
-- WARNING and sends nothing, and the "push ON" assertion fails (visible, not silent).

-- ===========================================================================
-- A. CATALOGUE -- [READ-ONLY]
-- ===========================================================================

-- A1 [READ-ONLY] the five kinds exist, active, EN + AR labels, push channel. Expect 5 rows
--    AFTER, 0 BEFORE.
select key, label_en, label_ar, default_priority, default_channels, route_template, is_active
from public.notification_kinds
where key in ('meetup.rsvp_received','meetup.request_received','meetup.request_approved',
              'meetup.request_declined','meetup.cancelled')
order by key;

-- A2 [READ-ONLY] both triggers exist and are enabled ('O'). Expect 2 rows AFTER.
select t.tgname, t.tgrelid::regclass as on_table, t.tgenabled, pg_get_triggerdef(t.oid) as def
from pg_trigger t
where not t.tgisinternal and t.tgname in ('trg_meetup_rsvps_notify','trg_meetups_cancel_notify');

-- A3 [READ-ONLY] function owner / definer / search_path / acl. Expect owner postgres,
--    prosecdef true, search_path pinned, anon_exec false, auth_exec false.
select p.oid::regprocedure as fn, pg_get_userbyid(p.proowner) as owner, p.prosecdef, p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec, p.proacl
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('trg_meetup_rsvps_notify','trg_meetups_cancel_notify');

-- A4 [READ-ONLY] KAN-182 untouched: authenticated must NOT execute process_notification_event.
select has_function_privilege('authenticated',
  'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure, 'EXECUTE') as must_be_false;

-- A5 [READ-ONLY] pre-flight (T-058): live bodies of everything this migration relies on.
select p.oid::regprocedure as signature, pg_get_functiondef(p.oid) as def
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('process_notification_event','emit_event','fn_meetup_rsvps_activity_sync',
                    'fn_public_activities_notify','trg_push_on_notification_insert','trgfn_meetups_outbox')
order by 1;

-- A6 [READ-ONLY] no other notification trigger on these tables will double-fire.
select t.tgrelid::regclass as on_table, t.tgname, pg_get_triggerdef(t.oid)
from pg_trigger t
where not t.tgisinternal and t.tgrelid in ('public.meetup_rsvps'::regclass, 'public.meetups'::regclass)
order by 1, 2;

-- ===========================================================================
-- B/C. BEHAVIOUR -- [WRITE-IN-TRANSACTION-ROLLBACK]. Run each as ONE batch.
-- ===========================================================================

-- C1 request: host gets exactly ONE meetup.request_received; the requester gets none;
--    the host's own going row (rpc_create_meetup) notifies nobody.
begin;
do $$
declare
  host_u uuid; host_p uuid; u1 uuid; sp uuid; var uuid; req int; mid uuid; n int;
begin
  select p.user_id, p.id into host_u, host_p from public.profiles p
   where p.persona_type='organiser' and p.is_active and public.can_create_meetup(p.id) limit 1;
  select x.user_id into u1 from public.profiles x
   where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  if host_u is null or u1 is null then raise exception 'FIXTURE: need an organiser and a player'; end if;
  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe notif request', null, null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req,6), 'public', 'request', false, null, null, null, null);
  reset role;

  select count(*) into n from public.notifications
   where kind_key like 'meetup.%' and context->>'entity_id' = mid::text;
  if n <> 0 then raise exception 'C1 FAIL: host-created meetup produced % notifications (host-self)', n; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.rpc_meetup_rsvp(mid, 'request', null, null);
  reset role;

  select count(*) into n from public.notifications
   where to_user_id = host_u and kind_key = 'meetup.request_received' and context->>'entity_id' = mid::text;
  if n <> 1 then raise exception 'C1 FAIL: host got % request_received (expected exactly 1)', n; end if;
  select count(*) into n from public.notifications
   where to_user_id = u1 and kind_key like 'meetup.%' and context->>'entity_id' = mid::text;
  if n <> 0 then raise exception 'C1 FAIL: the requester (actor) was notified % times', n; end if;
  raise notice 'C1 PASS';
end $$;
rollback;

-- C2 going: host gets exactly ONE notification per going event, of kind
--    meetup.player_joined (existing activity chain, fresh INSERT) OR meetup.rsvp_received
--    (UPDATE re-RSVP), never both; the actor is never notified.
begin;
do $$
declare
  host_u uuid; u1 uuid; u2 uuid; sp uuid; var uuid; req int; mid uuid; n int;
begin
  select p.user_id into host_u from public.profiles p
   where p.persona_type='organiser' and p.is_active and public.can_create_meetup(p.id) limit 1;
  select x.user_id into u1 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  select x.user_id into u2 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,u1) order by x.created_at limit 1;
  if host_u is null or u1 is null or u2 is null then raise exception 'FIXTURE: need organiser + 2 players'; end if;
  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe notif going', null, null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req,6), 'public', 'open', false, null, null, null, null);
  reset role;

  -- fresh INSERT going (u1)
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.rpc_meetup_rsvp(mid, 'going', null, null);
  reset role;
  select count(*) into n from public.notifications
   where to_user_id = host_u and kind_key in ('meetup.player_joined','meetup.rsvp_received')
     and context->>'entity_id' = mid::text and context->>'actor_user_id' = u1::text;
  if n <> 1 then raise exception 'C2 FAIL: INSERT going gave host % notifications (expected exactly 1)', n; end if;

  -- re-RSVP path: u2 interested then going (UPDATE)
  perform set_config('request.jwt.claims', json_build_object('sub', u2, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.rpc_meetup_rsvp(mid, 'interested', null, null);
  reset role;
  select count(*) into n from public.notifications
   where to_user_id = host_u and context->>'actor_user_id' = u2::text and context->>'entity_id' = mid::text;
  if n <> 0 then raise exception 'C2 FAIL: host notified (%) about an interested row', n; end if;
  set local role authenticated;
  perform public.rpc_meetup_rsvp(mid, 'going', null, null);
  reset role;
  select count(*) into n from public.notifications
   where to_user_id = host_u and kind_key = 'meetup.rsvp_received'
     and context->>'entity_id' = mid::text and context->>'actor_user_id' = u2::text;
  if n <> 1 then raise exception 'C2 FAIL: UPDATE going gave host % rsvp_received (expected 1)', n; end if;

  select count(*) into n from public.notifications
   where to_user_id in (u1, u2) and kind_key like 'meetup.%' and context->>'entity_id' = mid::text;
  if n <> 0 then raise exception 'C2 FAIL: an actor was notified of their own action (%)', n; end if;
  raise notice 'C2 PASS';
end $$;
rollback;

-- C3 approve / decline / self-cancel of a pending request.
begin;
do $$
declare
  host_u uuid; u1 uuid; u2 uuid; u3 uuid; sp uuid; var uuid; req int; mid uuid; n int;
begin
  select p.user_id into host_u from public.profiles p
   where p.persona_type='organiser' and p.is_active and public.can_create_meetup(p.id) limit 1;
  select x.user_id into u1 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  select x.user_id into u2 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,u1) order by x.created_at limit 1;
  select x.user_id into u3 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,u1,u2) order by x.created_at limit 1;
  if host_u is null or u1 is null or u2 is null or u3 is null then raise exception 'FIXTURE: need organiser + 3 players'; end if;
  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe notif decide', null, null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req,8), 'public', 'request', false, null, null, null, null);
  reset role;

  -- u1, u2, u3 request
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null); reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u2, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null); reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u3, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null);
  -- u3 withdraws their own pending request (self-cancel): NOT a decline
  perform public.rpc_meetup_rsvp(mid,'cancel',null,null); reset role;
  select count(*) into n from public.notifications where to_user_id = u3 and kind_key = 'meetup.request_declined';
  if n <> 0 then raise exception 'C3 FAIL: self-cancel produced % request_declined', n; end if;

  -- host approves u1, declines u2
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.rpc_meetup_decide_request(mid, u1, 'approve');
  perform public.rpc_meetup_decide_request(mid, u2, 'decline');
  reset role;

  select count(*) into n from public.notifications
   where to_user_id = u1 and kind_key = 'meetup.request_approved' and context->>'entity_id' = mid::text;
  if n <> 1 then raise exception 'C3 FAIL: approved attendee got % request_approved (expected 1)', n; end if;
  select count(*) into n from public.notifications
   where to_user_id = u2 and kind_key = 'meetup.request_declined' and context->>'entity_id' = mid::text;
  if n <> 1 then raise exception 'C3 FAIL: declined attendee got % request_declined (expected 1)', n; end if;
  select count(*) into n from public.notifications
   where to_user_id = host_u and kind_key in ('meetup.request_approved','meetup.request_declined');
  if n <> 0 then raise exception 'C3 FAIL: the host (actor) was told about their own decision (%)', n; end if;
  raise notice 'C3 PASS';
end $$;
rollback;

-- C4 cancel: going / interested / pending attendees are told once each; the host
--    (actor) is not; cancelled-already attendees are not.
begin;
do $$
declare
  host_u uuid; ug uuid; ui uuid; up uuid; uc uuid; sp uuid; var uuid; req int; mid uuid; n int;
begin
  select p.user_id into host_u from public.profiles p
   where p.persona_type='organiser' and p.is_active and public.can_create_meetup(p.id) limit 1;
  select x.user_id into ug from public.profiles x where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  select x.user_id into ui from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,ug) order by x.created_at limit 1;
  select x.user_id into up from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,ug,ui) order by x.created_at limit 1;
  select x.user_id into uc from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,ug,ui,up) order by x.created_at limit 1;
  if host_u is null or ug is null or ui is null or up is null or uc is null then raise exception 'FIXTURE: need organiser + 4 players'; end if;
  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe notif cancel', null, null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req,8), 'public', 'request', false, null, null, null, null);
  reset role;

  -- ug going (host approves), ui interested (approve to a full meetup is awkward: use direct fixture rows as postgres)
  insert into public.meetup_rsvps(meetup_id, user_id, profile_id, status)
  select mid, x.u, (select id from public.profiles where user_id = x.u and is_active limit 1), x.s
  from (values (ug,'going'),(ui,'interested'),(up,'pending'),(uc,'cancelled')) as x(u,s);
  -- the fixture inserts above run as the connection role (auth.uid() null) and are INSERTs:
  -- clear whatever the insert-time triggers produced so the assertions count only the cancel.
  -- (rolled back with the transaction; this is the probe's own fixture, not an existing row)
  create temp table _before on commit drop as
    select id from public.notifications where context->>'entity_id' = mid::text;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.rpc_meetup_cancel(mid);
  reset role;

  select count(*) into n from public.notifications x
   where x.kind_key = 'meetup.cancelled' and x.context->>'entity_id' = mid::text
     and x.to_user_id in (ug, ui, up) and x.id not in (select id from _before);
  if n <> 3 then raise exception 'C4 FAIL: % cancel notices to going/interested/pending (expected 3)', n; end if;
  select count(*) into n from public.notifications x
   where x.kind_key = 'meetup.cancelled' and x.context->>'entity_id' = mid::text and x.to_user_id = host_u;
  if n <> 0 then raise exception 'C4 FAIL: the host (actor) was notified of their own cancel'; end if;
  select count(*) into n from public.notifications x
   where x.kind_key = 'meetup.cancelled' and x.context->>'entity_id' = mid::text and x.to_user_id = uc;
  if n <> 0 then raise exception 'C4 FAIL: a cancelled attendee was notified'; end if;
  -- idempotent: cancelling again changes no row and sends nothing more
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_cancel(mid); reset role;
  select count(*) into n from public.notifications x
   where x.kind_key = 'meetup.cancelled' and x.context->>'entity_id' = mid::text;
  if n <> 3 then raise exception 'C4 FAIL: re-cancel changed the count to %', n; end if;
  raise notice 'C4 PASS';
end $$;
rollback;

-- C5 settings: with push ON a request enqueues exactly one net.http_request_queue row;
--    with push_enabled=false, and again with the kind muted, it enqueues none.
--    (net.http_post inserts into net.http_request_queue inside the transaction.)
begin;
do $$
declare
  host_u uuid; u1 uuid; u2 uuid; u3 uuid; sp uuid; var uuid; req int; mid uuid; q0 bigint; q1 bigint;
begin
  select p.user_id into host_u from public.profiles p
   where p.persona_type='organiser' and p.is_active and public.can_create_meetup(p.id) limit 1;
  select x.user_id into u1 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id <> host_u order by x.created_at limit 1;
  select x.user_id into u2 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,u1) order by x.created_at limit 1;
  select x.user_id into u3 from public.profiles x where x.is_active and x.persona_type='player' and x.user_id not in (host_u,u1,u2) order by x.created_at limit 1;
  if host_u is null or u1 is null or u2 is null or u3 is null then raise exception 'FIXTURE: need organiser + 3 players'; end if;
  select s.id, v.id, v.required_players into sp, var, req
    from public.sports s join public.sport_variants v on v.sport_id=s.id
   where s.is_active and v.is_active order by v.required_players limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  set local role authenticated;
  mid := public.rpc_create_meetup('organiser', sp, var, 'Probe notif push', null, null, 'Probe loc', null, null,
          now()+interval '7 days', now()+interval '8 days', greatest(req,8), 'public', 'request', false, null, null, null, null);
  reset role;

  -- push ON (any existing settings row for the host is left as found; the probe
  -- INSERTs one only if absent, and the transaction rolls back)
  insert into public.notification_settings(user_id) values (host_u) on conflict (user_id) do nothing;
  select count(*) into q0 from net.http_request_queue;
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null); reset role;
  select count(*) into q1 from net.http_request_queue;
  if q1 - q0 <> 1 then raise exception 'C5 FAIL: push ON enqueued % requests (expected 1; vault secrets present?)', q1 - q0; end if;

  -- push_enabled = false -> in-app row yes, push no
  perform set_config('request.jwt.claims', json_build_object('sub', host_u, 'role','authenticated')::text, true);
  update public.notification_settings set push_enabled = false, muted_kinds = '{}' where user_id = host_u;
  select count(*) into q0 from net.http_request_queue;
  perform set_config('request.jwt.claims', json_build_object('sub', u2, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null); reset role;
  select count(*) into q1 from net.http_request_queue;
  if q1 - q0 <> 0 then raise exception 'C5 FAIL: push_enabled=false still enqueued % pushes', q1 - q0; end if;
  if not exists (select 1 from public.notifications where to_user_id = host_u and kind_key='meetup.request_received'
                   and context->>'actor_user_id' = u2::text) then
    raise exception 'C5 FAIL: in-app row missing when push is off'; end if;

  -- kind muted -> no push
  update public.notification_settings set push_enabled = true, muted_kinds = array['meetup.request_received'] where user_id = host_u;
  select count(*) into q0 from net.http_request_queue;
  perform set_config('request.jwt.claims', json_build_object('sub', u3, 'role','authenticated')::text, true);
  set local role authenticated; perform public.rpc_meetup_rsvp(mid,'request',null,null); reset role;
  select count(*) into q1 from net.http_request_queue;
  if q1 - q0 <> 0 then raise exception 'C5 FAIL: muted kind still enqueued % pushes', q1 - q0; end if;
  raise notice 'C5 PASS';
end $$;
rollback;

-- C6 [WRITE-IN-TRANSACTION-ROLLBACK] a client cannot call the trigger functions or the
--    delivery primitive directly.
begin;
do $$
declare uid uuid;
begin
  select user_id into uid from public.profiles where is_active limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role','authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.process_notification_event(uid, 'meetup.cancelled', 'meetup', gen_random_uuid(), uid, 'x', 'y');
    raise exception 'C6 FAIL: authenticated executed process_notification_event';
  exception when insufficient_privilege then raise notice 'C6 PASS (process_notification_event denied)';
  end;
  reset role;
end $$;
rollback;
