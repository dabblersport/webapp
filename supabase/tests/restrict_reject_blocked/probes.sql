-- KAN-522 probe pack: rpc_restrict_set / rpc_restrict_clear reject 'blocked'
--
-- Covers: supabase/migrations/20261013130000_restrict_rpcs_reject_blocked.sql
--
-- STATUS: AUTHORED, NOT RUN. Nothing in this file was executed against any
-- database while writing it and this ticket does not claim it was. Memphis runs
-- it on the CEO-approved database (execute_sql, test data only, project
-- wtncuzcskpigqpmnxwws, stop on real user data) and records the real PASS/FAIL.
--
-- HOW TO RUN. Run each numbered block as ONE batch. Every block starts with
-- BEGIN and ends with ROLLBACK, so nothing persists, including the blocks marked
-- READ-ONLY (those open BEGIN READ ONLY). Section A before the apply, section B
-- after. Every B block is expected to FAIL when run before the apply (B1, B2,
-- B5 at least): that is the proof the probe can fail.
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads only (BEGIN READ ONLY)
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK
-- ROLE CAVEAT: the probes use SET LOCAL ROLE anon / authenticated with
-- request.jwt.claims. As postgres they pass vacuously.

-- ===========================================================================
-- A. PRE-APPLY
-- ===========================================================================

-- A1 [READ-ONLY] live definitions: diff against the baseline bodies in
--    rollback.sql (stop on a surprise).
begin read only;
select p.oid::regprocedure as signature, p.prosecdef, p.proconfig, pg_get_functiondef(p.oid) as def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('rpc_restrict_set','rpc_restrict_clear');
rollback;

-- A2 [READ-ONLY] ACL BEFORE. Save the output; rollback.sql restores it. Expect
--    anon_exec = true and public_grants = 1 on both (baseline grants).
begin read only;
select p.oid::regprocedure as signature,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('rpc_restrict_set','rpc_restrict_clear');
rollback;

-- A3 [READ-ONLY] DB-side callers (expect 0 rows, see CALLERS.md).
begin read only;
select p.oid::regprocedure as caller
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('public','util')
   and p.prosrc ~* '(rpc_restrict_set|rpc_restrict_clear)'
   and p.proname not in ('rpc_restrict_set','rpc_restrict_clear');
rollback;

-- A4 [WRITE-IN-TRANSACTION-ROLLBACK] BEFORE state of the defect: setting
--    'blocked' succeeds and leaves a row no guard reads. Expect NOTICE
--    "A4 DEFECT PRESENT". After the apply this block must raise A4 FAIL.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_restrict_set(b, 'blocked');
  reset role;
  select count(*) into n from public.restrictions where user_id = a and target_user_id = b and type = 'blocked';
  if n = 1 and not public.is_blocked(a, b) then raise notice 'A4 DEFECT PRESENT: a blocked restriction row exists and is_blocked is false';
  else raise exception 'A4 FAIL (expected before the apply)'; end if;
end $$;
rollback;

-- A5 [READ-ONLY] existing 'blocked' rows (informational: KAN-499 carries them to
--    user_blocks; this migration leaves them).
begin read only;
select count(*) as blocked_restriction_rows from public.restrictions where type = 'blocked';
rollback;

-- ===========================================================================
-- B. POST-APPLY
-- ===========================================================================

-- B1 [WRITE-IN-TRANSACTION-ROLLBACK] AC2: set 'blocked' raises use_rpc_block_user
--    and writes nothing (no restrictions row, no friendship change).
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; m text; n int; f0 int; f1 int;
begin
  select count(*) into f0 from public.friendships where status = 'removed';
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_set(b, 'blocked'); reset role; raise exception 'B1 FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'use_rpc_block_user' then raise exception 'B1 FAIL: got %', m; end if; end;
  select count(*) into n from public.restrictions where user_id = a and target_user_id = b and type = 'blocked';
  if n <> 0 then raise exception 'B1 FAIL: a blocked row was written'; end if;
  select count(*) into f1 from public.friendships where status = 'removed';
  if f0 <> f1 then raise exception 'B1 FAIL: a friendship was changed'; end if;
  raise notice 'B1 PASS';
end $$;
rollback;

-- B2 [WRITE-IN-TRANSACTION-ROLLBACK] clear 'blocked' raises use_rpc_unblock_user
--    and deletes nothing: a pre-existing blocked row (inserted here as postgres,
--    rolled back) survives the call.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; m text; n int;
begin
  insert into public.restrictions(user_id, target_user_id, type) values (a, b, 'blocked');
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_clear(b, 'blocked'); reset role; raise exception 'B2 FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'use_rpc_unblock_user' then raise exception 'B2 FAIL: got %', m; end if; end;
  select count(*) into n from public.restrictions where user_id = a and target_user_id = b and type = 'blocked';
  if n <> 1 then raise exception 'B2 FAIL: the blocked row was deleted'; end if;
  raise notice 'B2 PASS';
