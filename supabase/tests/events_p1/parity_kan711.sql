-- KAN-711 parity + exception report. READ-ONLY. Wrapped in a READ ONLY transaction so it cannot write.
-- Run as the migration owner (or any BYPASSRLS role): meetups is FORCE RLS and the view is
-- security_invoker, so a non-bypass role would see a partial legacy population and report false parity.
-- Expected result after a complete, clean backfill: every count below is 0 and both kinds finished.
-- STATUS: authored; executed on a LOCAL throwaway Postgres 16 only (see KAN711_CONTRACT.md).

BEGIN TRANSACTION READ ONLY;

-- 0. Guard: refuse to report from a role that cannot see every row.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-711 parity: role % does not bypass RLS; the report would undercount meetups', current_user;
  END IF;
END $$;

-- 0b. Pre-apply predictor: legacy rows that KAN-710's events CHECKs (KAN-710:62-90) would refuse.
-- Run this BEFORE the backfill on the target database; every such row lands in
-- events_backfill_exceptions (23514) instead of events. Rules legacy already enforces identically
-- (cost_cover logic, meetup title 3..80 = chk_meetups_title_len) are included anyway as a cross-check.
SELECT 'precheck_kan710' AS section, rule, count(*) AS rows
FROM (
  SELECT 'games.end_after_start (KAN-710:65)' AS rule FROM public.games WHERE end_at IS NOT NULL AND end_at <= start_at
  UNION ALL SELECT 'games.end_required (75)'       FROM public.games WHERE end_at IS NULL
  UNION ALL SELECT 'games.capacity 2..64 (76)'     FROM public.games WHERE capacity IS NULL OR capacity NOT BETWEEN 2 AND 64
  UNION ALL SELECT 'games.visibility (77)'         FROM public.games WHERE listing_visibility IS NULL OR listing_visibility NOT IN ('public', 'followers', 'private')
  UNION ALL SELECT 'games.join_policy (78)'        FROM public.games WHERE join_policy IS NULL OR join_policy NOT IN ('open', 'request', 'invite', 'link')
  UNION ALL SELECT 'games.sport/area/geo (79-81)'  FROM public.games WHERE sport_id IS NULL OR area_id IS NULL OR geo_location_id IS NULL
  UNION ALL SELECT 'games.skill 1..10 (82-83)'     FROM public.games WHERE min_skill NOT BETWEEN 1 AND 10 OR max_skill NOT BETWEEN 1 AND 10
  UNION ALL SELECT 'meetups.end_after_start (65)'  FROM public.meetups WHERE end_at IS NOT NULL AND end_at <= start_at
  UNION ALL SELECT 'meetups.title 3..80 (86)'      FROM public.meetups WHERE title IS NULL OR char_length(title) NOT BETWEEN 3 AND 80
  UNION ALL SELECT 'meetups.capacity > 0 (87)'     FROM public.meetups WHERE capacity IS NOT NULL AND capacity <= 0
  UNION ALL SELECT 'meetups.visibility (88)'       FROM public.meetups WHERE listing_visibility IS NULL OR listing_visibility NOT IN ('public', 'circle', 'invite', 'link', 'hidden')
  UNION ALL SELECT 'meetups.rsvp->join_policy (89)' FROM public.meetups WHERE rsvp_policy IS NULL OR rsvp_policy NOT IN ('open', 'request', 'invite', 'link', 'closed')
  UNION ALL SELECT 'meetups.skill fits smallint (KAN-710:39-40)' FROM public.meetups WHERE min_skill NOT BETWEEN -32768 AND 32767 OR max_skill NOT BETWEEN -32768 AND 32767
) v
GROUP BY rule
ORDER BY rule;

-- 1. Populations, counted (020): legacy vs events, per type.
SELECT 'population' AS section, t.kind, t.legacy_rows, t.event_rows, t.linked_rows
FROM (
  SELECT 'games' AS kind,
         (SELECT count(*) FROM public.games)                              AS legacy_rows,
         (SELECT count(*) FROM public.events WHERE event_type = 'game')   AS event_rows,
         (SELECT count(*) FROM public.games WHERE event_id = id)          AS linked_rows
  UNION ALL
  SELECT 'meetups',
         (SELECT count(*) FROM public.meetups),
         (SELECT count(*) FROM public.events WHERE event_type = 'meetup'),
         (SELECT count(*) FROM public.meetups WHERE event_id = id)
) t;

-- 2. Parity issues by class (0 rows in each = parity).
SELECT 'parity_by_issue' AS section, kind,
       count(*) FILTER (WHERE missing_event)                     AS missing_event,
       count(*) FILTER (WHERE orphan_event)                      AS orphan_event,
       count(*) FILTER (WHERE unlinked)                          AS unlinked,
       count(*) FILTER (WHERE cardinality(mismatched_fields) > 0) AS mismatched
