-- KAN-579 probe pack for public.msg_typing.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261020140000_kan579_msg_typing.sql is applied and
-- supabase/tests/messaging/notify_realtime_send_check.sql has passed. Every block is
-- WRITE-IN-TRANSACTION-ROLLBACK, begins with BEGIN and ends with ROLLBACK. No block prints a
-- payload: the checks print booleans and counts only.
--
-- Variables (supplied by the runner, no secrets): :game_id (future, not cancelled; a msg_conversations
-- row is created in-block), :user_a (active player on :game_id: the typer), :user_b, :user_c (active
-- players with profiles :profile_b, :profile_c), :user_e (not on the roster), all allowlisted in-block.
-- Conversation id 00000000-0000-4000-8000-00000000d579.
--
-- realtime.send stores each signal as a row in realtime.messages (topic, event, private, payload); the
-- blocks read those rows back as the migration role after resetting the role.

-- T1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A member's call queues one private typing event per OTHER
-- eligible member (never the typer), with exactly four payload keys.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d579', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
reset role;
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and event = 'typing' and private) = 1 as pass_b_signalled,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_c' and event = 'typing' and private) = 1 as pass_c_signalled,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a' and event = 'typing') = 0 as pass_typer_not_signalled,
  (select bool_and(array(select k from jsonb_object_keys(payload) k order by k) = array['conversation_id','on','type','user_id'])
     from realtime.messages where topic in ('user:' || :'user_b', 'user:' || :'user_c')) as pass_exactly_four_keys,
  (select bool_and((payload ->> 'type') = 'typing' and (payload ->> 'on')::boolean and (payload ->> 'user_id') = :'user_a'
                   and (payload ->> 'conversation_id') = '00000000-0000-4000-8000-00000000d579')
     from realtime.messages where topic in ('user:' || :'user_b', 'user:' || :'user_c')) as pass_payload_values;
ROLLBACK;

-- T2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A stop (typing = false) is delivered with on = false.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d579', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', false);
reset role;
select (select bool_and(not (payload ->> 'on')::boolean) from realtime.messages
         where topic = 'user:' || :'user_b' and event = 'typing') as pass_stop_delivered;
ROLLBACK;

-- T3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. TC5: a non-member, and a member who is no longer active
-- (removed / left), queue nothing.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_e');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d579', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_a', 'player', 'removed');
select count(*) as before_count from realtime.messages \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
reset role;
select (select count(*) from realtime.messages) - :before_count = 0 as pass_non_member_and_removed_queue_none;
ROLLBACK;

-- T4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A member who blocked the typer, and one who muted the
-- conversation, get no signal; the other member still does.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d579', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_b', :'user_a');
insert into public.msg_conversation_members (conversation_id, user_id, muted_at)
  values ('00000000-0000-4000-8000-00000000d579', :'user_c', now());
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
reset role;
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and event = 'typing') = 0 as pass_blocker_not_signalled,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_c' and event = 'typing') = 0 as pass_muted_not_signalled;
ROLLBACK;

-- T5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Nothing durable: no message, no notification, no
-- conversation stamp changes, and no event other than 'typing' is queued.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d579', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
select count(*) as notif_before from public.notifications \gset
select last_activity_at as stamp_before from public.msg_conversations where id = '00000000-0000-4000-8000-00000000d579' \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
reset role;
select
  (select count(*) from public.notifications) - :notif_before = 0 as pass_no_notification_or_push,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and event <> 'typing') = 0 as pass_only_typing_event;
ROLLBACK;

-- T6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Bad input queues nothing and never raises: no token,
-- null conversation, null flag, a conversation that does not exist.
BEGIN;
select count(*) as before_count from realtime.messages \gset
set local role authenticated;
select set_config('request.jwt.claims', '', true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', true);
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_typing(null, true);
select public.msg_typing('00000000-0000-4000-8000-00000000d579', null);
select public.msg_typing('00000000-0000-4000-8000-0000000fffff', true);
reset role;
select (select count(*) from realtime.messages) - :before_count = 0 as pass_bad_input_queues_none;
ROLLBACK;

-- T7 [READ-ONLY] AUTHORED, NOT RUN. Privileges: authenticated may execute, anon and PUBLIC may not; definer;
-- search_path is pinned.
select
  has_function_privilege('authenticated', 'public.msg_typing(uuid, boolean, text)', 'EXECUTE') as pass_authenticated_executes,
  not has_function_privilege('anon', 'public.msg_typing(uuid, boolean, text)', 'EXECUTE') as pass_anon_denied,
  (select p.prosecdef from pg_proc p where p.oid = 'public.msg_typing(uuid, boolean, text)'::regprocedure) as pass_security_definer,
  (select p.proconfig @> array['search_path=public, pg_temp'] from pg_proc p where p.oid = 'public.msg_typing(uuid, boolean, text)'::regprocedure) as pass_search_path_pinned;
