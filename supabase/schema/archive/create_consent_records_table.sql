-- Applied to remote as migration version 20260701171116.
--
-- Guideline 1.2: durable audit trail proving the EULA/Terms-of-Use gate
-- was shown and accepted before the user could register or log in.
-- user_id is nullable because acceptance happens pre-auth (no session yet);
-- the client also generates a stable per-device id so acceptance can still
-- be correlated to a device even before an account exists.
CREATE TABLE IF NOT EXISTS public.consent_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  consent_type text NOT NULL DEFAULT 'eula',
  consent_version text NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_consent_records_user_id ON public.consent_records(user_id);
CREATE INDEX IF NOT EXISTS idx_consent_records_device_id ON public.consent_records(device_id);

ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;

-- Anyone (including anon, pre-login) may record their own acceptance;
-- authenticated users may only attach their own uid.
CREATE POLICY consent_records_insert ON public.consent_records
  FOR INSERT
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- Users may only read their own linked consent records (device-only /
-- pre-auth rows are not readable by clients, matching moderation_reports'
-- write-only-from-client pattern).
CREATE POLICY consent_records_select_own ON public.consent_records
  FOR SELECT
  USING (user_id = auth.uid());

-- Immutable audit trail: no UPDATE/DELETE policies for regular clients.
CREATE POLICY consent_records_block_mutations ON public.consent_records
  FOR UPDATE USING (false);

CREATE POLICY consent_records_block_delete ON public.consent_records
  FOR DELETE USING (false);
