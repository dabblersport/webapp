-- KAN-928: the meetup twin of msg_game_conversation (KAN-563). APPLIED LIVE to wtncuzcskpigqpmnxwws.
--
-- Gap: KAN-558 taught msg_evaluate / msg_authorize / msg_my_conversations the kind 'meetup' row, but nothing ever
-- created one (0 rows live on 2026-11-14), so a meetup chat could not be opened.
--
-- This adds ONE new function and replaces none. It is msg_game_conversation with the game words swapped:
--   * p_meetup_id is meetups.id (= events.id for every meetup: 39/39 live).
--   * The lazy create runs only for a caller who is a member by the KAN-558 rule msg_evaluate already applies:
--     the organiser (events.creator_user_id) or an RSVP with status 'going'. Anyone else gets not_member and no row.
--   * The verdict is msg_evaluate's, unchanged: going -> send (or game_ended / game_cancelled read-only), an RSVP
--     'cancelled' -> read up to left_at_seq ('left'), anything else -> not_member. RSVP going grants access and
--     leaving / host cancel removes it at request time; there is no member row to keep in sync.
-- ACL: authenticated + service_role only (PUBLIC and anon revoked by name; pg_default_acl grants anon).

CREATE FUNCTION public.msg_meetup_conversation(p_meetup_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(user_id uuid, conversation_id uuid, meetup_id uuid, allowed_action text, reason text, left_at_seq bigint, muted boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_conv   uuid;
  v_eval   record;
  v_owner  uuid;
  v_exists boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint, false;
    RETURN;
  END IF;

  SELECT true, e.creator_user_id INTO v_exists, v_owner
    FROM public.meetups mt
    JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
   WHERE mt.id = p_meetup_id;
  IF v_exists IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, 'not_found'::text, NULL::bigint, false;
    RETURN;
  END IF;

  SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.meetup_id = p_meetup_id;

  IF v_conv IS NULL THEN
    -- The shared gates, by msg_evaluate itself: the nil id has no row, so past the gates it answers not_member.
    SELECT * INTO v_eval FROM public.msg_evaluate('00000000-0000-0000-0000-000000000000'::uuid, v_uid, p_access_mode);
    IF v_eval.reason IS DISTINCT FROM 'not_member' THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, v_eval.reason, NULL::bigint, false;
      RETURN;
    END IF;
    IF v_owner IS DISTINCT FROM v_uid
       AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps r
                        WHERE r.meetup_id = p_meetup_id AND r.user_id = v_uid AND r.status = 'going') THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, 'not_member'::text, NULL::bigint, false;
      RETURN;
    END IF;
    INSERT INTO public.msg_conversations (kind, meetup_id) VALUES ('meetup', p_meetup_id)
    -- the constraint by name: a bare (meetup_id) target would be ambiguous with the OUT column of the same name.
    ON CONFLICT ON CONSTRAINT msg_conversations_meetup_id_key DO NOTHING;
    SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.meetup_id = p_meetup_id;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(v_conv, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, v_eval.reason, NULL::bigint, false;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid, v_conv, p_meetup_id, v_eval.allowed_action, v_eval.reason, v_eval.left_at_seq,
         EXISTS (SELECT 1 FROM public.msg_conversation_members m
                  WHERE m.conversation_id = v_conv AND m.user_id = v_uid AND m.muted_at IS NOT NULL);
END;
$function$;

REVOKE ALL ON FUNCTION public.msg_meetup_conversation(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.msg_meetup_conversation(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.msg_meetup_conversation(uuid, text) TO authenticated, service_role;
