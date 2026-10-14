-- KAN-499 probe pack: collapse of rpc_block_user(uuid, boolean) onto user_blocks
--
-- Covers: supabase/migrations/20261013120000_kan499_collapse_rpc_block_user_overload.sql
--
-- STATUS: AUTHORED, NOT RUN. Nothing in this file was executed against any database while
-- writing it, and this ticket does not claim it was. It is to be run later by whoever applies
-- the migration, on a CEO-APPROVED NON-PRODUCTION database first. There is none approved yet.
-- Do NOT run it against the live project wtncuzcskpigqpmnxwws without the CEO's explicit approval.
--
-- HOW TO RUN. Run each numbered block as ONE batch (psql -f on the single block, or paste one
-- block). Every block starts with BEGIN and ends with ROLLBACK, so nothing persists, including the
-- blocks marked READ-ONLY (those open BEGIN READ ONLY). Order: section A, apply the KAN-497
-- migrations if the database does not have them, apply the KAN-499 migration, section B; section C
-- only after rollback.sql.
--
-- Every post-apply assertion is expected to FAIL when run BEFORE the migration is applied: that
-- is the proof the probe can fail. A probe nobody has seen fail is not evidence.
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads and SELECTs only (BEGIN READ ONLY)
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK (rpc_block_user, the carry-over INSERT)
--
-- ROLE CAVEAT: the probes that matter use SET LOCAL ROLE anon / authenticated / service_role
-- with request.jwt.claims set. Run as postgres they pass vacuously. Blocks that need two users take
-- them from public.profiles (active, no block between them) and stop with SETUP FAIL if there are none.

-- ===========================================================================
-- A. PRE-APPLY -- run BEFORE the KAN-499 migration
-- ===========================================================================

-- A1 [READ-ONLY] both overloads and their grants, BEFORE. Save the output: rollback.sql restores
--    exactly this. Expect two rows; the 2-argument one is executable by authenticated.
begin read only;
select p.oid::regprocedure as signature, p.prosecdef as security_definer, p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('rpc_block_user', 'rpc_unblock_user')
 order by 1;
rollback;

-- A2 [READ-ONLY] which store each overload writes (diff against the baseline bodies; stop on a
--    surprise). Expect: the 1-argument form mentions user_blocks and not restrictions; the
--    2-argument form mentions restrictions and not user_blocks.
begin read only;
select p.oid::regprocedure as signature,
       p.prosrc ilike '%user_blocks%'  as writes_user_blocks,
       p.prosrc ilike '%restrictions%' as writes_restrictions
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'rpc_block_user'
 order by 1;
rollback;

-- A3 [READ-ONLY] dependents and callers of the 2-argument overload. EXPECT NO ROW from the dependency,
--    view and policy queries and from the "function body: real call" query. The last query lists TEXT
--    MATCHES separately (a name inside a string literal, such as the 'use_rpc_block_user' error message of
--    rpc_restrict_set from KAN-522): a text match is reported, it is not a caller and does not fail the probe.
begin read only;
select 'pg_depend' as via, d.classid::regclass::text as dependent_catalog, d.objid
  from pg_depend d
 where d.refclassid = 'pg_proc'::regclass
   and d.refobjid = 'public.rpc_block_user(uuid, boolean)'::regprocedure
   and d.deptype = 'n';
-- real call syntax only: the name followed by "(" , not inside a quoted literal such as 'use_rpc_block_user'
select 'function body: real call' as via, p.oid::regprocedure as caller
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname not in ('pg_catalog', 'information_schema')
   and p.prosrc ~* '(^|[^_a-z0-9''])rpc_block_user\s*\('
   and p.oid <> 'public.rpc_block_user(uuid, boolean)'::regprocedure
   and p.oid <> 'public.rpc_block_user(uuid)'::regprocedure;
select 'view' as via, c.oid::regclass as caller
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relkind in ('v', 'm') and n.nspname not in ('pg_catalog', 'information_schema')
   and pg_get_viewdef(c.oid) ilike '%rpc_block_user%';
select 'policy' as via, (schemaname || '.' || tablename || ' ' || policyname) as caller
  from pg_policies
 where coalesce(qual, '') ilike '%rpc_block_user%' or coalesce(with_check, '') ilike '%rpc_block_user%';
