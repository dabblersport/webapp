-- APPLIED 2026-09-11 via apply_migration. Ledger version 20260911133843.
-- First of two KAN-189 migrations -- see the follow-up
-- 20260911163938_kan189_revoke_global_public_execute_default.sql for the
-- second, which this one alone does not complete AC2.
--
-- KAN-189: pg_default_acl for schema public, defaclobjtype='f' (function
-- defaults) still grants EXECUTE to anon on every FUTURE CREATE FUNCTION.
-- KAN-67's revoke covered TABLES only and never touched this. Root cause of
-- the anon-EXECUTE-on-creation exposure hit repeatedly this session
-- (KAN-131, KAN-179/183, KAN-177's companion oracle ticket).
--
-- AC1 live read, precise (pg_default_acl, schema public, defaclobjtype='f'):
--   grantor=postgres:        {postgres=X/postgres, anon=X/postgres,
--                              authenticated=X/postgres, service_role=X/postgres}
--   grantor=supabase_admin:  {postgres=X/supabase_admin, anon=X/supabase_admin,
--                              authenticated=X/supabase_admin, service_role=X/supabase_admin}
-- No bare PUBLIC entry visible in either catalog row -- only anon and
-- authenticated are named explicitly, alongside postgres/service_role.
--
-- ROLE-SPLIT (T-045, binding): this migration touches ONLY the postgres-
-- grantor default. supabase_admin's identical anon exposure is explicitly
-- OUT OF SCOPE for this ticket -- T-045 reserves that role split for its own
-- ruling (KAN-194 carries it for this exact object class).
--
-- SCOPE (anon only, not authenticated): the defect named is specifically
-- anon (unauthenticated) inheriting EXECUTE by accident. authenticated
-- inheriting EXECUTE by default is the ordinary, intended Supabase posture
-- and is not named as a defect anywhere in this ticket.
--
-- IMPORTANT, discovered during closure (see the follow-up migration): this
-- statement alone does NOT remove PostgreSQL's built-in, GLOBAL
-- EXECUTE-to-PUBLIC default on new functions -- a per-schema default is
-- ADDED on top of the global one and cannot remove it. A disposable probe
-- function created after only this migration still inherited EXECUTE via a
-- bare PUBLIC grant, and anon inherits EXECUTE through PUBLIC membership
-- regardless of this migration. This migration is still correct and kept as
-- applied -- it closes the named-role channel -- but AC2 is not satisfied
-- until the second migration lands.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;

DO $$
DECLARE
  v_postgres_acl aclitem[];
  v_admin_acl    aclitem[];
BEGIN
  SELECT d.defaclacl INTO v_postgres_acl
  FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
  WHERE n.nspname = 'public' AND d.defaclobjtype = 'f'
    AND d.defaclrole = 'postgres'::regrole;

  IF v_postgres_acl @> ARRAY['anon=X/postgres'::aclitem] THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: postgres-grantor function default still grants anon EXECUTE';
  END IF;
  IF NOT (v_postgres_acl @> ARRAY['authenticated=X/postgres'::aclitem]) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated EXECUTE was unintentionally removed from the postgres-grantor function default';
  END IF;

  SELECT d.defaclacl INTO v_admin_acl
  FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
  WHERE n.nspname = 'public' AND d.defaclobjtype = 'f'
    AND d.defaclrole = 'supabase_admin'::regrole;

  IF NOT (v_admin_acl @> ARRAY['anon=X/supabase_admin'::aclitem]) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: supabase_admin-grantor default was touched -- out of scope for KAN-189';
  END IF;
END $$;
