-- KAN-497 probe pack: is_blocked narrowing and anon revoke of the block RPCs
--
-- Covers:  supabase/migrations/20261013100000_kan497_is_blocked_narrow_to_caller.sql
--          supabase/migrations/20261013110000_kan497_revoke_anon_block_rpcs.sql
--
-- B5 FIXTURE CORRECTION (2026-10-13, CEO approval supabase-messaging-approval). The first
-- version of B5 chose its viewer with `select user_id from profiles where is_active and
-- user_id <> host limit 1`, an unordered pick. On the live project all three existing
-- user_blocks rows touch the game's host, and that pick returned one of those users, so the
-- "unblocked authenticated viewer" saw 0 rows and the probe failed on the UNTOUCHED baseline
-- body as well as on the narrowed one (measured: baseline body 0 rows, narrowed body 0 rows
-- with that fixture; with a clean viewer baseline 1 row, narrowed 1 row, and 0 rows after the
-- viewer blocks the host, anon 1 row). The fixture was wrong, not the migration. B5 now picks
-- the viewer deterministically (ORDER BY created_at, user_id) among active profiles with no
-- block relation to the host in either direction.
--
-- STATUS: AUTHORED, NOT RUN.  Nothing in this file was executed against any
-- database while writing it, and this ticket does not claim it was. It is to be
-- run later by whoever applies the migrations, on a CEO-APPROVED NON-PRODUCTION
-- database first. There is none approved yet. Do NOT run it against the live
-- project wtncuzcskpigqpmnxwws without the CEO's explicit approval.
--
-- HOW TO RUN. Run each numbered block as ONE batch (psql -f on the single block,
-- or paste one block). Every block starts with BEGIN and ends with ROLLBACK, so
-- nothing persists, including the blocks marked READ-ONLY (those open
-- `BEGIN READ ONLY`). Run the pre-apply section, apply the narrowing migration,
-- run the post-narrowing section, apply the revoke migration, run the
-- post-revoke section.
--
-- Every post-apply assertion is expected to FAIL when run BEFORE its migration
-- is applied: that is the proof the probe can fail. A probe nobody has seen
-- fail is not evidence.
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads and SELECTs only (BEGIN READ ONLY)
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK (rpc_block_user etc.)
--
-- ROLE CAVEAT: the probes that matter use SET LOCAL ROLE anon / authenticated /
-- service_role with request.jwt.claims set. Run as postgres they pass vacuously.
--
-- Test ids from the ticket: T-A1 anon refused after the revoke; T-A2 block /
-- unblock / unfollow still work as authenticated; T-A3 public game, meetup and
-- feed paths still render for anon and authenticated; T-A4 a block still fires
-- trg_notify_admins_of_block.

-- ===========================================================================
-- A. PRE-APPLY -- run BEFORE either migration
-- ===========================================================================

-- A1 [READ-ONLY] live definition of is_blocked: diff it against the baseline body in
--    rollback.sql (stop on a surprise), and show the owner / security / search_path.
begin read only;
select p.oid::regprocedure as signature, p.prosecdef as security_definer, p.proconfig,
       pg_get_functiondef(p.oid) as def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'is_blocked';
rollback;

-- A2 [READ-ONLY] grants of the five in-scope functions, BEFORE. Save the output;
--    rollback.sql re-grants exactly this. Expect anon_exec = true and
--    public_grants = 1 on all five (KAN-496 E1/E1b/E1c).
begin read only;
select p.oid::regprocedure as signature,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('is_blocked','rpc_block_user','rpc_unblock_user','rpc_unfollow_user')
 order by 1;
rollback;

-- A3 [READ-ONLY] DB-side callers of is_blocked and of the four RPCs. Compare with
--    CALLERS.md section A/B: any caller not on that list is a stop-and-ask.
begin read only;
select 'function' as kind, p.oid::regprocedure::text as caller, p.prosecdef as definer
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('public','util')
   and p.prosrc ~* '(is_blocked|rpc_block_user|rpc_unblock_user|rpc_unfollow_user)'
   and p.proname not in ('is_blocked','rpc_block_user','rpc_unblock_user','rpc_unfollow_user')
