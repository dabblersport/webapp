-- The 20260901140000 migration relied on `REVOKE ALL ... FROM PUBLIC` for the
-- function and named GRANTs to `authenticated` for the tables, assuming that
-- was sufficient to keep `anon` out. It wasn't: this Supabase project has
-- ALTER DEFAULT PRIVILEGES configured to auto-grant `anon` SELECT/REFERENCES/
-- TRIGGER on every newly created table (and, evidently, EXECUTE on new
-- functions too) regardless of PUBLIC. Confirmed live: anon had SELECT on
-- both export_download_logs and gdpr_compliance_log, and EXECUTE on
-- increment_download_count, immediately after the prior migration ran.
--
-- Applied and verified live 2026-09-01 (G-002): anon now denied on all three
-- objects, authenticated unaffected.

REVOKE SELECT, REFERENCES, TRIGGER ON public.export_download_logs FROM anon;
REVOKE SELECT, REFERENCES, TRIGGER ON public.gdpr_compliance_log FROM anon;
REVOKE ALL ON FUNCTION public.increment_download_count(text) FROM anon;
