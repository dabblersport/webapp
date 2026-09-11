-- Applied to live DB on 2026-07-11 (migration: drop_dormant_duplicate_notification_functions).
-- Cleanup: drop dormant duplicate like/comment notification enqueuers.
-- Verified before dropping: zero attached triggers, zero pg_depend dependents,
-- no textual references from other functions or client code. The live paths are
-- fn_likes_notify (likes -> social.post_liked / social.comment_liked) and
-- trg_post_reaction_notify (reactions -> social.post_reacted).
-- Deliberately KEPT (dormant but not duplicates):
--   trg_booking_payment_notify (sole arena.payment_required enqueuer, not yet wired)
--   allow_social_notifications (helper, may be wired later)
DROP FUNCTION IF EXISTS public.trg_post_like_notify();
DROP FUNCTION IF EXISTS public.trg_post_like_notification();
DROP FUNCTION IF EXISTS public.trg_comment_like_notify();
DROP FUNCTION IF EXISTS public.notify_post_like();
