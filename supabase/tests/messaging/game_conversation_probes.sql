-- KAN-563 probes for public.msg_game_conversation.   AUTHORED, NOT RUN. Each block is WRITE-IN-TRANSACTION-ROLLBACK and
-- prints booleans only. Variables (existing TEST data): :game_live (a live game), :host_user (its host, on the allowlist),
-- :stranger (an allowlisted user with no roster row on it), :game_ended, :ended_member (an active member of :game_ended).

-- G1 an active member of a live game gets a conversation (created on first use) that is writable; a second call returns the same id.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'host_user', 'role', 'authenticated')::text, true);
select conversation_id as conv, allowed_action = 'send' as writable, reason is null as no_reason, not muted as not_muted
  from public.msg_game_conversation(:'game_live', 'all') \gset
select :'conv' is not null as has_id, :'writable' as writable_true;
select (select conversation_id from public.msg_game_conversation(:'game_live', 'all')) = :'conv'::uuid as same_id;
ROLLBACK;

-- G2 a stranger gets not_member and NO conversation row is created for the game.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'stranger', 'role', 'authenticated')::text, true);
select allowed_action is null as denied, reason = 'not_member' as not_member, conversation_id is null as no_id
  from public.msg_game_conversation(:'game_live', 'all');
reset role;
select not exists (select 1 from public.msg_conversations where game_id = :'game_live') as no_row_created;
ROLLBACK;

-- G3 an ended game gives read / game_ended; an unknown game gives not_found; no token gives not_authenticated.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'ended_member', 'role', 'authenticated')::text, true);
select allowed_action = 'read' as read_only, reason = 'game_ended' as ended from public.msg_game_conversation(:'game_ended', 'all');
select reason = 'not_found' as unknown_game from public.msg_game_conversation('ffffffff-ffff-4fff-8fff-ffffffffffff', 'all');
ROLLBACK;
BEGIN;
set local role anon;
select public.msg_game_conversation(:'game_live', 'all');   -- expect permission denied (no EXECUTE for anon)
ROLLBACK;

-- M1 an active member mutes and unmutes in one call, idempotently; the muted flag is what msg_game_conversation returns.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'host_user', 'role', 'authenticated')::text, true);
select conversation_id as conv from public.msg_game_conversation(:'game_live', 'all') \gset
select reason is null as applied from public.msg_mute_conversation(:'conv', true, 'all');
select reason is null as applied_again from public.msg_mute_conversation(:'conv', true, 'all');
select muted as is_muted from public.msg_game_conversation(:'game_live', 'all');
select reason is null as unmuted from public.msg_mute_conversation(:'conv', false, 'all');
select not muted as not_muted from public.msg_game_conversation(:'game_live', 'all');
ROLLBACK;

-- M2 a stranger is refused with not_member and nothing is written.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'host_user', 'role', 'authenticated')::text, true);
select conversation_id as conv from public.msg_game_conversation(:'game_live', 'all') \gset
select set_config('request.jwt.claims', json_build_object('sub', :'stranger', 'role', 'authenticated')::text, true);
select reason = 'not_member' as refused from public.msg_mute_conversation(:'conv', true, 'all');
reset role;
select not exists (select 1 from public.msg_conversation_members where conversation_id = :'conv' and user_id = :'stranger') as nothing_written;
ROLLBACK;
