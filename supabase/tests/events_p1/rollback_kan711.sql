-- KAN-711 ROLLBACK RUNBOOK (stage 1 reversal). AUTHORED ONLY, NOT APPLIED. needs-ops.
-- Removes ONLY objects created by the three KAN-711 migrations:
--   20261102100000_kan711_events_parent_schema.sql
--   20261102110000_kan711_events_mirror_triggers.sql
--   20261102120000_kan711_events_backfill.sql
-- No legacy column, row, trigger, index or function is touched. games and meetups were authoritative
-- throughout phase 1, so dropping the mirror loses no source data: events holds only copies.
--
-- DESTRUCTIVE in the sense that public.events and the backfill bookkeeping are dropped. On production
-- this is a CEO-authorised step (CONTRACT.md, destructive/irreversible production action).
-- Run as the migration owner. Single transaction: it either fully reverses or changes nothing.
-- Order matters: the integrity constraint triggers and the link FKs must go before events.
-- Tested on a LOCAL throwaway Postgres 16 only (see KAN711_CONTRACT.md).

BEGIN;

-- Fail fast instead of queueing behind a long user transaction while holding earlier locks.
SET LOCAL lock_timeout = '5s';

-- 1. Link constraints added by validate_links (may not exist if validation never ran) and the FKs.
ALTER TABLE public.games   DROP CONSTRAINT IF EXISTS games_event_id_not_null;
ALTER TABLE public.meetups DROP CONSTRAINT IF EXISTS meetups_event_id_not_null;
ALTER TABLE public.games   DROP CONSTRAINT IF EXISTS games_event_id_fkey;
ALTER TABLE public.meetups DROP CONSTRAINT IF EXISTS meetups_event_id_fkey;

-- 2. Triggers (stage 2). Mirror and integrity first so no further events write is attempted.
DROP TRIGGER IF EXISTS trg_kan711_games_integrity        ON public.games;
DROP TRIGGER IF EXISTS trg_kan711_meetups_integrity      ON public.meetups;
DROP TRIGGER IF EXISTS trg_kan711_games_mirror           ON public.games;
DROP TRIGGER IF EXISTS trg_kan711_meetups_mirror         ON public.meetups;
DROP TRIGGER IF EXISTS trg_kan711_games_assign_event_id   ON public.games;
DROP TRIGGER IF EXISTS trg_kan711_meetups_assign_event_id ON public.meetups;
DO $$ BEGIN
  IF to_regclass('public.events') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_kan711_events_integrity ON public.events';
  END IF;
END $$;

-- 3. Stage 3 routines, view and bookkeeping.
DROP PROCEDURE IF EXISTS public.kan711_events_backfill_run(integer, integer);
DROP FUNCTION  IF EXISTS public.kan711_events_backfill_batch(text, integer);
DROP FUNCTION  IF EXISTS public.kan711_events_backfill_reset(text);
DROP FUNCTION  IF EXISTS public.kan711_events_validate_links();
DROP VIEW      IF EXISTS public.kan711_events_parity;
DROP TABLE     IF EXISTS public.events_backfill_exceptions;
DROP TABLE     IF EXISTS public.events_backfill_checkpoint;

-- 4. Stage 2 functions. Typed signatures depend on public.events/games/meetups row types, so they
-- must go before events is dropped. No CASCADE anywhere: an unexpected dependent must fail loudly.
DROP FUNCTION IF EXISTS public.kan711_events_integrity();
DROP FUNCTION IF EXISTS public.kan711_legacy_integrity();
DROP FUNCTION IF EXISTS public.kan711_games_mirror();
DROP FUNCTION IF EXISTS public.kan711_meetups_mirror();
DROP FUNCTION IF EXISTS public.kan711_assign_event_id();
DROP FUNCTION IF EXISTS public.kan711_events_upsert(public.events);
DROP FUNCTION IF EXISTS public.kan711_events_map_game(public.games);
DROP FUNCTION IF EXISTS public.kan711_events_map_meetup(public.meetups);

-- 5. Legacy link columns (stage 1). Their partial unique indexes drop with them.
DROP INDEX IF EXISTS public.games_event_id_key;
DROP INDEX IF EXISTS public.meetups_event_id_key;
ALTER TABLE public.games   DROP COLUMN IF EXISTS event_id;
ALTER TABLE public.meetups DROP COLUMN IF EXISTS event_id;

-- 6. The parent table (its own indexes drop with it).
DROP TABLE IF EXISTS public.events;

-- 7. Post-conditions: assert nothing of KAN-711 remains.
DO $$
BEGIN
  IF to_regclass('public.events') IS NOT NULL
     OR to_regclass('public.events_backfill_checkpoint') IS NOT NULL
     OR to_regclass('public.events_backfill_exceptions') IS NOT NULL
     OR to_regclass('public.kan711_events_parity') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-711 rollback: a relation survived';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname LIKE 'kan711\_%') THEN
    RAISE EXCEPTION 'KAN-711 rollback: a kan711 routine survived';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname LIKE 'trg\_kan711\_%') THEN
    RAISE EXCEPTION 'KAN-711 rollback: a kan711 trigger survived';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name IN ('games', 'meetups') AND column_name = 'event_id') THEN
    RAISE EXCEPTION 'KAN-711 rollback: an event_id column survived';
  END IF;
END $$;

COMMIT;

-- After COMMIT, remove the three migration versions from supabase_migrations.schema_migrations ONLY
-- through the Supabase CLI (`supabase migration repair --status reverted 20261102120000 20261102110000
-- 20261102100000`), so the migration history stays consistent with the catalogue.
