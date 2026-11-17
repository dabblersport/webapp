-- KAN-975 [W0-2] Settings contract (Epic KAN-973; plan Dabbler/dabbler-docs/briefs/NOTIFICATIONS_PLAN_2026-11-16.md).
--
-- One store for every notification preference: public.notification_settings.
--
-- Decisions implemented (NOTIFICATIONS_DESIGN_REVIEW_2026-11-16.md sections F and I, plan "CEO answers from planning"):
--   F-14  quiet hours set by the user, default 00:00-08:00     -> quiet_start_min 0 / quiet_end_min 480 defaults
--   F-4   control per reminder rung                            -> reminder_rungs jsonb, each rung on/off
--   I-5   Interested gets the full ladder 24h, 09:00, 2h, 30m  -> reminder_rungs.interested has the same four rungs
--   F-2   message preview, two options, sender+message default -> message_preview
--   F-15  remove email from settings                           -> email_enabled / sms_enabled kept, read by no function,
--                                                                 not writable through the new RPC
--   CEO   security notices always on, cannot be muted          -> guard trigger rejects a security kind in muted_kinds;
--                                                                 category_prefs has no security key;
--                                                                 notification_channel_enabled() returns true for them
--   Assumption "Turn off notifications like this" mutes the kind -> muted_kinds (unchanged column)
--
-- Shape of the window (why off = both NULL and not a separate flag): the live push trigger
-- trg_push_on_notification_insert (not owned here) already reads quiet_start_min / quiet_end_min and treats NULL as
-- "no quiet hours". A separate on/off column would be ignored by that trigger, so a user who switched quiet hours off
-- would still be treated as quiet. quiet_hours_enabled is therefore a generated column (start and end both set).
-- Switching quiet hours on with no window gives the 00:00-08:00 default.
--
-- Readers repointed from user_settings to notification_settings:
--   is_quiet_hour(uuid,timestamptz)  user_settings.timezone/quiet_start/quiet_end -> notification_settings.tz/quiet_*_min
--                                    now SECURITY DEFINER (reads the true row whatever the caller's RLS); EXECUTE only
--                                    postgres and service_role (anon/authenticated/PUBLIC revoked: it takes any user id).
--   schedule_game_reminders_for_user user_settings.timezone/quiet_end -> notification_settings.tz/quiet_end_min
--                                    (dead today: it writes notification_jobs, which does not exist; W2 replaces it).
--   is_in_quiet_hours(uuid)          read notification_settings in UTC; now delegates to is_quiet_hour.
-- A user with no row reads as the defaults everywhere (tz Asia/Dubai, quiet 00:00-08:00).
-- render_notification still reads user_settings.locale: locale is not a notification setting; left alone.
--
-- New functions:
--   rpc_get_my_notification_settings()             creates the caller's row with defaults on first read, returns it
--   rpc_update_my_notification_settings(jsonb)     partial update; reminder_rungs and category_prefs merge per key
--   rpc_set_my_notification_timezone(text)         device timezone (IANA name, validated)
--   notification_kind_is_unmutable(text)           true for security kinds
--   notification_channel_enabled(uuid,text,text)   delivery reader: may this kind reach this user on in_app / push
--   notification_reminder_rungs_valid(jsonb), notification_category_prefs_valid(jsonb)  CHECK validators
--   notification_settings_guard()                  BEFORE INSERT/UPDATE trigger: tz valid, no unmutable muted kind
--
-- The existing client (lib/features/notifications/data/notification_settings_repository_impl.dart) reads and upserts
-- the table directly under RLS; every column it sends still exists with the same meaning, so it keeps working. It does
-- not send the new columns, so they keep their defaults on its upsert.
--
-- Not touched (other Wave 0 tickets): notifications, notification_kinds (KAN-974), trg_push_on_notification_insert,
-- events (KAN-976), fcm_tokens (KAN-977). Category keys match notification_kinds.category values KAN-974 defines:
-- social, messages, games, meetups, rewards_announcements, booking (booking hidden in the UI).
--
-- Live test: supabase/tests/notifications_v2/kan975_settings_contract.sql.

-- 1. pre-image guard --------------------------------------------------------------------------------------------------
DO $pre$
DECLARE
  v_bad text := '';
BEGIN
  IF md5(pg_get_functiondef('public.is_quiet_hour(uuid,timestamptz)'::regprocedure))
       <> '6b4196ad668c3d64ce8d1ae1aa698169' THEN v_bad := v_bad || ' is_quiet_hour'; END IF;
  IF md5(pg_get_functiondef('public.schedule_game_reminders_for_user(uuid,uuid,timestamptz,jsonb)'::regprocedure))
       <> '73a4c12f91acf4c7170e2633660ff340' THEN v_bad := v_bad || ' schedule_game_reminders_for_user'; END IF;
  IF md5(pg_get_functiondef('public.is_in_quiet_hours(uuid)'::regprocedure))
       <> '811cee83705096f8dc131042b7180a8c' THEN v_bad := v_bad || ' is_in_quiet_hours(uuid)'; END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'notification_settings'
                AND column_name IN ('message_preview', 'reminder_rungs', 'category_prefs', 'quiet_hours_enabled')) THEN
    v_bad := v_bad || ' new-columns-already-present';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                AND proname IN ('rpc_get_my_notification_settings', 'rpc_update_my_notification_settings',
                                'rpc_set_my_notification_timezone', 'notification_kind_is_unmutable',
                                'notification_channel_enabled', 'notification_settings_guard',
                                'notification_reminder_rungs_valid', 'notification_category_prefs_valid')) THEN
    v_bad := v_bad || ' new-function-name-taken';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_settings
              WHERE (quiet_start_min IS NULL) <> (quiet_end_min IS NULL)
                 OR quiet_start_min NOT BETWEEN 0 AND 1439 OR quiet_end_min NOT BETWEEN 0 AND 1439
                 OR quiet_start_min = quiet_end_min) THEN
    v_bad := v_bad || ' existing-row-violates-quiet-checks';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-975 pre-image guard failed:%', v_bad;
  END IF;
