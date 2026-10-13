-- KAN-497 rollback. AUTHORED, NOT RUN.
--
-- THIS FILE IS ITSELF AN APPLY. Running it needs the CEO's explicit approval of
-- this exact text (G-002 backend owner plus PEER review), exactly like the
-- migrations it undoes. It REOPENS the disclosure: after it runs, anyone with the
-- public anon key can again ask whether one user blocked another and can again
-- execute the block / unblock / unfollow RPCs. Use it only as a last resort,
-- when a regression that cannot be fixed forward is proven.
--
-- Order (the reverse of the apply order):
--   1. undo the revoke   (re-grant EXECUTE to PUBLIC and anon on the five)
--   2. undo the narrowing (restore the previous is_blocked body)
-- Step 1 also covers a held is_blocked revoke, if the CEO had approved one.
--
-- Uses no DROP. CREATE OR REPLACE keeps the owner and the other grants.
--
-- "Exactly as they are today" = the state recorded by KAN-496 E1/E1b/E1c and by
-- the baseline: every one of the five holds a PUBLIC grant and explicit grants
-- to anon, authenticated and service_role (plus the owner, postgres, which is
-- never revoked). Confirm against probe A2's saved output before running; if
-- the live ACL differs from that, STOP and ask.

BEGIN;

-- 1. Undo the revoke migration (20261013110000_kan497_revoke_anon_block_rpcs.sql).
GRANT EXECUTE ON FUNCTION public.is_blocked(uuid, uuid)            TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_block_user(uuid)              TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_block_user(uuid, boolean)     TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_unblock_user(uuid)            TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_unfollow_user(uuid)           TO PUBLIC, anon, authenticated, service_role;

-- 2. Undo the narrowing migration (20261013100000_kan497_is_blocked_narrow_to_caller.sql):
--    the body below is the committed baseline definition, copied from
--    supabase/migrations/20260829080500_baseline_schema.sql line 8201, unchanged.
CREATE OR REPLACE FUNCTION "public"."is_blocked"("user_a" "uuid", "user_b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_user_id = user_a AND blocked_user_id = user_b)
       OR (blocker_user_id = user_b AND blocked_user_id = user_a)
  );
$$;

COMMIT;
