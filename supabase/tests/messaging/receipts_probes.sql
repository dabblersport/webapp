-- KAN-580 probe pack for public.msg_ack_receipt and public.msg_receipt_summary.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261020150000_kan580_msg_receipts.sql is applied. Every block is
-- WRITE-IN-TRANSACTION-ROLLBACK: it begins with BEGIN and ends with ROLLBACK, and prints booleans and counts only.
--
-- Variables (supplied by the runner, no secrets): :game_id (future, not cancelled), :user_a (active player: the
-- sender), :user_b, :user_c (active players with profiles :profile_b, :profile_c), :user_e (not on the roster).
-- Conversation id 00000000-0000-4000-8000-00000000d580.

-- R1 Monotonic: delivered then seen advances; a lower or equal ack never regresses; seen implies delivered.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'delivered', 5);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 3);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'delivered', 2);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 1);
reset role;
select
  (select delivered_seq from public.msg_receipts where user_id = :'user_b') = 5 as pass_delivered_not_regressed,
  (select seen_seq from public.msg_receipts where user_id = :'user_b') = 3 as pass_seen_kept_at_3,
  (select bool_and(seen_seq <= delivered_seq) from public.msg_receipts) as pass_seen_le_delivered;
ROLLBACK;

-- R2 Seen above delivered raises delivered with it (seen implies delivered).
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 7);
reset role;
select (select delivered_seq = 7 and seen_seq = 7 from public.msg_receipts where user_id = :'user_b') as pass_seen_raises_delivered;
ROLLBACK;

-- R3 Idempotent / multi-device: the same ack twice (two devices, or a retry) reports advanced=true once, then false.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select advanced as first_adv from public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 4) \gset
select advanced as second_adv from public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 4) \gset
reset role;
select :'first_adv'::boolean as pass_first_advances, not :'second_adv'::boolean as pass_replay_is_noop,
       (select count(*) from public.msg_receipts where user_id = :'user_b') = 1 as pass_single_row;
ROLLBACK;

-- R4 Only a current member advances state: a non-member, a removed member and no token change nothing.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_e');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'removed');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 3);
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 3);
select set_config('request.jwt.claims', '', true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 3);
reset role;
select (select count(*) from public.msg_receipts) = 0 as pass_no_row_for_non_member_removed_or_anon;
ROLLBACK;

-- R5 Bad input changes nothing: unknown state, null seq, zero or negative seq.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'read', 3);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', null);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 0);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', -4);
reset role;
select (select count(*) from public.msg_receipts) = 0 as pass_bad_input_writes_nothing;
ROLLBACK;

-- R6 A member who LEFT is capped at left_at_seq.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'left');
insert into public.msg_conversation_members (conversation_id, user_id, left_at_seq) values ('00000000-0000-4000-8000-00000000d580', :'user_b', 4);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 9);
reset role;
select (select seen_seq = 4 and delivered_seq = 4 from public.msg_receipts where user_id = :'user_b') as pass_leaver_capped_at_left_at_seq;
ROLLBACK;

-- R7 Direct table access is closed: an authenticated caller cannot read or write msg_receipts.
BEGIN;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
do $$ begin
  begin perform 1 from public.msg_receipts; raise exception 'read allowed'; exception when insufficient_privilege then null; end;
  begin insert into public.msg_receipts (conversation_id, user_id, delivered_seq) values ('00000000-0000-4000-8000-00000000d580', gen_random_uuid(), 1); raise exception 'write allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select true as pass_table_closed_to_api_roles;
ROLLBACK;

-- R8 Group counts: two recipients (the sender is excluded), distinct counting. B has seen 5, C has only had 3
-- delivered; the sender asks about seq 3 and seq 5. (A blocker leaving the denominator is NOT probed here: NOT RUN
-- and not covered; add a block of this shape before apply if wanted.)
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'seen', 5);
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
select public.msg_ack_receipt('00000000-0000-4000-8000-00000000d580', 'delivered', 3);
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select recipients as r3, delivered_count as d3, seen_count as s3 from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[3, 5]) where seq = 3 \gset
select recipients as r5, delivered_count as d5, seen_count as s5 from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[3, 5]) where seq = 5 \gset
reset role;
select :r3 = 2 and :d3 = 2 and :s3 = 1 as pass_seq3_delivered_by_both_seen_by_one,
       :r5 = 2 and :d5 = 1 and :s5 = 1 as pass_seq5_only_b_has_it;
ROLLBACK;

-- R9 Denominator follows membership: when C is removed, recipients drops from 2 to 1 and C no longer counts in the
-- numerators.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
insert into public.msg_receipts (conversation_id, user_id, delivered_seq, seen_seq) values
  ('00000000-0000-4000-8000-00000000d580', :'user_b', 5, 5),
  ('00000000-0000-4000-8000-00000000d580', :'user_c', 5, 5);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select recipients as r_before, seen_count as s_before from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[5]) \gset
reset role;
update public.game_roster set status = 'removed' where game_id = :'game_id' and user_id = :'user_c';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select recipients as r_after, seen_count as s_after from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[5]) \gset
reset role;
select :r_before = 2 and :s_before = 2 as pass_before, :r_after = 1 and :s_after = 1 as pass_removed_member_leaves_denominator;
ROLLBACK;

-- R10 A non-member asking for a summary gets no rows; so does an oversized or empty seq list.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_e');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d580', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select count(*) as n_nonmember from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[1]) \gset
select count(*) as n_empty from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', array[]::bigint[]) \gset
select count(*) as n_big from public.msg_receipt_summary('00000000-0000-4000-8000-00000000d580', (select array_agg(g) from generate_series(1, 101) g)) \gset
reset role;
select :n_nonmember = 0 and :n_empty = 0 and :n_big = 0 as pass_no_rows;
ROLLBACK;

-- R11 Grants: anon cannot execute either function; authenticated can.
select
  not has_function_privilege('anon', 'public.msg_ack_receipt(uuid, text, bigint, text)', 'execute') as pass_anon_no_ack,
  not has_function_privilege('anon', 'public.msg_receipt_summary(uuid, bigint[], text)', 'execute') as pass_anon_no_summary,
  has_function_privilege('authenticated', 'public.msg_ack_receipt(uuid, text, bigint, text)', 'execute') as pass_auth_ack,
  has_function_privilege('authenticated', 'public.msg_receipt_summary(uuid, bigint[], text)', 'execute') as pass_auth_summary;
