-- KAN-711 reviewer counterexamples (Codex review of SHA b2903455), run VERBATIM as probes.
-- LOCAL THROWAWAY POSTGRES ONLY, on a FRESH database built from local_harness_kan711.sql +
-- local_seed_kan711.sql + KAN-710 (20261101140000) + the two KAN-711 migrations, with NO backfill run.
-- This script COMMITS (kan711_events_backfill_run is a COMMIT-ing procedure and cannot run inside a
-- transaction block), so it is not part of probes_kan711.sql and must never be run on a shared DB.
--
--   psql -h /tmp -p 54399 -U postgres -d <fresh> -v ON_ERROR_STOP=1 -f reviewer_repro_kan711.sql
--
-- Each assertion raises on failure. Pre-fix (b2903455) results recorded by the reviewer:
--   R1 (reviewer-subtype-edit-timestamp.txt): parent 2025-12-03 14:00+04, legacy advanced, parity 0,
--      validate_links validated:true.
--   R2 (reviewer-local-probes.txt): repaired parent updated_at = now(), parity 0 (updated_at excluded).

\set ON_ERROR_STOP 1

-- R2 setup, verbatim: a parent created ahead of the backfill, then edited outside the mirror.
INSERT INTO public.events SELECT (public.kan711_events_map_game(g)).* FROM public.games g
 WHERE g.id = '10000000-0000-0000-0000-000000000001';
UPDATE public.events SET title = 'stale parent title' WHERE id = '10000000-0000-0000-0000-000000000001';

DO $$
BEGIN
  IF (SELECT array_agg(f ORDER BY f) FROM public.kan711_events_parity, unnest(mismatched_fields) f
       WHERE id = '10000000-0000-0000-0000-000000000001') IS DISTINCT FROM ARRAY['title', 'updated_at'] THEN
    RAISE EXCEPTION 'FAIL: R2 pre-repair parity must report title and updated_at on the stale parent';
  END IF;
  RAISE NOTICE 'PASS: R2 pre-repair parity reports {title,updated_at} on the stale parent';
END $$;

-- Full backfill (repairs the stale parent; inserts the rest).
CALL public.kan711_events_backfill_run(4);

DO $$
BEGIN
  IF NOT (SELECT e.updated_at = g.updated_at AND e.updated_at = '2025-12-02 10:00+00' AND e.title = 'Sunday 5s'
            FROM public.events e JOIN public.games g ON g.id = e.id WHERE e.id = '10000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'FAIL: R2 repaired parent must carry the source updated_at 2025-12-02 10:00+00, not now()';
  END IF;
  RAISE NOTICE 'PASS: R2 repair copies the source updated_at (2025-12-02 10:00+00) and restores the title';
  IF (SELECT count(*) FROM public.kan711_events_parity) <> 0 THEN
    RAISE EXCEPTION 'FAIL: R2 parity must be 0 after the full backfill';
  END IF;
  RAISE NOTICE 'PASS: R2 parity 0 after the full backfill';
END $$;

-- R1, verbatim: a subtype-only edit after the full backfill.
UPDATE public.games SET rules = jsonb_build_object('qa', 'changed retained subtype field')
 WHERE id = '10000000-0000-0000-0000-000000000002';

SELECT 'ORDINARY_SUBTYPE_EDIT_TIMESTAMP_DRIFT' finding, g.updated_at legacy_updated_at, e.updated_at parent_updated_at,
       (g.updated_at IS DISTINCT FROM e.updated_at) timestamp_mismatch,
       (SELECT count(*) FROM public.kan711_events_parity) reported_parity_rows
  FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '10000000-0000-0000-0000-000000000002';

DO $$
BEGIN
  IF NOT (SELECT g.updated_at = e.updated_at AND g.updated_at > '2025-12-03 10:00+00'
            FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '10000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'FAIL: R1 parent.updated_at must equal the advanced legacy updated_at';
  END IF;
  RAISE NOTICE 'PASS: R1 rules-only edit: parent.updated_at = legacy.updated_at (advanced)';
  IF (SELECT count(*) FROM public.kan711_events_parity) <> 0 THEN
    RAISE EXCEPTION 'FAIL: R1 parity must be 0 when the timestamps match';
  END IF;
  RAISE NOTICE 'PASS: R1 parity 0';
END $$;

SELECT public.kan711_events_validate_links() AS validate_links_after_r1_r2;

-- R3 forced drift, separate statement (so now() differs from the legacy value): parity > 0 and
-- validate_links false; then undone by a mirror write so the database ends consistent.
BEGIN;
UPDATE public.events SET title = title WHERE id = '10000000-0000-0000-0000-000000000002';   -- touch -> now()
DO $$
BEGIN
  IF (SELECT count(*) FROM public.kan711_events_parity WHERE 'updated_at' = ANY (mismatched_fields)) <> 1 THEN
    RAISE EXCEPTION 'FAIL: R3 forced updated_at drift must make parity > 0';
  END IF;
  IF (public.kan711_events_validate_links() ->> 'validated')::boolean THEN
    RAISE EXCEPTION 'FAIL: R3 validate_links must be false on the drift';
  END IF;
  RAISE NOTICE 'PASS: R3 forced drift: parity 1 row {updated_at}, validate_links false';
END $$;
SELECT public.kan711_events_validate_links() AS validate_links_on_forced_drift;
ROLLBACK;

SELECT 'ALL KAN-711 REVIEWER REPROS PASSED' AS result;
