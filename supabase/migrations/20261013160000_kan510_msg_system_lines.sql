-- KAN-510 (Messaging T15): system lines for roster changes and game cancellation.
-- AUTHORED. Apply is the operations process's step (needs-ops), never this branch's.
--
-- WHAT IT DOES. Three triggers (two on public.game_roster, one on public.games) call
-- public.msg_system_notify, which POSTs a small signed JSON event to the messaging Worker.
-- The Worker verifies the signature and stores the system line. Nothing here stores text.
--   joined    : a roster row is inserted as 'active', or its status changes to 'active'
--   left      : a roster row's status changes to 'left'
--   removed   : a roster row's status changes to 'kicked'
--   cancelled : games.is_cancelled turns true
-- Nothing else fires. In particular there is NO "game finished" line: no trigger can fire on
-- the passage of time, and no scheduled job is created here. The client renders "game
-- finished" itself from the game's end time (that is carried by T16).
--
-- SECRETS ARE NOT IN THIS FILE. Two database settings are read at call time and are named
-- here only (their values are supplied by operations, never committed):
--   app.msg_worker_url   full URL of the Worker's signed internal endpoint
--   app.msg_hmac_secret  the shared signing key; the Worker reads the same key from its
--                        binding MSG_SYSTEM_HMAC_SECRET
-- If either setting is empty the function does nothing (the roster change is never blocked).
-- Any failure inside it is swallowed with a WARNING that carries no payload, so a join, a
-- leave, a removal or a cancellation can never fail because the chat Worker is unreachable.
--
-- SIGNATURE. Header X-Msg-Signature: 'sha256=' || lower-hex HMAC-SHA256 of the exact request
-- body text, keyed by app.msg_hmac_secret. The body is the jsonb text, which is what pg_net
-- sends for a jsonb body; operations confirm that on first apply (see the probe pack).
--
-- IDEMPOTENCY. Every event carries event_id (a fresh uuid per trigger firing). The Worker keys
-- the stored line on it, so the same event delivered twice stores one line.
--
-- PRIVACY. The event carries the conversation id, the event kind and (roster events only) the
-- member's user id: nothing a member cannot already see on the roster. No name, no text.
--
-- No existing trigger, function or table is edited. No DROP. Needs the pg_net and pgcrypto
-- extensions, which Supabase installs in the extensions schema.

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

CREATE OR REPLACE FUNCTION public.msg_system_roster_trg()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  PERFORM public.msg_system_notify(
    CASE NEW.status WHEN 'active' THEN 'joined' WHEN 'left' THEN 'left' ELSE 'removed' END,
    NEW.game_id,
    NEW.user_id
  );
  RETURN NULL;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.msg_system_game_trg()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  PERFORM public.msg_system_notify('cancelled', NEW.id, NULL);
  RETURN NULL;
END;
$fn$;

REVOKE ALL ON FUNCTION public.msg_system_notify(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_system_roster_trg() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_system_game_trg() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER msg_system_roster_insert
  AFTER INSERT ON public.game_roster
  FOR EACH ROW WHEN (NEW.status = 'active')
  EXECUTE FUNCTION public.msg_system_roster_trg();

CREATE TRIGGER msg_system_roster_status
  AFTER UPDATE OF status ON public.game_roster
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('active', 'left', 'kicked'))
  EXECUTE FUNCTION public.msg_system_roster_trg();

CREATE TRIGGER msg_system_game_cancelled
  AFTER UPDATE OF is_cancelled ON public.games
  FOR EACH ROW WHEN (OLD.is_cancelled IS NOT TRUE AND NEW.is_cancelled IS TRUE)
  EXECUTE FUNCTION public.msg_system_game_trg();
