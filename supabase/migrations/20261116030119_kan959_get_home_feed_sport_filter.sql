-- KAN-959: For you sport filter. public.get_home_feed gains an optional p_sport_id uuid DEFAULT NULL.
-- DROP + CREATE of a single 3-arg function (no overload), so a 2-arg named PostgREST call
-- ({p_limit, p_cursor}) resolves to it without ambiguity (checked live: HTTP 200).
-- Body re-authored from the live pg_get_functiondef (pre-image md5 guarded). The push, pull, discovery
-- union and the dedupe are unchanged; the only change is a WHERE on the deduped set, before ORDER BY / LIMIT,
-- so a filtered page stays full.
-- Rule for p_sport_id set:
--   post                        -> posts.id = activity_id, posts.sport_id = p_sport_id
--   repost                      -> the reposted post: posts.id = parent_activity_id, posts.sport_id = p_sport_id
--                                  (a repost activity's own id is not a posts.id; checked 9/9 live)
--   game_create, meetup_create  -> events.id = activity_id, events.sport_id = p_sport_id
--   news (no sport) and others  -> dropped
-- p_sport_id NULL: the predicate is true for every row; output is identical to the pre-image.
-- Attributes restored exactly: owner postgres, SECURITY DEFINER, search_path=public, EXECUTE to PUBLIC, anon,
-- authenticated, service_role (the pre-image ACL), asserted after.
-- Live test: supabase/tests/events_p4/kan959_get_home_feed_sport_filter_live_test.sql.
-- Applied under G-002 by backend-2.

DO $pre$
DECLARE v_md5 text; v_n int;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)) INTO v_md5
    FROM pg_proc p WHERE p.oid = 'public.get_home_feed(integer,timestamptz)'::regprocedure;
  IF v_md5 IS DISTINCT FROM 'b19dc3488f562fab32603cf415c0415e' THEN
    RAISE EXCEPTION 'KAN-959 pre-image md5 mismatch: %', v_md5;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'get_home_feed';
  IF v_n <> 1 THEN RAISE EXCEPTION 'KAN-959 expected one get_home_feed, found %', v_n; END IF;
END
$pre$;

DROP FUNCTION public.get_home_feed(integer, timestamp with time zone);

CREATE FUNCTION public.get_home_feed(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_sport_id uuid DEFAULT NULL::uuid)
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
  -- KAN-959 sport filter, applied before LIMIT so a filtered page stays full.
  -- NULL p_sport_id: the predicate is true for every row (output unchanged).
  -- post: posts.id = activity_id; repost: the reposted post, posts.id = parent_activity_id;
  -- game_create / meetup_create: events.id = activity_id; news and anything else: dropped.
  WHERE p_sport_id IS NULL
     OR (d.activity_type = 'post' AND EXISTS (
           SELECT 1 FROM public.posts po WHERE po.id = d.activity_id AND po.sport_id = p_sport_id))
     OR (d.activity_type = 'repost' AND EXISTS (
           SELECT 1 FROM public.posts po WHERE po.id = d.parent_activity_id AND po.sport_id = p_sport_id))
     OR (d.activity_type IN ('game_create', 'meetup_create') AND EXISTS (
           SELECT 1 FROM public.events e WHERE e.id = d.activity_id AND e.sport_id = p_sport_id))
  ORDER BY d.created_at DESC
  LIMIT p_limit;
END;
$function$;

ALTER FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid) TO PUBLIC, anon, authenticated, service_role;

DO $post$
DECLARE v_acl text; v_def boolean; v_cfg text[]; v_owner text; v_n int;
BEGIN
  SELECT (SELECT string_agg(x, ',' ORDER BY x) FROM unnest(p.proacl::text[]) x), p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner)
    INTO v_acl, v_def, v_cfg, v_owner
    FROM pg_proc p WHERE p.oid = 'public.get_home_feed(integer,timestamptz,uuid)'::regprocedure;
  IF v_acl IS DISTINCT FROM '=X/postgres,anon=X/postgres,authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres'
     OR NOT v_def OR v_cfg IS DISTINCT FROM ARRAY['search_path=public'] OR v_owner <> 'postgres' THEN
    RAISE EXCEPTION 'KAN-959 post-assert failed: acl=% secdef=% cfg=% owner=%', v_acl, v_def, v_cfg, v_owner;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'get_home_feed';
  IF v_n <> 1 THEN RAISE EXCEPTION 'KAN-959 expected one get_home_feed after, found %', v_n; END IF;
END
$post$;

NOTIFY pgrst, 'reload schema';
