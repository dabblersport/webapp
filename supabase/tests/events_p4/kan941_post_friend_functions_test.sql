-- KAN-941 live proof for supabase/migrations/20261113231811_kan941_post_friend_functions.sql. Runs on wtncuzcskpigqpmnxwws
-- as postgres (execute_sql), BEGIN ... ROLLBACK. Probes call as role authenticated with JWT claims, each in its own
-- subtransaction; errors are captured, not raised. Uses live data only, plus one rpc_block_user call (rolled back).
-- Viewer a3ba3271-... is a mutual follower of author ec959ff7-... and is not in private circle 0771eb99-..., which
-- is the only circle of circle post a92603da-... . The 9 (circle post, mutual follower) pairs live are the 3 circle
-- posts of ec959ff7 x 3 mutual followers.
-- RED before the migration: the 14 functions exist, rpc_block_user reads friendships, the 2-arg can_view_post shows
-- the circle post to the non-member, and the two overloads disagree on 9 pairs. GREEN after: every row ok.
BEGIN;
SET LOCAL client_min_messages = warning;
CREATE TEMP TABLE k941_tap (n int PRIMARY KEY, ok boolean, label text, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k941_posts (p public.posts) ON COMMIT DROP;
INSERT INTO k941_posts SELECT p FROM public.posts p
 WHERE p.author_user_id = 'ec959ff7-46ef-4bf2-aab4-3515b81f5846' AND p.visibility = 'circle';
INSERT INTO k941_posts SELECT p FROM public.posts p
 WHERE p.id = (SELECT id FROM public.posts WHERE visibility = 'public' AND NOT is_deleted AND NOT is_hidden_admin
                AND author_user_id <> 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b'
                AND NOT public.is_benched(author_user_id) AND NOT public.is_frozen(author_user_id)
                AND NOT public._is_hidden('a3ba3271-3556-4b4e-b15d-bc0851f8a64b', author_user_id)
                ORDER BY created_at DESC LIMIT 1);
GRANT SELECT ON k941_posts TO authenticated;

CREATE FUNCTION pg_temp.k941_as(v_uid uuid, v_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE v_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  RETURN v;
END $f$;

DO $t$
DECLARE
  viewer uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  author uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';
  peer   uuid := '18e15813-52bc-4f03-9a30-25dc6441223d';
  cpost  uuid := 'a92603da-bdb0-455c-b006-5f71d6542ac9';
  v text; n int; m int;
BEGIN
  -- 1. the 14 functions with no reachable caller are gone
  SELECT count(*) INTO n FROM unnest(ARRAY[
    'public.rpc_search_posts(text[],text,uuid,text,timestamp with time zone,integer)',
    'public.rpc_trending_posts(integer,text,uuid,text[],integer)',
    'public.rpc_friend_request_send(uuid)', 'public.rpc_friend_request_accept(uuid)',
    'public.rpc_friend_request_reject(uuid)', 'public.rpc_friend_remove(uuid)', 'public.rpc_friend_unfriend(uuid)',
    'public.rpc_get_friends()', 'public.rpc_get_friendship_status(uuid)', 'public.rpc_get_friend_suggestions(integer)',
    'public.rpc_friend_requests_inbox()', 'public.rpc_friend_requests_outbox()', 'public.rpc_search_users(text,integer)',
    'public.v_activity_inbox()']) s WHERE to_regprocedure(s) IS NOT NULL;
  INSERT INTO k941_tap VALUES (1, n = 0, 'dropped functions absent', n || ' of 14 still exist');

  -- 2. nothing in public still reads public.friendships or v_post_discovery
  SELECT string_agg(p.oid::regprocedure::text, ',') INTO v FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND (p.prosrc ~* '\mfriendships\M' OR p.prosrc ILIKE '%v_post_discovery%');
  INSERT INTO k941_tap VALUES (2, v IS NULL, 'no function reads friendships / v_post_discovery', coalesce(v, 'none'));

  -- 3. rpc_block_user (live caller: home_post_row, post_detail_screen) blocks as authenticated
  v := pg_temp.k941_as(viewer, format('SELECT public.rpc_block_user(%L)::text', peer));
  SELECT count(*) INTO n FROM public.user_blocks WHERE blocker_user_id = viewer AND blocked_user_id = peer;
  INSERT INTO k941_tap VALUES (3, coalesce(v, '') NOT LIKE 'ERR%' AND n = 1,
    'rpc_block_user works', coalesce(nullif(v, ''), 'void') || ', user_blocks rows=' || n);

  -- 4. precondition: viewer is a mutual follower of the author and in none of the post's circles
  SELECT count(*) INTO n FROM public.post_circles pc JOIN public.circle_members cm ON cm.circle_id = pc.circle_id
   JOIN public.profiles pr ON pr.id = cm.member_profile_id WHERE pc.post_id = cpost AND pr.user_id = viewer;
  INSERT INTO k941_tap VALUES (4, public.are_synced(viewer, author) AND n = 0, 'viewer: mutual follower, outside circle',
    'are_synced=' || public.are_synced(viewer, author) || ' memberships=' || n);

  -- 5. 2-arg overload refuses the circle post to that viewer
  v := pg_temp.k941_as(viewer, format('SELECT public.can_view_post(NULL, t.p)::text FROM k941_posts t WHERE (t.p).id = %L', cpost));
  INSERT INTO k941_tap VALUES (5, v = 'false', 'can_view_post(uuid,posts) circle non-member', coalesce(v, 'null'));

  -- 6. 3-arg overload (the posts policy) refuses it too
  v := pg_temp.k941_as(viewer, format('SELECT public.can_view_post(%L, auth.uid(), NULL::uuid)::text', cpost));
  INSERT INTO k941_tap VALUES (6, v = 'false', 'can_view_post(uuid,uuid,uuid) circle non-member', coalesce(v, 'null'));

  -- 7. the overloads agree on all 9 (circle post, mutual follower) pairs
  n := 0; m := 0;
  FOR v IN SELECT format('%s|%s', (t.p).id, u.user_id) FROM k941_posts t
             CROSS JOIN (VALUES ('28307fab-5da4-4776-98ac-cbe993414b82'::uuid), (viewer), ('f487f2c8-dea5-4d9f-8e16-8496f56ecb2f'::uuid)) u(user_id)
            WHERE (t.p).visibility = 'circle' LOOP
    m := m + 1;
    IF pg_temp.k941_as(split_part(v, '|', 2)::uuid, format('SELECT public.can_view_post(NULL, t.p)::text FROM k941_posts t WHERE (t.p).id = %L', split_part(v, '|', 1)))
       IS DISTINCT FROM pg_temp.k941_as(split_part(v, '|', 2)::uuid, format('SELECT public.can_view_post(%L, auth.uid(), NULL::uuid)::text', split_part(v, '|', 1)))
    THEN n := n + 1; END IF;
  END LOOP;
  INSERT INTO k941_tap VALUES (7, m = 9 AND n = 0, 'overloads agree on circle pairs', n || ' of ' || m || ' disagree');

  -- 8. the author still sees the circle post through both
  v := pg_temp.k941_as(author, format('SELECT public.can_view_post(NULL, t.p)::text || ''/'' || public.can_view_post(%L, auth.uid(), NULL::uuid)::text FROM k941_posts t WHERE (t.p).id = %L', cpost, cpost));
  INSERT INTO k941_tap VALUES (8, v = 'true/true', 'author sees own circle post', coalesce(v, 'null'));

  -- 9. a public post is still visible through the 2-arg overload
  v := pg_temp.k941_as(viewer, 'SELECT public.can_view_post(NULL, t.p)::text FROM k941_posts t WHERE (t.p).visibility = ''public''');
  INSERT INTO k941_tap VALUES (9, v = 'true', 'public post visible via 2-arg', coalesce(v, 'null'));
END $t$;

SELECT (SELECT count(*) FILTER (WHERE ok) || '/' || count(*) FROM k941_tap) AS passed,
       string_agg(n || ' ' || CASE WHEN ok THEN 'ok ' ELSE 'NOT ok ' END || label || ' [' || detail || ']', E'\n' ORDER BY n) AS tap
  FROM k941_tap;
ROLLBACK;