end $$;
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] other guards unchanged: invalid type, self
--    target, NULL target, and no JWT.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; m text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_set(b, 'bogus'); reset role; raise exception 'B3 set type FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'invalid_type' then raise exception 'B3 set type FAIL: got %', m; end if; end;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_clear(b, 'bogus'); reset role; raise exception 'B3 clear type FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'invalid_type' then raise exception 'B3 clear type FAIL: got %', m; end if; end;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_set(a, 'hidden'); reset role; raise exception 'B3 self FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'invalid_target' then raise exception 'B3 self FAIL: got %', m; end if; end;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_set(null, 'hidden'); reset role; raise exception 'B3 null FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'invalid_target' then raise exception 'B3 null FAIL: got %', m; end if; end;
  perform set_config('request.jwt.claims', json_build_object('role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_set(b, 'hidden'); reset role; raise exception 'B3 no-sub set FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'not_authenticated' then raise exception 'B3 no-sub set FAIL: got %', m; end if; end;
  perform set_config('request.jwt.claims', json_build_object('role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_restrict_clear(b, 'hidden'); reset role; raise exception 'B3 no-sub clear FAIL: no error'; exception when others then
    get stacked diagnostics m = message_text; reset role;
    if m <> 'not_authenticated' then raise exception 'B3 no-sub clear FAIL: got %', m; end if; end;
  raise notice 'B3 PASS';
end $$;
rollback;

-- B4 [WRITE-IN-TRANSACTION-ROLLBACK] AC2: 'hidden' behaves as before: set writes
--    one row (idempotent), is_hidden sees it, clear removes it.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_restrict_set(b, 'hidden');
  perform public.rpc_restrict_set(b, 'hidden');
  reset role;
  select count(*) into n from public.restrictions where user_id = a and target_user_id = b and type = 'hidden';
  if n <> 1 then raise exception 'B4 FAIL: expected one hidden row, got %', n; end if;
  if public.is_hidden(a, b) is distinct from true then raise exception 'B4 FAIL: is_hidden does not see the row'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_restrict_clear(b, 'hidden');
  reset role;
  if public.is_hidden(a, b) is distinct from false then raise exception 'B4 FAIL: is_hidden still true after clear'; end if;
  raise notice 'B4 PASS';
end $$;
rollback;

-- B5 [READ-ONLY] AC3: neither anon nor the PUBLIC pseudo-role can execute; both
--    authenticated and service_role can.
begin read only;
do $$
declare sig text;
begin
  foreach sig in array array['public.rpc_restrict_set(uuid,text)','public.rpc_restrict_clear(uuid,text)'] loop
    if has_function_privilege('anon', sig::regprocedure, 'EXECUTE') then raise exception 'B5 FAIL: anon can execute %', sig; end if;
    if exists (select 1 from pg_proc p, aclexplode(p.proacl) a where p.oid = sig::regprocedure and a.grantee = 0) then
      raise exception 'B5 FAIL: PUBLIC can execute %', sig; end if;
    if not has_function_privilege('authenticated', sig::regprocedure, 'EXECUTE')
       or not has_function_privilege('service_role', sig::regprocedure, 'EXECUTE') then
      raise exception 'B5 FAIL: authenticated or service_role lost EXECUTE on %', sig; end if;
  end loop;
  raise notice 'B5 PASS';
end $$;
rollback;

-- B6 [WRITE-IN-TRANSACTION-ROLLBACK] runtime: an anon call to either function is
--    refused with insufficient_privilege.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare b uuid := current_setting('k522.b')::uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.rpc_restrict_set(b, 'hidden'); reset role; raise exception 'B6 FAIL: anon rpc_restrict_set ran';
  exception when insufficient_privilege then reset role; end;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.rpc_restrict_clear(b, 'hidden'); reset role; raise exception 'B6 FAIL: anon rpc_restrict_clear ran';
  exception when insufficient_privilege then reset role; end;
  raise notice 'B6 PASS';
end $$;
rollback;

-- B7 [WRITE-IN-TRANSACTION-ROLLBACK] the real block path is unaffected:
--    rpc_block_user(uuid) still writes user_blocks (and the admin notification
--    trigger still fires), rpc_unblock_user(uuid) removes it.
begin;
do $$
declare a uuid; b uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
     and not exists (select 1 from public.restrictions r
                      where r.user_id = a and r.target_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block or restriction between them'; end if;
  perform set_config('k522.a', a::text, true);
  perform set_config('k522.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k522.a')::uuid; b uuid := current_setting('k522.b')::uuid; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k522.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  select count(*) into n from public.user_blocks where blocker_user_id = a and blocked_user_id = b;
  if n <> 1 then raise exception 'B7 FAIL: rpc_block_user did not write user_blocks'; end if;
  perform public.rpc_unblock_user(b);
  select count(*) into n from public.user_blocks where blocker_user_id = a and blocked_user_id = b;
  if n <> 0 then raise exception 'B7 FAIL: rpc_unblock_user did not remove the block'; end if;
  reset role;
  raise notice 'B7 PASS';
end $$;
rollback;
