-- KAN-530 (Messaging): a message report carries no free text. AUTHORED, NOT APPLIED (operations applies it).
--
-- KAN-512 made a message report carry no message text in content_snapshot. Two baseline paths still
-- let a client store free text for target_type 'message' in moderation_reports.details:
--   1. public.report_content inserted p_details unchanged (and copied it into the audit payload);
--   2. the policy mr_self_insert accepts any column values, so a direct insert needs no function.
-- This migration closes both with the narrowest change:
--   - report_content PINS details to NULL when p_target_type = 'message' (it does not raise, so an
--     older client that still sends details keeps working; the text is discarded). The audit payload
--     carries details NULL for that call. Every other target type behaves exactly as before.
--   - one CHECK on moderation_reports: target_type <> 'message' OR details IS NULL. It is NOT VALID:
--     existing rows are not scanned, new inserts and updates are checked. mr_self_insert and every
--     other policy are neither recreated nor altered.
-- Unchanged on report_content: argument list and defaults, return type, LANGUAGE plpgsql, SECURITY
-- DEFINER, SET search_path TO 'public', the owner and the three EXECUTE grants (CREATE OR REPLACE
-- keeps them). content_snapshot and the KAN-512 snapshot rule are not touched.
--
-- BEFORE APPLY (SELECT only, executor reports the count):
--   select count(*) from public.moderation_reports where target_type = 'message' and details is not null;
-- A later UPDATE of such an old row (for example a moderator resolving it) fails under the CHECK until
-- its details is cleared, so a count above zero needs a decision first.
-- ROLLBACK (run alone, needs the same explicit approval; restores the baseline body verbatim and removes
-- only the new CHECK):
--   begin;
--   CREATE OR REPLACE FUNCTION "public"."report_content"("p_target_type" "public"."mod_target", "p_target_id" "uuid", "p_reason" "public"."report_reason", "p_details" "text" DEFAULT NULL::"text", "p_snapshot" "jsonb" DEFAULT NULL::"jsonb") RETURNS "public"."moderation_reports"
--       LANGUAGE "plpgsql" SECURITY DEFINER
--       SET "search_path" TO 'public'
--       AS $$
--   declare
--     me  uuid := auth.uid();
--     row public.moderation_reports;
--   begin
--     if me is null then
--       raise exception using errcode = 'P0001', message = 'auth_required';
--     end if;
--
--     insert into public.moderation_reports(
--       reporter_user_id, target_type, target_id, reason, details, content_snapshot
--     )
--     values (
--       me, p_target_type, p_target_id, p_reason, p_details, p_snapshot
--     )
--     returning * into row;
--
--     perform public.audit_log(
--       'mod.report',
--       p_target_type,
--       p_target_id,
--       null,
--       jsonb_build_object('reason', p_reason, 'details', p_details)
--     );
--
--     return row;
--   end;
--   $$;
--   alter table public.moderation_reports drop constraint if exists moderation_reports_message_no_details_check;
--   commit;

CREATE OR REPLACE FUNCTION "public"."report_content"("p_target_type" "public"."mod_target", "p_target_id" "uuid", "p_reason" "public"."report_reason", "p_details" "text" DEFAULT NULL::"text", "p_snapshot" "jsonb" DEFAULT NULL::"jsonb") RETURNS "public"."moderation_reports"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  me  uuid := auth.uid();
  row public.moderation_reports;
begin
  if me is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  insert into public.moderation_reports(
    reporter_user_id, target_type, target_id, reason, details, content_snapshot
  )
  values (
    me, p_target_type, p_target_id, p_reason,
    case when p_target_type = 'message' then null else p_details end,
    p_snapshot
  )
  returning * into row;

  perform public.audit_log(
    'mod.report',
    p_target_type,
    p_target_id,
    null,
    jsonb_build_object('reason', p_reason,
      'details', case when p_target_type = 'message' then null else p_details end)
  );

  return row;
end;
$$;

ALTER TABLE public.moderation_reports
  ADD CONSTRAINT moderation_reports_message_no_details_check
  CHECK (target_type <> 'message' OR details IS NULL) NOT VALID;
