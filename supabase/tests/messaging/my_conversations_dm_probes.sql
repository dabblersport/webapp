-- KAN-555 (Messaging DMs B3) probe pack for public.msg_my_conversations v2 (DM rows).   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261013161000_kan555_msg_my_conversations_dm.sql is applied (it needs
-- KAN-547 and KAN-560 applied). Every block is WRITE-IN-TRANSACTION-ROLLBACK (or READ-ONLY), begins with BEGIN and ends
-- with ROLLBACK. Fixtures are created inside the block and rolled back with it. Blocks print booleans and counts only:
-- no content, no names beyond equality checks. Setup is idempotent (allowlist inserts use ON CONFLICT DO NOTHING).
--
-- Variables (supplied by the runner, no secrets; existing TEST users):
--   :user_a, :user_b   adults (every profile age >= 16); :user_a is the caller, :user_b the counterpart
--   :user_e            an adult who shares nothing with :user_a
--   :game_live, :game_ended, :game_left, :game_kicked   test games with no msg_conversations row and on which
--                      :user_a has no roster row (as in my_conversations_probes.sql); :profile_a is :user_a's profile
-- A DM is created by msg_start_dm in the same transaction, so created_at equals last_activity_at there; the blocks that
-- need "a message exists" move created_at one hour back (the same as a conversation created earlier), then call the
-- real msg_notify, which stamps last_activity_at = now().
--
-- Helper used by several blocks: the expected public name of :user_b is read with the same rule the function uses.

-- L1 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Both members see the DM once a message exists, each with the
-- OTHER user as counterpart, with the public name and avatar and the kind column; no game fields.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
reset role;
update public.msg_conversations set created_at = now() - interval '1 hour' where id = :'conv';
set local role authenticated;
select public.msg_notify(:'conv', 1);
create temp table kan555_a as select * from public.msg_my_conversations();
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
create temp table kan555_b as select * from public.msg_my_conversations();
reset role;
select
  (select count(*) from kan555_a where conversation_id = :'conv') = 1 as pass_starter_sees_dm,
  (select count(*) from kan555_b where conversation_id = :'conv') = 1 as pass_recipient_sees_dm_after_first_message,
  (select kind = 'dm' and game_id is null and game_title is null and sport is null and start_at is null and end_at is null
     from kan555_a where conversation_id = :'conv') as pass_dm_row_has_no_game_fields,
  (select counterpart_user_id = :'user_b'::uuid from kan555_a where conversation_id = :'conv') as pass_starter_counterpart_is_b,
  (select counterpart_user_id = :'user_a'::uuid from kan555_b where conversation_id = :'conv') as pass_recipient_counterpart_is_a,
  (select counterpart_name is not distinct from
     (select v.display_name from public.profiles p join public.v_profile_public v on v.id = p.id
       where p.user_id = :'user_b' order by (p.profile_type = 'personal') desc, p.created_at limit 1)
     from kan555_a where conversation_id = :'conv') as pass_counterpart_name_is_the_public_name,
  (select counterpart_avatar is not distinct from
     (select v.avatar_url from public.profiles p join public.v_profile_public v on v.id = p.id
       where p.user_id = :'user_b' order by (p.profile_type = 'personal') desc, p.created_at limit 1)
     from kan555_a where conversation_id = :'conv') as pass_counterpart_avatar_is_the_public_avatar,
  (select state = 'send' from kan555_a where conversation_id = :'conv') as pass_dm_state_send;
ROLLBACK;

-- L2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. The empty-DM rule: a started-but-empty DM is listed for the
-- starter and NOT for the recipient; after the first message the recipient sees it.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select (select count(*) from public.msg_my_conversations() where conversation_id = :'conv') = 1 as pass_empty_dm_listed_for_starter;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select count(*) from public.msg_my_conversations() where conversation_id = :'conv') = 0 as pass_empty_dm_hidden_from_recipient;
reset role;
update public.msg_conversations set created_at = now() - interval '1 hour' where id = :'conv';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_notify(:'conv', 1);
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select count(*) from public.msg_my_conversations() where conversation_id = :'conv') = 1 as pass_recipient_sees_dm_after_first_message;
ROLLBACK;

-- L3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A block in either direction makes the DM read_only for both;
-- a banned or deleted counterpart makes it read_only; unblocking restores send.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'send' as pass_send_before_block;
reset role;
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_b', :'user_a');
set local role authenticated;
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'read_only' as pass_blocked_side_read_only;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
reset role;
update public.msg_conversations set created_at = now() - interval '1 hour', last_activity_at = now() where id = :'conv';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'read_only' as pass_blocker_side_read_only;
reset role;
delete from public.user_blocks where blocker_user_id = :'user_b' and blocked_user_id = :'user_a';
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'user_a', :'user_b');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'read_only' as pass_block_in_the_other_direction_read_only;
reset role;
delete from public.user_blocks where blocker_user_id = :'user_a' and blocked_user_id = :'user_b';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'send' as pass_unblocked_send_again;
reset role;
update auth.users set banned_until = now() + interval '1 day' where id = :'user_a';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'read_only' as pass_banned_counterpart_read_only;
reset role;
update auth.users set banned_until = null, deleted_at = now() where id = :'user_a';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select state from public.msg_my_conversations() where conversation_id = :'conv') = 'read_only' as pass_deleted_counterpart_read_only;
ROLLBACK;

