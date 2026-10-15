-- KAN-551 (Messaging launch M1a): admin-only list of message reports.   AUTHORED, NOT APPLIED.
--
-- Adds public.msg_list_message_reports(p_limit int DEFAULT 50). Ids, reason, status and time only.
-- No details, no content_snapshot, no reporter or target names, no message text. Reading a reported
-- message stays the KAN-513 audited Worker route (workers/messaging/src/moderation.ts); this function
-- neither reads nor copies message data.
--
-- Admin predicate: public.is_admin() (role_grants role 'admin' or 'super_admin' for auth.uid()), the
-- same one admin_resolve_report, v_mod_queue_open and the KAN-513 Worker read use. Not changed here.
--
-- Non-admin caller: RAISE P0001 'forbidden', the pattern of the existing admin RPC
-- public.admin_resolve_report (baseline_schema.sql:2614-2616). anon additionally holds no EXECUTE.
--
-- conversation_id: always NULL. msg_report_message (KAN-512) stores only the message id in
-- moderation_reports.target_id; the conversation id is a call argument and is not persisted. The
-- KAN-505 registry (msg_conversations, msg_conversation_members) holds no message table, and messages
-- live in the Worker's D1, so no message id can be mapped to a conversation in Supabase without
-- copying message data, which this ticket forbids. target_message_id is the report's target_id.
--
-- Notification check (read, not changed): trigger trg_notify_admins_of_report
-- (baseline_schema.sql:29995, AFTER INSERT FOR EACH ROW on moderation_reports) runs
-- public.notify_admins_of_report() (baseline_schema.sql:9323-9344): one notifications row per
-- app_admins row, body format('%s reported for %s', target_type, reason), context report_id,
-- target_type, target_id, reason. reason is the enum public.report_reason, so no reporter free text
-- can reach body or context. details and content_snapshot are not read by it, and are in any case
-- NULL for message reports (KAN-512 check 20261013160200, KAN-530 check 20261013160400). The only
-- later change to it is the ACL revoke in 20261013135000:62. No defect, so it is not redefined here.
--
-- ROLLBACK: supabase/tests/messaging/msg_report_list_rollback.sql (revoke only; an apply needing approval).

CREATE OR REPLACE FUNCTION public.msg_list_message_reports(p_limit integer DEFAULT 50)
RETURNS TABLE (
  report_id uuid,
  reason public.report_reason,
  created_at timestamptz,
  status public.report_status,
  target_message_id uuid,
  conversation_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'forbidden';
  END IF;

  RETURN QUERY
    SELECT r.id,
           r.reason,
           r.created_at,
           r.status,
           r.target_id,
           NULL::uuid
      FROM public.moderation_reports r
     WHERE r.target_type = 'message'::public.mod_target
     ORDER BY r.created_at DESC, r.id DESC
     LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
END;
$$;

COMMENT ON FUNCTION public.msg_list_message_reports(integer) IS
  'KAN-551: admin-only list of message reports (ids, reason, status, created_at; no text). Gate public.is_admin(); a non-admin gets P0001 forbidden, the admin_resolve_report pattern. conversation_id is always NULL: reports persist only the message id and the KAN-505 registry has no message table (messages live in the Worker D1). Message content is read only through the KAN-513 audited Worker route.';

REVOKE ALL ON FUNCTION public.msg_list_message_reports(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_list_message_reports(integer) TO authenticated;
