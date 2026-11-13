-- KAN-941: post discovery and friend functions read objects that do not exist; the two can_view_post overloads
-- disagreed on what 'circle' means.
--
-- Callers checked: lib/ on staging-dev (kan714-review worktree) and origin/main, supabase/functions, workers/,
-- scripts/, every pg_proc body, pg_policies, pg_views, pg_trigger, cron.job.
--   rpc_search_posts, rpc_trending_posts             no caller anywhere. Raised 42P01 (v_post_discovery).      DROP
--   rpc_search_users, v_activity_inbox()             no caller anywhere. Read public.friendships (absent).      DROP
--   rpc_friend_request_send/accept/reject, rpc_friend_remove, rpc_friend_unfriend, rpc_get_friends,
--   rpc_get_friendship_status, rpc_get_friend_suggestions, rpc_friend_requests_inbox/outbox
--                                                    Read public.friendships (absent). Only Dart callers are
--                                                    FriendsRepositoryImpl / CircleRepositoryImpl methods reached
--                                                    through providers and controllers no widget watches
--                                                    (community_providers, friends_list_provider, circles_providers
--                                                    friendInbox/Outbox, Friends/FriendRequests/SimpleFriends
--                                                    controllers; session_cleanup only invalidates them). The
--                                                    friend model is now the mutual follow (are_synced, KAN-931). DROP
--   rpc_block_user(uuid)                             live caller: home_post_row.dart, post_detail_screen.dart.
--                                                    Worked only by swallowing undefined_table on friendships.
--                                                    Dead friendships block removed.                          RE-AUTHOR
--   can_view_post(uuid,posts)                        circle went to can_view_with_scope (are_synced = mutual
--                                                    follow). Now delegates circle to can_view_post(uuid,uuid,uuid),
--                                                    the posts_select_policy function (post_circles membership). RE-AUTHOR
--
-- Re-authored from live pg_get_functiondef. CREATE OR REPLACE with the same signature, return type, language,
-- volatility, security and search_path keeps owner and ACL; the post-assert checks them.
-- Proof: supabase/tests/events_p4/kan941_post_friend_functions_test.sql.

DO $guard$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.can_view_post(uuid,posts)',                 'a0b38c0b10655f59345b18683397dd63'),
    ('public.rpc_block_user(uuid)',                      '8374cad05f49952c09cab96297118b71'),
    ('public.rpc_search_posts(text[],text,uuid,text,timestamp with time zone,integer)', 'fa62e45b2f6860a840f960730932f611'),
    ('public.rpc_trending_posts(integer,text,uuid,text[],integer)', '94d5c09c8b44ea5e3c17ed12b1ad726b'),
    ('public.rpc_friend_request_send(uuid)',             '1ae7e0e1ec85bdc7ce338cbadf66f6d4'),
    ('public.rpc_friend_request_accept(uuid)',           '161f5636dd292f3b1001fd47ee2907b4'),
    ('public.rpc_friend_request_reject(uuid)',           '56c3e4990c88debf9b0b0261f459662c'),
    ('public.rpc_friend_remove(uuid)',                   '56c3e4990c88debf9b0b0261f459662c'),
    ('public.rpc_friend_unfriend(uuid)',                 'cb45542fd074099aba3447f9d08246b4'),
    ('public.rpc_get_friends()',                         '30a347ae886d61ca064b9ea9a7f5b62f'),
    ('public.rpc_get_friendship_status(uuid)',           '78b094f20838ae33ec91dd54ff4c981a'),
    ('public.rpc_get_friend_suggestions(integer)',       'c5333dacffbea74eb131f66d852744ca'),
    ('public.rpc_friend_requests_inbox()',               'c6fc412251484cf47006d99c1561916c'),
    ('public.rpc_friend_requests_outbox()',              '25e88c03638afac6159a56100eb9d2b4'),
    ('public.rpc_search_users(text,integer)',            'bbdbf244502891677d0c3cd6efe729a5'),
    ('public.v_activity_inbox()',                        '21fe96a2ebf6a4df715e9a6237b6a6be')) v(sig, md5)
  LOOP
    IF to_regprocedure(r.sig) IS NULL THEN
      RAISE EXCEPTION 'KAN-941 guard: % is absent', r.sig;
    END IF;
    IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig)) <> r.md5 THEN
      RAISE EXCEPTION 'KAN-941 guard: % changed since the claim', r.sig;
    END IF;
  END LOOP;
