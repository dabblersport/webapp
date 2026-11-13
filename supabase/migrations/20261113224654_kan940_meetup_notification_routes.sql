-- KAN-940: meetup notifications carry action_route, and a re-join sends the same kind as a first join.
-- Every meetup notification is written by public.process_notification_event (no meetup kind has an aggregation rule,
-- so each one is the instant insert). Writers: trg_meetup_rsvps_notify, fn_public_activities_notify (meetup_join),
-- rpc_meetup_cancel_kan712_inner, trg_meetup_invite_notify.
--   1. process_notification_event: entity_type 'meetup' + kind 'meetup.%' -> '/meetups/<id>'; the host kinds the app
--      opens on Manage (lib/features/notifications/meetup_notification_routes.dart meetupHostKinds:
--      meetup.request_received, meetup.rsvp_received) -> '/meetups/<id>/manage', as game.join_request adds
--      '?focus=requests'. Game and every other kind are unchanged.
--   2. trg_meetup_rsvps_notify: an attendee flipping themselves back to 'going' sends meetup.player_joined (the kind a
--      first join sends through the meetup_join activity) instead of meetup.rsvp_received, with the same title.
-- Both bodies re-authored from pg_get_functiondef on the live catalogue. CREATE OR REPLACE keeps owner and ACL.

DO $pre$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure)
     <> '1b14f5666734be00236e5abd4aa13dd4' THEN
    RAISE EXCEPTION 'KAN-940: process_notification_event is not the pinned pre-image';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trg_meetup_rsvps_notify()'::regprocedure)
     <> '65d510509ef232d9d436054d318ec5a3' THEN
    RAISE EXCEPTION 'KAN-940: trg_meetup_rsvps_notify is not the pinned pre-image';
  END IF;
END
$pre$;

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
            WHEN 'game.player_joined'          THEN v_display_name || ' joined your game'
            WHEN 'game.updated'                THEN 'A game you joined was updated'
            WHEN 'game.waitlist_promoted'      THEN 'You''ve been promoted from the waitlist'
            WHEN 'meetup.invited'              THEN v_display_name || ' invited you to a meetup'
            WHEN 'meetup.player_joined'        THEN v_display_name || ' joined your meet-up'
            WHEN 'squad.invited'               THEN v_display_name || ' invited you to a squad'
            WHEN 'arena.payment_required'      THEN 'Payment required for your booking'
            WHEN 'reward.badge_awarded'        THEN 'You earned a new badge!'
            ELSE NULL
        END;

        -- Unknown/future kinds: fall back to the catalog label, never a
        -- generic "New notification".
        IF v_final_title IS NULL THEN
            SELECT label_en INTO v_final_title
            FROM public.notification_kinds
            WHERE key = p_kind_key;
            v_final_title := COALESCE(v_final_title, 'Notification');
        END IF;
    END IF;

    -- Deep-link route for game notifications (real detail route; the host's
    -- join-request notification lands on the pending-requests card).
    -- KAN-940: meetup notifications open the meetup; the host kinds open Manage
    -- (matches meetupHostKinds in lib/features/notifications/meetup_notification_routes.dart).
    v_action_route := CASE
        WHEN p_entity_type = 'game' AND p_kind_key LIKE 'game.%' THEN
            '/sports/games/' || p_entity_id::text ||
            CASE WHEN p_kind_key = 'game.join_request'
                 THEN '?focus=requests' ELSE '' END
        WHEN p_entity_type = 'meetup' AND p_kind_key LIKE 'meetup.%' AND p_entity_id IS NOT NULL THEN
            '/meetups/' || p_entity_id::text ||
            CASE WHEN p_kind_key IN ('meetup.request_received', 'meetup.rsvp_received')
                 THEN '/manage' ELSE '' END
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

CREATE OR REPLACE FUNCTION public.trg_meetup_rsvps_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_host_uid   uuid;
  v_title      text;
  v_name       text;
  v_old        text;
BEGIN
  -- OLD is unassigned on INSERT, so read it once, guarded.
  IF TG_OP = 'UPDATE' THEN v_old := OLD.status; END IF;

  -- Only status changes (and brand-new rows) are events.
  IF TG_OP = 'UPDATE' AND v_old IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT e.creator_user_id, e.title INTO v_host_uid, v_title
    FROM public.kan714_meetups_read m
    JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731: shared columns from events
   WHERE m.id = NEW.meetup_id;
  IF v_host_uid IS NULL THEN RETURN NEW; END IF;

  SELECT p.display_name INTO v_name
    FROM public.profiles p
   WHERE p.user_id = NEW.user_id AND p.is_active = true
   LIMIT 1;
  v_name := COALESCE(v_name, 'Someone');

  -- Someone asks to join (request policy): tell the host. Never the host's own row.
  IF NEW.status = 'pending'
     AND v_old IS DISTINCT FROM 'pending'
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.request_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' asked to join your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Attendee flips to 'going' themselves (UPDATE only: a fresh INSERT is covered
  -- by the existing meetup.player_joined chain; see header).
  -- KAN-940: same kind and title as that first-join notification.
  IF TG_OP = 'UPDATE' AND NEW.status = 'going'
     AND v_actor IS NOT NULL AND v_actor = NEW.user_id
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.player_joined', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' joined your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Somebody else (the host or an admin) decides a pending request: tell the attendee.
  IF TG_OP = 'UPDATE' AND v_old = 'pending'
     AND v_actor IS NOT NULL AND v_actor <> NEW.user_id
  THEN
    IF NEW.status = 'going' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'You''re in! Your request to join was approved', v_title);
    ELSIF NEW.status = 'interested' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'Your request was approved, but the meet-up is full', v_title);
    ELSIF NEW.status IN ('cancelled', 'declined') THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_declined', 'meetup', NEW.meetup_id, v_actor,
        'Your request to join was declined', v_title);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DO $post$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text fn, p.proacl::text acl, p.prosecdef, p.proconfig::text cfg, pg_get_userbyid(p.proowner) own
             FROM pg_proc p
            WHERE p.oid IN ('public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure,
                            'public.trg_meetup_rsvps_notify()'::regprocedure)
  LOOP
    IF r.acl <> '{postgres=X/postgres,service_role=X/postgres}' OR NOT r.prosecdef
       OR r.cfg <> '{"search_path=public, pg_temp"}' OR r.own <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-940 post-assert failed: % acl=% secdef=% cfg=% owner=%', r.fn, r.acl, r.prosecdef, r.cfg, r.own;
    END IF;
  END LOOP;
END
$post$;
