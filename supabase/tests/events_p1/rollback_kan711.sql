-- KAN-711 ROLLBACK RUNBOOK. AUTHORED ONLY, NOT APPLIED. needs-ops.
-- Removes ONLY objects created by the two KAN-711 migrations:
--   20261102110000_kan711_events_mirror_triggers.sql
--   20261102120000_kan711_events_backfill.sql
-- It does NOT drop public.events, the games/meetups.event_id columns, their UNIQUE/FK constraints, or
-- any KAN-710 trigger/function: those belong to KAN-710 (20261101140000) and are reversed only by
-- supabase/tests/events_parent/rollback_kan710.sql. No legacy column, row, trigger, index or function
-- is touched. games and meetups were authoritative throughout phase 1.
--
-- DATA LEFT IN PLACE (deliberately): the events rows the mirror/backfill wrote and the event_id values
-- it set stay where they are. Removing them is a mutation of existing rows of live tables (CEO-only,
-- 019) and is section B below, commented out and NOT run. Until it is run:
--   * events is no longer kept in step (the mirror is gone); parents go stale as legacy rows change,
--   * KAN-710's FK is ON DELETE CASCADE (KAN-710:282-285): deleting a stale events row DELETES its
--     linked game/meetup. Nobody but postgres/service_role can reach events (KAN-710:98-102).
--   * rollback_kan710.sql refuses while events has rows, so section B must run before it.
--
-- Run as the migration owner. Single transaction: it either fully reverses or changes nothing.
-- Tested on a LOCAL throwaway Postgres 16 only (see KAN711_CONTRACT.md).

BEGIN;

-- Fail fast instead of queueing behind a long user transaction while holding earlier locks.
SET LOCAL lock_timeout = '5s';

-- A. 1. NOT NULL checks added by kan711_events_validate_links() (absent if validation never ran).
ALTER TABLE public.games   DROP CONSTRAINT IF EXISTS games_event_id_not_null;
ALTER TABLE public.meetups DROP CONSTRAINT IF EXISTS meetups_event_id_not_null;

-- A. 2. Stage 2 triggers. Mirror first so no further events write is attempted.
DROP TRIGGER IF EXISTS trg_kan711_games_mirror            ON public.games;
DROP TRIGGER IF EXISTS trg_kan711_meetups_mirror          ON public.meetups;
DROP TRIGGER IF EXISTS trg_kan711_games_assign_event_id   ON public.games;
DROP TRIGGER IF EXISTS trg_kan711_meetups_assign_event_id ON public.meetups;
DROP TRIGGER IF EXISTS trg_kan711_events_keep_updated_at  ON public.events;

-- A. 3. Stage 3 routines, view and bookkeeping.
DROP PROCEDURE IF EXISTS public.kan711_events_backfill_run(integer, integer);
DROP FUNCTION  IF EXISTS public.kan711_events_backfill_batch(text, integer);
DROP FUNCTION  IF EXISTS public.kan711_events_backfill_reset(text);
DROP FUNCTION  IF EXISTS public.kan711_events_validate_links();
DROP VIEW      IF EXISTS public.kan711_events_parity;
DROP TABLE     IF EXISTS public.events_backfill_exceptions;
DROP TABLE     IF EXISTS public.events_backfill_checkpoint;

-- A. 4. Stage 2 functions. No CASCADE anywhere: an unexpected dependent must fail loudly.
DROP FUNCTION IF EXISTS public.kan711_games_mirror();
DROP FUNCTION IF EXISTS public.kan711_meetups_mirror();
DROP FUNCTION IF EXISTS public.kan711_assign_event_id();
DROP FUNCTION IF EXISTS public.kan711_events_keep_updated_at();
DROP FUNCTION IF EXISTS public.kan711_events_upsert(public.events);
DROP FUNCTION IF EXISTS public.kan711_events_map_game(public.games);
DROP FUNCTION IF EXISTS public.kan711_events_map_meetup(public.meetups);

-- A. 5. Post-conditions: nothing of KAN-711 remains, and everything of KAN-710 still does.
DO $$
BEGIN
  IF to_regclass('public.events_backfill_checkpoint') IS NOT NULL
     OR to_regclass('public.events_backfill_exceptions') IS NOT NULL
     OR to_regclass('public.kan711_events_parity') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-711 rollback: a KAN-711 relation survived';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname LIKE 'kan711\_%') THEN
    RAISE EXCEPTION 'KAN-711 rollback: a kan711 routine survived';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname LIKE 'trg\_kan711\_%') THEN
    RAISE EXCEPTION 'KAN-711 rollback: a kan711 trigger survived';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname IN ('games_event_id_not_null', 'meetups_event_id_not_null')) THEN
    RAISE EXCEPTION 'KAN-711 rollback: a NOT NULL check survived';
  END IF;
  -- KAN-710's objects must be untouched.
  IF to_regclass('public.events') IS NULL
     OR (SELECT count(*) FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name IN ('games', 'meetups') AND column_name = 'event_id') <> 2
     OR (SELECT count(*) FROM pg_constraint WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey',
                                                               'games_event_id_key', 'meetups_event_id_key')) <> 4
     OR (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgname IN (
           'trg_events_touch', 'trg_events_search_tsv', 'trg_events_type_immutable', 'trg_events_exclusive_check',
           'trg_events_series_start_check', 'trg_games_event_link_check', 'trg_meetups_event_link_check',
           'trg_games_series_occurrence_check')) <> 8 THEN
    RAISE EXCEPTION 'KAN-711 rollback: a KAN-710 object is missing; this script must not touch KAN-710';
  END IF;
END $$;

COMMIT;

-- After COMMIT, mark the two migration versions reverted ONLY through the Supabase CLI
-- (`supabase migration repair --status reverted 20261102120000 20261102110000`), so the migration
-- history stays consistent with the catalogue. 20261101140000 (KAN-710) stays applied.

-- ---------------------------------------------------------------------------------------------------
-- B. OPTIONAL DATA REVERSAL. NOT RUN. CEO-ONLY (mutates existing rows of live tables, 019).
-- Only needed before rollback_kan710.sql, which refuses while events has rows. Order is mandatory:
-- event_id must be NULLed BEFORE events rows are deleted, or KAN-710's ON DELETE CASCADE deletes the
-- legacy games/meetups. Legacy UPDATE triggers would fire on the NULLing (updated_at, activity, notify);
-- disable them for the transaction exactly as kan711_events_backfill_batch does, or accept the bump.
--
-- BEGIN;
-- SET LOCAL lock_timeout = '5s';
-- UPDATE public.games   SET event_id = NULL WHERE event_id IS NOT NULL;
-- UPDATE public.meetups SET event_id = NULL WHERE event_id IS NOT NULL;
-- DO $$ BEGIN
--   IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NOT NULL)
--      OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS NOT NULL) THEN
--     RAISE EXCEPTION 'links remain; refusing to delete events (would cascade)';
--   END IF;
-- END $$;
-- DELETE FROM public.events;
-- COMMIT;
