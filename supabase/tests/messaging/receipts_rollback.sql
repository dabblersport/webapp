-- KAN-580 rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the same explicit approval as the migration
-- (project wtncuzcskpigqpmnxwws only). It drops nothing and deletes nothing: it revokes. After it no API role can
-- execute the two functions, so no receipt is recorded or read; the table and its watermarks stay in place and the
-- change is reversible by re-running the grants in 20261020150000_kan580_msg_receipts.sql.

begin;
revoke all on function public.msg_ack_receipt(uuid, text, bigint, text) from public, anon, authenticated;
revoke all on function public.msg_receipt_summary(uuid, bigint[], text) from public, anon, authenticated;
commit;
