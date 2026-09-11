-- Applied to remote as migration version 20260701171104.
--
-- Guideline 1.2: exclude blocked users' posts from get_feed() as well
-- (defense-in-depth alongside the get_home_feed(p_limit,p_cursor) fix,
-- which is the function actually used by the Flutter client).
-- Note: get_home_feed(p_limit,p_offset) (jsonb-returning legacy overload)
-- is left untouched — it already references a stale post_reposts.original_post_id
-- column that no longer exists (pre-existing, unrelated breakage) and is not
-- called by the client, so it is out of scope here.
CREATE OR REPLACE FUNCTION public.get_feed(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS SETOF posts
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
 SET row_security TO 'off'
AS $function$
  SELECT p.* FROM public.posts p
  WHERE p.is_deleted = false AND p.is_hidden_admin = false AND p.is_active = true
    AND can_view_post(p.id, auth.uid(), current_setting('request.jwt.claim.profile_id', true)::uuid)
    AND NOT public.is_blocked(auth.uid(), p.author_user_id)
  ORDER BY (
    (p.like_count * 2) + (p.comment_count * 3) + (p.repost_count * 4)
    + (p.view_count * 0.2) + (p.priority_score * 5)
    + get_freshness_score(p.created_at)
  ) DESC
  LIMIT p_limit OFFSET p_offset;
$function$;
