-- KAN-579 rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the same explicit approval as the migration
-- (project wtncuzcskpigqpmnxwws only).
--
-- It removes nothing. It revokes: after it, no API role can execute public.msg_typing, so no typing signal is
-- sent (the Worker route then answers 204 and the signal is swallowed). The function stays in place, so the
-- change is reversible by re-running the grant in 20261020140000_kan579_msg_typing.sql.

begin;
revoke all on function public.msg_typing(uuid, boolean, text) from public, anon, authenticated;
commit;
