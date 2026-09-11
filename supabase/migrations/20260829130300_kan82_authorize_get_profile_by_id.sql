-- KAN-82 (HIGH): public.get_profile_by_id(uuid) is SECURITY DEFINER with no
-- authorization check and returns row_to_json(p.*) -- every column of
-- profiles, present and future, for any id, to anon (grant is via PUBLIC; a
-- revoke must name PUBLIC, not anon).
--
-- Unlike KAN-79/KAN-81, this function has a live, deliberate caller:
-- lib/features/profile/data/datasources/supabase_profile_datasource.dart:35
-- uses the SECURITY DEFINER escalation specifically to load is_active=false
-- profiles that RLS would otherwise block. It must NOT be dropped. The defect
-- is that the escalation applies to every caller including anon, instead of
-- being scoped to an authenticated session as the app's own usage requires.
--
-- Part 1 (this migration, unambiguous, ships now): close it to anon. No
-- legitimate caller is unauthenticated -- the datasource path always runs
-- behind a signed-in session. Keep SECURITY DEFINER (the inactive-profile
-- bypass is the point of the function); narrow the surface at both the
-- in-body check and the grant.
--
-- Part 2 (tracked separately, needs a CPO ruling): row_to_json(p.*) should be
-- an explicit column list, and cross-user / inactive-profile visibility needs
-- a product decision. Out of scope here -- do not fold into this migration.
--
-- CAUTION: CREATE OR REPLACE FUNCTION can reset a function's ACL (this project
-- has already been bitten by exactly that class of silent reopening -- see
-- security_invoker being reset on CREATE OR REPLACE VIEW). The REVOKE/GRANT
-- below is therefore issued AFTER the body change, in the same migration, not
-- assumed to survive from a prior grant.
--
-- Authorization is done via auth.uid() -- NOT
-- current_setting('request.jwt.claim.profile_id'), which is dead legacy GUC in
-- this database and would manufacture a false pass in verification.
--
-- G-002: authored by backend-owner, NOT applied here. cto applies after
-- measuring preconditions live and posting verification back to KAN-82.
-- flutter-feature-agent confirms AC4 (profile loading still works on Canary,
-- exercised in the running app) before this is treated as done.

CREATE OR REPLACE FUNCTION public.get_profile_by_id(p_profile_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN (
    SELECT row_to_json(p.*)::jsonb
    FROM profiles p
    WHERE p.id = p_profile_id
    LIMIT 1
  );
END;
$function$;

-- Re-apply grants AFTER the body change -- CREATE OR REPLACE can reset the ACL.
REVOKE EXECUTE ON FUNCTION public.get_profile_by_id(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_by_id(uuid) TO authenticated, service_role;

-- ============================================================
-- VERIFICATION (run all, all must hold)
-- ============================================================
-- 1. Unauthenticated POST /rest/v1/rpc/get_profile_by_id fails (permission
--    denied or 'not authorized') -- exercised as a real anon REST call on
--    Canary, not inferred from the grant table.
--
-- 2. has_function_privilege('anon', 'public.get_profile_by_id(uuid)', 'EXECUTE')
--    returns false.
--
-- 3. has_function_privilege('authenticated', 'public.get_profile_by_id(uuid)',
--    'EXECUTE') returns true, AND the function still returns an inactive
--    profile for an authenticated caller -- the deliberate RLS-bypass
--    behavior must survive this change, spot-checked with a real
--    authenticated session, not just the grant.
--
-- 4. Profile loading via supabase_profile_datasource.dart:35 still works on
--    Canary, exercised in the running app (flutter-feature-agent confirms).
--
-- 5. A follow-up ticket exists for Part 2 (explicit column list + CPO ruling
--    on cross-user and inactive-profile visibility) before this is closed.
