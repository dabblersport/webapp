-- KAN-77 — public.circle_member_count(uuid) is a SECURITY DEFINER RPC
-- callable directly by anon (and any authenticated caller) via PostgREST,
-- bypassing v_circle_feed's RLS entirely and leaking the true member
-- count of any circle, including private ones, to anyone who knows or
-- guesses its id. Authored by backend-owner. Found and fully
-- characterized by cto-8 immediately after applying
-- kan56b_v_circle_feed_members_count_fix.sql, which introduced the
-- function (docs/DECISIONS.md / KAN-56 comment thread). Not applied here
-- — G-002/G-006 apply.
--
-- Per T-031 (a migration file is immutable once applied): this is a NEW
-- file, not an edit to kan56b, even though it changes the same function.
--
-- Verified live before writing this file:
--   proacl on public.circle_member_count:
--     {=X/postgres, postgres=X/postgres, anon=X/postgres,
--      authenticated=X/postgres, service_role=X/postgres}
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d');
--   -- measured: 2 (the true count of a private circle, to an
--   -- unauthenticated caller)
--   ROLLBACK;
--
-- Why NOT a REVOKE (tested first, per KAN-77's own instruction not to
-- skip this): `v_circle_feed` is a security_invoker view, so it calls
-- this function AS THE CALLER. `REVOKE EXECUTE ... FROM PUBLIC, anon,
-- authenticated` closes anon's direct call, but a legitimate member
-- reading v_circle_feed then hits `ERROR 42501: permission denied for
-- function circle_member_count` — the circle feed breaks for every
-- signed-in user, not just the attacker. `REVOKE ... FROM PUBLIC, anon`
-- alone works and keeps the feed alive, but leaves any authenticated
-- caller free to enumerate counts for arbitrary circle ids by guessing
-- UUIDs — cheaper than closing it properly.
--
-- Fix: authorize inside the function instead of fighting the grant
-- matrix. Returns the count only when the circle is public, the caller
-- owns it, or the caller is a member; NULL otherwise. Closes the oracle
-- for anon AND authenticated, needs no REVOKE at all, and cannot break
-- the invoker view — every row the view can return is already one the
-- caller could see, so the function's answer never disagrees with the
-- view. Predicate mirrors circles_select / post_circles_select_visible
-- exactly (public / owner via profiles lookup / member via
-- is_circle_member(uuid, auth.uid())) — NOT
-- current_setting('request.jwt.claim.profile_id'), the legacy per-claim
-- GUC that KAN-56 already found is not populated in real sessions and
-- would silently fail this check closed for everyone.

BEGIN;

CREATE OR REPLACE FUNCTION public.circle_member_count(p_circle_id uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.circles c
      WHERE c.id = p_circle_id
        AND (
          c.circle_type = 'public'
          OR c.owner_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
          OR public.is_circle_member(c.id, auth.uid())
        )
    )
    THEN (SELECT count(*) FROM public.circle_members WHERE circle_id = p_circle_id)
    ELSE NULL
  END;
$$;

COMMIT;

