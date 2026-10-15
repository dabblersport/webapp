-- KAN-560 (Messaging DMs B2) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261013160900_kan560_msg_dm_conversations.sql is applied. Every block
-- is WRITE-IN-TRANSACTION-ROLLBACK (or READ-ONLY), begins with BEGIN and ends with ROLLBACK. Every fixture is created
-- or identified inside the block and rolled back with it. Blocks print booleans and counts only: no message content.
--
-- Variables (supplied by the runner, no secrets; all are existing TEST users):
--   :user_a, :user_b, :user_e, :user_f  adults: every profile of theirs has age >= 16
--   :user_c                             under 16: a profile with age < 16
--   :user_d                             no profile at all (no age on record)
--   :game_id, :profile_a                a future, not cancelled game with a msg_conversations row created in-block,
--                                       :user_a an active player on it; :profile_a is :user_a's profile
-- e.g. psql -v user_a=... -v user_b=... -v user_c=... -v user_d=... -v user_e=... -v user_f=... -f dm_probes.sql
-- Game-kind probes of earlier tickets (probes.sql, notify_probes.sql, my_conversations_probes.sql) must still pass.

-- D1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Start between two unrelated users: one conversation of kind dm,
-- no game, one pair row recording the starter, two member rows.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
reset role;
select
  (select kind = 'dm' and game_id is null from public.msg_conversations where id = :'conv') as pass_dm_kind_no_game,
  (select count(*) from public.msg_dm_pairs where conversation_id = :'conv'
     and user_low = least(:'user_a'::uuid, :'user_b'::uuid) and user_high = greatest(:'user_a'::uuid, :'user_b'::uuid)
     and started_by = :'user_a') = 1 as pass_pair_row_with_starter,
  (select array_agg(user_id order by user_id) from public.msg_conversation_members where conversation_id = :'conv')
     = (select array_agg(u order by u) from unnest(array[:'user_a'::uuid, :'user_b'::uuid]) u) as pass_both_members,
  (select bool_and(roster_id is null and muted_at is null) from public.msg_conversation_members where conversation_id = :'conv') as pass_no_roster_not_muted;
ROLLBACK;

-- D2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A second start returns the same id, from either side.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as first \gset
select public.msg_start_dm(:'user_b') = :'first'::uuid as pass_second_start_same_id;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_a') = :'first'::uuid as pass_other_side_same_id;
reset role;
select (select count(*) from public.msg_dm_pairs where conversation_id = :'first') = 1 as pass_still_one_pair;
ROLLBACK;

-- D3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Under 16, no age on record, and self are refused; nothing is created.
BEGIN;
select set_config('kan560.user_a', :'user_a', true), set_config('kan560.user_b', :'user_b', true), set_config('kan560.user_c', :'user_c', true), set_config('kan560.user_d', :'user_d', true), set_config('kan560.user_e', :'user_e', true), set_config('kan560.user_f', :'user_f', true); -- psql does not substitute variables inside dollar-quoted bodies
select count(*) as before_count from public.msg_dm_pairs \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_c')::uuid);
  raise exception 'FAIL pass_target_under_16_refused: the call was accepted';
exception when others then
  if sqlerrm = 'age_restricted' then
    raise notice 'pass_target_under_16_refused = true';
  else
    raise exception 'FAIL pass_target_under_16_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_d')::uuid);
  raise exception 'FAIL pass_target_without_age_refused: the call was accepted';
exception when others then
  if sqlerrm = 'age_restricted' then
    raise notice 'pass_target_without_age_refused = true';
  else
    raise exception 'FAIL pass_target_without_age_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_a')::uuid);
  raise exception 'FAIL pass_self_refused: the call was accepted';
exception when others then
  if sqlerrm = 'invalid_request' then
    raise notice 'pass_self_refused = true';
  else
    raise exception 'FAIL pass_self_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
do $$
begin
  perform public.msg_start_dm(null);
  raise exception 'FAIL pass_null_target_refused: the call was accepted';
exception when others then
  if sqlerrm = 'invalid_request' then
    raise notice 'pass_null_target_refused = true';
  else
    raise exception 'FAIL pass_null_target_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_a')::uuid);
  raise exception 'FAIL pass_caller_under_16_refused: the call was accepted';
exception when others then
  if sqlerrm = 'age_restricted' then
    raise notice 'pass_caller_under_16_refused = true';
  else
    raise exception 'FAIL pass_caller_under_16_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
