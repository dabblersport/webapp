-- Wire up the previously-dormant auth.welcome notification for new users.
--
-- auth.welcome existed in notification_kinds but nothing emitted it (one stray
-- historical row). This adds a dedicated AFTER INSERT trigger on profiles that
-- fires the welcome once per user:
--   * dedup on any prior auth.welcome (a user may have up to 2 profiles, and we
--     never re-welcome) — note profiles.id is the profile PK and profiles.user_id
--     is the auth user, so the notification targets NEW.user_id;
--   * SECURITY DEFINER to bypass the notifications n_block_insert lockdown;
--   * wrapped in an exception handler so a welcome failure can never roll back
--     user/profile creation.
-- Push is also enabled on the kind (note: a brand-new user often has no FCM
-- token yet, so the first welcome typically lands in-app only).

-- 1. Enable push on the auth.welcome kind (default_channels is notify_channel[]).
UPDATE public.notification_kinds
SET default_channels = (
  SELECT array(
    SELECT DISTINCT e
    FROM unnest(default_channels || ARRAY['push']::public.notify_channel[]) AS e
  )
)
WHERE key = 'auth.welcome';

-- 2. Emit the welcome once per user on profile creation.
CREATE OR REPLACE FUNCTION public.trg_welcome_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE to_user_id = NEW.user_id AND kind_key = 'auth.welcome'
  ) THEN
    BEGIN
      INSERT INTO public.notifications (
        to_user_id, kind_key, title, body, action_route, context, created_at
      )
      VALUES (
        NEW.user_id,
        'auth.welcome',
        'Welcome to Dabbler! 🎉',
        'Find games, join events, and connect with players near you.',
        '/home',
        '{}'::jsonb,
        now()
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'trg_welcome_notify failed for user %: %', NEW.user_id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_welcome_notify ON public.profiles;
CREATE TRIGGER trg_welcome_notify
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.trg_welcome_notify();
