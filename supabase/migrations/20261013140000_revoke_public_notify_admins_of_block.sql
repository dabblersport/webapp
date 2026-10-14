-- KAN-523: revoke the PUBLIC (and so anon) EXECUTE on
-- public.notify_admins_of_block().   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- KAN-498's read-only grant sweep found the function anon-executable through the
-- PUBLIC pseudo-role only (no explicit anon grant: the 2026-07-01 migration
-- already revoked anon and authenticated by name, which leaves PUBLIC standing).
-- It is a SECURITY DEFINER trigger function used only by
-- trg_notify_admins_of_block (AFTER INSERT ON public.user_blocks). The EXECUTE
-- privilege is checked when a trigger is created, not when it fires, and a
-- function returning trigger cannot be called as an RPC, so this is hygiene: it
-- takes the function off the anon-executable list and must not stop the block
-- notifications. authenticated is deliberately NOT granted.
--
-- No body edit, no trigger edit, no DROP.

REVOKE ALL ON FUNCTION public.notify_admins_of_block() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() TO service_role;
