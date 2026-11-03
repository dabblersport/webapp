-- KAN-791 local stack, step 4 (after the chain and stack_shim.sql; only when Realtime will run).
-- LOCAL THROWAWAY PG16 ONLY.
-- Realtime keeps its metadata in _realtime and its tenant objects in realtime, both pre-created on
-- Supabase by the platform image; its tenant migrations create supabase_realtime_admin themselves and
-- reference supabase_admin / dashboard_user, which exist on Supabase.
-- ORDER MATTERS: the Events harnesses (local_harness_kan724/725/728/731, B16 mode=before) refuse to load
-- once a "realtime" schema or a supabase_admin role exists ("looks like a Supabase database"), so this
-- runs only after the whole chain is in.
\set ON_ERROR_STOP 1
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS realtime;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='supabase_admin') THEN CREATE ROLE supabase_admin NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dashboard_user') THEN CREATE ROLE dashboard_user NOLOGIN; END IF;
END $$;
