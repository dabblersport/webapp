-- KAN-497 step 2 of 2 migrations: narrow public.is_blocked so it answers only
-- about the CALLER's own pairs.   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- Disclosure being closed (KAN-496 live check 2026-10-13, report section 2.1
-- row 1, decision D23): is_blocked(a, b) is SECURITY DEFINER, holds a PUBLIC and
-- an explicit anon EXECUTE grant, and had no caller check, so anyone with the
-- public anon key could ask whether user a blocked user b (or the reverse).
--
-- Change: ONLY the body. The function now returns false unless auth.uid() is
-- one of the two arguments:
--   * auth.uid() IS NULL (anon, service_role, cron, trigger without a JWT) -> false
--   * auth.uid() is neither user_a nor user_b                              -> false
--   * auth.uid() is user_a or user_b -> the original EXISTS, unchanged.
-- For an authenticated caller asking about their own relationships the answer
-- is identical to the baseline body (supabase/migrations/
-- 20260829080500_baseline_schema.sql, "public"."is_blocked", line 8201).
--
-- Kept exactly: signature (user_a uuid, user_b uuid) RETURNS boolean, LANGUAGE
-- sql, STABLE, SECURITY DEFINER, SET search_path TO 'public', 'pg_temp'. CREATE
-- OR REPLACE keeps the owner and every existing grant, so nothing is revoked
-- here (the grant change is the SEPARATE, later migration
-- 20261013110000_kan497_revoke_anon_block_rpcs.sql). No DROP.
--
-- Why this is safe for the callers (full map: supabase/tests/anon_block_grants/
-- CALLERS.md): every caller in the repo passes auth.uid() as the first
-- argument, or passes a viewer variable that is bound to auth.uid(), so for
-- them the answer is unchanged. Callers that run with no JWT never reach
-- is_blocked: each guards with `viewer_user_id IS NOT NULL` first.
--
-- Side effect, intended: can_view_with_scope, can_view_with_scope3 and
-- _can_view_with_scope_canonical are themselves anon-callable and take an
-- arbitrary viewer, so they were a second oracle for the same fact (they return
-- false for a blocked public pair). After this change they stop returning
-- block information to anyone but the viewer themself.

CREATE OR REPLACE FUNCTION public.is_blocked(user_a uuid, user_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN auth.uid() IS NULL THEN false
    WHEN auth.uid() IS DISTINCT FROM user_a
     AND auth.uid() IS DISTINCT FROM user_b THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.user_blocks
      WHERE (blocker_user_id = user_a AND blocked_user_id = user_b)
         OR (blocker_user_id = user_b AND blocked_user_id = user_a)
    )
  END;
$function$;

-- Post-condition (read-only): fail the migration if the shape drifted.
DO $$
DECLARE
  f oid := 'public.is_blocked(uuid,uuid)'::regprocedure;
  d boolean; cfg text[]; src text;
BEGIN
  SELECT prosecdef, proconfig, prosrc INTO d, cfg, src FROM pg_proc WHERE oid = f;
  IF NOT d THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: is_blocked lost SECURITY DEFINER';
  END IF;
  IF cfg IS NULL OR NOT (cfg @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: is_blocked search_path is %', cfg;
  END IF;
  IF src !~ 'auth\.uid\(\) IS NULL' OR src !~ 'IS DISTINCT FROM user_a' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: is_blocked is not narrowed to the caller';
  END IF;
END
$$;
