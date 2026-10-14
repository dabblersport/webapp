-- KAN-542 (Realtime R2): msg_system_notify also sends a seq-less Realtime wake-up to the
-- POST-change roster when a system line (joined, left, removed, cancelled) is queued.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step after review, in order after
-- 20261013160600_kan541_msg_notify.sql.
--
-- WHY. System lines have no user token, so the client-side msg_notify (KAN-541) cannot wake the
-- other members. The trigger function itself calls realtime.send in the same transaction as the
-- roster change, so a member's open chat refreshes when someone joins, leaves, is removed or the
-- game is cancelled.
--
-- WHAT CHANGES. Only the body of public.msg_system_notify(text, uuid, uuid). Everything from
-- KAN-539 is unchanged (constant staging URL, Vault read by name, signature, event body,
-- SECURITY DEFINER, empty search_path with every name schema qualified, quiet failure, revoked
-- grants). ADDED: after the net.http_post enqueue, and so only when the system line itself was
-- queued, a loop over the CURRENT active roster of the game (status active; role host, player or
-- sub: the same query as msg_notify) calls
--     realtime.send(payload, 'msg', 'user:' || <member id>, true)
-- The last argument is the private flag and is ALWAYS true (policy msg_user_topic_receive,
-- KAN-505, lets a user receive only on their own topic).
--
-- PAYLOAD. Exactly jsonb {"type":"sync","conversation_id":<uuid>}: no seq (the trigger does not
-- know it), no text, no event type, no member list. Never logged. The platform adds an `id` key
-- to the stored message itself; that is expected.
--
-- WHO IS WOKEN. The roster AFTER the change: a member who left or was removed is not on it and
-- gets no wake (CEO ruling); a cancellation wakes every active member.
--
-- QUIET FAILURE. The wake loop has its own exception block (plus one per recipient) that emits a
-- WARNING carrying only the sqlstate, so a failing wake never fails the roster change and never
-- undoes the queued system line. With the Vault secret missing the function returns before
-- anything, as in KAN-539.
--
-- GRANTS. The REVOKE below repeats KAN-539. Triggers are not touched. Nothing is removed.
-- Rollback: supabase/tests/messaging/system_wake_rollback.sql.

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
  v_payload jsonb;
  v_to      uuid;
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

  -- KAN-542: the system line is queued, so wake the POST-change roster (seq-less).
  BEGIN
    v_payload := jsonb_build_object('type', 'sync', 'conversation_id', v_conv);
    FOR v_to IN
      SELECT DISTINCT r.user_id
        FROM public.game_roster r
       WHERE r.game_id = p_game_id
         AND r.status = 'active'
         AND r.role IN ('host', 'player', 'sub')
    LOOP
      BEGIN
        PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'msg_system_notify wake failed (sqlstate %)', SQLSTATE;
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'msg_system_notify wake failed (sqlstate %)', SQLSTATE;
  END;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_system_notify failed (sqlstate %)', SQLSTATE;
END;
$fn$;

REVOKE ALL ON FUNCTION public.msg_system_notify(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
