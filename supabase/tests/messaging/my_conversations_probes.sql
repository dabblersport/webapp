-- KAN-547 (Messaging launch B1) probe pack for msg_my_conversations and the msg_notify stamp.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261013160800_kan547_msg_my_conversations.sql is applied.
-- Every block is WRITE-IN-TRANSACTION-ROLLBACK (or READ-ONLY), begins with BEGIN and ends with ROLLBACK.
-- Every fixture row is created inside the block and rolled back with it. Blocks print booleans and counts only:
-- no title, no message content.
--
-- Setup is idempotent: allowlist rows use ON CONFLICT DO NOTHING, so existing pilot test identities work.
-- Variables (supplied by the runner, no secrets): the caller :user_a with profile :profile_a, a user :user_e with
-- no roster rows, and four test games with no msg_conversations row and on which :user_a has no roster row:
--   :game_live   starts in the future, ends in the future, not cancelled
--   :game_ended  end_at in the past
--   :game_left   any state
--   :game_kicked any state
-- Fixture conversation ids end in d547 + 0..3: 00000000-0000-4000-8000-00000000d5470 (live) ... see each block.
-- e.g. psql -v user_a=... -v profile_a=... -v user_e=... -v game_live=... -f my_conversations_probes.sql

-- M1 [READ-ONLY] AUTHORED, NOT RUN. The user_id index exists, the new index exists, the column is not null.
BEGIN;
select
  exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'msg_conversation_members'
           and indexname = 'msg_conversation_members_user_idx') as pass_user_id_index_exists,
  exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'msg_conversations'
           and indexname = 'msg_conversations_last_activity_idx') as pass_last_activity_index_exists,
  (select is_nullable = 'NO' and column_default is not null from information_schema.columns
    where table_schema = 'public' and table_name = 'msg_conversations' and column_name = 'last_activity_at') as pass_column_not_null_default;
ROLLBACK;

-- M2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Send-state member, read_only member of an ended game,
-- leaver; a kicked member is absent; the result has exactly the listed columns and nothing else.
BEGIN;
insert into public.msg_conversations (id, game_id, last_activity_at) values
  ('00000000-0000-4000-8000-0000000d5470', :'game_live',   now()),
  ('00000000-0000-4000-8000-0000000d5471', :'game_ended',  now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000d5472', :'game_left',   now() - interval '2 hours'),
  ('00000000-0000-4000-8000-0000000d5473', :'game_kicked', now() - interval '3 hours');
update public.games set end_at = now() - interval '1 minute', start_at = now() - interval '3 hours' where id = :'game_ended';
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_live',   :'profile_a', :'user_a', 'player', 'active'),
  (:'game_ended',  :'profile_a', :'user_a', 'player', 'active'),
  (:'game_left',   :'profile_a', :'user_a', 'player', 'left'),
  (:'game_kicked', :'profile_a', :'user_a', 'player', 'kicked');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
create temp table kan547_m2 as select * from public.msg_my_conversations();
reset role;
select
  (select state from kan547_m2 where game_id = :'game_live') = 'send' as pass_send_state,
  (select state from kan547_m2 where game_id = :'game_ended') = 'read_only' as pass_ended_read_only,
  (select state from kan547_m2 where game_id = :'game_left') = 'left' as pass_leaver_left,
  not exists (select 1 from kan547_m2 where game_id = :'game_kicked') as pass_kicked_absent,
  (select count(*) from kan547_m2) = 3 as pass_three_rows,
  (select array_agg(attname order by attnum) from pg_attribute
    where attrelid = 'kan547_m2'::regclass and attnum > 0 and not attisdropped)
    = array['conversation_id','game_id','game_title','sport','start_at','end_at','state','last_activity_at'] as pass_exact_columns;
ROLLBACK;

-- M3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A cancelled game is read_only for an active member.
BEGIN;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-0000000d5470', :'game_live');
update public.games set is_cancelled = true, cancelled_at = now() where id = :'game_live';
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_live', :'profile_a', :'user_a', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations()) = 'read_only' as pass_cancelled_read_only;
ROLLBACK;

-- M4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A non-member gets an empty set; no token gets an empty set.
BEGIN;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-0000000d5470', :'game_live');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_live', :'profile_a', :'user_a', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select (select count(*) from public.msg_my_conversations()) = 0 as pass_non_member_empty;
select set_config('request.jwt.claims', '', true);
select (select count(*) from public.msg_my_conversations()) = 0 as pass_no_token_empty;
ROLLBACK;

-- M5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. anon and PUBLIC are refused (42501).
BEGIN;
set local role anon;
do $$
begin
  perform public.msg_my_conversations();
  raise exception 'FAIL pass_anon_refused: the call was accepted';
exception when insufficient_privilege then
  raise notice 'pass_anon_refused = true (42501)';
end;
$$;
ROLLBACK;

-- M6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Ordering: newest activity first; a tie falls back to the
-- game's start time, newest first.
BEGIN;
insert into public.msg_conversations (id, game_id, last_activity_at) values
  ('00000000-0000-4000-8000-0000000d5470', :'game_live',  now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000d5471', :'game_ended', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000d5472', :'game_left',  now());
update public.games set start_at = now() + interval '2 days', end_at = now() + interval '2 days 2 hours' where id = :'game_live';
update public.games set start_at = now() - interval '2 days', end_at = now() - interval '2 days' + interval '2 hours' where id = :'game_ended';
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_live',  :'profile_a', :'user_a', 'player', 'active'),
  (:'game_ended', :'profile_a', :'user_a', 'player', 'active'),
  (:'game_left',  :'profile_a', :'user_a', 'player', 'left');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select array_agg(game_id order by ord) from (select game_id, row_number() over () as ord from public.msg_my_conversations()) t)
       = array[:'game_left'::uuid, :'game_live'::uuid, :'game_ended'::uuid] as pass_newest_first_tie_by_start;
