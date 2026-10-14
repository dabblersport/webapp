-- KAN-505 (Messaging T8) rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the CEO's explicit approval,
-- on a non-production branch of project wtncuzcskpigqpmnxwws first.
--
-- It removes nothing. It disables: every grant on the new functions and tables is revoked,
-- and the Realtime policy is altered to deny everyone. The objects and their rows stay in
-- place, so the change is reversible by re-running the original grants.

begin;

-- Realtime policy (4/4): deny all receives on 'user:' topics through this policy.
do $$
begin
  if exists (select 1 from pg_policies
              where schemaname = 'realtime' and tablename = 'messages'
                and policyname = 'msg_user_topic_receive') then
    alter policy msg_user_topic_receive on realtime.messages using (false);
  end if;
end;
$$;

-- Functions (3/4): nobody may execute them.
revoke all on function public.msg_authorize(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_can_send(uuid, uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_can_read(uuid, uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_evaluate(uuid, uuid, text) from public, anon, authenticated, service_role;

-- Allowlist (2/4) and registry (1/4): no API role may read or write them. RLS stays on.
revoke all on table public.msg_access_allowlist from public, anon, authenticated, service_role;
revoke all on table public.msg_conversation_members from public, anon, authenticated, service_role;
revoke all on table public.msg_conversations from public, anon, authenticated, service_role;

commit;

-- ======================================================================================
-- KAN-529 rollback (run ALONE to revert only KAN-529).   AUTHORED, NOT RUN.
-- Restores the KAN-505 body of public.msg_evaluate verbatim with CREATE OR REPLACE: after it a
-- closed game returns ('read', 'read_only') again. Grants are untouched. Nothing is removed.
-- Needs the same explicit approval as the rest of this file.
begin;

CREATE OR REPLACE FUNCTION public.msg_evaluate(
  p_conversation_id uuid,
  p_user_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (allowed_action text, reason text, left_at_seq bigint, game_id uuid)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
  v_game_id   uuid;
  v_cancelled boolean;
  v_end_at    timestamptz;
  v_role      text;
  v_status    text;
  v_left_seq  bigint;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_authenticated'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode IS NULL OR p_access_mode NOT IN ('allowlist', 'all') THEN
    RETURN QUERY SELECT NULL::text, 'messaging_off'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode = 'allowlist'
     AND NOT EXISTS (SELECT 1 FROM public.msg_access_allowlist a WHERE a.user_id = p_user_id) THEN
    RETURN QUERY SELECT NULL::text, 'not_in_pilot'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  SELECT c.game_id, g.is_cancelled, g.end_at
    INTO v_game_id, v_cancelled, v_end_at
    FROM public.msg_conversations c
    JOIN public.games g ON g.id = c.game_id
   WHERE c.id = p_conversation_id;

  IF v_game_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- One user may hold more than one roster row (one per profile): an active row wins.
  SELECT r.role, r.status
    INTO v_role, v_status
    FROM public.game_roster r
   WHERE r.game_id = v_game_id
     AND r.user_id = p_user_id
     AND r.role IN ('host', 'player', 'sub')
   ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
   LIMIT 1;

  IF v_status IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF v_status = 'active' THEN
    IF NOT v_cancelled AND v_end_at >= now() THEN
      RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id;
    ELSE
      RETURN QUERY SELECT 'read'::text, 'read_only'::text, NULL::bigint, v_game_id;
    END IF;
    RETURN;
  END IF;

  IF v_status = 'left' THEN
    SELECT m.left_at_seq INTO v_left_seq
      FROM public.msg_conversation_members m
     WHERE m.conversation_id = p_conversation_id
       AND m.user_id = p_user_id;
    -- No recorded left_at_seq fails closed: read up to 0, i.e. nothing.
    RETURN QUERY SELECT 'read'::text, 'left'::text, COALESCE(v_left_seq, 0), v_game_id;
    RETURN;
  END IF;

  -- 'kicked' and every other non-active status read nothing.
  RETURN QUERY SELECT NULL::text, 'removed'::text, NULL::bigint, NULL::uuid;
END;
$$;

commit;

-- ======================================================================================
-- KAN-530 rollback (run ALONE to revert only KAN-530).   AUTHORED, NOT RUN.
-- Restores the baseline public.report_content body verbatim and removes only the new CHECK.
-- Needs the same explicit approval as the rest of this file.
begin;

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
    me, p_target_type, p_target_id, p_reason, p_details, p_snapshot
  )
  returning * into row;

  perform public.audit_log(
    'mod.report',
    p_target_type,
    p_target_id,
    null,
    jsonb_build_object('reason', p_reason, 'details', p_details)
  );

  return row;
end;
$$;

alter table public.moderation_reports drop constraint if exists moderation_reports_message_no_details_check;

commit;
