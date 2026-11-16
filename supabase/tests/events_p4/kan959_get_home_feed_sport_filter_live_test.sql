-- KAN-959 live test: public.get_home_feed(p_limit, p_cursor, p_sport_id) (migration 20261116030119_kan959_get_home_feed_sport_filter).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it creates (a pg_temp copy of the pre-image
-- function and a temp table) rolls back.
-- pg_temp.k959_old is the pre-image 2-arg body verbatim (md5 b19dc3488f562fab32603cf415c0415e), so "NULL sport
-- equals the old output" compares against the real old function, not a recollection of it. The real function is
-- SECURITY DEFINER owned by postgres, so the copy is called as postgres; the new function is called as
-- `authenticated`. Both read auth.uid() from the same request.jwt.claims (a real profile with push rows).
-- Expected: ERROR 'KAN-959 PASS ...'. Any failed probe yields 'KAN-959 FAIL ...' with the list.
-- v_neg := true is the negative control: the NULL-equality probes compare against a page one row shorter, the padel
-- probe calls with no sport, the paging probe uses the newest row of page 1 as the cursor, and the 2-arg probe
-- compares limit 9 against limit 10. P1, P1b, P2, P2c, P3 and P4 then FAIL (seen 2026-11-16; P2b stays green, the unfiltered page also holds posts).
CREATE OR REPLACE FUNCTION pg_temp.k959_old(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
    SELECT fi.activity_id, fi.activity_type, fi.parent_activity_id, fi.actor_profile_id, fi.created_at, fi.seen_at,
      1 AS path_priority, 'push'::text AS source
    FROM public.feed_items fi
    WHERE fi.recipient_profile_id = v_my_profile_id
      AND fi.hidden_at IS NULL
      AND (p_cursor IS NULL OR fi.created_at < p_cursor)
      AND fi.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
    UNION ALL
    SELECT pa.id, pa.activity_type, pa.parent_activity_id, pa.actor_profile_id, pa.created_at, NULL::timestamptz, 2, 'pull'::text
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
          AND (SELECT COUNT(*) FROM public.profile_follows WHERE following_profile_id = pf.following_profile_id) >= v_threshold
      )
    UNION ALL
    SELECT pa.id, pa.activity_type, pa.parent_activity_id, pa.actor_profile_id, pa.created_at, NULL::timestamptz, 3, 'discovery'::text
    FROM public.public_activities pa
    WHERE pa.activity_type IN ('post', 'news', 'repost', 'game_create', 'meetup_create')
      AND NOT pa.is_deleted
      AND NOT pa.is_hidden_admin
      AND pa.visibility = 'public'
      AND (p_cursor IS NULL OR pa.created_at < p_cursor)
      AND pa.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
  ),
  deduped AS (
    SELECT DISTINCT ON (c.activity_id)
      c.activity_id, c.activity_type, c.parent_activity_id, c.actor_profile_id, c.created_at, c.seen_at, c.source
    FROM combined c
    ORDER BY c.activity_id, c.path_priority ASC, c.created_at DESC
  )
  SELECT d.activity_id, d.activity_type, d.parent_activity_id, d.actor_profile_id, d.created_at, d.seen_at, d.source
  FROM deduped d
  ORDER BY d.created_at DESC
  LIMIT p_limit;
END;
$function$;

DO $t$
DECLARE
  v_neg     boolean := false;
  c_padel   uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_viewer  uuid;
  v_cursor  timestamptz;
  v_p1c     timestamptz;
  v_fail    text[] := '{}';
  v_info    text := '';
  v_n       int;
  v_bad     int;
