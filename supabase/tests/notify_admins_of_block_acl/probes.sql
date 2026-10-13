-- KAN-523 probe pack: notify_admins_of_block() ACL
--
-- Covers: supabase/migrations/20261013140000_revoke_public_notify_admins_of_block.sql
--
-- STATUS: AUTHORED, NOT RUN. Nothing in this file was executed against any
-- database while writing it and this ticket does not claim it was. Memphis runs
-- it on the CEO-approved database (execute_sql, test data only, project
-- wtncuzcskpigqpmnxwws, stop on real user data) and records the real PASS/FAIL.
--
-- HOW TO RUN. Run each numbered block as ONE batch. Every block starts with
-- BEGIN and ends with ROLLBACK, so nothing persists, including the READ-ONLY
-- blocks (BEGIN READ ONLY). Section A before the apply, section B after. B1 and
-- B2 are expected to FAIL before the apply (the proof they can fail).
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads only
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK
-- ROLE CAVEAT: the write probes use SET LOCAL ROLE authenticated / anon with
-- request.jwt.claims. As postgres they pass vacuously.

-- A. PRE-APPLY ------------------------------------------------------------

-- A1 [READ-ONLY] ACL BEFORE. Save the output. Expect anon_exec = true and
--    authenticated_exec = true through PUBLIC, public_grants = 1, service_role true.
begin read only;
select p.oid::regprocedure as signature, p.prosecdef as security_definer, p.prorettype::regtype as returns,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'notify_admins_of_block';
rollback;

-- A2 [READ-ONLY] who uses it: expect exactly trg_notify_admins_of_block, and no
--    function body that names it (CALLERS.md).
begin read only;
select 'trigger' as kind, t.tgname as name, t.tgrelid::regclass::text as on_table, t.tgenabled
  from pg_trigger t where t.tgfoid = 'public.notify_admins_of_block()'::regprocedure and not t.tgisinternal
union all
select 'function', p.oid::regprocedure::text, null, null
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('public','util') and p.prosrc ~* 'notify_admins_of_block'
   and p.proname <> 'notify_admins_of_block';
rollback;

-- A3 [WRITE-IN-TRANSACTION-ROLLBACK] BEFORE state of the notification: a block
--    through rpc_block_user(uuid) as an authenticated test user writes one
--    moderation.user_blocked notification per app_admins row. Expect NOTICE
--    "A3 PASS" (the baseline behaviour B3 must preserve).
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
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block between them'; end if;
  perform set_config('k523.a', a::text, true);
  perform set_config('k523.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k523.a')::uuid; b uuid := current_setting('k523.b')::uuid;
        admins int; before_ids text[]; new_rows int; new_distinct int; per_admin_bad int; stray int;
begin
  select count(*) into admins from public.app_admins;
  if admins < 1 then raise exception 'SETUP FAIL: app_admins is empty, so no notification can be expected; use a database with at least one test admin'; end if;
  if a = b or not exists (select 1 from public.profiles where user_id = a and is_active) or not exists (select 1 from public.profiles where user_id = b and is_active) then
    raise exception 'SETUP FAIL: the blocker and the blocked user must be two distinct active test users'; end if;
  raise notice 'A3 fixture: blocker=% blocked=% admins=%', a, b, admins;
  -- snapshot the ids that exist BEFORE the block, so only NEW rows are judged
  select coalesce(array_agg(id::text), '{}') into before_ids from public.notifications
   where kind_key = 'moderation.user_blocked' and context->>'blocker_user_id' = a::text and context->>'blocked_user_id' = b::text;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k523.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  reset role;
  create temp table k523_new on commit drop as
    select n.id::text as id, n.to_user_id from public.notifications n
     where n.kind_key = 'moderation.user_blocked' and n.context->>'blocker_user_id' = a::text and n.context->>'blocked_user_id' = b::text
       and not (n.id::text = any (before_ids));
  select count(*), count(distinct to_user_id) into new_rows, new_distinct from k523_new;
  if new_rows <> admins then raise exception 'A3 FAIL: expected % NEW notifications (one per admin), got %', admins, new_rows; end if;
  if new_distinct <> admins then raise exception 'A3 FAIL: the % new notifications reach only % distinct recipients', new_rows, new_distinct; end if;
  select count(*) into stray from k523_new where to_user_id not in (select user_id from public.app_admins);
  if stray <> 0 then raise exception 'A3 FAIL: % new notifications went to someone who is not an admin', stray; end if;
  select count(*) into per_admin_bad from public.app_admins ad
   where (select count(*) from k523_new k where k.to_user_id = ad.user_id) <> 1;
  if per_admin_bad <> 0 then raise exception 'A3 FAIL: % admins did not get exactly one new notification', per_admin_bad; end if;
  raise notice 'A3 PASS (admins=%, exactly one NEW notification per admin, no extras)', admins;
