-- APPLIED 2026-09-11 via apply_migration. Ledger version 20260911163938.
-- Second and final KAN-189 migration. Completes AC2; the first
-- (20260911133843_kan189_revoke_default_execute_functions.sql) alone was
-- insufficient.
--
-- ROOT CAUSE of why the first attempt -- schema-scoped
-- "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE
-- EXECUTE ON FUNCTIONS FROM PUBLIC", tried three ways, disposable-probe
-- verified ineffective each time -- did not work: PostgreSQL's built-in
-- EXECUTE-to-PUBLIC default on newly-created functions is part of the
-- GLOBAL default privilege, not the per-schema one. Per PostgreSQL
-- semantics, per-schema default privileges are ADDED on top of global
-- defaults; a per-schema REVOKE cannot remove a privilege granted globally.
-- The correct statement to remove it carries no IN SCHEMA clause at all.
--
-- Still postgres-grantor only (T-045 role split, unchanged from the first
-- migration): supabase_admin's identical global PUBLIC exposure remains
-- untouched and out of this ticket's authority.
--
-- Verified post-apply with a disposable probe function (created, inspected,
-- dropped): new-function proacl is now {postgres=X, authenticated=X,
-- service_role=X} -- no bare PUBLIC entry, anon EXECUTE is false. An
-- explicit GRANT EXECUTE ... TO anon on a disposable function still works
-- normally (the mechanism for intentional anon-callable RPCs is unaffected).
-- Existing functions (rpc_potential_vibes, fn_platform_owner_id,
-- rpc_get_friends, rpc_get_friend_suggestions) retain their existing
-- explicit anon/authenticated EXECUTE unchanged -- confirming the
-- default-privilege change is forward-only.
--
-- AC4, closed by rule rather than by editing any existing RPC: any future
-- RPC intentionally callable by anon must GRANT EXECUTE explicitly. It can
-- no longer rely on PostgreSQL's automatic PUBLIC function default.

ALTER DEFAULT PRIVILEGES
  FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
