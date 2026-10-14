-- KAN-512 (Messaging T17) 2/2: public.msg_report_message, the report RPC the Worker relays to.
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
-- Requires the KAN-505 functions (msg_evaluate) and 20261013160000_kan512_msg_report_no_snapshot_check.sql.
--
-- What it writes: ONE public.moderation_reports row with target_type 'message', target_id the
-- message id, reason from the EXISTING public.report_reason enum, content_snapshot NULL and
-- details NULL. Identifiers and the reason only; there is no parameter that could carry text.
-- No new reports table. No response-time promise.
--
-- Membership re-check (defence in depth): the Worker calls msg_authorize first with the
-- caller's bearer token, then relays (conversation id, message id, message seq, reason) with
-- the SAME bearer. This function re-evaluates the caller (auth.uid(), never a parameter)
-- with the KAN-505 evaluator msg_evaluate: the caller must currently be allowed to read the
-- conversation, and a member who left may report only a message with seq <= left_at_seq.
-- Non-members, kicked members, non-pilot users and guessed conversation ids are refused
-- with SQLSTATE 42501 (PostgREST 403), message 'not_member'.
-- Limit, stated: message text and the id->(conversation, seq) mapping live in D1, not here,
-- so this function cannot prove the message id belongs to that conversation; the Worker
-- binds them from D1. A direct caller can only file a report as themselves, on a
-- conversation they may read, carrying no content.
--
-- Idempotency: a repeat report by the same reporter on the same message returns the first
-- report's id with created = false and writes no second row. Check-then-insert under a
-- transaction-scoped advisory lock keyed on (reporter, message), so two concurrent repeats
-- serialise. No new unique index: existing moderation_reports rows are not known to be
-- unique on (reporter, target), so an index could fail to build.

CREATE OR REPLACE FUNCTION public.msg_report_message(
  p_conversation_id uuid,
  p_message_id uuid,
  p_message_seq bigint,
  p_reason public.report_reason,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (report_id uuid, created boolean)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_eval record;
  v_id   uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_conversation_id IS NULL OR p_message_id IS NULL OR p_message_seq IS NULL
     OR p_message_seq < 1 OR p_reason IS NULL THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL
     OR v_eval.allowed_action NOT IN ('read', 'send')
     OR (v_eval.reason = 'left' AND p_message_seq > COALESCE(v_eval.left_at_seq, 0)) THEN
    RAISE EXCEPTION 'not_member' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('msg_report:' || v_uid::text || ':' || p_message_id::text, 0));

  SELECT r.id INTO v_id
    FROM public.moderation_reports r
   WHERE r.reporter_user_id = v_uid
     AND r.target_type = 'message'::public.mod_target
     AND r.target_id = p_message_id
   ORDER BY r.created_at
   LIMIT 1;

  IF v_id IS NOT NULL THEN
    RETURN QUERY SELECT v_id, false;
    RETURN;
  END IF;

  INSERT INTO public.moderation_reports (reporter_user_id, target_type, target_id, reason, details, content_snapshot)
  VALUES (v_uid, 'message'::public.mod_target, p_message_id, p_reason, NULL, NULL)
  RETURNING moderation_reports.id INTO v_id;

  RETURN QUERY SELECT v_id, true;
END;
$$;

COMMENT ON FUNCTION public.msg_report_message(uuid, uuid, bigint, public.report_reason, text) IS
  'KAN-512: report a game-chat message. Ids and reason only, content_snapshot NULL. Caller re-checked with msg_evaluate; idempotent per (reporter, message).';

REVOKE ALL ON FUNCTION public.msg_report_message(uuid, uuid, bigint, public.report_reason, text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.msg_report_message(uuid, uuid, bigint, public.report_reason, text)
  TO authenticated;
