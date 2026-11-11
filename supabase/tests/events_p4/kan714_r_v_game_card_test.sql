-- KAN-899 (KAN-714 stage R, KAN-866 follow-up): public.v_game_card must not depend on any of the 22 games columns
-- that KAN-866 removes. KAN-899 was ruled satisfied without a migration: the current view
-- (20261105140000_kan715_v_game_card_my_games_event_id.sql) reads all 22 fields from public.events, not games.
-- This is the regression guard for that ruling.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end; it writes nothing but two session TEMP views.
-- pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or run it with pg_prove.
-- It asserts through pg_depend (the view's rewrite rule -> columns of public.games), which is what makes a later
-- ALTER TABLE public.games DROP COLUMN refuse or cascade; a body grep is not used.
--
-- Run (local throwaway Postgres with pgTAP loaded and the view built from the repo's current definition):
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_r_v_game_card_test.sql
--
-- Read-only live check for Memphis (must return 0 rows):
--   SELECT a.attname
--     FROM pg_rewrite rw
--     JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
--     JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
--    WHERE rw.ev_class = 'public.v_game_card'::regclass
--      AND d.refobjid = 'public.games'::regclass
--      AND a.attname = ANY ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
--                             join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
--                             venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}');
\set ON_ERROR_STOP 1
BEGIN;
SELECT plan(5);

-- The 22 KAN-866 columns, and the view's games-column dependencies, as reusable temp views.
CREATE TEMP VIEW k899_removed (col) AS
  SELECT unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                  join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                  venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);

CREATE TEMP VIEW k899_deps (col) AS
  SELECT DISTINCT a.attname::text
    FROM pg_rewrite rw
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = 'public.v_game_card'::regclass
     AND d.refobjid = 'public.games'::regclass;

SELECT has_view('public', 'v_game_card', 'R0 public.v_game_card exists');

SELECT is((SELECT count(DISTINCT col)::int FROM k899_removed), 22,
  'R1 the KAN-866 list holds 22 distinct column names');

-- Sanity: the probe sees real games dependencies, so an empty intersection below is not vacuous.
SELECT ok(EXISTS (SELECT 1 FROM k899_deps WHERE col = 'event_id'),
  'R2 sanity: v_game_card depends on games.event_id (pg_depend sees the view''s games columns)');

SELECT cmp_ok((SELECT count(*)::int FROM k899_deps), '>', 0,
  'R3 sanity: v_game_card depends on at least one games column');

SELECT is_empty(
  $$SELECT col FROM k899_deps WHERE col IN (SELECT col FROM k899_removed) ORDER BY col$$,
  'R4 KAN-899: v_game_card depends on none of the 22 KAN-866 games columns');

SELECT * FROM finish();
ROLLBACK;
