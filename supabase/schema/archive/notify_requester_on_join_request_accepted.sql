-- Applied to live DB on 2026-07-12 (migration: notify_requester_on_join_request_accepted).
--
-- Bug: a player whose game join request was approved received NO notification.
-- rpc_decide_join_request updated game_join_requests + game_roster, and the
-- roster sync only notifies the HOST (game.player_joined). The requester side
-- had no path at all.
--
-- Fix:
-- 1) New push-capable kind 'game.join_accepted' (inapp+push).
-- 2) rpc_decide_join_request now calls process_notification_event for the
--    requester on approval — "You're in!..." when joined, a waitlist variant
--    when the game is full. entity_type 'game' + game_id makes
--    process_notification_event attach the /sports/games/<id> deep link.
--    Notification failures are caught (RAISE WARNING) so they can never roll
--    back the approval.
-- Denials intentionally send nothing (product decision pending).

INSERT INTO public.notification_kinds (key, label_en, label_ar, default_priority, default_channels, route_template, is_active)
VALUES ('game.join_accepted', 'Join request accepted', 'تم قبول طلب الانضمام', 'normal', '{inapp,push}'::notify_channel[], '/game/{game_id}', true)
ON CONFLICT (key) DO NOTHING;

-- (full function body as applied; only the two PERFORM process_notification_event
--  blocks are new relative to the previous version)
CREATE OR REPLACE FUNCTION public.rpc_decide_join_request(p_request_id uuid, p_approve boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req   record;
  slots int;
BEGIN
  SELECT jr.*, g.creator_user_id
  INTO req
  FROM public.game_join_requests jr
  JOIN public.games g ON g.id = jr.game_id
  WHERE jr.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='request_not_found';
  END IF;

  IF req.creator_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  IF req.status <> 'pending' THEN RETURN 'already_decided'; END IF;

  IF p_approve THEN
    slots := public.game_slots_left(req.game_id);

    UPDATE public.game_join_requests
       SET status = 'approved', decided_at = now()
     WHERE id = p_request_id;

    IF slots > 0 THEN
      INSERT INTO public.game_roster(game_id, profile_id, role, status)
      VALUES (req.game_id, req.from_profile_id, 'player', 'active')
      ON CONFLICT (game_id, profile_id) DO UPDATE
        SET status = 'active', left_at = null;

      -- Notify the requester (entity_type 'game' also yields the
      -- /sports/games/<id> deep link). Never let notification failure
      -- roll back the approval itself.
      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'You''re in! Your request to join was accepted'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted notification failed: %', SQLERRM;
      END;

      RETURN 'approved_joined';
    ELSE
      INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
      SELECT req.game_id, req.from_profile_id, req.from_user_id,
             COALESCE((SELECT MAX(position)+1 FROM public.game_waitlist WHERE game_id = req.game_id), 1)
      ON CONFLICT DO NOTHING;

      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'Request approved — the game is full, you''re on the waitlist'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted (waitlist) notification failed: %', SQLERRM;
      END;

      RETURN 'approved_waitlisted';
    END IF;
  ELSE
    UPDATE public.game_join_requests
       SET status = 'denied', decided_at = now()
     WHERE id = p_request_id;
    RETURN 'denied';
  END IF;
END;
$function$;
