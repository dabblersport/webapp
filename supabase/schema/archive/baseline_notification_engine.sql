-- =====================================================================
-- BASELINE: Notification fan-out engine
-- =====================================================================
-- This file is a BASELINE capture of the existing Dabbler notification
-- fan-out engine. It documents database objects (functions + triggers)
-- that previously lived ONLY in the Supabase database
-- (project wtncuzcskpigqpmnxwws) and were not under version control.
--
-- This is a faithful dump produced via pg_get_functiondef() /
-- pg_get_triggerdef(). The SQL bodies are reproduced exactly as returned
-- by Postgres -- they are NOT paraphrased or "cleaned up".
--
-- Engine overview (data flow):
--   1. Domain events fire enqueuer triggers (e.g. a row inserted into
--      likes, comments, game_invites, friend_requests_audit, ...).
--   2. Each enqueuer trigger function calls
--      public.process_notification_event(...), which either:
--        - inserts a notification immediately (no aggregation rule), or
--        - upserts into public.notification_aggregates, coalescing
--          multiple actors within an aggregation window.
--   3. public.flush_notification_aggregates() runs on a schedule, expands
--      expired aggregate windows into final rows in public.notifications.
--   4. Inserts into public.notifications are picked up by the push
--      trigger (trg_push_on_notification_insert), which dispatches push.
--
-- NOTE: The push trigger itself (trg_push_on_notification_insert and its
-- function) is NOT captured here -- it is documented separately in
-- fix_push_trigger_edge_auth.sql and
-- enforce_notification_settings_in_push_trigger.sql.
-- =====================================================================


