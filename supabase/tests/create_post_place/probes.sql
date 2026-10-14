-- KAN-524 probe pack: create_post keeps the place
--
-- Covers: supabase/migrations/20261013150000_create_post_keeps_place.sql
--
-- STATUS: AUTHORED, NOT RUN. Nothing in this file was executed against any database while writing it, and
-- this ticket does not claim it was. Memphis runs it under the CEO approval of 2026-10-13 (execute_sql only,
-- test data and fixtures only, stop on real user data) and records the real PASS/FAIL. Project
-- wtncuzcskpigqpmnxwws only.
--
-- HOW TO RUN. Run each numbered block as ONE batch. Every block starts with BEGIN and ends with ROLLBACK, so
-- nothing persists, including the blocks marked READ-ONLY (BEGIN READ ONLY). Section A before the migration,
-- section B after it, section C after rollback.sql. Every B assertion is expected to FAIL before the migration.
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads only (BEGIN READ ONLY)
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK (create_post, fixtures)
--
-- ROLE CAVEAT: the probes that matter use SET LOCAL ROLE authenticated / anon with request.jwt.claims set; as
-- postgres they pass vacuously. Writes use an existing active profile as the test user; everything is rolled back.

-- ===========================================================================
-- A. PRE-APPLY -- run BEFORE the migration
-- ===========================================================================

-- A1 [READ-ONLY] the live signature and ACL BEFORE. Expect ONE create_post with 15 arguments, SECURITY
--    DEFINER, executable by authenticated and service_role, not anon. Diff against the baseline (stop on a surprise).
begin read only;
select p.oid::regprocedure as signature, p.pronargs, p.prosecdef as security_definer, p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('create_post', 'create_post_legacy_v1')
 order by 1;
rollback;

-- A2 [READ-ONLY] the trigger that fills the place columns, and that no other create_post-like function exists.
begin read only;
select t.tgname, t.tgenabled, pg_get_triggerdef(t.oid) as def
  from pg_trigger t
 where t.tgrelid = 'public.posts'::regclass and not t.tgisinternal and t.tgname = 'trg_posts_set_geo';
rollback;

-- A3 [WRITE-IN-TRANSACTION-ROLLBACK] BEFORE: a call naming only the old parameters returns a post, and a
--    circle post has its post_circles row. (Expected to PASS before the migration and after it.)
begin;
do $$
declare a uuid; c uuid; r jsonb; p uuid; n int;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  if a is null then raise exception 'SETUP FAIL: no active profile'; end if;
  insert into public.circles (owner_profile_id, name)
    select id, 'kan524-probe' from public.profiles where user_id = a and is_active order by created_at limit 1
    returning id into c;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.create_post(p_kind => 'moment', p_visibility => 'circle', p_body => 'kan524 old args', p_circle_ids => array[c]);
  reset role;
  p := (r->>'id')::uuid;
  select count(*) into n from public.post_circles where post_id = p and circle_id = c;
  if p is null or n <> 1 then raise exception 'A3 FAIL: post % circle rows %', p, n; end if;
  raise notice 'A3 PASS (before): old-argument circle post created, post_circles row present';
end $$;
rollback;

-- ===========================================================================
-- B. POST-APPLY -- run AFTER 20261013150000_create_post_keeps_place.sql
-- ===========================================================================

-- B1 [READ-ONLY] AC2/AC4: exactly one callable create_post (20 arguments, the first 15 unchanged); the legacy
--    function exists with the 15 arguments; ACL: create_post executable by authenticated and service_role only
--    (anon false, PUBLIC grants 0); create_post_legacy_v1 NOT executable by anon, authenticated or PUBLIC.
begin read only;
select p.oid::regprocedure as signature, p.pronargs, p.prosecdef as security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('public', p.oid, 'EXECUTE')        as public_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       (select count(*) from aclexplode(p.proacl) a where a.grantee = 0) as public_grants,
       pg_get_userbyid(p.proowner) as owner, p.proconfig
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('create_post', 'create_post_legacy_v1')
 order by p.pronargs desc;