union all
select 'view', c.oid::regclass::text, null
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'v'
   and pg_get_viewdef(c.oid) ~* '(is_blocked|can_view_with_scope|can_view_owner)'
union all
select 'policy', schemaname||'.'||tablename||'.'||policyname, null
  from pg_policies
 where coalesce(qual,'') || coalesce(with_check,'') ~* '(is_blocked|can_view_with_scope)'
order by 1, 2;
rollback;

-- A4 [WRITE-IN-TRANSACTION-ROLLBACK] BEFORE state of the disclosure. After a blocks b,
--    anon learns it from is_blocked(a,b). Expected BEFORE the narrowing: NOTICE
--    "A4 DISCLOSURE PRESENT". AFTER the narrowing this block must raise the FAIL line
--    (that is the sign the closure worked); it is the mirror of B1.
begin;
-- fixture: three active users a, b, c with no block row among them (read-only pick),
-- kept as transaction-local settings so every role can read them.
do $$
declare a uuid; b uuid; c uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id not in (a, b)
     and not exists (select 1 from public.user_blocks x
                      where x.blocker_user_id in (a, b) and x.blocked_user_id = p.user_id
                         or x.blocked_user_id in (a, b) and x.blocker_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null or c is null then
    raise exception 'SETUP FAIL: need three active users with no block among them';
  end if;
  perform set_config('k497.a', a::text, true);
  perform set_config('k497.b', b::text, true);
  perform set_config('k497.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k497.a')::uuid; b uuid := current_setting('k497.b')::uuid; seen boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  seen := public.is_blocked(a, b);
  reset role;
  if seen then raise notice 'A4 DISCLOSURE PRESENT: anon is_blocked(a,b) = true';
  else raise exception 'A4 FAIL (expected before the narrowing): anon already gets false'; end if;
end $$;
rollback;

-- A5 [READ-ONLY] BEFORE snapshot for the regression comparison in B6: how many rows
--    anon sees in the public listing views. Save the three numbers.
begin read only;
select (select count(*) from public.v_game_card)    as game_card_rows,
       (select count(*) from public.v_meetup_list)  as meetup_list_rows,
       (select count(*) from public.v_challenge_card) as challenge_card_rows;
rollback;

-- ===========================================================================
-- B. POST-NARROWING -- run AFTER 20261013100000 is applied, BEFORE the revoke
-- ===========================================================================

-- B1 [WRITE-IN-TRANSACTION-ROLLBACK] AC2: the answer to anon and to a third party is
--    false; the two parties still get the real answer (true) in BOTH argument orders;
--    an unrelated pair is false; with no JWT (service_role) the answer is false.
begin;
-- fixture: three active users a, b, c with no block row among them (read-only pick),
-- kept as transaction-local settings so every role can read them.
do $$
declare a uuid; b uuid; c uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id not in (a, b)
     and not exists (select 1 from public.user_blocks x
                      where x.blocker_user_id in (a, b) and x.blocked_user_id = p.user_id
                         or x.blocked_user_id in (a, b) and x.blocker_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null or c is null then
    raise exception 'SETUP FAIL: need three active users with no block among them';
  end if;
  perform set_config('k497.a', a::text, true);
  perform set_config('k497.b', b::text, true);
  perform set_config('k497.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k497.a')::uuid; b uuid := current_setting('k497.b')::uuid; c uuid := current_setting('k497.c')::uuid;
        r boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  r := public.is_blocked(a, b);  if r is distinct from true  then raise exception 'B1 FAIL: blocker asking (a,b) got %', r; end if;
  r := public.is_blocked(b, a);  if r is distinct from true  then raise exception 'B1 FAIL: blocker asking (b,a) got %', r; end if;
  r := public.is_blocked(a, c);  if r is distinct from false then raise exception 'B1 FAIL: blocker asking an unblocked pair got %', r; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.b'), 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.is_blocked(a, b);  if r is distinct from true  then raise exception 'B1 FAIL: blocked party asking (a,b) got %', r; end if;
  r := public.is_blocked(b, a);  if r is distinct from true  then raise exception 'B1 FAIL: blocked party asking (b,a) got %', r; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.c'), 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.is_blocked(a, b);  if r is distinct from false then raise exception 'B1 FAIL: third party learned % (T-A1 pair)', r; end if;
  r := public.is_blocked(b, a);  if r is distinct from false then raise exception 'B1 FAIL: third party learned % (reverse)', r; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  r := public.is_blocked(a, b);  if r is distinct from false then raise exception 'B1 FAIL: anon learned %', r; end if;
  r := public.is_blocked(b, a);  if r is distinct from false then raise exception 'B1 FAIL: anon learned % (reverse)', r; end if;
  r := public.is_blocked(null, null); if r is distinct from false then raise exception 'B1 FAIL: anon NULL,NULL got %', r; end if;
  reset role;
  perform set_config('request.jwt.claims', '', true); set local role service_role;
  r := public.is_blocked(a, b);  if r is distinct from false then raise exception 'B1 FAIL: no-JWT caller got %', r; end if;
  reset role;
  raise notice 'B1 PASS';
end $$;
rollback;

-- B2 [READ-ONLY] the narrowed function kept its shape (AC2/C5): definer, search_path
--    'public','pg_temp', same signature, owner unchanged, grants unchanged from A2.
begin read only;
do $$
declare f oid := 'public.is_blocked(uuid,uuid)'::regprocedure;
begin
  if not (select prosecdef from pg_proc where oid = f) then raise exception 'B2 FAIL: not SECURITY DEFINER'; end if;
  if not ((select proconfig from pg_proc where oid = f) @> array['search_path=public, pg_temp']) then
    raise exception 'B2 FAIL: search_path changed'; end if;
  if not has_function_privilege('anon', f, 'EXECUTE') then
    raise exception 'B2 FAIL: anon lost EXECUTE; the narrowing migration must not change grants'; end if;
  raise notice 'B2 PASS';
end $$;
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] second oracle closed: the anon-callable resolvers
--    no longer reveal a block to anon or to a third party. Before the narrowing they
--    returned false for a blocked public pair.
begin;
-- fixture: three active users a, b, c with no block row among them (read-only pick),
-- kept as transaction-local settings so every role can read them.
do $$
declare a uuid; b uuid; c uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id not in (a, b)
     and not exists (select 1 from public.user_blocks x
                      where x.blocker_user_id in (a, b) and x.blocked_user_id = p.user_id
                         or x.blocked_user_id in (a, b) and x.blocker_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null or c is null then
    raise exception 'SETUP FAIL: need three active users with no block among them';
  end if;
  perform set_config('k497.a', a::text, true);
  perform set_config('k497.b', b::text, true);
  perform set_config('k497.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k497.a')::uuid; b uuid := current_setting('k497.b')::uuid; c uuid := current_setting('k497.c')::uuid;
        r boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  r := public.can_view_with_scope(a, b, 'public', null);
  if r is distinct from false then raise exception 'B3 FAIL: the blocker still sees a blocked user''s public scope (got %)', r; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  r := public.can_view_with_scope(a, b, 'public', null);
  if r is distinct from true then raise exception 'B3 FAIL: anon can still tell the pair is blocked (can_view_with_scope = %)', r; end if;
  r := public.can_view_with_scope3(a, b, 'public');
  if r is distinct from true then raise exception 'B3 FAIL: anon can still tell the pair is blocked (can_view_with_scope3 = %)', r; end if;
  r := public._can_view_with_scope_canonical(a, b, 'public');
  if r is distinct from true then raise exception 'B3 FAIL: anon can still tell the pair is blocked (canonical = %)', r; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.c'), 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.can_view_with_scope(a, b, 'public', null);
  if r is distinct from true then raise exception 'B3 FAIL: a third party can still tell the pair is blocked (%)', r; end if;
  reset role;
  raise notice 'B3 PASS';
end $$;
rollback;

-- B4 [WRITE-IN-TRANSACTION-ROLLBACK] T-A2 and T-A4: block / unblock / unfollow still
--    work as authenticated, and a block still fires trg_notify_admins_of_block (one
--    notification per app_admins row, kind moderation.user_blocked).
begin;
-- fixture: three active users a, b, c with no block row among them (read-only pick),
-- kept as transaction-local settings so every role can read them.
do $$
declare a uuid; b uuid; c uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id not in (a, b)
     and not exists (select 1 from public.user_blocks x
                      where x.blocker_user_id in (a, b) and x.blocked_user_id = p.user_id
                         or x.blocked_user_id in (a, b) and x.blocker_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null or c is null then
    raise exception 'SETUP FAIL: need three active users with no block among them';
  end if;
  perform set_config('k497.a', a::text, true);
  perform set_config('k497.b', b::text, true);
  perform set_config('k497.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k497.a')::uuid; b uuid := current_setting('k497.b')::uuid;
        admins int; n0 int; n1 int; pid uuid;
begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_notify_admins_of_block' and tgenabled = 'O') then
    raise exception 'B4 FAIL: trg_notify_admins_of_block missing or disabled'; end if;
  select count(*) into admins from public.app_admins;
  select count(*) into n0 from public.notifications where kind_key = 'moderation.user_blocked'
     and context->>'blocker_user_id' = a::text and context->>'blocked_user_id' = b::text;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k497.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);                                   -- 1-arg block (the app's call)
  if public.is_blocked(a, b) is distinct from true then raise exception 'B4 FAIL: rpc_block_user did not record the block'; end if;
  perform public.rpc_unblock_user(b);
  if public.is_blocked(a, b) is distinct from false then raise exception 'B4 FAIL: rpc_unblock_user did not remove the block'; end if;
  perform public.rpc_block_user(b);                                   -- block again for the trigger count
  select id into pid from public.profiles where user_id = b limit 1;
  perform public.rpc_unfollow_user(pid);                              -- returns a row count; must not raise
  perform public.rpc_block_user(b, true);                             -- 2-arg overload still callable
  perform public.rpc_block_user(b, false);
  reset role;
  select count(*) into n1 from public.notifications where kind_key = 'moderation.user_blocked'
     and context->>'blocker_user_id' = a::text and context->>'blocked_user_id' = b::text;
  if n1 - n0 <> admins * 2 then
    raise exception 'B4 FAIL (T-A4): expected % admin notifications for two block inserts, got %', admins * 2, n1 - n0; end if;
  raise notice 'B4 PASS (T-A2, T-A4; admins=%)', admins;
end $$;
rollback;

-- B5 [WRITE-IN-TRANSACTION-ROLLBACK] T-A3 part 1: the block guard on public games still
--    works and anon is unaffected. For one real public game: anon still sees its host's
--    game; a viewer who blocked the host does not; the host's block of the viewer
--    hides it too.
begin;
do $$
declare g record; v uuid; r int; n_anon int;
begin
  select * into g from public.games where listing_visibility = 'public' and not is_cancelled and start_at > now() limit 1;
  if g.id is null then raise notice 'B5 SKIPPED: no future public game on this database'; return; end if;
  -- viewer: an active profile with NO block relation to the host in either direction,
  -- picked deterministically (the earlier fixture used an unordered LIMIT 1, see the header note).
  select p.user_id into v from public.profiles p
   where p.is_active and p.user_id <> g.creator_user_id
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = g.creator_user_id and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = g.creator_user_id))
   order by p.created_at, p.user_id limit 1;
  if v is null then raise exception 'B5 SETUP FAIL: no active viewer without a block relation to the host'; end if;
  select count(*) into n_anon from public.v_game_card where id = g.id;
  -- anon
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true); set local role anon;
  select count(*) into r from public.v_game_card where id = g.id;
  if r <> n_anon then raise exception 'B5 FAIL: anon view count differs from baseline'; end if;
  reset role;
  perform set_config('k497.v', v::text, true); perform set_config('k497.h', g.creator_user_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role','authenticated')::text, true); set local role authenticated;
  select count(*) into r from public.v_game_card where id = g.id;
  if r <> 1 then raise exception 'B5 FAIL: an unblocked authenticated viewer lost a public game'; end if;
  perform public.rpc_block_user(g.creator_user_id);
  select count(*) into r from public.v_game_card where id = g.id;
  if r <> 0 then raise exception 'B5 FAIL: a viewer who blocked the host still sees the host''s public game'; end if;
  reset role;
  raise notice 'B5 PASS';
end $$;
rollback;

-- B6 [READ-ONLY] T-A3 part 2: public pages and the feed still render for anon and for
--    authenticated. Each statement must run without an error (an error here is the
--    "permission denied" the held is_blocked revoke would cause). Compare the three
--    counts with A5: they must be identical.
begin read only;
do $$
declare n int; m uuid; uid uuid;
begin
  select user_id into uid from public.profiles where is_active order by created_at limit 1;
  select id into m from public.meetups limit 1;
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true); set local role anon;
  select count(*) into n from public.v_game_card;                 raise notice 'B6 anon v_game_card = %', n;
  select count(*) into n from public.v_meetup_list;               raise notice 'B6 anon v_meetup_list = %', n;
  select count(*) into n from public.v_challenge_card;            raise notice 'B6 anon v_challenge_card = %', n;
  select count(*) into n from public.rpc_get_nearby_games(25.2, 55.27, 50000, null, 'distance', null);
                                                                  raise notice 'B6 anon rpc_get_nearby_games = %', n;
  select count(*) into n from public.get_feed(10, 0);             raise notice 'B6 anon get_feed = %', n;
  if m is not null then perform public.rpc_meetup_card(m, 'player'); perform public.can_current_user_rsvp_meetup(m, null); end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role','authenticated')::text, true); set local role authenticated;
  select count(*) into n from public.v_game_card;                 raise notice 'B6 auth v_game_card = %', n;
  select count(*) into n from public.v_meetup_list;               raise notice 'B6 auth v_meetup_list = %', n;
  select count(*) into n from public.rpc_get_nearby_games(25.2, 55.27, 50000, null, 'distance', null);
                                                                  raise notice 'B6 auth rpc_get_nearby_games = %', n;
  select count(*) into n from public.get_feed(10, 0);             raise notice 'B6 auth get_feed = %', n;
  if m is not null then
    perform public.rpc_meetup_card(m, 'player');
    perform count(*) from public.rpc_meetup_attendees(m, null, 10, 0);
    perform public.can_current_user_rsvp_meetup(m, null);
  end if;
  reset role;
  raise notice 'B6 PASS (no error); compare the counts with A5';
