-- KAN-580 (UI half, recipient drawer): per-person receipt state for ONE message seq.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step (needs-ops), after
-- 20261020150000_kan580_msg_receipts.sql, project wtncuzcskpigqpmnxwws only. No DROP, no data written by this file.
--
-- WHAT. public.msg_receipt_recipients(conversation, seq, caller, members) returns one row per recipient with that
-- recipient's state for the message at `seq`: 'seen' (seen_seq >= seq), 'delivered' (delivered_seq >= seq) or 'sent',
-- and the time of the recipient's last watermark update (updated_at) as the best available "when". The recipient set is
-- the one msg_receipt_summary counts (distinct current members, minus the caller, minus members who blocked the
-- caller), so the drawer's three lists add up to the group count the bubble shows.
--
-- SERVICE_ROLE ONLY (CTO ruling, KAN-580 decision dreq-2a502389). Names are shown only to the person who SENT the
-- message (MESSAGING_DS_ADDITIONS.md section 15). The database cannot see D1, where senders live, so it cannot check
-- that. This function therefore has NO caller identity of its own (no auth.uid()): EXECUTE is granted to service_role
-- ONLY and revoked from PUBLIC, anon and authenticated. The only caller is the Worker route
-- GET /v1/conversations/{id}/receipts/{seq}, which first proves (1) the caller is a current member (msg_authorize with
-- the caller's own bearer, whose member_user_ids it passes here) and (2) the caller sent `seq` (D1), and answers 404
-- otherwise. The member list is trusted only because only service_role can call this.
--
-- Returns user ids and states, never message content. Display names are resolved by the app from profiles.
--
-- Rollback: revoke execute from service_role (supabase/tests/messaging/receipt_recipients_probes.sql). No DROP.

CREATE OR REPLACE FUNCTION public.msg_receipt_recipients(
  p_conversation_id uuid,
  p_seq bigint,
  p_caller_id uuid,
  p_member_ids uuid[]
)
RETURNS TABLE (user_id uuid, state text, updated_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
BEGIN
  IF p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 OR p_caller_id IS NULL
     OR p_member_ids IS NULL OR cardinality(p_member_ids) > 500 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH recips AS (
    SELECT DISTINCT m AS user_id
      FROM unnest(p_member_ids) AS m
     WHERE m <> p_caller_id
       AND NOT EXISTS (
         SELECT 1 FROM public.user_blocks b
          WHERE b.blocker_user_id = m AND b.blocked_user_id = p_caller_id)
  )
  SELECT x.user_id,
         CASE
           WHEN r.seen_seq      >= p_seq THEN 'seen'
           WHEN r.delivered_seq >= p_seq THEN 'delivered'
           ELSE 'sent'
         END AS state,
         r.updated_at
    FROM recips x
    LEFT JOIN public.msg_receipts r
           ON r.conversation_id = p_conversation_id AND r.user_id = x.user_id
   ORDER BY 2, x.user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_receipt_recipients(uuid, bigint, uuid, uuid[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.msg_receipt_recipients(uuid, bigint, uuid, uuid[]) TO service_role;
