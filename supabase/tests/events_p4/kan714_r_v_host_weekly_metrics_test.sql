-- KAN-901 (KAN-714 chain stage R): read-only regression guard for public.v_host_weekly_metrics.
--
-- RULING dreq-5a8d606b (task_owner): KAN-901 is satisfied without a migration. B07
-- (20261104100700_kan714_b07_sport_overview_counts.sql, KAN-726) already moved the view onto public.events; from
-- public.games it reads only id (count key) and event_id (join key). This file guards the KAN-866 DROP at the end of
-- the chain: it fails if the view ever depends again on any of the 22 games columns KAN-866 drops.
--
-- READ-ONLY. It writes nothing, so it is safe on the live database too (Memphis runs it, or the LIVE query below,
-- during integration). Output is TAP; exit status is non-zero when any case fails.
--
-- Cases:
--   T1 the view exists.
--   T2 the view reads public.events (pg_depend through its rewrite rule).
--   T3 the view depends on none of the 22 KAN-866 games columns.
--   T4 its only games dependencies are id and event_id.
--
-- Local chain (throwaway PG16, never port 5432), as tests/events_p2/kan714_b07_sport_overview.sql plus 6c:
--   events_p1 harness + seed, events_p2 harness, events_p2_kan713 harness, events_p2_kan714 harness,
--   migrations 20261101140000, 20261102110000, 20261102120000 (+ backfill + validate), 20261103100000,
--   20261103105000, 20261103110000, 20261104100000, 20261104110000, 20261104110300, 20261104100100, 20261104100200, 20261104100700,
--   then:  psql -X -h /tmp -p <port> -U postgres -d <db> -v ON_ERROR_STOP=1 -f <this file>
--
-- LIVE (read-only, for Memphis after integration; expect zero rows):
--   SELECT DISTINCT a.attname
--     FROM pg_depend d
--     JOIN pg_rewrite rw ON rw.oid = d.objid
--     JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
--    WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass
--      AND d.refobjid = 'public.games'::regclass
--      AND a.attname NOT IN ('id', 'event_id');
\set ON_ERROR_STOP 1
SET client_min_messages = notice;
BEGIN READ ONLY;

DO $t$
DECLARE
  c_drop CONSTANT text[] := ARRAY['creator_profile_id', 'creator_user_id', 'title', 'start_at', 'end_at', 'capacity',
    'listing_visibility', 'join_policy', 'is_cancelled', 'cancelled_at', 'cancelled_reason', 'sport_id', 'area_id',
    'geo_location_id', 'venue_id', 'min_skill', 'max_skill', 'joining_rule', 'cost_cover', 'request_id',
    'created_at', 'updated_at'];
  v_fail int := 0;
  v_bad  text;
BEGIN
  RAISE NOTICE '1..4';
  IF cardinality(c_drop) <> 22 THEN RAISE EXCEPTION 'KAN-901: drop list has % columns, expected 22', cardinality(c_drop); END IF;

  IF to_regclass('public.v_host_weekly_metrics') IS NULL THEN
    RAISE NOTICE 'not ok 1 - public.v_host_weekly_metrics exists';
    RAISE EXCEPTION 'KAN-901: 1 of 4 failed (view missing)';
  END IF;
  RAISE NOTICE 'ok 1 - public.v_host_weekly_metrics exists';

  IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
              WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE NOTICE 'ok 2 - the view reads public.events';
  ELSE
    RAISE NOTICE 'not ok 2 - the view reads public.events'; v_fail := v_fail + 1;
  END IF;

  SELECT string_agg(DISTINCT a.attname, ',' ORDER BY a.attname) INTO v_bad
    FROM pg_depend d
    JOIN pg_rewrite rw ON rw.oid = d.objid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass
     AND d.refobjid = 'public.games'::regclass
     AND a.attname = ANY (c_drop);
  IF v_bad IS NULL THEN
    RAISE NOTICE 'ok 3 - the view depends on none of the 22 KAN-866 games columns';
  ELSE
    RAISE NOTICE 'not ok 3 - the view depends on none of the 22 KAN-866 games columns (reads: %)', v_bad; v_fail := v_fail + 1;
  END IF;

  SELECT string_agg(DISTINCT a.attname, ',' ORDER BY a.attname) INTO v_bad
    FROM pg_depend d
    JOIN pg_rewrite rw ON rw.oid = d.objid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass
     AND d.refobjid = 'public.games'::regclass
     AND a.attname NOT IN ('id', 'event_id');
  IF v_bad IS NULL THEN
    RAISE NOTICE 'ok 4 - the only games columns it reads are id and event_id';
  ELSE
    RAISE NOTICE 'not ok 4 - the only games columns it reads are id and event_id (also: %)', v_bad; v_fail := v_fail + 1;
  END IF;

  IF v_fail > 0 THEN RAISE EXCEPTION 'KAN-901: % of 4 failed', v_fail; END IF;
END
$t$;

ROLLBACK;
