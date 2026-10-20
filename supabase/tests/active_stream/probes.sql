-- KAN-595 (Active stream) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws (a non-production branch first), after
-- 20261020120000_kan595_active_stream.sql is applied. Every block begins with BEGIN and ends with ROLLBACK;
-- fixtures are changed inside it and rolled back with it. Blocks print booleans/counts only.
--
-- Variables (supplied by the runner, no secrets; existing TEST users and test data):
--   :viewer            an authenticated test user
--   :other             another test user with a personal profile :other_profile, no block with :viewer
--   :game_id           a test game created by :other, listing_visibility 'public', in an area whose city is :city
--   :meetup_id         a test meetup created by :other, listing_visibility 'public', area in :city
--   :city              the city text of those areas

-- P1 [READ-ONLY] AUTHORED, NOT RUN. Newest first: event_at never increases down the page.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select bool_and(ok) as p1_newest_first from (
  select event_at <= lag(event_at) over (order by rn) or lag(event_at) over (order by rn) is null as ok
    from (select s.*, row_number() over () rn from public.active_stream(null, null, 50) s) x) y;
ROLLBACK;

-- P2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Each event type is present for a past game/meetup.
BEGIN;
update public.games set is_cancelled = false, created_at = now() - interval '3 hours',
       start_at = now() - interval '2 hours', end_at = now() - interval '1 hour' where id = :'game_id';
update public.meetups set is_cancelled = false, created_at = now() - interval '3 hours',
       start_at = now() - interval '2 hours', end_at = now() - interval '1 hour' where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select array_agg(distinct event_type order by event_type) as p2_types_present
  from public.active_stream(null, :'city', 50)
 where entity_id in (:'game_id', :'meetup_id');
-- expect {game_created,game_ended,game_started,meetup_completed,meetup_created,meetup_started}
select count(*) > 0 as p2_player_joined from public.active_stream(array['player_joined'], null, 50);
select count(*) > 0 as p2_venue_added from public.active_stream(array['venue_added'], null, 50);
ROLLBACK;

-- P3 [READ-ONLY] AUTHORED, NOT RUN. Type filter returns only the requested types.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select coalesce(bool_and(event_type in ('game_created', 'meetup_created')), true) as p3_type_filter
  from public.active_stream(array['game_created', 'meetup_created'], null, 50);
ROLLBACK;

-- P4 [READ-ONLY] AUTHORED, NOT RUN. City filter (case-insensitive) and NULL city = all cities.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select coalesce(bool_and(lower(city) = lower(:'city')), true) as p4_city_only
  from public.active_stream(null, upper(:'city'), 50);
select (select count(*) from public.active_stream(null, null, 50))
    >= (select count(*) from public.active_stream(null, :'city', 50)) as p4_null_city_superset;
ROLLBACK;

-- P5 [READ-ONLY] AUTHORED, NOT RUN. No duplicate (event_type, entity_id).
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select count(*) = count(distinct (event_type, entity_id)) as p5_no_duplicates
  from public.active_stream(null, null, 50);
ROLLBACK;

-- P6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Blocked actor excluded, viewer blocks other.
BEGIN;
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'viewer', :'other');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select count(*) = 0 as p6_blocker_side
  from public.active_stream(null, null, 50) where entity_id in (:'game_id', :'meetup_id', :'other_profile');
ROLLBACK;

-- P7 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Blocked actor excluded, other blocks viewer.
BEGIN;
insert into public.user_blocks (blocker_user_id, blocked_user_id) values (:'other', :'viewer');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select count(*) = 0 as p7_blocked_side
  from public.active_stream(null, null, 50) where entity_id in (:'game_id', :'meetup_id', :'other_profile');
ROLLBACK;

-- P8 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Private game, hidden meetup and cancelled items excluded.
BEGIN;
update public.games set listing_visibility = 'private' where id = :'game_id';
update public.meetups set listing_visibility = 'hidden' where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select count(*) = 0 as p8_private_excluded
  from public.active_stream(null, null, 50) where entity_id in (:'game_id', :'meetup_id');
ROLLBACK;
BEGIN;
update public.games set is_cancelled = true, cancelled_at = now() where id = :'game_id';
update public.meetups set is_cancelled = true where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select count(*) = 0 as p8_cancelled_excluded
  from public.active_stream(null, null, 50) where entity_id in (:'game_id', :'meetup_id');
ROLLBACK;

-- P9 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Future items: created only, no started/ended.
-- Negative control: P2 shows the same entities DO emit started/ended once their times have passed.
BEGIN;
update public.games set is_cancelled = false, start_at = now() + interval '1 day',
       end_at = now() + interval '1 day 2 hours' where id = :'game_id';
update public.meetups set is_cancelled = false, start_at = now() + interval '1 day', end_at = null
 where id = :'meetup_id';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
select array_agg(event_type order by event_type) as p9_future_types
  from public.active_stream(null, null, 50) where entity_id in (:'game_id', :'meetup_id');
-- expect at most {game_created,meetup_created}
ROLLBACK;

-- P10 [READ-ONLY] AUTHORED, NOT RUN. Keyset pagination: page 2 starts strictly after page 1, no overlap; limit clamp.
BEGIN;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'viewer', 'role', 'authenticated')::text, true);
create temp table p10_a as select * from public.active_stream(null, null, 5);
select event_at, event_type, entity_id from p10_a order by event_at, event_type, entity_id limit 1 \gset last_
create temp table p10_b as
  select * from public.active_stream(null, null, 5, :'last_event_at', :'last_event_type', :'last_entity_id');
select not exists (select 1 from p10_a a join p10_b b using (event_type, entity_id)) as p10_no_overlap;
select (select count(*) from public.active_stream(null, null, 1000)) <= 50 as p10_limit_clamped;
ROLLBACK;

-- P11 [READ-ONLY] AUTHORED, NOT RUN. ACL: authenticated may execute; anon and PUBLIC may not; definer, pinned path.
BEGIN;
select has_function_privilege('authenticated', 'public.active_stream(text[], text, int, timestamptz, text, uuid)', 'EXECUTE') as p11_auth,
       not has_function_privilege('anon', 'public.active_stream(text[], text, int, timestamptz, text, uuid)', 'EXECUTE') as p11_no_anon,
       p.prosecdef as p11_definer,
       p.proconfig @> array['search_path=public, pg_temp'] as p11_path,
       p.provolatile = 's' as p11_stable,
       p.proacl::text not like '%=X/%' as p11_no_public
  from pg_proc p where p.oid = 'public.active_stream(text[], text, int, timestamptz, text, uuid)'::regprocedure;
ROLLBACK;

-- P12 [READ-ONLY] AUTHORED, NOT RUN. No auth.uid(): no rows (fails closed).
BEGIN;
select set_config('request.jwt.claims', '{}', true);
select count(*) = 0 as p12_no_viewer_no_rows from public.active_stream(null, null, 50);
ROLLBACK;
