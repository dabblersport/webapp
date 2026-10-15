-- KAN-560 rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the same explicit approval as the migration
-- (project wtncuzcskpigqpmnxwws only). It runs in one transaction and REFUSES (nothing changes) when any DM
-- conversation exists: a DM row cannot live under the old game-only shape.
--
-- What it does when no DM exists: revokes msg_start_dm and msg_set_muted from the app, re-issues the previous
-- msg_evaluate (KAN-529), msg_authorize (KAN-505) and msg_notify (KAN-547) texts verbatim, and restores the old
-- shape of msg_conversations (kind 'game' only, game_id NOT NULL). The two constraint removals below are the only
-- removals. It leaves in place, because they are additive and harmless: msg_dm_pairs (empty), the muted_at column,
-- the two internal helper functions, and the msg_dm_pairs index.

begin;

do $$
begin
  if exists (select 1 from public.msg_conversations where kind = 'dm') then
    raise exception 'rollback refused: dm conversations exist';
  end if;
  if exists (select 1 from public.msg_dm_pairs) then
    raise exception 'rollback refused: dm pairs exist';
  end if;
end;
$$;

revoke execute on function public.msg_start_dm(uuid) from authenticated;
revoke execute on function public.msg_set_muted(uuid, boolean) from authenticated;

-- The previous msg_evaluate (20261013160100_kan529_msg_evaluate_closed_game_reasons.sql), verbatim.
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
    IF v_cancelled THEN
      -- Cancelled wins over ended: a cancelled game past its end time is still game_cancelled.
      RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, v_game_id;
    ELSIF v_end_at >= now() THEN
      RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id;
    ELSE
      RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, v_game_id;
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

revoke all on function public.msg_evaluate(uuid, uuid, text) from public, anon, authenticated;

-- The previous msg_authorize (20261013150200_kan505_msg_functions.sql), verbatim.
CREATE OR REPLACE FUNCTION public.msg_authorize(
  p_conversation_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (
  user_id uuid,
  allowed_action text,
  reason text,
  left_at_seq bigint,
  member_user_ids uuid[],
  hidden_sender_ids uuid[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_eval record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::text, v_eval.reason, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid,
         v_eval.allowed_action,
         v_eval.reason,
         v_eval.left_at_seq,
         -- CURRENT active members, for fan-out.
         COALESCE((SELECT array_agg(DISTINCT r.user_id ORDER BY r.user_id)
                     FROM public.game_roster r
                    WHERE r.game_id = v_eval.game_id
                      AND r.status = 'active'
                      AND r.role IN ('host', 'player', 'sub')), '{}'::uuid[]),
         -- D4 group rule: users the caller blocked; the Worker hides their messages.
         COALESCE((SELECT array_agg(DISTINCT b.blocked_user_id ORDER BY b.blocked_user_id)
                     FROM public.user_blocks b
                    WHERE b.blocker_user_id = v_uid), '{}'::uuid[]);
END;
$$;

revoke all on function public.msg_authorize(uuid, text) from public, anon;
grant execute on function public.msg_authorize(uuid, text) to authenticated, service_role;

-- The previous msg_notify (20261013160800_kan547_msg_my_conversations.sql), verbatim.
CREATE OR REPLACE FUNCTION public.msg_notify(
  p_conversation_id uuid,
  p_seq bigint,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_eval    record;
  v_payload jsonb;
  v_to      uuid;
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 THEN
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;

  -- KAN-547: the one added statement. Stamps the conversation so the Messages list can order by
  -- recent activity. Quiet: a failed stamp warns (sqlstate only) and the wake-ups below still go out.
  BEGIN
    UPDATE public.msg_conversations SET last_activity_at = now() WHERE id = p_conversation_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'msg_notify stamp failed (sqlstate %)', SQLSTATE;
  END;

  v_payload := jsonb_build_object(
    'type', 'msg',
    'conversation_id', p_conversation_id,
    'seq', p_seq
  );

  FOR v_to IN
    SELECT DISTINCT r.user_id
      FROM public.game_roster r
     WHERE r.game_id = v_eval.game_id
       AND r.status = 'active'
       AND r.role IN ('host', 'player', 'sub')
       AND NOT EXISTS (
         SELECT 1
           FROM public.user_blocks b
          WHERE b.blocker_user_id = r.user_id
            AND b.blocked_user_id = v_uid
       )
  LOOP
    BEGIN
      PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'msg_notify send failed (sqlstate %)', SQLSTATE;
    END;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$$;

revoke all on function public.msg_notify(uuid, bigint, text) from public, anon;
grant execute on function public.msg_notify(uuid, bigint, text) to authenticated;

-- The old shape of msg_conversations (only reached when no DM exists).
alter table public.msg_conversations drop constraint if exists msg_conversations_kind_game_check;
alter table public.msg_conversations drop constraint if exists msg_conversations_kind_check;
alter table public.msg_conversations
  add constraint msg_conversations_kind_check check (kind = 'game');
alter table public.msg_conversations alter column game_id set not null;

commit;