-- Core functions
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_notification_event(p_to_user_id uuid, p_kind_key text, p_entity_type text, p_entity_id uuid, p_actor_user_id uuid, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rule RECORD;
    v_existing RECORD;
    v_last_event timestamptz;
    v_new_actors uuid[];
    v_display_name text;
    v_final_title text;
BEGIN

    -- Prevent rapid duplicate spam (10 sec window)
    SELECT updated_at
    INTO v_last_event
    FROM public.notification_aggregates
    WHERE to_user_id = p_to_user_id
      AND kind_key = p_kind_key
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND is_flushed = false
      AND p_actor_user_id = ANY(actors)
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_last_event IS NOT NULL
       AND v_last_event > now() - interval '10 seconds'
    THEN
        RETURN;
    END IF;

    -- Look up actor display name for title generation
    SELECT display_name INTO v_display_name
    FROM public.profiles
    WHERE user_id = p_actor_user_id AND is_active = true
    LIMIT 1;

    v_display_name := COALESCE(v_display_name, 'Someone');

    -- Generate title if not provided
    IF p_title IS NOT NULL THEN
        v_final_title := p_title;
    ELSE
        v_final_title := CASE p_kind_key
            WHEN 'social.post_liked'           THEN v_display_name || ' liked your post'
            WHEN 'social.post_commented'       THEN v_display_name || ' commented on your post'
            WHEN 'social.post_reacted'         THEN v_display_name || ' reacted to your post'
            WHEN 'social.comment_liked'        THEN v_display_name || ' liked your comment'
            WHEN 'social.followed'             THEN v_display_name || ' started following you'
            WHEN 'social.circle_joined'        THEN v_display_name || ' joined your circle'
            WHEN 'social.mentioned_in_post'    THEN v_display_name || ' mentioned you in a post'
            WHEN 'social.mentioned_in_comment' THEN v_display_name || ' mentioned you in a comment'
            WHEN 'friend.requested'            THEN v_display_name || ' sent you a friend request'
            WHEN 'friend.accepted'             THEN v_display_name || ' accepted your friend request'
            WHEN 'game.invited'                THEN v_display_name || ' invited you to a game'
            WHEN 'game.join_request'           THEN v_display_name || ' wants to join your game'
            WHEN 'game.updated'                THEN 'A game you joined was updated'
            WHEN 'game.waitlist_promoted'      THEN 'You''ve been promoted from the waitlist'
            WHEN 'meetup.invited'              THEN v_display_name || ' invited you to a meetup'
            WHEN 'squad.invited'               THEN v_display_name || ' invited you to a squad'
            WHEN 'arena.payment_required'      THEN 'Payment required for your booking'
            WHEN 'reward.badge_awarded'        THEN 'You earned a new badge!'
            ELSE 'New notification'
        END;
    END IF;

    -- Try to get aggregation rule
    SELECT *
    INTO v_rule
    FROM public.notification_aggregation_rules
    WHERE kind_key = p_kind_key
      AND enabled = true;

    -- If NO aggregation rule → instant insert
    IF NOT FOUND THEN
        INSERT INTO public.notifications (
            to_user_id,
            kind_key,
            title,
            body,
            context,
            priority,
            is_read,
            created_at
        )
        VALUES (
            p_to_user_id,
            p_kind_key,
            v_final_title,
            p_body,
            jsonb_build_object(
                'entity_type', p_entity_type,
                'entity_id', p_entity_id,
                'actor_user_id', p_actor_user_id,
                'actor_display_name', v_display_name
            ),
            'normal',
            false,
            now()
        );

        RETURN;
    END IF;

    -- Aggregated path
    SELECT *
    INTO v_existing
    FROM public.notification_aggregates
    WHERE to_user_id = p_to_user_id
      AND kind_key = p_kind_key
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND is_flushed = false
      AND window_expires_at > now()
    LIMIT 1;

    IF FOUND THEN

        SELECT ARRAY(
            SELECT DISTINCT x
            FROM unnest(v_existing.actors || p_actor_user_id) AS t(x)
        )
        INTO v_new_actors;

        UPDATE public.notification_aggregates
        SET actors = v_new_actors,
            total_count = array_length(v_new_actors, 1),
            updated_at = now()
        WHERE id = v_existing.id;

    ELSE

        INSERT INTO public.notification_aggregates (
            to_user_id,
            kind_key,
            entity_type,
            entity_id,
            actors,
            total_count,
            window_started_at,
            window_expires_at
        )
        VALUES (
            p_to_user_id,
            p_kind_key,
            p_entity_type,
            p_entity_id,
            ARRAY[p_actor_user_id],
            1,
            now(),
            now() + make_interval(secs => v_rule.aggregation_window_seconds)
        );

    END IF;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.flush_notification_aggregates()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_record RECORD;
    v_count integer := 0;
    v_title text;
    v_body text;
    v_route text;
    v_context jsonb;
    v_display_name text;
BEGIN

FOR v_record IN
    SELECT *
    FROM public.notification_aggregates
    WHERE is_flushed = false
      AND window_expires_at <= now()
LOOP

    -- Look up the first actor's display name
    SELECT display_name INTO v_display_name
    FROM public.profiles
    WHERE user_id = v_record.actors[1] AND is_active = true
    LIMIT 1;

    v_display_name := COALESCE(v_display_name, 'Someone');
    v_body := NULL;

    -- ==============================
    -- SOCIAL: POST LIKED
    -- ==============================
    IF v_record.kind_key = 'social.post_liked' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' liked your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others liked your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: POST COMMENTED
    -- ==============================
    ELSIF v_record.kind_key = 'social.post_commented' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' commented on your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others commented on your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: POST REACTED
    -- ==============================
    ELSIF v_record.kind_key = 'social.post_reacted' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' reacted to your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others reacted to your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: FOLLOWED
    -- ==============================
    ELSIF v_record.kind_key = 'social.followed' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' started following you';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others started following you';
        END IF;

        v_route := '/user-profile/' || v_record.actors[1]::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'follower_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: CIRCLE JOINED
    -- ==============================
    ELSIF v_record.kind_key = 'social.circle_joined' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' joined your circle';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others joined your circle';
        END IF;

        v_route := '/user-profile/' || v_record.actors[1]::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- DEFAULT FALLBACK
    -- ==============================
    ELSE
        v_title := 'New Activity';
        v_route := null;
        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id
        );
    END IF;

    -- ==============================
    -- INSERT FINAL NOTIFICATION
    -- ==============================

    INSERT INTO public.notifications (
        to_user_id,
        kind_key,
        title,
        body,
        action_route,
        context,
        priority,
        ai_score,
        interaction_count,
        created_at
    )
    VALUES (
        v_record.to_user_id,
        v_record.kind_key,
        v_title,
        v_body,
        v_route,
        v_context,
        'normal',
        1,
        0,
        now()
    );

    -- mark as flushed
    UPDATE public.notification_aggregates
    SET is_flushed = true
    WHERE id = v_record.id;

    v_count := v_count + 1;

END LOOP;

RETURN v_count;

END;
$function$
;


