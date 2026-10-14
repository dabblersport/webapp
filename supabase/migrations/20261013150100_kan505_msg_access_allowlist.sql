-- KAN-505 (Messaging T8) 2/4: pilot allowlist (D19).
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
--
-- Consulted by public.msg_authorize only when the access mode passed by the Worker is
-- 'allowlist'. A user absent from this table is denied with reason 'not_in_pilot'.
-- Rows are added by service_role only. RLS on, no policy: anon and authenticated
-- cannot see who is in the pilot.

CREATE TABLE IF NOT EXISTS public.msg_access_allowlist (
  user_id  uuid PRIMARY KEY,
  added_at timestamptz NOT NULL DEFAULT now(),
  note     text
);

COMMENT ON TABLE public.msg_access_allowlist IS
  'KAN-505: messaging pilot cohort (D19). Read by msg_authorize when mode = allowlist.';

ALTER TABLE public.msg_access_allowlist ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.msg_access_allowlist FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.msg_access_allowlist TO service_role;
