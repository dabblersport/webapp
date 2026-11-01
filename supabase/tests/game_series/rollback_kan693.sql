-- KAN-693 rollback: reverses ONLY 20261030120000_kan693_rpc_create_game_series.sql. Memphis runs it via execute_sql.
-- Leaves KAN-671's game_series table, games.series_id and any games rows (including generated occurrences) intact.
-- The DROPs are of objects this migration created; the unique index and column are dropped last.
BEGIN;
DROP FUNCTION IF EXISTS public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time,integer,text,text,integer,text,uuid,date,text,text,integer,numeric);
DROP FUNCTION IF EXISTS public.fn_generate_game_series_occurrences(uuid);
DROP INDEX IF EXISTS public.games_series_id_start_at_key;
ALTER TABLE public.game_series DROP COLUMN IF EXISTS sport_variant_id;
COMMIT;