-- Enqueuer trigger functions
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_likes_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_uid   uuid;
  v_activity_type text;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT pa.actor_user_id, pa.activity_type
    INTO v_target_uid, v_activity_type
  FROM public.public_activities pa
  WHERE pa.id = NEW.parent_activity_id;

  -- Don't notify if liking your own content
  IF v_target_uid IS NULL OR v_target_uid = NEW.actor_user_id THEN RETURN NEW; END IF;

  PERFORM public.process_notification_event(
    v_target_uid,
    CASE v_activity_type
      WHEN 'comment' THEN 'social.comment_liked'
      ELSE 'social.post_liked'
    END,
    v_activity_type,
    NEW.parent_activity_id,
    NEW.actor_user_id,
    NULL,
    NULL
  );
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_public_activities_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_user_id uuid;
  v_kind_key       text;
BEGIN
  -- Only act on INSERT of non-deleted activities that have a target
  IF TG_OP <> 'INSERT' THEN RETURN NEW; END IF;
  IF NEW.is_deleted THEN RETURN NEW; END IF;
  IF NEW.target_profile_id IS NULL THEN RETURN NEW; END IF;

  -- Skip self-actions
  IF NEW.target_profile_id = NEW.actor_profile_id THEN RETURN NEW; END IF;

  -- Only handle types NOT already covered by per-domain notification triggers
  -- (comment → trg_post_comment_notify, reaction → trg_post_reaction_notify,
  --  follow → trg_profile_follow_notify, badge → trg_badge_awarded_notify)
  IF NEW.activity_type NOT IN ('game_join', 'meetup_join') THEN
    RETURN NEW;
  END IF;

  -- Resolve target profile → user_id
  SELECT user_id INTO v_target_user_id
  FROM public.profiles WHERE id = NEW.target_profile_id;

  IF v_target_user_id IS NULL THEN RETURN NEW; END IF;
  IF v_target_user_id = NEW.actor_user_id THEN RETURN NEW; END IF;

  v_kind_key := CASE NEW.activity_type
    WHEN 'game_join'   THEN 'game.player_joined'
    WHEN 'meetup_join' THEN 'meetup.player_joined'
    ELSE NULL
  END;

  IF v_kind_key IS NULL THEN RETURN NEW; END IF;

  PERFORM public.process_notification_event(
    v_target_user_id,
    v_kind_key,
    NEW.activity_type,
    NEW.id,
    NEW.actor_user_id
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_badge_awarded_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.process_notification_event(
        NEW.user_id,
        'reward.badge_awarded',
        'badge',
        NEW.badge_id,
        NEW.user_id
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_booking_payment_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.process_notification_event(
        NEW.user_id,
        'arena.payment_required',
        'booking',
        NEW.id,
        NEW.user_id
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_circle_join_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_circle_owner uuid;
BEGIN

    SELECT p.user_id
    INTO v_circle_owner
    FROM public.circles c
    JOIN public.profiles p ON p.id = c.owner_profile_id
    WHERE c.id = NEW.circle_id;

    IF v_circle_owner IS NULL THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_circle_owner,
        'social.circle_joined',
        'circle',
        NEW.circle_id,
        (
            SELECT user_id
            FROM public.profiles
            WHERE id = NEW.member_profile_id
        )
    );

    RETURN NEW;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_comment_like_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_comment_author_uid uuid;
  v_comment_body       text;
BEGIN
  SELECT pc.author_user_id, left(pc.body, 200) INTO v_comment_author_uid, v_comment_body
    FROM public.comments pc WHERE pc.id = NEW.comment_id;
  IF v_comment_author_uid IS NULL OR v_comment_author_uid = NEW.user_id THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(
    v_comment_author_uid, 'social.comment_liked', 'comment',
    NEW.comment_id, NEW.user_id, NULL, v_comment_body);
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_comment_mention_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_mentioned_uid      uuid;
  v_comment_author_uid uuid;
  v_comment_body       text;
BEGIN
  SELECT user_id INTO v_mentioned_uid FROM public.profiles WHERE id = NEW.mentioned_profile_id;
  SELECT pc.author_user_id, left(pc.body, 200) INTO v_comment_author_uid, v_comment_body
    FROM public.comments pc WHERE pc.id = NEW.comment_id;
  IF v_mentioned_uid IS NULL OR v_comment_author_uid IS NULL
     OR v_mentioned_uid = v_comment_author_uid THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(
    v_mentioned_uid, 'social.mentioned_in_comment', 'comment',
    NEW.comment_id, v_comment_author_uid, NULL, v_comment_body);
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_friend_request_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF NEW.from_user = NEW.to_user THEN
        RETURN NEW;
    END IF;

    IF NEW.action = 'requested' THEN
        PERFORM public.process_notification_event(
            NEW.to_user,
            'friend.requested',
            'friend_request',
            NEW.id,
            NEW.from_user
        );
    ELSIF NEW.action = 'accepted' THEN
        PERFORM public.process_notification_event(
            NEW.from_user,
            'friend.accepted',
            'friend_request',
            NEW.id,
            NEW.to_user
        );
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_game_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_inviter_uid uuid;
BEGIN
    SELECT user_id INTO v_inviter_uid
    FROM public.profiles
    WHERE id = NEW.invited_by_profile_id;

    IF v_inviter_uid IS NULL OR v_inviter_uid = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'game.invited',
        'game',
        NEW.game_id,
        v_inviter_uid
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_game_join_request_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid;
BEGIN
  SELECT creator_user_id INTO v_host_uid FROM public.games WHERE id = NEW.game_id;
  IF v_host_uid IS NULL OR v_host_uid = NEW.from_user_id THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(v_host_uid, 'game.join_request', 'game', NEW.game_id, NEW.from_user_id);
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_game_updated_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_player RECORD;
BEGIN
  IF OLD.is_cancelled = false AND NEW.is_cancelled = true THEN
    FOR v_player IN
      SELECT user_id FROM public.game_roster WHERE game_id = NEW.id AND user_id <> NEW.creator_user_id
    LOOP
      PERFORM public.process_notification_event(v_player.user_id, 'game.updated', 'game', NEW.id, NEW.creator_user_id);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_game_waitlist_promoted_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid; v_in_roster boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM public.game_roster WHERE game_id = OLD.game_id AND user_id = OLD.user_id) INTO v_in_roster;
  IF NOT v_in_roster THEN RETURN OLD; END IF;
  SELECT creator_user_id INTO v_host_uid FROM public.games WHERE id = OLD.game_id;
  PERFORM public.process_notification_event(OLD.user_id, 'game.waitlist_promoted', 'game', OLD.game_id, COALESCE(v_host_uid, OLD.user_id));
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_meetup_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF NEW.created_by = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'meetup.invited',
        'meetup',
        NEW.meetup_id,
        NEW.created_by
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_post_comment_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_post_author uuid;
BEGIN
    SELECT author_user_id INTO v_post_author
    FROM public.posts WHERE id = NEW.parent_activity_id;

    IF v_post_author IS NULL OR v_post_author = NEW.author_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_commented',
        'post',
        NEW.parent_activity_id,
        NEW.author_user_id,
        NULL,
        left(NEW.body, 200)
    );
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_post_like_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_post_owner uuid;
BEGIN

    -- Get post author
    SELECT author_user_id
    INTO v_post_owner
    FROM public.posts
    WHERE id = NEW.post_id;

    -- Do not notify self-like
    IF v_post_owner IS NULL OR v_post_owner = NEW.user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_post_owner,
        'social.post_liked',
        'post',
        NEW.post_id,
        NEW.user_id
    );

    RETURN NEW;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_post_like_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_post_author uuid;
