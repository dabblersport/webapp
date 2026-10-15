-- KAN-541 (Realtime R1) probe pack for public.msg_notify.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261013160600_kan541_msg_notify.sql is applied and
-- supabase/tests/messaging/notify_realtime_send_check.sql has passed. Every block is
-- WRITE-IN-TRANSACTION-ROLLBACK, begins with BEGIN and ends with ROLLBACK. No block prints a
-- payload: the checks print booleans and counts only.
--
-- Variables (supplied by the runner, no secrets): :game_id (future, not cancelled, a msg_conversations
-- row will be created in-block), :user_a (active player on :game_id: the sender), :user_b, :user_c,
-- :user_d (test users with profiles :profile_b, :profile_c, :profile_d), :user_e (not on the roster),
-- all allowlisted in-block. conversation id 00000000-0000-4000-8000-00000000d541.
-- e.g. psql -v game_id=... -v user_a=... -v user_b=... -v profile_b=... -f notify_probes.sql
--
-- realtime.send stores each wake-up as a row in realtime.messages (topic, event, private, payload);
-- the blocks read those rows back as the migration role after resetting the role.

-- N1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A member's call queues one wake per eligible recipient.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d541', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
reset role;
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and event = 'msg' and private) = 1 as pass_member_b_woken,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a' and event = 'msg' and private) = 1 as pass_sender_own_topic_included,
  (select bool_and(private) from realtime.messages where topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_all_private,
  (select bool_and(array(select k from jsonb_object_keys(payload) k order by k) = array['conversation_id','seq','type'])
     from realtime.messages where topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_exactly_three_keys,
  (select bool_and((payload ->> 'type') = 'msg' and (payload ->> 'seq')::bigint = 7
                   and (payload ->> 'conversation_id') = '00000000-0000-4000-8000-00000000d541')
     from realtime.messages where topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_payload_values;
ROLLBACK;

-- N2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A non-member queues nothing.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_e');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d541', :'game_id');
select count(*) as before_count from realtime.messages \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
reset role;
select (select count(*) from realtime.messages) - :before_count = 0 as pass_non_member_queues_none;
ROLLBACK;

-- N3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A caller who cannot send (not allowlisted, no token) queues nothing, and the function does not raise.
BEGIN;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d541', :'game_id');
select count(*) as before_count from realtime.messages \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
select set_config('request.jwt.claims', '', true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
select public.msg_notify(null, 7);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 0);
reset role;
select (select count(*) from realtime.messages) - :before_count = 0 as pass_no_gate_queues_none;
ROLLBACK;

-- N4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A recipient who blocked the sender is excluded; the other members are still woken.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d541', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_b', :'user_a');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
reset role;
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b') = 0 as pass_blocker_excluded,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_c') = 1 as pass_unblocking_member_woken;
ROLLBACK;

-- N5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A leaver and a removed member are excluded.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d541', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_c', :'user_c', 'player', 'left'),
  (:'game_id', :'profile_d', :'user_d', 'player', 'kicked');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-00000000d541', 7);
reset role;
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_c') = 0 as pass_leaver_excluded,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_d') = 0 as pass_removed_excluded,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a') = 1 as pass_sender_still_woken;
ROLLBACK;

-- N6 [READ-ONLY] AUTHORED, NOT RUN. Grants and attributes.
BEGIN;
select
  has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') as pass_authenticated_can_execute,
  not has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') as pass_anon_cannot_execute,
  (select p.prosecdef and pg_get_userbyid(p.proowner) = 'postgres'
     and p.proconfig @> array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'public.msg_notify(uuid,bigint,text)'::regprocedure) as pass_definer_postgres_search_path,
  not exists (select 1 from pg_policies where schemaname = 'realtime' and tablename = 'messages' and cmd in ('INSERT', 'ALL')) as pass_no_insert_policy;
ROLLBACK;
