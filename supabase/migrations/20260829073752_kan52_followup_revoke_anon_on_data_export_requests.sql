-- KAN-52 followup — defensive explicit revoke of anon privileges on
-- public.data_export_requests. Already applied live (recovered/reconstructed
-- alongside 20260829073638_kan52_data_export_requests_table.sql — see that
-- file's header). Do not re-apply.
--
-- The base migration only ever GRANTs to `authenticated`, so `anon` should
-- never have picked up privileges here — this is belt-and-suspenders against
-- any stale ALTER DEFAULT PRIVILEGES grant predating KAN-67
-- (20260828160122_kan67_revoke_anon_view_write_grants.sql) applying to this
-- table. Verified live 2026-09-01: information_schema.role_table_grants
-- shows zero rows for anon on this table.

BEGIN;

REVOKE ALL ON public.data_export_requests FROM anon;

COMMIT;
