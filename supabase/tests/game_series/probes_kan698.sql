-- KAN-698 probes: v_game_card gained series_id, series_frequency, series_ends_on
-- (migration 20261101120000). READ-ONLY against live: SELECTs inside BEGIN..ROLLBACK, no writes.
-- Run 2026-11-01 on project wtncuzcskpigqpmnxwws. Recorded output is under each probe.

-- P1 anon: the three columns select; null-value case (no series data exists yet)
begin; set local role anon;
select 'anon' as role, count(*) as rows_visible, count(series_id) as series_id_nonnull,
  count(series_frequency) as freq_nonnull, count(series_ends_on) as ends_nonnull,
  (select pg_typeof(series_frequency)::text from public.v_game_card limit 1) as freq_type
from public.v_game_card;
rollback;
-- OUTPUT: anon | rows_visible 227 | series_id_nonnull 0 | freq_nonnull 0 | ends_nonnull 0 | freq_type text

-- P2 authenticated: same
begin; set local role authenticated;
select 'authenticated' as role, count(*) as rows_visible, count(series_id) as series_id_nonnull,
  count(series_frequency) as freq_nonnull, count(series_ends_on) as ends_nonnull,
  (select pg_typeof(series_frequency)::text from public.v_game_card limit 1) as freq_type
from public.v_game_card;
rollback;
-- OUTPUT: authenticated | rows_visible 227 | series_id_nonnull 0 | freq_nonnull 0 | ends_nonnull 0 | freq_type text

-- P3 column count/order, options, grants, series data
select (select count(*) from pg_attribute where attrelid='public.v_game_card'::regclass and attnum>0 and not attisdropped) as total_cols,
  (select string_agg(attname, ',' order by attnum) from pg_attribute where attrelid='public.v_game_card'::regclass and attnum between 1 and 51 and not attisdropped) as first_51,
  (select string_agg(attnum||':'||attname||':'||format_type(atttypid,atttypmod), ',' order by attnum) from pg_attribute where attrelid='public.v_game_card'::regclass and attnum>51 and not attisdropped) as appended,
  (select coalesce(reloptions::text,'NULL') from pg_class where oid='public.v_game_card'::regclass) as reloptions,
  (select string_agg(grantee||':'||privilege_type, ',' order by grantee, privilege_type) from information_schema.role_table_grants where table_schema='public' and table_name='v_game_card' and grantee in ('anon','authenticated')) as grants,
  (select count(*) from public.game_series) as series_rows,
  (select count(*) from public.games where series_id is not null) as series_games;
-- OUTPUT:
-- total_cols 54
-- first_51 (before = 20261008140000 Step 3, 51 columns, unchanged and in the same order):
--   id,title,game_type,start_at,end_at,capacity,bench_slots,total_slots,min_skill,max_skill,listing_visibility,
--   join_policy,allow_spectators,allows_waitlist,is_cancelled,rules,created_at,updated_at,sport_id,sport_key,
--   sport_name_en,sport_name_ar,sport_variant_id,variant_key,variant_name_en,variant_name_ar,required_players,
--   players_per_side,creator_profile_id,creator_username,creator_display_name,creator_avatar_url,geo_location_id,
--   area_id,area_name,venue_space_id,venue_id,venue_space_name,venue_name,joining_rule,cost_cover,roster_count,
--   is_creator,is_joined,host_verified,liked_by_me,latitude,longitude,favorite_count,favourited_by_me,price_aed
-- appended: 52:series_id:uuid,53:series_frequency:text,54:series_ends_on:date
-- reloptions NULL (not security_invoker; unchanged)
-- grants anon:REFERENCES,anon:SELECT,anon:TRIGGER,authenticated:REFERENCES,authenticated:SELECT,authenticated:TRIGGER (unchanged)
-- series_rows 0 | series_games 0  -> only the null-value case is observable live; non-null path not exercised
