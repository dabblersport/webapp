-- KAN-979 [W1-B1] Delivery (Epic KAN-973).
--
-- * trg_push_on_notification_insert (rebuilt from the live definition, md5 b11a6cbff6d04a165ade85be37ce85fb):
--   - quiet hours no longer DROP the push (I-2): it goes out silent (Android dabbler_quiet channel, low priority, no
--     sound; iOS interruption-level passive, no sound; web silent);
--   - breaks_quiet kinds and security kinds alert in quiet hours and are iOS time-sensitive (I-3, CEO security answer);
--   - push gate = notification_push_enabled (notification_channel_enabled + the activities rule, KAN-975 handoff);
--   - payload adds notification_id, the real entity_type / entity_id, dedupe_key, group_key, and a delivery block
--     (mode, time_sensitive, android_channel_id, ios_category, thread_id, collapse_id, badge = unread count);
--   - message snippet hook for KAN-984: a messages-category row's push body is replaced by the transaction-local
--     setting dabbler.push_body when set; the snippet never reaches the notifications row;
--   - the legacy allow_all_override / allow_high_priority_override flags are no longer read (0 rows had either on).
-- * notification_deliveries: one row per device written by send-push-notification v14; new columns token_id,
--   device_platform, delivery_mode, time_sensitive, error_class, attempted_at; status check; the id sequence is
--   locked to service_role (it was rwU for anon/authenticated from the project default ACL, see KAN-976b).
-- * KAN-975 handoff (Jira KAN-979 comment 16415): quiet_start_min / quiet_end_min default 0 / 480 (00:00-08:00, F-14),
--   and is_quiet_hour treats a user with no row as Asia/Dubai 00:00-08:00.

-- 1. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.trg_push_on_notification_insert()'::regprocedure)) <> 'b11a6cbff6d04a165ade85be37ce85fb' THEN
    RAISE EXCEPTION 'kan979 pre-image: trg_push_on_notification_insert changed';
  END IF;
  IF md5(pg_get_functiondef('public.is_quiet_hour(uuid,timestamp with time zone)'::regprocedure)) <> '20b52e9c871ffe0a81d6a727abd08261' THEN
    RAISE EXCEPTION 'kan979 pre-image: is_quiet_hour changed';
  END IF;
  IF md5(pg_get_functiondef('public.notification_channel_enabled(uuid,text,text)'::regprocedure)) <> '476d24f63607b555012c4cfb9f5988a2' THEN
    RAISE EXCEPTION 'kan979 pre-image: notification_channel_enabled changed';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notification_deliveries'
               AND column_name IN ('token_id','device_platform','delivery_mode','time_sensitive','error_class','attempted_at')) THEN
    RAISE EXCEPTION 'kan979 pre-image: a delivery column already exists';
  END IF;
  IF to_regproc('public.notification_push_enabled') IS NOT NULL OR to_regproc('public.notification_push_category') IS NOT NULL THEN
    RAISE EXCEPTION 'kan979 pre-image: a helper already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_deliveries WHERE status <> 'queued') THEN
    RAISE EXCEPTION 'kan979 pre-image: unexpected delivery status values';
  END IF;
END
$guard$;

-- 2. notification_deliveries: one attempt per device -----------------------------------------------------------------
ALTER TABLE public.notification_deliveries
  ADD COLUMN token_id        uuid REFERENCES public.fcm_tokens(id) ON DELETE SET NULL,
  ADD COLUMN device_platform text,
  ADD COLUMN delivery_mode   text,
  ADD COLUMN time_sensitive  boolean,
  ADD COLUMN error_class     text,
  ADD COLUMN attempted_at    timestamptz;

ALTER TABLE public.notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_chk CHECK (status IN ('queued', 'accepted', 'failed')),
  ADD CONSTRAINT notification_deliveries_mode_chk CHECK (delivery_mode IS NULL OR delivery_mode IN ('alert', 'silent')),
  ADD CONSTRAINT notification_deliveries_error_class_chk CHECK (error_class IS NULL OR error_class ~ '^[a-z_]{1,32}$');

CREATE INDEX notification_deliveries_notification_idx ON public.notification_deliveries (notification_id);

COMMENT ON TABLE public.notification_deliveries IS
  'KAN-979: one push attempt per device (fcm_tokens row), written by send-push-notification v14. Never the token, never the text.';
COMMENT ON COLUMN public.notification_deliveries.status IS 'queued (legacy rows) | accepted (FCM took it) | failed.';
COMMENT ON COLUMN public.notification_deliveries.provider_id IS 'FCM message name returned on accept.';
COMMENT ON COLUMN public.notification_deliveries.error IS 'Legacy; not written since KAN-979 (use error_class).';
COMMENT ON COLUMN public.notification_deliveries.error_class IS
  'unregistered | invalid_token | invalid_payload | sender_mismatch | apns_auth | quota | auth | unavailable | unknown.';
