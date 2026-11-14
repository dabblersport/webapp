-- KAN-866 (F11 KAN-719b): drop the 22 shared columns from public.games. Their values live on public.events
-- (event_type 'game', events.id = games.event_id = games.id) since KAN-710/711; every game writer writes events first
-- since KAN-947 (20261114114127 .. 20261114120447) and every reader reads events since KAN-948 (20261114113938).
--
-- Authorization: CEO msg-20261111075244-c8f3f719 ("I approve for the KAN-866 DROP", Jira 15963) and the CEO decision of
-- 2026-11-14 "نحذف دلوقتي" (Jira 16314/16315), which accepts that mobile builds older than 181 break.
-- Claim: Jira KAN-866 comment 16330. Preflight (read only, 2026-11-14, wtncuzcskpigqpmnxwws): no view, rule or policy
-- depends on the columns; the only trigger with a column dependency is the disabled trg_games_inherit_geo; the only
-- live functions naming the columns on games are the KAN-947 mirror pair, which this drops.
--
-- Order (one transaction, no CASCADE anywhere):
--   1. pre-image guards (the 22 columns present; md5 of every function dropped here; the four disabled triggers).
--   2. backup: public._kan866_games_backup (id + the 22 columns, 269 rows at authoring), RLS on, no policy, every
--      grant revoked from PUBLIC/anon/authenticated/service_role. Rollback: supabase/schema/rollback/
--      kan866_ROLLBACK_restore_games_shared_columns.sql.
--   3. the four disabled games triggers and their functions (each function is attached to nothing else; the only other
--      mention, in kan713_games_location, is a comment): trg_game_created/handle_game_created,
--      trg_games_inherit_geo/fn_games_inherit_geo, trg_games_inherit_venue_geo/trg_fn_games_inherit_venue_geo,
--      trg_games_sync_joining_rule/fn_games_sync_joining_rule.
--   4. the KAN-947 events->games mirror: trg_00/trg_zz_kan947_games_from_events + kan947_games_from_events(),
--      trg_zz_kan947_events_game_mirror + kan947_events_game_mirror().
--   5. supabase_realtime: games is re-published with (id, event_changed_at). Of its old list (id + 12 dropped columns +
--      event_changed_at) nothing else survives. KAN-949's trg_kan949_events_nudge_subtype bumps event_changed_at on
--      every listing-field change, so the KAN-755 nudge keeps firing. meetups is untouched.
--   6. the 11 indexes, 6 foreign keys and 10 CHECK constraints on the columns, by name; then the 22 columns, RESTRICT.
--      Uniqueness that moved: games_creator_request_id_key -> events_type_creator_request_id_key;
--      games_series_id_start_at_key -> kan718_series_occurrence_guard on events and games (trigger-enforced).
--   7. post: columns gone, backup complete and closed, every game still has its events parent, publication list.
-- Test: supabase/tests/events_p4/kan866_drop_games_shared_columns_live_test.sql.

do $pre$
declare
  k record;
  n int;