BEGIN
  CREATE TEMP TABLE _k959 ON COMMIT DROP AS
    SELECT ''::text AS lbl, 0 AS rn, s.* FROM public.get_home_feed(1) s WHERE false;
  GRANT ALL ON _k959 TO authenticated;

  -- a real viewer with the most push rows, so the push path is exercised
  SELECT p.user_id INTO v_viewer
    FROM public.feed_items fi JOIN public.profiles p ON p.id = fi.recipient_profile_id
   WHERE p.user_id IS NOT NULL
   GROUP BY p.user_id ORDER BY count(*) DESC LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);

  -- old function (pre-image copy), as owner
  INSERT INTO _k959 SELECT 'old', row_number() OVER (), s.* FROM pg_temp.k959_old(CASE WHEN v_neg THEN 49 ELSE 50 END, NULL) s;
  INSERT INTO _k959 SELECT 'old_all', row_number() OVER (), s.* FROM pg_temp.k959_old(100000, NULL) s;
  SELECT created_at INTO v_cursor FROM _k959 WHERE lbl = 'old' AND rn = 20;
  INSERT INTO _k959 SELECT 'old_c', row_number() OVER (), s.* FROM pg_temp.k959_old(CASE WHEN v_neg THEN 49 ELSE 50 END, v_cursor) s;

  -- new function, as authenticated
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k959 SELECT 'new', row_number() OVER (), s.* FROM public.get_home_feed(50, NULL, NULL) s;
  INSERT INTO _k959 SELECT 'new_c', row_number() OVER (), s.* FROM public.get_home_feed(50, v_cursor, NULL) s;
  INSERT INTO _k959 SELECT 'padel', row_number() OVER (), s.* FROM public.get_home_feed(30, NULL, CASE WHEN v_neg THEN NULL ELSE c_padel END) s;
  INSERT INTO _k959 SELECT 'pg1', row_number() OVER (), s.* FROM public.get_home_feed(10, NULL, c_padel) s;
  EXECUTE 'RESET ROLE';
  SELECT CASE WHEN v_neg THEN max(created_at) ELSE min(created_at) END INTO v_p1c FROM _k959 WHERE lbl = 'pg1';
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k959 SELECT 'pg2', row_number() OVER (), s.* FROM public.get_home_feed(10, v_p1c, c_padel) s;
  INSERT INTO _k959 SELECT 'two', row_number() OVER (), s.* FROM public.get_home_feed(CASE WHEN v_neg THEN 9 ELSE 10 END, NULL) s;
  INSERT INTO _k959 SELECT 'two_ref', row_number() OVER (), s.* FROM public.get_home_feed(10, NULL, NULL) s;
  EXECUTE 'RESET ROLE';

  -- P1: NULL sport == old output (rows, order by created_at, every column), first page and a cursor page
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k959 WHERE lbl = 'old'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k959 WHERE lbl = 'new')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k959 WHERE lbl = 'new'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k959 WHERE lbl = 'old')) x;
  SELECT count(*) INTO v_n FROM _k959 WHERE lbl = 'new';
  v_info := v_info || format('null_page=%s diff=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P1 NULL sport first page differs from old'::text; END IF;

  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, source, seen_at FROM _k959 WHERE lbl = 'old_c' EXCEPT SELECT rn, activity_id, source, seen_at FROM _k959 WHERE lbl = 'new_c')
    UNION ALL
    (SELECT rn, activity_id, source, seen_at FROM _k959 WHERE lbl = 'new_c' EXCEPT SELECT rn, activity_id, source, seen_at FROM _k959 WHERE lbl = 'old_c')) x;
  SELECT count(*) INTO v_n FROM _k959 WHERE lbl = 'new_c';
  v_info := v_info || format('null_cursor_page=%s diff=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P1b NULL sport cursor page differs from old'::text; END IF;

  -- P2: padel returns only padel rows by the rule, includes posts, and is the first 30 of the filtered full old feed
  SELECT count(*) INTO v_n FROM _k959 WHERE lbl = 'padel';
  SELECT count(*) INTO v_bad FROM _k959 k
   WHERE k.lbl = 'padel' AND NOT (
         (k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = c_padel))
      OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = c_padel))
      OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = c_padel)));
  v_info := v_info || format('padel=%s non_padel=%s posts=%s events=%s; ', v_n, v_bad,
    (SELECT count(*) FROM _k959 WHERE lbl = 'padel' AND activity_type IN ('post','repost')),
    (SELECT count(*) FROM _k959 WHERE lbl = 'padel' AND activity_type IN ('game_create','meetup_create')));
  IF v_bad <> 0 OR v_n = 0 THEN v_fail := v_fail || 'P2 padel filter returned non-padel rows or nothing'::text; END IF;
  IF NOT EXISTS (SELECT 1 FROM _k959 WHERE lbl = 'padel' AND activity_type = 'post') THEN
    v_fail := v_fail || 'P2b padel filter returned no post'::text;
  END IF;
  -- filter before LIMIT: the padel page equals the first 30 qualifying rows of the whole old feed
  SELECT count(*) INTO v_bad FROM (
    (SELECT activity_id FROM _k959 WHERE lbl = 'padel'
     EXCEPT SELECT activity_id FROM (
       SELECT k.activity_id FROM _k959 k WHERE k.lbl = 'old_all' AND (
            (k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = c_padel))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = c_padel))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = c_padel)))
       ORDER BY k.rn LIMIT 30) f)) x;
  SELECT count(*) INTO v_n FROM _k959 k WHERE k.lbl = 'old_all' AND (
            (k.activity_type = 'post'   AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.activity_id AND po.sport_id = c_padel))
         OR (k.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = k.parent_activity_id AND po.sport_id = c_padel))
         OR (k.activity_type IN ('game_create','meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = k.activity_id AND e.sport_id = c_padel)));
  v_info := v_info || format('padel_in_full_feed=%s page_not_top30=%s; ', v_n, v_bad);
  IF v_bad <> 0 OR (SELECT count(*) FROM _k959 WHERE lbl = 'padel') <> least(30, v_n) THEN
    v_fail := v_fail || 'P2c padel page is not the first full page of the filtered feed'::text;
  END IF;

  -- P3: paging with the filter has no overlap and page 2 is strictly older than page 1's cursor
  SELECT count(*) INTO v_bad FROM _k959 a JOIN _k959 b ON a.activity_id = b.activity_id WHERE a.lbl = 'pg1' AND b.lbl = 'pg2';
  SELECT count(*) INTO v_n FROM _k959 WHERE lbl = 'pg2';
  v_info := v_info || format('pg1=%s pg2=%s overlap=%s; ', (SELECT count(*) FROM _k959 WHERE lbl = 'pg1'), v_n, v_bad);
  IF v_bad <> 0 OR v_n = 0 OR EXISTS (SELECT 1 FROM _k959 WHERE lbl = 'pg2' AND created_at >= v_p1c) THEN
    v_fail := v_fail || 'P3 sport-filtered paging overlaps or is empty'::text;
  END IF;

  -- P4: the 2-arg call still resolves and equals the 3-arg call with NULL sport
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, source FROM _k959 WHERE lbl = 'two' EXCEPT SELECT rn, activity_id, source FROM _k959 WHERE lbl = 'two_ref')
    UNION ALL
    (SELECT rn, activity_id, source FROM _k959 WHERE lbl = 'two_ref' EXCEPT SELECT rn, activity_id, source FROM _k959 WHERE lbl = 'two')) x;
  v_info := v_info || format('two_arg=%s diff=%s', (SELECT count(*) FROM _k959 WHERE lbl = 'two'), v_bad);
  IF v_bad <> 0 OR NOT EXISTS (SELECT 1 FROM _k959 WHERE lbl = 'two') THEN
    v_fail := v_fail || 'P4 2-arg call differs from 3-arg NULL'::text;
  END IF;

  IF cardinality(v_fail) = 0 THEN
    RAISE EXCEPTION 'KAN-959 PASS (neg=%): %', v_neg, v_info;
  ELSE
    RAISE EXCEPTION 'KAN-959 FAIL (neg=%): % | %', v_neg, array_to_string(v_fail, '; '), v_info;
  END IF;
END
$t$;
