-- KAN-777 (KAN-718 D09): final duplicate-count, parity and invariant precheck before the destructive step.
-- READ-ONLY. One READ ONLY transaction, no temp tables, no writes, ends in ROLLBACK.
-- Run as a role that bypasses RLS (superuser / BYPASSRLS): meetups is FORCE RLS and events is closed to the
-- API roles, so any other role would count a partial population and report false parity. The guard refuses.
-- Expected on a clean database: every BLOCK row has n = 0, the counts rows agree, and the last row says
-- d09_ok = true. Any BLOCK row with n > 0 means: do NOT run the destructive step.
-- STATUS: authored; executed only on a LOCAL throwaway Postgres 16 (see KAN718_D09_PRECHECK.md). Never run
-- against production by this ticket; the CEO/ops run on the target is a separate, authorised step.
--
-- It stands alone: it does not use public.kan711_events_parity or its mapping functions, so a defect in
-- those cannot hide a mismatch here. The mapping rules it checks are written out below.
--   games   -> events: every mirrored column 1:1; min_skill/max_skill integer -> smallint.
--   meetups -> events: rsvp_policy is join_policy; cancelled_at and cancelled_reason are always NULL
--              (meetups has neither column); every other mirrored column 1:1.
--   Nulls, ids and timestamps are compared with IS DISTINCT FROM: NULL = NULL is parity, a value invented
--   where legacy has NULL is a mismatch.

BEGIN TRANSACTION READ ONLY;

-- 0. Guard.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-718 D09: role % does not bypass RLS; the precheck would undercount meetups', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'games'   AND column_name = 'event_id')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'meetups' AND column_name = 'event_id') THEN
    RAISE EXCEPTION 'KAN-718 D09: public.events and games/meetups.event_id must exist (KAN-710 not applied)';
  END IF;
END $$;

