-- KAN-38 — v_comments / v_post_comments anon-read leak.
-- Migration B of 2 (see kan37_kan38_definer_view_read_sweep.sql for
-- Migration A, approved separately under G-002).
--
-- Ruled by cpo (KAN-38 comment 10109) and confirmed by cto's rejection of
-- the original draft (comment 10107): LEFT JOIN profiles, then flip.
--
-- The leak: v_comments is `comments pc JOIN profiles pr ON pr.id =
-- pc.author_profile_id`, definer, anon-readable. comments' own SELECT
-- policy already admits the right rows (own rows, or any row whose
-- parent_activity_id points at a public, non-deleted activity) — the
-- leak is that the view bypasses that policy instead of enforcing it.
-- v_post_comments is `SELECT ... FROM v_comments` and inherits whatever
-- v_comments does.
--
-- Why the original INNER JOIN draft was wrong, and why it matters more
-- than it first looked: profiles.is_active is NOT a ban/moderation flag.
-- It is Dabbler's multi-persona switch (lib/features/profile/domain/
-- services/persona_service.dart:155-221) — a user with more than one
-- profile persona has exactly one is_active = true at a time, by design,
-- flipped every time they switch personas in normal use. An INNER JOIN
-- to profiles under security_invoker therefore didn't just hide 18
-- edge-case rows once — it would have silently erased a user's comment
-- history from public posts every time they switched their active
-- persona, as an ongoing side effect of a routine product action. Not
-- acceptable collateral for closing a 1-row leak.
--
-- Measured, read-only, against production, 2026-08-28/29:
--
--   v_comments as anon today (definer):                          67
--   v_comments as anon under the rejected INNER JOIN + flip:      48
--     lost — comment author's persona currently inactive:         18 (wrong: ongoing collateral, not a fix)
--     lost — parent activity not public (the actual leak):         1
--   v_comments as anon under LEFT JOIN + flip (this migration):   66
--     lost — parent activity not public (the actual leak, only):   1
--
-- LEFT JOIN closes exactly the 1-row confidentiality leak and nothing
-- else. A comment whose author's persona is not currently public-facing
-- keeps its row; author_username/author_display_name/author_role come
-- back NULL for that comment instead of the row vanishing. This is not
-- new client-facing behaviour — it is how the app already treats an
-- embedded profile join everywhere else it reads comments+profiles
-- together. lib/data/repositories/post_repository_impl.dart:1348-1368
-- (getComments) uses PostgREST's embedded-resource join
-- `profiles!post_comments_author_profile_id_fkey(display_name)` against
-- the live comments table today, and explicitly guards
-- `if (profile is Map && profile['display_name'] != null)` before
-- setting author_display_name — i.e. the client already expects and
-- handles a missing/invisible joined profile as "no display name", not
-- as "drop the comment". lib/data/models/social/comment.dart:14-15 also
-- already types authorDisplayName and authorAvatarUrl as nullable. A
-- null author on this view matches an established, already-shipped
-- pattern, not a new one.
--
-- Client impact: neither v_comments nor v_post_comments is referenced
-- anywhere in lib/ (checked by literal and by SupabaseConfig constant —
-- the app reads the `comments` base table directly, joining profiles
-- client-side via the embedded-resource pattern above). This migration
-- changes no live screen.

BEGIN;

CREATE OR REPLACE VIEW public.v_comments AS
SELECT pc.id,
       pc.parent_activity_id,
       pc.parent_activity_id AS post_id,
       pc.parent_comment_id,
       pc.body,
       pc.is_deleted,
       pc.is_hidden_admin,
       pc.created_at,
       pc.like_count,
       pc.image_url,
       pc.gif_url,
       pr.username AS author_username,
       pr.display_name AS author_display_name,
       pr.profile_type AS author_role
FROM public.comments pc
LEFT JOIN public.profiles pr ON pr.id = pc.author_profile_id
WHERE NOT pc.is_hidden_admin;

ALTER VIEW public.v_comments      SET (security_invoker = on);
ALTER VIEW public.v_post_comments SET (security_invoker = on);

COMMIT;

-- Verification — run as postgres after apply.
--
-- 1. Row count matches the LEFT JOIN preview exactly (66, not 48 — 48
--    would mean the JOIN change didn't take, since that's the INNER JOIN
--    number):
--    SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_comments;       -- expect: 66
--    SELECT count(*) FROM public.v_post_comments;   -- expect: 66
--
-- 2. The 1 genuine leak (non-public parent activity) is closed, and
--    exactly 1 row differs from today's 67:
--    SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_comments WHERE author_username IS NULL; -- expect: > 0 (the persona-inactive rows, present with null author)
--
-- 3. security_invoker flags reflect the change:
--    SELECT relname,
--           coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
--                      WHERE option_name = 'security_invoker'), 'false') AS security_invoker
--    FROM pg_class WHERE relname IN ('v_comments','v_post_comments');
--    -- expect: 'true' for both.
