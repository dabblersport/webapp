-- Applied to remote as migration version 20260701170928.
--
-- Guideline 1.2 fix: the home feed RPC (the one the Flutter client calls,
-- get_home_feed(p_limit, p_cursor)) never excluded content from users the
-- caller has blocked (or who blocked the caller). Blocking must instantly
-- remove that user's content from the feed. Add a blocked-profile CTE and
-- filter all three feed paths (push/pull/discovery) by it.
CREATE OR REPLACE FUNCTION public.get_home_feed(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(activity_id uuid, activity_type text, parent_activity_id uuid, actor_profile_id uuid, created_at timestamp with time zone, seen_at timestamp with time zone, source text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_my_profile_id  uuid;
  v_my_uid         uuid := auth.uid();
  v_threshold      integer;
BEGIN
  SELECT id INTO v_my_profile_id
  FROM public.profiles WHERE user_id = v_my_uid LIMIT 1;

  IF v_my_profile_id IS NULL THEN RETURN; END IF;

  SELECT push_pull_threshold INTO v_threshold FROM public.feed_rank_config LIMIT 1;
  v_threshold := COALESCE(v_threshold, 1000);

  RETURN QUERY
  WITH blocked_profile_ids AS (
    SELECT p.id
    FROM public.profiles p
    JOIN public.user_blocks ub
      ON (ub.blocker_user_id = v_my_uid AND ub.blocked_user_id = p.user_id)
      OR (ub.blocked_user_id = v_my_uid AND ub.blocker_user_id = p.user_id)
  ),
  combined AS (
    -- Push path: pre-materialised rows for this recipient
    SELECT
      fi.activity_id,
      fi.activity_type,
      fi.parent_activity_id,
      fi.actor_profile_id,
      fi.created_at,
      fi.seen_at,
      1 AS path_priority,
      'push'::text AS source
    FROM public.feed_items fi
    WHERE fi.recipient_profile_id = v_my_profile_id
      AND fi.hidden_at IS NULL
      AND (p_cursor IS NULL OR fi.created_at < p_cursor)
      AND fi.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)

    UNION ALL

    -- Pull path: activities from high-follower users the caller follows
    SELECT
      pa.id,
      pa.activity_type,
      pa.parent_activity_id,
      pa.actor_profile_id,
      pa.created_at,
      NULL::timestamptz,
      2,
      'pull'::text
    FROM public.public_activities pa
    WHERE pa.activity_type IN ('post', 'news', 'repost', 'game_create', 'meetup_create')
      AND NOT pa.is_deleted
      AND NOT pa.is_hidden_admin
      AND (p_cursor IS NULL OR pa.created_at < p_cursor)
      AND pa.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
      AND pa.actor_profile_id IN (
        SELECT pf.following_profile_id
        FROM public.profile_follows pf
        WHERE pf.follower_profile_id = v_my_profile_id
          AND (
            SELECT COUNT(*) FROM public.profile_follows
            WHERE following_profile_id = pf.following_profile_id
          ) >= v_threshold
      )

    UNION ALL

    -- Discovery path: all recent public activities (ensures feed is never empty)
    SELECT
      pa.id,
      pa.activity_type,
      pa.parent_activity_id,
      pa.actor_profile_id,
      pa.created_at,
      NULL::timestamptz,
      3,
      'discovery'::text
    FROM public.public_activities pa
    WHERE pa.activity_type IN ('post', 'news', 'repost', 'game_create', 'meetup_create')
      AND NOT pa.is_deleted
      AND NOT pa.is_hidden_admin
      AND pa.visibility = 'public'
      AND (p_cursor IS NULL OR pa.created_at < p_cursor)
      AND pa.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
  ),
  -- Deduplicate: keep highest-priority path per activity, then sort by recency
  deduped AS (
    SELECT DISTINCT ON (c.activity_id)
      c.activity_id,
      c.activity_type,
      c.parent_activity_id,
      c.actor_profile_id,
      c.created_at,
      c.seen_at,
      c.source
    FROM combined c
    ORDER BY c.activity_id, c.path_priority ASC, c.created_at DESC
  )
  SELECT
    d.activity_id,
    d.activity_type,
    d.parent_activity_id,
    d.actor_profile_id,
    d.created_at,
    d.seen_at,
    d.source
  FROM deduped d
  ORDER BY d.created_at DESC
  LIMIT p_limit;
END;
$function$;