begin
  select count(*) into n from pg_attribute
   where attrelid = 'public.games'::regclass and not attisdropped
     and attname in ('creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
                     'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id',
                     'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id','created_at','updated_at');
  if n <> 22 then
    raise exception 'KAN-866 pre: % of the 22 columns present', n;
  end if;
  for k in select * from (values
    ('public.kan947_games_from_events()', '4d31b7b4d09abd78430f92fa91b37399'),
    ('public.kan947_events_game_mirror()', 'f658a220416408c6a0366037d087fc11'),
    ('public.handle_game_created()', '86d0ba9aa5fa5cd946b43d1033031e83'),
    ('public.fn_games_inherit_geo()', '8e20becc9f00e36b14ea352a783a19dc'),
    ('public.trg_fn_games_inherit_venue_geo()', '67a27c72b8c43331c93b09771788c639'),
    ('public.fn_games_sync_joining_rule()', '47a0aa3b6ceee50c1a4d55bdeea75815')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-866 pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if (select count(*) from pg_trigger where tgrelid = 'public.games'::regclass and tgenabled = 'D'
         and tgname in ('trg_game_created','trg_games_inherit_geo','trg_games_inherit_venue_geo','trg_games_sync_joining_rule')) <> 4 then
    raise exception 'KAN-866 pre: the four disabled games triggers are not all present and disabled';
  end if;
  if exists (select 1 from pg_trigger where tgfoid in ('public.handle_game_created()'::regprocedure, 'public.fn_games_inherit_geo()'::regprocedure,
               'public.trg_fn_games_inherit_venue_geo()'::regprocedure, 'public.fn_games_sync_joining_rule()'::regprocedure)
              and tgrelid <> 'public.games'::regclass) then
    raise exception 'KAN-866 pre: a disabled-trigger function is attached elsewhere';
  end if;
  if exists (select 1 from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null) then
    raise exception 'KAN-866 pre: a game has no events parent';
  end if;
  if to_regclass('public._kan866_games_backup') is not null then
    raise exception 'KAN-866 pre: backup table already exists';
  end if;
end
$pre$;

-- 2. backup ----------------------------------------------------------------------------------------------------------
CREATE TABLE public._kan866_games_backup AS
SELECT id, creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility, join_policy,
       is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id, venue_id, min_skill, max_skill,
       joining_rule, cost_cover, request_id, created_at, updated_at, now() AS backed_up_at
  FROM public.games;
ALTER TABLE public._kan866_games_backup ADD PRIMARY KEY (id);
ALTER TABLE public._kan866_games_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._kan866_games_backup FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON TABLE public._kan866_games_backup IS
  'KAN-866 rollback data: the 22 games columns as they stood before the drop (values equal to public.events). Read only by postgres; see supabase/schema/rollback/kan866_ROLLBACK_restore_games_shared_columns.sql.';

-- 3. disabled triggers -----------------------------------------------------------------------------------------------
DROP TRIGGER trg_game_created ON public.games;
DROP TRIGGER trg_games_inherit_geo ON public.games;
DROP TRIGGER trg_games_inherit_venue_geo ON public.games;
DROP TRIGGER trg_games_sync_joining_rule ON public.games;
DROP FUNCTION public.handle_game_created();
DROP FUNCTION public.fn_games_inherit_geo();
DROP FUNCTION public.trg_fn_games_inherit_venue_geo();
DROP FUNCTION public.fn_games_sync_joining_rule();

-- 4. the KAN-947 mirror ----------------------------------------------------------------------------------------------
DROP TRIGGER trg_00_kan947_games_from_events ON public.games;
DROP TRIGGER trg_zz_kan947_games_from_events ON public.games;
DROP FUNCTION public.kan947_games_from_events();
DROP TRIGGER trg_zz_kan947_events_game_mirror ON public.events;
DROP FUNCTION public.kan947_events_game_mirror();

-- 5. Realtime publication --------------------------------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime DROP TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.games (id, event_changed_at);

-- 6. dependents, then the columns ------------------------------------------------------------------------------------
DROP INDEX public.idx_games_time;
DROP INDEX public.idx_games_host;
DROP INDEX public.idx_games_visibility;
DROP INDEX public.idx_games_cancelled;
DROP INDEX public.idx_games_is_cancelled;
DROP INDEX public.idx_games_start_at;
DROP INDEX public.idx_games_title_prefix;
DROP INDEX public.idx_games_geo;
DROP INDEX public.idx_games_area;
DROP INDEX public.games_creator_request_id_key;
DROP INDEX public.games_series_id_start_at_key;

ALTER TABLE public.games DROP CONSTRAINT fk_games_geo;
ALTER TABLE public.games DROP CONSTRAINT games_area_id_fkey;
ALTER TABLE public.games DROP CONSTRAINT games_creator_profile_id_fkey;
ALTER TABLE public.games DROP CONSTRAINT games_creator_user_id_fkey;
ALTER TABLE public.games DROP CONSTRAINT games_sport_id_fkey;
ALTER TABLE public.games DROP CONSTRAINT games_venue_id_fkey;
ALTER TABLE public.games DROP CONSTRAINT games_capacity_check;
ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_check;
ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_logic;
ALTER TABLE public.games DROP CONSTRAINT games_join_policy_check;
ALTER TABLE public.games DROP CONSTRAINT games_join_policy_chk;
ALTER TABLE public.games DROP CONSTRAINT games_joining_rule_check;
ALTER TABLE public.games DROP CONSTRAINT games_listing_visibility_check;
ALTER TABLE public.games DROP CONSTRAINT games_location_required;
ALTER TABLE public.games DROP CONSTRAINT games_max_skill_check;
ALTER TABLE public.games DROP CONSTRAINT games_min_skill_check;

ALTER TABLE public.games
  DROP COLUMN creator_profile_id RESTRICT,
  DROP COLUMN creator_user_id RESTRICT,
  DROP COLUMN title RESTRICT,
  DROP COLUMN start_at RESTRICT,
  DROP COLUMN end_at RESTRICT,
  DROP COLUMN capacity RESTRICT,
  DROP COLUMN listing_visibility RESTRICT,
  DROP COLUMN join_policy RESTRICT,
  DROP COLUMN is_cancelled RESTRICT,
  DROP COLUMN cancelled_at RESTRICT,
  DROP COLUMN cancelled_reason RESTRICT,
  DROP COLUMN sport_id RESTRICT,
  DROP COLUMN area_id RESTRICT,
  DROP COLUMN geo_location_id RESTRICT,
  DROP COLUMN venue_id RESTRICT,
  DROP COLUMN min_skill RESTRICT,
  DROP COLUMN max_skill RESTRICT,
  DROP COLUMN joining_rule RESTRICT,
  DROP COLUMN cost_cover RESTRICT,
  DROP COLUMN request_id RESTRICT,
  DROP COLUMN created_at RESTRICT,
  DROP COLUMN updated_at RESTRICT;

do $post$
declare
  n int;
  v_cols text;
begin
  select count(*) into n from pg_attribute
   where attrelid = 'public.games'::regclass and not attisdropped
     and attname in ('creator_profile_id','creator_user_id','title','start_at','end_at','capacity','listing_visibility',
                     'join_policy','is_cancelled','cancelled_at','cancelled_reason','sport_id','area_id','geo_location_id',
                     'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id','created_at','updated_at');
  if n <> 0 then raise exception 'KAN-866 post: % shared columns still on games', n; end if;
  if (select count(*) from public._kan866_games_backup) <> (select count(*) from public.games)
     or exists (select 1 from public.games g left join public._kan866_games_backup b on b.id = g.id where b.id is null) then
    raise exception 'KAN-866 post: backup does not cover every game';
  end if;
  if exists (select 1 from information_schema.role_table_grants where table_schema = 'public' and table_name = '_kan866_games_backup'
              and grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role'))
     or not (select relrowsecurity from pg_class where oid = 'public._kan866_games_backup'::regclass) then
    raise exception 'KAN-866 post: backup table is not closed';
  end if;
  if exists (select 1 from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null) then
    raise exception 'KAN-866 post: a game has no events parent';
  end if;
  select string_agg(a.attname, ',' order by a.attnum) into v_cols
    from pg_publication_rel pr join pg_publication p on p.oid = pr.prpubid
    join pg_attribute a on a.attrelid = pr.prrelid and a.attnum = any (pr.prattrs)
   where p.pubname = 'supabase_realtime' and pr.prrelid = 'public.games'::regclass;
  if v_cols is distinct from 'id,event_changed_at' then
    raise exception 'KAN-866 post: games publication list is %', v_cols;
  end if;
  if exists (select 1 from pg_trigger where tgrelid in ('public.games'::regclass, 'public.events'::regclass) and tgname ~ 'kan947_(games_from_events|events_game_mirror)') then
    raise exception 'KAN-866 post: a kan947 mirror trigger is still attached';
  end if;
end
$post$;
