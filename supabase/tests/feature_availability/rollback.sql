-- KAN-585 rollback. AUTHORED, NOT APPLIED. Run by the operations team only if
-- the migration must be reverted; it removes only what the migration created.
-- The app keeps its last good cached value, else the compile-time default,
-- when the RPC is absent. (Dropping is deliberate here and is a rollback, not
-- part of the migration.)
BEGIN;
DROP FUNCTION IF EXISTS public.get_feature_availability();
DROP POLICY IF EXISTS feature_availability_select_authenticated ON public.feature_availability;
DROP TABLE IF EXISTS public.feature_availability;
COMMIT;
