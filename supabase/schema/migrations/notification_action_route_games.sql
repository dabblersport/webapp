-- Set action_route on game notifications.
--
-- Notification rows were inserted without action_route (the templates table
-- render_notification expects doesn't exist), so push taps navigated
-- nowhere and in-app taps fell back to client kind_key mapping — which
-- pointed at /games/:id, a route that doesn't exist. The real detail route
-- is /sports/games/:gameId.
--
-- process_notification_event now stamps game.* notifications with the real
-- route; game.join_request additionally gets ?focus=requests so the detail
-- screen auto-scrolls to the pending-requests card for the host.
-- (game.* kinds have no aggregation rules, so the instant-insert path is
-- the only one that matters here.)

create or replace function public.process_notification_event(
  p_to_user_id uuid,
  p_kind_key text,
  p_entity_type text,
  p_entity_id uuid,
  p_actor_user_id uuid,
  p_title text default null::text,
  p_body text default null::text
) returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
DECLARE
    v_rule RECORD;
    v_existing RECORD;
    v_last_event timestamptz;
    v_new_actors uuid[];
    v_display_name text;
    v_final_title text;
    v_action_route text;
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

    -- Deep-link route for game notifications (real detail route; the host's
    -- join-request notification lands on the pending-requests card).
    v_action_route := CASE
        WHEN p_entity_type = 'game' AND p_kind_key LIKE 'game.%' THEN
            '/sports/games/' || p_entity_id::text ||
            CASE WHEN p_kind_key = 'game.join_request'
                 THEN '?focus=requests' ELSE '' END
        ELSE NULL
    END;

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
            action_route,
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
            v_action_route,
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
$function$;
