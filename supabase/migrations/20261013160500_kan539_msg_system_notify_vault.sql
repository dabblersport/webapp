-- KAN-539 (Messaging staging T-G): msg_system_notify reads its signing secret from Supabase Vault
-- and its Worker URL from a constant.   AUTHORED, NOT APPLIED. Apply is the operations process's
-- step after review, in order after 20261013160000_kan510_msg_system_lines.sql.
--
-- WHY. KAN-510's function read two database settings (app.msg_worker_url, app.msg_hmac_secret).
-- Supabase refuses to set a custom database setting for the postgres role (42501 permission
-- denied), so those settings can never exist on the hosted project and the function would
-- always do nothing.
--
-- WHAT CHANGES. Only the body of public.msg_system_notify(text, uuid, uuid):
--   * the URL is the constant below (the staging Worker's internal endpoint, not a secret);
--   * the signing secret is read inside the function, by name, from vault.decrypted_secrets
--     (secret name msg_hmac_secret); it holds the same value as the Worker secret
--     MSG_SYSTEM_HMAC_SECRET. The value is never written in any file.
-- Everything else is as in KAN-510: SECURITY DEFINER, empty search_path (every name is schema
-- qualified), the same event body and signature, the same quiet failure. If the secret is
-- missing the function does nothing (the roster change is never blocked). Any other failure is
-- swallowed with a WARNING that carries no payload and no secret.
--
-- GRANTS. CREATE OR REPLACE keeps the owner and the existing grants; the REVOKE below repeats
-- the KAN-510 revoke so the result does not depend on them. The two trigger functions and the
-- three triggers are not touched. Nothing is removed.
--
-- When the Worker moves (production), replace the constant in a new migration.

CREATE OR REPLACE FUNCTION public.msg_system_notify(p_event text, p_game_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_url     constant text := 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line';
  v_secret  text;
  v_conv    uuid;
  v_body    jsonb;
  v_sig     text;
BEGIN
  SELECT s.decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets s
   WHERE s.name = 'msg_hmac_secret'
   LIMIT 1;
  IF v_secret IS NULL OR v_secret = '' THEN
    RETURN;
  END IF;

  SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id;
  IF v_conv IS NULL THEN
    RETURN; -- no chat exists for this game yet: nothing to say
  END IF;

  v_body := jsonb_strip_nulls(jsonb_build_object(
    'event_id', gen_random_uuid(),
    'conversation_id', v_conv,
    'event', p_event,
    'user_id', p_user_id
  ));
  v_sig := encode(extensions.hmac(convert_to(v_body::text, 'utf8'), convert_to(v_secret, 'utf8'), 'sha256'), 'hex');

  PERFORM net.http_post(
    url := v_url,
    body := v_body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'X-Msg-Signature', 'sha256=' || v_sig)
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_system_notify failed (sqlstate %)', SQLSTATE;
END;
$fn$;

REVOKE ALL ON FUNCTION public.msg_system_notify(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
