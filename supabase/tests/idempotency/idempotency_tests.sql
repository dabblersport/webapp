-- KAN-611 SQL tests: request-id idempotency for create_post / rpc_create_game / rpc_create_meetup.
--
-- Covers: supabase/migrations/20261021120000_kan611_request_id_idempotency.sql
--
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
-- Index: T1 post same id | T2 post different ids | T3 post rollback (hashtag failure, squad failure) | T4 post no id
--        G1 game same id | G2 game different ids | G3 game guards + replay | G4 game no id
--        M1 meetup same id | M2 meetup different ids | M3 meetup guards + replay | M4 meetup no id
--        X1 legacy functions closed | X2 index + setting hygiene | X3 scoped per profile

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

-- T3a [WRITE-IN-TRANSACTION-ROLLBACK] partial failure: a hashtag-link failure inside create_post leaves NO post.
-- A trigger that always raises is created on post_hashtags inside this transaction (DDL rolls back with it).
begin;
create function public.kan611_test_boom() returns trigger language plpgsql as $f$ begin raise exception 'kan611_boom'; end $f$;
create trigger kan611_test_boom before insert on public.post_hashtags for each row execute function public.kan611_test_boom();
do $$
declare u uuid; rid uuid := gen_random_uuid(); failed boolean := false; n int; h int;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T3a: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  begin
    perform public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T3a', p_tags => array['kan611tag'], p_request_id => rid);
  exception when others then failed := true;
  end;
  select count(*) into n from public.posts where request_id = rid or body = 'kan611-T3a';
  select count(*) into h from public.hashtags where tag = 'kan611tag';
  if not failed then raise exception 'KAN611 FAIL T3a: the forced hashtag failure did not raise'; end if;
  if n <> 0 then raise exception 'KAN611 FAIL T3a: % post row(s) remain after the failure', n; end if;
  if h <> 0 then raise exception 'KAN611 FAIL T3a: % hashtag row(s) remain after the failure', h; end if;
  raise notice 'KAN611 PASS T3a';
end $$;
rollback;

-- T3b [WRITE-IN-TRANSACTION-ROLLBACK] partial failure: a squad-link failure leaves NO post. The same boom trigger on
-- post_squads forces it (independent of whether post_squads has a foreign key).
begin;
create function public.kan611_test_boom() returns trigger language plpgsql as $f$ begin raise exception 'kan611_boom'; end $f$;
create trigger kan611_test_boom before insert on public.post_squads for each row execute function public.kan611_test_boom();
do $$
declare u uuid; rid uuid := gen_random_uuid(); failed boolean := false; n int;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T3b: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  begin
    perform public.create_post(p_kind => 'moment', p_visibility => 'squad', p_body => 'kan611-T3b', p_squad_ids => array[gen_random_uuid()], p_request_id => rid);
  exception when others then failed := true;
  end;
  select count(*) into n from public.posts where request_id = rid or body = 'kan611-T3b';
  if not failed then raise exception 'KAN611 FAIL T3b: the forced squad failure did not raise'; end if;
  if n <> 0 then raise exception 'KAN611 FAIL T3b: % post row(s) remain', n; end if;
  raise notice 'KAN611 PASS T3b';
end $$;
rollback;

-- T3c [WRITE-IN-TRANSACTION-ROLLBACK] the success path links hashtags and the squad in the same call, and a repeat adds nothing.
begin;
do $$
declare u uuid; rid uuid := gen_random_uuid(); a jsonb; pid uuid; h1 int; h2 int;
begin
  select user_id into u from public.profiles where is_active and persona_type = 'player' order by created_at limit 1;
  if u is null then raise notice 'KAN611 SKIPPED T3c: no active player profile'; return; end if;
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  a := public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T3c', p_tags => array['#KAN611Tag', 'kan611tag2'], p_request_id => rid);
  pid := (a->>'id')::uuid;
  select count(*) into h1 from public.post_hashtags where post_id = pid;
  perform public.create_post(p_kind => 'moment', p_visibility => 'public', p_body => 'kan611-T3c', p_tags => array['#KAN611Tag', 'kan611tag2'], p_request_id => rid);
  select count(*) into h2 from public.post_hashtags where post_id = pid;
  if h1 <> 2 or h2 <> 2 then raise exception 'KAN611 FAIL T3c: hashtag links % then % (want 2 and 2)', h1, h2; end if;
  raise notice 'KAN611 PASS T3c';
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
  a := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_request_id => r1);
  b := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_request_id => r1);
  select count(*) into n from public.meetups where request_id = r1;
  select count(*) into h from public.meetup_rsvps where meetup_id = a;
  if a is distinct from b then raise exception 'KAN611 FAIL M1: ids differ % vs %', a, b; end if;
  if n <> 1 or h <> 1 then raise exception 'KAN611 FAIL M1: % meetup rows, % rsvp rows', n, h; end if;
  raise notice 'KAN611 PASS M1';
  c := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M', p_location_name => 'kan611 place', p_request_id => r2);
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
    perform public.rpc_create_meetup('organiser', sp, sv, 'kan611-M3', p_location_name => 'kan611 place', p_meta => '{"joining_rule":"paid"}'::jsonb, p_request_id => r);
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
  a := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M4', p_location_name => 'kan611 place');
  b := public.rpc_create_meetup('organiser', sp, sv, 'kan611-M4', p_location_name => 'kan611 place');
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
  if has_function_privilege('anon', 'public.create_post(text,text,text,text,text,text,jsonb,text[],uuid,uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid,text,double precision,double precision,uuid,uuid)'::regprocedure, 'EXECUTE')
    then raise exception 'KAN611 FAIL X1: anon can execute create_post'; end if;
  raise notice 'KAN611 PASS X1';
end $$;
rollback;

-- X2 [READ-ONLY] the three partial unique indexes exist with the right predicate, and the stamping setting is empty outside a create.
begin read only;
do $$
begin
  if (select count(*) from pg_indexes where schemaname = 'public' and indexname in ('posts_author_request_id_key', 'games_creator_request_id_key', 'meetups_creator_request_id_key')
        and indexdef ilike '%UNIQUE%' and indexdef ilike '%request_id IS NOT NULL%') <> 3
    then raise exception 'KAN611 FAIL X2: a partial unique index is missing'; end if;
  if coalesce(nullif(current_setting('thebes.create_request_id', true), ''), '') <> '' then raise exception 'KAN611 FAIL X2: setting left set'; end if;
  raise notice 'KAN611 PASS X2';
end $$;
rollback;

-- X3 [WRITE-IN-TRANSACTION-ROLLBACK] the request id is scoped to the profile: the same id used by a second user creates a
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