select set_config('request.jwt.claims', json_build_object('sub', :'user_d', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_a')::uuid);
  raise exception 'FAIL pass_caller_without_age_refused: the call was accepted';
exception when others then
  if sqlerrm = 'age_restricted' then
    raise notice 'pass_caller_without_age_refused = true';
  else
    raise exception 'FAIL pass_caller_without_age_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
reset role;
select (select count(*) from public.msg_dm_pairs) = :before_count as pass_nothing_created;
ROLLBACK;

-- D4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A block in either direction refuses the start; a banned target is refused.
BEGIN;
select set_config('kan560.user_a', :'user_a', true), set_config('kan560.user_b', :'user_b', true), set_config('kan560.user_c', :'user_c', true), set_config('kan560.user_d', :'user_d', true), set_config('kan560.user_e', :'user_e', true), set_config('kan560.user_f', :'user_f', true); -- psql does not substitute variables inside dollar-quoted bodies
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_a', :'user_b'), (:'user_e', :'user_a');
update auth.users set banned_until = now() + interval '1 day' where id = :'user_f';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_b')::uuid);
  raise exception 'FAIL pass_caller_blocked_target_refused: the call was accepted';
exception when others then
  if sqlerrm = 'blocked' then
    raise notice 'pass_caller_blocked_target_refused = true';
  else
    raise exception 'FAIL pass_caller_blocked_target_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_e')::uuid);
  raise exception 'FAIL pass_target_blocked_caller_refused: the call was accepted';
exception when others then
  if sqlerrm = 'blocked' then
    raise notice 'pass_target_blocked_caller_refused = true';
  else
    raise exception 'FAIL pass_target_blocked_caller_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_f')::uuid);
  raise exception 'FAIL pass_banned_target_refused: the call was accepted';
exception when others then
  if sqlerrm = 'not_found' then
    raise notice 'pass_banned_target_refused = true';
  else
    raise exception 'FAIL pass_banned_target_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
ROLLBACK;

-- D5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Block AFTER start: sending is refused for BOTH, history stays
-- readable (read, never deleted); unblocking restores sending.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select (select allowed_action from public.msg_authorize(:'conv', 'allowlist')) = 'send' as pass_send_before_block;
reset role;
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_b', :'user_a');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select allowed_action || ':' || reason from public.msg_authorize(:'conv', 'allowlist')) = 'read:blocked' as pass_blocked_side_read_only;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select allowed_action || ':' || reason from public.msg_authorize(:'conv', 'allowlist')) = 'read:blocked' as pass_blocker_side_read_only;
reset role;
select (select count(*) from public.msg_conversations where id = :'conv') = 1 as pass_conversation_kept;
delete from public.user_blocks where blocker_user_id = :'user_b' and blocked_user_id = :'user_a';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select allowed_action from public.msg_authorize(:'conv', 'allowlist')) = 'send' as pass_send_restored_after_unblock;
ROLLBACK;

-- D6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A deleted or banned counterpart makes the DM read-only; a
-- non-member of the DM gets not_member; msg_authorize lists the two members.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_e');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select (select member_user_ids from public.msg_authorize(:'conv', 'allowlist'))
       @> array[:'user_a'::uuid, :'user_b'::uuid] and cardinality((select member_user_ids from public.msg_authorize(:'conv', 'allowlist'))) = 2 as pass_two_members_listed;
reset role;
update auth.users set banned_until = now() + interval '1 day' where id = :'user_b';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select allowed_action || ':' || reason from public.msg_authorize(:'conv', 'allowlist')) = 'read:suspended' as pass_banned_counterpart_read_only;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select (select reason from public.msg_authorize(:'conv', 'allowlist')) = 'not_member' as pass_non_member_refused;
ROLLBACK;

-- D7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Daily cap: with 19 other DMs already started in the last 24
-- hours, the 20th new DM is allowed and the 21st DISTINCT new DM is refused; re-opening an existing pair is not
-- counted and still works. Old DMs (older than 24 hours) do not count.
BEGIN;
select set_config('kan560.user_a', :'user_a', true), set_config('kan560.user_b', :'user_b', true), set_config('kan560.user_c', :'user_c', true), set_config('kan560.user_d', :'user_d', true), set_config('kan560.user_e', :'user_e', true), set_config('kan560.user_f', :'user_f', true); -- psql does not substitute variables inside dollar-quoted bodies
-- 19 synthetic recent DMs started by :user_a (random counterpart ids; the table has no foreign key on them)
with convs as (
  insert into public.msg_conversations (kind) select 'dm' from generate_series(1, 19) returning id
), numbered as (
  select id, row_number() over (order by id) as n from convs
), pairs as (
  select id, n, gen_random_uuid() as other from numbered
)
insert into public.msg_dm_pairs (conversation_id, user_low, user_high, started_by)
select id, least(:'user_a'::uuid, other), greatest(:'user_a'::uuid, other), :'user_a' from pairs;
-- plus 5 DMs started two days ago: they do not count
with convs as (
  insert into public.msg_conversations (kind) select 'dm' from generate_series(1, 5) returning id
), pairs as (
  select id, gen_random_uuid() as other from convs
)
insert into public.msg_dm_pairs (conversation_id, user_low, user_high, started_by, created_at)
select id, least(:'user_a'::uuid, other), greatest(:'user_a'::uuid, other), :'user_a', now() - interval '2 days' from pairs;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as twentieth \gset
select :'twentieth' is not null as pass_twentieth_allowed;
do $$
begin
  perform public.msg_start_dm(current_setting('kan560.user_e')::uuid);
  raise exception 'FAIL pass_twentyfirst_new_dm_refused: the call was accepted';
