-- KAN-505 (Messaging T8) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: a NON-PRODUCTION branch of project wtncuzcskpigqpmnxwws, after the four
-- KAN-505 migrations are applied there. Run with psql as the branch owner role.
-- Every block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and ends in `rollback;`.
-- Each block prints boolean `pass` columns; every one must be true.
--
-- TEST ACCOUNTS (non-prod test users only; ids supplied by the runner, no secrets here):
--   :user_a   pilot user, active 'player' on :game_id      (sender / blocker)
--   :user_b   pilot user, active 'player' on :game_id      (blocked by A)
--   :user_c   pilot user, NOT on :game_id's roster         (non-member)
--   :user_d   NOT allowlisted                              (non-pilot)
--   :game_id  a non-prod test game whose end_at is in the future, not cancelled,
--             with no msg_conversations row yet
--   :profile_x a profile id owned by :user_c, used to create roster rows in-transaction
-- e.g. psql -v user_a=... -v user_b=... -v user_c=... -v user_d=... -v game_id=... -v profile_x=... -f probes.sql
--
-- Token handling: PostgREST verifies the bearer token before SQL runs, so a forged or
-- expired token arrives with no claims. In SQL that is emulated by an empty
-- request.jwt.claims, which makes auth.uid() null.

-- shared fixture, re-created inside every write block:
--   conversation id 00000000-0000-4000-8000-00000000c505 on :game_id; A, B, C allowlisted.

-- P1 [READ-ONLY] AUTHORED, NOT RUN. Grants and settings on the new objects.
begin;
select
  not has_function_privilege('anon', 'public.msg_authorize(uuid,text)', 'EXECUTE') as pass_anon_no_exec,
  has_function_privilege('authenticated', 'public.msg_authorize(uuid,text)', 'EXECUTE') as pass_auth_exec,
  not has_function_privilege('authenticated', 'public.msg_can_send(uuid,uuid,text)', 'EXECUTE') as pass_can_send_internal,
  not has_table_privilege('authenticated', 'public.msg_access_allowlist', 'SELECT') as pass_allowlist_hidden,
  not has_table_privilege('anon', 'public.msg_conversations', 'SELECT') as pass_registry_hidden,
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.msg_conversations'::regclass, 'public.msg_conversation_members'::regclass,
                  'public.msg_access_allowlist'::regclass)) as pass_rls_on;
rollback;

-- P2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Non-member and guessed id denied.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
select (r.allowed_action is null and r.reason = 'not_member' and r.member_user_ids is null) as pass_non_member
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
select (r.allowed_action is null and r.reason = 'not_member') as pass_guessed_id
  from public.msg_authorize('00000000-0000-4000-8000-0000deadbeef', 'allowlist') r;
rollback;

-- P3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. 'kicked' (created explicitly) denied.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status)
  values (:'game_id', :'profile_x', :'user_c', 'player', 'kicked');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
select (r.allowed_action is null and r.reason = 'removed' and r.left_at_seq is null) as pass_kicked
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
rollback;

-- P4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. 'left' reads up to left_at_seq only.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status)
  values (:'game_id', :'profile_x', :'user_c', 'player', 'left');
insert into public.msg_conversation_members (conversation_id, user_id, left_at_seq)
  values ('00000000-0000-4000-8000-00000000c505', :'user_c', 42);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'read' and r.reason = 'left' and r.left_at_seq = 42
        and not (:'user_c'::uuid = any (r.member_user_ids))) as pass_left_reads_to_seq
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
rollback;

-- P5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Ended game not writable (D5); reason is exactly game_ended.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
select (public.msg_can_send('00000000-0000-4000-8000-00000000c505', :'user_a', 'allowlist')) as pass_writable_before;
update public.games set start_at = now() - interval '3 hours', end_at = now() - interval '1 minute' where id = :'game_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'read' and r.reason = 'game_ended') as pass_ended_game_ended
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
reset role;
select (not public.msg_can_send('00000000-0000-4000-8000-00000000c505', :'user_a', 'allowlist')
        and public.msg_can_read('00000000-0000-4000-8000-00000000c505', :'user_a', 'allowlist')) as pass_ended_still_readable;
rollback;

-- P6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Cancelled game not writable (D5); reason is exactly game_cancelled.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
update public.games set is_cancelled = true, cancelled_at = now() where id = :'game_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'read' and r.reason = 'game_cancelled') as pass_cancelled_game_cancelled
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
rollback;

