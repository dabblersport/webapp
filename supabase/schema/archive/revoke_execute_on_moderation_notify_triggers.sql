-- Applied to remote as migration version 20260701172012.
--
-- These are trigger-only functions (reference NEW, not safe/meaningful to
-- invoke directly via PostgREST). Match the project's existing convention
-- (see p2_revoke_execute_internal_functions) of revoking EXECUTE on
-- internal-only functions from anon/authenticated.
REVOKE EXECUTE ON FUNCTION public.notify_admins_of_report() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_admins_of_block() FROM anon, authenticated;
