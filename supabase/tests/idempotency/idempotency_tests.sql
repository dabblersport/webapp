-- KAN-611 SQL tests: request-id idempotency for create_post / rpc_create_game / rpc_create_meetup.
--
-- Covers: supabase/migrations/20261021120000_kan611_request_id_columns.sql
--         supabase/migrations/20261021120100_kan611_create_post_request_id.sql
--         supabase/migrations/20261021120200_kan611_rpc_create_game_request_id.sql
--         supabase/migrations/20261021120300_kan611_rpc_create_meetup_request_id.sql
--
-- AUTHORED NOT RUN.
-- STATUS: AUTHORED, NOT RUN. Nothing here was executed against any database by the team. Memphis runs it AFTER
-- applying the migration (execute_sql only, test data only, project wtncuzcskpigqpmnxwws only) and records the real
-- PASS/FAIL. Every test is ONE batch that starts with BEGIN and ends with ROLLBACK, so nothing persists. A failing
-- assertion RAISEs 'KAN611 FAIL ...'; a passing test ends with RAISE NOTICE 'KAN611 PASS <id>'. A fixture that does not
-- exist raises NOTICE 'KAN611 SKIPPED <id>: <reason>' and is NOT a pass.
--
-- Fixtures are discovered from existing rows (an active player profile, an active organiser profile, a challenge sport
-- with an active variant, a non-challenge sport with an active variant) and the caller is impersonated with
-- SET LOCAL ROLE authenticated + request.jwt.claims. Run each test as postgres with the role switched inside the batch;
-- as postgres alone the guards would pass vacuously.
--
-- Index: P0 pre-check (run BEFORE the migration)
--        T1 post same id | T2 post different ids | T4 post no id
--        G1 game same id | G2 game different ids | G3 game guards + replay | G4 game no id
--        M1 meetup same id | M2 meetup different ids | M3 meetup guards + replay | M4 meetup no id
--        X1 post-check: one overload each, legacy closed, no anon/PUBLIC on new fns | X2 indexes + setting | X3 scoped per user
-- Limits: no numeric daily create limit exists for posts/games/meetups (see README). G3 proves a replay adds no row,
-- so it cannot consume a count-based allowance; G3/M3 prove the guards still fire on a first call with an id.

-- P0 [READ-ONLY] pre-check, BEFORE apply: exactly one overload per name, and no *_legacy_v2 yet.
begin read only;
do $$
declare f text;
begin
  foreach f in array array['create_post', 'rpc_create_game', 'rpc_create_meetup'] loop
    if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = f) <> 1
      then raise exception 'KAN611 FAIL P0: % does not have exactly one overload', f; end if;
    if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = f || '_legacy_v2')
      then raise exception 'KAN611 FAIL P0: %_legacy_v2 already exists', f; end if;
  end loop;
  raise notice 'KAN611 PASS P0';
end $$;
rollback;

-- T1 [WRITE-IN-TRANSACTION-ROLLBACK] create_post twice with the same request id: one row, the same id both times.
begin;
do $$
declare u uuid; rid uuid := gen_random_uuid(); a jsonb; b jsonb; n int;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T1: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T1', p_request_id => rid);
  b := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T1', p_request_id => rid);
  select count(*) into n from public.posts where request_id = rid;
  if a->>'id' is distinct from b->>'id' then raise exception 'KAN611 FAIL T1: ids differ % vs %', a->>'id', b->>'id'; end if;
  if n <> 1 then raise exception 'KAN611 FAIL T1: % rows for one request id', n; end if;
  if (select array_agg(k order by k) from jsonb_object_keys(a) k) is distinct from (select array_agg(k order by k) from jsonb_object_keys(b) k)
    then raise exception 'KAN611 FAIL T1: replay payload has a different shape'; end if;
  raise notice 'KAN611 PASS T1';
end $$;
rollback;

-- T2 [WRITE-IN-TRANSACTION-ROLLBACK] two different request ids create two rows.
begin;
do $$
declare u uuid; r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); a jsonb; b jsonb; n int;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T2: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T2', p_request_id => r1);
  b := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T2', p_request_id => r2);
  select count(*) into n from public.posts where request_id in (r1, r2);
  if n <> 2 or a->>'id' = b->>'id' then raise exception 'KAN611 FAIL T2: expected two rows, got %', n; end if;
  raise notice 'KAN611 PASS T2';
end $$;
rollback;

-- T4 [WRITE-IN-TRANSACTION-ROLLBACK] create_post WITHOUT a request id works as before: request_id stays NULL, no dedupe.
begin;
do $$
declare u uuid; a jsonb; b jsonb;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T4: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T4');
  b := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T4');
  if a->>'id' = b->>'id' then raise exception 'KAN611 FAIL T4: two id-less calls returned one row'; end if;
  if (a->>'request_id') is not null or (b->>'request_id') is not null then raise exception 'KAN611 FAIL T4: request_id set without an id'; end if;
  raise notice 'KAN611 PASS T4';
end $$;
rollback;