BEGIN
    -- Get post author user_id (returns NULL if parent is a news article, not a post)
    SELECT author_user_id
    INTO v_post_author
    FROM public.posts
    WHERE id = NEW.parent_activity_id;

    -- Do not notify self, and skip if parent is not a post
    IF v_post_author IS NULL OR v_post_author = NEW.user_id THEN
        RETURN NEW;
    END IF;

    -- Route into notification engine
    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_liked',
        'post',
        NEW.parent_activity_id,
        NEW.user_id
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_post_mention_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_mentioned_uid uuid;
    v_post_author_uid uuid;
    v_post_body text;
BEGIN
    SELECT user_id INTO v_mentioned_uid
    FROM public.profiles
    WHERE id = NEW.mentioned_profile_id;

    SELECT p.author_user_id, left(p.body, 200)
    INTO v_post_author_uid, v_post_body
    FROM public.posts p
    WHERE p.id = NEW.post_id;

    IF v_mentioned_uid IS NULL
       OR v_post_author_uid IS NULL
       OR v_mentioned_uid = v_post_author_uid THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_mentioned_uid,
        'social.mentioned_in_post',
        'post',
        NEW.post_id,
        v_post_author_uid,
        NULL,
        v_post_body
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_post_reaction_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_post_author uuid;
BEGIN
    SELECT author_user_id INTO v_post_author
    FROM public.posts WHERE id = NEW.parent_activity_id;

    IF v_post_author IS NULL OR v_post_author = NEW.actor_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_reacted',
        'post',
        NEW.parent_activity_id,
        NEW.actor_user_id
    );
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_profile_follow_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_followed_user uuid;
    v_follower_user uuid;
