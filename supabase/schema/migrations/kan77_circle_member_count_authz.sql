-- KAN-77: circle_member_count() is a SECURITY DEFINER RPC exposed via PostgREST
-- to anon/authenticated, and returns the true member count for ANY circle id,
-- including private ones, bypassing v_circle_feed's RLS entirely.
--
-- Tested and rejected: revoking EXECUTE from PUBLIC/anon/authenticated breaks
-- v_circle_feed for legitimate signed-in users, because the view is
-- security_invoker and calls the function as the caller — a bare REVOKE turns
-- a normal feed read into a hard 42501 error for every authenticated user.
--
-- Fix: authorize INSIDE the function instead of touching the grant. Return the
-- real count only when the circle is public, the caller owns it, or the caller
-- is a member (mirrors circles_select's own USING clause); NULL otherwise. No
-- REVOKE needed — every row the view can already show a caller becomes exactly
-- the set of circles this function will answer for.
--
-- v_circle_feed's body is untouched, so its security_invoker=on flag is not
-- affected and does not need to be re-asserted here.

BEGIN;

CREATE OR REPLACE FUNCTION public.circle_member_count(p_circle_id uuid)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.circles c
      WHERE c.id = p_circle_id
        AND (
          c.circle_type = 'public'
          OR c.owner_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
          OR (
            (c.circle_type = 'followers' OR c.circle_type = 'private')
            AND public.is_circle_member(c.id, auth.uid())
          )
        )
    )
    THEN (SELECT count(*) FROM public.circle_members WHERE circle_id = p_circle_id)
    ELSE NULL
  END;
$$;

COMMIT;

-- ============================================================
-- VERIFICATION (run in a rolled-back transaction before applying live;
-- uses request.jwt.claims only, never the legacy per-claim GUCs)
-- ============================================================
--
-- BEGIN;
-- <apply the CREATE OR REPLACE above>
-- CREATE TEMP TABLE test_results (test text, result text);
-- GRANT ALL ON test_results TO anon, authenticated;
--
-- -- 1. anon direct call on private circle -> NULL
-- SET LOCAL ROLE anon;
-- RESET request.jwt.claims;
-- INSERT INTO test_results SELECT 'AC1_anon_direct',
--   public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d')::text;
-- RESET ROLE;
--
-- -- 2. signed-in non-member on private circle -> NULL
-- SET LOCAL ROLE authenticated;
-- SELECT set_config('request.jwt.claims',
--   json_build_object('sub','00000000-0000-0000-0000-000000000999')::text, true);
-- INSERT INTO test_results SELECT 'AC2_nonmember_direct',
--   public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d')::text;
-- RESET ROLE;
--
-- -- 3. legitimate member -> 2, no error
-- SET LOCAL ROLE authenticated;
-- SELECT set_config('request.jwt.claims',
--   json_build_object('sub','f487f2c8-dea5-4d9f-8e16-8496f56ecb2f')::text, true);
-- INSERT INTO test_results SELECT 'AC3_member_direct',
--   public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d')::text;
-- RESET ROLE;
--
-- -- 4. owner -> 2, same as member
-- SET LOCAL ROLE authenticated;
-- SELECT set_config('request.jwt.claims',
--   json_build_object('sub','ec959ff7-46ef-4bf2-aab4-3515b81f5846')::text, true);
-- INSERT INTO test_results SELECT 'AC4_owner_direct',
--   public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d')::text;
-- RESET ROLE;
--
-- -- 5. anon reading v_circle_feed -> 0 rows, no error
-- SET LOCAL ROLE anon;
-- RESET request.jwt.claims;
-- INSERT INTO test_results SELECT 'AC5_anon_v_circle_feed_rowcount',
--   count(*)::text FROM public.v_circle_feed;
-- RESET ROLE;
--
-- SELECT * FROM test_results ORDER BY test;
-- ROLLBACK;
--
-- MEASURED RESULTS (2026-08-29, backend-owner, rolled back):
--   AC1_anon_direct              -> NULL
--   AC2_nonmember_direct         -> NULL
--   AC3_member_direct            -> 2
--   AC4_owner_direct             -> 2
--   AC5_anon_v_circle_feed_rowcount -> 0
-- All five acceptance criteria pass. security_invoker=on confirmed unchanged
-- on v_circle_feed (reloptions still show security_invoker=on; view body not
-- touched by this migration).
