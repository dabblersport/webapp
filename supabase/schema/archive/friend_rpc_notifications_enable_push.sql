-- Enable push for friend request / accept notifications.
--
-- rpc_friend_request_send and rpc_friend_request_accept inserted notifications
-- directly with the IN-APP-ONLY kinds social.friend_request /
-- social.friend_accepted, so friend notifications never pushed (the
-- push-capable friend.requested / friend.accepted kinds were only emitted by a
-- dormant friend_requests_audit trigger these RPCs don't feed). They also
-- hardcoded generic titles ("Someone sent you a friend request").
--
-- This points both RPCs at the push-capable friend.* kinds and personalizes
-- the title with the actor's display name (matching process_notification_event).
-- The legacy social.friend_* kinds are left in notification_kinds because
-- historical notification rows still reference them.

CREATE OR REPLACE FUNCTION public.rpc_friend_request_send(p_peer_profile_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_my_profile_id UUID;
  v_user_id UUID;
  v_peer_user_id UUID;
  v_display_name text;
BEGIN
  SELECT user_id INTO v_my_profile_id
  FROM profiles
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_my_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile not found for current user';
  END IF;

  -- Ensure correct ordering: user_id < peer_user_id to satisfy check constraint
  IF v_my_profile_id < p_peer_profile_id THEN
    v_user_id := v_my_profile_id;
    v_peer_user_id := p_peer_profile_id;
  ELSE
    v_user_id := p_peer_profile_id;
    v_peer_user_id := v_my_profile_id;
  END IF;

  INSERT INTO friendships (user_id, peer_user_id, requested_by, status, created_at, updated_at)
  VALUES (v_user_id, v_peer_user_id, v_my_profile_id, 'pending', NOW(), NOW())
  ON CONFLICT (user_id, peer_user_id) DO UPDATE
  SET status = 'pending', requested_by = v_my_profile_id, updated_at = NOW();

  SELECT display_name INTO v_display_name
  FROM profiles
  WHERE user_id = v_my_profile_id AND is_active = true
  LIMIT 1;
  v_display_name := COALESCE(v_display_name, 'Someone');

  -- Push-capable friend.requested kind (was social.friend_request, in-app only).
  INSERT INTO notifications (to_user_id, kind_key, title, body, context, action_route, created_at)
  VALUES (
    p_peer_profile_id,
    'friend.requested',
    v_display_name || ' sent you a friend request',
    NULL,
    jsonb_build_object('from_user_id', v_my_profile_id),
    '/user-profile/' || v_my_profile_id,
    NOW()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_friend_request_accept(p_peer_profile_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_my_profile_id UUID;
  v_user_id UUID;
  v_peer_user_id UUID;
  v_display_name text;
BEGIN
  SELECT user_id INTO v_my_profile_id
  FROM profiles
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_my_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile not found for current user';
  END IF;

  IF v_my_profile_id < p_peer_profile_id THEN
    v_user_id := v_my_profile_id;
    v_peer_user_id := p_peer_profile_id;
  ELSE
    v_user_id := p_peer_profile_id;
    v_peer_user_id := v_my_profile_id;
  END IF;

  UPDATE friendships
  SET status = 'accepted', updated_at = NOW()
  WHERE user_id = v_user_id AND peer_user_id = v_peer_user_id;

  SELECT display_name INTO v_display_name
  FROM profiles
  WHERE user_id = v_my_profile_id AND is_active = true
  LIMIT 1;
  v_display_name := COALESCE(v_display_name, 'Someone');

  -- Notify the original requester. Push-capable friend.accepted kind
  -- (was social.friend_accepted, in-app only).
  INSERT INTO notifications (to_user_id, kind_key, title, body, context, action_route, created_at)
  VALUES (
    p_peer_profile_id,
    'friend.accepted',
    v_display_name || ' accepted your friend request',
    NULL,
    jsonb_build_object('from_user_id', v_my_profile_id),
    '/user-profile/' || v_my_profile_id,
    NOW()
  );
END;
$function$;
