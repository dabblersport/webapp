-- KAN-580 (backend half): per-recipient message receipts, sent < delivered < seen.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step (needs-ops), one migration at a time, project
-- wtncuzcskpigqpmnxwws only. No DROP, no data written by this file.
--
-- MODEL. A receipt is a WATERMARK per (conversation, recipient), not a row per message:
--     delivered_seq = highest seq this recipient's device has received
--     seen_seq      = highest seq this recipient has seen (on screen)
-- A message at seq s is, for that recipient: 'seen' if s <= seen_seq, else 'delivered' if s <= delivered_seq, else
-- 'sent'. Message bodies and history stay in D1; this table holds ids and two integers, nothing else.
--
-- MONOTONIC, NEVER REGRESSING. Both columns only ever increase (GREATEST in the upsert, and a conditional update that
-- touches the row only when something would grow). seen implies delivered: CHECK (seen_seq <= delivered_seq), and an
-- acknowledgement of 'seen' raises delivered_seq to at least the same seq.
--
-- WHO ADVANCES IT. Only the recipient's own authenticated call: public.msg_ack_receipt uses auth.uid() and nothing
-- about the caller comes from a parameter. The table has RLS enabled and NO policy and no grant to anon or
-- authenticated; only this SECURITY DEFINER function writes it.
--
-- CURRENT MEMBERSHIP. The caller must pass public.msg_evaluate (the same gate as reading: a non-member, a removed
-- member, a user outside the pilot, a user whose messaging is off gets nothing). A member who LEFT may acknowledge
-- only up to their left_at_seq (the cap is applied, not an error). A read-only member (finished game, block) may still
-- acknowledge what they read.
--
-- IDEMPOTENT, MULTI-DEVICE. The state is per user, not per device. Any device acknowledging a seq the user already
-- holds is a no-op (advanced = false); two devices racing advance the state once (the upsert is atomic on the primary
-- key). Replays and retries are harmless for the same reason; a send retried under the same client key (Worker,
-- UNIQUE(conversation, sender, client_key)) returns the same seq, so it never creates a second receipt target.
--
-- SENDER'S VIEW. public.msg_receipt_summary(conversation, seqs) returns, for message seqs the caller says are theirs
-- (the Worker filters to the caller's own messages from D1), the DENOMINATOR and the counts. Denominator rule:
--   recipients = DISTINCT current active members (the msg_authorize member set) MINUS the sender
--                MINUS any member who has blocked the sender.
-- Numerator and denominator are taken over that same set, so delivered <= seen-or-delivered <= recipients always.
-- A member who leaves or is removed drops out of both; a member who joins counts for the history they can read. The
-- count is DISTINCT users (one watermark per user), so a user with two devices or two roster rows counts once.
-- A group message is 'delivered' for the sender when delivered_count = recipients and 'seen' when seen_count =
-- recipients; the app's wording and the per-person drawer are design-defined and NOT in this change.
--
-- GRANTS. REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. Rollback:
-- supabase/tests/messaging/receipts_rollback.sql. Probes: supabase/tests/messaging/receipts_probes.sql.

CREATE TABLE IF NOT EXISTS public.msg_receipts (
  conversation_id uuid NOT NULL REFERENCES public.msg_conversations (id),
  user_id         uuid NOT NULL,
  delivered_seq   bigint NOT NULL DEFAULT 0 CONSTRAINT msg_receipts_delivered_seq_check CHECK (delivered_seq >= 0),
  seen_seq        bigint NOT NULL DEFAULT 0 CONSTRAINT msg_receipts_seen_seq_check CHECK (seen_seq >= 0),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT msg_receipts_seen_le_delivered_check CHECK (seen_seq <= delivered_seq)
);

COMMENT ON TABLE public.msg_receipts IS
  'KAN-580: per-recipient receipt watermarks (delivered_seq, seen_seq), monotonic, written only by msg_ack_receipt. Identifiers and integers only; no message content.';

CREATE INDEX IF NOT EXISTS msg_receipts_user_idx ON public.msg_receipts (user_id);

ALTER TABLE public.msg_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.msg_receipts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.msg_receipts TO service_role;

-- The recipient's own acknowledgement.
CREATE OR REPLACE FUNCTION public.msg_ack_receipt(
  p_conversation_id uuid,
  p_state text,
  p_through_seq bigint,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (delivered_seq bigint, seen_seq bigint, advanced boolean)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
DECLARE
  v_uid       uuid := auth.uid();
  v_eval      record;
  v_through   bigint;
  v_delivered bigint;
  v_seen      bigint;
  v_adv       boolean := false;
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_through_seq IS NULL
     OR p_state IS NULL OR p_state NOT IN ('delivered', 'seen') THEN
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS NULL THEN
    RETURN;
  END IF;

  v_through := p_through_seq;
  IF v_eval.left_at_seq IS NOT NULL THEN
    v_through := LEAST(v_through, v_eval.left_at_seq);
  END IF;
  IF v_through < 1 THEN
    RETURN QUERY
      SELECT COALESCE(r.delivered_seq, 0), COALESCE(r.seen_seq, 0), false
        FROM (SELECT 1) one
        LEFT JOIN public.msg_receipts r
          ON r.conversation_id = p_conversation_id AND r.user_id = v_uid;
    RETURN;
  END IF;

  INSERT INTO public.msg_receipts AS r (conversation_id, user_id, delivered_seq, seen_seq)
  VALUES (p_conversation_id, v_uid, v_through, CASE WHEN p_state = 'seen' THEN v_through ELSE 0 END)
  ON CONFLICT (conversation_id, user_id) DO UPDATE
     SET delivered_seq = GREATEST(r.delivered_seq, EXCLUDED.delivered_seq),
         seen_seq      = GREATEST(r.seen_seq, EXCLUDED.seen_seq),
         updated_at    = now()
   WHERE EXCLUDED.delivered_seq > r.delivered_seq OR EXCLUDED.seen_seq > r.seen_seq
  RETURNING r.delivered_seq, r.seen_seq INTO v_delivered, v_seen;
  v_adv := FOUND;

  IF NOT v_adv THEN
    SELECT r.delivered_seq, r.seen_seq INTO v_delivered, v_seen
      FROM public.msg_receipts r
     WHERE r.conversation_id = p_conversation_id AND r.user_id = v_uid;
  END IF;

  RETURN QUERY SELECT v_delivered, v_seen, v_adv;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_ack_receipt(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_ack_receipt(uuid, text, bigint, text) TO authenticated;

-- The sender's view: denominator and distinct-recipient counts for the caller's own messages.
CREATE OR REPLACE FUNCTION public.msg_receipt_summary(
  p_conversation_id uuid,
  p_seqs bigint[],
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (seq bigint, recipients integer, delivered_count integer, seen_count integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
DECLARE
  v_uid  uuid := auth.uid();
  v_auth record;
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_seqs IS NULL
     OR cardinality(p_seqs) = 0 OR cardinality(p_seqs) > 100 THEN
    RETURN;
  END IF;

  SELECT * INTO v_auth FROM public.msg_authorize(p_conversation_id, p_access_mode);
  IF v_auth.allowed_action IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH recips AS (
    SELECT DISTINCT m AS user_id
      FROM unnest(v_auth.member_user_ids) AS m
     WHERE m <> v_uid
       AND NOT EXISTS (
         SELECT 1 FROM public.user_blocks b
          WHERE b.blocker_user_id = m AND b.blocked_user_id = v_uid)
  ),
  wanted AS (SELECT DISTINCT s AS seq FROM unnest(p_seqs) AS s WHERE s >= 1)
  SELECT w.seq,
         (SELECT count(*)::integer FROM recips),
         (SELECT count(*)::integer FROM recips x
            JOIN public.msg_receipts r ON r.conversation_id = p_conversation_id AND r.user_id = x.user_id
           WHERE r.delivered_seq >= w.seq),
         (SELECT count(*)::integer FROM recips x
            JOIN public.msg_receipts r ON r.conversation_id = p_conversation_id AND r.user_id = x.user_id
           WHERE r.seen_seq >= w.seq)
    FROM wanted w
   ORDER BY w.seq;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_receipt_summary(uuid, bigint[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_receipt_summary(uuid, bigint[], text) TO authenticated;
