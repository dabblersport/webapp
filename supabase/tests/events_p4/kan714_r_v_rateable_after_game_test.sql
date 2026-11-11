-- KAN-902 (KAN-714 stage R, KAN-866 follow-up): public.v_rateable_after_game must not depend on any of the 22 games
-- columns that KAN-866 removes. KAN-902 needs no migration: since B03
-- (20261104100300_kan714_b03_views_rating_host_metrics.sql) the view reads host_user_id and end_at from public.events
-- (events.creator_user_id, events.end_at), and its only games dependencies are games.event_id and games.id.
-- 20261105100000_kan714_events_parent_reads.sql re-creates it with the same body. This is the regression guard.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end; it writes nothing but two session TEMP views.
-- pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or run it with pg_prove.
-- It asserts through pg_depend (the view's rewrite rule -> columns of public.games), which is what makes a later
-- ALTER TABLE public.games DROP COLUMN refuse or cascade; a body grep is not used.
--
-- Run (local throwaway Postgres with pgTAP loaded and the view built from the repo's current definition):
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_r_v_rateable_after_game_test.sql
--
-- Read-only live check for Memphis (must return 0 rows):
--   SELECT a.attname
--     FROM pg_rewrite rw
--     JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
--     JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
--    WHERE rw.ev_class = 'public.v_rateable_after_game'::regclass
--      AND d.refobjid = 'public.games'::regclass
--      AND a.attname = ANY ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
--                             join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
--                             venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}');
\set ON_ERROR_STOP 1
BEGIN;
SELECT plan(6);

-- The 22 KAN-866 columns, and the view's games-column dependencies, as reusable temp views.
CREATE TEMP VIEW k902_removed (col) AS
  SELECT unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                  join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                  venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);

CREATE TEMP VIEW k902_deps (col) AS
  SELECT DISTINCT a.attname::text
    FROM pg_rewrite rw
    JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = 'public.v_rateable_after_game'::regclass
     AND d.refobjid = 'public.games'::regclass;

SELECT has_view('public', 'v_rateable_after_game', 'R0 public.v_rateable_after_game exists');

SELECT is((SELECT count(DISTINCT col)::int FROM k902_removed), 22,
  'R1 the KAN-866 list holds 22 distinct column names');

-- Sanity: the probe sees real games dependencies, so an empty intersection below is not vacuous.
SELECT ok(EXISTS (SELECT 1 FROM k902_deps WHERE col = 'event_id'),
  'R2 sanity: v_rateable_after_game depends on games.event_id (pg_depend sees the view''s games columns)');

SELECT ok(EXISTS (SELECT 1 FROM k902_deps WHERE col = 'id'),
  'R3 sanity: v_rateable_after_game depends on games.id');

SELECT cmp_ok((SELECT count(*)::int FROM k902_deps), '>', 0,
  'R4 sanity: v_rateable_after_game depends on at least one games column');

SELECT is_empty(
  $$SELECT col FROM k902_deps WHERE col IN (SELECT col FROM k902_removed) ORDER BY col$$,
  'R5 KAN-902: v_rateable_after_game depends on none of the 22 KAN-866 games columns');

SELECT * FROM finish();
ROLLBACK;
