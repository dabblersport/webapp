-- KAN-671 probes. AUTHORED, NOT RUN. Run by the operations team AFTER the migration is applied.
-- ONE transaction: BEGIN .. ROLLBACK. Nothing is kept. Each block names its expected result.

BEGIN;

-- P1 [game_series RLS on, games RLS still on] expect: true, true
select (select relrowsecurity from pg_class where oid = 'public.game_series'::regclass) as series_rls,
       (select relrowsecurity from pg_class where oid = 'public.games'::regclass) as games_rls;

-- P2 [game_series policies are TO authenticated only] expect: 1 policy, roles {authenticated}, cmd SELECT
select policyname, cmd, roles::text
from pg_policies
where schemaname = 'public' and tablename = 'game_series'
order by policyname;

-- P3 [no policy on game_series names public or anon] expect: 0
select count(*)
from pg_policies
where schemaname = 'public' and tablename = 'game_series'
  and (roles && array['public', 'anon']::name[]);

-- P4 [anon and PUBLIC hold nothing on game_series] expect: false, false, false, false
select has_table_privilege('anon', 'public.game_series', 'select'),
       has_table_privilege('anon', 'public.game_series', 'insert'),
       has_table_privilege('anon', 'public.game_series', 'update'),
       has_table_privilege('anon', 'public.game_series', 'delete');

-- P5 [authenticated reads but cannot write game_series] expect: true, false, false, false
select has_table_privilege('authenticated', 'public.game_series', 'select'),
       has_table_privilege('authenticated', 'public.game_series', 'insert'),
       has_table_privilege('authenticated', 'public.game_series', 'update'),
       has_table_privilege('authenticated', 'public.game_series', 'delete');

-- P6 [games.series_id is nullable uuid; every existing row is NULL] expect: uuid, YES, 0
select c.data_type, c.is_nullable,
       (select count(*) from public.games where series_id is not null) as non_null_rows
from information_schema.columns c
where c.table_schema = 'public' and c.table_name = 'games' and c.column_name = 'series_id';

-- P7 [GAMES RLS CHECK 1: games still has no policy, so the migration opened no row] expect: 0
select count(*) from pg_policies where schemaname = 'public' and tablename = 'games';

-- P8 [GAMES RLS CHECK 2: privileges on the new column equal an old column, so nothing new is granted]
-- expect: all rows true (anon select, authenticated select, authenticated update match creator_user_id)
select (has_column_privilege('anon', 'public.games', 'series_id', 'select')
        = has_column_privilege('anon', 'public.games', 'creator_user_id', 'select')) as anon_select_same,
       (has_column_privilege('authenticated', 'public.games', 'series_id', 'select')
        = has_column_privilege('authenticated', 'public.games', 'creator_user_id', 'select')) as auth_select_same,
       (has_column_privilege('authenticated', 'public.games', 'series_id', 'update')
        = has_column_privilege('authenticated', 'public.games', 'creator_user_id', 'update')) as auth_update_same;

-- P9 [GAMES RLS CHECK 3: v_my_games does not expose series_id; its row filter is unchanged] expect: false
select pg_get_viewdef('public.v_my_games'::regclass) ~ 'series_id' as view_mentions_series_id;

-- P10 [GAMES RLS CHECK 4: runtime, an authenticated caller still reads 0 games rows directly]
-- expect: 0, 0 (RLS on, no policy; series_id adds no read path)
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*) as visible_games, count(*) filter (where series_id is not null) as visible_series_games
from public.games;
reset role;

-- P11 [owner-only series read] a series row inserted for an existing profile is visible to its owner
-- and to nobody else. expect: 1, 0
insert into public.game_series
  (creator_user_id, creator_profile_id, sport_id, geo_location_id, area_id,
   capacity, start_time_local, duration_minutes, rrule, timezone, starts_on)
select p.user_id, p.id, g.sport_id, g.geo_location_id, g.area_id,
       10, '19:00'::time, 90, 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU', 'Asia/Dubai', current_date
from public.profiles p
cross join lateral (select sport_id, geo_location_id, area_id from public.games limit 1) g
limit 1;
select set_config('request.jwt.claims',
  json_build_object('sub', (select creator_user_id from public.game_series limit 1), 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*) as owner_sees from public.game_series;
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*) as stranger_sees from public.game_series;
reset role;

-- P12 [failure demo] a rrule outside weekly/biweekly is refused. expect: check_violation
insert into public.game_series
  (creator_user_id, creator_profile_id, sport_id, geo_location_id, area_id,
   capacity, start_time_local, duration_minutes, rrule, timezone, starts_on)
select p.user_id, p.id, g.sport_id, g.geo_location_id, g.area_id,
       10, '19:00'::time, 90, 'FREQ=DAILY', 'Asia/Dubai', current_date
from public.profiles p
cross join lateral (select sport_id, geo_location_id, area_id from public.games limit 1) g
limit 1;
ROLLBACK;
