-- Fix server-triggered push delivery (was failing with HTTP 401).
--
-- trg_push_on_notification_insert posted to the send-push-notification edge
-- function with `Authorization: Bearer <anon_key>`. The function then called
-- callerClient.auth.getUser(), which returns null for a non-user token, so
-- every trigger-driven push (likes, comments, invites, follows, ...) was
-- rejected with 401 before reaching FCM. Only direct NotificationSender calls
-- (real user JWT) got through.
--
-- Fix: the trigger now sends a random shared secret in the x-trigger-secret
-- header. The edge function recognises it (via the service_role-only RPC
-- get_push_trigger_secret) and takes a trusted-server path that skips the
-- per-user auth + block checks — the notification row already targeted the
-- correct recipient. The anon-key bearer is retained only to satisfy the
-- platform's verify_jwt gate.
--
-- Secret provisioning is automatic: push_trigger_secret is generated into the
-- vault below if absent; nothing needs to be added by hand.

-- 1. Random shared secret in the vault (idempotent).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'push_trigger_secret') THEN
    PERFORM vault.create_secret(
      replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
      'push_trigger_secret',
      'Shared secret authenticating trg_push_on_notification_insert to the send-push-notification edge function'
    );
  END IF;
END $$;

-- 2. Expose the secret to the edge function (runs as service_role) only.
CREATE OR REPLACE FUNCTION public.get_push_trigger_secret()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_push_trigger_secret() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_push_trigger_secret() TO service_role;

-- 3. Trigger sends the shared secret in x-trigger-secret.
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
BEGIN
  SELECT default_channels INTO _channels
  FROM public.notification_kinds
  WHERE key = NEW.kind_key;

  IF _channels IS NULL OR NOT ('push' = ANY(_channels)) THEN
    RETURN NEW;
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
