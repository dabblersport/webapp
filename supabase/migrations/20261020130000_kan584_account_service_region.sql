-- KAN-584: the account's service region, stored per account so it follows the
-- user across devices.   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- Separate from the public profile country and from the
-- device's current location. One row per account, written only by its owner.
-- Allowed values are the five supported countries (English names, as the app
-- stores them) and 'Global'. No anon access.

CREATE TABLE IF NOT EXISTS public.account_service_region (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  region text NOT NULL DEFAULT 'Global'
    CHECK (region IN ('Egypt', 'Morocco', 'Qatar', 'Saudi Arabia',
                      'United Arab Emirates', 'Global')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.account_service_region ENABLE ROW LEVEL SECURITY;

CREATE POLICY account_service_region_select_own
  ON public.account_service_region FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY account_service_region_insert_own
  ON public.account_service_region FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY account_service_region_update_own
  ON public.account_service_region FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

REVOKE ALL ON public.account_service_region FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.account_service_region TO authenticated;
GRANT ALL ON public.account_service_region TO service_role;
