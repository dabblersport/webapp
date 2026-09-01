-- KAN-52 / P-029 followup — closes the gap the original kan52 migration
-- flagged but explicitly left out of scope: public.export_download_logs,
-- public.gdpr_compliance_log, and the increment_download_count() RPC are
-- all absent from production. Verified live 2026-09-01 (execute_sql against
-- information_schema.tables / pg_proc, project wtncuzcskpigqpmnxwws).
--
-- DataExportService (lib/features/profile/services/data_export_service.dart)
-- calls these three from _trackDownload() (lines ~1600-1619) and
-- _recordGDPRExport() (lines ~1645-1660). Both call sites are already
-- wrapped in try/catch that logs a warning and continues — their absence
-- does not break the request/export flow, it just means downloads go
-- untracked and completed exports go unrecorded in the compliance log.
-- Building them here removes that silent gap rather than accepting it.
--
-- NOT YET APPLIED — per G-002 / decision 019, only `cto` may apply this to
-- production. Authored and posted to KAN-52 for handoff.

BEGIN;

-- ---------------------------------------------------------------------------
-- export_download_logs — one row per download of a completed export.
-- Column shapes taken from the _trackDownload() insert payload.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.export_download_logs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id     text NOT NULL REFERENCES public.data_export_requests(id) ON DELETE CASCADE,
  downloaded_at  timestamptz NOT NULL DEFAULT now(),
  ip_address     text NULL
);

CREATE INDEX IF NOT EXISTS idx_export_download_logs_request_id ON public.export_download_logs(request_id);

ALTER TABLE public.export_download_logs ENABLE ROW LEVEL SECURITY;

-- No direct user_id column — ownership is via the parent export request.
-- T-020: scoped to the owner of the request being downloaded, nobody else.
CREATE POLICY export_download_logs_select_own ON public.export_download_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.data_export_requests der
    WHERE der.id = export_download_logs.request_id
      AND der.user_id = auth.uid()
  )
);

CREATE POLICY export_download_logs_insert_own ON public.export_download_logs
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.data_export_requests der
    WHERE der.id = export_download_logs.request_id
      AND der.user_id = auth.uid()
  )
);

GRANT SELECT, INSERT ON public.export_download_logs TO authenticated;

-- ---------------------------------------------------------------------------
-- gdpr_compliance_log — append-only record of completed export actions.
-- Column shapes taken from the _recordGDPRExport() insert payload.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gdpr_compliance_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action        text NOT NULL,
  request_id    text NULL REFERENCES public.data_export_requests(id) ON DELETE SET NULL,
  format        text NULL,
  completed_at  timestamptz NULL,
  legal_basis   text NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gdpr_compliance_log_user_id ON public.gdpr_compliance_log(user_id);

ALTER TABLE public.gdpr_compliance_log ENABLE ROW LEVEL SECURITY;

-- Owner-only, matching the pattern used for data_export_requests. This is a
-- compliance record about the user, not a moderation/admin log — no
-- separate admin read path is added here; out of this ticket's scope.
CREATE POLICY gdpr_compliance_log_select_own ON public.gdpr_compliance_log
FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY gdpr_compliance_log_insert_own ON public.gdpr_compliance_log
FOR INSERT
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT ON public.gdpr_compliance_log TO authenticated;

-- ---------------------------------------------------------------------------
-- increment_download_count() — bumps data_export_requests.download_count.
-- SECURITY INVOKER (the default): runs as the calling `authenticated` role,
-- so the existing data_export_requests_update_own RLS policy
-- (user_id = auth.uid()) governs the UPDATE below — no DEFINER privilege
-- escalation needed for a one-column self-owned counter bump.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_download_count(request_id text)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE public.data_export_requests
  SET download_count = download_count + 1,
      updated_at = now()
  WHERE id = increment_download_count.request_id
    AND user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.increment_download_count(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_download_count(text) TO authenticated;

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply.
-- ============================================================================
--
-- 1. Both tables exist with RLS enabled:
--    SELECT relname, relrowsecurity FROM pg_class
--    WHERE relname IN ('export_download_logs','gdpr_compliance_log');
--    -- expect: t, t
--
-- 2. Policy counts:
--    SELECT tablename, policyname, cmd FROM pg_policies
--    WHERE schemaname='public' AND tablename IN ('export_download_logs','gdpr_compliance_log')
--    ORDER BY tablename, cmd;
--    -- expect: 2 rows each (SELECT, INSERT)
--
-- 3. anon has no access to either table or the function:
--    SELECT has_table_privilege('anon','public.export_download_logs','SELECT');   -- expect: false
--    SELECT has_table_privilege('anon','public.gdpr_compliance_log','SELECT');    -- expect: false
--    SELECT has_function_privilege('anon','public.increment_download_count(text)','EXECUTE'); -- expect: false
--
-- 4. A user can log a download against their own request and cannot against
--    another user's:
--    BEGIN;
--      SET LOCAL ROLE authenticated;
--      SELECT set_config('request.jwt.claims', json_build_object('sub','<user_a_id>')::text, true);
--      INSERT INTO public.export_download_logs (request_id, ip_address)
--        VALUES ('<user_a_request_id>', 'masked_for_privacy');  -- expect: success
--      INSERT INTO public.export_download_logs (request_id, ip_address)
--        VALUES ('<user_b_request_id>', 'masked_for_privacy');  -- expect: RLS violation
--    ROLLBACK;
--
-- 5. increment_download_count only bumps the caller's own row:
--    BEGIN;
--      SET LOCAL ROLE authenticated;
--      SELECT set_config('request.jwt.claims', json_build_object('sub','<user_a_id>')::text, true);
--      SELECT public.increment_download_count('<user_a_request_id>');
--      SELECT download_count FROM public.data_export_requests WHERE id = '<user_a_request_id>'; -- expect: incremented
--      SELECT public.increment_download_count('<user_b_request_id>');  -- expect: 0 rows affected, no error, no change
--    ROLLBACK;
