-- KAN-710 probes. Run AFTER the migration is applied, on a BRANCH/LOCAL database only.
-- Part A is read-only (safe anywhere). Part B writes inside BEGIN..ROLLBACK, needs one games row
-- and one meetups row, and must NOT be run on live. Run with:
--   psql -v game_id=<existing games.id> -v meetup_id=<existing meetups.id> -f probes_kan710.sql
-- Part B prints "NOTICE: PASS ..." per adversarial case and raises "FAIL ..." otherwise.
-- STATUS: authored; NOT executed (no Postgres available to the authoring session, C2 = FAIL/not run).

-- ===== Part A: read-only (KAN-709/09 P-01..P-10, plus E-xx) =====
select 'P-01' p, relrowsecurity, relforcerowsecurity from pg_class where oid='public.events'::regclass;   -- t,t
select 'P-02' p, count(*) from pg_policies where schemaname='public' and tablename='events';               -- 0
select 'P-03' p, grantee, privilege_type from information_schema.role_table_grants
  where table_schema='public' and table_name='events' and grantee in ('anon','authenticated','PUBLIC');    -- 0 rows
select 'P-04' p, count(*) from public.events;                                                              -- 0
select 'P-05' p, conname from pg_constraint where conrelid='public.events'::regclass order by 2;          -- pkey, 5 FKs, checks
select 'P-06' p, c.relname, t.tgname, t.tgdeferrable, t.tginitdeferred from pg_trigger t join pg_class c on c.oid=t.tgrelid
  where t.tgconstraint<>0 and c.relname in ('events','games','meetups')
    and (t.tgname like 'trg\_%event%' or t.tgname like 'trg\_%series%');                                    -- all t,t
select 'P-07' p, indexdef from pg_indexes where tablename='events' and indexname='events_type_creator_request_id_key';
select 'P-08' p, table_name, is_nullable from information_schema.columns
  where table_schema='public' and table_name in ('games','meetups') and column_name='event_id';             -- 2 rows, YES
select 'P-09' p, (select count(*) from public.games where event_id is not null) g,
                 (select count(*) from public.meetups where event_id is not null) m;                       -- 0,0
select 'P-10' p, count(*) from pg_publication_tables where tablename='events';                              -- 0
select 'E-01' p, relowner::regrole from pg_class where oid='public.events'::regclass;                      -- postgres
select 'E-02' p, rolbypassrls from pg_roles where rolname='postgres';                                      -- t (assumption of the definer functions)
select 'E-03' p, proname, prosecdef, proconfig, proowner::regrole from pg_proc
  where pronamespace='public'::regnamespace and proname like 'events\_%' order by 2;                       -- owner postgres, search_path set
select 'E-04' p, proname, has_function_privilege('anon', oid,'execute') a, has_function_privilege('authenticated', oid,'execute') u
  from pg_proc where pronamespace='public'::regnamespace and proname like 'events\_%';                      -- f,f

-- ===== Part B: adversarial, BRANCH ONLY (each case rolls back) =====
create or replace function pg_temp.expect_fail(label text, stmt text) returns void language plpgsql as $$
begin
  begin execute stmt;
  exception when others then raise notice 'PASS % (%: %)', label, sqlstate, sqlerrm; return; end;
  raise exception 'FAIL % : statement succeeded', label;
end $$;
grant execute on function pg_temp.expect_fail(text,text) to public;

-- B-01 unauthorised access: anon / authenticated cannot read or write events
begin; set local role anon;          select pg_temp.expect_fail('B-01a anon select', 'select 1 from public.events'); rollback;
begin; set local role authenticated; select pg_temp.expect_fail('B-01b auth select', 'select 1 from public.events'); rollback;
begin; set local role authenticated; select pg_temp.expect_fail('B-01c auth insert', 'insert into public.events(id) values (gen_random_uuid())'); rollback;

-- B-02 normal atomic creation: parent + link in one transaction succeeds at commit time
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.title,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id
  from public.games g where g.id = :'game_id';
  update public.games set event_id = id where id = :'game_id';
  set constraints all immediate;   -- run the deferred checks now; must not raise
  select 'PASS B-02 atomic create' as result;
rollback;

-- B-03 wrong subtype: a meetups row linked to a 'game' event
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select m.id,'game',m.creator_profile_id,m.creator_user_id,coalesce(m.title,'xxx'),m.start_at,m.start_at+interval '1 hour',4,
         (select id from public.sports limit 1),(select id from public.areas limit 1),(select id from public.geo_locations limit 1)
  from public.meetups m where m.id = :'meetup_id';
  update public.meetups set event_id = id where id = :'meetup_id';
  select pg_temp.expect_fail('B-03 wrong subtype', 'set constraints all immediate');
rollback;

-- B-04 orphan: event_id points at an event that does not exist
begin;
  update public.games set event_id = id where id = :'game_id';
  select pg_temp.expect_fail('B-04 orphan', 'set constraints all immediate');
rollback;