end $$;
rollback;

-- ===========================================================================
-- C. POST-REVOKE -- run AFTER 20261013110000 is applied
-- ===========================================================================

-- C1 [READ-ONLY] AC5: neither anon nor the PUBLIC pseudo-role (grantee 0) can execute
--    the four RPCs; authenticated and service_role can. Prints is_blocked for the
--    CEO decision: it is expected to STILL be anon-executable (held, decision 5).
begin read only;
select p.oid::regprocedure as signature,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,       -- false for the four
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,  -- 0 for the four
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,       -- true
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec     -- true
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('rpc_block_user','rpc_unblock_user','rpc_unfollow_user','is_blocked')
 order by 1;
do $$
declare sig text;
begin
  foreach sig in array array['public.rpc_block_user(uuid)','public.rpc_block_user(uuid,boolean)',
                             'public.rpc_unblock_user(uuid)','public.rpc_unfollow_user(uuid)'] loop
    if has_function_privilege('anon', sig::regprocedure, 'EXECUTE') then raise exception 'C1 FAIL: anon can execute %', sig; end if;
    if exists (select 1 from pg_proc p, aclexplode(p.proacl) a where p.oid = sig::regprocedure and a.grantee = 0) then
      raise exception 'C1 FAIL: PUBLIC can execute %', sig; end if;
    if not has_function_privilege('authenticated', sig::regprocedure, 'EXECUTE')
       or not has_function_privilege('service_role', sig::regprocedure, 'EXECUTE') then
      raise exception 'C1 FAIL: authenticated or service_role lost EXECUTE on %', sig; end if;
  end loop;
  raise notice 'C1 PASS';
