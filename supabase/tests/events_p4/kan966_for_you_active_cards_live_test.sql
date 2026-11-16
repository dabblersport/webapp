-- KAN-966 live test: public.get_home_feed(p_limit, p_cursor, p_sport_id, p_sport_ids, p_cursor_id, p_cursor_kind)
-- and public.rpc_mark_feed_impressions(jsonb) (migration 20261116141927_kan966_for_you_active_cards).
-- One DO block that always ends in RAISE EXCEPTION, so every fixture change (viewer profile city/interests, a game
-- made full, a meetup moved into the past, an RSVP, impressions, a pg_temp copy of the pre-image) rolls back.
-- pg_temp.k966_old is the pre-image 4-arg body verbatim (live md5 4a5f31e4ac392587b35c3d76bed494ae, minus SECURITY
-- DEFINER), called as postgres. The new function is called as `authenticated` with request.jwt.claims of a real user
-- that has exactly one profile (so the pre-image's unordered LIMIT 1 and the new active-persona pick agree).
-- now() is fixed for the whole transaction, so repeated calls see the same clock.
-- Expected: ERROR 'KAN-966 PASS ...' with TAP lines. Any failed probe yields 'KAN-966 FAIL ...'.
-- v_neg := true is the negative control: every probe is fed the input that must make it fail
-- (see the NEG notes on each probe); all of T1..T12 must then report "not ok".
-- TAP numbers follow run order (T9, T10, T13, T11 run before T8). T13 is the KAN-966b probe (migration
-- 20261116160213): a card marked with the real RPC keeps its row and is pushed down one by a newer post.
-- Run 2026-11-16 by backend-1 after 20261116160213: v_neg=false -> PASS 13/13 (T13 rows 15->15->15->16);
-- v_neg=true -> FAIL 13 (T13 rows 15->2->2->2, the PEER-reported jump).
CREATE OR REPLACE FUNCTION pg_temp.k966_old(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_sport_id uuid DEFAULT NULL::uuid, p_sport_ids uuid[] DEFAULT NULL::uuid[])
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
          AND (SELECT COUNT(*) FROM public.profile_follows WHERE following_profile_id = pf.following_profile_id) >= v_threshold)
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
  WHERE (p_sport_id IS NULL
     OR (d.activity_type = 'post' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = d.activity_id AND po.sport_id = p_sport_id))
     OR (d.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = d.parent_activity_id AND po.sport_id = p_sport_id))
     OR (d.activity_type IN ('game_create', 'meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = d.activity_id AND e.sport_id = p_sport_id)))
    AND (p_sport_ids IS NULL
     OR (d.activity_type = 'post' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = d.activity_id AND po.sport_id = ANY (p_sport_ids)))
     OR (d.activity_type = 'repost' AND EXISTS (SELECT 1 FROM public.posts po WHERE po.id = d.parent_activity_id AND po.sport_id = ANY (p_sport_ids)))
     OR (d.activity_type IN ('game_create', 'meetup_create') AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = d.activity_id AND e.sport_id = ANY (p_sport_ids))))
  ORDER BY d.created_at DESC
  LIMIT p_limit;
END;
$function$;

DO $t$
DECLARE
  v_neg      boolean := false;
  v_uid      uuid;
  v_pid      uuid;
  v_other    uuid;
  v_int      uuid[];
  v_tap      text[] := '{}';
  v_fail     int := 0;
  v_info     text := '';
  v_n        int;
  v_m        int;
  v_bad      int;
  v_ok       boolean;
  v_c        record;
  v_full     uuid;  v_full_ev uuid;
  v_fin      uuid;  v_fin_ev uuid;
  v_join     uuid;
  v_imp      uuid;  v_imp_kind text;
  v_rn_before int;  v_rn_after int;
  v_seen1    timestamptz; v_seen2 timestamptz; v_seen_re timestamptz;
  v_err      text;
  v_s_id     uuid; v_s_kind text; v_s_fa timestamptz; v_s_n int;
  v_s_r0     bigint; v_s_r1 bigint; v_s_r2 bigint; v_s_r3 bigint;
  v_k        int := 0;
