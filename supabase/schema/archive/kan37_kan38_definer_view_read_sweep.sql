-- KAN-37 + KAN-38 (partial) — definer-view anon-read sweep, backend-owner.
-- Migration A of 2 — reviewed and approved by cto under G-002, 2026-08-28
-- (KAN-38 comment 10107). Migration B (v_comments / v_post_comments) was
-- rejected as originally written and is split out to its own file, held
-- pending a cpo product ruling — see kan38_v_comments_read_sweep.sql.
--
-- Scope: v_notifications_feed + v_notifications_ranked (KAN-37, confirmed
-- 609-row leak) and 6 of KAN-38's remainder MINUS v_mod_queue_open,
-- v_safety_overview, v_circle_feed (KAN-25's scope — moderation/safety
-- data, kept as its own P0), v_circle_feed_visible (depends on the
-- still-open v_circle_feed, deferred to whoever closes KAN-25), and
-- v_comments/v_post_comments (Migration B, held).
--
-- Not touched here, and why:
--   * username_registry_public, geography_columns, geometry_columns —
--     intentionally public (see docs/DECISIONS.md T-027). The latter two
--     are supabase_admin-owned platform catalog views we cannot ALTER,
--     same reasoning as T-019/T-025 for the KAN-67 REVOKE.
--   * v_potential_vibes_default, v_recreate_quickpicks — function-backed
--     views. security_invoker is a no-op for a view selecting from a
--     function; the access control lives inside the function
--     (rpc_potential_vibes injects auth.uid() itself; rpc_recreate_suggestions
--     reads v_recreate_candidates, which already filters on uid). Documented
--     as intentional in T-027, not part of this migration.
--   * v_space_slots_today — currently broken independent of security:
--     find_slots() references public.venue_opening_hours, which does not
--     exist (superseded by the opening-hours merge migration). Errors for
--     every role including postgres. Filed as its own ticket per cto's
--     review (KAN-38 comment 10107), not fixed here.
--
-- Per docs/DECISIONS.md T-024: a definer view over a zero-policy base table
-- stays definer — flipping it to security_invoker returns zero rows to
-- everyone, forever, which is not a fix. games and challenge_fixtures are
-- both RLS-enabled with zero policies, by design (T-024, T-015): they are
-- meant to be read only through SECURITY DEFINER functions/views, not
-- directly. v_game_rating and v_challenge_standings sit on top of them, so
-- they keep their definer view and the fix is closing the SELECT grant
-- instead (T-018's "the REVOKE is the boundary, not the invoker flip").
--
-- v_user_badges_summary is a related-but-different shape: user_badges'
-- only policy is `USING (false)` for ALL commands, i.e. nobody may read it
-- directly, not even its own owner. Same "definer-only by design" pattern,
-- but here the view itself carried no per-caller filter — it returns every
-- user's badges to anyone who can read the view. The correct fix is to
-- scope the view (WHERE user_id = auth.uid()), not flip its security mode
-- — flipping would return zero rows forever, including to a legitimate
-- future "my badges" screen, because the base table's RLS blocks the
-- owner too. This is the same pattern already used elsewhere in this
-- schema (v_my_drafts, v_hidden_list, v_my_games: filters_on_uid = true,
-- security_invoker = false).
--
-- Every view in this migration selects from exactly one base relation
-- (checked per cto's correction: the two-stage T-024 rule has to be run
-- against every relation a view touches, joins included — v_comments
-- failed that check because of its JOIN to profiles, which is why it is
-- not in this file). notifications, user_reputation_aggregate and
-- meetup_attendees are each read from directly, with no join, so there is
-- no second relation whose RLS could drop otherwise-visible rows.
--
-- Client impact: `grep -rn` across lib/ for every view named below —
-- v_notifications_feed, v_notifications_ranked, v_user_reputation,
-- v_meetup_counts, v_game_rating, v_challenge_standings,
-- v_user_badges_summary — returns zero matches. The notifications feature
-- reads the `notifications` base table directly (SupabaseConfig.
-- notificationsTable), not these views. None of the other five appear
-- anywhere in lib/ either. This migration cannot blank a screen.
--
-- Preconditions measured live against wtncuzcskpigqpmnxwws, 2026-08-28,
-- independently reproduced by cto (KAN-38 comment 10107):
--   * v_notifications_feed as anon: 609 rows / 49 distinct recipients.
--   * v_game_rating as anon: 217 rows (all of them — games has zero
--     policies, so every row leaks through this specific view today).
--   * v_user_badges_summary, v_user_reputation, v_meetup_counts,
--     v_challenge_standings: 0 rows currently (user_badges,
--     user_reputation_aggregate, meetup_attendees, challenge_fixtures are
--     all empty tables today) — not a live leak yet, fixed here so it
--     never becomes one.

BEGIN;

-- 1. Flip to security_invoker = on: the backing table carries a real
--    policy that admits exactly the rows the view is meant to return, for
--    the roles that call it, and the view has no second relation whose
--    RLS could silently drop otherwise-visible rows.
ALTER VIEW public.v_notifications_feed   SET (security_invoker = on);
ALTER VIEW public.v_notifications_ranked SET (security_invoker = on);
ALTER VIEW public.v_user_reputation      SET (security_invoker = on);
ALTER VIEW public.v_meetup_counts        SET (security_invoker = on);

-- 2. Stay SECURITY DEFINER (zero-policy backing table, by design).
--    Close the read grant instead of flipping.
REVOKE SELECT ON public.v_game_rating         FROM anon, authenticated;
REVOKE SELECT ON public.v_challenge_standings FROM anon, authenticated;

-- 3. v_user_badges_summary: scope the view definition; keep it definer
--    (user_badges' RLS blocks even the row owner, so invoker would blank
--    it for everyone). Revoke anon's grant too — belt and suspenders,
--    the WHERE clause already yields 0 rows for anon since auth.uid() is
--    null with no session, but the grant should not exist regardless.
CREATE OR REPLACE VIEW public.v_user_badges_summary AS
SELECT user_id,
       jsonb_agg(
         jsonb_build_object(
           'badge_key', badge_key,
           'awarded_at', awarded_at,
           'reason', reason,
           'context', context
         ) ORDER BY awarded_at DESC
       ) AS badges
FROM public.user_badges ub
WHERE user_id = auth.uid()
GROUP BY user_id;

REVOKE SELECT ON public.v_user_badges_summary FROM anon;

COMMIT;

-- Verification — run as postgres after apply.
--
-- 1. Reads close for anon on the two direct-REVOKE views:
--    SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_game_rating;          -- expect: permission denied
--    SELECT count(*) FROM public.v_challenge_standings;   -- expect: permission denied
--    SELECT count(*) FROM public.v_user_badges_summary;   -- expect: permission denied
--
-- 2. Invoker-flip views return 0 for anon, matching their base table's
--    policy (all inside one DO block per T-025's lesson — SET LOCAL is
--    unsafe split across autocommitted statements):
--    DO $$
--    BEGIN
--      SET LOCAL ROLE anon;
--      ASSERT (SELECT count(*) FROM public.v_notifications_feed) = 0;
--      ASSERT (SELECT count(*) FROM public.v_notifications_ranked) = 0;
--      ASSERT (SELECT count(*) FROM public.v_meetup_counts) = 0;
--    END $$;
--
-- 3. An authenticated user sees only their own rows through the flipped
--    notification views (uid taken from a live notifications row; read
--    only, no mutation):
--    DO $$
--    DECLARE v_uid uuid;
--    BEGIN
--      SELECT to_user_id INTO v_uid FROM public.notifications LIMIT 1;
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid)::text, true);
--      ASSERT (SELECT count(*) FROM public.v_notifications_feed WHERE to_user_id <> v_uid) = 0;
--      ASSERT (SELECT count(*) FROM public.v_notifications_feed) > 0;
--    END $$;
--
-- 4. security_invoker flags reflect the change:
--    SELECT relname,
--           coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
--                      WHERE option_name = 'security_invoker'), 'false') AS security_invoker
--    FROM pg_class WHERE relname IN
--      ('v_notifications_feed','v_notifications_ranked','v_user_reputation','v_meetup_counts');
--    -- expect: 'true' for all four.