-- G1 [WRITE-IN-TRANSACTION-ROLLBACK] rpc_create_game twice with one id: one row, the same uuid; G2 a new id: a second row.
begin;
do $$
declare u uuid; sp uuid; sv uuid; r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); a uuid; b uuid; c uuid; n int; h int;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'player' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and s.is_challenge_sport and v.is_active order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED G1/G2: no player profile or challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.rpc_create_game('player', sp, sv, 'kan611-G', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r1);
  b := public.rpc_create_game('player', sp, sv, 'kan611-G', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r1);
  select count(*) into n from public.games where request_id = r1;
  select count(*) into h from public.game_roster where game_id = a;
  if a is distinct from b then raise exception 'KAN611 FAIL G1: ids differ % vs %', a, b; end if;
  if n <> 1 then raise exception 'KAN611 FAIL G1: % rows for one request id', n; end if;
  if h <> 1 then raise exception 'KAN611 FAIL G1: % roster rows (host row duplicated)', h; end if;
  raise notice 'KAN611 PASS G1';
  c := public.rpc_create_game('player', sp, sv, 'kan611-G', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r2);
  select count(*) into n from public.games where request_id in (r1, r2);
  if c = a or n <> 2 then raise exception 'KAN611 FAIL G2: expected a second row, got % rows', n; end if;
  raise notice 'KAN611 PASS G2';
end $$;
rollback;

-- G3 [WRITE-IN-TRANSACTION-ROLLBACK] guards still apply on a first call (price_required), a failed first call leaves no
-- row, and a replay never adds a row (so it cannot consume any count-based allowance twice).
begin;
do $$
declare u uuid; sp uuid; sv uuid; r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); a uuid; msg text; n0 int; n1 int;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'player' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and s.is_challenge_sport and v.is_active order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED G3: no player profile or challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  begin
    perform public.rpc_create_game('player', sp, sv, 'kan611-G3', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, null, r2);
  exception when others then msg := sqlerrm;
  end;
  if msg is distinct from 'price_required' then raise exception 'KAN611 FAIL G3: guard did not fire with a request id (got %)', msg; end if;
  if exists (select 1 from public.games where request_id = r2) then raise exception 'KAN611 FAIL G3: a refused call left a row'; end if;
  a := public.rpc_create_game('player', sp, sv, 'kan611-G3', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r1);
  select count(*) into n0 from public.games where creator_profile_id = (select creator_profile_id from public.games where id = a);
  perform public.rpc_create_game('player', sp, sv, 'kan611-G3', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r1);
  perform public.rpc_create_game('player', sp, sv, 'kan611-G3', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0, r1);
  select count(*) into n1 from public.games where creator_profile_id = (select creator_profile_id from public.games where id = a);
  if n1 <> n0 then raise exception 'KAN611 FAIL G3: replays changed the creator''s game count % -> %', n0, n1; end if;
  raise notice 'KAN611 PASS G3';
end $$;
rollback;

-- G4 [WRITE-IN-TRANSACTION-ROLLBACK] rpc_create_game WITHOUT a request id behaves as before (two calls, two rows, request_id NULL).
begin;
do $$
declare u uuid; sp uuid; sv uuid; a uuid; b uuid; r uuid;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'player' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and s.is_challenge_sport and v.is_active order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED G4: no player profile or challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.rpc_create_game('player', sp, sv, 'kan611-G4', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0);
  b := public.rpc_create_game('player', sp, sv, 'kan611-G4', null, now() + interval '2 days', now() + interval '2 days 1 hour', 0, 'public', 'open', null, null, null, null, false, false, null, null, null, null, null, null, null, null, 0);
  select request_id into r from public.games where id = a;
  if a = b or r is not null then raise exception 'KAN611 FAIL G4: id-less behaviour changed'; end if;
  raise notice 'KAN611 PASS G4';
end $$;
rollback;

-- M1/M2 [WRITE-IN-TRANSACTION-ROLLBACK] rpc_create_meetup twice with one id: one row, the same uuid; a new id: a second row.
begin;
do $$
declare u uuid; sp uuid; sv uuid; r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); a uuid; b uuid; c uuid; n int; h int;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'organiser' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and v.is_active and not coalesce(s.is_challenge_sport, false) order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED M1/M2: no organiser profile or non-challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_is_indoor => true, p_request_id => r1);
  b := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_is_indoor => true, p_request_id => r1);
  select count(*) into n from public.meetups where request_id = r1;
  select count(*) into h from public.meetup_rsvps where meetup_id = a;
  if a is distinct from b then raise exception 'KAN611 FAIL M1: ids differ % vs %', a, b; end if;
  if n <> 1 or h <> 1 then raise exception 'KAN611 FAIL M1: % meetup rows, % rsvp rows', n, h; end if;
  raise notice 'KAN611 PASS M1';
  c := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_is_indoor => true, p_request_id => r2);
  select count(*) into n from public.meetups where request_id in (r1, r2);
  if c = a or n <> 2 then raise exception 'KAN611 FAIL M2: expected a second row, got %', n; end if;
  raise notice 'KAN611 PASS M2';
end $$;
rollback;

