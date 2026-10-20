-- KAN-584 rollback. AUTHORED, NOT APPLIED. Run by the operations team only if
-- the migration must be reverted; it removes only what the migration created.
-- The app falls back to its per-account local copy when the table is absent.
-- (Dropping is deliberate here and is a rollback, not part of the migration.)
BEGIN;
DROP POLICY IF EXISTS account_service_region_update_own ON public.account_service_region;
DROP POLICY IF EXISTS account_service_region_insert_own ON public.account_service_region;
DROP POLICY IF EXISTS account_service_region_select_own ON public.account_service_region;
DROP TABLE IF EXISTS public.account_service_region;
COMMIT;
