-- KAN-499 rollback: bring rpc_block_user(uuid, boolean) back under its original name and ACL.
--
-- STATUS: AUTHORED, NOT RUN. Rolling back is itself an APPLY: it needs the CEO's explicit approval of
-- this exact text, the same non-production-first order and the same owners as the migration.
-- It uses no DROP. It RE-OPENS the second block store: after it, a client can again block through
-- public.restrictions, where nothing enforces the block. Use it only if the migration broke a
-- caller that the caller map missed.
--
-- What it does NOT undo: the rows the migration carried from restrictions into user_blocks stay in
-- user_blocks (they are real blocks the users made). It does not touch restrictions.
--
-- Run order if both tickets were applied: undo KAN-499 (this file) first, then KAN-497's rollback.

ALTER FUNCTION public.rpc_block_user_legacy_v1(uuid, boolean) RENAME TO rpc_block_user;

-- Restore the ACL the function held BEFORE the migration. Take the truth from the A1 output saved
-- before the migration was applied (probes.sql). Default below: KAN-497's revoke migration had been
-- applied first (as the apply order requires), which leaves authenticated and service_role.
REVOKE ALL ON FUNCTION public.rpc_block_user(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_block_user(uuid, boolean) TO authenticated, service_role;

-- If A1 showed the baseline ACL instead (KAN-497's revoke NOT applied: PUBLIC, anon, authenticated and
-- service_role all executable), replace the two statements above with:
--   GRANT ALL ON FUNCTION public.rpc_block_user(uuid, boolean) TO PUBLIC, anon, authenticated, service_role;