COMMENT ON COLUMN public.notification_deliveries.token_id IS 'fcm_tokens.id of the device (SET NULL when the token is pruned).';
COMMENT ON COLUMN public.notification_deliveries.delivery_mode IS 'alert | silent (quiet hours, I-2).';

-- Writes are server-only (RLS nd_block_dml + service_role); the recipient may read their own rows (nd_self_read).
REVOKE ALL ON public.notification_deliveries FROM anon;
REVOKE ALL ON SEQUENCE public.notification_deliveries_id_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.notification_deliveries_id_seq TO service_role;

-- 3. Quiet-hours default 00:00-08:00 (KAN-975 handoff, F-14) ---------------------------------------------------------
ALTER TABLE public.notification_settings
  ALTER COLUMN quiet_start_min SET DEFAULT 0,
  ALTER COLUMN quiet_end_min SET DEFAULT 480;

-- Rebuilt from pg_get_functiondef (md5 20b52e9c871ffe0a81d6a727abd08261); only the no-row branch changes.
CREATE OR REPLACE FUNCTION public.is_quiet_hour(p_user uuid, p_at timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
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
    -- No row yet: same as the column defaults since KAN-979, 00:00-08:00 Asia/Dubai (CEO F-14). Quiet hours deliver
    -- silently (I-2) since the same migration, so this costs nobody a push.
    v_tz := 'Asia/Dubai';
    v_start := 0;
    v_end := 480;
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

-- 4. Push gate with the activities rule ------------------------------------------------------------------------------
-- notification_channel_enabled (KAN-975) has no entity argument; an activities kind follows games for a game and
-- meetups for a meetup (KAN-975 handoff). Security kinds stay always on (channel_enabled returns true for them).
CREATE FUNCTION public.notification_push_enabled(p_user uuid, p_kind text, p_entity_type text)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_category text;
  v_flag jsonb;
BEGIN
  IF NOT public.notification_channel_enabled(p_user, p_kind, 'push') THEN
    RETURN false;
  END IF;
  SELECT nk.category INTO v_category FROM public.notification_kinds nk WHERE nk.key = p_kind;
  IF v_category = 'activities' AND p_entity_type IN ('game', 'meetup') THEN
    SELECT ns.category_prefs -> (CASE p_entity_type WHEN 'game' THEN 'games' ELSE 'meetups' END) -> 'push'
      INTO v_flag FROM public.notification_settings ns WHERE ns.user_id = p_user;
    IF v_flag IS NOT NULL AND jsonb_typeof(v_flag) = 'boolean' THEN
      RETURN v_flag::text::boolean;
    END IF;
  END IF;
  RETURN true;
END;
$function$;

-- 5. iOS category (actions) per kind; the same id travels in data.category for Android actions (KAN-992) -----------
CREATE FUNCTION public.notification_push_category(p_kind text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_kind = 'message.received'           THEN 'DABBLER_MESSAGE'    -- Reply, Mark as read
    WHEN p_kind = 'meetup.confirm_attendance'  THEN 'DABBLER_RSVP'       -- Going, Not going
    WHEN p_kind = 'game.waitlist_promoted'     THEN 'DABBLER_WAITLIST'   -- Cancel my place
    WHEN p_kind LIKE 'security.%'              THEN 'DABBLER_SECURITY'   -- no actions; hidden-preview lock screen
    ELSE 'DABBLER_DEFAULT'                                               -- Mark as read
  END;
$function$;

-- 6. The push trigger function ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_notification_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  _kind public.notification_kinds%ROWTYPE;
  _anon_key text;
  _trigger_secret text;
  _entity_type text := NULLIF(NEW.context->>'entity_type', '');
  _entity_id text := NULLIF(NEW.context->>'entity_id', '');
  _breaks boolean;
  _quiet boolean;
  _collapse text;
  _badge int;
  _body text := COALESCE(NEW.body, '');
  _snippet text;
BEGIN
  -- Only proceed for kinds whose default channels include push.
  SELECT * INTO _kind FROM public.notification_kinds WHERE key = NEW.kind_key;
  IF NOT FOUND OR _kind.default_channels IS NULL OR NOT ('push' = ANY(_kind.default_channels)) THEN
    RETURN NEW;
  END IF;

  -- Per-user push gate: master switch, muted kinds, category flags (activities follow games / meetups by entity).
  -- Security kinds are always on. The in-app row is never touched here.
  IF NOT public.notification_push_enabled(NEW.to_user_id, NEW.kind_key, _entity_type) THEN
    RETURN NEW;
  END IF;

  -- KAN-979, I-2 / I-3: quiet hours deliver silently; breaks_quiet and security kinds alert and are time-sensitive.
  _breaks := COALESCE(_kind.breaks_quiet, false) OR public.notification_kind_is_unmutable(NEW.kind_key);
  _quiet := NOT _breaks AND public.is_quiet_hour(NEW.to_user_id, now());

  _collapse := CASE WHEN NEW.group_key IS NULL THEN NULL
                    WHEN octet_length(NEW.group_key) <= 64 THEN NEW.group_key
                    ELSE md5(NEW.group_key) END;

  SELECT count(*)::int INTO _badge FROM public.notifications n WHERE n.to_user_id = NEW.to_user_id AND NOT n.is_read;

  -- KAN-984 hook: the message snippet travels in the push only. The producer sets it transaction-locally right before
  -- inserting the row; it is consumed once and never stored in notifications.
  IF _kind.category = 'messages' THEN
    _snippet := NULLIF(current_setting('dabbler.push_body', true), '');
    IF _snippet IS NOT NULL THEN
      _body := _snippet;
      PERFORM set_config('dabbler.push_body', '', true);
    END IF;
  END IF;

  SELECT decrypted_secret INTO _anon_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_anon_key'
  LIMIT 1;

  IF _anon_key IS NULL THEN
    RAISE WARNING 'trg_push_on_notification_insert: supabase_anon_key not found in vault';
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO _trigger_secret
  FROM vault.decrypted_secrets
  WHERE name = 'push_trigger_secret'
  LIMIT 1;

  IF _trigger_secret IS NULL THEN
    RAISE WARNING 'trg_push_on_notification_insert: push_trigger_secret not found in vault';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url    := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-push-notification',
    body   := jsonb_build_object(
      'user_id',         NEW.to_user_id,
      'notification_id', NEW.id,
      'title',           COALESCE(NEW.title, ''),
      'body',            _body,
      'data',            jsonb_build_object(
        'kind_key',        NEW.kind_key,
        'action_route',    COALESCE(NEW.action_route, ''),
        'entity_type',     COALESCE(_entity_type, ''),
        'entity_id',       COALESCE(_entity_id, ''),
        'notification_id', NEW.id::text,
        'dedupe_key',      COALESCE(NEW.dedupe_key, ''),
        'group_key',       COALESCE(NEW.group_key, '')
      ) || CASE
        WHEN _entity_type = 'meetup' AND _entity_id IS NOT NULL
        THEN jsonb_build_object('meetup_id', _entity_id)   -- kept for meetupPushRoute in current builds
        ELSE '{}'::jsonb
      END,
      'delivery',        jsonb_build_object(
        'mode',               CASE WHEN _quiet THEN 'silent' ELSE 'alert' END,
        'time_sensitive',     _breaks,
        'android_channel_id', CASE WHEN _quiet THEN 'dabbler_quiet' ELSE 'dabbler_' || COALESCE(_kind.category, 'default') END,
        'ios_category',       public.notification_push_category(NEW.kind_key),
        'thread_id',          NEW.group_key,
        'collapse_id',        _collapse,
        'badge',              _badge
      )
    ),
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-trigger-secret', _trigger_secret
    )
  );

  RETURN NEW;
