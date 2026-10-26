-- KAN-671 rollback. AUTHORED, NOT APPLIED. Run by the operations team only if the migration must be
-- reverted; it removes only what the migration created. Dropping is deliberate here and is a rollback,
-- not part of the migration. Any series_id values are lost; games rows themselves are untouched.
BEGIN;
DROP INDEX IF EXISTS public.games_series_id_idx;
ALTER TABLE public.games DROP COLUMN IF EXISTS series_id;
DROP POLICY IF EXISTS game_series_select_owner ON public.game_series;
DROP TABLE IF EXISTS public.game_series;
COMMIT;