-- expected: create_post   20  true  anon false  auth true  public false service true  public_grants 0  owner postgres
--           create_post_legacy_v1 15 true anon false auth false public false service true public_grants 0
select count(*) as create_post_overloads from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'create_post';   -- expect 1
rollback;

-- B2 [WRITE-IN-TRANSACTION-ROLLBACK] AC1: an old-argument call still returns a post and the post_circles row exists.
begin;
do $$
declare a uuid; c uuid; r jsonb; p uuid; n int;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  if a is null then raise exception 'SETUP FAIL: no active profile'; end if;
  insert into public.circles (owner_profile_id, name)
    select id, 'kan524-probe' from public.profiles where user_id = a and is_active order by created_at limit 1
    returning id into c;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.create_post(p_kind => 'moment', p_visibility => 'circle', p_body => 'kan524 old args', p_circle_ids => array[c]);
  reset role;
  p := (r->>'id')::uuid;
  select count(*) into n from public.post_circles where post_id = p and circle_id = c;
  if p is null or n <> 1 then raise exception 'B2 FAIL: post % circle rows %', p, n; end if;
  raise notice 'B2 PASS: old-argument call returns a post; post_circles row present';
end $$;
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] AC1/AC6: a circle post created with a venue stores venue_id (and the
--    location_name) and has its post_circles row. The trigger OVERWRITES area and coordinates from the venue:
--    the NOTICE records what actually happened (a fact for the frontend ticket).
begin;
do $$
declare a uuid; c uuid; v uuid; r jsonb; p uuid; n int; row_ record;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  select ve.id into v from public.venues ve where ve.geo_location_id is not null limit 1;
  if a is null or v is null then raise exception 'SETUP FAIL: need an active profile and a venue with a geo location'; end if;
  insert into public.circles (owner_profile_id, name)
    select id, 'kan524-probe' from public.profiles where user_id = a and is_active order by created_at limit 1
    returning id into c;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.create_post(p_kind => 'moment', p_visibility => 'circle', p_body => 'kan524 venue',
                          p_circle_ids => array[c], p_venue_id => v, p_location_name => 'KAN-524 venue label');
  reset role;
  p := (r->>'id')::uuid;
  select venue_id, location_name, area_id, geo_lat, geo_lng into row_ from public.posts where id = p;
  if row_.venue_id is distinct from v then raise exception 'B3 FAIL: venue_id % (expected %)', row_.venue_id, v; end if;
  if row_.location_name is distinct from 'KAN-524 venue label' then raise exception 'B3 FAIL: location_name %', row_.location_name; end if;
  select count(*) into n from public.post_circles where post_id = p and circle_id = c;
  if n <> 1 then raise exception 'B3 FAIL: post_circles rows %', n; end if;
  raise notice 'B3 PASS: venue_id and location_name stored; trigger-derived area_id=% lat=% lng=%', row_.area_id, row_.geo_lat, row_.geo_lng;
end $$;
rollback;

-- B4 [WRITE-IN-TRANSACTION-ROLLBACK] AC1/AC6: a circle post created with lat/lng, location_name and area_id stores
--    location_name and the coordinates. The NOTICE records whether the supplied area_id survived the trigger
--    (expected: it does NOT, the trigger replaces it with the nearest area on the manual-point path).
begin;
do $$
declare a uuid; c uuid; ar uuid; r jsonb; p uuid; n int; row_ record;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  select id into ar from public.areas where is_active order by id limit 1;
  if a is null or ar is null then raise exception 'SETUP FAIL: need an active profile and an area'; end if;
  insert into public.circles (owner_profile_id, name)
    select id, 'kan524-probe' from public.profiles where user_id = a and is_active order by created_at limit 1
    returning id into c;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.create_post(p_kind => 'moment', p_visibility => 'circle', p_body => 'kan524 point',
                          p_circle_ids => array[c], p_geo_lat => 25.2048, p_geo_lng => 55.2708,
                          p_location_name => 'KAN-524 point label', p_area_id => ar);
  reset role;
  p := (r->>'id')::uuid;
  select location_name, geo_lat, geo_lng, area_id into row_ from public.posts where id = p;
  if row_.location_name is distinct from 'KAN-524 point label' then raise exception 'B4 FAIL: location_name %', row_.location_name; end if;
  if row_.geo_lat is distinct from 25.2048 or row_.geo_lng is distinct from 55.2708 then
    raise exception 'B4 FAIL: coordinates % %', row_.geo_lat, row_.geo_lng; end if;
  select count(*) into n from public.post_circles where post_id = p and circle_id = c;
  if n <> 1 then raise exception 'B4 FAIL: post_circles rows %', n; end if;
  raise notice 'B4 PASS: location_name and coordinates stored; supplied area_id % -> stored area_id % (%)',
    ar, row_.area_id, case when row_.area_id = ar then 'kept' else 'replaced by the trigger' end;
