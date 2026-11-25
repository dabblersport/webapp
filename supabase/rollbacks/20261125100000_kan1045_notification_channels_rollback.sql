-- KAN-1045 rollback: restores notification_push_dispatch exactly as it was live before 20261125100000
-- (pg_get_functiondef, 2026-11-25) and drops the channel objects. Edge function: redeploy
-- supabase/functions/send-push-notification from commit 5ef5f6e (live version 18 before this change).
BEGIN;
CREATE OR REPLACE FUNCTION public.notification_push_dispatch(p_notification_id uuid, p_repush boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  n public.notifications%ROWTYPE;
  _kind public.notification_kinds%ROWTYPE;
  _anon_key text;
  _trigger_secret text;
  _entity_type text;
  _entity_id text;
  _breaks boolean;
  _quiet boolean;
  _collapse text;
  _badge int;
  _body text;
  _snippet text;
BEGIN
  SELECT * INTO n FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  _entity_type := NULLIF(n.context->>'entity_type', '');
  _entity_id := NULLIF(n.context->>'entity_id', '');
  _body := COALESCE(n.body, '');

  -- KAN-984: the snippet hook is consumed first, before any gate, so it can never carry over to another row.
  IF NOT p_repush THEN
    _snippet := NULLIF(current_setting('dabbler.push_body', true), '');
    IF _snippet IS NOT NULL THEN
      PERFORM set_config('dabbler.push_body', '', true);
    END IF;
  END IF;

  -- Only proceed for kinds whose default channels include push.
  SELECT * INTO _kind FROM public.notification_kinds WHERE key = n.kind_key;
  IF NOT FOUND OR _kind.default_channels IS NULL OR NOT ('push' = ANY(_kind.default_channels)) THEN
    RETURN false;
  END IF;

  -- Per-user push gate: master switch, muted kinds, category flags (activities follow games / meetups by entity).
  -- Security kinds are always on. The in-app row is never touched here.
  IF NOT public.notification_push_enabled(n.to_user_id, n.kind_key, _entity_type) THEN
    RETURN false;
  END IF;

  IF p_repush THEN
    -- KAN-980 growth re-push: replaces the group's push, no sound, never time-sensitive.
    _breaks := false;
    _quiet := true;
  ELSE
    -- KAN-979, I-2 / I-3: quiet hours deliver silently; breaks_quiet and security kinds alert and are time-sensitive.
    _breaks := COALESCE(_kind.breaks_quiet, false) OR public.notification_kind_is_unmutable(n.kind_key);
    _quiet := NOT _breaks AND public.is_quiet_hour(n.to_user_id, now());
  END IF;

  _collapse := CASE WHEN n.group_key IS NULL THEN NULL
                    WHEN octet_length(n.group_key) <= 64 THEN n.group_key
                    ELSE md5(n.group_key) END;

  SELECT count(*)::int INTO _badge FROM public.notifications x WHERE x.to_user_id = n.to_user_id AND NOT x.is_read;

  -- KAN-984 hook: the message snippet travels in the push only, for a messages kind; it is never stored.
  IF _kind.category = 'messages' AND _snippet IS NOT NULL THEN
    _body := _snippet;
  END IF;

  SELECT decrypted_secret INTO _anon_key FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key' LIMIT 1;
  IF _anon_key IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: supabase_anon_key not found in vault';
    RETURN false;
  END IF;
  SELECT decrypted_secret INTO _trigger_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
  IF _trigger_secret IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: push_trigger_secret not found in vault';
    RETURN false;
  END IF;

  PERFORM net.http_post(
    url    := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-push-notification',
    body   := jsonb_build_object(
      'user_id',         n.to_user_id,
      'notification_id', n.id,
      'title',           COALESCE(n.title, ''),
      'body',            _body,
      'data',            jsonb_build_object(
        'kind_key',        n.kind_key,
        'action_route',    COALESCE(n.action_route, ''),
        'entity_type',     COALESCE(_entity_type, ''),
        'entity_id',       COALESCE(_entity_id, ''),
        'notification_id', n.id::text,
        'dedupe_key',      COALESCE(n.dedupe_key, ''),
        'group_key',       COALESCE(n.group_key, ''),
        'repush',          CASE WHEN p_repush THEN 'true' ELSE 'false' END
      ) || CASE
        WHEN _entity_type = 'meetup' AND _entity_id IS NOT NULL
        THEN jsonb_build_object('meetup_id', _entity_id)   -- kept for meetupPushRoute in current builds
        ELSE '{}'::jsonb
      END
      -- KAN-984: the chat a message belongs to, so the app can skip the alert for the open chat (KAN-992)
      || jsonb_strip_nulls(jsonb_build_object(
           'conversation_id', n.args->>'conversation_id',
           'game_id',         n.args->>'game_id',
           'meetup_id',       n.args->>'meetup_id')),
      'delivery',        jsonb_build_object(
        'mode',               CASE WHEN _quiet THEN 'silent' ELSE 'alert' END,
        'time_sensitive',     _breaks,
        'android_channel_id', CASE WHEN _quiet THEN 'dabbler_quiet' ELSE 'dabbler_' || COALESCE(_kind.category, 'default') END,
        'ios_category',       public.notification_push_category(n.kind_key),
        'thread_id',          n.group_key,
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
  RETURN true;
END;
$function$;
DROP FUNCTION IF EXISTS public.rpc_list_notification_channels();
DROP FUNCTION IF EXISTS public.rpc_set_notification_channel_muted(text, boolean);
DROP FUNCTION IF EXISTS public.rpc_set_notification_group_muted(text, boolean);
DROP FUNCTION IF EXISTS public.notification_channel_muted(uuid, text);
DROP TABLE IF EXISTS public.notification_channel_mutes;
ALTER TABLE public.notification_kinds DROP COLUMN IF EXISTS channel_key;
DROP TABLE IF EXISTS public.notification_channels;
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261125100000';
COMMIT;
