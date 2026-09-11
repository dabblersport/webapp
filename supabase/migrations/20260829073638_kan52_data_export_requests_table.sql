-- KAN-52 — public.data_export_requests did not exist in production.
-- Authored by backend-owner, 2026-08-29. Already applied live (this file
-- was recovered from an untracked copy at supabase/schema/migrations/ and
-- moved to the current migrations convention — supabase/migrations/,
-- YYYYMMDDHHMMSS_ prefix — per KAN-33; content reconstructed to match the
-- verified live table exactly). Do not re-apply.
--
-- DataExportService (lib/features/profile/services/data_export_service.dart)
-- writes/reads this table directly from the client under the requesting
-- user's session — there is no edge function or service-role path in this
-- flow. Every insert/select/update the service issues is scoped by
-- `user_id`, so RLS must allow the owning user through on all three, or the
-- symptom KAN-52 found (writes silently caught and logged, not surfaced)
-- recurs at the RLS layer instead of the missing-table layer.
--
-- Column shapes taken from DataExportRequest.fromJson/toJson and the two
-- update call sites (_updateExportStatus, _updateExportRequest), which
-- together also need `updated_at` — present in both UPDATE payloads but
-- absent from the ticket's own column list.
--
-- `id` is NOT a database-generated uuid: DataExportRequest._generateExportId()
-- builds it client-side as `'gdpr_export_' + Uuid().v4()`, a string, and the
-- client always supplies it on insert. Column is `text`, not `uuid`, and has
-- no server-side default.
--
-- `format`/`status` are validated against the exact enum names Dart sends
-- (DataExportFormat, DataExportStatus), via `.toString().split('.').last`,
-- so the CHECK constraints below are the enum's own value set, not a guess.

BEGIN;

CREATE TABLE IF NOT EXISTS public.data_export_requests (
  id                       text PRIMARY KEY,
  user_id                  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email               text NOT NULL,
  format                   text NOT NULL CHECK (format IN ('json', 'csv', 'zip')),
  status                   text NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'expired')),
  requested_at             timestamptz NOT NULL DEFAULT now(),
  expires_at               timestamptz NOT NULL,
  send_email_notification  boolean NOT NULL DEFAULT true,
  custom_message           text NULL,
  file_path                text NULL,
  error_message            text NULL,
  completed_at             timestamptz NULL,
  download_count           integer NOT NULL DEFAULT 0,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_data_export_requests_user_id ON public.data_export_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_data_export_requests_user_status ON public.data_export_requests(user_id, status);

ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;

-- Owner-only, all three verbs the client actually issues. No admin/service
-- read path is added here — T-020 says a control's data is never readable
-- by the people it constrains, not that it must be readable by people it
-- doesn't.
CREATE POLICY data_export_requests_select_own ON public.data_export_requests
FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY data_export_requests_insert_own ON public.data_export_requests
FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY data_export_requests_update_own ON public.data_export_requests
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Post-KAN-67: ALTER DEFAULT PRIVILEGES no longer auto-grants anon/authenticated
-- write on new tables. RLS above scopes rows; these grants give the
-- `authenticated` role the verb capability RLS then narrows.
GRANT SELECT, INSERT, UPDATE ON public.data_export_requests TO authenticated;

COMMIT;