-- M3 [WRITE-IN-TRANSACTION-ROLLBACK] meetup guards still apply with a request id (free_meetups_only); a refused call leaves no row.
begin;
do $$
declare u uuid; sp uuid; sv uuid; r uuid := gen_random_uuid(); msg text;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'organiser' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and v.is_active and not coalesce(s.is_challenge_sport, false) order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED M3: no organiser profile or non-challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  begin
    perform public.rpc_create_meetup('organiser', sp, sv, 'kan611-M3', p_location_name => 'kan611 place', p_is_indoor => true, p_meta => '{"joining_rule":"paid"}'::jsonb, p_request_id => r);
  exception when others then msg := sqlerrm;
  end;
  if msg is distinct from 'free_meetups_only' then raise exception 'KAN611 FAIL M3: guard did not fire (got %)', msg; end if;
  if exists (select 1 from public.meetups where request_id = r) then raise exception 'KAN611 FAIL M3: a refused call left a row'; end if;
  raise notice 'KAN611 PASS M3';
end $$;
rollback;

-- M4 [WRITE-IN-TRANSACTION-ROLLBACK] rpc_create_meetup WITHOUT a request id behaves as before.
begin;
do $$
declare u uuid; sp uuid; sv uuid; a uuid; b uuid; r uuid;
begin
  select p.user_id into u from public.profiles p where p.is_active and p.persona_type = 'organiser' order by p.created_at limit 1;
  select s.id, v.id into sp, sv from public.sports s join public.sport_variants v on v.sport_id = s.id
   where s.is_active and v.is_active and not coalesce(s.is_challenge_sport, false) order by s.created_at, v.created_at limit 1;
  if u is null or sp is null then raise notice 'KAN611 SKIPPED M4: no organiser profile or non-challenge sport variant'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M4', p_location_name => 'kan611 place', p_is_indoor => true);
  b := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M4', p_location_name => 'kan611 place', p_is_indoor => true);
  select request_id into r from public.meetups where id = a;
  if a = b or r is not null then raise exception 'KAN611 FAIL M4: id-less behaviour changed'; end if;
  raise notice 'KAN611 PASS M4';
end $$;
rollback;

-- X1 [READ-ONLY] the legacy bodies are closed to clients; the new functions keep the old ACL; one create_post exists.
begin read only;
do $$
declare bad text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into bad from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('create_post_legacy_v2', 'rpc_create_game_legacy_v2', 'rpc_create_meetup_legacy_v2')
     and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  if bad is not null then raise exception 'KAN611 FAIL X1: legacy function open to clients: %', bad; end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('create_post', 'rpc_create_game', 'rpc_create_meetup')) <> 3
    then raise exception 'KAN611 FAIL X1: expected exactly one create_post, rpc_create_game and rpc_create_meetup'; end if;
  -- New functions: proacl set, no PUBLIC (grantee 0) and no anon entry; authenticated can execute.
  select string_agg(p.oid::regprocedure::text, ', ') into bad from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('create_post', 'rpc_create_game', 'rpc_create_meetup')
     and (p.proacl is null
          or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0 or a.grantee = 'anon'::regrole)
          or has_function_privilege('anon', p.oid, 'EXECUTE')
          or not has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  if bad is not null then raise exception 'KAN611 FAIL X1: new function ACL wrong (anon/PUBLIC present or authenticated missing): %', bad; end if;
  raise notice 'KAN611 PASS X1';
end $$;
rollback;

-- X2 [READ-ONLY] the three partial unique indexes exist with the right predicate, and the stamping setting is empty outside a create.
begin read only;
do $$
begin
  if (select count(*) from pg_indexes where schemaname = 'public' and indexname in ('posts_author_user_request_id_key', 'games_creator_user_request_id_key', 'meetups_creator_user_request_id_key')
        and indexdef ilike '%UNIQUE%' and indexdef ilike '%request_id IS NOT NULL%') <> 3
    then raise exception 'KAN611 FAIL X2: a partial unique index is missing'; end if;
  if coalesce(nullif(current_setting('thebes.create_request_id', true), ''), '') <> '' then raise exception 'KAN611 FAIL X2: setting left set'; end if;
  raise notice 'KAN611 PASS X2';
end $$;
rollback;

-- X3 [WRITE-IN-TRANSACTION-ROLLBACK] the request id is scoped to the owner user: the same id used by a second user creates a
-- separate post and never returns the first user's row.
begin;
do $$
declare u1 uuid; u2 uuid; rid uuid := gen_random_uuid(); a jsonb; b jsonb;
begin
  select user_id into u1 from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  select user_id into u2 from public.profiles where is_active and user_id <> u1 order by created_at limit 1;
  if u1 is null or u2 is null then raise notice 'KAN611 SKIPPED X3: needs two users'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  a := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-X3', p_request_id => rid);
  perform set_config('request.jwt.claims', json_build_object('sub', u2, 'role', 'authenticated')::text, true);
  b := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-X3', p_request_id => rid);
  if a->>'id' = b->>'id' then raise exception 'KAN611 FAIL X3: a second user was handed the first user''s post'; end if;
  raise notice 'KAN611 PASS X3';
end $$;
rollback;
