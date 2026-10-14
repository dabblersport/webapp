-- KAN-512 (Messaging T17) 1/2: a message report never carries a copy of the message (D21).
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
--
-- Rule: on public.moderation_reports, target_type 'message' implies content_snapshot IS NULL.
-- Every other target type is untouched (report_content may still snapshot posts, comments ...).
--
-- WHY THIS CANNOT FAIL ON EXISTING ROWS: the constraint is added NOT VALID. PostgreSQL then
-- enforces it for every row inserted or updated from now on and does not scan existing rows,
-- so ADD CONSTRAINT succeeds whatever the table already holds. Whether any existing row
-- violates the rule is not assumed: probe R1 in supabase/tests/messaging/report_probes.sql
-- counts violators and expects 0. Only after R1 returns 0 may a separate, later statement
-- run VALIDATE CONSTRAINT; that statement is deliberately NOT in this file.
--
-- Re-runnable: the constraint is added only if it is not already present.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'moderation_reports_message_no_snapshot_check'
       AND conrelid = 'public.moderation_reports'::regclass
  ) THEN
    ALTER TABLE public.moderation_reports
      ADD CONSTRAINT moderation_reports_message_no_snapshot_check
      CHECK (target_type <> 'message'::public.mod_target OR content_snapshot IS NULL)
      NOT VALID;
  END IF;
END;
$$;

COMMENT ON CONSTRAINT moderation_reports_message_no_snapshot_check ON public.moderation_reports IS
  'KAN-512 (D21): a report on a message stores no copy of the message. Added NOT VALID; validate only after probe R1 counts 0 violators.';