-- 1. Every check, one row each. severity BLOCK = must be 0 before the destructive step; INFO = reported only.
WITH
-- 1a. Per-field parity, games vs events (joined on id; a missing event is a separate check).
gf AS (
  SELECT g.id,
         ARRAY[
           CASE WHEN e.event_type         IS DISTINCT FROM 'game'                    THEN 'event_type' END,
           CASE WHEN e.title              IS DISTINCT FROM g.title                   THEN 'title' END,
           CASE WHEN e.creator_profile_id IS DISTINCT FROM g.creator_profile_id      THEN 'creator_profile_id' END,
           CASE WHEN e.creator_user_id    IS DISTINCT FROM g.creator_user_id         THEN 'creator_user_id' END,
           CASE WHEN e.sport_id           IS DISTINCT FROM g.sport_id                THEN 'sport_id' END,
           CASE WHEN e.start_at           IS DISTINCT FROM g.start_at                THEN 'start_at' END,
           CASE WHEN e.end_at             IS DISTINCT FROM g.end_at                  THEN 'end_at' END,
           CASE WHEN e.capacity           IS DISTINCT FROM g.capacity                THEN 'capacity' END,
           CASE WHEN e.venue_id           IS DISTINCT FROM g.venue_id                THEN 'venue_id' END,
           CASE WHEN e.geo_location_id    IS DISTINCT FROM g.geo_location_id         THEN 'geo_location_id' END,
           CASE WHEN e.area_id            IS DISTINCT FROM g.area_id                 THEN 'area_id' END,
           CASE WHEN e.listing_visibility IS DISTINCT FROM g.listing_visibility      THEN 'listing_visibility' END,
           CASE WHEN e.join_policy        IS DISTINCT FROM g.join_policy             THEN 'join_policy' END,
           CASE WHEN e.min_skill          IS DISTINCT FROM g.min_skill::smallint     THEN 'min_skill' END,
           CASE WHEN e.max_skill          IS DISTINCT FROM g.max_skill::smallint     THEN 'max_skill' END,
           CASE WHEN e.joining_rule       IS DISTINCT FROM g.joining_rule            THEN 'joining_rule' END,
           CASE WHEN e.cost_cover         IS DISTINCT FROM g.cost_cover              THEN 'cost_cover' END,
           CASE WHEN e.is_cancelled       IS DISTINCT FROM g.is_cancelled            THEN 'is_cancelled' END,
           CASE WHEN e.cancelled_at       IS DISTINCT FROM g.cancelled_at            THEN 'cancelled_at' END,
           CASE WHEN e.cancelled_reason   IS DISTINCT FROM g.cancelled_reason        THEN 'cancelled_reason' END,
           CASE WHEN e.request_id         IS DISTINCT FROM g.request_id              THEN 'request_id' END,
           CASE WHEN e.created_at         IS DISTINCT FROM g.created_at              THEN 'created_at' END,
           CASE WHEN e.updated_at         IS DISTINCT FROM g.updated_at              THEN 'updated_at' END
         ] AS bad
  FROM public.games g JOIN public.events e ON e.id = g.id
),
-- 1b. Per-field parity, meetups vs events.
mf AS (
  SELECT m.id,
         ARRAY[
           CASE WHEN e.event_type         IS DISTINCT FROM 'meetup'                  THEN 'event_type' END,
           CASE WHEN e.title              IS DISTINCT FROM m.title                   THEN 'title' END,
           CASE WHEN e.creator_profile_id IS DISTINCT FROM m.creator_profile_id      THEN 'creator_profile_id' END,
           CASE WHEN e.creator_user_id    IS DISTINCT FROM m.creator_user_id         THEN 'creator_user_id' END,
           CASE WHEN e.sport_id           IS DISTINCT FROM m.sport_id                THEN 'sport_id' END,
           CASE WHEN e.start_at           IS DISTINCT FROM m.start_at                THEN 'start_at' END,
           CASE WHEN e.end_at             IS DISTINCT FROM m.end_at                  THEN 'end_at' END,
           CASE WHEN e.capacity           IS DISTINCT FROM m.capacity                THEN 'capacity' END,
           CASE WHEN e.venue_id           IS DISTINCT FROM m.venue_id                THEN 'venue_id' END,
           CASE WHEN e.geo_location_id    IS DISTINCT FROM m.geo_location_id         THEN 'geo_location_id' END,
           CASE WHEN e.area_id            IS DISTINCT FROM m.area_id                 THEN 'area_id' END,
           CASE WHEN e.listing_visibility IS DISTINCT FROM m.listing_visibility      THEN 'listing_visibility' END,
           CASE WHEN e.join_policy        IS DISTINCT FROM m.rsvp_policy             THEN 'join_policy(rsvp_policy)' END,
           CASE WHEN e.min_skill          IS DISTINCT FROM m.min_skill::smallint     THEN 'min_skill' END,
           CASE WHEN e.max_skill          IS DISTINCT FROM m.max_skill::smallint     THEN 'max_skill' END,
           CASE WHEN e.joining_rule       IS DISTINCT FROM m.joining_rule            THEN 'joining_rule' END,
           CASE WHEN e.cost_cover         IS DISTINCT FROM m.cost_cover              THEN 'cost_cover' END,
           CASE WHEN e.is_cancelled       IS DISTINCT FROM m.is_cancelled            THEN 'is_cancelled' END,
           CASE WHEN e.cancelled_at       IS NOT NULL                                THEN 'cancelled_at(must be NULL)' END,
           CASE WHEN e.cancelled_reason   IS NOT NULL                                THEN 'cancelled_reason(must be NULL)' END,
           CASE WHEN e.request_id         IS DISTINCT FROM m.request_id              THEN 'request_id' END,
           CASE WHEN e.created_at         IS DISTINCT FROM m.created_at              THEN 'created_at' END,
           CASE WHEN e.updated_at         IS DISTINCT FROM m.updated_at              THEN 'updated_at' END
         ] AS bad
  FROM public.meetups m JOIN public.events e ON e.id = m.id
),
fields AS (
  SELECT 'games' AS kind, f.field, count(*) AS n
  FROM gf CROSS JOIN LATERAL unnest(gf.bad) AS f(field) WHERE f.field IS NOT NULL GROUP BY f.field
  UNION ALL
  SELECT 'meetups', f.field, count(*)
  FROM mf CROSS JOIN LATERAL unnest(mf.bad) AS f(field) WHERE f.field IS NOT NULL GROUP BY f.field
),
-- 1c. The check list.
checks(ord, id, severity, descr, n) AS (
  VALUES
  -- counts (shown as INFO rows so the two sides can be read together; BLOCK rows below enforce them)
  (10, 'count.games',            'INFO',  'public.games rows',                      (SELECT count(*) FROM public.games)),
  (11, 'count.events_game',      'INFO',  'public.events rows with event_type=game', (SELECT count(*) FROM public.events WHERE event_type = 'game')),
  (12, 'count.meetups',          'INFO',  'public.meetups rows',                    (SELECT count(*) FROM public.meetups)),
  (13, 'count.events_meetup',    'INFO',  'public.events rows with event_type=meetup', (SELECT count(*) FROM public.events WHERE event_type = 'meetup')),
  (14, 'count.events_total',     'INFO',  'public.events rows (all)',               (SELECT count(*) FROM public.events)),
  (20, 'count.games_eq_events',  'BLOCK', 'games count differs from game events (absolute difference)',
        (SELECT abs((SELECT count(*) FROM public.games) - (SELECT count(*) FROM public.events WHERE event_type = 'game')))),
  (21, 'count.meetups_eq_events','BLOCK', 'meetups count differs from meetup events (absolute difference)',
        (SELECT abs((SELECT count(*) FROM public.meetups) - (SELECT count(*) FROM public.events WHERE event_type = 'meetup')))),
  (22, 'count.events_eq_sum',    'BLOCK', 'events total differs from games + meetups (absolute difference)',
        (SELECT abs((SELECT count(*) FROM public.events) - (SELECT count(*) FROM public.games) - (SELECT count(*) FROM public.meetups)))),

  -- duplicates: nothing doubled
  (30, 'dup.events_id',          'BLOCK', 'events ids appearing more than once',
        (SELECT count(*) FROM (SELECT id FROM public.events GROUP BY id HAVING count(*) > 1) s)),
  (31, 'dup.games_event_id',     'BLOCK', 'games.event_id values shared by more than one games row',
        (SELECT count(*) FROM (SELECT event_id FROM public.games WHERE event_id IS NOT NULL GROUP BY event_id HAVING count(*) > 1) s)),
  (32, 'dup.meetups_event_id',   'BLOCK', 'meetups.event_id values shared by more than one meetups row',
        (SELECT count(*) FROM (SELECT event_id FROM public.meetups WHERE event_id IS NOT NULL GROUP BY event_id HAVING count(*) > 1) s)),
  (33, 'dup.event_both_subtypes','BLOCK', 'events linked from BOTH a games row and a meetups row',
        (SELECT count(*) FROM public.games g JOIN public.meetups m ON m.event_id = g.event_id WHERE g.event_id IS NOT NULL)),
  (34, 'dup.id_both_tables',     'BLOCK', 'ids present in both games and meetups',
        (SELECT count(*) FROM public.games g JOIN public.meetups m ON m.id = g.id)),
  (35, 'dup.request_events',     'BLOCK', 'events (event_type, creator_profile_id, request_id) keys appearing more than once',
        (SELECT count(*) FROM (SELECT 1 FROM public.events WHERE request_id IS NOT NULL
                               GROUP BY event_type, creator_profile_id, request_id HAVING count(*) > 1) s)),
  (36, 'dup.series_occurrence',  'BLOCK', 'games sharing the same (series_id, start_at)',
        (SELECT count(*) FROM (SELECT 1 FROM public.games WHERE series_id IS NOT NULL
                               GROUP BY series_id, start_at HAVING count(*) > 1) s)),

  -- identity and link invariants
  (40, 'inv.game_missing_event', 'BLOCK', 'games rows with no events row of the same id',
        (SELECT count(*) FROM public.games g WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.id))),
  (41, 'inv.meetup_missing_event','BLOCK','meetups rows with no events row of the same id',
        (SELECT count(*) FROM public.meetups m WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = m.id))),
  (42, 'inv.event_orphan',       'BLOCK', 'events rows with no games row and no meetups row',
        (SELECT count(*) FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
                                                AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id))),
  (43, 'inv.game_event_id_null', 'BLOCK', 'games rows with event_id NULL',
        (SELECT count(*) FROM public.games WHERE event_id IS NULL)),
  (44, 'inv.meetup_event_id_null','BLOCK','meetups rows with event_id NULL',
        (SELECT count(*) FROM public.meetups WHERE event_id IS NULL)),
  (45, 'inv.game_event_id_ne_id','BLOCK', 'games rows whose event_id is not their own id (ids must be unchanged)',
        (SELECT count(*) FROM public.games WHERE event_id IS NOT NULL AND event_id <> id)),
  (46, 'inv.meetup_event_id_ne_id','BLOCK','meetups rows whose event_id is not their own id',
        (SELECT count(*) FROM public.meetups WHERE event_id IS NOT NULL AND event_id <> id)),
  (47, 'inv.game_type_mismatch', 'BLOCK', 'games rows whose events row is not event_type=game',
        (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.id WHERE e.event_type <> 'game')),
  (48, 'inv.meetup_type_mismatch','BLOCK','meetups rows whose events row is not event_type=meetup',
        (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.id WHERE e.event_type <> 'meetup')),
  (49, 'inv.dangling_event_fk',  'BLOCK', 'games/meetups event_id values pointing at no events row',
        (SELECT (SELECT count(*) FROM public.games g WHERE g.event_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.event_id))
              + (SELECT count(*) FROM public.meetups m WHERE m.event_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = m.event_id)))),
  (50, 'inv.fk_not_validated',   'BLOCK', 'games/meetups_event_id_fkey constraints that are missing or NOT VALID',
        (SELECT 2 - count(*) FROM pg_constraint
          WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey') AND contype = 'f' AND convalidated)),
  (51, 'inv.meetup_cancel_cols', 'BLOCK', 'meetup events carrying cancelled_at or cancelled_reason (meetups has neither)',
        (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND (cancelled_at IS NOT NULL OR cancelled_reason IS NOT NULL))),
  (52, 'inv.time_order',         'BLOCK', 'events with updated_at earlier than created_at, or end_at not after start_at',
        (SELECT count(*) FROM public.events WHERE updated_at < created_at OR (end_at IS NOT NULL AND end_at <= start_at))),
  (53, 'inv.mirror_backlog',     'BLOCK', 'unresolved events_backfill_exceptions rows (0 when the table is absent)',
        (CASE WHEN to_regclass('public.events_backfill_exceptions') IS NULL THEN 0
              ELSE (SELECT count(*) FROM public.events_backfill_exceptions WHERE resolved_at IS NULL) END)),

  -- null preservation: a nullable column must have the same number of NULLs on both sides (nothing invented, nothing dropped)
  (60, 'null.games.title',       'BLOCK', 'games.title NULL count minus events NULL count (absolute)',
        (SELECT abs((SELECT count(*) FROM public.games WHERE title IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'game' AND title IS NULL)))),
  (61, 'null.meetups.end_at',    'BLOCK', 'meetups.end_at NULL count minus events NULL count (absolute)',
        (SELECT abs((SELECT count(*) FROM public.meetups WHERE end_at IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND end_at IS NULL)))),
  (62, 'null.meetups.capacity',  'BLOCK', 'meetups.capacity NULL count minus events NULL count (absolute)',
        (SELECT abs((SELECT count(*) FROM public.meetups WHERE capacity IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND capacity IS NULL)))),
  (63, 'null.meetups.geo_sport_area','BLOCK','meetups NULL sport_id/area_id/geo_location_id count minus events (absolute)',
        (SELECT abs((SELECT count(*) FROM public.meetups WHERE sport_id IS NULL) + (SELECT count(*) FROM public.meetups WHERE area_id IS NULL)
                  + (SELECT count(*) FROM public.meetups WHERE geo_location_id IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND sport_id IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND area_id IS NULL)
                  - (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND geo_location_id IS NULL)))),

  -- known conflicts: reported, never fixed here (KAN-708 contract). INFO only.
  (80, 'known.visibility_meetup_only','INFO','meetups using a visibility the games set does not allow (circle/invite/link/hidden)',
        (SELECT count(*) FROM public.meetups WHERE listing_visibility NOT IN ('public', 'followers', 'private'))),
  (81, 'known.join_policy_closed','INFO', 'meetups with rsvp_policy=closed (not a games join_policy)',
        (SELECT count(*) FROM public.meetups WHERE rsvp_policy = 'closed')),
  (82, 'known.meta_venue_space', 'INFO', 'meetups carrying meta.venue_space_id (not copied to events.venue_id)',
        (SELECT count(*) FROM public.meetups WHERE meta ? 'venue_space_id')),
  (83, 'known.null_title_game',  'INFO', 'games with NULL title (events.title stays nullable)',
        (SELECT count(*) FROM public.games WHERE title IS NULL)),
  (84, 'known.null_end_meetup',  'INFO', 'meetups with NULL end_at',
        (SELECT count(*) FROM public.meetups WHERE end_at IS NULL)),
  (85, 'known.null_cap_meetup',  'INFO', 'meetups with NULL capacity (unlimited)',
        (SELECT count(*) FROM public.meetups WHERE capacity IS NULL)),
  (86, 'known.creator_drift',    'INFO', 'meetups whose creator_user_id differs from their profile user_id (legal in legacy)',
        (SELECT count(*) FROM public.meetups m JOIN public.profiles p ON p.id = m.creator_profile_id WHERE p.user_id IS DISTINCT FROM m.creator_user_id))
)
SELECT ord, id AS check_id, severity, n, descr FROM checks
UNION ALL
SELECT 100 + row_number() OVER (ORDER BY kind, field), 'field.' || kind || '.' || field, 'BLOCK', n,
       'rows where events.' || field || ' differs from the legacy ' || kind || ' value'
FROM fields
ORDER BY ord;

-- 2. One-line verdict: the count of BLOCK conditions that are not zero.
WITH
gf AS (
  SELECT g.id FROM public.games g JOIN public.events e ON e.id = g.id
  WHERE e.event_type IS DISTINCT FROM 'game' OR e.title IS DISTINCT FROM g.title
     OR e.creator_profile_id IS DISTINCT FROM g.creator_profile_id OR e.creator_user_id IS DISTINCT FROM g.creator_user_id
     OR e.sport_id IS DISTINCT FROM g.sport_id OR e.start_at IS DISTINCT FROM g.start_at OR e.end_at IS DISTINCT FROM g.end_at
     OR e.capacity IS DISTINCT FROM g.capacity OR e.venue_id IS DISTINCT FROM g.venue_id
     OR e.geo_location_id IS DISTINCT FROM g.geo_location_id OR e.area_id IS DISTINCT FROM g.area_id
     OR e.listing_visibility IS DISTINCT FROM g.listing_visibility OR e.join_policy IS DISTINCT FROM g.join_policy
     OR e.min_skill IS DISTINCT FROM g.min_skill::smallint OR e.max_skill IS DISTINCT FROM g.max_skill::smallint
     OR e.joining_rule IS DISTINCT FROM g.joining_rule OR e.cost_cover IS DISTINCT FROM g.cost_cover
     OR e.is_cancelled IS DISTINCT FROM g.is_cancelled OR e.cancelled_at IS DISTINCT FROM g.cancelled_at
     OR e.cancelled_reason IS DISTINCT FROM g.cancelled_reason OR e.request_id IS DISTINCT FROM g.request_id
     OR e.created_at IS DISTINCT FROM g.created_at OR e.updated_at IS DISTINCT FROM g.updated_at
),
mf AS (
  SELECT m.id FROM public.meetups m JOIN public.events e ON e.id = m.id
  WHERE e.event_type IS DISTINCT FROM 'meetup' OR e.title IS DISTINCT FROM m.title
     OR e.creator_profile_id IS DISTINCT FROM m.creator_profile_id OR e.creator_user_id IS DISTINCT FROM m.creator_user_id
     OR e.sport_id IS DISTINCT FROM m.sport_id OR e.start_at IS DISTINCT FROM m.start_at OR e.end_at IS DISTINCT FROM m.end_at
     OR e.capacity IS DISTINCT FROM m.capacity OR e.venue_id IS DISTINCT FROM m.venue_id
     OR e.geo_location_id IS DISTINCT FROM m.geo_location_id OR e.area_id IS DISTINCT FROM m.area_id
     OR e.listing_visibility IS DISTINCT FROM m.listing_visibility OR e.join_policy IS DISTINCT FROM m.rsvp_policy
     OR e.min_skill IS DISTINCT FROM m.min_skill::smallint OR e.max_skill IS DISTINCT FROM m.max_skill::smallint
     OR e.joining_rule IS DISTINCT FROM m.joining_rule OR e.cost_cover IS DISTINCT FROM m.cost_cover
     OR e.is_cancelled IS DISTINCT FROM m.is_cancelled OR e.cancelled_at IS NOT NULL OR e.cancelled_reason IS NOT NULL
     OR e.request_id IS DISTINCT FROM m.request_id OR e.created_at IS DISTINCT FROM m.created_at
     OR e.updated_at IS DISTINCT FROM m.updated_at
)
SELECT 'verdict' AS section,
       (SELECT count(*) FROM gf)                                                                    AS games_with_field_mismatch,
       (SELECT count(*) FROM mf)                                                                    AS meetups_with_field_mismatch,
       (SELECT count(*) FROM public.games g WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.id))
         + (SELECT count(*) FROM public.meetups m WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = m.id))
         + (SELECT count(*) FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
                                                   AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id)) AS missing_or_orphan,
       (SELECT count(*) FROM public.games WHERE event_id IS DISTINCT FROM id)
         + (SELECT count(*) FROM public.meetups WHERE event_id IS DISTINCT FROM id)                 AS unlinked_or_wrong_link,
       ((SELECT count(*) FROM gf) = 0 AND (SELECT count(*) FROM mf) = 0
        AND (SELECT count(*) FROM public.games) = (SELECT count(*) FROM public.events WHERE event_type = 'game')
        AND (SELECT count(*) FROM public.meetups) = (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
        AND (SELECT count(*) FROM public.events) = (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups)
        AND NOT EXISTS (SELECT 1 FROM public.games g JOIN public.meetups m ON m.event_id = g.event_id WHERE g.event_id IS NOT NULL)
        AND NOT EXISTS (SELECT 1 FROM public.games g JOIN public.meetups m ON m.id = g.id)
        AND NOT EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
        AND NOT EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id)
        AND NOT EXISTS (SELECT 1 FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
                                                        AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id))
       ) AS d09_ok;

ROLLBACK;
