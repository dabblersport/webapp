-- KAN-555 rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the same explicit approval as the migration
-- (project wtncuzcskpigqpmnxwws only). It removes nothing: it swaps the names back so the app calls the KAN-547
-- (v1) function again. CREATE OR REPLACE cannot restore v1 over the new result columns, so the v1 function, which the
-- migration only renamed, becomes msg_my_conversations again and the new function is kept under another name with
-- its EXECUTE revoked.

begin;

revoke all on function public.msg_my_conversations(int) from public, anon, authenticated;
alter function public.msg_my_conversations(int) rename to msg_my_conversations_dm_off;

alter function public.msg_my_conversations_v1(int) rename to msg_my_conversations;
revoke all on function public.msg_my_conversations(int) from public, anon;
grant execute on function public.msg_my_conversations(int) to authenticated;

commit;
