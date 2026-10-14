-- KAN-541 (Realtime R1) rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the same explicit approval as the
-- migration (project wtncuzcskpigqpmnxwws only).
--
-- It removes nothing. It revokes: after it, no API role can execute public.msg_notify, so no
-- wake-up is sent. The function and the realtime policy stay in place, so the change is reversible
-- by re-running the grant in 20261013160600_kan541_msg_notify.sql.

begin;

revoke all on function public.msg_notify(uuid, bigint, text) from public, anon, authenticated, service_role;

commit;