BEGIN

    -- Get followed user_id
    SELECT user_id
    INTO v_followed_user
    FROM public.profiles
    WHERE id = NEW.following_profile_id;

    -- Get follower user_id
    SELECT user_id
    INTO v_follower_user
    FROM public.profiles
    WHERE id = NEW.follower_profile_id;

    -- Prevent self notification
    IF v_followed_user IS NULL OR v_followed_user = v_follower_user THEN
        RETURN NEW;
    END IF;

    -- Route to AI engine
    PERFORM public.process_notification_event(
        v_followed_user,
        'social.followed',
        'profile',
        NEW.following_profile_id,
        v_follower_user
    );

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_squad_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_inviter_uid uuid;
BEGIN
    SELECT user_id INTO v_inviter_uid
    FROM public.profiles
    WHERE id = NEW.created_by_profile_id;

    IF v_inviter_uid IS NULL OR v_inviter_uid = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'squad.invited',
        'squad',
        NEW.squad_id,
        v_inviter_uid
    );

    RETURN NEW;
END;
$function$
;


-- Triggers
-- ---------------------------------------------------------------------

CREATE TRIGGER tr_likes_notify AFTER INSERT ON public.likes FOR EACH ROW EXECUTE FUNCTION fn_likes_notify();

CREATE TRIGGER tr_public_activities_notify AFTER INSERT ON public.public_activities FOR EACH ROW EXECUTE FUNCTION fn_public_activities_notify();

CREATE TRIGGER trg_badge_awarded_notify AFTER INSERT ON public.user_badges FOR EACH ROW EXECUTE FUNCTION trg_badge_awarded_notify();

CREATE TRIGGER trg_circle_join_notify AFTER INSERT ON public.circle_members FOR EACH ROW EXECUTE FUNCTION trg_circle_join_notify();

CREATE TRIGGER trg_comment_mention_notify AFTER INSERT ON public.comment_mentions FOR EACH ROW EXECUTE FUNCTION trg_comment_mention_notify();

CREATE TRIGGER trg_friend_request_notify AFTER INSERT ON public.friend_requests_audit FOR EACH ROW EXECUTE FUNCTION trg_friend_request_notify();

CREATE TRIGGER trg_game_invite_notify AFTER INSERT ON public.game_invites FOR EACH ROW EXECUTE FUNCTION trg_game_invite_notify();

CREATE TRIGGER trg_game_join_request_notify AFTER INSERT ON public.game_join_requests FOR EACH ROW EXECUTE FUNCTION trg_game_join_request_notify();

CREATE TRIGGER trg_game_updated_notify AFTER UPDATE ON public.games FOR EACH ROW WHEN ((old.is_cancelled IS DISTINCT FROM new.is_cancelled)) EXECUTE FUNCTION trg_game_updated_notify();

CREATE TRIGGER trg_game_waitlist_promoted_notify AFTER DELETE ON public.game_waitlist FOR EACH ROW EXECUTE FUNCTION trg_game_waitlist_promoted_notify();

CREATE TRIGGER trg_meetup_invite_notify AFTER INSERT ON public.meetup_invites FOR EACH ROW EXECUTE FUNCTION trg_meetup_invite_notify();

CREATE TRIGGER trg_post_comment_notify AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION trg_post_comment_notify();

CREATE TRIGGER trg_post_mention_notify AFTER INSERT ON public.post_mentions FOR EACH ROW EXECUTE FUNCTION trg_post_mention_notify();

CREATE TRIGGER trg_post_reaction_notify AFTER INSERT ON public.reactions FOR EACH ROW EXECUTE FUNCTION trg_post_reaction_notify();

CREATE TRIGGER trg_profile_follow_notify AFTER INSERT ON public.profile_follows FOR EACH ROW EXECUTE FUNCTION trg_profile_follow_notify();

CREATE TRIGGER trg_squad_invite_notify AFTER INSERT ON public.squad_invites FOR EACH ROW EXECUTE FUNCTION trg_squad_invite_notify();
