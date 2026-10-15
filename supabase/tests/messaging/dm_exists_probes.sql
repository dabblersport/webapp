-- KAN-561 probes for public.msg_dm_exists.   AUTHORED, NOT RUN. Variables: :user_a, :user_b (adults), :user_e (no DM with a).
-- Each block is WRITE-IN-TRANSACTION-ROLLBACK, prints booleans only.

-- E1 false before the pair exists, true for BOTH members after msg_start_dm, with no message in it (an empty DM).
BEGIN;
insert into public.msg_access_allowlist (user_id) values (:'user_a'), (:'user_b') on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select not public.msg_dm_exists(:'user_b') as before_false;
select public.msg_start_dm(:'user_b') as conv \gset
select public.msg_dm_exists(:'user_b') as a_sees_true;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b', 'role', 'authenticated')::text, true);
select public.msg_dm_exists(:'user_a') as b_sees_true;
ROLLBACK;

-- E2 a stranger pair is false; self and anonymous are refused.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select not public.msg_dm_exists(:'user_e') as stranger_false;
select public.msg_dm_exists(:'user_a');   -- expect invalid_request (22023)
ROLLBACK;
BEGIN;
set local role anon;
select public.msg_dm_exists(:'user_b');   -- expect permission denied (no EXECUTE for anon)
ROLLBACK;
