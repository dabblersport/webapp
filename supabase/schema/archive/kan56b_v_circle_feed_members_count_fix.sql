-- KAN-56 follow-up — v_circle_feed's circle_members_count corrupted by
-- the security_invoker flip. Authored by backend-owner, defect caught by
-- cto's G-002 review (KAN-56 comment 10161) after the base migration
-- (kan56_mod_safety_circle_view_leak_closure.sql) had already been
-- applied by a second, racing cto review pass that had not yet seen the
-- rejection (comment 10162, applied within a minute of the rejection).
-- This is a live production defect, not a pre-apply catch — fix ships as
-- its own migration rather than editing the already-applied file.
--
-- The defect: v_circle_feed's definition ends with
--   count(cm.member_profile_id) OVER (PARTITION BY c.id) AS circle_members_count
-- over `LEFT JOIN circle_members cm ON cm.circle_id = c.id`. Under
-- security_invoker, circle_members' own RLS (circle_members_select:
-- admits only the caller's own membership row, or rows in a circle they
-- own) applies to that LEFT JOIN — so the window count only sees the
-- circle_members rows the CALLER can see, not the rows that exist. A
-- non-owner member of a 2-person circle sees `circle_members_count = 1`
-- (their own row only), not 2.
--
-- Re-verified live, 2026-08-29, against the already-applied production
-- state (v_circle_feed.security_invoker = on, confirmed via pg_class):
--
--   actual circle_members rows for circle 0771eb99…: 2
--   as the real non-owner member (user f487f2c8…), pre-fix:
--     v_circle_feed WHERE circle_id = '0771eb99…' -> 3 rows (correct,
--     one per real post — no rows dropped, matching cto's finding that
--     this corrupts a value rather than dropping a row), each reporting
--     circle_members_count = 3 (not 2 — and not even the pre-flip value,
--     see below).
--
-- Worth recording: this window-function expression was ALREADY WRONG
-- before the KAN-56 flip, just consistently wrong for everyone. It's
-- `count(...)  OVER (PARTITION BY c.id)` with no DISTINCT and no
-- pre-aggregation, over a join that already fans out one row per post —
-- so even under the original SECURITY DEFINER (full read, no RLS), the
-- count reflects (post count in the circle) × (real member count) for
-- that partition, not the member count itself. The flip didn't invent
-- the defect, it just made an already-wrong value additionally
-- caller-dependent, which is what turned "wrong" into "silently
-- corrupted differently per viewer."
--
-- Fix: computed via a SECURITY DEFINER helper function instead of a
-- window aggregate over a caller-RLS-filtered join, so the value is
-- correct and caller-independent (any viewer who can see the circle feed
-- row at all already knows the circle exists — the member count is not
-- additional sensitive information beyond that). Uses CREATE OR REPLACE
-- VIEW, not DROP/CREATE — Postgres requires the same column name/position/
-- type, which this preserves (`bigint`, same as the original `count(...)`),
-- so existing grants and the `security_invoker` flag on v_circle_feed are
-- untouched. v_circle_feed_visible needs no change — it selects
-- `circle_members_count` straight through from v_circle_feed and picks up
-- the corrected value automatically.
--
-- No caller in lib/ or supabase/functions/ references `circle_members_count`,
-- `v_circle_feed`, or `v_circle_feed_visible` at all (grepped before writing
-- this file) — this fixes a defect before any feature depends on it, not a
-- regression in a shipped screen.
--
-- Separately flagged, NOT fixed here (different view, different defect,
-- out of this fix's scope): v_circle_feed_visible's own WHERE clause uses
-- `current_setting('request.jwt.claim.profile_id')` — the same legacy
-- singular-GUC pattern cto's review just corrected in post_circles_select_
-- visible, for the same reason (custom_access_token_hook populates
-- request.jwt.claims JSON, not this GUC). v_circle_feed_visible predates
-- KAN-56 (only its security_invoker flag was touched, not its body) and
-- is unreferenced anywhere in the app today, so it's dead rather than
-- actively broken — but it would silently show an empty feed to every
-- private/followers-circle member if it were ever wired up. Needs its own
-- ruling/fix, not bundled into this hotfix.

BEGIN;

CREATE OR REPLACE FUNCTION public.circle_member_count(p_circle_id uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT count(*) FROM public.circle_members WHERE circle_id = p_circle_id;
$$;

CREATE OR REPLACE VIEW public.v_circle_feed AS
SELECT p.id,
    p.author_profile_id,
    p.author_user_id,
    p.author_display_name,
    p.body,
    p.visibility,
    p.created_at,
    c.id AS circle_id,
    c.name AS circle_name,
    c.circle_type,
    public.circle_member_count(c.id) AS circle_members_count
FROM ((posts p
     JOIN post_circles pc ON ((pc.post_id = p.id)))
     JOIN circles c ON ((c.id = pc.circle_id)))
WHERE ((p.visibility = 'circle'::text) AND (p.is_deleted = false) AND (p.is_hidden_admin = false) AND (p.is_active = true));

-- CRITICAL, verified live before writing this: CREATE OR REPLACE VIEW
-- silently RESETS the security_invoker reloption to off (grants survive,
-- this option does not — confirmed in a rolled-back transaction against
-- the already-flipped production view: reloptions came back empty
-- immediately after CREATE OR REPLACE, before this ALTER VIEW was added).
-- Without this statement, this migration would silently re-open the exact
-- leak KAN-56 just closed — v_circle_feed would revert to running as its
-- owner (bypassing RLS) again, readable in full by anon and any
-- authenticated caller. Re-flip explicitly:
ALTER VIEW public.v_circle_feed SET (security_invoker = on);

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply.
-- ============================================================================
--
-- 1. The exact case cto measured, asserting the VALUE this time (not just
--    a row count):
--    DO $$
--    BEGIN
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims',
--        json_build_object('sub', 'f487f2c8-dea5-4d9f-8e16-8496f56ecb2f')::text, true);
--      ASSERT (SELECT count(DISTINCT circle_members_count) FROM public.v_circle_feed
--                WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d') = 1;
--      ASSERT (SELECT circle_members_count FROM public.v_circle_feed
--                WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d' LIMIT 1) = 2;
--    END $$;
--
-- 2. Same value for the owner (caller-independence — the whole point of
--    the fix):
--    DO $$
--    DECLARE v_owner_user uuid;
--    BEGIN
--      SELECT p.user_id INTO v_owner_user FROM public.circles c
--        JOIN public.profiles p ON p.id = c.owner_profile_id
--        WHERE c.id = '0771eb99-880c-4144-8b24-0a50dfb9750d';
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_user)::text, true);
--      ASSERT (SELECT circle_members_count FROM public.v_circle_feed
--                WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d' LIMIT 1) = 2;
--    END $$;
--
-- 3. Ground truth matches:
--    SELECT count(*) FROM public.circle_members WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d';
--    -- expect: 2.
--
-- 4. security_invoker survives this migration (the near-miss this file's
--    own ALTER VIEW exists to prevent):
--    SELECT coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
--             WHERE option_name = 'security_invoker'), 'false')
--    FROM pg_class WHERE relname = 'v_circle_feed';
--    -- expect: 'true'.
--
-- 5. The leak KAN-56 closed stays closed (regression guard on the same
--    near-miss, from the anon side this time):
--    BEGIN; SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_circle_feed;   -- expect: 0
--    ROLLBACK;
