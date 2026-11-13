-- KAN-621 rollback: removes ONLY the function this ticket added. Nothing else changes.
-- Run on a scratch database; production rollback goes through Operations.
DROP FUNCTION IF EXISTS public.rpc_sport_overview(uuid, text);
