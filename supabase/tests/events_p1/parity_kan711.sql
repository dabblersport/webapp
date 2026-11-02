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

-- 7. Series occurrence uniqueness cross-check: games_series_id_start_at_key enforces it on games;
-- events has no series_id in phase 1, so prove the mirrored start_at cannot have broken it.
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

-- 9. Link-constraint state (validate_links flips these once parity is 0).
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
