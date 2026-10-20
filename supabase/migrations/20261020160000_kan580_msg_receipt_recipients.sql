-- KAN-580 (UI half, recipient drawer): per-person receipt state for ONE message seq.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step (needs-ops), after
-- 20261020150000_kan580_msg_receipts.sql, project wtncuzcskpigqpmnxwws only. No DROP, no data written by this file.
--
-- WHAT. public.msg_receipt_recipients(conversation, seq) returns one row per recipient with that recipient's state for
-- the message at `seq`: 'seen' (seen_seq >= seq), 'delivered' (delivered_seq >= seq) or 'sent', and the time of the
-- recipient's last watermark update (updated_at) as the best available "when". The recipient set is exactly the one
-- msg_receipt_summary counts (distinct current active members, minus the caller, minus members who blocked the caller),
-- so the drawer's three lists add up to the group count the bubble shows.
--
-- SENDER-ONLY. Names are shown only to the person who sent the message (MESSAGING_DS_ADDITIONS.md section 15: "who
-- may open the receipts drawer: built sender only"). The database cannot see D1, where message senders live, so this
-- function CANNOT verify that `seq` is the caller's own message. The Worker route that exposes it MUST first confirm
-- from D1 that the caller sent `seq`, exactly as it filters seqs for msg_receipt_summary. Granted to authenticated
-- only; without that Worker check, any current member could list recipients of any seq, so the function must not be
-- exposed to the app directly.
--
-- Returns user ids and states, never message content. Display names are resolved by the app from profiles.
--
-- Rollback: revoke execute (supabase/tests/messaging/receipt_recipients_probes.sql, last section). No DROP.

CREATE OR REPLACE FUNCTION public.msg_receipt_recipients(
  p_conversation_id uuid,
  p_seq bigint,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (user_id uuid, state text, updated_at timestamptz)
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
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 THEN
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

REVOKE ALL ON FUNCTION public.msg_receipt_recipients(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_receipt_recipients(uuid, bigint, text) TO authenticated;
