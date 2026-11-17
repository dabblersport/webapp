-- KAN-975 follow-up: category_prefs keys follow notification_kinds.category (KAN-974, applied in parallel).
--
-- 20261117045159 keyed category_prefs by the design's labels (social, messages, games, meetups,
-- rewards_announcements, booking). KAN-974 then landed notification_kinds.category with the check
-- notification_kinds_category_chk: social, messages, games, meetups, activities, system, security, booking.
-- New key set (coordinator ruling 2026-11-17): social, messages, games, meetups, system, booking.
--   rewards_announcements -> system  (system holds reward.badge_awarded and system.announcement; the UI labels it
--                                     "Rewards & announcements"). The row's flags move unchanged.
--   security  has no key: security notices are always on and cannot be switched off.
--   booking   key stays; hidden from the UI.
--   activities has NO key of its own. RULE for delivery (KAN-979): an activity kind (category = 'activities':
--             check-in, lifecycle, results, ratings) follows the games pref when its entity is a game and the
--             meetups pref when its entity is a meetup. notification_channel_enabled(user, kind, channel) has no
--             entity argument, so for an activities kind it applies only push_enabled and muted_kinds; the caller
--             that knows the entity must also check category_prefs -> 'games' | 'meetups' -> channel.
-- Steps: pre-image guard (validator md5, every row still has rewards_announcements) -> replace the validator ->
-- rename the key in every row -> new column default -> post asserts.

DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.notification_category_prefs_valid(jsonb)'::regprocedure))
       <> 'ac02792cb402d57eb607cee183440cce' THEN
    RAISE EXCEPTION 'KAN-975b pre-image guard failed: notification_category_prefs_valid changed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_settings WHERE NOT category_prefs ? 'rewards_announcements') THEN
    RAISE EXCEPTION 'KAN-975b pre-image guard failed: a row already lacks rewards_announcements';
  END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.notification_category_prefs_valid(p jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Exactly the switchable notification_kinds.category values, each {"in_app": bool, "push": bool}.
  -- No "security" key (always on). No "activities" key: activity kinds follow games or meetups by entity.
  SELECT p IS NOT NULL
     AND jsonb_typeof(p) = 'object'
     AND p ?& ARRAY['social', 'messages', 'games', 'meetups', 'system', 'booking']
     AND (SELECT count(*) FROM jsonb_object_keys(p)) = 6
     AND (SELECT bool_and(CASE WHEN jsonb_typeof(v) = 'object' THEN
                   v ?& ARRAY['in_app', 'push'] AND (SELECT count(*) FROM jsonb_object_keys(v)) = 2
               AND jsonb_typeof(v -> 'in_app') = 'boolean'
               AND jsonb_typeof(v -> 'push') = 'boolean'
                 ELSE false END)
            FROM jsonb_each(p) e(k, v));
$function$;

UPDATE public.notification_settings
   SET category_prefs = (category_prefs - 'rewards_announcements')
                        || jsonb_build_object('system', category_prefs -> 'rewards_announcements');

ALTER TABLE public.notification_settings ALTER COLUMN category_prefs SET DEFAULT
      '{"social":   {"in_app": true, "push": true},
        "messages": {"in_app": true, "push": true},
        "games":    {"in_app": true, "push": true},
        "meetups":  {"in_app": true, "push": true},
        "system":   {"in_app": true, "push": true},
        "booking":  {"in_app": true, "push": true}}'::jsonb;

COMMENT ON COLUMN public.notification_settings.category_prefs IS
  'KAN-975: per-category {"in_app","push"} flags keyed by notification_kinds.category: social, messages, games, meetups, system ("Rewards & announcements"), booking (hidden in UI). No security key (always on). No activities key: an activities kind follows games when its entity is a game, meetups when it is a meetup (applied by delivery, KAN-979).';

DO $post$
DECLARE v_bad text := ''; v_ok boolean;
BEGIN
  IF EXISTS (SELECT 1 FROM public.notification_settings
              WHERE NOT public.notification_category_prefs_valid(category_prefs)) THEN
    v_bad := v_bad || ' invalid-row';
  END IF;
  EXECUTE 'SELECT public.notification_category_prefs_valid(' ||
          (SELECT pg_get_expr(d.adbin, d.adrelid) FROM pg_attrdef d
             JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
            WHERE d.adrelid = 'public.notification_settings'::regclass AND a.attname = 'category_prefs') || ')'
     INTO v_ok;
  IF v_ok IS NOT TRUE THEN
    v_bad := v_bad || ' default-invalid';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds k
              WHERE k.category IS NOT NULL AND k.category NOT IN ('security', 'activities')
                AND k.category NOT IN ('social', 'messages', 'games', 'meetups', 'system', 'booking')) THEN
    v_bad := v_bad || ' registry-category-without-key';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-975b post assert failed:%', v_bad;
  END IF;
END
$post$;
