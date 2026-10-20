-- KAN-595 (Active stream) rollback.   AUTHORED, NOT RUN.
-- Removes only what 20261020120000_kan595_active_stream.sql created: the function public.active_stream.
-- No table, index or data was created by that migration, so nothing else is touched.
BEGIN;
REVOKE ALL ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) FROM authenticated;
DROP FUNCTION IF EXISTS public.active_stream(text[], text, int, timestamptz, text, uuid);
COMMIT;