ROLLBACK;

-- M7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. The limit is clamped to 1..100 and a null limit means 50.
BEGIN;
insert into public.msg_conversations (id, game_id) values
  ('00000000-0000-4000-8000-0000000d5470', :'game_live'),
  ('00000000-0000-4000-8000-0000000d5471', :'game_ended'),
  ('00000000-0000-4000-8000-0000000d5472', :'game_left');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_live',  :'profile_a', :'user_a', 'player', 'active'),
  (:'game_ended', :'profile_a', :'user_a', 'player', 'active'),
  (:'game_left',  :'profile_a', :'user_a', 'player', 'left');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select
  (select count(*) from public.msg_my_conversations(1)) = 1 as pass_limit_one,
  (select count(*) from public.msg_my_conversations(0)) = 1 as pass_limit_zero_clamped_to_one,
  (select count(*) from public.msg_my_conversations(-5)) = 1 as pass_limit_negative_clamped_to_one,
  (select count(*) from public.msg_my_conversations(100000)) between 1 and 100 as pass_limit_capped_at_100,
  (select count(*) from public.msg_my_conversations(null)) = 3 as pass_null_limit_default;
ROLLBACK;

-- M8 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Stamping: a member's msg_notify moves the conversation up
-- the list; a non-sender's call does not stamp.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_e')
  on conflict (user_id) do nothing;
insert into public.msg_conversations (id, game_id, last_activity_at) values
  ('00000000-0000-4000-8000-0000000d5470', :'game_live',  now() - interval '5 hours'),
  ('00000000-0000-4000-8000-0000000d5471', :'game_ended', now() - interval '1 hour');
update public.games set end_at = now() - interval '1 minute', start_at = now() - interval '3 hours' where id = :'game_ended';
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_live',  :'profile_a', :'user_a', 'player', 'active'),
  (:'game_ended', :'profile_a', :'user_a', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select game_id from public.msg_my_conversations() limit 1) = :'game_ended' as pass_before_stamp_ended_first;
select public.msg_notify('00000000-0000-4000-8000-0000000d5470', 1);
select (select game_id from public.msg_my_conversations() limit 1) = :'game_live' as pass_stamp_moved_it_up;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select public.msg_notify('00000000-0000-4000-8000-0000000d5471', 1);
reset role;
select (select last_activity_at from public.msg_conversations where id = '00000000-0000-4000-8000-0000000d5471') < now() - interval '30 minutes' as pass_non_member_does_not_stamp;
ROLLBACK;

-- M9 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A failed stamp does not raise, and the wake-ups still go out.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a')
  on conflict (user_id) do nothing;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-0000000d5470', :'game_live');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_live', :'profile_a', :'user_a', 'player', 'active');
-- a test-only trigger that makes the stamp fail; it lives and dies with this transaction
create function public.kan547_probe_stamp_fails() returns trigger language plpgsql as $$ begin raise exception 'probe: stamp refused'; end; $$;
create trigger kan547_probe_stamp_fails before update on public.msg_conversations for each row execute function public.kan547_probe_stamp_fails();
select count(*) as wakes_before from realtime.messages where topic = 'user:' || :'user_a' \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_notify('00000000-0000-4000-8000-0000000d5470', 1);
  raise notice 'pass_failed_stamp_does_not_raise = true';
exception when others then
  raise exception 'FAIL pass_failed_stamp_does_not_raise: msg_notify raised (sqlstate %)', sqlstate;
end;
$$;
reset role;
select (select count(*) from realtime.messages where topic = 'user:' || :'user_a') - :wakes_before = 1 as pass_wake_still_sent_after_failed_stamp;
ROLLBACK;

-- M10 [READ-ONLY] AUTHORED, NOT RUN. Grants and attributes.
BEGIN;
select
  has_function_privilege('authenticated', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_authenticated_can_execute,
  not has_function_privilege('anon', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_anon_cannot_execute,
  not has_function_privilege('public', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_public_cannot_execute,
  (select p.prosecdef and p.proconfig @> array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure) as pass_definer_pinned_search_path,
  (select pg_get_userbyid(p.proowner) from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure) = 'postgres' as pass_owner_postgres,
  has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') as pass_msg_notify_still_authenticated;
ROLLBACK;
