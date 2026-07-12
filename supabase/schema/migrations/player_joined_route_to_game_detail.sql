-- Applied to live DB on 2026-07-12 (migration: player_joined_route_to_game_detail).
--
-- game.player_joined notifications had no deep link: fn_public_activities_notify
-- passed the ACTIVITY row id with entity_type 'game_join', so
-- process_notification_event's route builder (requires entity_type = 'game')
-- never produced an action_route, and the stored entity_id wasn't the game id.
-- For roster activities parent_activity_id IS the game/meetup id (shared UUID,
-- see fn_game_roster_activity_sync / fn_meetup_rsvps_activity_sync).
--
-- Change: fn_public_activities_notify now passes
--   entity_type := 'game' | 'meetup'
--   entity_id   := COALESCE(NEW.parent_activity_id, NEW.id)
-- so game.player_joined notifications get action_route
-- '/sports/games/<game_id>' (the app's real game-detail route) and correct
-- context. Full function body below.

CREATE OR REPLACE FUNCTION public.fn_public_activities_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_user_id uuid;
  v_kind_key       text;
  v_entity_type    text;
  v_entity_id      uuid;
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

  -- parent_activity_id is the game/meetup id for roster activities; passing
  -- entity_type 'game' lets process_notification_event build the
  -- /sports/games/<id> deep link.
  v_entity_type := CASE NEW.activity_type
    WHEN 'game_join'   THEN 'game'
    WHEN 'meetup_join' THEN 'meetup'
  END;
  v_entity_id := COALESCE(NEW.parent_activity_id, NEW.id);

  PERFORM public.process_notification_event(
    v_target_user_id,
    v_kind_key,
    v_entity_type,
    v_entity_id,
    NEW.actor_user_id
  );

  RETURN NEW;
END;
$function$;

-- Backfill: give existing game.player_joined notifications the game-detail
-- route and correct entity context (old context stored the activity id).
UPDATE public.notifications n
SET action_route = '/sports/games/' || pa.parent_activity_id::text,
    context = n.context || jsonb_build_object(
      'entity_type', 'game',
      'entity_id',   pa.parent_activity_id,
      'game_id',     pa.parent_activity_id,
      'activity_id', pa.id)
FROM public.public_activities pa
WHERE n.kind_key = 'game.player_joined'
  AND n.action_route IS NULL
  AND (n.context->>'entity_id') IS NOT NULL
  AND pa.id = (n.context->>'entity_id')::uuid
  AND pa.parent_activity_id IS NOT NULL;

-- Same context correction for meetup.player_joined (no meetup detail route yet).
UPDATE public.notifications n
SET context = n.context || jsonb_build_object(
      'entity_type', 'meetup',
      'entity_id',   pa.parent_activity_id,
      'meetup_id',   pa.parent_activity_id,
      'activity_id', pa.id)
FROM public.public_activities pa
WHERE n.kind_key = 'meetup.player_joined'
  AND (n.context->>'entity_type') = 'meetup_join'
  AND pa.id = (n.context->>'entity_id')::uuid
  AND pa.parent_activity_id IS NOT NULL;
