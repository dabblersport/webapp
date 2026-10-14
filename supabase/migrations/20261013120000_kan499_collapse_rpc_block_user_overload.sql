-- KAN-499: collapse the 2-argument block RPC overload onto the single user_blocks store.
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing in this file was run against any database. It is
-- applied later, non-production first, only with the CEO's explicit approval of this exact text
-- (G-002 backend owner plus PEER review; devops for the push). Project wtncuzcskpigqpmnxwws only.
--
-- Why. public.rpc_block_user has two overloads. The 1-argument form (the only one the app calls)
-- writes public.user_blocks and fires trg_notify_admins_of_block; the 2-argument form
-- (p_peer uuid, p_block boolean) writes public.restrictions, a second block store that nothing
-- reads. A block made through it is enforced nowhere. Caller map: supabase/tests/block_overload_collapse/CALLERS.md
-- (the app never calls it; no edge function, trigger, view, policy or function body does).
--
-- What it does, in this order. Nothing is dropped; no function body is edited.
--   1. Renames the 2-argument overload to rpc_block_user_legacy_v1 (the pattern of
--      20261008140000_game_price_meetup_setting.sql, Step 8). A client call that names p_block
--      no longer resolves.
--   2. Revokes ALL on the renamed function from PUBLIC, anon and authenticated; service_role
--      and the owner keep EXECUTE.
--   3. Carries every restrictions row of type 'blocked' into user_blocks, once, with
--      ON CONFLICT DO NOTHING. It only reads restrictions; the table stays in place and is not written.
--      Each carried row fires trg_notify_admins_of_block (AFTER INSERT on user_blocks), so with N
--      rows to carry the admins get N low-priority notifications; live evidence (KAN-496 E2,
--      2026-10-13) shows 0 restrictions rows, so none today.
--
-- Not changed: rpc_block_user(uuid) and rpc_unblock_user(uuid) (body and ACL), the restrictions
-- table, rpc_restrict_set / rpc_restrict_clear (see CALLERS.md, "Residual second block store").
--
-- Order. This file sorts after KAN-497's two migrations (20261013100000_kan497_is_blocked_narrow_to_caller.sql,
-- 20261013110000_kan497_revoke_anon_block_rpcs.sql) and is written to be applied after them.
-- Rollback: supabase/tests/block_overload_collapse/rollback.sql (itself an apply; re-opens the second store).

ALTER FUNCTION public.rpc_block_user(uuid, boolean) RENAME TO rpc_block_user_legacy_v1;

REVOKE ALL ON FUNCTION public.rpc_block_user_legacy_v1(uuid, boolean) FROM PUBLIC, anon, authenticated;

INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
SELECT r.user_id, r.target_user_id
FROM public.restrictions r
WHERE r.type = 'blocked'
ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
