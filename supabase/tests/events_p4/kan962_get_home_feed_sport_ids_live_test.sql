-- KAN-962 live test: public.get_home_feed(p_limit, p_cursor, p_sport_id, p_sport_ids)
-- (migration 20261116043147_kan962_get_home_feed_sport_ids).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it creates (a pg_temp copy of the pre-image
-- function and a temp table) rolls back.
-- pg_temp.k962_old is the pre-image 3-arg body verbatim (live md5 625c89998680d132de02fe99b64672b2, minus SECURITY
-- DEFINER), so "both NULL equals the old output" compares against the real old function. The copy is called as
-- postgres (the real one is SECURITY DEFINER owned by postgres); the new function is called as `authenticated`.
-- Both read auth.uid() from the same request.jwt.claims (the real profile with the most push rows).
-- Sports A and B are the two most frequent sports in that viewer's whole old feed, chosen at run time.
-- Expected: ERROR 'KAN-962 PASS ...'. Any failed probe yields 'KAN-962 FAIL ...' with the list.
-- v_neg := true is the negative control: the old pages are one row shorter, the {A,B} probe passes NULL ids, the
-- paging cursor is the newest row of page 1, '{}' becomes NULL, p_sport_id-alone and the combined probes pass NULL
-- sport, and the 2-arg probe compares limit 9 against limit 10. P1, P1b, P2, P2b, P3, P4, P5, P6 and P7 then FAIL.
CREATE OR REPLACE FUNCTION pg_temp.k962_old(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_sport_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(activity_id uuid, activity_type text, parent_activity_id uuid, actor_profile_id uuid, created_at timestamp with time zone, seen_at timestamp with time zone, source text)
 LANGUAGE plpgsql
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

DO $t$
DECLARE
  v_neg     boolean := false;
  v_viewer  uuid;
  v_a       uuid;
  v_b       uuid;
  v_ab      uuid[];
  v_cursor  timestamptz;
  v_p1c     timestamptz;
  v_fail    text[] := '{}';
  v_info    text := '';
  v_n       int;
  v_bad     int;
BEGIN
  CREATE TEMP TABLE _k962 ON COMMIT DROP AS
    SELECT ''::text AS lbl, 0 AS rn, s.* FROM public.get_home_feed(1) s WHERE false;
  GRANT ALL ON _k962 TO authenticated;

  SELECT p.user_id INTO v_viewer
    FROM public.feed_items fi JOIN public.profiles p ON p.id = fi.recipient_profile_id
   WHERE p.user_id IS NOT NULL
   GROUP BY p.user_id ORDER BY count(*) DESC LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);

  -- old function (pre-image copy), as owner
  INSERT INTO _k962 SELECT 'old', row_number() OVER (), s.* FROM pg_temp.k962_old(CASE WHEN v_neg THEN 49 ELSE 50 END, NULL, NULL) s;
  INSERT INTO _k962 SELECT 'old_all', row_number() OVER (), s.* FROM pg_temp.k962_old(100000, NULL, NULL) s;
  SELECT created_at INTO v_cursor FROM _k962 WHERE lbl = 'old' AND rn = 20;
  INSERT INTO _k962 SELECT 'old_c', row_number() OVER (), s.* FROM pg_temp.k962_old(CASE WHEN v_neg THEN 49 ELSE 50 END, v_cursor, NULL) s;

  -- the two most frequent sports in the viewer's whole feed, by the matching paths
  SELECT array_agg(sp ORDER BY n DESC) INTO v_ab FROM (
    SELECT sp, count(*) n FROM (
      SELECT CASE WHEN k.activity_type = 'post' THEN (SELECT po.sport_id FROM public.posts po WHERE po.id = k.activity_id)
                  WHEN k.activity_type = 'repost' THEN (SELECT po.sport_id FROM public.posts po WHERE po.id = k.parent_activity_id)
                  WHEN k.activity_type IN ('game_create','meetup_create') THEN (SELECT e.sport_id FROM public.events e WHERE e.id = k.activity_id)
             END sp
        FROM _k962 k WHERE k.lbl = 'old_all') q
     WHERE sp IS NOT NULL GROUP BY sp ORDER BY count(*) DESC LIMIT 2) t;
  v_a := v_ab[1]; v_b := v_ab[2];
  INSERT INTO _k962 SELECT 'old_a', row_number() OVER (), s.* FROM pg_temp.k962_old(30, NULL, v_a) s;
  INSERT INTO _k962 SELECT 'two_ref', row_number() OVER (), s.* FROM pg_temp.k962_old(10, NULL, NULL) s;

  -- new function, as authenticated
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k962 SELECT 'new', row_number() OVER (), s.* FROM public.get_home_feed(50, NULL, NULL, NULL) s;
  INSERT INTO _k962 SELECT 'new_c', row_number() OVER (), s.* FROM public.get_home_feed(50, v_cursor, NULL, NULL) s;
  INSERT INTO _k962 SELECT 'ab', row_number() OVER (), s.* FROM public.get_home_feed(20, NULL, NULL, CASE WHEN v_neg THEN NULL ELSE v_ab END) s;
  INSERT INTO _k962 SELECT 'pg1', row_number() OVER (), s.* FROM public.get_home_feed(10, NULL, NULL, v_ab) s;
  EXECUTE 'RESET ROLE';
  SELECT CASE WHEN v_neg THEN max(created_at) ELSE min(created_at) END INTO v_p1c FROM _k962 WHERE lbl = 'pg1';
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k962 SELECT 'pg2', row_number() OVER (), s.* FROM public.get_home_feed(10, v_p1c, NULL, v_ab) s;
  INSERT INTO _k962 SELECT 'empty', row_number() OVER (), s.* FROM public.get_home_feed(50, NULL, NULL, CASE WHEN v_neg THEN NULL ELSE '{}'::uuid[] END) s;
  INSERT INTO _k962 SELECT 'new_a', row_number() OVER (), s.* FROM public.get_home_feed(30, NULL, CASE WHEN v_neg THEN NULL ELSE v_a END) s;
  INSERT INTO _k962 SELECT 'a_ab', row_number() OVER (), s.* FROM public.get_home_feed(30, NULL, CASE WHEN v_neg THEN NULL ELSE v_a END, v_ab) s;
  INSERT INTO _k962 SELECT 'a_b', row_number() OVER (), s.* FROM public.get_home_feed(30, NULL, CASE WHEN v_neg THEN NULL ELSE v_a END, ARRAY[v_b]) s;
  INSERT INTO _k962 SELECT 'two', row_number() OVER (), s.* FROM public.get_home_feed(CASE WHEN v_neg THEN 9 ELSE 10 END, NULL) s;
  EXECUTE 'RESET ROLE';

  v_info := format('viewer_feed=%s sports=%s; ', (SELECT count(*) FROM _k962 WHERE lbl = 'old_all'), cardinality(v_ab));
  IF cardinality(v_ab) IS DISTINCT FROM 2 THEN v_fail := v_fail || 'P0 fewer than two sports in the feed'::text; END IF;

  -- P1: both NULL == old output (rows, order, every column), first page and a cursor page
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old')) x;
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'new';
  v_info := v_info || format('null_page=%s diff=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P1 both-NULL first page differs from old'::text; END IF;
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old_c' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new_c')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new_c' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old_c')) x;
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'new_c';
  v_info := v_info || format('null_cursor_page=%s diff=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P1b both-NULL cursor page differs from old'::text; END IF;

  -- P2: p_sport_ids {A,B} returns only A or B rows, and is the first 20 qualifying rows of the whole old feed
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'ab';
  SELECT count(*) INTO v_bad FROM _k962 k WHERE k.lbl = 'ab' AND NOT ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (v_ab))));
  v_info := v_info || format('ab=%s not_ab=%s a=%s b=%s; ', v_n, v_bad,
    (SELECT count(*) FROM _k962 k WHERE k.lbl = 'ab' AND ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (ARRAY[v_a])))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (ARRAY[v_a])))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (ARRAY[v_a]))))),
    (SELECT count(*) FROM _k962 k WHERE k.lbl = 'ab' AND ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (ARRAY[v_b])))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (ARRAY[v_b])))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (ARRAY[v_b]))))));
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P2 {A,B} returned other rows or nothing'::text; END IF;
  SELECT count(*) INTO v_n FROM _k962 k WHERE k.lbl = 'old_all' AND ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (v_ab))));
  SELECT count(*) INTO v_bad FROM (
    SELECT activity_id FROM _k962 WHERE lbl = 'ab'
    EXCEPT SELECT activity_id FROM (SELECT k.activity_id FROM _k962 k WHERE k.lbl = 'old_all' AND ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (v_ab)))) ORDER BY k.rn LIMIT 20) f) x;
  v_info := v_info || format('ab_in_full_feed=%s page_not_top20=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR (SELECT count(*) FROM _k962 WHERE lbl = 'ab') <> least(20, v_n) THEN
    v_fail := v_fail || 'P2b {A,B} page is not the first full page of the filtered feed'::text;
  END IF;

  -- P3: paging with p_sport_ids has no overlap, page 2 non-empty, strictly older than page 1's cursor, still A or B
  SELECT count(*) INTO v_bad FROM _k962 a JOIN _k962 b ON a.activity_id = b.activity_id WHERE a.lbl = 'pg1' AND b.lbl = 'pg2';
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'pg2';
  v_info := v_info || format('pg1=%s pg2=%s overlap=%s; ', (SELECT count(*) FROM _k962 WHERE lbl = 'pg1'), v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 OR EXISTS (SELECT 1 FROM _k962 WHERE lbl = 'pg2' AND created_at >= v_p1c)
     OR EXISTS (SELECT 1 FROM _k962 k WHERE k.lbl = 'pg2' AND NOT ((k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = ANY (v_ab)))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = ANY (v_ab))))) THEN
    v_fail := v_fail || 'P3 p_sport_ids paging overlaps, is empty, or leaks other sports'::text;
  END IF;

  -- P4: '{}' returns no rows
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'empty';
  v_info := v_info || format('empty_array=%s; ', v_n);
  IF v_n <> 0 THEN v_fail := v_fail || 'P4 empty array returned rows'::text; END IF;

  -- P5: p_sport_id alone (3-arg call) == the pre-image with the same sport
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old_a' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new_a')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'new_a' EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k962 WHERE lbl = 'old_a')) x;
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'new_a';
  v_info := v_info || format('sport_id_alone=%s diff=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P5 p_sport_id alone differs from old'::text; END IF;

  -- P6: both set is an AND: A with {A,B} == A alone; A with {B} is empty
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, source FROM _k962 WHERE lbl = 'a_ab' EXCEPT SELECT rn, activity_id, source FROM _k962 WHERE lbl = 'old_a')
    UNION ALL
    (SELECT rn, activity_id, source FROM _k962 WHERE lbl = 'old_a' EXCEPT SELECT rn, activity_id, source FROM _k962 WHERE lbl = 'a_ab')) x;
  SELECT count(*) INTO v_n FROM _k962 WHERE lbl = 'a_b';
  v_info := v_info || format('a_and_ab_diff=%s a_and_b=%s; ', v_bad, v_n);
  IF v_bad <> 0 OR NOT EXISTS (SELECT 1 FROM _k962 WHERE lbl = 'a_ab') OR v_n <> 0 THEN
    v_fail := v_fail || 'P6 p_sport_id AND p_sport_ids is not an intersection'::text;
  END IF;

  -- P7: the 2-arg call still resolves and equals the pre-image
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, source, seen_at FROM _k962 WHERE lbl = 'two' EXCEPT SELECT rn, activity_id, source, seen_at FROM _k962 WHERE lbl = 'two_ref')
    UNION ALL
    (SELECT rn, activity_id, source, seen_at FROM _k962 WHERE lbl = 'two_ref' EXCEPT SELECT rn, activity_id, source, seen_at FROM _k962 WHERE lbl = 'two')) x;
  v_info := v_info || format('two_arg=%s diff=%s', (SELECT count(*) FROM _k962 WHERE lbl = 'two'), v_bad);
  IF v_bad <> 0 OR NOT EXISTS (SELECT 1 FROM _k962 WHERE lbl = 'two') THEN
    v_fail := v_fail || 'P7 2-arg call differs from old'::text;
  END IF;

  IF cardinality(v_fail) = 0 THEN
    RAISE EXCEPTION 'KAN-962 PASS (neg=%): %', v_neg, v_info;
  ELSE
    RAISE EXCEPTION 'KAN-962 FAIL (neg=%): % | %', v_neg, array_to_string(v_fail, '; '), v_info;
  END IF;
END
$t$;
