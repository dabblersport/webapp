-- KAN-664 rollback (AUTHORED, NOT RUN; Operations runs it). Removes only the three read functions the migration added.
-- No table, row, policy or existing function is touched.
DROP FUNCTION IF EXISTS public.rpc_get_unrated_coplayers(uuid);
DROP FUNCTION IF EXISTS public.rpc_get_user_rating_aggregate(uuid);
DROP FUNCTION IF EXISTS public.rpc_list_rating_dimensions();