end $$;
rollback;

-- B5 [WRITE-IN-TRANSACTION-ROLLBACK] AC3: half a point raises geo_incomplete (P0001), in both directions, and
--    stores nothing.
begin;
do $$
declare a uuid; e text; n0 int; n1 int;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  if a is null then raise exception 'SETUP FAIL: no active profile'; end if;
  select count(*) into n0 from public.posts;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin perform public.create_post(p_kind => 'moment', p_visibility => 'public', p_geo_lat => 25.2);
    e := 'NO ERROR'; exception when others then e := sqlstate || ':' || sqlerrm; end;
  if e <> 'P0001:geo_incomplete' then raise exception 'B5 FAIL: lat only gave %', e; end if;
  begin perform public.create_post(p_kind => 'moment', p_visibility => 'public', p_geo_lng => 55.2);
    e := 'NO ERROR'; exception when others then e := sqlstate || ':' || sqlerrm; end;
  if e <> 'P0001:geo_incomplete' then raise exception 'B5 FAIL: lng only gave %', e; end if;
  reset role;
  select count(*) into n1 from public.posts;
  if n1 <> n0 then raise exception 'B5 FAIL: posts changed % -> %', n0, n1; end if;
  raise notice 'B5 PASS';
end $$;
rollback;

-- B6 [WRITE-IN-TRANSACTION-ROLLBACK] AC2/AC4: anon cannot execute create_post or create_post_legacy_v1;
--    authenticated cannot execute create_post_legacy_v1 (insufficient_privilege or undefined_function counts).
begin;
do $$
declare a uuid; e text;
begin
  select pr.user_id into a from public.profiles pr where pr.is_active order by pr.created_at limit 1;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
  begin perform public.create_post(p_kind => 'moment', p_visibility => 'public'); e := 'EXECUTED';
    exception when insufficient_privilege then e := 'denied'; when others then e := sqlstate; end;
  if e <> 'denied' then raise exception 'B6 FAIL: anon create_post gave %', e; end if;
  begin perform public.create_post_legacy_v1(p_kind => 'moment', p_visibility => 'public'); e := 'EXECUTED';
    exception when insufficient_privilege then e := 'denied'; when others then e := sqlstate; end;
  if e <> 'denied' then raise exception 'B6 FAIL: anon legacy gave %', e; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin perform public.create_post_legacy_v1(p_kind => 'moment', p_visibility => 'public'); e := 'EXECUTED';
    exception when insufficient_privilege then e := 'denied'; when others then e := sqlstate; end;
  if e <> 'denied' then raise exception 'B6 FAIL: authenticated legacy gave %', e; end if;
  reset role;
  raise notice 'B6 PASS';
end $$;
rollback;

-- ===========================================================================
-- C. POST-ROLLBACK -- run AFTER rollback.sql (an apply by Memphis)
-- ===========================================================================

-- C1 [READ-ONLY] the 15-argument create_post is back with the A1 ACL; the legacy name is gone; the new function is
--    parked under create_post_v2_rolledback and not executable by anon or authenticated.
begin read only;
select p.oid::regprocedure as signature, p.pronargs,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('create_post', 'create_post_legacy_v1', 'create_post_v2_rolledback')
 order by 1;
rollback;