-- text matches, reported separately (live 2026-10-14: exactly one, rpc_restrict_set(uuid,text), error-message literal)
select 'function body: text match only' as via, p.oid::regprocedure as caller,
       (p.prosrc ~* '(^|[^_a-z0-9''])rpc_block_user\s*\(') as has_call_syntax
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname not in ('pg_catalog', 'information_schema')
   and p.prosrc ilike '%rpc_block_user%'
   and p.oid <> 'public.rpc_block_user(uuid, boolean)'::regprocedure
   and p.oid <> 'public.rpc_block_user(uuid)'::regprocedure;
rollback;

-- A4 [READ-ONLY] the two stores BEFORE, and the number of rows the migration will carry. Save the
--    numbers: B6 compares. Live evidence (KAN-496 E2, 2026-10-13): user_blocks 3, restrictions 0.
begin read only;
select (select count(*) from public.user_blocks)                              as user_blocks_rows,
       (select count(*) from public.restrictions)                             as restrictions_rows,
       (select count(*) from public.restrictions where type = 'blocked')      as restrictions_blocked_rows,
       (select count(*) from public.restrictions r
         where r.type = 'blocked'
           and not exists (select 1 from public.user_blocks b
                            where b.blocker_user_id = r.user_id and b.blocked_user_id = r.target_user_id))
                                                                              as rows_the_migration_will_carry,
       (select count(*) from public.app_admins)                               as admins_notified_per_carried_row;
rollback;

-- A5 [WRITE-IN-TRANSACTION-ROLLBACK] BEFORE behaviour: as authenticated, the 2-argument call writes
--    restrictions and fires NO admin notification; the 1-argument call writes user_blocks and does.
--    (This block is expected to PASS before the migration and to FAIL its first call after it.)
begin;
do $$
declare a uuid; b uuid; n0 int; n1 int; r0 int; r1 int; u0 int; u1 int;
begin
  select p.user_id into a from public.profiles p where p.is_active order by p.created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block between them'; end if;
  perform set_config('k499.a', a::text, true);
  perform set_config('k499.b', b::text, true);
  select count(*) into n0 from public.notifications where kind_key = 'moderation.user_blocked';
  select count(*) into r0 from public.restrictions;
  select count(*) into u0 from public.user_blocks;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b, true);
  reset role;
  select count(*) into r1 from public.restrictions;
  select count(*) into u1 from public.user_blocks;
  select count(*) into n1 from public.notifications where kind_key = 'moderation.user_blocked';
  if r1 <> r0 + 1 or u1 <> u0 or n1 <> n0 then raise exception 'A5 FAIL: 2-arg call did not behave as the baseline (restrictions %->%, user_blocks %->%, notifications %->%)', r0, r1, u0, u1, n0, n1; end if;
  raise notice 'A5 PASS (before): the 2-argument overload writes restrictions only and fires no admin notification';
end $$;
rollback;

-- ===========================================================================
-- B. POST-APPLY -- run AFTER 20261013120000_kan499_collapse_rpc_block_user_overload.sql
-- ===========================================================================

-- B1 [READ-ONLY] AC2: there is exactly one callable rpc_block_user, the 1-argument form; the
--    renamed function exists with the same argument list; nothing was dropped.
begin read only;
select (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'rpc_block_user')                        as rpc_block_user_overloads,   -- 1
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'rpc_block_user'
           and p.pronargs = 2)                                                               as two_arg_overloads_left,      -- 0
       to_regprocedure('public.rpc_block_user(uuid)') is not null                            as one_arg_present,             -- true
       to_regprocedure('public.rpc_block_user_legacy_v1(uuid, boolean)') is not null         as legacy_present,              -- true
       to_regprocedure('public.rpc_unblock_user(uuid)') is not null                          as unblock_present,             -- true
       to_regclass('public.restrictions') is not null                                        as restrictions_table_kept;     -- true
rollback;

