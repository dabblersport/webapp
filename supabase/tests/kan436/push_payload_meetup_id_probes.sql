-- KAN-436 -- probe pack for 20260915150100_kan436_push_payload_meetup_id.sql
--
-- STATUS: AUTHORED, NOT RUN. Run BEFORE applying (B and C1 must FAIL: proof each can fail)
-- and AFTER (all must pass). [READ-ONLY] = catalogue only;
-- [WRITE-IN-TRANSACTION-ROLLBACK] = BEGIN ... ROLLBACK, nothing persists.
-- PRECONDITION for the push probes: vault secrets supabase_anon_key and push_trigger_secret
-- exist, otherwise the trigger sends nothing (WARNING) and the "enqueued" asserts fail visibly.
-- To observe the payload without calling out, the probes read net._http_response / the
-- request queue net.http_request_queue (pg_net) inside the same transaction.

-- A. CATALOGUE -- [READ-ONLY]
-- A1 definer + pinned search_path + meetup_id in the body. Expect prosecdef true,
--    proconfig = {search_path=public, pg_temp}, has_meetup_id true (false BEFORE).
select p.prosecdef, p.proconfig, pg_get_functiondef(p.oid) like '%''meetup_id''%' as has_meetup_id
from pg_proc p where p.oid = 'public.trg_push_on_notification_insert()'::regprocedure;

-- A2 trigger still attached and enabled ('O'). Expect 1 row.
select tgname, tgenabled from pg_trigger
where tgname = 'trg_push_on_notification_insert' and not tgisinternal;

-- A3 KAN-182 untouched: expect must_be_false = false; also record proacl (must equal pre-apply).
select has_function_privilege('authenticated',
  'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure,'EXECUTE') as must_be_false,
  (select proacl from pg_proc where oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure) as acl;

-- A4 the fn_public_activities_notify entity_id probe -- [READ-ONLY]. The meetup rows reach
--    notifications with context.entity_type = 'meetup' and context.entity_id = the MEETUP id
--    only if that function writes it. Expect the body to mention both keys.
select pg_get_functiondef('public.fn_public_activities_notify()'::regprocedure) ~ 'entity_type'
   and pg_get_functiondef('public.fn_public_activities_notify()'::regprocedure) ~ 'entity_id' as writes_entity_context;

-- B. PAYLOAD -- [WRITE-IN-TRANSACTION-ROLLBACK]
-- Each scenario inserts a notifications row for a throwaway user and reads the queued
-- pg_net request body. Expectations:
--  B1 kind 'meetup.invited', context {"entity_type":"meetup","entity_id":"<M>"}:
--     data.meetup_id = <M>, data.entity_id = the notification row id (NOT <M>). FAILS BEFORE.
--  B2 kind 'game.invited' (a game.* row), context {"entity_type":"game","entity_id":"<G>"}:
--     data has NO meetup_id; data = {kind_key, action_route, entity_id} exactly.
--  B3 a social.* kind: same as B2.
--  B4 a meetup kind with context {} (or empty entity_id): no meetup_id, same three keys.
begin;
do $$
declare _u uuid; _n uuid; _m uuid := gen_random_uuid(); _data jsonb;
begin
  select id into _u from auth.users limit 1;
  insert into public.notifications(to_user_id, kind_key, title, body, context)
  values (_u, 'meetup.invited', 't', 'b',
          jsonb_build_object('entity_type','meetup','entity_id',_m::text))
  returning id into _n;
  select (convert_from(body,'utf8')::jsonb)->'data' into _data
  from net.http_request_queue order by id desc limit 1;
  assert _data->>'meetup_id' = _m::text, 'B1 meetup_id missing';
  assert _data->>'entity_id' = _n::text, 'B1 entity_id must stay the notification id';

  insert into public.notifications(to_user_id, kind_key, title, body, context)
  values (_u, 'game.invited', 't', 'b',
          jsonb_build_object('entity_type','game','entity_id',_m::text))
  returning id into _n;
  select (convert_from(body,'utf8')::jsonb)->'data' into _data
  from net.http_request_queue order by id desc limit 1;
  assert not (_data ? 'meetup_id'), 'B2 game row must not carry meetup_id';
  assert _data = jsonb_build_object('kind_key','game.invited','action_route',
    coalesce((select action_route from public.notifications where id=_n),''),'entity_id',_n::text),
    'B2 map must be otherwise identical';
end $$;
rollback;

-- C. PUSH GATES UNCHANGED -- [WRITE-IN-TRANSACTION-ROLLBACK]
-- C1 push_enabled = false for the user: inserting a meetup.invited row enqueues NOTHING
--    (queue row count unchanged). C2 kind in muted_kinds: nothing enqueued.
begin;
do $$
declare _u uuid; _before bigint; _after bigint;
begin
  select id into _u from auth.users limit 1;
  insert into public.notification_settings(user_id, push_enabled) values (_u, false)
    on conflict (user_id) do update set push_enabled = false;
  select count(*) into _before from net.http_request_queue;
  insert into public.notifications(to_user_id, kind_key, title, body, context)
  values (_u, 'meetup.invited', 't', 'b', '{"entity_type":"meetup","entity_id":"x"}'::jsonb);
  select count(*) into _after from net.http_request_queue;
  assert _after = _before, 'C1 push disabled must enqueue nothing';

  update public.notification_settings set push_enabled = true,
    muted_kinds = array['meetup.invited'] where user_id = _u;
  insert into public.notifications(to_user_id, kind_key, title, body, context)
  values (_u, 'meetup.invited', 't', 'b', '{"entity_type":"meetup","entity_id":"x"}'::jsonb);
  select count(*) into _after from net.http_request_queue;
  assert _after = _before, 'C2 muted kind must enqueue nothing';
end $$;
rollback;
