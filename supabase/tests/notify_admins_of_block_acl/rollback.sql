-- KAN-523 rollback. AUTHORED, NOT RUN.
--
-- THIS FILE IS ITSELF AN APPLY, done only by Memphis with the CEO approval of
-- 2026-10-13 (execute_sql, never apply_migration, project
-- wtncuzcskpigqpmnxwws, test data only). It re-opens EXECUTE to PUBLIC (and so to
-- anon and authenticated). Last resort. No DROP.
--
-- Restores the baseline ACL: default PUBLIC execute plus the explicit
-- service_role grant (baseline line 35866). Confirm against probe A1's saved
-- output first; if the live ACL differed from that, STOP and ask.

BEGIN;
GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() TO service_role;
COMMIT;