-- B2 [READ-ONLY] AC2: the legacy function is NOT executable by anon, authenticated or the PUBLIC
--    pseudo-role (grantee 0); service_role keeps EXECUTE.
begin read only;
select p.oid::regprocedure as signature,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,       -- false
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,       -- false
       has_function_privilege('public', p.oid, 'EXECUTE')        as public_exec,     -- false
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,  -- 0
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,    -- true
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'rpc_block_user_legacy_v1';
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] AC2: a call that names p_block no longer resolves (undefined
--    function) for authenticated and for anon, positionally and by name; the legacy name is refused
--    (insufficient privilege) for both. Nothing is written, so the counts must not move.
begin;
do $$
declare a uuid; b uuid; e text; r0 int; r1 int;
begin
  select p.user_id into a from public.profiles p where p.is_active order by p.created_at limit 1;
  select p.user_id into b from public.profiles p where p.is_active and p.user_id <> a order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users'; end if;
  select count(*) into r0 from public.restrictions;
  -- authenticated, positional
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_block_user(b, true); e := 'RESOLVED';
  exception when undefined_function then e := 'undefined_function'; when others then e := sqlstate; end;
  reset role;
  if e <> 'undefined_function' then raise exception 'B3 FAIL: authenticated rpc_block_user(uuid, boolean) gave %', e; end if;
  -- authenticated, by name
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_block_user(p_peer => b, p_block => true); e := 'RESOLVED';
  exception when undefined_function then e := 'undefined_function'; when others then e := sqlstate; end;
  reset role;
  if e <> 'undefined_function' then raise exception 'B3 FAIL: authenticated named p_block gave %', e; end if;
  -- anon, positional
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.rpc_block_user(b, true); e := 'RESOLVED';
  exception when undefined_function then e := 'undefined_function'; when others then e := sqlstate; end;
  reset role;
  if e <> 'undefined_function' then raise exception 'B3 FAIL: anon rpc_block_user(uuid, boolean) gave %', e; end if;
  -- the legacy name: refused for authenticated and anon
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.rpc_block_user_legacy_v1(b, true); e := 'EXECUTED';
  exception when insufficient_privilege then e := 'insufficient_privilege'; when others then e := sqlstate; end;
  reset role;
  if e <> 'insufficient_privilege' then raise exception 'B3 FAIL: authenticated legacy call gave %', e; end if;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.rpc_block_user_legacy_v1(b, true); e := 'EXECUTED';
  exception when insufficient_privilege then e := 'insufficient_privilege'; when others then e := sqlstate; end;
  reset role;
  if e <> 'insufficient_privilege' then raise exception 'B3 FAIL: anon legacy call gave %', e; end if;
  select count(*) into r1 from public.restrictions;
  if r1 <> r0 then raise exception 'B3 FAIL: restrictions changed (% -> %)', r0, r1; end if;
  raise notice 'B3 PASS';
end $$;
rollback;

-- B4 [WRITE-IN-TRANSACTION-ROLLBACK] AC3/AC5: as authenticated, block and unblock through the
--    1-argument form still work: block writes user_blocks (one row), writes NOTHING to restrictions,
--    fires trg_notify_admins_of_block (a notification row for the fixture admin), unblock removes the row.
--    Fixtures (all rolled back): three distinct active users: a (blocker), b (blocked), adm (a test admin
--    row inserted into app_admins inside this transaction). Setup FAILS if the fixtures cannot be built, so
--    the trigger assertion is never skipped.
begin;
do $$
declare a uuid; b uuid; adm uuid; u0 int; u1 int; u2 int; r0 int; r1 int; n0 int; n1 int; admins int;
begin
  select p.user_id into a from public.profiles p where p.is_active order by p.created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into adm from public.profiles p
   where p.is_active and p.user_id not in (a, b) order by p.created_at limit 1;
  if a is null or b is null or adm is null then
    raise exception 'SETUP FAIL: need three distinct active users (blocker, blocked, admin fixture), a and b with no block between them';
  end if;
  insert into public.app_admins (user_id) select adm where not exists (select 1 from public.app_admins where user_id = adm);
  select count(*) into admins from public.app_admins;
  if admins < 1 or not exists (select 1 from public.app_admins where user_id = adm) then
    raise exception 'SETUP FAIL: the admin fixture was not created';
  end if;
  select count(*) into u0 from public.user_blocks;
  select count(*) into r0 from public.restrictions;
  select count(*) into n0 from public.notifications where kind_key = 'moderation.user_blocked' and to_user_id = adm;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  reset role;
  select count(*) into u1 from public.user_blocks;
  select count(*) into r1 from public.restrictions;
  select count(*) into n1 from public.notifications where kind_key = 'moderation.user_blocked' and to_user_id = adm;
  if u1 <> u0 + 1 then raise exception 'B4 FAIL: block did not write one user_blocks row (% -> %)', u0, u1; end if;
  if r1 <> r0 then raise exception 'B4 FAIL: block wrote restrictions (% -> %)', r0, r1; end if;
  if n1 <> n0 + 1 then raise exception 'B4 FAIL: trg_notify_admins_of_block did not notify the admin fixture (% -> %)', n0, n1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_unblock_user(b);
  reset role;
  select count(*) into u2 from public.user_blocks;
  if u2 <> u0 then raise exception 'B4 FAIL: unblock left % rows (expected %)', u2, u0; end if;
  raise notice 'B4 PASS (block wrote user_blocks only, the admin fixture was notified, unblock removed the row)';
