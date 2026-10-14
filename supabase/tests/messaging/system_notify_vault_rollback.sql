-- KAN-539 rollback.   AUTHORED, NOT RUN.
--
-- Itself an apply, done only by the operations process with approval. It restores the KAN-510 body
-- of public.msg_system_notify (the two app.msg_* settings), which on the hosted project cannot be
-- set, so after it the function does nothing. Last resort. Nothing is removed.
-- Source: supabase/migrations/20261013160000_kan510_msg_system_lines.sql.

BEGIN;

CREATE OR REPLACE FUNCTION public.msg_system_notify(p_event text, p_game_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_url     text := nullif(current_setting('app.msg_worker_url', true), '');
  v_secret  text := nullif(current_setting('app.msg_hmac_secret', true), '');
  v_conv    uuid;
  v_body    jsonb;
  v_sig     text;
BEGIN
  IF v_url IS NULL OR v_secret IS NULL THEN
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

COMMIT;