BEGIN
  CREATE TEMP TABLE _k966 ON COMMIT DROP AS
    SELECT ''::text AS lbl, 0::bigint AS rn, s.* FROM public.get_home_feed(1) s WHERE false;
  CREATE TEMP TABLE _k966o ON COMMIT DROP AS
    SELECT ''::text AS lbl, 0::bigint AS rn, s.* FROM pg_temp.k966_old(1) s WHERE false;
  GRANT ALL ON _k966, _k966o TO authenticated, anon;

  -- Viewer: the user with the most push rows among users with exactly one profile.
  SELECT p.user_id, p.id INTO v_uid, v_pid
    FROM public.feed_items fi JOIN public.profiles p ON p.id = fi.recipient_profile_id
   WHERE p.user_id IS NOT NULL
     AND (SELECT count(*) FROM public.profiles p2 WHERE p2.user_id = p.user_id) = 1
   GROUP BY p.user_id, p.id ORDER BY count(*) DESC LIMIT 1;
  SELECT p.user_id INTO v_other FROM public.profiles p
   WHERE p.user_id IS NOT NULL AND p.user_id <> v_uid ORDER BY p.created_at LIMIT 1;

  -- Fixture: the viewer lives in Dubai and is interested in the sports of every upcoming Dubai event.
  SELECT array_agg(DISTINCT e.sport_id) INTO v_int
    FROM public.events e JOIN public.areas a ON a.id = e.area_id
   WHERE NOT e.is_cancelled AND COALESCE(e.end_at, e.start_at) > now() AND a.city = 'Dubai';
  -- primary_sport is required for sport personas: use one outside v_int, so every card's sport term is the flat 14.
  UPDATE public.profiles SET city = 'Dubai', interests = v_int,
         primary_sport = (SELECT s.id FROM public.sports s WHERE s.is_active AND s.id <> ALL (v_int) ORDER BY s.name_en LIMIT 1)
   WHERE id = v_pid;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- ---------------------------------------------------------------- baseline: full feed with candidates
  INSERT INTO _k966o SELECT 'old_all', row_number() OVER (), s.* FROM pg_temp.k966_old(100000) s;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'all', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  SELECT count(*) FILTER (WHERE item_kind = 'active'), count(*) INTO v_n, v_m FROM _k966 WHERE lbl = 'all';
  v_info := v_info || format('viewer_rows=%s active=%s; ', v_m, v_n);

  -- T1: cards exist with the fixture (precondition for every card probe). NEG: viewer interests = '{}' first.
  IF v_neg THEN
    UPDATE public.profiles SET interests = '{}' WHERE id = v_pid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM _k966 WHERE lbl = 'all';
    INSERT INTO _k966 SELECT 'all', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
    EXECUTE 'RESET ROLE';
    UPDATE public.profiles SET interests = v_int WHERE id = v_pid;
  END IF;
  v_k := v_k + 1; v_ok := (SELECT count(*) FROM _k966 WHERE lbl = 'all' AND item_kind = 'active') >= 3;
  v_tap := v_tap || format('%s %s - at least 3 Active cards with the fixture', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;
  IF v_neg THEN
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM _k966 WHERE lbl = 'all';
    INSERT INTO _k966 SELECT 'all', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
    EXECUTE 'RESET ROLE';
  END IF;

  -- T2: no candidates -> posts identical to the pre-image (rows, order, all 7 legacy columns), first page and a
  -- legacy p_cursor page; and no active row. NEG: compare against the pre-image limit 49.
  UPDATE public.profiles SET interests = '{}' WHERE id = v_pid;
  INSERT INTO _k966o SELECT 'old50', row_number() OVER (), s.* FROM pg_temp.k966_old(CASE WHEN v_neg THEN 49 ELSE 50 END) s;
  INSERT INTO _k966o SELECT 'old50c', row_number() OVER (), s.* FROM pg_temp.k966_old(CASE WHEN v_neg THEN 49 ELSE 50 END,
         (SELECT created_at FROM _k966o WHERE lbl = 'old50' AND rn = 20)) s;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'none50', row_number() OVER (), s.* FROM public.get_home_feed(50) s;
  INSERT INTO _k966 SELECT 'none50c', row_number() OVER (), s.* FROM public.get_home_feed(50,
         (SELECT created_at FROM _k966o WHERE lbl = 'old50' AND rn = 20)) s;
  INSERT INTO _k966 SELECT 'none_l2', row_number() OVER (), s.* FROM public.get_home_feed(p_limit => 10, p_cursor => NULL) s;
  EXECUTE 'RESET ROLE';
  UPDATE public.profiles SET interests = v_int WHERE id = v_pid;
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966o WHERE lbl = 'old50'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966 WHERE lbl = 'none50')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966 WHERE lbl = 'none50'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966o WHERE lbl = 'old50')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966o WHERE lbl = 'old50c'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966 WHERE lbl = 'none50c')
    UNION ALL
    (SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966 WHERE lbl = 'none50c'
     EXCEPT SELECT rn, activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966o WHERE lbl = 'old50c')) x;
  v_k := v_k + 1;
  v_ok := v_bad = 0 AND (SELECT count(*) FROM _k966 WHERE lbl = 'none50') = 50
          AND NOT EXISTS (SELECT 1 FROM _k966 WHERE lbl IN ('none50', 'none50c', 'none_l2') AND item_kind <> 'post')
          AND (SELECT count(*) FROM _k966 WHERE lbl = 'none_l2') = 10;
  v_info := v_info || format('T2 diff=%s; ', v_bad);
  v_tap := v_tap || format('%s %s - no candidates: posts equal the pre-image (page 1, legacy cursor page, 2-arg call)', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T3: with candidates, the post rows are the pre-image rows minus the game_create/meetup_create rows of shown cards,
  -- in created_at order. The pre-image orders by created_at alone (14 created_at values are shared by several feed
  -- rows), so rows are compared as sets above the page's oldest created_at, plus a never-ascending order check.
  -- NEG: do not remove those rows from the pre-image.
  SELECT count(*) INTO v_bad FROM (
    (SELECT activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966
      WHERE lbl = 'all' AND item_kind = 'post'
        AND created_at > (SELECT min(created_at) FROM _k966 WHERE lbl = 'all' AND item_kind = 'post')
     EXCEPT
     SELECT o.activity_id, o.activity_type, o.parent_activity_id, o.actor_profile_id, o.created_at, o.seen_at, o.source FROM _k966o o
      WHERE o.lbl = 'old_all'
        AND o.created_at > (SELECT min(created_at) FROM _k966 WHERE lbl = 'all' AND item_kind = 'post')
        AND (v_neg OR NOT (o.activity_type IN ('game_create', 'meetup_create')
             AND o.activity_id IN (SELECT g.event_id FROM _k966 a JOIN public.games g ON g.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'game'
                                   UNION SELECT m.event_id FROM _k966 a JOIN public.meetups m ON m.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'meetup'))))
    UNION ALL
    (SELECT o.activity_id, o.activity_type, o.parent_activity_id, o.actor_profile_id, o.created_at, o.seen_at, o.source FROM _k966o o
      WHERE o.lbl = 'old_all'
        AND o.created_at > (SELECT min(created_at) FROM _k966 WHERE lbl = 'all' AND item_kind = 'post')
        AND (v_neg OR NOT (o.activity_type IN ('game_create', 'meetup_create')
             AND o.activity_id IN (SELECT g.event_id FROM _k966 a JOIN public.games g ON g.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'game'
                                   UNION SELECT m.event_id FROM _k966 a JOIN public.meetups m ON m.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'meetup')))
     EXCEPT
     SELECT activity_id, activity_type, parent_activity_id, actor_profile_id, created_at, seen_at, source FROM _k966
      WHERE lbl = 'all' AND item_kind = 'post'
        AND created_at > (SELECT min(created_at) FROM _k966 WHERE lbl = 'all' AND item_kind = 'post'))) x;
  SELECT v_bad + count(*) INTO v_bad FROM (
    SELECT created_at, lag(created_at) OVER (ORDER BY rn) prev FROM _k966 WHERE lbl = 'all' AND item_kind = 'post') o
   WHERE o.created_at > o.prev;
  v_k := v_k + 1; v_ok := v_bad = 0;
  v_info := v_info || format('T3 diff=%s; ', v_bad);
  v_tap := v_tap || format('%s %s - with candidates: posts keep the pre-image order minus card duplicates', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T4: no two adjacent active rows, and a visible post (post/repost/news) between any two cards.
  -- NEG: run the check on the cards plus the first row only.
  SELECT count(*) INTO v_bad FROM (
    SELECT item_kind, lag(item_kind) OVER (ORDER BY rn) prev_kind,
           count(*) FILTER (WHERE item_kind = 'post' AND activity_type IN ('post', 'repost', 'news'))
             OVER (ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) vis_upto,
           rn
      FROM _k966 WHERE lbl = 'all' AND (NOT v_neg OR item_kind = 'active' OR rn = 1)) w
   WHERE w.item_kind = 'active' AND w.prev_kind = 'active';
  SELECT v_bad + count(*) INTO v_bad FROM (
    SELECT a.rn, lead(a.rn) OVER (ORDER BY a.rn) nxt FROM _k966 a WHERE a.lbl = 'all' AND a.item_kind = 'active') c
   WHERE c.nxt IS NOT NULL AND NOT EXISTS (
     SELECT 1 FROM _k966 b WHERE b.lbl = 'all' AND b.rn > c.rn AND b.rn < c.nxt AND b.item_kind = 'post'
        AND b.activity_type IN ('post', 'repost', 'news')
        AND (NOT v_neg OR b.rn = 1));
  v_k := v_k + 1; v_ok := v_bad = 0;
  v_tap := v_tap || format('%s %s - never two Active cards in a row (a visible post between any two)', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T5: the first item is a post, and a visible post precedes the first card. NEG: look at the cards only.
  v_k := v_k + 1;
  v_ok := (SELECT item_kind FROM _k966 WHERE lbl = 'all' AND (NOT v_neg OR item_kind = 'active') ORDER BY rn LIMIT 1) = 'post'
      AND EXISTS (SELECT 1 FROM _k966 b WHERE b.lbl = 'all' AND b.item_kind = 'post' AND b.activity_type IN ('post', 'repost', 'news')
                     AND b.rn < (SELECT min(rn) FROM _k966 WHERE lbl = 'all' AND item_kind = 'active'));
  v_tap := v_tap || format('%s %s - the first item is a post', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T6: interests. Every card has a sport in the viewer's interests; with interests narrowed to one sport, every card
  -- is that sport and some card disappears. NEG: check against an interest set that holds none of the card sports.
  SELECT count(*) INTO v_bad FROM _k966 a
   WHERE a.lbl = 'all' AND a.item_kind = 'active'
     AND NOT EXISTS (SELECT 1 FROM public.sports s WHERE s.name_en = ANY (a.sport_names_en)
                        AND s.id = ANY (CASE WHEN v_neg THEN ARRAY[gen_random_uuid()] ELSE v_int END));
  UPDATE public.profiles SET interests = ARRAY[v_int[1]] WHERE id = v_pid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'one_sport', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  UPDATE public.profiles SET interests = v_int WHERE id = v_pid;
  SELECT v_bad + count(*) INTO v_bad FROM _k966 a
   WHERE a.lbl = 'one_sport' AND a.item_kind = 'active'
     AND NOT EXISTS (SELECT 1 FROM public.sports s WHERE s.name_en = ANY (a.sport_names_en) AND s.id = v_int[1]);
  v_k := v_k + 1;
  v_ok := v_bad = 0 AND (SELECT count(*) FROM _k966 WHERE lbl = 'one_sport' AND item_kind = 'active')
                      < (SELECT count(*) FROM _k966 WHERE lbl = 'all' AND item_kind = 'active');
  v_info := v_info || format('T6 bad=%s one_sport_cards=%s; ', v_bad, (SELECT count(*) FROM _k966 WHERE lbl = 'one_sport' AND item_kind = 'active'));
  v_tap := v_tap || format('%s %s - interests filter (always applied; narrowing interests narrows the cards)', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T7: area. Every card is in Dubai; a viewer in Cairo gets no card; a viewer in the area "Dubai Marina" gets Dubai
  -- cards. NEG: the "Cairo" viewer stays in Dubai.
  SELECT count(*) INTO v_bad FROM _k966 a WHERE a.lbl = 'all' AND a.item_kind = 'active'
     AND lower(regexp_replace(a.city, '\s+city\s*$', '', 'i')) <> 'dubai';
  UPDATE public.profiles SET city = CASE WHEN v_neg THEN 'Dubai' ELSE 'Cairo' END WHERE id = v_pid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'cairo', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  UPDATE public.profiles SET city = 'Dubai Marina' WHERE id = v_pid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'marina', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  UPDATE public.profiles SET city = 'Dubai' WHERE id = v_pid;
  v_k := v_k + 1;
  v_ok := v_bad = 0
      AND NOT EXISTS (SELECT 1 FROM _k966 WHERE lbl = 'cairo' AND item_kind = 'active')
      AND EXISTS (SELECT 1 FROM _k966 WHERE lbl = 'marina' AND item_kind = 'active')
      AND NOT EXISTS (SELECT 1 FROM _k966 WHERE lbl = 'marina' AND item_kind = 'active' AND city <> 'Dubai');
  v_info := v_info || format('T7 outside=%s cairo=%s marina=%s; ', v_bad,
    (SELECT count(*) FROM _k966 WHERE lbl = 'cairo' AND item_kind = 'active'), (SELECT count(*) FROM _k966 WHERE lbl = 'marina' AND item_kind = 'active'));
  v_tap := v_tap || format('%s %s - area filter (same city or area only)', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T9: no game_create / meetup_create row repeats an event shown as a card, while the pre-image had such rows.
  -- NEG: check the pre-image rows instead of the new output.
  SELECT count(*) INTO v_bad FROM (
    SELECT o.activity_id, o.activity_type FROM _k966 o WHERE NOT v_neg AND o.lbl = 'all'
    UNION ALL SELECT o.activity_id, o.activity_type FROM _k966o o WHERE v_neg AND o.lbl = 'old_all') r
   WHERE r.activity_type IN ('game_create', 'meetup_create')
     AND r.activity_id IN (SELECT g.event_id FROM _k966 a JOIN public.games g ON g.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'game'
                           UNION SELECT m.event_id FROM _k966 a JOIN public.meetups m ON m.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'meetup');
  SELECT count(*) INTO v_n FROM _k966o o WHERE o.lbl = 'old_all' AND o.activity_type IN ('game_create', 'meetup_create')
     AND o.activity_id IN (SELECT g.event_id FROM _k966 a JOIN public.games g ON g.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'game'
                           UNION SELECT m.event_id FROM _k966 a JOIN public.meetups m ON m.id = a.entity_id WHERE a.lbl = 'all' AND a.entity_kind = 'meetup');
  v_k := v_k + 1; v_ok := v_bad = 0 AND v_n > 0;
  v_info := v_info || format('T9 dup=%s preimage_dups_dropped=%s; ', v_bad, v_n);
  v_tap := v_tap || format('%s %s - no game_create/meetup_create duplicate of a card', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T10: stable paging over 3 pages of 10 (keyset p_cursor, p_cursor_id, p_cursor_kind) == one call of 30, no
  -- duplicates. NEG: page 2 starts from row 9 of page 1 instead of row 10.
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'p30', row_number() OVER (), s.* FROM public.get_home_feed(30) s;
  INSERT INTO _k966 SELECT 'p1', row_number() OVER (), s.* FROM public.get_home_feed(10) s;
  SELECT * INTO v_c FROM _k966 WHERE lbl = 'p1' AND rn = CASE WHEN v_neg THEN 9 ELSE 10 END;
  INSERT INTO _k966 SELECT 'p2', 10 + row_number() OVER (), s.* FROM public.get_home_feed(10, v_c.feed_at, NULL, NULL, v_c.cursor_id, v_c.item_kind) s;
  SELECT * INTO v_c FROM _k966 WHERE lbl = 'p2' AND rn = 20;
  INSERT INTO _k966 SELECT 'p3', 20 + row_number() OVER (), s.* FROM public.get_home_feed(p_limit => 10, p_cursor => v_c.feed_at, p_cursor_id => v_c.cursor_id, p_cursor_kind => v_c.item_kind) s;
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_bad FROM (
    (SELECT rn, item_kind, activity_id, cursor_id, feed_at FROM _k966 WHERE lbl IN ('p1', 'p2', 'p3')
     EXCEPT SELECT rn, item_kind, activity_id, cursor_id, feed_at FROM _k966 WHERE lbl = 'p30')
    UNION ALL
    (SELECT rn, item_kind, activity_id, cursor_id, feed_at FROM _k966 WHERE lbl = 'p30'
     EXCEPT SELECT rn, item_kind, activity_id, cursor_id, feed_at FROM _k966 WHERE lbl IN ('p1', 'p2', 'p3'))) x;
  SELECT v_bad + count(*) INTO v_bad FROM (
    SELECT item_kind, activity_id FROM _k966 WHERE lbl IN ('p1', 'p2', 'p3') GROUP BY 1, 2 HAVING count(*) > 1) d;
  v_k := v_k + 1;
  v_ok := v_bad = 0 AND (SELECT count(*) FROM _k966 WHERE lbl IN ('p1', 'p2', 'p3')) = 30
      AND EXISTS (SELECT 1 FROM _k966 WHERE lbl IN ('p1', 'p2', 'p3') AND item_kind = 'active');
  v_info := v_info || format('T10 diff=%s cards_in_30=%s; ', v_bad, (SELECT count(*) FROM _k966 WHERE lbl = 'p30' AND item_kind = 'active'));
  v_tap := v_tap || format('%s %s - stable paging over 3 pages (no duplicate, no skip)', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T11: impressions. The first card of the feed is marked (returns 1; marking it again returns 0 and keeps
  -- first_seen_at; bogus type / bad uuid items are skipped). Then its first_seen_at is set to 10 days ago: it sinks
  -- below its unseen position, its feed_at is >= first_seen_at, and no visible post newer than first_seen_at comes
  -- after it (it is not boosted again). Owner-only RLS: another user reads none of the rows and cannot insert one for
  -- this viewer.
  -- NEG: the second mark uses another entity, and first_seen_at is not moved back.
  -- T13 (KAN-966b, PEER 16385): mark the deepest card with the real RPC and the row's feed_at, no backdating.
  -- Its row must not decrease on the next two calls, and a post moved above it (a push row for an older feed post,
  -- created now) must push it down by exactly one. NEG: after marking, seen_anchor_at is overwritten with now() (the
  -- pre-fix placement, which jumps to the top), and no post is moved above.
  SELECT entity_id, entity_kind, rn, feed_at INTO v_s_id, v_s_kind, v_s_r0, v_s_fa
    FROM _k966 WHERE lbl = 'all' AND item_kind = 'active' ORDER BY rn DESC LIMIT 1;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_s_n := public.rpc_mark_feed_impressions(jsonb_build_array(
             jsonb_build_object('entity_type', v_s_kind, 'entity_id', v_s_id, 'feed_at', v_s_fa)));
  EXECUTE 'RESET ROLE';
  IF v_neg THEN
    UPDATE public.home_feed_impressions SET seen_anchor_at = now() WHERE profile_id = v_pid AND entity_id = v_s_id;
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'm1', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  INSERT INTO _k966 SELECT 'm2', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  SELECT rn INTO v_s_r1 FROM _k966 WHERE lbl = 'm1' AND item_kind = 'active' AND entity_id = v_s_id;
  SELECT rn INTO v_s_r2 FROM _k966 WHERE lbl = 'm2' AND item_kind = 'active' AND entity_id = v_s_id;
  IF NOT v_neg THEN
    INSERT INTO public.feed_items (recipient_profile_id, activity_id, actor_profile_id, activity_type, parent_activity_id, created_at)
    SELECT v_pid, a.activity_id, a.actor_profile_id, a.activity_type, a.parent_activity_id, now()
      FROM _k966 a
     WHERE a.lbl = 'm2' AND a.item_kind = 'post' AND a.activity_type = 'post' AND a.source = 'discovery' AND a.rn > v_s_r2
     ORDER BY a.rn LIMIT 1;
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'm3', row_number() OVER (), s.* FROM public.get_home_feed(500) s;
  EXECUTE 'RESET ROLE';
  SELECT rn INTO v_s_r3 FROM _k966 WHERE lbl = 'm3' AND item_kind = 'active' AND entity_id = v_s_id;
  v_k := v_k + 1;
  v_ok := v_s_n = 1 AND v_s_r1 IS NOT NULL AND v_s_r1 >= v_s_r0 AND v_s_r2 >= v_s_r1 AND v_s_r3 = v_s_r2 + 1
      AND (SELECT seen_anchor_at FROM public.home_feed_impressions WHERE profile_id = v_pid AND entity_id = v_s_id) = v_s_fa;
  v_info := v_info || format('T13 rows %s->%s->%s->%s (post moved above); ', v_s_r0, v_s_r1, v_s_r2, v_s_r3);
  v_tap := v_tap || format('%s %s - marked card keeps its row (real RPC, no backdating) and a newer post pushes it down one', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  SELECT entity_id, entity_kind, rn INTO v_imp, v_imp_kind, v_rn_before FROM _k966 WHERE lbl = 'all' AND item_kind = 'active' ORDER BY rn LIMIT 1;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_n := public.rpc_mark_feed_impressions(jsonb_build_array(jsonb_build_object('entity_type', v_imp_kind, 'entity_id', v_imp)));
  SELECT first_seen_at INTO v_seen1 FROM public.home_feed_impressions WHERE entity_id = v_imp;
  v_m := public.rpc_mark_feed_impressions(jsonb_build_array(
           jsonb_build_object('entity_type', v_imp_kind, 'entity_id', CASE WHEN v_neg THEN gen_random_uuid() ELSE v_imp END),
           jsonb_build_object('entity_type', 'bogus', 'entity_id', gen_random_uuid()),
           jsonb_build_object('entity_type', 'game', 'entity_id', 'not-a-uuid')));
  SELECT first_seen_at INTO v_seen_re FROM public.home_feed_impressions WHERE entity_id = v_imp;
  EXECUTE 'RESET ROLE';
  IF NOT v_neg THEN
    -- simulate a card first seen 10 days ago under a post of that time (KAN-966b: placement uses seen_anchor_at)
    UPDATE public.home_feed_impressions SET first_seen_at = now() - interval '10 days', seen_anchor_at = now() - interval '10 days'
     WHERE profile_id = v_pid AND entity_id = v_imp;
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'seen', row_number() OVER (), s.* FROM public.get_home_feed(1000) s;
  EXECUTE 'RESET ROLE';
  SELECT rn INTO v_rn_after FROM _k966 WHERE lbl = 'seen' AND item_kind = 'active' AND entity_id = v_imp;
  SELECT seen_anchor_at INTO v_seen2 FROM public.home_feed_impressions WHERE profile_id = v_pid AND entity_id = v_imp;
  v_k := v_k + 1;
  v_ok := v_n = 1 AND v_m = 0 AND v_seen1 IS NOT NULL AND v_seen_re = v_seen1
      AND v_rn_after > v_rn_before
      AND (SELECT feed_at FROM _k966 WHERE lbl = 'seen' AND item_kind = 'active' AND entity_id = v_imp) >= v_seen2
      AND NOT EXISTS (SELECT 1 FROM _k966 b WHERE b.lbl = 'seen' AND b.rn > v_rn_after AND b.item_kind = 'post'
                        AND b.activity_type IN ('post', 'repost', 'news') AND b.created_at >= v_seen2);
  v_info := v_info || format('T11 marked=%s remark=%s rn %s->%s; ', v_n, v_m, v_rn_before, v_rn_after);
  -- owner-only RLS, as another authenticated user
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO v_bad FROM public.home_feed_impressions WHERE profile_id = v_pid;
  BEGIN
    INSERT INTO public.home_feed_impressions (profile_id, entity_type, entity_id) VALUES (v_pid, 'game', gen_random_uuid());
    v_bad := v_bad + 1;
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  v_ok := v_ok AND v_bad = 0;
  v_tap := v_tap || format('%s %s - impressions: first first_seen_at kept, the card sinks and is not boosted again; owner-only RLS', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T8: full, finished and joined events are excluded. A capped game card is made full, a meetup card is moved into
  -- the past, the viewer RSVPs 'going' to another meetup card. NEG: no fixture change is made.
  SELECT a.entity_id, g.event_id INTO v_full, v_full_ev FROM _k966 a JOIN public.games g ON g.id = a.entity_id
   WHERE a.lbl = 'all' AND a.entity_kind = 'game' AND a.capacity IS NOT NULL ORDER BY a.rn LIMIT 1;
  SELECT a.entity_id, m.event_id INTO v_fin, v_fin_ev FROM _k966 a JOIN public.meetups m ON m.id = a.entity_id
   WHERE a.lbl = 'all' AND a.entity_kind = 'meetup' ORDER BY a.rn LIMIT 1;
  SELECT a.entity_id INTO v_join FROM _k966 a
   WHERE a.lbl = 'all' AND a.entity_kind = 'meetup' AND a.entity_id IS DISTINCT FROM v_fin ORDER BY a.rn LIMIT 1;
  IF NOT v_neg THEN
    UPDATE public.events e SET capacity = (SELECT a.participant_count FROM _k966 a WHERE a.lbl = 'all' AND a.entity_id = v_full)
     WHERE e.id = v_full_ev;
    UPDATE public.events e SET start_at = now() - interval '3 hours', end_at = now() - interval '2 hours' WHERE e.id = v_fin_ev;
    INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (v_join, v_uid, v_pid, 'going');
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k966 SELECT 'excl', row_number() OVER (), s.* FROM public.get_home_feed(5000) s;
  EXECUTE 'RESET ROLE';
  v_k := v_k + 1;
  -- control: exactly the three targeted cards leave; every other card of the baseline is still there.
  v_ok := v_full IS NOT NULL AND v_fin IS NOT NULL AND v_join IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM _k966 WHERE lbl = 'excl' AND item_kind = 'active' AND entity_id IN (v_full, v_fin, v_join))
      AND NOT EXISTS (SELECT entity_id FROM _k966 WHERE lbl = 'all' AND item_kind = 'active' AND entity_id NOT IN (v_full, v_fin, v_join)
                      EXCEPT SELECT entity_id FROM _k966 WHERE lbl = 'excl' AND item_kind = 'active');
  v_info := v_info || format('T8 full=%s fin=%s join=%s left=%s; ', v_full IS NOT NULL, v_fin IS NOT NULL, v_join IS NOT NULL,
    (SELECT count(*) FROM _k966 WHERE lbl = 'excl' AND item_kind = 'active'));
  v_tap := v_tap || format('%s %s - full, finished and joined events are excluded', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  -- T12: anon is denied get_home_feed, rpc_mark_feed_impressions and the table. NEG: run as authenticated.
  v_bad := 0;
  EXECUTE format('SET LOCAL ROLE %I', CASE WHEN v_neg THEN 'authenticated' ELSE 'anon' END);
  BEGIN PERFORM * FROM public.get_home_feed(5); v_bad := v_bad + 1;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.rpc_mark_feed_impressions('[]'::jsonb); v_bad := v_bad + 1;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM 1 FROM public.home_feed_impressions LIMIT 1; v_bad := v_bad + 1;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  EXECUTE 'RESET ROLE';
  v_k := v_k + 1; v_ok := v_bad = 0;
  v_tap := v_tap || format('%s %s - anon is denied', CASE WHEN v_ok THEN 'ok' ELSE 'not ok' END, v_k);
  IF NOT v_ok THEN v_fail := v_fail + 1; END IF;

  RAISE EXCEPTION 'KAN-966 % (neg=%) 1..% | % | %', CASE WHEN v_fail = 0 THEN 'PASS' ELSE 'FAIL ' || v_fail END, v_neg, v_k,
    array_to_string(v_tap, ' | '), v_info;
END
$t$;