-- ============================================================================
-- VERIFICATION — all 5 acceptance criteria from KAN-77, each confirmed
-- live in a rolled-back transaction before this file was posted. Per
-- KAN-77 AC6: request.jwt.claims only, never request.jwt.claim.* GUCs.
-- ============================================================================
--
-- AC1: anon calling the RPC directly for a private circle gets no usable
-- answer:
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d');
--   -- expect: NULL. Measured: NULL.
--   ROLLBACK;
--
-- AC2: a signed-in non-member calling the RPC for a private circle they
-- are not in gets no usable answer:
--   DO $$
--   DECLARE v_stranger uuid;
--   BEGIN
--     SELECT u.id INTO v_stranger FROM auth.users u
--       WHERE u.id NOT IN (
--         SELECT p.user_id FROM public.circle_members cm
--         JOIN public.profiles p ON p.id = cm.member_profile_id
--         WHERE cm.circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d'
--       ) LIMIT 1;
--     SET LOCAL ROLE authenticated;
--     PERFORM set_config('request.jwt.claims', json_build_object('sub', v_stranger)::text, true);
--     ASSERT (SELECT public.circle_member_count('0771eb99-880c-4144-8b24-0a50dfb9750d')) IS NULL;
--   END $$;
--   -- Measured: NULL.
--
-- AC3 + AC7: a legitimate member reading v_circle_feed still gets
-- circle_members_count = 2, with no error (the regression the naive
-- revoke causes):
--   DO $$
--   BEGIN
--     SET LOCAL ROLE authenticated;
--     PERFORM set_config('request.jwt.claims',
--       json_build_object('sub', 'f487f2c8-dea5-4d9f-8e16-8496f56ecb2f')::text, true);
--     ASSERT (SELECT circle_members_count FROM public.v_circle_feed
--               WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d' LIMIT 1) = 2;
--   END $$;
--   -- Measured: 2, no error.
--
-- AC4: the circle owner gets the same value as the member —
-- caller-independence survives:
--   DO $$
--   DECLARE v_owner_user uuid;
--   BEGIN
--     SELECT p.user_id INTO v_owner_user FROM public.circles c
--       JOIN public.profiles p ON p.id = c.owner_profile_id
--       WHERE c.id = '0771eb99-880c-4144-8b24-0a50dfb9750d';
--     SET LOCAL ROLE authenticated;
--     PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_user)::text, true);
--     ASSERT (SELECT circle_members_count FROM public.v_circle_feed
--               WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d' LIMIT 1) = 2;
--   END $$;
--   -- Measured: 2.
--
-- AC5: anon reading v_circle_feed still returns 0 rows, not an error:
--   BEGIN; SET LOCAL ROLE anon;
--   SELECT count(*) FROM public.v_circle_feed;
--   -- expect: 0, no error. Measured: 0.
--   ROLLBACK;
--
-- This migration does not touch v_circle_feed's body or its
-- security_invoker flag at all (only the function backing one of its
-- columns), so there is nothing to re-ALTER — the flag was never at risk
-- this time. AC7's re-ALTER requirement applies if a future fix ever
-- does CREATE OR REPLACE VIEW on v_circle_feed again; verified the flag
-- is untouched by this migration as a matter of record:
--   SELECT coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
--            WHERE option_name = 'security_invoker'), 'false')
--   FROM pg_class WHERE relname = 'v_circle_feed';
--   -- expect: 'true' (unchanged).

-- ============================================================================
-- WIDER LOOK, REPORTED NOT FIXED HERE — per KAN-77's own request
-- ============================================================================
--
-- circle_member_count is not a special case: EVERY SECURITY DEFINER
-- function in `public` is exposed by PostgREST as a callable RPC with
-- EXECUTE to PUBLIC plus explicit anon/authenticated grants (Supabase's
-- default privilege posture for the public schema). Census, measured
-- live, 2026-08-29:
--
--   SELECT count(*) FROM pg_proc p
--   JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.prosecdef
--     AND pg_get_function_arguments(p.oid) ~ '\muuid\M'
--     AND pg_get_function_result(p.oid) NOT IN ('void', 'boolean', 'trigger');
--   -- measured: 118
--
-- 118 is not "118 leaks" — most take a uuid but are mutations returning
-- their own result row (rpc_create_*, admin_take_action, request_payout),
-- or already self-check (`admin_resolve_report`, `rpc_admin_freeze_user`,
-- `admin_*` generally use `is_admin(auth.uid())`; actor-scoped RPCs like
-- `rpc_join_game`/`rpc_leave_game` act on the caller's own actor, not an
-- arbitrary id's data). But 118 is far too many to hand-triage inside
-- this ticket without turning a low-severity single-function fix into an
-- unbounded audit. Spot-checked a few return-shapes that look like the
-- same class as circle_member_count — a uuid in, private data about a row
-- the caller may not own, out, no visible auth check in the signature —
-- worth a dedicated pass rather than guessing here: `admin_whois_profile`,
-- `get_profile_by_id`, `meetup_counts`, `meetup_my_status`,
-- `rpc_get_friendship_status`, `rpc_my_venue_permissions`,
-- `rpc_submission_approval_state`, `rpc_submission_audit_timeline`. Not
-- confirmed vulnerable — not read past their signatures, that's the
-- triage this recommends, not a finding in itself. Filing as its own
-- ticket is cto/master-analyst's call, not made here.
