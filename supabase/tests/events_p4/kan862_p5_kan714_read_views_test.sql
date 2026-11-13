-- KAN-862 P5 live proof for supabase/migrations/20261113144816_kan862_p5_kan714_read_views.sql (version 20261113144816, as
-- recorded in supabase_migrations.schema_migrations).
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- READ-ONLY: it writes nothing but session TEMP tables, which the final ROLLBACK discards.
--
-- DEFECT (Z01 gate G6): public.kan714_games_read read games.search_tsv and public.kan714_meetups_read read
-- meetups.search_tsv. Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql) drops both, so G6 refused.
-- The views keep their search_tsv column (rpc_search_entities reads gm.search_tsv from kan714_games_read;
-- rpc_unified_search_sectioned reads m.search_tsv from kan714_meetups_read), now sourced from the replacement:
--   games:   events.search_tsv (events_set_search_tsv: to_tsvector('simple', unaccent(title)), same as the games trigger)
--   meetups: computed in the view exactly as meetups_search_tsv_trigger did, title(A) || description(B) ||
--            location_name(C), from events.title and the retained meetups.description / meetups.location_name.
--
--   T1/T2 column list (name:type, in order) unchanged for each view
--   T3/T4 row set equals the legacy row set (games|meetups JOIN events on event_id and event_type), compared
--         through a TEMP snapshot taken inside this transaction: same count, no id missing either way
--   T5/T6 search_tsv equals the legacy table's search_tsv on every row, while that column still exists
--         (after Z01 drops it the check reports 'skipped: source column dropped' and passes)
--   T7/T8 owner, ACL and reloptions unchanged (owner postgres, {postgres=arwdDxtm/postgres}, no reloptions):
--         not anon-readable, so SCHEMA.md 2f needs no entry
--   T9/T10 no pg_depend edge from the view to any games/meetups column outside the Z01 retained lists  (RED before)
--   T11   sanity: the dependency probe sees the views' retained columns (event_id), so T9/T10 are not vacuous
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862p5_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;

-- Snapshots taken inside the transaction.
CREATE TEMP TABLE k862p5_g_legacy ON COMMIT DROP AS
  SELECT g.id FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game';
CREATE TEMP TABLE k862p5_m_legacy ON COMMIT DROP AS
  SELECT m.id FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup';
CREATE TEMP TABLE k862p5_g_view ON COMMIT DROP AS SELECT id, search_tsv FROM public.kan714_games_read;
CREATE TEMP TABLE k862p5_m_view ON COMMIT DROP AS SELECT id, search_tsv FROM public.kan714_meetups_read;

CREATE FUNCTION pg_temp.k862p5_cols(v regclass) RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT string_agg(attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attnum)
    FROM pg_attribute WHERE attrelid = v AND attnum > 0 AND NOT attisdropped
$f$;

-- Rows whose view search_tsv differs from the legacy column; NULL when the legacy column no longer exists.
CREATE FUNCTION pg_temp.k862p5_tsv_diff(tbl text) RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE n bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = ('public.' || tbl)::regclass
                    AND attname = 'search_tsv' AND NOT attisdropped) THEN
    RETURN NULL;
  END IF;
  EXECUTE format('SELECT count(*) FROM %I v JOIN public.%I t ON t.id = v.id WHERE v.search_tsv IS DISTINCT FROM t.search_tsv',
                 CASE tbl WHEN 'games' THEN 'k862p5_g_view' ELSE 'k862p5_m_view' END, tbl) INTO n;
  RETURN n;
END $f$;

-- Columns of games/meetups each view depends on that Z01 drops (Z01 G6 retained lists, verbatim).
CREATE FUNCTION pg_temp.k862p5_bad_deps(v regclass) RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT string_agg(DISTINCT d.refobjid::regclass::text || '.' || a.attname, ',')
    FROM pg_depend d
    JOIN pg_rewrite r ON d.classid = 'pg_rewrite'::regclass AND d.objid = r.oid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE r.ev_class = v AND d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND d.refobjsubid > 0
     AND NOT (d.refobjid = 'public.games'::regclass AND a.attname = ANY ('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'))
     AND NOT (d.refobjid = 'public.meetups'::regclass AND a.attname = ANY ('{id,event_id,vibe_key,meta,host_actor_id,members_only,description,location_name,is_indoor}'))
$f$;

INSERT INTO k862p5_tap SELECT 1, pg_temp.k862p5_cols('public.kan714_games_read') =
  'id:uuid,game_type:text,title:text,creator_profile_id:uuid,creator_user_id:uuid,venue_space_id:uuid,start_at:timestamp with time zone,end_at:timestamp with time zone,capacity:integer,listing_visibility:text,join_policy:text,allow_spectators:boolean,min_skill:integer,max_skill:integer,rules:jsonb,is_cancelled:boolean,cancelled_at:timestamp with time zone,cancelled_reason:text,created_at:timestamp with time zone,updated_at:timestamp with time zone,squad_id:uuid,search_tsv:tsvector,sport_specific_data:jsonb,allows_waitlist:boolean,sport_id:uuid,geo_location_id:uuid,area_id:uuid,venue_id:uuid,sport_variant_id:uuid,bench_slots:integer,joining_rule:text,cost_cover:text,price_aed:numeric(10,2),request_id:uuid,series_id:uuid,event_id:uuid',
  'kan714_games_read column list unchanged (36 columns)', md5(pg_temp.k862p5_cols('public.kan714_games_read'));