-- L4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. The muted flag reflects the CALLER only.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
reset role;
update public.msg_conversations set created_at = now() - interval '1 hour' where id = :'conv';
set local role authenticated;
select public.msg_notify(:'conv', 1);
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select (select muted = false from public.msg_my_conversations() where conversation_id = :'conv') as pass_not_muted_by_default;
select public.msg_set_muted(:'conv', true);
select (select muted from public.msg_my_conversations() where conversation_id = :'conv') as pass_muter_sees_muted_true;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select muted = false from public.msg_my_conversations() where conversation_id = :'conv') as pass_other_side_still_false;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_set_muted(:'conv', false);
select (select muted = false from public.msg_my_conversations() where conversation_id = :'conv') as pass_unmuted_false_again;
ROLLBACK;

-- L5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Game rows are unchanged (kind game, NULL counterpart fields,
-- the v1 states, kicked excluded) and are ordered with a DM by last activity.
BEGIN;
insert into public.msg_conversations (id, game_id, last_activity_at) values
  ('00000000-0000-4000-8000-0000000d5550', :'game_live',   now() - interval '2 hours'),
  ('00000000-0000-4000-8000-0000000d5551', :'game_ended',  now() - interval '4 hours'),
  ('00000000-0000-4000-8000-0000000d5552', :'game_left',   now() - interval '5 hours'),
  ('00000000-0000-4000-8000-0000000d5553', :'game_kicked', now() - interval '6 hours');
update public.games set end_at = now() - interval '1 minute', start_at = now() - interval '3 hours' where id = :'game_ended';
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_live',   :'profile_a', :'user_a', 'player', 'active'),
  (:'game_ended',  :'profile_a', :'user_a', 'player', 'active'),
  (:'game_left',   :'profile_a', :'user_a', 'player', 'left'),
  (:'game_kicked', :'profile_a', :'user_a', 'player', 'kicked');
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
reset role;
update public.msg_conversations set created_at = now() - interval '9 hours', last_activity_at = now() - interval '3 hours' where id = :'conv';
set local role authenticated;
create temp table kan555_l5 as select * from public.msg_my_conversations();
reset role;
select
  (select state from kan555_l5 where game_id = :'game_live') = 'send' as pass_game_send_unchanged,
  (select state from kan555_l5 where game_id = :'game_ended') = 'read_only' as pass_game_read_only_unchanged,
  (select state from kan555_l5 where game_id = :'game_left') = 'left' as pass_game_left_unchanged,
  not exists (select 1 from kan555_l5 where game_id = :'game_kicked') as pass_kicked_game_still_absent,
  (select bool_and(kind = 'game' and counterpart_user_id is null and counterpart_name is null and counterpart_avatar is null and muted = false)
     from kan555_l5 where game_id is not null) as pass_game_rows_have_null_counterpart,
  (select array_agg(conversation_id order by rn) from (select conversation_id, row_number() over () as rn from kan555_l5) o)
     = array['00000000-0000-4000-8000-0000000d5550'::uuid, :'conv'::uuid, '00000000-0000-4000-8000-0000000d5551'::uuid, '00000000-0000-4000-8000-0000000d5552'::uuid]
     as pass_dm_ordered_with_games_by_last_activity;
ROLLBACK;

-- L6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A non-participant sees nothing of the DM; no token sees nothing;
-- the limit clamp still holds.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b'), (:'user_e')
  on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select public.msg_start_dm(:'user_b') as conv \gset
select set_config('request.jwt.claims', json_build_object('sub', :'user_e', 'role', 'authenticated')::text, true);
select (select count(*) from public.msg_my_conversations() where conversation_id = :'conv') = 0 as pass_non_participant_sees_nothing;
select set_config('request.jwt.claims', '', true);
select (select count(*) from public.msg_my_conversations()) = 0 as pass_no_token_empty;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select (select count(*) from public.msg_my_conversations(0)) <= 1 as pass_limit_zero_clamped,
       (select count(*) from public.msg_my_conversations(100000)) <= 100 as pass_limit_capped_at_100;
ROLLBACK;

-- L7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. anon is refused (42501).
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

-- L8 [READ-ONLY] AUTHORED, NOT RUN. The result has exactly the v1 columns then the five new ones (no content column),
-- the old function is renamed and not callable by the app, and the grants and attributes are right.
BEGIN;
select
  (select pg_get_function_result(p.oid) from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure)
     = 'TABLE(conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamp with time zone, end_at timestamp with time zone, state text, last_activity_at timestamp with time zone, kind text, counterpart_user_id uuid, counterpart_name text, counterpart_avatar text, muted boolean)' as pass_exact_columns,
  has_function_privilege('authenticated', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_authenticated_can_execute,
  not has_function_privilege('anon', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_anon_cannot_execute,
  not has_function_privilege('public', 'public.msg_my_conversations(int)', 'EXECUTE') as pass_public_cannot_execute,
  not has_function_privilege('authenticated', 'public.msg_my_conversations_v1(int)', 'EXECUTE') as pass_v1_not_callable_by_app,
  (select p.prosecdef and p.proconfig @> array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure) as pass_definer_pinned_search_path,
  (select pg_get_userbyid(p.proowner) from pg_proc p where p.oid = 'public.msg_my_conversations(int)'::regprocedure) = 'postgres' as pass_owner_postgres;
ROLLBACK;