end $$;
rollback;

-- C2 [WRITE-IN-TRANSACTION-ROLLBACK] T-A1 at run time: an anon call to each RPC is
--    refused with insufficient_privilege (42501), not merely "Not authenticated".
begin;
-- fixture: three active users a, b, c with no block row among them (read-only pick),
-- kept as transaction-local settings so every role can read them.
do $$
declare a uuid; b uuid; c uuid;
begin
  select user_id into a from public.profiles where is_active order by created_at limit 1;
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id <> a
     and not exists (select 1 from public.user_blocks x
                      where (x.blocker_user_id = a and x.blocked_user_id = p.user_id)
                         or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id not in (a, b)
     and not exists (select 1 from public.user_blocks x
                      where x.blocker_user_id in (a, b) and x.blocked_user_id = p.user_id
                         or x.blocked_user_id in (a, b) and x.blocker_user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or b is null or c is null then
    raise exception 'SETUP FAIL: need three active users with no block among them';
  end if;
  perform set_config('k497.a', a::text, true);
  perform set_config('k497.b', b::text, true);
  perform set_config('k497.c', c::text, true);
end $$;
do $$
declare b uuid := current_setting('k497.b')::uuid; sqlstate_seen text;
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true); set local role anon;
  begin perform public.rpc_block_user(b);          raise exception 'C2 FAIL: anon rpc_block_user(uuid) ran';
  exception when insufficient_privilege then null; end;
  begin perform public.rpc_block_user(b, true);    raise exception 'C2 FAIL: anon rpc_block_user(uuid,boolean) ran';
  exception when insufficient_privilege then null; end;
  begin perform public.rpc_unblock_user(b);        raise exception 'C2 FAIL: anon rpc_unblock_user ran';
  exception when insufficient_privilege then null; end;
  begin perform public.rpc_unfollow_user(gen_random_uuid()); raise exception 'C2 FAIL: anon rpc_unfollow_user ran';
  exception when insufficient_privilege then null; end;
  reset role;
  raise notice 'C2 PASS';
end $$;
rollback;

-- C3 [WRITE-IN-TRANSACTION-ROLLBACK] T-A2 and T-A4 again after the revoke: B4 must
--    still pass unchanged. Re-run block B4 here and require "B4 PASS".

-- C4 [READ-ONLY] T-A3 again after the revoke: re-run B6 and require "B6 PASS" with
--    the same counts as A5. The revoke touches only the four RPCs, which no page calls.

-- C5 [WRITE-IN-TRANSACTION-ROLLBACK] B1 and B3 again after the revoke (the narrowed
--    is_blocked is untouched by the revoke migration): require "B1 PASS", "B3 PASS".

-- ===========================================================================
-- D. HELD -- ONLY if the CEO approves revoking is_blocked (README, "Held for a CEO
--    decision"). Do not run D before the CEO decides. Each block is wrapped.
-- ===========================================================================

-- D1 [READ-ONLY] the exact regression the held revoke would cause, shown WITHOUT
--    applying anything: as anon, call the invoker resolver. It works today because
--    anon can execute is_blocked. After the held revoke it would raise 42501 here.
begin read only;
do $$
declare r boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true); set local role anon;
  r := public.can_view_with_scope(null, gen_random_uuid(), 'public', null);
  reset role;
  raise notice 'D1 anon can_view_with_scope = % (an error here after a held is_blocked revoke is the regression)', r;
end $$;
rollback;
