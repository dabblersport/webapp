-- KAN-563 probes for public.msg_game_conversation.   AUTHORED, NOT RUN.
-- Variables: :game_open (not cancelled, end_at in the future), :user_a (active player of :game_open, allowlisted),
-- :user_x (no roster row on :game_open). Each block is BEGIN; ... ROLLBACK; and prints ids/booleans/reasons only.

-- G1 AUTHORED, NOT RUN. Read-or-create: the first call creates the one row, the second returns the same id.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a') on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select conversation_id as c1, allowed_action, reason, muted from public.msg_game_conversation(:'game_open') \gset
select conversation_id = :'c1' as same_id, allowed_action = 'send' as sends
  from public.msg_game_conversation(:'game_open');
reset role;
select count(*) = 1 as one_row from public.msg_conversations where game_id = :'game_open';
ROLLBACK;

-- G2 AUTHORED, NOT RUN. A stranger gets not_member and NOTHING is created.
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_x') on conflict (user_id) do nothing;
reset role;
select count(*) as before_rows from public.msg_conversations where game_id = :'game_open' \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_x', 'role', 'authenticated')::text, true);
select reason = 'not_member' as refused, conversation_id is null as no_id from public.msg_game_conversation(:'game_open');
reset role;
select count(*) = :before_rows as nothing_created from public.msg_conversations where game_id = :'game_open';
ROLLBACK;

-- G3 AUTHORED, NOT RUN. Unknown game -> not_found; not allowlisted -> not_in_pilot; anon has no EXECUTE.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_x', 'role', 'authenticated')::text, true);
select reason = 'not_found' as unknown_game from public.msg_game_conversation(gen_random_uuid());
delete from public.msg_access_allowlist where user_id = :'user_x';
ROLLBACK;
BEGIN;
set local role anon;
select * from public.msg_game_conversation(:'game_open');   -- expect permission denied (no EXECUTE for anon)
ROLLBACK;

-- G4 AUTHORED, NOT RUN. ACL: exactly authenticated (plus the owner) may execute.
BEGIN;
select has_function_privilege('anon', 'public.msg_game_conversation(uuid, text)', 'EXECUTE') as anon_false,
       has_function_privilege('authenticated', 'public.msg_game_conversation(uuid, text)', 'EXECUTE') as auth_true,
       p.prosecdef as definer, p.proconfig as config
  from pg_proc p where p.oid = 'public.msg_game_conversation(uuid, text)'::regprocedure;
ROLLBACK;