END
$pre$;

-- 2. validators (IMMUTABLE, used by CHECK constraints) -----------------------------------------------------------------
CREATE FUNCTION public.notification_reminder_rungs_valid(p jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Exactly {"going": {...}, "interested": {...}}, each with exactly the rungs 24h, 09:00, 2h, 30m, each a boolean.
  SELECT p IS NOT NULL
     AND jsonb_typeof(p) = 'object'
     AND p ?& ARRAY['going', 'interested'] AND (SELECT count(*) FROM jsonb_object_keys(p)) = 2
     AND (SELECT bool_and(CASE WHEN jsonb_typeof(p -> a) = 'object' THEN
                   (p -> a) ?& ARRAY['24h', '09:00', '2h', '30m'] AND (SELECT count(*) FROM jsonb_object_keys(p -> a)) = 4
               AND (SELECT bool_and(jsonb_typeof(v) = 'boolean') FROM jsonb_each(p -> a) e(r, v))
                 ELSE false END)
            FROM unnest(ARRAY['going', 'interested']) a);
$function$;

CREATE FUNCTION public.notification_category_prefs_valid(p jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Exactly the design's categories, each {"in_app": bool, "push": bool}. No "security" key: security notices
  -- cannot be switched off (CEO answer from planning).
  SELECT p IS NOT NULL
     AND jsonb_typeof(p) = 'object'
     AND p ?& ARRAY['social', 'messages', 'games', 'meetups', 'rewards_announcements', 'booking']
     AND (SELECT count(*) FROM jsonb_object_keys(p)) = 6
     AND (SELECT bool_and(CASE WHEN jsonb_typeof(v) = 'object' THEN
                   v ?& ARRAY['in_app', 'push'] AND (SELECT count(*) FROM jsonb_object_keys(v)) = 2
               AND jsonb_typeof(v -> 'in_app') = 'boolean'
               AND jsonb_typeof(v -> 'push') = 'boolean'
                 ELSE false END)
            FROM jsonb_each(p) e(k, v));
$function$;

REVOKE ALL ON FUNCTION public.notification_reminder_rungs_valid(jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.notification_category_prefs_valid(jsonb) FROM PUBLIC, anon;
-- CHECK constraints run the validator as the writing role, so the client role needs EXECUTE (pure functions).
GRANT EXECUTE ON FUNCTION public.notification_reminder_rungs_valid(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.notification_category_prefs_valid(jsonb) TO authenticated, service_role;

-- 3. columns, defaults, checks ----------------------------------------------------------------------------------------
ALTER TABLE public.notification_settings
  ALTER COLUMN quiet_start_min SET DEFAULT 0,
  ALTER COLUMN quiet_end_min   SET DEFAULT 480,
  ADD COLUMN quiet_hours_enabled boolean
      GENERATED ALWAYS AS (quiet_start_min IS NOT NULL AND quiet_end_min IS NOT NULL) STORED,
  ADD COLUMN message_preview text NOT NULL DEFAULT 'sender_and_message',
  ADD COLUMN reminder_rungs jsonb NOT NULL DEFAULT
      '{"going":      {"24h": true, "09:00": true, "2h": true, "30m": true},
        "interested": {"24h": true, "09:00": true, "2h": true, "30m": true}}'::jsonb,
  ADD COLUMN category_prefs jsonb NOT NULL DEFAULT
      '{"social":                {"in_app": true, "push": true},
        "messages":              {"in_app": true, "push": true},
        "games":                 {"in_app": true, "push": true},
        "meetups":               {"in_app": true, "push": true},
        "rewards_announcements": {"in_app": true, "push": true},
        "booking":               {"in_app": true, "push": true}}'::jsonb,
  ADD CONSTRAINT notification_settings_quiet_pair_chk  CHECK ((quiet_start_min IS NULL) = (quiet_end_min IS NULL)),
  ADD CONSTRAINT notification_settings_quiet_range_chk CHECK (quiet_start_min BETWEEN 0 AND 1439
                                                          AND quiet_end_min   BETWEEN 0 AND 1439),
  ADD CONSTRAINT notification_settings_quiet_span_chk  CHECK (quiet_start_min <> quiet_end_min),
  ADD CONSTRAINT notification_settings_message_preview_chk
      CHECK (message_preview IN ('sender_and_message', 'sender_only')),
  ADD CONSTRAINT notification_settings_reminder_rungs_chk CHECK (public.notification_reminder_rungs_valid(reminder_rungs)),
  ADD CONSTRAINT notification_settings_category_prefs_chk CHECK (public.notification_category_prefs_valid(category_prefs));

COMMENT ON COLUMN public.notification_settings.tz IS
  'KAN-975: IANA timezone, set from the device (rpc_set_my_notification_timezone). Validated by notification_settings_guard.';
COMMENT ON COLUMN public.notification_settings.quiet_start_min IS
  'KAN-975: quiet hours start, minutes after local midnight (0-1439). NULL with quiet_end_min = quiet hours off. Default 0 (00:00).';
COMMENT ON COLUMN public.notification_settings.quiet_end_min IS
  'KAN-975: quiet hours end (exclusive), minutes after local midnight. Default 480 (08:00). Must differ from start.';
COMMENT ON COLUMN public.notification_settings.quiet_hours_enabled IS
  'KAN-975: generated, true when a quiet window is set.';
COMMENT ON COLUMN public.notification_settings.message_preview IS
  'KAN-975 (F-2): sender_and_message (default) or sender_only.';
COMMENT ON COLUMN public.notification_settings.reminder_rungs IS
  'KAN-975 (F-4, I-5): {"going"|"interested": {"24h","09:00","2h","30m": bool}}, all true by default.';
COMMENT ON COLUMN public.notification_settings.category_prefs IS
  'KAN-975: per-category {"in_app","push"} flags keyed by notification_kinds.category. No security key: never mutable.';
COMMENT ON COLUMN public.notification_settings.muted_kinds IS
  'notification_kinds.key values the user muted. A security kind is rejected (notification_settings_guard).';
COMMENT ON COLUMN public.notification_settings.email_enabled IS
  'KAN-975 (F-15): legacy, read by no function. Kept, not dropped.';
COMMENT ON COLUMN public.notification_settings.sms_enabled IS
  'KAN-975 (F-15): legacy, read by no function. Kept, not dropped.';

-- anon never owns a row; RLS already returns nothing, the grant was only surface.
REVOKE ALL ON TABLE public.notification_settings FROM anon;

-- 4. unmutable kinds and the guard trigger ----------------------------------------------------------------------------
CREATE FUNCTION public.notification_kind_is_unmutable(p_kind text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Security notices can never be muted. A kind is a security kind when its key is in the security.* family, or
  -- when the registry marks it (category = 'security' or can_mute = false). to_jsonb keeps this valid whether or not
  -- KAN-974's category / can_mute columns exist yet.
  SELECT p_kind LIKE 'security.%'
      OR COALESCE((SELECT (to_jsonb(nk) ->> 'category') = 'security'
                       OR (to_jsonb(nk) ->> 'can_mute') = 'false'
                     FROM public.notification_kinds nk
                    WHERE nk.key = p_kind), false);
$function$;

REVOKE ALL ON FUNCTION public.notification_kind_is_unmutable(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notification_kind_is_unmutable(text) TO authenticated, service_role;

CREATE FUNCTION public.notification_settings_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bad text;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.tz IS DISTINCT FROM OLD.tz THEN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = NEW.tz) THEN
      RAISE EXCEPTION 'unknown timezone: %', NEW.tz USING ERRCODE = '22023';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR NEW.muted_kinds IS DISTINCT FROM OLD.muted_kinds THEN
    SELECT string_agg(k, ', ') INTO v_bad
      FROM unnest(COALESCE(NEW.muted_kinds, '{}')) k
     WHERE public.notification_kind_is_unmutable(k);
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'security notices cannot be muted: %', v_bad USING ERRCODE = '22023';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.notification_settings_guard() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_notification_settings_guard
  BEFORE INSERT OR UPDATE ON public.notification_settings
  FOR EACH ROW EXECUTE FUNCTION public.notification_settings_guard();

-- 5. readers repointed ------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_quiet_hour(p_user uuid, p_at timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tz text;
  v_start int;
  v_end int;
  v_local int;
begin
  -- KAN-975: the one store is notification_settings.
  select ns.tz, ns.quiet_start_min, ns.quiet_end_min into v_tz, v_start, v_end
  from public.notification_settings ns where ns.user_id = p_user;

  if not found then
    -- No row yet: the defaults (F-14), same as the column defaults.
    v_tz := 'Asia/Dubai'; v_start := 0; v_end := 480;
  end if;

  if v_start is null or v_end is null or v_start = v_end then
    return false; -- quiet hours off
  end if;

  v_local := extract(hour from (coalesce(p_at, now()) at time zone coalesce(v_tz, 'Asia/Dubai')))::int * 60
           + extract(minute from (coalesce(p_at, now()) at time zone coalesce(v_tz, 'Asia/Dubai')))::int;

  if v_start < v_end then
    return v_local >= v_start and v_local < v_end;    -- same-day window, e.g. 13:00-15:00
  else
    return v_local >= v_start or v_local < v_end;     -- across midnight, e.g. 23:00-07:00
  end if;
end;
$function$;

REVOKE ALL ON FUNCTION public.is_quiet_hour(uuid, timestamp with time zone) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_quiet_hour(uuid, timestamp with time zone) TO service_role;

CREATE OR REPLACE FUNCTION public.is_in_quiet_hours(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- KAN-975: one quiet-hours rule. This used to compare UTC clock minutes with the user's local window.
    RETURN public.is_quiet_hour(p_user_id, now());
END;
$function$;

REVOKE ALL ON FUNCTION public.is_in_quiet_hours(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_in_quiet_hours(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.schedule_game_reminders_for_user(p_user uuid, p_game_id uuid, p_start_at timestamp with time zone, p_payload jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  cnt int := 0;
  t timestamptz;
  due timestamptz;
  offs interval[];
  off interval;
begin
  offs := ARRAY['24 hours'::interval, '2 hours'::interval, '30 minutes'::interval];

  foreach off in array offs loop
    t := p_start_at - off;

    -- If within quiet hours, nudge to end of quiet window (simple heuristic)
    if public.is_quiet_hour(p_user, t) then
      -- compute user local tz from settings (KAN-975: notification_settings; no row = defaults)
      declare tz text := coalesce((select ns.tz from public.notification_settings ns where ns.user_id=p_user),'Asia/Dubai');
              qend time := case
                             when exists (select 1 from public.notification_settings ns where ns.user_id=p_user)
                             then (select (ns.quiet_end_min * interval '1 minute')::time
                                     from public.notification_settings ns where ns.user_id=p_user)
                             else time '08:00'
                           end;
              local_date date := (t at time zone tz)::date;
      begin
        if qend is not null then
          due := (local_date::timestamptz + qend) at time zone tz;
        else
          due := t;
        end if;
      end;
    else
      due := t;
    end if;

    insert into public.notification_jobs(user_id, type_key, payload, due_at)
    values (p_user, 'game.reminder', jsonb_build_object('game_id', p_game_id)::jsonb || p_payload, due)
    on conflict do nothing;
    cnt := cnt + 1;
  end loop;

  return cnt;
end;
$function$;

REVOKE ALL ON FUNCTION public.schedule_game_reminders_for_user(uuid, uuid, timestamp with time zone, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_game_reminders_for_user(uuid, uuid, timestamp with time zone, jsonb)
  TO service_role;

-- 6. delivery reader --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.notification_channel_enabled(p_user uuid, p_kind text, p_channel text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.notification_settings;
  v_category text;
  v_flag jsonb;
BEGIN
  IF p_channel NOT IN ('in_app', 'push') THEN
    RAISE EXCEPTION 'channel must be in_app or push, got %', p_channel USING ERRCODE = '22023';
  END IF;

  -- Security notices: always on, whatever the settings say (CEO answer from planning).
  IF public.notification_kind_is_unmutable(p_kind) THEN
    RETURN true;
  END IF;

  SELECT * INTO r FROM public.notification_settings WHERE user_id = p_user;
  IF NOT FOUND THEN
    RETURN true; -- defaults: every category on, nothing muted, push on
  END IF;

  IF p_channel = 'push' AND NOT COALESCE(r.push_enabled, true) THEN
    RETURN false;
  END IF;

  IF p_kind = ANY (COALESCE(r.muted_kinds, '{}')) THEN
    RETURN false;
  END IF;

  SELECT to_jsonb(nk) ->> 'category' INTO v_category FROM public.notification_kinds nk WHERE nk.key = p_kind;
  v_flag := r.category_prefs -> v_category -> p_channel;
  IF v_flag IS NOT NULL AND jsonb_typeof(v_flag) = 'boolean' THEN
    RETURN v_flag::text::boolean;
  END IF;

  RETURN true; -- kind has no category (yet): only the master switch and mutes apply
END;
$function$;

REVOKE ALL ON FUNCTION public.notification_channel_enabled(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_channel_enabled(uuid, text, text) TO service_role;

-- 7. client RPCs (SECURITY INVOKER: RLS ns_self_* scopes every statement to auth.uid()) -------------------------------
CREATE FUNCTION public.rpc_get_my_notification_settings()
 RETURNS public.notification_settings
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  r public.notification_settings;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  -- A row is created on first read, with the table defaults.
  INSERT INTO public.notification_settings (user_id) VALUES (v_uid) ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO r FROM public.notification_settings WHERE user_id = v_uid;
  RETURN r;
END;
$function$;

CREATE FUNCTION public.rpc_update_my_notification_settings(p_patch jsonb)
 RETURNS public.notification_settings
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  r public.notification_settings;
  v_unknown text;
  v_start int;
  v_end int;
  v_on boolean;
  k text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RAISE EXCEPTION 'patch must be a json object' USING ERRCODE = '22023';
  END IF;

  -- Only these keys. The legacy email and SMS flags are not settable here (F-15).
  SELECT string_agg(key, ', ') INTO v_unknown
    FROM jsonb_object_keys(p_patch) key
   WHERE key NOT IN ('tz', 'quiet_hours_enabled', 'quiet_start_min', 'quiet_end_min', 'message_preview',
                     'reminder_rungs', 'category_prefs', 'muted_kinds', 'push_enabled');
  IF v_unknown IS NOT NULL THEN
    RAISE EXCEPTION 'unknown setting(s): %', v_unknown USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.notification_settings (user_id) VALUES (v_uid) ON CONFLICT (user_id) DO NOTHING;
  SELECT * INTO r FROM public.notification_settings WHERE user_id = v_uid FOR UPDATE;

  -- Quiet hours: off clears the window; on, or a new start/end, sets it (missing parts from the current
  -- window, else the 00:00-08:00 default). Start equal to end is rejected.
  v_start := r.quiet_start_min;
  v_end := r.quiet_end_min;
  IF p_patch ? 'quiet_hours_enabled' THEN
    v_on := (p_patch ->> 'quiet_hours_enabled')::boolean;
  ELSIF p_patch ? 'quiet_start_min' OR p_patch ? 'quiet_end_min' THEN
    v_on := true;
  END IF;
  IF v_on IS false THEN
    v_start := NULL;
    v_end := NULL;
  ELSIF v_on IS true THEN
    v_start := COALESCE((p_patch ->> 'quiet_start_min')::int, v_start, 0);
    v_end := COALESCE((p_patch ->> 'quiet_end_min')::int, v_end, 480);
    IF v_start = v_end THEN
      RAISE EXCEPTION 'quiet hours start must differ from end' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_patch ? 'reminder_rungs' THEN
    IF jsonb_typeof(p_patch -> 'reminder_rungs') <> 'object' THEN
      RAISE EXCEPTION 'reminder_rungs must be an object' USING ERRCODE = '22023';
    END IF;
    FOR k IN SELECT jsonb_object_keys(p_patch -> 'reminder_rungs') LOOP
      r.reminder_rungs := jsonb_set(r.reminder_rungs, ARRAY[k],
                                    COALESCE(r.reminder_rungs -> k, '{}'::jsonb) || (p_patch -> 'reminder_rungs' -> k));
    END LOOP;
  END IF;

  IF p_patch ? 'category_prefs' THEN
    IF jsonb_typeof(p_patch -> 'category_prefs') <> 'object' THEN
      RAISE EXCEPTION 'category_prefs must be an object' USING ERRCODE = '22023';
    END IF;
    FOR k IN SELECT jsonb_object_keys(p_patch -> 'category_prefs') LOOP
      r.category_prefs := jsonb_set(r.category_prefs, ARRAY[k],
                                    COALESCE(r.category_prefs -> k, '{}'::jsonb) || (p_patch -> 'category_prefs' -> k));
    END LOOP;
  END IF;

  IF p_patch ? 'muted_kinds' THEN
    IF jsonb_typeof(p_patch -> 'muted_kinds') <> 'array' THEN
      RAISE EXCEPTION 'muted_kinds must be an array' USING ERRCODE = '22023';
    END IF;
    r.muted_kinds := ARRAY(SELECT DISTINCT x FROM jsonb_array_elements_text(p_patch -> 'muted_kinds') x ORDER BY x);
  END IF;

  UPDATE public.notification_settings SET
    tz              = COALESCE(p_patch ->> 'tz', r.tz),
    quiet_start_min = v_start,
    quiet_end_min   = v_end,
    message_preview = COALESCE(p_patch ->> 'message_preview', r.message_preview),
    reminder_rungs  = r.reminder_rungs,
    category_prefs  = r.category_prefs,
    muted_kinds     = r.muted_kinds,
    push_enabled    = COALESCE((p_patch ->> 'push_enabled')::boolean, r.push_enabled)
  WHERE user_id = v_uid
  RETURNING * INTO r;

  RETURN r;
END;
$function$;

CREATE FUNCTION public.rpc_set_my_notification_timezone(p_tz text)
 RETURNS public.notification_settings
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM public.rpc_update_my_notification_settings(jsonb_build_object('tz', p_tz));
$function$;

REVOKE ALL ON FUNCTION public.rpc_get_my_notification_settings() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_update_my_notification_settings(jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_set_my_notification_timezone(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_my_notification_settings() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_update_my_notification_settings(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_set_my_notification_timezone(text) TO authenticated, service_role;

-- 8. post asserts -----------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  v_bad text := '';
  f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.is_quiet_hour(uuid,timestamptz)', 'public.is_in_quiet_hours(uuid)',
                           'public.schedule_game_reminders_for_user(uuid,uuid,timestamptz,jsonb)',
                           'public.notification_channel_enabled(uuid,text,text)',
                           'public.notification_settings_guard()'] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') OR has_function_privilege('authenticated', f, 'EXECUTE') THEN
      v_bad := v_bad || ' client-can-execute:' || f;
    END IF;
  END LOOP;
  FOREACH f IN ARRAY ARRAY['public.rpc_get_my_notification_settings()', 'public.rpc_update_my_notification_settings(jsonb)',
                           'public.rpc_set_my_notification_timezone(text)'] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') OR NOT has_function_privilege('authenticated', f, 'EXECUTE') THEN
      v_bad := v_bad || ' rpc-acl:' || f;
    END IF;
  END LOOP;
  IF has_table_privilege('anon', 'public.notification_settings', 'SELECT') THEN
    v_bad := v_bad || ' anon-select-table';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p')
                AND pg_get_functiondef(p.oid) ~* 'user_settings'
                AND pg_get_functiondef(p.oid) ~* '(quiet_start|quiet_end|timezone)') THEN
    v_bad := v_bad || ' a-function-still-reads-user_settings-quiet-or-timezone';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p')
                AND pg_get_functiondef(p.oid) ~* '(email_enabled|sms_enabled)') THEN
    v_bad := v_bad || ' a-function-reads-email-or-sms';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-975 post assert failed:%', v_bad;
  END IF;
END
$post$;