-- B-05 duplicate linkage: two subtype rows cannot share one event_id (UNIQUE, not deferrable)
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.title,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id
  from public.games g where g.id = :'game_id';
  update public.games set event_id = id where id = :'game_id';
  select pg_temp.expect_fail('B-05 duplicate link',
    format('update public.games set event_id = %L where id in (select id from public.games where id <> %L limit 1)', :'game_id', :'game_id'));
rollback;

-- B-06 event_id must equal the row id
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select 'cccccccc-0000-0000-0000-000000000001','game',g.creator_profile_id,g.creator_user_id,g.start_at,g.end_at,4,g.sport_id,g.area_id,g.geo_location_id
  from public.games g where g.id = :'game_id';
  update public.games set event_id = 'cccccccc-0000-0000-0000-000000000001' where id = :'game_id';
  select pg_temp.expect_fail('B-06 event_id <> id (parent exists)', 'set constraints all immediate');
rollback;

-- B-07 cross-type double ownership: a game event cannot also be claimed by a meetups row
--      (needs both rows to carry the same id, so we assert the parent-side trigger directly)
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.title,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id
  from public.games g where g.id = :'game_id';
  select pg_temp.expect_fail('B-07 parent type vs children',
    format('update public.meetups set event_id = %L where id = %L; set constraints all immediate', :'game_id', :'meetup_id'));
rollback;

-- B-08 event_type immutable (no retag game <-> meetup)
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id
  from public.games g where g.id = :'game_id';
  select pg_temp.expect_fail('B-08 type immutable', format('update public.events set event_type = ''meetup'' where id = %L', :'game_id'));
rollback;

-- B-09 per-type checks: game without end_at; meetup with a 2-character title
begin;
  select pg_temp.expect_fail('B-09a game no end_at', format($q$
    insert into public.events (id,event_type,creator_profile_id,creator_user_id,start_at,capacity,sport_id,area_id,geo_location_id)
    select gen_random_uuid(),'game',creator_profile_id,creator_user_id,start_at,4,sport_id,area_id,geo_location_id from public.games where id = %L$q$, :'game_id'));
  select pg_temp.expect_fail('B-09b meetup short title', format($q$
    insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at)
    select gen_random_uuid(),'meetup',creator_profile_id,creator_user_id,'ab',start_at from public.meetups where id = %L$q$, :'meetup_id'));
rollback;

-- B-10 request replay: same (type, creator, request_id) twice is rejected
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,start_at,end_at,capacity,sport_id,area_id,geo_location_id,request_id)
  select gen_random_uuid(),'game',g.creator_profile_id,g.creator_user_id,g.start_at,g.end_at,4,g.sport_id,g.area_id,g.geo_location_id,'11111111-1111-1111-1111-111111111111'
  from public.games g where g.id = :'game_id';
  select pg_temp.expect_fail('B-10 request replay', format($q$
    insert into public.events (id,event_type,creator_profile_id,creator_user_id,start_at,end_at,capacity,sport_id,area_id,geo_location_id,request_id)
    select gen_random_uuid(),'game',g.creator_profile_id,g.creator_user_id,g.start_at,g.end_at,4,g.sport_id,g.area_id,g.geo_location_id,'11111111-1111-1111-1111-111111111111'
    from public.games g where g.id = %L$q$, :'game_id'));
rollback;

-- B-11 legacy untouched: a game with event_id NULL still updates and passes the deferred checks
begin; update public.games set updated_at = updated_at where id = :'game_id'; set constraints all immediate; select 'PASS B-11 legacy null link' as result; rollback;

-- B-12 rollback atomicity: a failed parent+link transaction leaves no events row
begin; savepoint s;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.title,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id from public.games g where g.id = :'game_id';
  rollback to s;
  select case when (select count(*) from public.events) = 0 then 'PASS B-12 rollback leaves no parent' else 'FAIL B-12' end as result;
rollback;
-- Not executed anywhere (would delete real rows): delete cascade vs NO ACTION FKs on posts and
-- msg_conversations; proven structurally by KAN-709/03 §C. Series occurrence trigger is inert until
-- games.event_id is populated (KAN-711); exercise it then.

-- B-13 subtype id mutation after a valid link must be rejected (games and meetups)
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
  select g.id,'game',g.creator_profile_id,g.creator_user_id,g.title,g.start_at,g.end_at,g.capacity,g.sport_id,g.area_id,g.geo_location_id from public.games g where g.id = :'game_id';
  update public.games set event_id = id where id = :'game_id';
  set constraints all immediate;
  set constraints all deferred;
  update public.games set id = gen_random_uuid() where id = :'game_id';
  select pg_temp.expect_fail('B-13a games id mutation', 'set constraints all immediate');
rollback;
begin;
  insert into public.events (id,event_type,creator_profile_id,creator_user_id,title,start_at)
  select m.id,'meetup',m.creator_profile_id,m.creator_user_id,coalesce(m.title,'xxx'),m.start_at from public.meetups m where m.id = :'meetup_id';
  update public.meetups set event_id = id where id = :'meetup_id';
  set constraints all immediate;
  set constraints all deferred;
  update public.meetups set id = gen_random_uuid() where id = :'meetup_id';
  select pg_temp.expect_fail('B-13b meetups id mutation', 'set constraints all immediate');
rollback;