end $$;
rollback;

-- B. POST-APPLY -----------------------------------------------------------

-- B1 [READ-ONLY] AC1: anon, authenticated and the PUBLIC pseudo-role (grantee 0)
--    cannot execute; service_role can.
begin read only;
do $$
declare f oid := 'public.notify_admins_of_block()'::regprocedure;
begin
  if has_function_privilege('anon', f, 'EXECUTE') then raise exception 'B1 FAIL: anon can execute'; end if;
  if has_function_privilege('authenticated', f, 'EXECUTE') then raise exception 'B1 FAIL: authenticated can execute'; end if;
  if exists (select 1 from pg_proc p, aclexplode(p.proacl) a where p.oid = f and a.grantee = 0) then
    raise exception 'B1 FAIL: PUBLIC can execute'; end if;
  if not has_function_privilege('service_role', f, 'EXECUTE') then raise exception 'B1 FAIL: service_role lost EXECUTE'; end if;
  raise notice 'B1 PASS';
end $$;
rollback;

-- B2 [WRITE-IN-TRANSACTION-ROLLBACK] runtime: an anon and an authenticated direct
--    call are refused with insufficient_privilege (a trigger function cannot be
--    called this way in any case; the refusal must come first).
begin;
do $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.notify_admins_of_block(); reset role; raise exception 'B2 FAIL: anon call was not refused';
  exception when insufficient_privilege then reset role; end;
  perform set_config('request.jwt.claims', json_build_object('role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.notify_admins_of_block(); reset role; raise exception 'B2 FAIL: authenticated call was not refused';
  exception when insufficient_privilege then reset role; end;
  raise notice 'B2 PASS';
end $$;
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] AC2: a block as an authenticated test user
--    still creates one notification per admin (count before and after inside the
--    transaction). STOP if this fails: do not grant authenticated to fix it.
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
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block between them'; end if;
  perform set_config('k523.a', a::text, true);
  perform set_config('k523.b', b::text, true);
end $$;
do $$
declare a uuid := current_setting('k523.a')::uuid; b uuid := current_setting('k523.b')::uuid;
        admins int; before_ids text[]; new_rows int; new_distinct int; per_admin_bad int; stray int;
begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_notify_admins_of_block' and tgenabled = 'O') then
    raise exception 'B3 FAIL: trg_notify_admins_of_block missing or disabled'; end if;
  select count(*) into admins from public.app_admins;
  if admins < 1 then raise exception 'SETUP FAIL: app_admins is empty, so no notification can be expected; use a database with at least one test admin'; end if;
  if a = b or not exists (select 1 from public.profiles where user_id = a and is_active) or not exists (select 1 from public.profiles where user_id = b and is_active) then
    raise exception 'SETUP FAIL: the blocker and the blocked user must be two distinct active test users'; end if;
  raise notice 'B3 fixture: blocker=% blocked=% admins=%', a, b, admins;
  -- snapshot the ids that exist BEFORE the block, so only NEW rows are judged
  select coalesce(array_agg(id::text), '{}') into before_ids from public.notifications
   where kind_key = 'moderation.user_blocked' and context->>'blocker_user_id' = a::text and context->>'blocked_user_id' = b::text;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k523.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  reset role;
  create temp table k523_new on commit drop as
    select n.id::text as id, n.to_user_id from public.notifications n
     where n.kind_key = 'moderation.user_blocked' and n.context->>'blocker_user_id' = a::text and n.context->>'blocked_user_id' = b::text
       and not (n.id::text = any (before_ids));
  select count(*), count(distinct to_user_id) into new_rows, new_distinct from k523_new;
  if new_rows <> admins then raise exception 'B3 FAIL: expected % NEW notifications (one per admin), got %', admins, new_rows; end if;
  if new_distinct <> admins then raise exception 'B3 FAIL: the % new notifications reach only % distinct recipients', new_rows, new_distinct; end if;
  select count(*) into stray from k523_new where to_user_id not in (select user_id from public.app_admins);
  if stray <> 0 then raise exception 'B3 FAIL: % new notifications went to someone who is not an admin', stray; end if;
  select count(*) into per_admin_bad from public.app_admins ad
   where (select count(*) from k523_new k where k.to_user_id = ad.user_id) <> 1;
  if per_admin_bad <> 0 then raise exception 'B3 FAIL: % admins did not get exactly one new notification', per_admin_bad; end if;
  raise notice 'B3 PASS (admins=%, exactly one NEW notification per admin, no extras)', admins;
end $$;
rollback;