end $$;
rollback;

-- B5 [WRITE-IN-TRANSACTION-ROLLBACK] AC3: the carry-over. A restrictions 'blocked' row is copied
--    into user_blocks by the migration's INSERT (the statement text below is copied from the
--    migration), a second run adds nothing (ON CONFLICT DO NOTHING), and restrictions is not
--    written by the carry-over. The setup row is written inside this rolled-back transaction.
begin;
do $$
declare a uuid; b uuid; u0 int; u1 int; u2 int; r0 int; r1 int; r2 int;
begin
  select p.user_id into a from public.profiles p where p.is_active order by p.created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  if a is null or b is null then raise exception 'SETUP FAIL: need two active users with no block between them'; end if;
  insert into public.restrictions (user_id, target_user_id, type) values (a, b, 'blocked');  -- test setup, rolled back
  select count(*) into u0 from public.user_blocks;
  select count(*) into r0 from public.restrictions;
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  SELECT r.user_id, r.target_user_id
  FROM public.restrictions r
  WHERE r.type = 'blocked'
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  select count(*) into u1 from public.user_blocks;
  select count(*) into r1 from public.restrictions;
  if not exists (select 1 from public.user_blocks where blocker_user_id = a and blocked_user_id = b) then
    raise exception 'B5 FAIL: the blocked row was not carried into user_blocks'; end if;
  if r1 <> r0 then raise exception 'B5 FAIL: the carry-over changed restrictions (% -> %)', r0, r1; end if;
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  SELECT r.user_id, r.target_user_id
  FROM public.restrictions r
  WHERE r.type = 'blocked'
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  select count(*) into u2 from public.user_blocks;
  select count(*) into r2 from public.restrictions;
  if u2 <> u1 then raise exception 'B5 FAIL: a second run added rows (% -> %)', u1, u2; end if;
  if r2 <> r1 then raise exception 'B5 FAIL: the second run changed restrictions'; end if;
  raise notice 'B5 PASS (user_blocks % -> % -> %, restrictions % constant)', u0, u1, u2, r0;
end $$;
rollback;

-- B6 [READ-ONLY] AC3: the stores AFTER. Compare with A4: restrictions_rows and
--    restrictions_blocked_rows are UNCHANGED (the migration never writes restrictions);
--    user_blocks_rows grew by exactly rows_the_migration_will_carry from A4; the carry query now
--    finds nothing left to carry.
begin read only;
select (select count(*) from public.user_blocks)                              as user_blocks_rows,
       (select count(*) from public.restrictions)                             as restrictions_rows,
       (select count(*) from public.restrictions where type = 'blocked')      as restrictions_blocked_rows,
       (select count(*) from public.restrictions r
         where r.type = 'blocked'
           and not exists (select 1 from public.user_blocks b
                            where b.blocker_user_id = r.user_id and b.blocked_user_id = r.target_user_id))
                                                                              as rows_still_to_carry;  -- 0
rollback;

-- B7 [READ-ONLY] AC2/AC3: the 1-argument rpc_block_user and rpc_unblock_user kept their body and
--    ACL: diff the rows with the A1 output (same signature, security_definer, proacl, exec flags).
begin read only;
select p.oid::regprocedure as signature, p.prosecdef as security_definer, p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl, md5(p.prosrc) as body_md5
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('rpc_block_user', 'rpc_unblock_user')
 order by 1;
rollback;

-- ===========================================================================
-- C. POST-ROLLBACK -- run AFTER rollback.sql (itself an apply that needs the CEO's approval)
-- ===========================================================================

-- C1 [READ-ONLY] the 2-argument overload is back with the A1 ACL, the legacy name is gone, and
--    carried user_blocks rows are still there (rollback does not remove them).
begin read only;
select to_regprocedure('public.rpc_block_user(uuid, boolean)') is not null        as two_arg_restored,   -- true
       to_regprocedure('public.rpc_block_user_legacy_v1(uuid, boolean)') is null  as legacy_name_gone,   -- true
       has_function_privilege('authenticated', 'public.rpc_block_user(uuid, boolean)'::regprocedure, 'EXECUTE') as auth_exec,
       has_function_privilege('anon', 'public.rpc_block_user(uuid, boolean)'::regprocedure, 'EXECUTE')          as anon_exec;
rollback;
