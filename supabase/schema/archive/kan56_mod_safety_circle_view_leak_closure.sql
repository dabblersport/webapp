-- KAN-56 (dedupes KAN-25/36) — the last 6 anon-readable definer views,
-- authored by backend-owner, per docs/DECISIONS.md T-029 (cto, 2026-08-29).
--
-- T-029's ruling, re-verified live against wtncuzcskpigqpmnxwws before
-- writing this file (2026-08-29):
--
--   View                    | Base relations (policy count)                          | Ruling
--   v_mod_queue_open        | moderation_reports (2), profiles (13)                   | REVOKE(anon) + scoped rewrite, stays definer (corrected below — moderation_reports is a deliberate deny-all funnel table per T-015, not a flip candidate; see the correction from team-lead/master-analyst, 2026-08-29)
--   v_circle_feed           | posts (5), post_circles (1), circles (6), circle_members (5) | FLIP
--   v_circle_feed_visible   | v_circle_feed, circle_members (5), profile_follows (4)  | FLIP, after v_circle_feed
--   v_safety_overview       | moderation_reports(2), moderation_actions(1),
--                             safety_takedowns (0), audit_events(1)                   | REVOKE(anon) + scoped rewrite (see below — no bare exemption, it had no caller filter at all)
--   v_hidden_list           | user_hidden_modes (0)                                   | REVOKE + exemption
--   v_my_drafts             | content_drafts (0)                                      | REVOKE + exemption
--
-- Anon SELECT confirmed live on all 6 before this migration; anon row
-- counts today: v_mod_queue_open 9, v_safety_overview 1, v_circle_feed 6
-- (v_circle_feed_visible/v_hidden_list/v_my_drafts already 0 for anon —
-- they self-filter on profile/uid — but the grant itself must still go).
--
-- ============================================================================
-- WHERE THIS MIGRATION DEPARTS FROM T-029, AND WHY — READ BEFORE APPLYING
-- ============================================================================
--
-- T-029's split rule ("every base relation has >=1 policy" => safe to flip)
-- is necessary but not sufficient. A relation can carry a policy that is
-- non-empty and still admit ZERO rows to the exact caller the view exists
-- to serve. Verified live, read-only, in a rolled-back transaction:
--
--   moderation_reports' only two policies are `mr_block_dml` (ALL, USING
--   false — a blanket deny) and `mr_self_insert` (INSERT only). There is
--   NO policy that ever permits a SELECT, for anyone, including an admin:
--
--     BEGIN; SET LOCAL ROLE authenticated;
--     SELECT set_config('request.jwt.claims',
--       '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
--     SELECT count(*) FROM moderation_reports;   -- measured: 0
--     ROLLBACK;
--
--   A bare flip of v_mod_queue_open would not "restrict the queue to
--   admins" as T-029 assumed — it would return 0 rows to EVERY caller,
--   including real admins, permanently. That breaks
--   lib/services/moderation_service.dart's fetchOpenModQueue(), which
--   calls this view directly as the signed-in admin's own `authenticated`
--   session (not via service_role) — this is not a hypothetical.
--
--   post_circles carries exactly one policy, `post_circles_author_manage`
--   (ALL, USING is_post_owner(...)) — written for INSERT/UPDATE/DELETE by
--   the post's own author, but because it is cmd=ALL it also governs
--   SELECT. No policy admits "I am a member of this circle" at all.
--   Verified live against a real circle post, as a profile that is not
--   its author:
--
--     BEGIN; SET LOCAL ROLE authenticated;
--     SELECT set_config('request.jwt.claim.profile_id',
--       '00000000-0000-0000-0000-000000000099', true);
--     SELECT count(*) FROM post_circles WHERE post_id = '<real circle post id>';
--     -- measured: 0
--     ROLLBACK;
--
--   Today every circle post in production happens to be authored by its
--   own circle's owner, so this has not yet visibly broken the circle
--   feed — but a bare flip would silently and permanently reduce
--   "everyone's posts in my circle" to "only my own posts, in circles I
--   also happen to own", the moment a second member posts.
--
-- CORRECTION (2026-08-29, before handoff, flagged by team-lead/master-analyst,
-- re-verified live by backend-owner): the first draft of this file closed
-- the moderation_reports gap by adding a new `mr_admin_select` RLS policy
-- to the table and flipping the view. That is wrong. `moderation_reports`'
-- `mr_block_dml` (ALL, `USING false`) is not an accidental gap — it is
-- T-015's deliberate definer-funnel pattern (the same reasoning already
-- applied to `games`/`challenge_fixtures` in Migration A, and to
-- `safety_takedowns` below in this file): the table is meant to be
-- unreachable by direct RLS-based access, full stop, with every real read
-- path going through a `SECURITY DEFINER` function or view that carries
-- its own explicit check. Adding a permissive RLS policy to the table
-- itself — even a correctly-scoped `is_admin()` one — moves the admin
-- gate from "inside a definer boundary this schema already uses
-- everywhere else for this table" to "a new, parallel access path on the
-- base table," which is a real architectural regression even though it
-- would have been functionally safe. `v_mod_queue_open` is now handled
-- the same way as `v_safety_overview` below: stays `SECURITY DEFINER`,
-- gets the admin check in the view body instead, no new base-table
-- policy. `post_circles` is a different situation — it is NOT one of the
-- 30 zero-policy T-015 tables (it has one real, if too-narrow, policy),
-- there is no admin-funnel intent behind it, and its own visibility rule
-- (public / owner / member) is a normal per-caller RLS concern, not a
-- funnel. The `post_circles_select_visible` policy stays.
--
-- post_circles: new SELECT policy mirrors circles_select's own predicate
-- exactly (public circle, OR owner, OR member-of-followers/private) so
-- post_circles visibility can never drift from circle visibility. Called
-- out for cto's G-002 review same as before — if a narrower predicate is
-- wanted, it's a one-line swap before apply.
--
-- ============================================================================