END;
$function$;

-- 7. Grants: server-side only ----------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text, text) TO service_role;
REVOKE ALL ON FUNCTION public.notification_push_category(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_category(text) TO service_role;

-- 8. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
DECLARE v text;
BEGIN
  SELECT relacl::text INTO v FROM pg_class WHERE oid = 'public.notification_deliveries_id_seq'::regclass;
  IF v LIKE '%anon=%' OR v LIKE '%authenticated=%' OR v LIKE '{=%' OR v LIKE '%,=%' THEN
    RAISE EXCEPTION 'kan979 post-image: delivery sequence still open: %', v;
  END IF;
  IF has_table_privilege('anon', 'public.notification_deliveries', 'SELECT') THEN
    RAISE EXCEPTION 'kan979 post-image: anon can read notification_deliveries';
  END IF;
  FOR v IN SELECT p.oid::regprocedure::text || ' ' || COALESCE(p.proacl::text, 'null') FROM pg_proc p
            WHERE p.oid IN ('public.notification_push_enabled(uuid,text,text)'::regprocedure,
                            'public.notification_push_category(text)'::regprocedure,
                            'public.trg_push_on_notification_insert()'::regprocedure,
                            'public.is_quiet_hour(uuid,timestamp with time zone)'::regprocedure) LOOP
    IF v NOT LIKE '%{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan979 post-image: unexpected proacl %', v;
    END IF;
  END LOOP;
  IF (SELECT column_default FROM information_schema.columns WHERE table_schema = 'public'
        AND table_name = 'notification_settings' AND column_name = 'quiet_start_min') <> '0'
     OR (SELECT column_default FROM information_schema.columns WHERE table_schema = 'public'
        AND table_name = 'notification_settings' AND column_name = 'quiet_end_min') <> '480' THEN
    RAISE EXCEPTION 'kan979 post-image: quiet-hours defaults not 0/480';
  END IF;
END
$post$;