-- P6b [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Cancelled AND past its end: cancelled wins.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
update public.games set is_cancelled = true, cancelled_at = now(),
       start_at = now() - interval '3 hours', end_at = now() - interval '1 minute' where id = :'game_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'read' and r.reason = 'game_cancelled') as pass_cancelled_and_ended_game_cancelled
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
rollback;

-- P7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Blocked pair in a game chat (D4).
-- Both stay members and both may send; only the blocker gets the blocked id to hide.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_a', :'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'send' and :'user_b'::uuid = any (r.hidden_sender_ids)
        and :'user_b'::uuid = any (r.member_user_ids)) as pass_blocker_hides_blocked
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (r.allowed_action = 'send' and not (:'user_a'::uuid = any (r.hidden_sender_ids))
        and :'user_a'::uuid = any (r.member_user_ids)) as pass_blocked_still_member
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
rollback;

-- P8 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Non-allowlisted user -> not_in_pilot.
begin;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c505', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_d', 'role', 'authenticated')::text, true);
select (r.allowed_action is null and r.reason = 'not_in_pilot') as pass_not_in_pilot
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'allowlist') r;
select (r.reason = 'messaging_off') as pass_unknown_mode_fails_closed
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'bogus') r;
rollback;

-- P9 [READ-ONLY] AUTHORED, NOT RUN. Forged / expired token yields no user_id.
begin;
set local role authenticated;
select set_config('request.jwt.claims', '', true);
select (r.user_id is null and r.allowed_action is null and r.reason = 'not_authenticated') as pass_no_uid
  from public.msg_authorize('00000000-0000-4000-8000-00000000c505', 'all') r;
rollback;

-- P10 [READ-ONLY] AUTHORED, NOT RUN. User A cannot join user B's topic.
-- Emulates the policy check: realtime.topic() reads the realtime.topic setting.
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select set_config('realtime.topic', 'user:' || :'user_b', true);
select (count(*) = 0) as pass_a_not_on_b_topic from realtime.messages where topic = 'user:' || :'user_b';
select (realtime.topic() = 'user:' || auth.uid()::text) is not true as pass_policy_expr_false_for_b;
select set_config('realtime.topic', 'user:' || :'user_a', true);
select (realtime.topic() = 'user:' || auth.uid()::text) as pass_policy_expr_true_for_own;
rollback;

-- KAN-530 probe P11 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. KAN-530: report_content drops free text for a message.
-- :user_a is a test user acting as the reporter; :msg_target and :post_target are any uuids.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.details is null) as pass_message_details_pinned_null
  from public.report_content('message', :'msg_target', 'spam', 'free text', null) r;
ROLLBACK;

-- KAN-530 probe P12 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. KAN-530: any other type keeps its details unchanged.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (r.details = 'free text') as pass_post_details_unchanged
  from public.report_content('post', :'post_target', 'spam', 'free text', null) r;
ROLLBACK;

-- KAN-530 probe P13 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. KAN-530: a direct insert of a message report with details is refused (23514).
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
do $$
begin
  insert into public.moderation_reports (reporter_user_id, target_type, target_id, reason, details)
  values (auth.uid(), 'message', gen_random_uuid(), 'spam', 'free text');
  raise exception 'FAIL pass_direct_message_with_details_refused: insert was accepted';
exception when check_violation then
  raise notice 'pass_direct_message_with_details_refused = true (23514)';
end;
$$;
ROLLBACK;

-- KAN-530 probe P14 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. KAN-530: a direct insert for a post with details succeeds.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
with ins as (
  insert into public.moderation_reports (reporter_user_id, target_type, target_id, reason, details)
  values (auth.uid(), 'post', gen_random_uuid(), 'spam', 'free text')
  returning details)
select (details = 'free text') as pass_direct_post_with_details_ok from ins;
ROLLBACK;

-- KAN-530 probe P15 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. KAN-530: a direct insert of a message report with details NULL succeeds.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
with ins as (
  insert into public.moderation_reports (reporter_user_id, target_type, target_id, reason, details)
  values (auth.uid(), 'message', gen_random_uuid(), 'spam', null)
  returning details)
select (details is null) as pass_direct_message_null_details_ok from ins;
ROLLBACK;