END $guard$;

DROP FUNCTION public.rpc_search_posts(text[],text,uuid,text,timestamp with time zone,integer);
DROP FUNCTION public.rpc_trending_posts(integer,text,uuid,text[],integer);
DROP FUNCTION public.rpc_friend_request_send(uuid);
DROP FUNCTION public.rpc_friend_request_accept(uuid);
DROP FUNCTION public.rpc_friend_request_reject(uuid);
DROP FUNCTION public.rpc_friend_remove(uuid);
DROP FUNCTION public.rpc_friend_unfriend(uuid);
DROP FUNCTION public.rpc_get_friends();
DROP FUNCTION public.rpc_get_friendship_status(uuid);
DROP FUNCTION public.rpc_get_friend_suggestions(integer);
DROP FUNCTION public.rpc_friend_requests_inbox();
DROP FUNCTION public.rpc_friend_requests_outbox();
DROP FUNCTION public.rpc_search_users(text,integer);
DROP FUNCTION public.v_activity_inbox();

CREATE OR REPLACE FUNCTION public.can_view_post(p_viewer uuid, p_post posts)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-180: p_viewer is accepted for signature compatibility and is
  -- deliberately IGNORED. The effective viewer is auth.uid().
  -- KAN-941: circle is decided by can_view_post(uuid,uuid,uuid), the
  -- posts_select_policy function (post_circles membership), not by a follow.
  SELECT CASE
    WHEN p_post.is_deleted OR p_post.is_hidden_admin THEN false
    WHEN p_post.author_user_id = auth.uid() THEN true
    WHEN public.is_benched(p_post.author_user_id) OR public.is_frozen(p_post.author_user_id) THEN false
    WHEN public._is_hidden(auth.uid(), p_post.author_user_id) THEN false
    WHEN p_post.visibility = 'circle'
      THEN coalesce(public.can_view_post(p_post.id, auth.uid(), NULL::uuid), false)
    WHEN p_post.visibility IN ('public','private','link')
      THEN public.can_view_with_scope(auth.uid(), p_post.author_user_id, p_post.visibility, NULL)
    ELSE false
  END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_block_user(p_peer uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF v_caller = p_peer THEN RAISE EXCEPTION 'Cannot block yourself'; END IF;
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  VALUES (v_caller, p_peer)
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  DELETE FROM public.profile_follows
  WHERE (follower_profile_id IN (SELECT id FROM profiles WHERE user_id = v_caller)
     AND following_profile_id IN (SELECT id FROM profiles WHERE user_id = p_peer))
     OR (follower_profile_id IN (SELECT id FROM profiles WHERE user_id = p_peer)
     AND following_profile_id IN (SELECT id FROM profiles WHERE user_id = v_caller));
END;
$function$;

DO $assert$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.can_view_post(uuid,posts)', false, '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.rpc_block_user(uuid)',      true,  '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}')) v(sig, secdef, acl)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig)
                    AND pg_get_userbyid(p.proowner) = 'postgres' AND p.prosecdef = r.secdef
                    AND p.proconfig = ARRAY['search_path=public, pg_temp'] AND p.proacl::text = r.acl) THEN
      RAISE EXCEPTION 'KAN-941 post-assert: % owner/security/search_path/ACL drifted', r.sig;
    END IF;
  END LOOP;
  SELECT count(*) INTO n FROM pg_proc WHERE pronamespace = 'public'::regnamespace
   AND (prosrc ~* '\mfriendships\M' OR prosrc ILIKE '%v_post_discovery%');
  IF n <> 0 THEN RAISE EXCEPTION 'KAN-941 post-assert: % functions still read friendships/v_post_discovery', n; END IF;
END $assert$;