INSERT INTO k862p5_tap SELECT 2, pg_temp.k862p5_cols('public.kan714_meetups_read') =
  'id:uuid,creator_profile_id:uuid,creator_user_id:uuid,title:text,description:text,vibe_key:text,listing_visibility:text,rsvp_policy:text,capacity:integer,start_at:timestamp with time zone,end_at:timestamp with time zone,is_cancelled:boolean,meta:jsonb,created_at:timestamp with time zone,updated_at:timestamp with time zone,host_actor_id:uuid,search_tsv:tsvector,geo_location_id:uuid,sport_id:uuid,area_id:uuid,venue_id:uuid,min_skill:integer,max_skill:integer,members_only:boolean,joining_rule:text,cost_cover:text,location_name:text,is_indoor:boolean,request_id:uuid,event_id:uuid',
  'kan714_meetups_read column list unchanged (30 columns)', md5(pg_temp.k862p5_cols('public.kan714_meetups_read'));

INSERT INTO k862p5_tap SELECT 3,
  (SELECT count(*) FROM k862p5_g_view) = (SELECT count(*) FROM k862p5_g_legacy)
  AND NOT EXISTS (SELECT id FROM k862p5_g_legacy EXCEPT SELECT id FROM k862p5_g_view)
  AND NOT EXISTS (SELECT id FROM k862p5_g_view EXCEPT SELECT id FROM k862p5_g_legacy),
  'kan714_games_read row set equals the legacy games JOIN events snapshot',
  'view ' || (SELECT count(*) FROM k862p5_g_view) || ' legacy ' || (SELECT count(*) FROM k862p5_g_legacy);
INSERT INTO k862p5_tap SELECT 4,
  (SELECT count(*) FROM k862p5_m_view) = (SELECT count(*) FROM k862p5_m_legacy)
  AND NOT EXISTS (SELECT id FROM k862p5_m_legacy EXCEPT SELECT id FROM k862p5_m_view)
  AND NOT EXISTS (SELECT id FROM k862p5_m_view EXCEPT SELECT id FROM k862p5_m_legacy),
  'kan714_meetups_read row set equals the legacy meetups JOIN events snapshot',
  'view ' || (SELECT count(*) FROM k862p5_m_view) || ' legacy ' || (SELECT count(*) FROM k862p5_m_legacy);

INSERT INTO k862p5_tap SELECT 5, coalesce(d, 0) = 0, 'kan714_games_read.search_tsv equals games.search_tsv on every row',
  coalesce(d::text || ' rows differ', 'skipped: source column dropped') FROM (SELECT pg_temp.k862p5_tsv_diff('games') d) x;
INSERT INTO k862p5_tap SELECT 6, coalesce(d, 0) = 0, 'kan714_meetups_read.search_tsv equals meetups.search_tsv on every row',
  coalesce(d::text || ' rows differ', 'skipped: source column dropped') FROM (SELECT pg_temp.k862p5_tsv_diff('meetups') d) x;

INSERT INTO k862p5_tap SELECT 6 + i,
  c.relkind = 'v' AND pg_get_userbyid(c.relowner) = 'postgres' AND c.relacl::text = '{postgres=arwdDxtm/postgres}'
  AND c.reloptions IS NULL
  AND NOT has_table_privilege('anon', c.oid, 'SELECT') AND NOT has_table_privilege('authenticated', c.oid, 'SELECT'),
  c.relname || ' owner, ACL and reloptions unchanged; not readable by anon/authenticated',
  pg_get_userbyid(c.relowner) || ' ' || coalesce(c.relacl::text, 'null') || ' ' || coalesce(c.reloptions::text, 'no reloptions')
  FROM (VALUES (1, 'public.kan714_games_read'::regclass), (2, 'public.kan714_meetups_read'::regclass)) v(i, r)
  JOIN pg_class c ON c.oid = v.r;

INSERT INTO k862p5_tap SELECT 8 + i, pg_temp.k862p5_bad_deps(r) IS NULL,
  r::text || ' depends on no games/meetups column that Z01 drops', coalesce(pg_temp.k862p5_bad_deps(r), 'none')
  FROM (VALUES (1, 'public.kan714_games_read'::regclass), (2, 'public.kan714_meetups_read'::regclass)) v(i, r);

INSERT INTO k862p5_tap SELECT 11,
  (SELECT count(*) FROM pg_depend d JOIN pg_rewrite r ON d.classid = 'pg_rewrite'::regclass AND d.objid = r.oid
     JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
    WHERE r.ev_class IN ('public.kan714_games_read'::regclass, 'public.kan714_meetups_read'::regclass)
      AND d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND a.attname = 'event_id') = 2,
  'sanity: the dependency probe sees both views'' event_id edges', NULL;

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k862p5_tap) t
ORDER BY n;
ROLLBACK;
