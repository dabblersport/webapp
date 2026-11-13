-- KAN-926 live check for supabase/migrations/20261113050426_kan926_app_min_versions.sql. Read-only; run as postgres.
--   T0 public.app_min_versions exists
--   T1 exactly 3 rows (web, ios, android), all min_build 0
--   T2 RLS is enabled
--   T3 anon and authenticated can SELECT
--   T4 anon and authenticated hold no INSERT/UPDATE/DELETE/TRUNCATE privilege
--   T5 exactly one policy: SELECT, roles {anon,authenticated}, using true
-- Before the migration every line reads "not ok" (seen 2026-11-13); after it, all ok.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, to_regclass('public.app_min_versions') IS NOT NULL ok, 'app_min_versions exists' label
  UNION ALL SELECT 1, COALESCE((SELECT (xpath('//c/text()', query_to_xml(
      $q$SELECT count(*) FILTER (WHERE min_build = 0 AND platform IN ('web','ios','android')) = 3 AND count(*) = 3 AS c FROM public.app_min_versions$q$,
      false, false, '')))[1]::text::boolean
      WHERE to_regclass('public.app_min_versions') IS NOT NULL), false), '3 rows, min_build 0'
  UNION ALL SELECT 2, COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.app_min_versions')), false), 'RLS enabled'
  UNION ALL SELECT 3, COALESCE(has_table_privilege('anon', to_regclass('public.app_min_versions'), 'SELECT')
                  AND has_table_privilege('authenticated', to_regclass('public.app_min_versions'), 'SELECT'), false), 'anon + authenticated can SELECT'
  UNION ALL SELECT 4, COALESCE(NOT has_table_privilege('anon', to_regclass('public.app_min_versions'), 'INSERT,UPDATE,DELETE,TRUNCATE')
                  AND NOT has_table_privilege('authenticated', to_regclass('public.app_min_versions'), 'INSERT,UPDATE,DELETE,TRUNCATE'), false), 'anon + authenticated have no write privilege'
  UNION ALL SELECT 5, (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'app_min_versions') = 1
                  AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'app_min_versions'
                              AND cmd = 'SELECT' AND roles = '{anon,authenticated}' AND qual = 'true'), 'one SELECT policy for anon, authenticated'
) t;
