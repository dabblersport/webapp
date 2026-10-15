-- KAN-551 rollback for 20261013161100_kan551_msg_report_list.sql.   AUTHORED, NOT RUN.
-- This is itself an apply against the database and needs explicit approval before it is run.
-- It removes nothing: it only takes EXECUTE away, so no client role can call the function.
-- notify_admins_of_report was not changed by KAN-551, so nothing is re-issued for it.
begin;
REVOKE EXECUTE ON FUNCTION public.msg_list_message_reports(integer) FROM authenticated;
commit;
