-- KAN-1017: a game invite sent no notification. rpc_invite_user stored invited_by_profile_id only from an
-- 'organiser' profile (NULL for a host without one), and trg_game_invite_notify returned early on a NULL inviter and
-- still used process_notification_event.
--   * rpc_invite_user: invited_by_profile_id = the caller's profile (organiser profile, else the game's creator profile
--     when the caller created it, else the caller's oldest active profile).
--   * trg_game_invite_notify: game.invited through notify_v2 only (via kan982_notify, which adds title_en / title_ar
--     from kan981_event_title), actor = the inviter (profile's user, else the caller), dedupe game.invited:<invite id>.
--     The old process_notification_event call is gone, so the kind has one sender.
--   * game.invited titles name the game: "{actor} invited you to {title}" / "{actor} دعاك إلى {title}".
-- Backfill: none. The only pending invite is the QA device-test invite, which is left untouched on purpose.
-- CREATE OR REPLACE / UPDATE only. No DROP, no DELETE.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_invite_user(uuid,uuid)'::regprocedure)) <> '42943fab515d64c84878931af206ca42' THEN
    RAISE EXCEPTION 'KAN-1017 guard: rpc_invite_user changed since it was read';
  END IF;
  IF md5(pg_get_functiondef('public.trg_game_invite_notify()'::regprocedure)) <> '5cd96cea520ae770fcf5353ae84ed882' THEN
    RAISE EXCEPTION 'KAN-1017 guard: trg_game_invite_notify changed since it was read';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.notification_kinds WHERE key = 'game.invited' AND is_active
                  AND title_template_en = '{actor} invited you to a game'
                  AND title_template_ar = '{actor} دعاك إلى مباراة') THEN
    RAISE EXCEPTION 'KAN-1017 guard: game.invited templates changed';
  END IF;
  IF to_regprocedure('public.kan982_notify(uuid,text,jsonb,text,uuid,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-1017 guard: kan982_notify missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules WHERE kind_key = 'game.invited' AND enabled) THEN
    RAISE EXCEPTION 'KAN-1017 guard: game.invited has an aggregation rule';
  END IF;
END
$guard$;

UPDATE public.notification_kinds
   SET title_template_en = '{actor} invited you to {title}',
       title_template_ar = '{actor} دعاك إلى {title}'
 WHERE key = 'game.invited';

-- rpc_invite_user (from the live definition): record the caller's profile as the inviter.
CREATE OR REPLACE FUNCTION public.rpc_invite_user(p_game_id uuid, p_to_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE gid uuid;
BEGIN
  -- KAN-798: host from events.
  IF NOT EXISTS (
    SELECT 1 FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    WHERE g.id = p_game_id
      AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  INSERT INTO public.game_invites(game_id, to_user_id, invited_by_profile_id, status)
  VALUES (
    p_game_id,
    p_to_user_id,
    -- KAN-1017: always the caller's profile (was the organiser profile only, so NULL for most hosts).
    COALESCE(
      (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND profile_type = 'organiser' LIMIT 1),
      (SELECT e.creator_profile_id FROM public.games g
         JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
        WHERE g.id = p_game_id AND e.creator_user_id = auth.uid()),
      (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND is_active = true ORDER BY created_at LIMIT 1)),
    'pending'
  )
  RETURNING id INTO gid;

  RETURN gid;
END$function$;

-- trg_game_invite_notify (from the live definition): notify_v2 only, never silent on a NULL inviter.
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
    -- KAN-1017: an invite without a recorded profile is still from the caller.
    v_inviter_uid := COALESCE(v_inviter_uid, auth.uid());

    IF v_inviter_uid IS NOT DISTINCT FROM NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.kan982_notify(
        NEW.to_user_id, 'game.invited', '{}'::jsonb, 'game', NEW.game_id, v_inviter_uid,
        'game.invited:' || NEW.id);

    RETURN NEW;
END;
$function$;
