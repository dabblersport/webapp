-- KAN-497 step 4: close anon/PUBLIC EXECUTE on the block / unblock / unfollow
-- RPCs.   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- Separate file, later-timestamped than 20261013100000_kan497_is_blocked_narrow_
-- to_caller.sql, so it can be held back independently. Apply ONLY after the
-- narrowing migration is applied AND the probes in supabase/tests/
-- anon_block_grants/probes.sql have passed on a CEO-approved non-production
-- database.
--
-- Each function is SECURITY DEFINER and holds BOTH a PUBLIC grant and an
-- explicit anon grant (KAN-496 LIVE_EVIDENCE E1/E1b/E1c). Revoking from anon
-- alone would do nothing, because PUBLIC would still let anon execute, so both
-- are named. authenticated and service_role are then granted explicitly (the
-- app calls these as authenticated; service_role is kept as today).
--
-- Why this is safe: the app calls them only from signed-in screens
-- (lib/data/repositories/block_repository_impl.dart, the profile, post-detail,
-- community and meetup follow flows); the three block/unblock bodies already
-- raise on a NULL auth.uid(); rpc_unfollow_user matches no rows without a
-- caller. Nothing in supabase/functions calls them. Caller map: CALLERS.md.
--
-- HELD OUT ON PURPOSE (decision 5): public.is_blocked(uuid, uuid). The caller
-- map shows anon-reachable INVOKER-rights callers (the visibility resolvers
-- reached from anon-readable views): an invoker function runs as the calling
-- role, so revoking anon EXECUTE on is_blocked would make those public pages
-- fail with "permission denied". The narrowing migration already makes
-- is_blocked answer false to anon, which closes the disclosure. Whether to also
-- revoke it is a CEO decision; the exact list and the held statements are in
-- supabase/tests/anon_block_grants/README.md, not here.
--
-- Out of scope and untouched: every function other than the four below. No DROP.

REVOKE EXECUTE ON FUNCTION public.rpc_block_user(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_block_user(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_block_user(uuid, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_block_user(uuid, boolean) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_unblock_user(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_unblock_user(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_unfollow_user(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_unfollow_user(uuid) TO authenticated, service_role;

-- Post-condition (read-only): neither anon nor the PUBLIC pseudo-role may
-- execute any of the four; authenticated and service_role must.
DO $$
DECLARE
  sig text;
BEGIN
  FOREACH sig IN ARRAY ARRAY[
    'public.rpc_block_user(uuid)',
    'public.rpc_block_user(uuid,boolean)',
    'public.rpc_unblock_user(uuid)',
    'public.rpc_unfollow_user(uuid)'
  ] LOOP
    IF has_function_privilege('anon', sig::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: anon can still execute %', sig;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
      WHERE p.oid = sig::regprocedure AND a.grantee = 0
    ) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: PUBLIC can still execute %', sig;
    END IF;
    IF NOT has_function_privilege('authenticated', sig::regprocedure, 'EXECUTE')
       OR NOT has_function_privilege('service_role', sig::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated/service_role lost EXECUTE on %', sig;
    END IF;
  END LOOP;
END
$$;
