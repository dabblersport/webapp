-- KAN-645 rollback. Exposure/code first: removes only the new RPC. No data is touched and no persona is rewritten.
-- Profiles, extension rows and stats created through it stay (KAN-644's schema is not part of this rollback).
SELECT 'aggregate counts (informational)' AS note,
       (SELECT count(*) FROM public.profiles WHERE persona_type = 'contributor') AS contributors,
       (SELECT count(*) FROM public.profiles WHERE persona_type = 'partner')     AS partners;
DROP FUNCTION IF EXISTS public.rpc_onboard_unified_profile(uuid, text, text, integer, text, text, uuid, uuid[], text, text);
