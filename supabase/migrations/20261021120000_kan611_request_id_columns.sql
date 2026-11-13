-- KAN-611 (1 of 4): request_id columns, partial unique indexes, stamping trigger.
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing in this file was run against any database. Memphis applies it after
-- approval (execute_sql only, never apply_migration, test data only; rollback in
-- supabase/tests/idempotency/rollback.sql; SQL probes in supabase/tests/idempotency/idempotency_tests.sql).
-- Project wtncuzcskpigqpmnxwws only.
--
-- Files, applied in this order:
--   20261021120000_kan611_request_id_columns.sql     (this file)
--   20261021120100_kan611_create_post_request_id.sql
--   20261021120200_kan611_rpc_create_game_request_id.sql
--   20261021120300_kan611_rpc_create_meetup_request_id.sql
--
-- Why. A create call whose response is lost is retried by the app, and today the retry creates a second post / game /
-- meetup. A client request id (uuid) makes the retry return the row the first call created.
--
-- Additive only: nothing is removed, no RLS policy is touched. Uniqueness is keyed on the OWNER USER id
-- (posts.author_user_id, games.creator_user_id, meetups.creator_user_id), the same identity the create RPCs write.
-- The indexes are PARTIAL (WHERE request_id IS NOT NULL): every existing row and every call without a request id is
-- outside them and behaves exactly as before. Every statement is re-runnable.

ALTER TABLE public.posts   ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.games   ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.meetups ADD COLUMN IF NOT EXISTS request_id uuid;

COMMENT ON COLUMN public.posts.request_id   IS 'KAN-611: client request id; (author_user_id, request_id) is unique. NULL = created without one.';
COMMENT ON COLUMN public.games.request_id   IS 'KAN-611: client request id; (creator_user_id, request_id) is unique. NULL = created without one.';
COMMENT ON COLUMN public.meetups.request_id IS 'KAN-611: client request id; (creator_user_id, request_id) is unique. NULL = created without one.';

CREATE UNIQUE INDEX IF NOT EXISTS posts_author_user_request_id_key
  ON public.posts (author_user_id, request_id) WHERE request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS games_creator_user_request_id_key
  ON public.games (creator_user_id, request_id) WHERE request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS meetups_creator_user_request_id_key
  ON public.meetups (creator_user_id, request_id) WHERE request_id IS NOT NULL;

-- Stamping trigger for the two wrapped RPCs (games, meetups). Still needed: the wrapped *_legacy_v2 bodies INSERT
-- without a request id. The new wrapper sets the transaction-local setting thebes.create_request_id just before calling
-- the legacy body; this BEFORE INSERT trigger copies it onto the row (no UPDATE, so no AFTER UPDATE trigger fires a
-- second time). The wrapper clears it right after. A direct INSERT never sets it, so request_id stays NULL.
-- create_post writes request_id in its own INSERT and needs no trigger.

CREATE OR REPLACE FUNCTION public.kan611_stamp_request_id() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v text := nullif(current_setting('thebes.create_request_id', true), '');
BEGIN
  IF v IS NOT NULL AND NEW.request_id IS NULL THEN
    NEW.request_id := v::uuid;
  END IF;
  RETURN NEW;
END;
$$;
ALTER FUNCTION public.kan611_stamp_request_id() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.kan611_stamp_request_id() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_games_stamp_request_id
  BEFORE INSERT ON public.games FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();
CREATE OR REPLACE TRIGGER trg_meetups_stamp_request_id
  BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();