exception when others then
  if sqlerrm = 'rate_limited' then
    raise notice 'pass_twentyfirst_new_dm_refused = true';
  else
    raise exception 'FAIL pass_twentyfirst_new_dm_refused: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
select public.msg_start_dm(:'user_b') = :'twentieth'::uuid as pass_existing_pair_not_counted;
reset role;
select (select count(*) from public.msg_dm_pairs where started_by = :'user_a' and created_at > now() - interval '24 hours') = 20 as pass_exactly_cap_recent;
ROLLBACK;

-- D8 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Mute and unmute by a member; refused for a non-member and
-- for no token; the chat is not hidden.
BEGIN;
select set_config('kan560.user_a', :'user_a', true), set_config('kan560.user_b', :'user_b', true), set_config('kan560.user_c', :'user_c', true), set_config('kan560.user_d', :'user_d', true), set_config('kan560.user_e', :'user_e', true), set_config('kan560.user_f', :'user_f', true); -- psql does not substitute variables inside dollar-quoted bodies
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_set_muted(:'conv', true);
reset role;
select (select muted_at is not null from public.msg_conversation_members where conversation_id = :'conv' and user_id = :'user_b') as pass_muted_by_member,
       (select muted_at is null from public.msg_conversation_members where conversation_id = :'conv' and user_id = :'user_a') as pass_other_side_untouched;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select allowed_action from public.msg_authorize(:'conv', 'allowlist')) = 'send' as pass_muted_chat_still_visible;
select public.msg_set_muted(:'conv', false);
reset role;
select set_config('kan560.conv', :'conv', true);
select (select muted_at is null from public.msg_conversation_members where conversation_id = :'conv' and user_id = :'user_b') as pass_unmuted_by_member;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_set_muted(current_setting('kan560.conv')::uuid, true);
  raise exception 'FAIL pass_mute_refused_for_non_member: the call was accepted';
exception when others then
  if sqlerrm = 'not_member' then
    raise notice 'pass_mute_refused_for_non_member = true';
  else
    raise exception 'FAIL pass_mute_refused_for_non_member: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
select set_config('request.jwt.claims', '', true);
do $$
begin
  perform public.msg_set_muted(current_setting('kan560.conv')::uuid, true);
  raise exception 'FAIL pass_mute_refused_without_token: the call was accepted';
exception when others then
  if sqlerrm = 'not_authenticated' then
    raise notice 'pass_mute_refused_without_token = true';
  else
    raise exception 'FAIL pass_mute_refused_without_token: got % (sqlstate %)', sqlerrm, sqlstate;
  end if;
end;
$$;
ROLLBACK;

-- D9 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. msg_notify in a DM: the counterpart is woken; a muted
-- counterpart is skipped; it never raises. Wakes are the rows realtime.send leaves in realtime.messages; only counts.
BEGIN;
select set_config('kan560.user_a', :'user_a', true), set_config('kan560.user_b', :'user_b', true), set_config('kan560.user_c', :'user_c', true), set_config('kan560.user_d', :'user_d', true), set_config('kan560.user_e', :'user_e', true), set_config('kan560.user_f', :'user_f', true); -- psql does not substitute variables inside dollar-quoted bodies
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
reset role;
select count(*) as before_b from realtime.messages where topic = 'user:' || :'user_b' \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify(:'conv', 1);
reset role;
select (select count(*) from realtime.messages where topic = 'user:' || :'user_b') - :before_b = 1 as pass_counterpart_woken,
       (select count(*) from realtime.messages where topic = 'user:' || :'user_a') >= 1 as pass_sender_own_topic_included;
select count(*) as before_b2 from realtime.messages where topic = 'user:' || :'user_b' \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_set_muted(:'conv', true);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select set_config('kan560.conv', :'conv', true);
do $$
begin
  perform public.msg_notify(current_setting('kan560.conv')::uuid, 2);
  raise notice 'pass_notify_never_raises = true';