BEGIN;

-- 1. post_circles gets the SELECT policy it's missing (this is an
--    ordinary per-caller RLS gap, not a definer-funnel table — see the
--    correction note above), then v_circle_feed / v_circle_feed_visible
--    flip. No INNER JOIN in either view touches a relation whose RLS
--    could now silently drop an otherwise-visible row without a real
--    fix in place (circle_members' LEFT JOIN in v_circle_feed is just
--    for the member-count aggregate).

CREATE POLICY post_circles_select_visible ON public.post_circles
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.circles c
    WHERE c.id = post_circles.circle_id
      AND (
        c.circle_type = 'public'
        OR c.owner_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
        OR (c.circle_type IN ('followers','private') AND public.is_circle_member(c.id, auth.uid()))
      )
  )
);

ALTER VIEW public.v_circle_feed         SET (security_invoker = on);
ALTER VIEW public.v_circle_feed_visible SET (security_invoker = on);

-- 2. moderation_reports stays behind its deliberate deny-all funnel
--    (T-015) — no new policy on the table. v_mod_queue_open stays
--    SECURITY DEFINER and gets the admin check moved into the view body
--    instead, same treatment as v_safety_overview below. LEFT JOINs to
--    profiles are unchanged (a blocked profile read nulls the username
--    columns rather than dropping the report row, same as before).

CREATE OR REPLACE VIEW public.v_mod_queue_open AS
SELECT mr.id AS report_id,
    mr.status,
    mr.reason,
    mr.created_at,
    mr.target_type,
    mr.target_id,
    mr.target_user_id,
    rp.username AS reporter_username,
    tp.username AS target_username,
    mr.details
FROM ((moderation_reports mr
     LEFT JOIN profiles rp ON (((rp.user_id = mr.reporter_user_id) AND (rp.profile_type = 'player'::text))))
     LEFT JOIN profiles tp ON (((tp.user_id = mr.target_user_id) AND (tp.profile_type = 'player'::text))))
