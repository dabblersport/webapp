-- KAN-436 -- push payload carries meetup_id (CTO ruling, option b).
--
-- AUTHORED, NOT APPLIED. File only: nothing here has been run against any database.
--
-- The push data map is { kind_key, action_route, entity_id } and entity_id is the
-- NOTIFICATION row id, so a push tap with an empty action_route cannot know which
-- meetup it is for. This adds meetup_id to the map for meetup notifications only
-- (notifications.context.entity_type = 'meetup' with a non-empty entity_id). Every
-- other row keeps the exact previous map; entity_id is unchanged. The function body
-- is the live definition (baseline 20260829080500, ~18204-18320) verbatim except for
-- that one data expression. No edge-function change and no client change: the client
-- already reads data.meetup_id (meetupPushRoute).
-- Preserved: SECURITY DEFINER, SET search_path TO 'public','pg_temp', owner postgres,
-- the trigger itself, and the service_role grant (CREATE OR REPLACE keeps all of them).

BEGIN;

-- Remember process_notification_event's ACL so the post-condition can prove it is unchanged.
SELECT set_config('kan436.pne_acl',
  COALESCE((SELECT proacl::text FROM pg_proc
            WHERE oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure), ''),
  true);

CREATE OR REPLACE FUNCTION "public"."trg_push_on_notification_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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

  -- Per-user preference enforcement. The in-app notification row is left
  -- untouched (this trigger only gates the push); we just decide whether to
  -- fire the HTTP call.
  SELECT * INTO _settings
  FROM public.notification_settings
  WHERE user_id = NEW.to_user_id;
  _has_settings := FOUND;

  IF _has_settings THEN
    -- Hard off: user disabled push entirely.
    IF NOT COALESCE(_settings.push_enabled, true) THEN
      RETURN NEW;
    END IF;

    -- Kind muted by the user.
    IF NEW.kind_key = ANY(COALESCE(_settings.muted_kinds, '{}')) THEN
      RETURN NEW;
    END IF;

    -- Quiet hours (minutes-since-midnight in the user's tz, wraps midnight).
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
        -- allow_all_override sends everything; allow_high_priority_override
        -- sends only high/urgent. Otherwise suppress during quiet hours.
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
      ) || CASE
        WHEN NEW.context->>'entity_type' = 'meetup'
         AND NULLIF(NEW.context->>'entity_id', '') IS NOT NULL
        THEN jsonb_build_object('meetup_id', NEW.context->>'entity_id')
        ELSE '{}'::jsonb
      END
    ),
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-trigger-secret', _trigger_secret
    )
  );

  RETURN NEW;
END;
$$;

DO $$
DECLARE
  _p pg_proc%ROWTYPE;
BEGIN
  SELECT * INTO _p FROM pg_proc
  WHERE oid = 'public.trg_push_on_notification_insert()'::regprocedure;
  IF NOT _p.prosecdef THEN
    RAISE EXCEPTION 'KAN-436: trg_push_on_notification_insert lost SECURITY DEFINER';
  END IF;
  IF NOT ('search_path=public, pg_temp' = ANY(COALESCE(_p.proconfig, '{}'))) THEN
    RAISE EXCEPTION 'KAN-436: trg_push_on_notification_insert lost its pinned search_path';
  END IF;
  IF pg_get_functiondef(_p.oid) NOT LIKE '%meetup_id%' THEN
    RAISE EXCEPTION 'KAN-436: meetup_id is not in the push data map';
  END IF;
  IF COALESCE((SELECT proacl::text FROM pg_proc
               WHERE oid = 'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure), '')
     IS DISTINCT FROM current_setting('kan436.pne_acl') THEN
    RAISE EXCEPTION 'KAN-436: process_notification_event ACL changed';
  END IF;
  -- KAN-182: authenticated must still not execute process_notification_event.
  IF has_function_privilege('authenticated',
       'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure,
       'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-436: authenticated can execute process_notification_event';
  END IF;
END
$$;

COMMIT;