exception when others then
  raise exception 'FAIL pass_notify_never_raises: msg_notify raised (sqlstate %)', sqlstate;
end;
$$;
reset role;
select (select count(*) from realtime.messages where topic = 'user:' || :'user_b') - :before_b2 = 0 as pass_muted_recipient_skipped;
ROLLBACK;

-- D10 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Reports work on a DM message exactly as on a game message
-- (msg_report_message was not re-issued); a game chat is unchanged: its member still sends, the same mute applies.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select (select created from public.msg_report_message(:'conv', gen_random_uuid(), 1, 'spam')) as pass_dm_message_reportable;
reset role;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-0000000d5600', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_a', :'user_a', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select allowed_action from public.msg_authorize('00000000-0000-4000-8000-0000000d5600', 'allowlist')) = 'send' as pass_game_chat_member_still_sends;
select (select created from public.msg_report_message('00000000-0000-4000-8000-0000000d5600', gen_random_uuid(), 1, 'spam')) as pass_game_message_reportable;
select public.msg_set_muted('00000000-0000-4000-8000-0000000d5600', true);
reset role;
select (select muted_at is not null from public.msg_conversation_members where conversation_id = '00000000-0000-4000-8000-0000000d5600' and user_id = :'user_a') as pass_game_chat_mute_works;
ROLLBACK;

-- D11 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. anon is refused everywhere (42501); the internal helpers are not callable by the app roles.
BEGIN;
set local role anon;
do $$ begin perform public.msg_start_dm('00000000-0000-4000-8000-000000000001'::uuid);
  raise exception 'FAIL pass_anon_start_refused'; exception when insufficient_privilege then raise notice 'pass_anon_start_refused = true'; end; $$;
do $$ begin perform public.msg_set_muted('00000000-0000-4000-8000-000000000001'::uuid, true);
  raise exception 'FAIL pass_anon_mute_refused'; exception when insufficient_privilege then raise notice 'pass_anon_mute_refused = true'; end; $$;
set local role authenticated;
do $$ begin perform public.msg_user_unavailable('00000000-0000-4000-8000-000000000001'::uuid);
  raise exception 'FAIL pass_helper_unavailable_not_callable'; exception when insufficient_privilege then raise notice 'pass_helper_unavailable_not_callable = true'; end; $$;
do $$ begin perform public.msg_user_age_ok('00000000-0000-4000-8000-000000000001'::uuid);
  raise exception 'FAIL pass_helper_age_not_callable'; exception when insufficient_privilege then raise notice 'pass_helper_age_not_callable = true'; end; $$;
ROLLBACK;

-- D12 [READ-ONLY] AUTHORED, NOT RUN. Shape, constraints and grants.
BEGIN;
select
  (select pg_get_constraintdef(oid) from pg_constraint where conname = 'msg_conversations_kind_check' and conrelid = 'public.msg_conversations'::regclass) like '%game%dm%' as pass_kind_check_game_and_dm,
  (select is_nullable = 'YES' from information_schema.columns where table_schema = 'public' and table_name = 'msg_conversations' and column_name = 'game_id') as pass_game_id_nullable,
  exists (select 1 from pg_constraint where conname = 'msg_conversations_kind_game_check') as pass_kind_game_pairing_check,
  (select relrowsecurity from pg_class where oid = 'public.msg_dm_pairs'::regclass) as pass_pairs_rls_on,
  not has_table_privilege('authenticated', 'public.msg_dm_pairs', 'SELECT') as pass_pairs_hidden,
  not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'msg_dm_pairs'
                and column_name in ('body', 'text', 'content', 'message')) as pass_pairs_no_content_column,
  has_function_privilege('authenticated', 'public.msg_start_dm(uuid)', 'EXECUTE') as pass_start_dm_authenticated,
  has_function_privilege('authenticated', 'public.msg_set_muted(uuid,boolean)', 'EXECUTE') as pass_set_muted_authenticated,
  not has_function_privilege('anon', 'public.msg_start_dm(uuid)', 'EXECUTE') as pass_start_dm_anon_refused,
  not has_function_privilege('anon', 'public.msg_set_muted(uuid,boolean)', 'EXECUTE') as pass_set_muted_anon_refused,
  (select bool_and(p.prosecdef and p.proconfig @> array['search_path=public, pg_temp'])
     from pg_proc p where p.oid in ('public.msg_start_dm(uuid)'::regprocedure, 'public.msg_set_muted(uuid,boolean)'::regprocedure)) as pass_definer_pinned_search_path;
ROLLBACK;