WHERE (mr.status = ANY (ARRAY['open'::report_status, 'triage'::report_status, 'escalated'::report_status]))
  AND public.is_admin(auth.uid())
ORDER BY mr.created_at;

REVOKE SELECT ON public.v_mod_queue_open FROM anon;

-- 3. Stay SECURITY DEFINER (zero-policy backing table, by design —
--    T-015/T-024: adding a policy to admit the flip would break the
--    deliberate deny-all funnel these tables exist behind). v_hidden_list
--    and v_my_drafts already filter on auth.uid() internally, so
--    authenticated keeps read (that's the legitimate "my own hidden list
--    / my own drafts" caller) and only anon's grant goes.
--
--    v_safety_overview is the one view in the REVOKE set with NO
--    per-caller filter in its own definition at all — it's a bare
--    aggregate (five correlated subqueries, no FROM/WHERE at the outer
--    level), so today ANY authenticated caller, not just admins, gets
--    the full moderation/safety counts. lib/services/moderation_service.
--    dart's fetchSafetyOverview() calls this view directly as the signed-
--    in admin's own `authenticated` session — a bare REVOKE FROM
--    authenticated (matching v_game_rating/v_challenge_standings in
--    Migration A) would close the leak by breaking that screen instead
--    of by actually scoping it. Same pattern as v_user_badges_summary in
--    Migration A: scope the view body to admins, keep it definer (so it
--    can still read safety_takedowns' zero-policy table for a real
--    admin), then only revoke anon.

CREATE OR REPLACE VIEW public.v_safety_overview AS
SELECT ( SELECT count(*) AS count
           FROM moderation_reports
          WHERE (moderation_reports.status = ANY (ARRAY['open'::report_status, 'triage'::report_status, 'escalated'::report_status]))) AS reports_open,
    ( SELECT count(*) AS count
           FROM moderation_actions
          WHERE ((moderation_actions.action = ANY (ARRAY['freeze'::mod_action, 'shadowban'::mod_action, 'ban'::mod_action])) AND ((moderation_actions.expires_at IS NULL) OR (moderation_actions.expires_at > now())))) AS active_enforcements,
    ( SELECT count(*) AS count
           FROM safety_takedowns) AS takedowns_active,
    ( SELECT count(*) AS count
           FROM audit_events
          WHERE (audit_events.created_at > (now() - '24:00:00'::interval))) AS audits_24h,
    now() AS as_of
WHERE public.is_admin(auth.uid());

REVOKE SELECT ON public.v_safety_overview FROM anon;
REVOKE SELECT ON public.v_hidden_list     FROM anon;
REVOKE SELECT ON public.v_my_drafts       FROM anon;

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply, each in its own rolled-back
-- transaction per T-025 (SET LOCAL is unsafe split across autocommitted
-- statements).
-- ============================================================================
--
-- 1. anon is fully closed out on all 6:
--    DO $$
--    BEGIN
--      SET LOCAL ROLE anon;
--      ASSERT (SELECT count(*) FROM public.v_circle_feed) = 0;
--      ASSERT (SELECT count(*) FROM public.v_circle_feed_visible) = 0;
--    END $$;
--    -- and, separately (anon has no SELECT grant at all post-migration,
--    -- so these must error, not return 0):
--    SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_mod_queue_open;    -- expect: permission denied
--    SELECT count(*) FROM public.v_safety_overview;   -- expect: permission denied
--    SELECT count(*) FROM public.v_hidden_list;        -- expect: permission denied
--    SELECT count(*) FROM public.v_my_drafts;          -- expect: permission denied
--
-- 2. THE critical one — a real admin still sees the full moderation
--    queue through the rescoped view (this is what T-029 asked to be
--    proven, and what a bare flip — or a bare REVOKE with no rescoping —
--    would have failed):
--    DO $$
--    DECLARE v_admin uuid;
--    BEGIN
--      SELECT user_id INTO v_admin FROM public.role_grants
--        WHERE role IN ('admin','super_admin') LIMIT 1;
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin)::text, true);
--      ASSERT (SELECT count(*) FROM public.v_mod_queue_open) = 9;
--      ASSERT (SELECT count(*) FROM public.v_safety_overview) = 1;
--    END $$;
--
-- 3. A non-admin authenticated caller sees nothing on either admin view
--    (the leak is closed for authenticated too, not just anon — neither
--    view was scoped to admins at all before this migration):
--    DO $$
--    DECLARE v_non_admin uuid;
--    BEGIN
--      SELECT id INTO v_non_admin FROM auth.users
--        WHERE id NOT IN (SELECT user_id FROM public.role_grants WHERE role IN ('admin','super_admin'))
--        LIMIT 1;
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_non_admin)::text, true);
--      ASSERT (SELECT count(*) FROM public.v_mod_queue_open) = 0;
--      ASSERT (SELECT count(*) FROM public.v_safety_overview) = 0;
--    END $$;
--
-- 4. A circle owner still sees their own circle's feed (regression guard
--    on the flip). Deliberately supplies ONLY `sub` — the same single
--    claim a real session carries — and nothing else, so the test can't
--    pass for a reason a real caller wouldn't have (cto's G-002 note: an
--    earlier draft injected `request.jwt.claim.profile_id` directly,
--    which would have hidden exactly the failure mode this predicate is
--    prone to — an inactive profile never getting that claim at all):
--    DO $$
--    DECLARE v_owner_profile uuid; v_owner_user uuid;
--    BEGIN
--      SELECT owner_profile_id INTO v_owner_profile FROM public.circles
--        WHERE id = '0771eb99-880c-4144-8b24-0a50dfb9750d';
--      SELECT user_id INTO v_owner_user FROM public.profiles WHERE id = v_owner_profile;
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_user)::text, true);
--      ASSERT (SELECT count(*) FROM public.v_circle_feed WHERE circle_id = '0771eb99-880c-4144-8b24-0a50dfb9750d') = 3;
--    END $$;
--
--    Known limit of this test: every live circle post today is authored
--    by its own circle's owner (see the measurement in the departure note
--    above), so this only exercises the owner branch of
--    post_circles_select_visible. It cannot demonstrate the member branch
--    (the "second member posts" case that motivated the policy) without
--    fabricating data, which this verification deliberately does not do.
--    The member branch's correctness rests on policy reasoning —
--    `is_circle_member` mirrors `circles_select`'s own member check
--    exactly, and posts.posts_select_policy (`can_view_post`) already
--    admits the same member for the post row itself — not on a row count
--    here.
--
-- 5. security_invoker flags reflect the change — only the two circle
--    views flip; v_mod_queue_open stays definer on purpose:
--    SELECT relname,
--           coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
--                      WHERE option_name = 'security_invoker'), 'false') AS security_invoker
--    FROM pg_class WHERE relname IN
--      ('v_mod_queue_open','v_circle_feed','v_circle_feed_visible');
--    -- expect: 'false' for v_mod_queue_open, 'true' for the other two.
--
-- 6. moderation_reports carries no new policy (regression guard on the
--    correction itself):
--    SELECT count(*) FROM pg_policies WHERE schemaname='public'
--      AND tablename='moderation_reports';
--    -- expect: 2 (unchanged — mr_block_dml, mr_self_insert only).
--
-- ============================================================================
-- FLAGGED, NOT FIXED HERE — for cto/cpo, separate from this ticket's scope
-- ============================================================================
--
-- v_safety_overview had zero per-caller filtering in its definition before
-- this migration (a bare aggregate, no WHERE) — meaning any signed-in
-- user, not just admins, could already read it via `authenticated`, this
-- whole time; anon was only the more visible half of that leak. This
-- migration's `WHERE is_admin(auth.uid())` rewrite closes both halves in
-- one step rather than leaving the authenticated-non-admin exposure
-- standing after the anon fix landed. Noting it here as a materially
-- different finding from "readable by anon" so it doesn't get lost as a
-- footnote — cto/cpo may want to confirm no admin dashboard code
-- silently depended on non-admins reading this.
