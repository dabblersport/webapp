-- KAN-512 (Messaging T17) rollback.   AUTHORED, NOT RUN.
-- Running this is itself an apply on the target project and needs CEO approval.
-- It removes the report capability by revoking execution; it deletes nothing and
-- does not touch any moderation_reports row.
--
-- The NOT VALID constraint moderation_reports_message_no_snapshot_check is left in place:
-- it only refuses a copy of a message inside a message report, which D21 forbids anyway.
-- Removing the constraint itself requires a separately authored, CEO-approved statement
-- that this pack does not contain.

begin;
revoke execute on function public.msg_report_message(uuid, uuid, bigint, public.report_reason, text)
  from authenticated;
select not has_function_privilege('authenticated',
         'public.msg_report_message(uuid,uuid,bigint,public.report_reason,text)', 'EXECUTE') as pass_revoked;
commit;
