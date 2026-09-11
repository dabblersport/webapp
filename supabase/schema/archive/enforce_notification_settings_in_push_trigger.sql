-- Honor per-user notification_settings when sending push.
--
-- Builds on fix_push_trigger_edge_auth.sql. The trigger still creates the
-- in-app notification row unconditionally (the feed is never suppressed); this
-- only gates whether the push HTTP call fires, based on the recipient's
-- public.notification_settings:
--   * push_enabled = false        -> never push
--   * kind_key in muted_kinds      -> never push for that kind
--   * inside quiet hours (tz-aware, wraps midnight) -> suppress, unless
--       allow_all_override, or allow_high_priority_override for high/urgent.
-- Users with no settings row keep the previous behaviour (always push).

CREATE OR REPLACE FUNCTION public.trg_push_on_notification_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  _channels text[];
  _anon_key text;
  _trigger_secret text;
  _settings public.notification_settings%ROWTYPE;
  _has_settings boolean := false;
  _tz text;
  _now_min int;
  _in_quiet boolean;
  _is_high boolean;
BEGIN
  -- Only proceed for kinds whose default channels include push.
  SELECT default_channels INTO _channels
  FROM public.notification_kinds
  WHERE key = NEW.kind_key;

  IF _channels IS NULL OR NOT ('push' = ANY(_channels)) THEN
    RETURN NEW;
  END IF;

  -- Per-user preference enforcement (gates the push only, not the in-app row).
  SELECT * INTO _settings
  FROM public.notification_settings
  WHERE user_id = NEW.to_user_id;
  _has_settings := FOUND;

  IF _has_settings THEN
    IF NOT COALESCE(_settings.push_enabled, true) THEN
      RETURN NEW;
    END IF;

    IF NEW.kind_key = ANY(COALESCE(_settings.muted_kinds, '{}')) THEN
      RETURN NEW;
    END IF;

    IF _settings.quiet_start_min IS NOT NULL
       AND _settings.quiet_end_min IS NOT NULL THEN
      _tz := COALESCE(_settings.tz, 'Asia/Dubai');
      _now_min := EXTRACT(hour FROM (now() AT TIME ZONE _tz))::int * 60
                + EXTRACT(minute FROM (now() AT TIME ZONE _tz))::int;

      IF _settings.quiet_start_min <= _settings.quiet_end_min THEN
        _in_quiet := _now_min >= _settings.quiet_start_min
                 AND _now_min <  _settings.quiet_end_min;
      ELSE
        _in_quiet := _now_min >= _settings.quiet_start_min
                  OR _now_min <  _settings.quiet_end_min;
      END IF;

      IF _in_quiet THEN
        _is_high := NEW.priority::text IN ('high', 'urgent');
        IF COALESCE(_settings.allow_all_override, false) THEN
          NULL; -- send
        ELSIF COALESCE(_settings.allow_high_priority_override, false)
              AND _is_high THEN
          NULL; -- send
        ELSE
          RETURN NEW; -- suppress
        END IF;
      END IF;
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
      'user_id', NEW.to_user_id,
      'title',   COALESCE(NEW.title, ''),
      'body',    COALESCE(NEW.body, ''),
      'data',    jsonb_build_object(
        'kind_key',     NEW.kind_key,
        'action_route', COALESCE(NEW.action_route, ''),
        'entity_id',    COALESCE(NEW.id::text, '')
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