FROM public.kan711_events_parity
GROUP BY kind;

-- 3. Mismatches by field (which mapping rule is wrong, if any).
SELECT 'parity_by_field' AS section, p.kind, f.field, count(*) AS rows
FROM public.kan711_events_parity p
CROSS JOIN LATERAL unnest(p.mismatched_fields) AS f(field)
GROUP BY p.kind, f.field
ORDER BY rows DESC, p.kind, f.field;

-- 4. First 50 problem rows, for triage.
SELECT 'parity_rows' AS section, kind, id, missing_event, orphan_event, unlinked, mismatched_fields
FROM public.kan711_events_parity
ORDER BY kind, id
LIMIT 50;

-- 5. Backfill checkpoint state.
SELECT 'checkpoint' AS section, kind, last_id, rows_done, rows_failed, batches_done,
       started_at, updated_at, finished_at, (finished_at IS NOT NULL) AS finished
FROM public.events_backfill_checkpoint
ORDER BY kind;

-- 6. Unresolved exceptions (each is a legacy row the backfill could not mirror).
SELECT 'exceptions_unresolved' AS section, kind, sqlstate, count(*) AS rows,
       min(first_seen_at) AS first_seen, max(last_seen_at) AS last_seen
FROM public.events_backfill_exceptions
WHERE resolved_at IS NULL
GROUP BY kind, sqlstate
ORDER BY kind, sqlstate;

SELECT 'exception_rows' AS section, kind, legacy_id, sqlstate, message, detail, attempts
FROM public.events_backfill_exceptions
WHERE resolved_at IS NULL
ORDER BY kind, legacy_id
LIMIT 50;

-- 7. Series occurrence cross-check. games_series_id_start_at_key enforces uniqueness on games, and
-- KAN-710's trg_games_series_occurrence_check / trg_events_series_start_check (KAN-710:214-249,
-- 270, 293-295) check linked occurrences against events.start_at. Prove the mirrored start_at agrees.
SELECT 'series_duplicates' AS section, g.series_id, e.start_at, count(*) AS rows
FROM public.games g
JOIN public.events e ON e.id = g.id AND e.event_type = 'game'
WHERE g.series_id IS NOT NULL
GROUP BY g.series_id, e.start_at
HAVING count(*) > 1;

-- 8. Request idempotency cross-checks.
--   8a. events key (event_type, creator_profile_id, request_id) — enforced by an index; must be 0.
SELECT 'request_dup_events' AS section, event_type, creator_profile_id, request_id, count(*) AS rows
FROM public.events WHERE request_id IS NOT NULL
GROUP BY event_type, creator_profile_id, request_id HAVING count(*) > 1;
--   8b. Legacy rows whose (type, profile, request) would collide in events although legacy accepted them
--       (legacy keys on creator_user_id). These are the rows that land in exceptions as 23505.
SELECT 'request_dup_legacy_by_profile' AS section, kind, creator_profile_id, request_id, count(*) AS rows,
       array_agg(id ORDER BY id) AS ids
FROM (
  SELECT 'games' AS kind, id, creator_profile_id, request_id FROM public.games WHERE request_id IS NOT NULL
  UNION ALL
  SELECT 'meetups', id, creator_profile_id, request_id FROM public.meetups WHERE request_id IS NOT NULL
) s
GROUP BY kind, creator_profile_id, request_id HAVING count(*) > 1;

-- 9. Link-constraint state. games/meetups_event_id_fkey are KAN-710's (KAN-710:282-285), created
-- VALID, so convalidated is true from the start. The *_not_null checks are KAN-711's, added NOT VALID
-- and validated by kan711_events_validate_links() only once parity is 0; absent before that.
SELECT 'link_constraints' AS section, conrelid::regclass AS tbl, conname, contype, convalidated
FROM pg_constraint
WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey',
                  'games_event_id_not_null', 'meetups_event_id_not_null')
ORDER BY conname;

-- 10. One-line verdict.
SELECT 'verdict' AS section,
       (SELECT count(*) FROM public.kan711_events_parity)                                    AS parity_rows,
       (SELECT count(*) FROM public.events_backfill_exceptions WHERE resolved_at IS NULL)    AS unresolved_exceptions,
       (SELECT count(*) FROM public.events_backfill_checkpoint WHERE finished_at IS NULL)    AS unfinished_kinds,
       ((SELECT count(*) FROM public.kan711_events_parity) = 0
        AND (SELECT count(*) FROM public.events_backfill_exceptions WHERE resolved_at IS NULL) = 0
        AND (SELECT count(*) FROM public.events_backfill_checkpoint WHERE finished_at IS NULL) = 0) AS parity_ok;

ROLLBACK;
